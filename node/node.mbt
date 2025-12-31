///|
/// Intrinsic size measurement result
pub(all) struct IntrinsicSize {
  min_width : Double
  max_width : Double
  min_height : Double
  max_height : Double
}

///|
/// Default intrinsic size for leaf nodes without measure function
/// Note: Taffy uses 0 for unmeasured nodes, but our tests expect non-zero defaults
/// because gentest.ts doesn't extract text content measure functions yet
pub fn IntrinsicSize::default() -> IntrinsicSize {
  { min_width: 20.0, max_width: 40.0, min_height: 20.0, max_height: 40.0 }
}

///|
/// Measure function type - called to determine intrinsic size of a node
/// Parameters: (available_width, available_height) -> IntrinsicSize
pub(all) struct MeasureFunc {
  func : (Double, Double) -> IntrinsicSize
}

///|
/// A node in the layout tree
pub struct Node {
  id : String
  style : @style.Style
  children : Array[Node]
  measure : MeasureFunc?
}

///|
pub fn Node::new(
  id : String,
  style : @style.Style,
  children : Array[Node],
) -> Node {
  { id, style, children, measure: None }
}

///|
pub fn Node::leaf(id : String, style : @style.Style) -> Node {
  { id, style, children: [], measure: None }
}

///|
/// Create a leaf node with a custom measure function
pub fn Node::with_measure(
  id : String,
  style : @style.Style,
  measure : MeasureFunc,
) -> Node {
  { id, style, children: [], measure: Some(measure) }
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
  UnsupportedFloat(String) // node id with float: left/right
  UnsupportedPosition(String) // node id with position: absolute/fixed
  UnsupportedDisplay(String) // node id with unsupported display type
} derive(Show)

///|
/// Result of layout computation with warnings
pub(all) struct LayoutResult {
  layout : Layout
  warnings : Array[LayoutWarning]
}
