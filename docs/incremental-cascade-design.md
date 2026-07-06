# Design: incremental (scoped) cascade for the dynamic-rendering path

Status: **proposal / design phase.** This is the explicitly-deferred next lever
named in `docs/incremental-reflow-design.md` ("Risks / open questions → *Cascade
still O(n)* … a later phase could scope cascade with the mutation set + selector
dependencies"; "The remaining ceiling is the **cascade**"). Layout is already
incremental and default-on; this document designs making the **style cascade**
incremental too.

## Where the cost is now (measured)

After the incremental-layout work landed, a dynamic re-render on a `domOps`
batch does, per `browser/shell/render_cache.mbt`:

1. `prepare_render_document_for_context` — CSS parse + selector indexing.
   **Cached** across reflows (keyed on dark mode).
2. `render_node_from_document` → `@renderer.build_render_root_node(doc, ctx,
   prepared)` — **the full per-element cascade, re-run every reflow.**
3. `build_dynamic_layout_tree` — **incremental**: stable uids, `reconcile_from`,
   `Style::layout_eq` dirty seed, block-flow memoization. Only dirty subtrees
   recompute.

Profiling the native reflow path (paint-only recolor branch that reuses layout,
`benchmarks/reflow_profile`, 20 iters under callgrind) shows the split starkly:

| phase | inclusive Ir | note |
|---|---|---|
| `build_render_root_node` (cascade) | ~everything | `StyleBuilder::build` runs O(n) per reflow |
| `from_node_and_layout` (paint rebuild) | 0.17% | local, negligible |
| `diff_trees` (paint diff) | 0.16% | local, negligible |

~59% of the reflow is memory-management churn (`moonbit_drop_object`,
`ref_child_slot_at`, `ref_child_count`, malloc/free) — the allocate-then-drop of
a fresh styled `Node` tree — and almost all of the remaining app work is the
cascade itself (`mizchi/css` `StyleBuilder`, selector matching). So **cascade is
now the reflow ceiling**, exactly as the reflow design predicted.

The single most common dynamic mutation — a UI framework updating text
(`textContent` / `CharacterData`) — currently pays this full O(n) cascade even
though it changes **zero** computed styles (barring `:empty`/`:blank`; see
below).

## The correctness invariant (unchanged, and it's the whole difficulty)

A mutation on node *X* can change the *computed* style of a **different** node
*Y* through a selector combinator. The `mizchi/css` matcher supports the full
range that makes this true — confirmed in-tree:

- `:has()` (relational — an ancestor/anywhere dependency),
- `:nth-child` / `:nth-of-type` / `:first-child` / `:last-child`,
- next-sibling (`+`) and subsequent-sibling (`~`) combinators,
- `:empty` / `:blank` (depend on **child/text presence**, so even a text or
  child-list mutation can flip a match).

Today's reflow is correct **because the cascade stays full** and the dirty seed
is computed by diffing the freshly-cascaded computed `@style.Style`
(`node_layout_inputs_equal` in `incremental_reflow.mbt`), which already reflects
every combinator. Any cascade-scoping must preserve this: **the set of nodes we
re-cascade (or skip) must be a provable superset of the nodes whose computed
style could change.** Under-cascading = silently stale styles. This is the same
failure mode the reflow doc flags for the mutation queue ("*not* a safe
substitute for the style diff").

## Design principle: stylesheet-derived guards, conservative fallback

Rather than a full Blink-style invalidation-set engine up front, exploit a cheap
fact: **what a mutation *can* invalidate is bounded by what the stylesheet's
selectors actually reference.** Precompute, once per prepared stylesheet (cached
alongside `PreparedRenderDocument`), a small set of guard flags / maps:

- `uses_empty_or_blank : Bool` — any selector contains `:empty`/`:blank`.
- `uses_sibling_combinator : Bool` — any `+` or `~`.
- `uses_nth_or_position : Bool` — any `:nth-*`/`:first/last-child`/`:only-*`.
- `uses_has : Bool` — any `:has()`.
- `classes_in_selectors : Set[String]`, `attrs_in_selectors : Set[String]`,
  `ids_in_selectors : Set[String]` — the class / attribute / id names any
  selector keys on (including inside `:has()` / combinators).

These are derived from the already-parsed, already-indexed selector set, so the
computation is one pass over the stylesheet at prepare time — amortized to ~0 per
reflow (the prepared doc is cached). When any guard can't be reasoned about,
**fall back to the current full cascade** — correctness never depends on the
optimization firing.

## Phasing (value / risk ordered)

### Phase 1 — whole-batch cascade *skip* for provably-inert mutations (recommended first)

Target the dominant case: a `domOps` batch that only changes **text**
(`CharacterData`) and touches **no** class/attribute/structure that any selector
depends on.

A text-only batch changes zero computed styles **iff** the stylesheet does not
use `:empty`/`:blank` (a text edit can flip `:empty`; a combinator can then
propagate it). So:

```
batch_is_cascade_inert(batch, guards) =
  every record is CharacterData
  && not guards.uses_empty_or_blank
  && (no record adds/removes a node — pure text edits, not childList)
```

When inert, **skip `build_render_root_node` entirely.** Reuse the prior
cascaded node tree (`incremental_prev_node`) and patch only the changed text onto
the corresponding nodes (matched by `dom_id` → uid, the identity plumbing phase A
already provides). Feed the patched tree to the existing `reconcile_from`; the
`Style::layout_eq` seed will (correctly) flag only the text-changed nodes, and
block-flow memoization reuses everything else — the layout path is unchanged.

- **Win:** removes the entire O(n) cascade for the most frequent mutation kind.
  Given cascade ≈ the whole reflow today, a text-only reflow should drop toward
  the cost of re-laying-out the one changed text subtree — a several-fold reflow
  speedup on framework-driven text churn.
- **Risk:** low and *bounded by a single guard flag*. If the sheet uses
  `:empty`/`:blank`, or the batch isn't pure-text, fall back to full cascade.
- **Cost:** shell plumbing + a text-patch over the reused node tree. No change to
  `mizchi/css`.

### Phase 2 — class/attribute invalidation scoping

For an attribute/class edit on element *E*: if the changed name is **not** in
`classes_in_selectors` / `attrs_in_selectors`, no selector matches on it →
computed styles are unchanged everywhere → skip cascade (same reuse path as
Phase 1). If it *is* referenced, re-cascade a **scope**: *E*'s subtree, plus
combinator-reachable neighbours when `uses_sibling_combinator` /
`uses_nth_or_position` / `uses_has` are set (else just *E*'s subtree). Everything
outside the scope reuses prior computed styles.

- **Win:** covers class-toggle theming / state changes without a full cascade.
- **Risk:** medium — the "scope" must be a correct superset. The guard flags let
  us widen conservatively (e.g. any `:has()` in the sheet ⇒ scope widens to the
  document ⇒ effectively Phase-1-only for that sheet, still correct).

### Phase 3 — full descendant/sibling/:has invalidation sets (Blink-style)

Precompute per-feature invalidation sets from selectors and apply them per
mutation. Largest win on complex apps, largest engineering + correctness
surface. **Likely not worth it** relative to Phase 1+2 for crater's targets;
list it for completeness and defer.

## Where it hooks

- Guard computation: alongside `prepare_render_document*` (cache on the prepared
  doc), in `renderer` or `browser/shell/render_cache.mbt`.
- Skip/scope decision + node-tree reuse: `Browser::render_node_from_document`
  (`render_cache.mbt`) and `Browser::build_dynamic_layout_tree`
  (`incremental_reflow.mbt`), which already hold `incremental_prev_node` and the
  uid registry.
- The DomTree mutation queue (`dom/dom/mutation.mbt`,
  `MutationRecord::affects_layout`) supplies the per-record classification the
  batch predicate consumes — as a *refinement on top of* the correct guard, never
  a replacement (per the reflow doc's warning).

## Validation (js target, no V8)

Reuse the existing equivalence harness pattern: incremental result must be
**byte-identical** to a full from-scratch recompute, per mutation kind
(`browser/shell/incremental_reflow_wbtest.mbt`, `renderer/vrt`
`RenderSession::branch_*`). Add:

1. A "cascade skipped" counter (like `block_flow_cache_hit_count`) so a test can
   assert the fast path actually engaged — otherwise a silently-disabled skip
   looks like a pass.
2. Golden equality per kind: text-only, text-only **with** a `:empty` rule
   present (must fall back and still match), class toggle referenced vs
   unreferenced by a selector, sibling-combinator case, `:has()` case, append /
   remove / move.
3. A fuzz-ish mutation sequence asserting incremental == full throughout.

## Risks / open questions

- **`:empty`/`:blank` + text/childList** — handled by `uses_empty_or_blank`
  (fall back). This is the one non-obvious text-mutation hazard; the guard makes
  it safe.
- **`:has()`** — a relational dependency that can reach anywhere; `uses_has`
  forces conservative widening (document scope) in Phase 2.
- **Generated / anonymous boxes** — no `dom_id`; reuse must keep them attached to
  their owning element's reused subtree (the reflow doc's deterministic-uid note
  applies).
- **Shadow DOM / slots** — `sync_render_state`'s shadow path should fall back to
  full cascade until covered, matching the reflow phase-2 stance.
- **CSS custom properties / `var()`** — a `--x` change on `:root` can affect any
  consumer; treat a custom-property mutation as non-inert (fall back) unless a
  dependency map is added later.

## Recommended scope for the first change

**Phase 1 only**, as one landable step: guard computation + text-only inert-batch
detection + prior-node-tree reuse with text patching, gated behind the existing
`enable_incremental_reflow` flag and the guard fallback, with the js-target
equivalence tests above (including the "skip actually engaged" counter and the
`:empty` fallback case). Defer Phases 2–3 to follow-up PRs.

Per `CLAUDE.md`, this multi-PR workstream should get a `pkspec` scenario
(`diagnostic.*` / `protocol.*` family) filed from day one so each PR backlinks to
it; `TODO.md` gets a row under the appropriate priority.
