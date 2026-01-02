///|
/// CSS display property
pub(all) enum Display {
  Block
  Flex
  InlineFlex
  Grid
  InlineGrid
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
} derive(Show, Eq)

///|
/// Alignment for justify-content, align-items, etc.
/// Note: Start/End are physical/logical directions (not affected by flex-wrap direction)
///       FlexStart/FlexEnd are flex-relative (affected by wrap-reverse)
pub(all) enum Alignment {
  Start
  End
  FlexStart
  FlexEnd
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
} derive(Show, Eq)

///|
/// Align-self value (can override align-items for individual items)
pub(all) enum AlignSelf {
  Auto // Inherit from parent's align-items
  Start
  End
  Center
  Stretch
  Baseline // Align item by its baseline
} derive(Show, Eq)

///|
/// CSS float property
pub(all) enum Float {
  None
  Left
  Right
} derive(Show, Eq)

///|
/// CSS clear property
pub(all) enum Clear {
  None
  Left
  Right
  Both
} derive(Show, Eq)

///|
/// CSS overflow property
pub(all) enum Overflow {
  Visible // Content is not clipped (default)
  Hidden // Content is clipped, no scrollbars
  Scroll // Content is clipped with scrollbars
  Auto // Scrollbars if needed
} derive(Show, Eq)

///|
/// CSS box-sizing property
pub(all) enum BoxSizing {
  ContentBox // width/height = content only (default)
  BorderBox // width/height = content + padding + border
} derive(Show, Eq)

///|
/// CSS visibility property
pub(all) enum Visibility {
  Visible // Element is visible (default)
  Hidden // Element is invisible but takes up space
  Collapse // Same as hidden for most elements
} derive(Show, Eq)

///|
/// CSS z-index property
pub(all) enum ZIndex {
  Auto // Stacking order determined by DOM order
  Value(Int) // Explicit stacking level
} derive(Show, Eq)

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
/// All fields are mutable to support Yoga-like setter API
pub(all) struct Style {
  mut display : Display
  mut position : Position
  mut float : Float
  mut clear : Clear
  // Box sizing
  mut box_sizing : BoxSizing
  // Overflow
  mut overflow_x : Overflow
  mut overflow_y : Overflow
  // Sizing
  mut width : @types.Dimension
  mut height : @types.Dimension
  mut min_width : @types.Dimension
  mut min_height : @types.Dimension
  mut max_width : @types.Dimension
  mut max_height : @types.Dimension
  // Box model
  mut margin : @types.Rect[@types.Dimension]
  mut padding : @types.Rect[@types.Dimension]
  mut border : @types.Rect[@types.Dimension]
  // Flexbox
  mut flex_direction : FlexDirection
  mut flex_wrap : FlexWrap
  mut justify_content : Alignment
  mut align_items : Alignment
  mut align_content : Alignment
  mut align_self : AlignSelf
  mut flex_grow : Double
  mut flex_shrink : Double
  mut flex_basis : @types.Dimension
  mut order : Int // Flex item order (default 0)
  // Gap
  mut row_gap : @types.Dimension
  mut column_gap : @types.Dimension
  // Aspect ratio (width / height)
  mut aspect_ratio : Double?
  // Inset for position: absolute (left, right, top, bottom)
  mut inset : @types.Rect[@types.Dimension]
  // Grid container properties
  mut grid_template_rows : Array[TrackSizingFunction]
  mut grid_template_columns : Array[TrackSizingFunction]
  mut grid_auto_rows : Array[TrackSizingFunction]
  mut grid_auto_columns : Array[TrackSizingFunction]
  mut grid_auto_flow : GridAutoFlow
  // Grid template areas (each string is a row, e.g. ["header header", "sidebar main"])
  mut grid_template_areas : Array[String]
  // Grid item properties
  mut grid_row : GridLine
  mut grid_column : GridLine
  mut grid_area : String? // Named area for item placement
  // justify-items for grid (different from justify-content)
  mut justify_items : Alignment
  // justify-self for grid items (horizontal self-alignment)
  mut justify_self : AlignSelf
  // Font properties (for baseline calculation)
  mut font_size : Double // Computed font size in pixels (default 16.0)
  mut line_height : Double // Computed line height in pixels (default = font_size)
  // Paint properties (visual, not layout)
  mut visibility : Visibility
  mut z_index : ZIndex
  mut opacity : Double // 0.0 = transparent, 1.0 = opaque
}

///|
pub fn Style::default() -> Style {
  {
    display: Block,
    position: Relative,
    float: None,
    clear: None,
    box_sizing: ContentBox,
    overflow_x: Visible,
    overflow_y: Visible,
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
    order: 0,
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
    font_size: 16.0,
    line_height: 16.0,
    visibility: Visible,
    z_index: Auto,
    opacity: 1.0,
  }
}
