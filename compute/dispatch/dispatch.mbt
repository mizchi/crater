///|
/// Layout dispatcher - chooses the correct layout algorithm based on display type
/// This module resolves the circular dependency between block and flex layouts.

///|
/// Compute layout for a node, dispatching to the appropriate layout algorithm
/// based on the node's display property.
pub fn compute(node : @node.Node, ctx : @node.LayoutContext) -> @node.Layout {
  match node.style.display {
    @style.Flex | @style.InlineFlex => @flex.compute(node, ctx)
    @style.Grid | @style.InlineGrid => @grid.compute(node, ctx)
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
