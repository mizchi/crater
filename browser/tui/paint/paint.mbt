// =============================================================================
// TUI Paint Facade - browser-facing wrappers over crater paint packages
// =============================================================================

///|
pub using @paint_plain {type PaintNode}

///|
pub using @paint_runtime {type ScrollableElement, type PreparedPaint}

///|
pub fn from_node_and_layout(
  node : @node.Node,
  layout : @types.Layout,
) -> PaintNode {
  @paint_plain.from_node_and_layout(node, layout)
}

///|
pub fn from_node_and_layout_with_viewport(
  node : @node.Node,
  layout : @types.Layout,
  viewport_top : Double,
  viewport_bottom : Double,
  parent_y : Double,
) -> PaintNode? {
  @paint_viewport.from_node_and_layout_with_viewport(
    node, layout, viewport_top, viewport_bottom, parent_y,
  )
}

///|
pub fn prepare_viewport_paint(
  node : @node.Node,
  layout : @types.Layout,
  viewport_top : Double,
  viewport_bottom : Double,
  parent_y : Double,
) -> PreparedPaint? {
  @paint_runtime.prepare_viewport_paint(
    node, layout, viewport_top, viewport_bottom, parent_y,
  )
}
