# Design: incremental reflow for the dynamic-rendering path

Status: design. This is step (4) of `docs/dynamic-rendering-js-bridge-design.md`
— make a DOM mutation re-lay-out only the dirty subtree instead of a full
re-parse + re-layout. Grounded in the current code; no implementation yet.

## Where the cost is today

The dynamic path (`browser/shell`) reflows like this on every batch of `domOps`:

1. `apply_dom_ops` (`browser/native/js_v8/js_runtime_v8.mbt:950`) writes the
   mutations into the `@dom.DomTree`.
2. `Browser::sync_render_state_from_dom_tree`
   (`browser/shell/script_dom_runtime.mbt:68`) re-serializes the DomTree to HTML,
   rebuilds the `@html.Document`, and calls `clear_render_cache`
   (`browser/shell/render_cache.mbt:28`), which drops `render_node` **and**
   `layout_tree`.
3. The next render rebuilds the render node tree from HTML and lays it out from
   scratch.

So every mutation pays a full cascade + full layout, no matter how small.

## The incremental machinery already exists — at the layout level

`@layout.LayoutTree` already does per-node incremental layout; the text renderer
uses it for non-mutating re-renders (`browser/shell/text_renderer.mbt:48`):

- `LayoutTree` holds `node_map : Map[uid, LayoutNode]` and `parent_map`
  (`layout/tree/layout_tree.mbt`).
- `LayoutNode` carries `mut dirty`, `mut children_dirty`, `cached_layout`, and an
  `on_dirty` callback that propagates `children_dirty` up the parent chain
  (`layout/tree/layout_node.mbt:65`, `:163`).
