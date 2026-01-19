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
} derive(Show, Eq)

///|
/// CSS position property
pub(all) enum Position {
  Static // Default - no offset applied
  Relative
  Absolute
  Fixed
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
