# Design memo: connecting the layout engine to page JS (dynamic rendering)

Status: design + first data-layer step landed. The remaining work lives in the
dynamic-JS runtime (native V8 in `browser/native/js_v8`, QuickJS in `runtime/`),
which cannot be built or run in the web sandbox (rusty_v8 egress is blocked —
see #312 — and the MoonBit test suite does not execute real JS), so it is
captured here to be picked up in an environment where that runtime builds.

## The gap

crater has two render paths:

- **Static** (JS/wasm target): `parse → cascade → layout → paint`. Does **not**
  execute `<script>`. This is the VRT / snapshot / `RenderSession` path.
- **Dynamic** (native V8 / QuickJS): page JS runs against a mock DOM
  (`browser/native/js_v8/mock_dom_full.mbt`); mutations are batched as `domOps`
  and applied to the real `@dom.DomTree`, which is re-serialized to HTML and
  re-rendered.

Real Preact (`h`/`render`/`useState`) mounts on the dynamic path and the DOM is
queryable, but **layout is offline to page JS**:

- `getBoundingClientRect()` is a heuristic over inline `style.width/height/...`
  (`webdriver/.../bidi_runtime_eval.mbt:1859`; `browser/native/js_v8/mock_dom_full.mbt:4770`
  returns all-zero), so CSS-rule / flow-derived sizes read as the fallback `1`.
- `getComputedStyle()` returns a Proxy whose every property is `""`
  (`mock_dom_full.mbt:7231`); `matchMedia()` always `matches:false`;
  `offsetWidth/Height` return `0`.
- There is **no event loop**: timers / rAF only drain on an explicit
  `Browser::tick_js()`, and a mutation re-serializes the whole DOM and
  re-renders (no incremental reflow, no synchronous reflow mid-script).

So frameworks that measure layout during render (responsive, virtualization,
popover positioning, animations) don't work, and interactive apps need an
external driver to pump the loop.

## (1) Expose real layout to page JS

### Data layer — landed

`renderer/vrt` now flattens the layout tree to per-element absolute geometry:

```
pub(all) struct LayoutBox { id, index, x, y, width, height }
pub fn collect_layout_boxes(layout) -> Array[LayoutBox]   // document order
pub fn layout_box_by_id(layout, id_fragment) -> LayoutBox?
pub fn RenderSession::element_boxes() -> Array[LayoutBox]
```

crater's layout tree stores **absolute viewport coordinates**, so a box's
`{x, y, width, height}` is `{left, top, width, height}` directly. `index` is the
pre-order position — a stable key a JS DOM built in the same document order can
match. Verified: a flex row of two fixed boxes reports `#a` x=0/w=100 and `#b`
x=100/w=80.

### JS-side wiring — follow-up (needs the runtime)

1. Before `script.evaluate` (or per forced reflow), compute the layout and call
   `collect_layout_boxes`, then inject a `__craterLayoutBoxes` array into the JS
   realm (an extern set on `globalThis`).
2. Give each mock-DOM element its document-order `index` at construction (the
   mock DOM already builds in document order). Rewrite `getBoundingClientRect` /
   `offsetWidth` / `offsetHeight` / `offsetLeft/Top` to read
   `__craterLayoutBoxes[this._index]` when present, else fall back to today's
   heuristic.
3. `getComputedStyle` needs a parallel **computed-style index**: walk the render
   node tree (which holds the resolved `@style.Style` per element — see
   `compute_element_style_indexed`) and expose the subset frameworks read
   (display, position, color, font-size, width/height used values, …) keyed by
   the same `index`. This is the node-tree analogue of `collect_layout_boxes`
   and is the next testable MoonBit piece.

### Synchronous reflow caveat

A browser recomputes layout synchronously when JS reads `getBoundingClientRect`
after a mutation. crater's `domOps`-batch model can't reflow mid-script. Two
options:

- **Initial-layout only** (cheap, partial): inject the pre-script layout; reads
  before any mutation are correct, reads after a mutation are stale. Good enough
  for mount-then-measure and most SSR-shaped use.
- **Forced reflow** (full): on a measuring read, flush pending `domOps` →
  `@dom.DomTree` → recompute layout (ideally `compute_incremental`) → re-inject.
  Requires the JS↔MoonBit boundary to call back mid-execution, which the batch
  model doesn't currently support; this is the real-reflow path and pairs with
  (2).

## (2) Event loop + incremental reflow

Turn the one-shot `tick_js` into a real run-loop in `browser/shell`:

1. Run the current task (script / event handler).
2. Drain the **microtask** queue (Promise callbacks) to completion.
3. Apply batched `domOps` to `@dom.DomTree`; if the tree changed, mark the
   affected subtree dirty (the `dom/dom/mutation*.mbt` queue already classifies
   layout- vs paint-affecting via `is_layout_property`).
4. **Incrementally** re-layout/paint only the dirty subtree using the existing
   `layout/tree` `compute_incremental` (today the render path always does a full
   re-parse + re-layout — see `sync_render_state_from_dom_tree`).
5. Run **rAF** callbacks (now able to read fresh geometry), then the next macro
   task (timers). Loop until quiescent (and, for automation, expose a "settled"
   signal).

This makes `setState → re-render`, effects, and animation loops work without an
external pump, and is the prerequisite for the forced-reflow path in (1).

## Suggested order

1. **computed-style index** (MoonBit, testable like `collect_layout_boxes`).
2. **JS wiring, initial-layout** — `getBoundingClientRect`/`offsetWidth/Height` +
   `getComputedStyle` read the injected indexes (validate in an env with the
   runtime).
3. **Run-loop** in `browser/shell` (microtask → domOps → incremental reflow →
   rAF), then wire forced reflow into the measuring reads.
