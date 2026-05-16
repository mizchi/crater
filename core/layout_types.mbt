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
/// Matches Taffy behavior: empty/unmeasured nodes have zero intrinsic size
pub fn IntrinsicSize::default() -> IntrinsicSize {
  { min_width: 0.0, max_width: 0.0, min_height: 0.0, max_height: 0.0 }
}

///|
/// Measure function type - called to determine intrinsic size of a node
/// Parameters: (available_width, available_height) -> IntrinsicSize
pub(all) struct MeasureFunc {
  func : (Double, Double) -> IntrinsicSize
}

///|
/// Sizing mode for layout computation
/// Definite: Use available space (normal flow)
/// MaxContent: Use intrinsic max-content (shrink-to-fit)
pub(all) enum SizingMode {
  Definite
  MaxContent
} derive(Eq)

///|
/// Context for layout computation
pub(all) struct LayoutContext {
  available_width : Double
  available_height : Double?
  sizing_mode : SizingMode
  viewport_width : Double
  viewport_height : Double
  stretch_width : Bool
  stretch_height : Bool
}

///|
/// Warnings emitted during layout computation
pub(all) enum LayoutWarning {
  UnsupportedFloat(String)
  UnsupportedPosition(String)
  UnsupportedDisplay(String)
} derive(Debug)

///|
/// Complete layout result for a node
pub(all) struct Layout {
  id : String
  x : Double
  y : Double
  width : Double
  height : Double
  margin : @values.Rect[Double]
  padding : @values.Rect[Double]
  border : @values.Rect[Double]
  overflow_x : @values.Overflow
  overflow_y : @values.Overflow
  scroll_width : Double
  scroll_height : Double
  children : Array[Layout]
  text : String?
}

///|
pub fn Layout::to_bounding_rect(self : Layout) -> @values.BoundingRect {
  { x: self.x, y: self.y, width: self.width, height: self.height }
}

///|
/// Result of layout computation with warnings
pub(all) struct LayoutResult {
  layout : Layout
  warnings : Array[LayoutWarning]
}

///|
pub impl Show for LayoutWarning with output(self, logger) {
  let text = match self {
    UnsupportedFloat(id) => "UnsupportedFloat(\{id})"
    UnsupportedPosition(id) => "UnsupportedPosition(\{id})"
    UnsupportedDisplay(id) => "UnsupportedDisplay(\{id})"
  }
  logger.write_string(text)
}
