///|
/// A node in the layout tree
pub struct Node {
  id : String
  style : @style.Style
  children : Array[Node]
}

///|
pub fn Node::new(id : String, style : @style.Style, children : Array[Node]) -> Node {
  { id, style, children }
}

///|
pub fn Node::leaf(id : String, style : @style.Style) -> Node {
  { id, style, children: [] }
}

///|
/// Complete layout result for a node
pub(all) struct Layout {
  id : String
  x : Double
  y : Double
  width : Double
  height : Double
  // Box model resolved values
  margin : @types.Rect[Double]
  padding : @types.Rect[Double]
  border : @types.Rect[Double]
  // Children layouts
  children : Array[Layout]
}

///|
pub fn Layout::to_bounding_rect(self : Layout) -> @types.BoundingRect {
  { x: self.x, y: self.y, width: self.width, height: self.height }
}

///|
/// Context for layout computation
pub(all) struct LayoutContext {
  /// Available width from parent
  available_width : Double
  /// Available height from parent (may be undefined)
  available_height : Double?
}

///|
/// Warnings emitted during layout computation
pub(all) enum LayoutWarning {
  UnsupportedFloat(String)    // node id with float: left/right
  UnsupportedPosition(String) // node id with position: absolute/fixed
  UnsupportedDisplay(String)  // node id with unsupported display type
} derive(Show)

///|
/// Result of layout computation with warnings
pub(all) struct LayoutResult {
  layout : Layout
  warnings : Array[LayoutWarning]
}
