///|
/// Layout dispatcher - chooses the correct layout algorithm based on display type
/// This module resolves the circular dependency between block and flex layouts.

///|
/// Compute layout for a node, dispatching to the appropriate layout algorithm
/// based on the node's display property.
pub fn compute(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  match node.style.display {
    @types.Flex | @types.InlineFlex => @flex.compute(node, ctx, dispatch)
    @types.Grid | @types.InlineGrid => @grid.compute(node, ctx, dispatch)
    @types.Table | @types.InlineTable => @table.compute(node, ctx, dispatch)
    _ => @block.compute(node, ctx, dispatch)
  }
}

///|
/// Create the default dispatch function
pub fn default_dispatch() -> @node.DispatchFn {
  @node.DispatchFn(fn(node, ctx, dispatch) { compute(node, ctx, dispatch) })
}

///|
/// Compute layout with the default dispatcher (convenience function)
pub fn compute_layout(
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  let dispatch = default_dispatch()
  compute(node, ctx, dispatch)
}

///|
/// Clear intrinsic size cache for a specific node.
/// Call this when a node is marked dirty.
pub fn clear_intrinsic_cache_for_node(uid : Int) -> Unit {
  @flex.clear_intrinsic_cache_for_node(uid)
}

///|
/// Reset all intrinsic size caches.
/// Call this for a full re-layout.
pub fn reset_intrinsic_cache() -> Unit {
  @flex.reset_intrinsic_cache()
  @flex.reset_resolved_cache()
}

///|
/// @deprecated Use compute_layout or pass dispatch explicitly
/// Initialize the global layout dispatcher (kept for backward compatibility)
pub fn setup() -> Unit {
  // No-op: global dispatcher removed, use compute_layout instead
  ()
}
