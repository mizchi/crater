// =============================================================================
// Paint Scroll Package - Scrollable extraction and hit-testing
// =============================================================================

///|
pub(all) struct ScrollableElement {
  id : String
  scroll_width : Double
  scroll_height : Double
  client_width : Double
  client_height : Double
}

///|
pub fn collect_scrollable_elements(
  node : @model.PaintNode,
) -> Array[ScrollableElement] {
  let result : Array[ScrollableElement] = []
  fn collect(
    node : @model.PaintNode,
    result : Array[ScrollableElement],
  ) -> Unit {
    if node.is_scrollable() {
      result.push({
        id: node.id,
        scroll_width: node.scroll_width,
        scroll_height: node.scroll_height,
        client_width: node.width,
        client_height: node.height,
      })
    }
    for child in node.children {
      collect(child, result)
    }
  }

  collect(node, result)
  result
}

///|
pub(all) struct ScrollableHitResult {
  id : String
  x : Double
  y : Double
  width : Double
  height : Double
  scroll_width : Double
  scroll_height : Double
}

///|
pub fn find_scrollable_at(
  node : @model.PaintNode,
  x : Double,
  y : Double,
  parent_x : Double,
  parent_y : Double,
) -> ScrollableHitResult? {
  let abs_x = parent_x + node.x
  let abs_y = parent_y + node.y
  if x < abs_x ||
    x >= abs_x + node.width ||
    y < abs_y ||
    y >= abs_y + node.height {
    return None
  }
  for child in node.children {
    match find_scrollable_at(child, x, y, abs_x, abs_y) {
      Some(result) => return Some(result)
      None => ()
    }
  }
  if node.is_scrollable() {
    return Some({
      id: node.id,
      x: abs_x,
      y: abs_y,
      width: node.width,
      height: node.height,
      scroll_width: node.scroll_width,
      scroll_height: node.scroll_height,
    })
  }
  None
}
