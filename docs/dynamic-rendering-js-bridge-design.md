# Design memo: connecting the layout engine to page JS (dynamic rendering)

Status: data layers, JS payload serializer, mock-DOM consumer, and the browser-
shell activation have all landed (steps (1)-(2) below). What remains is the
incremental run-loop (step (3)).

A note on "the runtime can't build in the web sandbox" (earlier drafts cited
#312): that was imprecise. The blocker is **git egress scope**, not general
egress. The Claude-Code-on-the-web git proxy is scoped to the session's
repositories, so `mizchi/v8`'s postadd (`build-rusty-v8.sh`) fails when it runs
`git clone https://github.com/denoland/rusty_v8` (403), which aborts whole-
workspace dependency resolution — even for a v8-unrelated `--target js` test.
Plain HTTPS egress to GitHub is open: the rusty_v8 source tarball, the prebuilt
`librusty_v8*.a`, and the `src_binding_release_*.rs` all download via `curl`
(HTTP 200/206). So the native runtime *does* build in this environment once the
`git clone` is replaced by an HTTPS source fetch (see #312 and
`docs/v8-build-egress.md`). The MoonBit test suite still does not execute real
JS, so the V8 round-trip is validated by the native `js_v8` tests, not the
JS-target suite.

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

   **Known gap (id-less elements).** The robust join is by id; the `_index`
   fallback is currently inert because the mock DOM never assigns `_index`
   (`create_dom_init_code` only sets `_mockId`). So `querySelector('div')` on an
   id-less element still reads the zero/empty fallback. The clean fix, now that
   render nodes carry `Node.dom_id` (= the DomTree id, == the mock element's
   `_mockId`), is to key the injected entries by `dom_id` and look them up by
   `el._mockId`. That works directly for the computed-style index (it walks the
   node tree, which has `dom_id`), but the layout-box index walks
   `@layout_types.Layout`, which does **not** carry `dom_id` — so it first needs
   `dom_id` threaded onto `Layout` through the layout engine (or boxes collected
   by walking the node + layout trees in tandem). Tracked as a follow-up.

2. **Mock-DOM consumer — landed.** `browser/native/js_v8/mock_dom_full.mbt`
   installs `__craterLayoutBox(el)` / `__craterComputedEntry(el)` (id-keyed map,
   built once and cached per injected array; `_index` fallback) and rewrites
   `getBoundingClientRect` / `offsetWidth` / `offsetHeight` / `offsetTop` /
   `offsetLeft` / `getComputedStyle` to read them. Absent the globals every
   lookup returns null and the methods fall back to today's heuristic, so the
   change is inert until a host injects the payload.

3. **Host activation — landed.** `browser/shell` (`Browser::inject_layout_bridge`
   in `js_execution.mbt`) computes the current render node + layout for the
   viewport and evaluates the payload into the realm before each script batch
   (`process_pending_script_tasks`) and before each inline eval
   (`execute_inline_js`), so `globalThis.__craterLayoutBoxes` /
   `__craterComputedStyles` are defined before page JS runs. It computes layout
   directly (not via the cached graphics node/layout, which is keyed for the
   paint path) and is best-effort — any failure leaves the mock DOM on its
   fallback. `browser/shell` now depends on `mizchi/crater-renderer/vrt` (no
   cycle: `vrt` does not import the shell). This is the "initial-layout" path:
   reads before a mutation see real geometry; reads after a mutation see the
   last injected layout until the next batch re-injects (full synchronous
   forced reflow is step (3)).

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

The run-loop landed: `Browser::run_event_loop(max_iterations~)` in
`browser/shell/js_execution.mbt` drives pending script / event tasks, the
microtask drain, `domOps` application, re-render, and one timer + rAF callback
per iteration until quiescent — returning a settled / hit-cap signal. The layout
bridge is refreshed each iteration so timer / rAF callbacks measure the latest
render, so `setState → re-render`, effects, and animation steps run without an
external pump.

**Reflow today:** the bridge skips recomputing layout when the serialized DOM is
unchanged since the last injection (`Browser::bridge_injected_html`), so idle /
no-mutation iterations (rAF that only *reads* geometry, effects that don't
mutate, polling timers) cost no extra layout. When the DOM *does* change it is
still a **full** re-layout — true dirty-subtree incremental reflow (step 4) is
the remaining follow-up, and it is a sizeable one:

- `sync_render_state_from_dom_tree` rebuilds the render node tree from
  re-serialized HTML and `clear_render_cache` drops the persistent
  `layout_tree` on every mutation, so the existing incremental machinery
  (`@layout.LayoutTree::compute_incremental`, used by the text renderer for
  non-mutating re-renders) can't reuse anything across a DOM mutation: the
  rebuilt node tree has fresh `uid`s, so nothing matches the cached layout.
- Making a mutation incremental needs a **persistent, `uid`-stable render node
  tree patched directly by `domOps`** (append/remove/setAttribute/setTextContent
  against DomTree node ids → the corresponding render nodes), with style re-
  cascaded only on the touched subtree, then `compute_incremental`. That is the
  DomTree ↔ render-node ↔ LayoutTree mapping; it is an architectural project,
  not a local edit, and should be scoped on its own.

The original sketch — turn the one-shot `tick_js` into a real run-loop in
`browser/shell`:

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
   `getComputedStyle` read the injected indexes. — landed end-to-end: payload
   serializer (`layout_bridge_init_js`), mock-DOM consumer
   (`browser/native/js_v8/mock_dom_full.mbt`), and shell activation
   (`Browser::inject_layout_bridge`). Validate the V8 round-trip with the native
   `js_v8` tests (see `docs/v8-build-egress.md` to build the runtime here).
3. **Run-loop** in `browser/shell` (microtask → domOps → reflow → rAF). — landed
   as `Browser::run_event_loop`. Redundant-layout elision landed (skip when the
   DOM is unchanged). Remaining: true dirty-subtree incremental reflow (needs the
   persistent `uid`-stable node tree patched by `domOps` — see above) and wiring
   the forced-reflow path into the measuring reads.
