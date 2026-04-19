// =============================================================================
// Paint Build Package - Compatibility wrapper
// =============================================================================

///|
pub using @scroll {type ScrollableElement, type ScrollableHitResult}

///|
pub fn sort_by_stacking_order(
  nodes : Array[@model.PaintNode],
) -> Array[@model.PaintNode] {
  @traversal.sort_by_stacking_order(nodes)
}

///|
pub fn sort_tree_by_stacking_order(node : @model.PaintNode) -> @model.PaintNode {
  @traversal.sort_tree_by_stacking_order(node)
}

///|
pub fn flatten_for_rendering(
  node : @model.PaintNode,
) -> Array[@model.PaintNode] {
  @traversal.flatten_for_rendering(node)
}

///|
pub fn collect_scrollable_elements(
  node : @model.PaintNode,
) -> Array[ScrollableElement] {
  @scroll.collect_scrollable_elements(node)
}

///|
pub fn find_scrollable_at(
  node : @model.PaintNode,
  x : Double,
  y : Double,
  parent_x : Double,
  parent_y : Double,
) -> ScrollableHitResult? {
  @scroll.find_scrollable_at(node, x, y, parent_x, parent_y)
}
