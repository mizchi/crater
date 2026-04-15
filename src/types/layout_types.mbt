///|
/// CSS display property
pub(all) enum Display {
  Block
  Inline
  InlineBlock
  Flex
  InlineFlex
  Grid
  InlineGrid
  // Table display types
  Table
  InlineTable
  TableRow
  TableCell
  TableCaption
  TableRowGroup // tbody
  TableHeaderGroup // thead
  TableFooterGroup // tfoot
  TableColumn // col (not rendered)
  TableColumnGroup // colgroup (not rendered)
  None
  // Special display type - element doesn't generate a box
  // but its children are treated as if they were children of the parent
  Contents
  // Flow-root creates a new block formatting context
  // Similar to Block but establishes BFC (contains floats, prevents margin collapse)
  FlowRoot
} derive(Debug, Eq)

///|
/// CSS position property
pub(all) enum Position {
  Static // Default - no offset applied
  Relative
  Absolute
  Fixed
} derive(Debug, Eq)

///|
/// Flex direction
pub(all) enum FlexDirection {
  Row
  RowReverse
  Column
  ColumnReverse
} derive(Debug, Eq)

///|
/// Alignment for justify-content, align-items, etc.
/// Note: Start/End are physical/logical directions (not affected by flex-wrap direction)
///       FlexStart/FlexEnd are flex-relative (affected by wrap-reverse)
pub(all) enum Alignment {
  Start
  End
  Left
  Right
  FlexStart
  FlexEnd
  Center
  SpaceBetween
  SpaceAround
  SpaceEvenly
  Stretch
  Baseline // Align items by their baselines (bottom of box for simple elements)
} derive(Debug, Eq)

///|
/// Flex wrap mode
pub(all) enum FlexWrap {
  NoWrap
  Wrap
  WrapReverse
} derive(Debug, Eq)

///|
/// Align-self value (can override align-items for individual items)
pub(all) enum AlignSelf {
  Auto // Inherit from parent's align-items
  Start
  End
  Center
  Stretch
  Baseline // Align item by its baseline
} derive(Debug, Eq)

///|
/// CSS float property
pub(all) enum Float {
  None
  Left
  Right
} derive(Debug, Eq)

///|
/// CSS clear property
pub(all) enum Clear {
  None
  Left
  Right
  Both
} derive(Debug, Eq)

///|
/// CSS overflow property
pub(all) enum Overflow {
  Visible // Content is not clipped (default)
  Hidden // Content is clipped, no scrollbars
  Clip // Content is clipped, no scrolling (like hidden but no scroll container)
  Scroll // Content is clipped with scrollbars
  Auto // Scrollbars if needed
} derive(Debug, Eq)

///|
/// CSS box-sizing property
pub(all) enum BoxSizing {
  ContentBox // width/height = content only (default)
  BorderBox // width/height = content + padding + border
} derive(Debug, Eq)

///|
/// Grid auto-flow direction
pub(all) enum GridAutoFlow {
  Row // Fill rows first (default)
  Column // Fill columns first
  RowDense // Fill rows first with dense packing
  ColumnDense // Fill columns first with dense packing
} derive(Debug, Eq)

///|
/// Grid line placement for grid items
pub(all) enum GridPlacement {
  Auto // Auto placement
  Line(Int) // Place at specific line (1-indexed, negative counts from end)
  Span(Int) // Span specified number of tracks
} derive(Debug, Eq)

///|
/// Single track sizing function (non-repeating)
pub(all) enum SingleTrackSizing {
  Length(Double) // Fixed length (px)
  Percent(Double) // Percentage (0.0 - 1.0)
  Fr(Double) // Flexible fraction (fr unit)
  Auto // Auto sizing
  MinContent // Min-content sizing
  MaxContent // Max-content sizing
  MinMax(MinTrackSizing, MaxTrackSizing) // minmax(min, max)
  FitContentLength(Double) // fit-content(length)
  FitContentPercent(Double) // fit-content(percent)
} derive(Debug, Eq)

///|
/// Repeat count for repeat() function
pub(all) enum RepeatCount {
  Count(Int) // Fixed number of repetitions
  AutoFill // Fill with as many tracks as fit
  AutoFit // Like AutoFill but collapse empty tracks
} derive(Debug, Eq)

