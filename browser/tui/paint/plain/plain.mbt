///|
pub using @paint_model {type PaintNode}

///|
pub fn from_node_and_layout(
  node : @node.Node,
  layout : @layout_types.Layout,
) -> PaintNode {
  @paint_node.from_node_and_layout(node, layout)
}
