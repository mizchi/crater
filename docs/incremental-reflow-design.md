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
  `dirty_uids`. `LayoutTree::flow_dirty_uids(seed)` (landed, js-tested) expands a
  seed of directly-changed uids into the correct set: for each changed node, the
  following siblings' subtrees at its level and at every ancestor level. Feeding
  this to `reconcile_from` makes the incremental layout equal a full recompute
  while keeping the dirty set tight.
- **but** the practical speedup is currently bounded by the layout engine's
  per-node cache, not by the dirty set: `children_dirty` propagates to the root
  on any change, so the reliable reuse today is the **root / high-subtree
  short-circuit** (a clean subtree returns its cached layout without descending)
  — i.e. no-op, paint-only, and disjoint-subtree re-renders.

  **Measured root cause (item 3).** The per-uid cache (`try_cache_by_uid`,
  `incremental_compute.mbt`) was only consulted for children dispatched through
  the cache-aware callback — i.e. **flex / grid / table / inline-block BFC
  roots** (`block.mbt`, `dispatch_fn(child_for_layout, …)`). Ordinary **in-flow
  block children** were laid out by `compute_with_collapse` directly, which never
  read the cache. So a `display:block` stack recomputed in full no matter how
  little changed — a late-element change reused nothing earlier. Pinned by
  `layout/tree/incremental_perf_wbtest.mbt`.

  **Fix (landed): block-flow memoization.** `compute_with_collapse(child, ctx)`
  is a *pure* function of the child subtree and the constraint, so it is
  memoized per `uid` (`block_flow_cache` in `block.mbt`): an in-flow block child
  whose whole subtree is unchanged is served from its cached
  `LayoutWithCollapse` — layout **and** escaping collapse margins together — so
  the parent's stacking / shift passes treat it identically to a fresh compute.
  No coordinate or collapse-through reasoning is needed: a clean child under the
  same constraint returns exactly what a recompute would. Two correctness gates,
  both required before reuse:

  - the child's subtree is unchanged — `@node.node_is_clean(uid)`, a core hook
    installed by `compute_tree_incremental` over the `LayoutTree`'s dirty state
    (`!dirty && !children_dirty`, dependency-inverted like the layout dispatcher
    so `layout/block` need not depend on `layout/tree`); and
  - the constraint matches — the cache key encodes available width/height,
    sizing mode, and viewport.

  The cache is populated only while an incremental layout is active
  (`@node.node_incremental_active()`), so the static / full-layout path neither
  reads nor writes it and is byte-for-byte unchanged. Validated on the js target:
  a 12-block stack with the last block changed now reuses all 11 preceding
  blocks (`block_flow_cache_hit_count() == 11`) and the incremental layout is
  byte-identical to a full recompute; a width change misses the key (no stale
  reuse); nested block subtrees reuse the unchanged sibling branch. The whole
  layout (326) and renderer/vrt (410) suites stay green.

  The remaining ceiling is the **cascade** (still O(n) per mutation) and the
  flex/grid cross-axis perturbation (a change to one flex item can legitimately
  dirty its line); those are separate levers.

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

> **Note — the mutation queue is *not* a safe substitute for the style diff.**
> A mutation on node X can change node Y's *computed* style via a combinator
> (`:has()`, `+`, `~`, `:nth-child`). Dirtying only the mutated DomTree nodes
> would leave Y reading stale cache. The only fully-correct seed is comparing the
> freshly-cascaded computed `@style.Style` (step 3), which reflects every
> combinator. The mutation queue is a *paint-vs-layout* refinement on top of a
> correct seed, not a replacement for it.

#### Step 3 narrowing — **landed** (mizchi/css `Style::layout_eq`)