///|
/// Track sizing function for grid-template-rows/columns
pub(all) enum TrackSizingFunction {
  Length(Double) // Fixed length (px)
  Percent(Double) // Percentage (0.0 - 1.0)
  Fr(Double) // Flexible fraction (fr unit)
  Auto // Auto sizing
  MinContent // Min-content sizing
  MaxContent // Max-content sizing
  MinMax(MinTrackSizing, MaxTrackSizing) // minmax(min, max)
  Repeat(RepeatCount, Array[SingleTrackSizing]) // repeat(count, tracks)
  FitContentLength(Double) // fit-content(length)
  FitContentPercent(Double) // fit-content(percent)
} derive(Debug, Eq)

///|
/// Minimum track sizing function for minmax()
pub(all) enum MinTrackSizing {
  Length(Double)
  Percent(Double)
  Auto
  MinContent
  MaxContent
} derive(Debug, Eq)

///|
/// Maximum track sizing function for minmax()
pub(all) enum MaxTrackSizing {
  Length(Double)
  Percent(Double)
  Fr(Double)
  Auto
  MinContent
  MaxContent
} derive(Debug, Eq)

///|
/// Grid line range (start and end)
pub(all) struct GridLine {
  start : GridPlacement
  end : GridPlacement
} derive(Debug, Eq)

///|
pub fn GridLine::auto() -> GridLine {
  { start: Auto, end: Auto }
}

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
  /// Available width from parent
  available_width : Double
  /// Available height from parent (may be undefined)
  available_height : Double?
  /// Sizing mode (defaults to MaxContent for root-level intrinsic sizing)
  sizing_mode : SizingMode
  /// Viewport width for position: fixed elements
  viewport_width : Double
  /// Viewport height for position: fixed elements
  viewport_height : Double
  /// Whether the element should stretch to fill available width (e.g., grid stretch alignment)
  stretch_width : Bool
  /// Whether the element should stretch to fill available height (e.g., grid stretch alignment)
  stretch_height : Bool
}

///|
/// Warnings emitted during layout computation
pub(all) enum LayoutWarning {
  UnsupportedFloat(String) // node id with float: left/right
  UnsupportedPosition(String) // node id with position: absolute/fixed
  UnsupportedDisplay(String) // node id with unsupported display type
} derive(Debug)

///|
/// Complete layout result for a node
pub(all) struct Layout {
  id : String
  x : Double
  y : Double
  width : Double
  height : Double
  // Box model resolved values
  margin : Rect[Double]
  padding : Rect[Double]
  border : Rect[Double]
  // Overflow clipping info
  overflow_x : Overflow
  overflow_y : Overflow
  // Scroll dimensions (content extent, used for scrollbar calculation)
  // scroll_width/height is the total scrollable content size
  // When content overflows, scroll_width/height > width/height
  scroll_width : Double
  scroll_height : Double
  // Children layouts
  children : Array[Layout]
  // Text content for text nodes
  text : String?
}

///|
pub fn Layout::to_bounding_rect(self : Layout) -> BoundingRect {
  { x: self.x, y: self.y, width: self.width, height: self.height }
}

///|
/// Result of layout computation with warnings
pub(all) struct LayoutResult {
  layout : Layout
  warnings : Array[LayoutWarning]
}

///|
pub impl Show for Display with output(self, logger) {
  let name = match self {
    Block => "Block"
    Inline => "Inline"
    InlineBlock => "InlineBlock"
    Flex => "Flex"
    InlineFlex => "InlineFlex"
    Grid => "Grid"
    InlineGrid => "InlineGrid"
    Table => "Table"
    InlineTable => "InlineTable"
    TableRow => "TableRow"
    TableCell => "TableCell"
    TableCaption => "TableCaption"
    TableRowGroup => "TableRowGroup"
    TableHeaderGroup => "TableHeaderGroup"
    TableFooterGroup => "TableFooterGroup"
    TableColumn => "TableColumn"
    TableColumnGroup => "TableColumnGroup"
    None => "None"
    Contents => "Contents"
    FlowRoot => "FlowRoot"
  }
  logger.write_string(name)
}

///|
pub impl Show for Position with output(self, logger) {
  let name = match self {
    Static => "Static"
    Relative => "Relative"
    Absolute => "Absolute"
    Fixed => "Fixed"
  }
  logger.write_string(name)
}

///|
pub impl Show for FlexDirection with output(self, logger) {
  let name = match self {
    Row => "Row"
    RowReverse => "RowReverse"
    Column => "Column"
    ColumnReverse => "ColumnReverse"
  }
  logger.write_string(name)
}

