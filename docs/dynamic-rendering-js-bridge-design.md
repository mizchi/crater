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

### JS-side wiring — payload + consumer landed; host activation remains

The data half and the mock-DOM consumer are now in place; what is left is the
host call that injects the payload before page scripts run.

1. **Payload serializer — landed.** `renderer/vrt` `layout_bridge_init_js(boxes,
   styles)` (and `RenderSession::layout_bridge_init_js()`) serializes the
   layout-box geometry index and the computed-style index into the JS that
   defines two page-realm globals:
   - `globalThis.__craterLayoutBoxes` — `{index, id, x, y, width, height}` in
     document order.
   - `globalThis.__craterComputedStyles` — `{index, id, display, position,
     visibility, fontSize, fontFamily, opacity, zIndex, color,
     backgroundColor}`.

   Each entry carries both the pre-order `index` and the `tag#id` `id` string so
   the consumer can join by id (unique when the element has an id attribute) or
   by document-order index. Snapshot-tested in `renderer/vrt`.

2. **Mock-DOM consumer — landed.** `browser/native/js_v8/mock_dom_full.mbt`
   installs `__craterLayoutBox(el)` / `__craterComputedEntry(el)` (id-keyed map,
   built once and cached per injected array; `_index` fallback) and rewrites
   `getBoundingClientRect` / `offsetWidth` / `offsetHeight` / `offsetTop` /
   `offsetLeft` / `getComputedStyle` to read them. Absent the globals every
   lookup returns null and the methods fall back to today's heuristic, so the
   change is inert until a host injects the payload.

3. **Host activation — remaining (needs the runtime).** The browser shell holds
   the computed layout and render node tree (`Browser` state
   `graphics_layout : @layout_types.Layout?` / `graphics_render_node :
   @node.Node?`), so before `script.evaluate` it can build the payload via
   `@vrt.layout_bridge_init_js(@vrt.collect_layout_boxes(layout),
   @vrt.collect_computed_styles(node))` and `eval_string` it into the realm
   (re-injecting on a forced reflow). This needs `browser/shell` to depend on
   `mizchi/crater-renderer/vrt` (no cycle: `vrt` does not import the shell) and
   can only be validated where the native V8 runtime builds (blocked in the web
   sandbox — see #312).

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

1. **computed-style index** (MoonBit, testable like `collect_layout_boxes`). —
   landed (`collect_computed_styles`).
2. **JS wiring, initial-layout** — `getBoundingClientRect`/`offsetWidth/Height` +
   `getComputedStyle` read the injected indexes. — payload serializer
   (`layout_bridge_init_js`) and mock-DOM consumer landed; the host activation
   call in `browser/shell` is the remaining piece (validate in an env with the
   runtime).
3. **Run-loop** in `browser/shell` (microtask → domOps → incremental reflow →
   rAF), then wire forced reflow into the measuring reads.