The shell used to pass **every** uid as `dirty_uids`
(`Browser::build_dynamic_layout_tree`) — correct (== full recompute) but it
defeated the block-flow memoization, which only reuses nodes the driver reports
clean. Narrowing needed an `old_style != new_style` check per uid; `@style.Style`
is a large struct and a hand-rolled comparator in crater would under-report the
moment a field is missed (→ stale layout). The clean signal lives upstream:
**`mizchi/css@0.7.3` adds `Style::layout_eq(self, other) -> Bool`** comparing only
layout-affecting fields (paint-only — color, background, shadow, border-color,
border-radius, clip, opacity, z-index, pointer-events — ignored), so a paint-only
change does not invalidate layout. (Blanket `derive(Eq)` on `Style` would instead
force `Eq` onto paint types like gradients/shadows and over-dirty on repaint — the
focused method is the right tool.)

crater consumes it (`Browser::build_dynamic_layout_tree`): it keeps the prior
render-node tree (`incremental_prev_node`), seeds the dirty set with the persisted
uids whose `node_layout_inputs_equal` fails — `!a.style.layout_eq(b.style)` or a
`text` / `src` / measure-presence change — expands it with `flow_dirty_uids`
(absolute-geometry flow shift), and hands that to `reconcile_from` (whose
structural pass covers add/remove/move). The comparison is against the *computed*
post-cascade style, so a mutation that changes an un-mutated node's style via a
combinator (`:has()`, `+`, `~`, `:nth-child`) is still caught. js-tested on-vs-off
render equivalence per mutation kind (text, size, paint-only, append, remove) in
`browser/shell/incremental_reflow_wbtest.mbt`. Residual: a measure-func *value*
change with no src/style change (closures aren't comparable).

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
   (`LayoutTree::reconcile_from`, js-tested), stable-uid registry landed
   (`stabilize_uids` / `UidRegistry`, js-tested), and the **shell wiring landed
   behind a default-off flag**: `Browser::set_incremental_reflow(true)` makes the
   dynamic render path stabilize uids and reconcile against the prior tree
   (`Browser::build_dynamic_layout_tree` in `browser/shell/incremental_reflow.mbt`,
   used by the text render path). Off by default → byte-for-byte the current
   behavior; js-tested that on vs off render identically. The dirty seed is now
   **narrowed** (landed): `build_dynamic_layout_tree` seeds only the persisted
   uids whose layout inputs changed (`Style::layout_eq` / text / src / measure),
   expands with `flow_dirty_uids`, and reconciles — so the **block-flow
   memoization** (also landed) reuses the unchanged block subtrees. js-tested
   on-vs-off equivalence per mutation kind (see "Step 3 narrowing — landed"
   above). Validate the dynamic round-trip with native V8.
3. **paint-only fast path** — use `affects_layout` to keep layout and re-paint
   only (the dynamic-path analogue of `branch_reusing_layout`).
4. **forced reflow read path** (separate memo) — on a measuring read after a
   mutation, run (B) mid-script and re-inject the layout bridge so reads-after-
   mutation aren't stale. Needs a JS↔MoonBit callback the batch model doesn't yet
   have; pairs with the bridge work.

## Checking it (CLI / VRT)

The flag is exposed on the CLI as `--incremental-reflow` (default off), so a
render can be driven with reconcile on without code changes:

```bash
# Same page, flag off vs on — text output should be identical (a smoke check
# that reconcile doesn't perturb a static render):
crater --text https://example.com > off.txt
crater --text --incremental-reflow https://example.com > on.txt
diff off.txt on.txt   # expect no difference

# The real signal is on *re-renders after a DOM mutation* (the dynamic path),
# which the static paint-VRT harness (single `crater_paint` render) does not
# exercise. Use the native-V8 e2e sign-off for that:
just test-native-full   # "E2E: incremental reflow matches a full rebuild ..."
```

The js-target `incremental_reflow_wbtest.mbt` sweep is the offline equivalent of
the VRT equivalence check (incremental == full per mutation kind, no browser
needed). A paint-level VRT that mutates then re-renders would need a harness on
the dynamic (JS) path rather than the static `crater_paint` stdin renderer.

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
