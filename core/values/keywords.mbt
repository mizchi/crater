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
  Table
  InlineTable
  TableRow
  TableCell
  TableCaption
  TableRowGroup
  TableHeaderGroup
  TableFooterGroup
  TableColumn
  TableColumnGroup
  None
  Contents
  FlowRoot
} derive(Debug, Eq)

///|
/// CSS position property
pub(all) enum Position {
  Static
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
  Baseline
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
  Auto
  Start
  End
  Center
  Stretch
  Baseline
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
  Visible
  Hidden
  Clip
  Scroll
  Auto
} derive(Debug, Eq)

///|
/// CSS box-sizing property
pub(all) enum BoxSizing {
  ContentBox
  BorderBox
} derive(Debug, Eq)

///|
/// Grid auto-flow direction
pub(all) enum GridAutoFlow {
  Row
  Column
  RowDense
  ColumnDense
} derive(Debug, Eq)

///|
/// Grid line placement for grid items
pub(all) enum GridPlacement {
  Auto
  Line(Int)
  Span(Int)
} derive(Debug, Eq)

///|
/// Single track sizing function (non-repeating)
pub(all) enum SingleTrackSizing {
  Length(Double)
  Percent(Double)
  Fr(Double)
  Auto
  MinContent
  MaxContent
  MinMax(MinTrackSizing, MaxTrackSizing)
  FitContentLength(Double)
  FitContentPercent(Double)
} derive(Debug, Eq)

///|
/// Repeat count for repeat() function
pub(all) enum RepeatCount {
  Count(Int)
  AutoFill
  AutoFit
} derive(Debug, Eq)

///|
/// Track sizing function for grid-template-rows/columns
pub(all) enum TrackSizingFunction {
  Length(Double)
  Percent(Double)
  Fr(Double)
  Auto
  MinContent
  MaxContent
  MinMax(MinTrackSizing, MaxTrackSizing)
  Repeat(RepeatCount, Array[SingleTrackSizing])
  FitContentLength(Double)
  FitContentPercent(Double)
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
    Repeat(count, tracks) => "Repeat(\{count}, \{to_repr(tracks)})"
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
