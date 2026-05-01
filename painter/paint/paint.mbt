// =============================================================================
// Paint Package - Umbrella compatibility wrapper
// =============================================================================

///|
pub using @paint_build {type ScrollableElement, type ScrollableHitResult}

///|
pub using @paint_model {type PaintNode, type PaintProperties}

///|
pub fn sort_by_stacking_order(nodes : Array[PaintNode]) -> Array[PaintNode] {
  @paint_build.sort_by_stacking_order(nodes)
}

///|
pub fn sort_tree_by_stacking_order(node : PaintNode) -> PaintNode {
  @paint_build.sort_tree_by_stacking_order(node)
}

///|
pub fn flatten_for_rendering(node : PaintNode) -> Array[PaintNode] {
  @paint_build.flatten_for_rendering(node)
}

///|
pub fn from_node_and_layout(
  node : @node.Node,
  layout : @types.Layout,
) -> PaintNode {
  @paint_node.from_node_and_layout(node, layout)
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
pub fn from_node_and_layout_with_viewport_rect(
  node : @node.Node,
  layout : @types.Layout,
  viewport_left : Double,
  viewport_top : Double,
  viewport_right : Double,
  viewport_bottom : Double,
  parent_x : Double,
  parent_y : Double,
) -> PaintNode? {
  @paint_viewport.from_node_and_layout_with_viewport_rect(
    node, layout, viewport_left, viewport_top, viewport_right, viewport_bottom, parent_x,
    parent_y,
  )
}

///|
pub fn from_layout(layout : @types.Layout) -> PaintNode {
  @paint_layout_tree.from_layout(layout)
}

///|
pub fn collect_scrollable_elements(
  node : PaintNode,
) -> Array[ScrollableElement] {
  @paint_build.collect_scrollable_elements(node)
}

///|
pub fn find_scrollable_at(
  node : PaintNode,
  x : Double,
  y : Double,
  parent_x : Double,
  parent_y : Double,
) -> ScrollableHitResult? {
  @paint_build.find_scrollable_at(node, x, y, parent_x, parent_y)
}
