// Intrinsic-width and incremental block-flow caches and their lifecycle.

///|
/// Calculate max-content width of children for intrinsic sizing
/// This is used when min-width or max-width is max-content/min-content
// Per-render memoization of intrinsic widths. A node's min/max-content width is
// a pure function of (node subtree, parent_width [, parent_content_height]) and
// node.uid is process-unique, so a key of (uid, ...) is stable; the cache is
// only cleared for memory hygiene (see clear_block_intrinsic_caches), never for
// correctness. This collapses the otherwise exponential mutual recursion
// between min/max-content over deep trees (the dominant layout cost on
// text-heavy pages — see #316).
let min_intrinsic_width_cache : Ref[Map[String, Double]] = { val: Map([]), }

///|
let max_intrinsic_width_cache : Ref[Map[String, Double]] = { val: Map([]), }

///|
/// Reset the intrinsic-width memoization caches. Called once at the start of a
/// top-level layout so they don't accumulate across renders.
pub fn clear_block_intrinsic_caches() -> Unit {
  min_intrinsic_width_cache.val = Map([])
  max_intrinsic_width_cache.val = Map([])
}

///|
/// Block-flow memoization: per-`uid` cache of an in-flow block child's
/// `compute_with_collapse` result (layout + escaping collapse margins), so an
/// incremental relayout can skip recomputing a child whose whole subtree is
/// unchanged. `compute_with_collapse(child, ctx)` is a pure function of the
/// child subtree and the constraint, so reusing it for a clean child under the
/// same constraint is exact — the parent's stacking / shift passes treat a
/// cached result identically to a freshly computed one.
///
/// Correctness gates (both required before reuse): the child is reported clean
/// by the incremental driver (`@node.node_is_clean(uid)` — its subtree did not
/// change) AND the cached constraint key matches the current child constraint.
/// The cache is populated only while an incremental layout is active
/// (`@node.node_incremental_active()`), so the static / full-layout path never
/// reads or writes it and is byte-for-byte unchanged. `uid`s are stabilized
/// across rebuilds by the reconcile registry, so an entry keeps tracking the
/// same element.
priv struct BlockFlowCacheEntry {
  key : String
  result : LayoutWithCollapse
}

///|
let block_flow_cache : Ref[Map[Int32, BlockFlowCacheEntry]] = { val: Map([]), }

///|
let block_flow_cache_hits : Ref[Int32] = { val: 0, }

///|
/// Number of in-flow block children served from the block-flow cache since the
/// last `reset_block_flow_cache_hits`. For tests / perf characterization.
pub fn block_flow_cache_hit_count() -> Int32 {
  block_flow_cache_hits.val
}

///|
/// Reset the block-flow cache hit counter (tests / perf characterization).
pub fn reset_block_flow_cache_hits() -> Unit {
  block_flow_cache_hits.val = 0
}

///|
/// Drop the whole block-flow memoization cache (memory hygiene / test isolation).
pub fn clear_block_flow_cache() -> Unit {
  block_flow_cache.val = Map([])
  block_flow_cache_hits.val = 0
}

///|
/// Build the constraint key for the block-flow cache from a child layout
/// context. Includes every field that can change the child's computed layout.
fn block_flow_cache_key(ctx : @layout_types.LayoutContext) -> String {
  let ah = match ctx.available_height {
    Some(h) => h.to_string()
    None => "_"
  }
  let sizing = match ctx.sizing_mode {
    @layout_types.Definite => "d"
    @layout_types.MaxContent => "max"
  }
  ctx.available_width.to_string() +
  "|" +
  ah +
  "|" +
  sizing +
  "|" +
  ctx.viewport_width.to_string() +
  "|" +
  ctx.viewport_height.to_string() +
  "|" +
  (if ctx.stretch_width { "1" } else { "0" }) +
  (if ctx.stretch_height { "1" } else { "0" })
}

///|
/// Compute an in-flow block child's layout, reusing the cached
/// `compute_with_collapse` result when the child's subtree is unchanged
/// (see `block_flow_cache`). On a miss it computes and (while incremental is
/// active) stores the result.
fn compute_block_child_memoized(
  child : @node.Node,
  ctx : @layout_types.LayoutContext,
  warnings : Array[@layout_types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> LayoutWithCollapse {
  // `node_is_clean` only answers true while an incremental reflow has a clean
  // predicate installed, which is also the one condition under which this
  // cache is written, so outside such a reflow the key has no reader at all.
  // Building it up front spent five `Double::to_string()` calls and six string
  // concatenations per block child of every static render, then threw the
  // result away.
  let key : String? = if @node.node_incremental_active() {
    Some(block_flow_cache_key(ctx))
  } else {
    None
  }
  match key {
    Some(key) =>
      if @node.node_is_clean(child.uid) {
        match block_flow_cache.val.get(child.uid) {
          Some(entry) =>
            if entry.key == key {
              block_flow_cache_hits.val = block_flow_cache_hits.val + 1
              return entry.result
            }
          None => ()
        }
      }
    None => ()
  }
  let raw = compute_with_collapse(child, ctx, warnings, dispatch)
  let snapped = apply_initial_scroll_snap(child, raw.layout)
  // `apply_initial_scroll_snap` hands its input straight back for any child
  // without overflow alignment or mandatory scroll snap (nearly all of them),
  // so rebuilding the record unconditionally allocated one
  // `LayoutWithCollapse` per block child per render for no change at all.
  let result = if physical_equal(snapped, raw.layout) {
    raw
  } else {
    { ..raw, layout: snapped, }
  }
  match key {
    Some(key) => block_flow_cache.val.set(child.uid, { key, result, })
    None => ()
  }
  result
}
