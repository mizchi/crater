// =============================================================================
// Helper functions
// =============================================================================

///|
fn min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

// =============================================================================
// Core Types
// =============================================================================

///|
/// 2D size with width and height
pub struct Size[T] {
  width : T
  height : T
}

///|
pub fn[T] Size::new(width : T, height : T) -> Size[T] {
  { width, height }
}

///|
pub impl[T : Show] Show for Size[T] with output(self, logger) {
  logger.write_string("Size { width: ")
  self.width.output(logger)
  logger.write_string(", height: ")
  self.height.output(logger)
  logger.write_string(" }")
}

///|
pub fn Size::zero() -> Size[Double] {
  { width: 0.0, height: 0.0 }
}

///|
pub fn[T, U] Size::map(self : Size[T], f : (T) -> U) -> Size[U] {
  { width: f(self.width), height: f(self.height) }
}

///|
/// 2D point with x and y coordinates
pub struct Point[T] {
  x : T
  y : T
}

///|
pub fn[T] Point::new(x : T, y : T) -> Point[T] {
  { x, y }
}

///|
pub impl[T : Show] Show for Point[T] with output(self, logger) {
  logger.write_string("Point { x: ")
  self.x.output(logger)
  logger.write_string(", y: ")
  self.y.output(logger)
  logger.write_string(" }")
}

///|
pub fn Point::zero() -> Point[Double] {
  { x: 0.0, y: 0.0 }
}

///|
pub fn[T, U] Point::map(self : Point[T], f : (T) -> U) -> Point[U] {
  { x: f(self.x), y: f(self.y) }
}

///|
/// Rectangle with left, right, top, bottom edges
/// Used for margin, padding, border, inset
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
pub impl[T : Show] Show for Rect[T] with output(self, logger) {
  logger.write_string("Rect { left: ")
  self.left.output(logger)
  logger.write_string(", right: ")
  self.right.output(logger)
  logger.write_string(", top: ")
  self.top.output(logger)
  logger.write_string(", bottom: ")
  self.bottom.output(logger)
  logger.write_string(" }")
}

///|
pub fn Rect::zero() -> Rect[Double] {
  { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 }
}

///|
pub fn[T, U] Rect::map(self : Rect[T], f : (T) -> U) -> Rect[U] {
  {
    left: f(self.left),
    right: f(self.right),
    top: f(self.top),
    bottom: f(self.bottom),
  }
}

///|
/// Sum of left and right (horizontal axis)
pub fn Rect::horizontal_sum(self : Rect[Double]) -> Double {
  self.left + self.right
}

///|
/// Sum of top and bottom (vertical axis)
pub fn Rect::vertical_sum(self : Rect[Double]) -> Double {
  self.top + self.bottom
}

///|
/// A line segment with start and end points
pub struct Line[T] {
  start : T
  end : T
}

///|
pub fn[T] Line::new(start : T, end : T) -> Line[T] {
  { start, end }
}

///|
pub impl[T : Show] Show for Line[T] with output(self, logger) {
  logger.write_string("Line { start: ")
  self.start.output(logger)
  logger.write_string(", end: ")
  self.end.output(logger)
  logger.write_string(" }")
}

///|
/// CSS dimension value: length, percentage, or auto
pub(all) enum Dimension {
  Length(Double)
  Percent(Double) // 0.0 to 1.0
  Auto
}

///|
pub impl Show for Dimension with output(self, logger) {
  match self {
    Length(v) => {
      logger.write_string("Length(")
      v.output(logger)
      logger.write_string(")")
    }
    Percent(v) => {
      logger.write_string("Percent(")
      v.output(logger)
      logger.write_string(")")
    }
    Auto => logger.write_string("Auto")
  }
}

///|
/// Resolve dimension to concrete value
/// context: parent size for percentage calculation
pub fn Dimension::resolve(self : Dimension, context : Double) -> Double? {
  match self {
    Length(v) => Some(v)
    Percent(v) => Some(context * v)
    Auto => None
  }
}

///|
/// Resolve with fallback value for Auto
pub fn Dimension::resolve_or(
  self : Dimension,
  context : Double,
  fallback : Double,
) -> Double {
  match self.resolve(context) {
    Some(v) => v
    None => fallback
  }
}

///|
/// BoundingRect - the output of layout computation
/// Matches browser's getBoundingClientRect()
pub(all) struct BoundingRect {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub fn BoundingRect::new(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> BoundingRect {
  { x, y, width, height }
}

///|
pub impl Show for BoundingRect with output(self, logger) {
  logger.write_string("BoundingRect { x: ")
  self.x.output(logger)
  logger.write_string(", y: ")
  self.y.output(logger)
  logger.write_string(", width: ")
  self.width.output(logger)
  logger.write_string(", height: ")
  self.height.output(logger)
  logger.write_string(" }")
}

///|
pub fn BoundingRect::zero() -> BoundingRect {
  { x: 0.0, y: 0.0, width: 0.0, height: 0.0 }
}

///|
/// Get the right edge (x + width)
pub fn BoundingRect::right(self : BoundingRect) -> Double {
  self.x + self.width
}

///|
/// Get the bottom edge (y + height)
pub fn BoundingRect::bottom(self : BoundingRect) -> Double {
  self.y + self.height
}

///|
/// Calculate the area of the bounding rect
pub fn BoundingRect::area(self : BoundingRect) -> Double {
  self.width * self.height
}

///|
/// Calculate union of two bounding rects
pub fn BoundingRect::union(
  self : BoundingRect,
  other : BoundingRect,
) -> BoundingRect {
  let x = min(self.x, other.x)
  let y = min(self.y, other.y)
  let right = max(self.right(), other.right())
  let bottom = max(self.bottom(), other.bottom())
  { x, y, width: right - x, height: bottom - y }
}
