///|
/// Layout dispatcher - chooses the correct layout algorithm based on display type
/// This module resolves the circular dependency between block and flex layouts.

///|
/// Compute layout for a node, dispatching to the appropriate layout algorithm
/// based on the node's display property.
pub fn compute(node : @node.Node, ctx : @node.LayoutContext) -> @node.Layout {
  match node.style.display {
    @types.Flex | @types.InlineFlex => @flex.compute(node, ctx)
    @types.Grid | @types.InlineGrid => @grid.compute(node, ctx)
    @types.Table | @types.InlineTable => @table.compute(node, ctx)
    _ => @block.compute(node, ctx)
  }
}

///|
/// Initialize the global layout dispatcher
/// Call this before performing any layout computations
pub fn setup() -> Unit {
  @node.set_layout_dispatcher(
    @node.LayoutDispatchFunc(fn(node, ctx) { compute(node, ctx) }),
  )
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
