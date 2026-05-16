// =============================================================================
// Helper functions
// =============================================================================

///|
pub fn min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn max(a : Double, b : Double) -> Double {
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
/// Create a rect with all sides set to the same value
pub fn[T] Rect::all(value : T) -> Rect[T] {
  { left: value, right: value, top: value, bottom: value }
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
/// CSS dimension value: length, percentage, auto, or intrinsic sizing keywords
pub(all) enum Dimension {
  Length(Double)
  Percent(Double) // 0.0 to 1.0
  Auto
  MinContent // Intrinsic minimum content size
  MaxContent // Intrinsic maximum content size
  FitContent(Double) // fit-content(length) - clamp between min-content and max-content
} derive(Eq)

///|
/// Check if dimension equals a specific length value
pub fn Dimension::eq_length(self : Dimension, value : Double) -> Bool {
  match self {
    Length(v) => (v - value).abs() < 0.0001
    _ => false
  }
}

///|
/// Check if dimension equals a specific percent value
pub fn Dimension::eq_percent(self : Dimension, value : Double) -> Bool {
  match self {
    Percent(v) => (v - value).abs() < 0.0001
    _ => false
  }
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
    MinContent => logger.write_string("MinContent")
    MaxContent => logger.write_string("MaxContent")
    FitContent(v) => {
      logger.write_string("FitContent(")
      v.output(logger)
      logger.write_string(")")
    }
  }
}

///|
/// Resolve dimension to concrete value
/// context: parent size for percentage calculation
/// Note: MinContent, MaxContent, FitContent return None - they need intrinsic size calculation
pub fn Dimension::resolve(self : Dimension, context : Double) -> Double? {
  match self {
    Length(v) => Some(v)
    Percent(v) => Some(context * v)
    Auto => None
    MinContent => None // Requires intrinsic size calculation
    MaxContent => None // Requires intrinsic size calculation
    FitContent(_) => None // Requires intrinsic size calculation
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
/// Check if dimension is a definite value (Length or Percent)
pub fn Dimension::is_definite(self : Dimension) -> Bool {
  match self {
    Length(_) | Percent(_) => true
    _ => false
  }
}

///|
/// Check if dimension requires intrinsic sizing
pub fn Dimension::is_intrinsic(self : Dimension) -> Bool {
  match self {
    MinContent | MaxContent | FitContent(_) => true
    _ => false
  }
}

///|
/// Resolve dimension to length, treating intrinsic keywords as fallback
pub fn Dimension::resolve_or_intrinsic(
  self : Dimension,
  context : Double,
  fallback : Double,
) -> Double {
  match self {
    Length(v) => v
    Percent(p) => context * p
    Auto => fallback
    MinContent => fallback // Intrinsic sizing handled by layout engine
    MaxContent => fallback
    FitContent(_) => fallback
  }
}

///|
/// Resolve a Rect[Dimension] (margin/padding/border) to Rect[Double]
/// Uses parent_width for percentage resolution (CSS spec: percentages resolve against width)
pub fn resolve_rect(
  rect : Rect[Dimension],
  parent_width : Double,
) -> Rect[Double] {
  {
    left: rect.left.resolve_or(parent_width, 0.0),
    right: rect.right.resolve_or(parent_width, 0.0),
    top: rect.top.resolve_or(parent_width, 0.0),
    bottom: rect.bottom.resolve_or(parent_width, 0.0),
  }
}

///|
/// Resolve a dimension rect for intrinsic sizing
/// Percentages resolve to 0 in intrinsic sizing contexts
pub fn resolve_rect_intrinsic(rect : Rect[Dimension]) -> Rect[Double] {
  fn resolve_intrinsic(dim : Dimension) -> Double {
    match dim {
      Length(v) => v
      Percent(_) => 0.0
      Auto => 0.0
      MinContent => 0.0 // Not applicable for margin/padding/border
      MaxContent => 0.0
      FitContent(_) => 0.0
    }
  }

  {
    left: resolve_intrinsic(rect.left),
    right: resolve_intrinsic(rect.right),
    top: resolve_intrinsic(rect.top),
    bottom: resolve_intrinsic(rect.bottom),
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

// ============================================================================
// Aspect Ratio utilities
// ============================================================================

///|
/// Apply aspect ratio to calculate width from height.
/// Returns width if aspect_ratio is defined, otherwise returns None.
pub fn apply_aspect_ratio_width(
  height : Double,
  aspect_ratio : Double?,
) -> Double? {
  match aspect_ratio {
    Some(ar) if ar > 0.0 => Some(height * ar)
    _ => None
  }
}

///|
/// Apply aspect ratio to calculate height from width.
/// Returns height if aspect_ratio is defined, otherwise returns None.
pub fn apply_aspect_ratio_height(
  width : Double,
  aspect_ratio : Double?,
) -> Double? {
  match aspect_ratio {
    Some(ar) if ar > 0.0 => Some(width / ar)
    _ => None
  }
}

///|
/// Resolve dimensions with aspect ratio.
/// Given known dimension (width or height), aspect_ratio, and min/max constraints,
/// returns the final (width, height) pair.
///
/// - If width is known, height = width / aspect_ratio
/// - If height is known, width = height * aspect_ratio
/// - If both are known, aspect_ratio overrides the height
/// - Min/max constraints are applied after aspect ratio calculation
pub fn resolve_dimensions_with_aspect_ratio(
  width : Double?, // Known width (or None)
  height : Double?, // Known height (or None)
  aspect_ratio : Double?, // aspect_ratio = width / height
  min_width : Double, // 0.0 if no constraint
  max_width : Double, // Infinity if no constraint
  min_height : Double, // 0.0 if no constraint
  max_height : Double, // Infinity if no constraint
) -> (Double?, Double?) {
  match aspect_ratio {
    None => (width, height)
    Some(ar) if ar <= 0.0 => (width, height)
    Some(ar) =>
      match (width, height) {
        (Some(w), Some(_)) => {
          // Both known: aspect ratio overrides height
          let h = w / ar
          let h = clamp(h, min_height, max_height)
          (Some(w), Some(h))
        }
        (Some(w), None) => {
          // Width known: calculate height
          let h = w / ar
          let h = clamp(h, min_height, max_height)
          (Some(w), Some(h))
        }
        (None, Some(h)) => {
          // Height known: calculate width
          let w = h * ar
          let w = clamp(w, min_width, max_width)
          (Some(w), Some(h))
        }
        (None, None) => (None, None)
      }
  }
}

///|
/// Clamp a value between min and max
/// CSS spec: min takes precedence over max when they conflict
/// So apply max first (value cannot exceed max), then min (value cannot go below min)
pub fn clamp(value : Double, min_val : Double, max_val : Double) -> Double {
  // First apply max constraint
  let clamped = if value > max_val { max_val } else { value }
  // Then apply min constraint (min wins if min > max)
  if clamped < min_val {
    min_val
  } else {
    clamped
  }
}

// =============================================================================
// Clip Rect (for legacy clip property)
// =============================================================================

///|
/// CSS clip property value
/// clip: rect(top, right, bottom, left) or auto
/// Note: This is a deprecated property, but still widely used for accessibility
pub(all) enum ClipRect {
  /// clip: auto (no clipping)
  Auto
  /// clip: rect(top, right, bottom, left)
  /// Values are offsets from the element's edges
  Rect(top~ : Double, right~ : Double, bottom~ : Double, left~ : Double)
} derive(Eq)

///|
pub impl Show for ClipRect with output(self, logger) {
  match self {
    Auto => logger.write_string("auto")
    Rect(top~, right~, bottom~, left~) => {
      logger.write_string("rect(")
      top.output(logger)
      logger.write_string(", ")
      right.output(logger)
      logger.write_string(", ")
      bottom.output(logger)
      logger.write_string(", ")
      left.output(logger)
      logger.write_string(")")
    }
  }
}

///|
pub fn ClipRect::default() -> ClipRect {
  Auto
}
