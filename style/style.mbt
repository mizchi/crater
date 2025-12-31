///|
/// CSS display property
pub(all) enum Display {
  Block
  Flex
  Grid
  None
} derive(Show, Eq)

///|
/// CSS position property
pub(all) enum Position {
  Relative
  Absolute
} derive(Show, Eq)

///|
/// Flex direction
pub(all) enum FlexDirection {
  Row
  RowReverse
  Column
  ColumnReverse
} derive(Show)

///|
/// Alignment for justify-content, align-items, etc.
pub(all) enum Alignment {
  Start
  End
  Center
  SpaceBetween
  SpaceAround
  SpaceEvenly
  Stretch
  Baseline // Align items by their baselines (bottom of box for simple elements)
} derive(Show, Eq)

///|
/// Flex wrap mode
pub(all) enum FlexWrap {
  NoWrap
  Wrap
  WrapReverse
} derive(Show)

///|
/// Align-self value (can override align-items for individual items)
pub(all) enum AlignSelf {
  Auto // Inherit from parent's align-items
  Start
  End
  Center
  Stretch
} derive(Show)

///|
/// CSS float property (currently unsupported, for detection only)
pub(all) enum Float {
  None
  Left
  Right
} derive(Show)

///|
/// Grid auto-flow direction
pub(all) enum GridAutoFlow {
  Row // Fill rows first (default)
  Column // Fill columns first
  RowDense // Fill rows first with dense packing
  ColumnDense // Fill columns first with dense packing
} derive(Show, Eq)

///|
/// Grid line placement for grid items
pub(all) enum GridPlacement {
  Auto // Auto placement
  Line(Int) // Place at specific line (1-indexed, negative counts from end)
  Span(Int) // Span specified number of tracks
} derive(Show, Eq)

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
} derive(Show, Eq)

///|
/// Repeat count for repeat() function
pub(all) enum RepeatCount {
  Count(Int) // Fixed number of repetitions
  AutoFill // Fill with as many tracks as fit
  AutoFit // Like AutoFill but collapse empty tracks
} derive(Show, Eq)

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
} derive(Show, Eq)

///|
/// Minimum track sizing function for minmax()
pub(all) enum MinTrackSizing {
  Length(Double)
  Percent(Double)
  Auto
  MinContent
  MaxContent
} derive(Show, Eq)

///|
/// Maximum track sizing function for minmax()
pub(all) enum MaxTrackSizing {
  Length(Double)
  Percent(Double)
  Fr(Double)
  Auto
  MinContent
  MaxContent
} derive(Show, Eq)

///|
/// Grid line range (start and end)
pub(all) struct GridLine {
  start : GridPlacement
  end : GridPlacement
} derive(Show, Eq)

///|
pub fn GridLine::auto() -> GridLine {
  { start: Auto, end: Auto }
}

///|
/// CSS Style definition for layout computation
pub(all) struct Style {
  display : Display
  position : Position
  float : Float
  // Sizing
  width : @types.Dimension
  height : @types.Dimension
  min_width : @types.Dimension
  min_height : @types.Dimension
  max_width : @types.Dimension
  max_height : @types.Dimension
  // Box model
  margin : @types.Rect[@types.Dimension]
  padding : @types.Rect[@types.Dimension]
  border : @types.Rect[@types.Dimension]
  // Flexbox
  flex_direction : FlexDirection
  flex_wrap : FlexWrap
  justify_content : Alignment
  align_items : Alignment
  align_content : Alignment
  align_self : AlignSelf
  flex_grow : Double
  flex_shrink : Double
  flex_basis : @types.Dimension
  // Gap
  row_gap : @types.Dimension
  column_gap : @types.Dimension
  // Aspect ratio (width / height)
  aspect_ratio : Double?
  // Inset for position: absolute (left, right, top, bottom)
  inset : @types.Rect[@types.Dimension]
  // Grid container properties
  grid_template_rows : Array[TrackSizingFunction]
  grid_template_columns : Array[TrackSizingFunction]
  grid_auto_rows : Array[TrackSizingFunction]
  grid_auto_columns : Array[TrackSizingFunction]
  grid_auto_flow : GridAutoFlow
  // Grid template areas (each string is a row, e.g. ["header header", "sidebar main"])
  grid_template_areas : Array[String]
  // Grid item properties
  grid_row : GridLine
  grid_column : GridLine
  grid_area : String? // Named area for item placement
  // justify-items for grid (different from justify-content)
  justify_items : Alignment
  // justify-self for grid items (horizontal self-alignment)
  justify_self : AlignSelf
}

///|
pub fn Style::default() -> Style {
  {
    display: Block,
    position: Relative,
    float: None,
    width: @types.Auto,
    height: @types.Auto,
    min_width: @types.Auto,
    min_height: @types.Auto,
    max_width: @types.Auto,
    max_height: @types.Auto,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    padding: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    border: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    flex_direction: Row,
    flex_wrap: NoWrap,
    justify_content: Start,
    align_items: Stretch,
    align_content: Stretch,
    align_self: Auto,
    flex_grow: 0.0,
    flex_shrink: 1.0,
    flex_basis: @types.Auto,
    row_gap: @types.Length(0.0),
    column_gap: @types.Length(0.0),
    aspect_ratio: None,
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Auto,
      bottom: @types.Auto,
    },
    grid_template_rows: [],
    grid_template_columns: [],
    grid_auto_rows: [],
    grid_auto_columns: [],
    grid_auto_flow: Row,
    grid_template_areas: [],
    grid_row: GridLine::auto(),
    grid_column: GridLine::auto(),
    grid_area: None,
    justify_items: Stretch,
    justify_self: Auto,
  }
}
