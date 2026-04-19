///|
/// Flex direction.
pub(all) enum FlexDirection {
  Row
  RowReverse
  Column
  ColumnReverse
} derive(Show, Eq)

///|
/// Alignment for justify-content, align-items and similar properties.
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
  Baseline
} derive(Show, Eq)

///|
/// Align-self value.
pub(all) enum AlignSelf {
  Auto
  Start
  End
  Center
  Stretch
  Baseline
} derive(Show, Eq)

///|
/// Generic 4-edge rect.
pub(all) struct Rect[T] {
  left : T
  right : T
  top : T
  bottom : T
}

///|
pub fn[T] Rect::new(left : T, right : T, top : T, bottom : T) -> Rect[T] {
  { left, right, top, bottom }
}

///|
/// CSS dimension value.
pub(all) enum Dimension {
  Length(Double)
  Percent(Double)
  Auto
  MinContent
  MaxContent
  FitContent(Double)
} derive(Eq, Show)
