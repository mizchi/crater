///|
pub using @paint_model {type PaintNode}

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
