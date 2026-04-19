// =============================================================================
// Paint Layout Bridge Package - Compatibility wrappers
// =============================================================================

///|
pub fn from_node_and_layout(
  node : @layout.Node,
  layout : @types.Layout,
) -> @model.PaintNode {
  @node_bridge.from_node_and_layout(node, layout)
}

///|
pub fn from_node_and_layout_with_viewport(
  node : @layout.Node,
  layout : @types.Layout,
  viewport_top : Double,
  viewport_bottom : Double,
  parent_y : Double,
) -> @model.PaintNode? {
  @viewport.from_node_and_layout_with_viewport(
    node, layout, viewport_top, viewport_bottom, parent_y,
  )
}

///|
pub fn from_layout(layout : @types.Layout) -> @model.PaintNode {
  @layout_tree_bridge.from_layout(layout)
}