- `compute_tree_incremental` (`layout/tree/incremental_compute.mbt:426`) reuses a
  node's `cached_layout` when `can_use_cache(node, constraint) &&
  !children_dirty`.

### The decisive constraint

`can_use_cache` (`incremental_compute.mbt`) checks `node.dirty` and whether the
cached layout is still valid **for the constraint** given the node's sizing
style — but it does **not** detect a change in the node's own style *value*. For
a fixed width, `@types.Length(_) => true` unconditionally: a `width: 100px ->
200px` edit, with the parent's available space unchanged, is a **cache hit on
stale geometry** unless the node is explicitly marked dirty.

**Therefore: every node whose computed style or content changed must be
`mark_dirty()`-ed by the reflow.** The cache handles propagation and
constraint-driven invalidation; it cannot notice self-style edits.

## Why it can't be reused across a mutation today

`LayoutTree` is keyed by `Node.uid` (`core/node/node.mbt:17`), assigned from a
monotonic `next_uid()` at construction. Because the dynamic path **rebuilds the
node tree from re-serialized HTML**, every node gets a fresh `uid` on every
mutation, so the persistent `node_map` / `cached_layout` matches nothing. The
blocker is **uid churn**, plus the lack of any link from a `@dom.DomTree` node to
its render `Node`.

## Design

Decouple the two hard problems. Keep **cascade full** (correct for every selector
combinator) but make **layout incremental** (the dominant cost). Three enabling
pieces:

### (A) Stable identity: DomTree NodeId → render-node uid

Thread the originating `@dom.NodeId` onto the render `Node` so a persistent
`Map[dom_id, uid]` can keep uids stable across rebuilds.

- The DomTree already has stable per-node ids; `apply_dom_ops` works in terms of
  them and `V8JsRuntime.id_map` maps `mock_id -> @dom.NodeId`.
- `build_render_document_from_dom_tree` builds the `@html.Document` the renderer
  consumes; carry the DomTree id onto the `@html.Element` and then onto `Node`
  (add `Node.dom_id : Int?`, default `None` so the static path is unaffected).
- Keep a `Map[dom_id, uid]` in the browser. When rebuilding the node tree, assign
  `uid` from this map when the element's `dom_id` is known (stable); allocate a
  fresh uid for new elements and record it; drop entries for removed nodes.

Anonymous boxes (generated content, inline splitting — see
`renderer/renderer/generated_content.mbt`) have no `dom_id`; give them a uid
derived deterministically from their owning element's uid + a local index so they
are stable too.

### (B) Persist the tree across mutations; mark only what changed

**Layout-level core landed.** `LayoutTree::reconcile_from(prev, new_root,
dirty_uids, vw, vh)` (`layout/tree/incremental_reconcile.mbt`) bridges a freshly
built tree to a prior one: it migrates each node's `cached_layout` by matching
`uid`, clears the `from_node` default-dirty flag on persisted nodes, auto-detects
structural changes (a node whose child-`uid` set differs), then re-dirties the
structural + caller-supplied `dirty_uids` — `mark_node_dirty` propagates
`children_dirty` to ancestors. `compute_incremental` then recomputes only the
dirty subtrees. js-tested: incremental == full recompute for a content change, a
structural append, and an unchanged re-render (the last reuses the cache —
`cache_hits > 0`). Findings worth knowing for the rest of (B):

- `LayoutNode::from_node` marks every node **dirty**, so migration must
  `clear_dirty()` persisted nodes or nothing is ever a cache hit.
- crater caches **absolute** geometry, so a flow-shifting change (resizing a box
  shifts its following siblings) must include those following siblings in
  `dirty_uids` — the cache helps most for changes with no later siblings, for
  independent subtrees, and for no-op / paint-only re-renders. Tightening this
  (relative-position caching / dirty-rects) is a separate layout-engine lever.
- per-node child cache hits depend on the layout dispatcher routing children
  through the cached dispatch; today the reliable win is the clean-tree reuse.

The remaining (B) work is the shell integration that produces `dirty_uids` and a
new render node tree with stable uids (phase A's `dom_id`), then calls
`reconcile_from` instead of `clear_render_cache` + full rebuild:

1. Do **not** `clear_render_cache` on a `domOps` apply. Keep `layout_tree`.
2. Rebuild the render node tree from the mutated Document **with stable uids**
   (A). Cascade runs fully — correct for descendant/sibling/`:has()` selectors.
3. Diff each rebuilt node's computed `@style.Style` against the style the
   persistent `LayoutNode` of the same uid currently holds. Where it differs (or
   text / `src` / child-list differs), `mark_dirty()` that `LayoutNode`; new and
   removed nodes mark their parent `mark_children_dirty()`.
4. Swap the updated nodes into the `LayoutTree` (`node_map`/`parent_map`),
   preserving `cached_layout` on untouched nodes.
5. `compute_incremental()` → only dirty subtrees recompute; everything else is a
   cache hit.

A cheaper classification feeds step 3: the DomTree mutation queue already tags
records (`@dom.MutationRecord::affects_layout`, `dom/dom/mutation.mbt:148`). A
paint-only attribute edit (e.g. `color`) can skip `mark_dirty` for layout and
only invalidate paint; a layout attribute (`width`, `display`, …) marks dirty.

### (C) Validation without V8 (js target)

Correctness is a pure layout property and is testable on the **js** target, no
V8 needed: for a sequence of mutations, assert the incremental result is
byte-identical to a full from-scratch recompute — the same equivalence
`renderer/vrt`'s `RenderSession::branch_reusing_layout` vs `branch_full` tests
already use. Add a golden equality test per mutation kind (text, paint-only
attr, layout attr, append, remove, move) and a fuzz-ish sequence.

## Phasing

1. **(A) identity plumbing** — `Node.dom_id`, carry it through
   `build_render_document_from_dom_tree`, stable-uid assignment. Isolated and
   js-testable; the static render path keeps `dom_id = None` and is unchanged.
2. **(B) incremental apply** — layout-level core landed
   (`LayoutTree::reconcile_from`, js-tested). Remaining: the shell integration —
   persist `layout_tree`, build the new node tree with stable uids, compute
   `dirty_uids` (style/text diff + flow-shift following siblings), call
   `reconcile_from` instead of the full wipe. Gate behind a flag; fall back to the
   current full path when anything is unmapped (anonymous-box edge, shadow DOM)
   so it can never be *wrong*, only *less incremental*.
3. **paint-only fast path** — use `affects_layout` to keep layout and re-paint
   only (the dynamic-path analogue of `branch_reusing_layout`).
4. **forced reflow read path** (separate memo) — on a measuring read after a
   mutation, run (B) mid-script and re-inject the layout bridge so reads-after-
   mutation aren't stale. Needs a JS↔MoonBit callback the batch model doesn't yet
   have; pairs with the bridge work.

## Risks / open questions

- **Cascade still O(n).** This design makes layout incremental but re-cascades
  fully each mutation. Cascade is cheaper than layout, but a later phase could
  scope cascade with the mutation set + selector dependencies.
- **Selector combinators.** Handled correctly *because* cascade stays full; the
  risk is only in a future cascade-scoping optimization.
- **Anonymous / generated boxes.** Need deterministic uids (B/A); until then they
  force their subtree dirty.
- **Shadow DOM / slots.** `sync_render_state` has a shadow path; phase 2's
  fallback-to-full keeps it correct while incremental coverage grows.
- **measure funcs / fonts.** Cached layout already keys on constraints; a font
  load that changes measurement must invalidate — wire it to the existing
  intrinsic-cache clear (`layout_node.mark_dirty` already calls
  `clear_intrinsic_cache_for_node`).

## First commit

Phase 1 (A): add `Node.dom_id : Int?`, thread it through the DomTree→Document→
node build, and a js-target test that two renders of the same document reuse uids
for matching `dom_id`s. No behavior change to the static path.