///|
pub impl Show for Alignment with output(self, logger) {
  let name = match self {
    Start => "Start"
    End => "End"
    Left => "Left"
    Right => "Right"
    FlexStart => "FlexStart"
    FlexEnd => "FlexEnd"
    Center => "Center"
    SpaceBetween => "SpaceBetween"
    SpaceAround => "SpaceAround"
    SpaceEvenly => "SpaceEvenly"
    Stretch => "Stretch"
    Baseline => "Baseline"
  }
  logger.write_string(name)
}

///|
pub impl Show for FlexWrap with output(self, logger) {
  let name = match self {
    NoWrap => "NoWrap"
    Wrap => "Wrap"
    WrapReverse => "WrapReverse"
  }
  logger.write_string(name)
}

///|
pub impl Show for AlignSelf with output(self, logger) {
  let name = match self {
    Auto => "Auto"
    Start => "Start"
    End => "End"
    Center => "Center"
    Stretch => "Stretch"
    Baseline => "Baseline"
  }
  logger.write_string(name)
}

///|
pub impl Show for Float with output(self, logger) {
  let name = match self {
    None => "None"
    Left => "Left"
    Right => "Right"
  }
  logger.write_string(name)
}

///|
pub impl Show for Clear with output(self, logger) {
  let name = match self {
    None => "None"
    Left => "Left"
    Right => "Right"
    Both => "Both"
  }
  logger.write_string(name)
}

///|
pub impl Show for Overflow with output(self, logger) {
  let name = match self {
    Visible => "Visible"
    Hidden => "Hidden"
    Clip => "Clip"
    Scroll => "Scroll"
    Auto => "Auto"
  }
  logger.write_string(name)
}

///|
pub impl Show for BoxSizing with output(self, logger) {
  let name = match self {
    ContentBox => "ContentBox"
    BorderBox => "BorderBox"
  }
  logger.write_string(name)
}

///|
pub impl Show for GridAutoFlow with output(self, logger) {
  let name = match self {
    Row => "Row"
    Column => "Column"
    RowDense => "RowDense"
    ColumnDense => "ColumnDense"
  }
  logger.write_string(name)
}

///|
pub impl Show for GridPlacement with output(self, logger) {
  let text = match self {
    Auto => "Auto"
    Line(v) => "Line(\{v})"
    Span(v) => "Span(\{v})"
  }
  logger.write_string(text)
}

///|
pub impl Show for SingleTrackSizing with output(self, logger) {
  let text = match self {
    Length(v) => "Length(\{v})"
    Percent(v) => "Percent(\{v})"
    Fr(v) => "Fr(\{v})"
    Auto => "Auto"
    MinContent => "MinContent"
    MaxContent => "MaxContent"
    MinMax(min, max) => "MinMax(\{min}, \{max})"
    FitContentLength(v) => "FitContentLength(\{v})"
    FitContentPercent(v) => "FitContentPercent(\{v})"
  }
  logger.write_string(text)
}

///|
pub impl Show for RepeatCount with output(self, logger) {
  let text = match self {
    Count(v) => "Count(\{v})"
    AutoFill => "AutoFill"
    AutoFit => "AutoFit"
  }
  logger.write_string(text)
}

///|
pub impl Show for TrackSizingFunction with output(self, logger) {
  let text = match self {
    Length(v) => "Length(\{v})"
    Percent(v) => "Percent(\{v})"
    Fr(v) => "Fr(\{v})"
    Auto => "Auto"
    MinContent => "MinContent"
    MaxContent => "MaxContent"
    MinMax(min, max) => "MinMax(\{min}, \{max})"
    Repeat(count, tracks) => "Repeat(\{count}, \{tracks})"
    FitContentLength(v) => "FitContentLength(\{v})"
    FitContentPercent(v) => "FitContentPercent(\{v})"
  }
  logger.write_string(text)
}

///|
pub impl Show for MinTrackSizing with output(self, logger) {
  let text = match self {
    Length(v) => "Length(\{v})"
    Percent(v) => "Percent(\{v})"
    Auto => "Auto"
    MinContent => "MinContent"
    MaxContent => "MaxContent"
  }
  logger.write_string(text)
}

///|
pub impl Show for MaxTrackSizing with output(self, logger) {
  let text = match self {
    Length(v) => "Length(\{v})"
    Percent(v) => "Percent(\{v})"
    Fr(v) => "Fr(\{v})"
    Auto => "Auto"
    MinContent => "MinContent"
    MaxContent => "MaxContent"
  }
  logger.write_string(text)
}

///|
pub impl Show for GridLine with output(self, logger) {
  logger.write_string("{start: ")
  logger.write_string(self.start.to_string())
  logger.write_string(", end: ")
  logger.write_string(self.end.to_string())
  logger.write_string("}")
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
