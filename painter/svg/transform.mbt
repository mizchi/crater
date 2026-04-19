///|
/// SVG Transform Operations
/// Optimized 2D affine transformation matrix operations

///|
/// Identity transform (no transformation)
pub fn Transform::identity() -> Transform {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
/// Check if this is an identity transform (optimization)
pub fn Transform::is_identity(self : Transform) -> Bool {
  self.a == 1.0 &&
  self.b == 0.0 &&
  self.c == 0.0 &&
  self.d == 1.0 &&
  self.e == 0.0 &&
  self.f == 0.0
}

///|
/// Create a translation transform
pub fn Transform::translate(tx : Double, ty : Double) -> Transform {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: tx, f: ty }
}

///|
/// Create a scaling transform
pub fn Transform::scale(sx : Double, sy : Double) -> Transform {
  { a: sx, b: 0.0, c: 0.0, d: sy, e: 0.0, f: 0.0 }
}

///|
/// Create a uniform scaling transform
pub fn Transform::scale_uniform(s : Double) -> Transform {
  Transform::scale(s, s)
}

///|
/// Create a rotation transform (angle in radians)
pub fn Transform::rotate(angle : Double) -> Transform {
  let cos_a = @math.cos(angle)
  let sin_a = @math.sin(angle)
  { a: cos_a, b: sin_a, c: -sin_a, d: cos_a, e: 0.0, f: 0.0 }
}

///|
/// Create a rotation transform around a point (angle in radians)
pub fn Transform::rotate_around(
  angle : Double,
  cx : Double,
  cy : Double,
) -> Transform {
  // Translate to origin, rotate, translate back
  let t1 = Transform::translate(-cx, -cy)
  let r = Transform::rotate(angle)
  let t2 = Transform::translate(cx, cy)
  t2.multiply(r.multiply(t1))
}

///|
/// Create a skewX transform (angle in radians)
pub fn Transform::skew_x(angle : Double) -> Transform {
  { a: 1.0, b: 0.0, c: @math.tan(angle), d: 1.0, e: 0.0, f: 0.0 }
}

///|
/// Create a skewY transform (angle in radians)
pub fn Transform::skew_y(angle : Double) -> Transform {
  { a: 1.0, b: @math.tan(angle), c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
/// Create a transform from a full matrix specification
pub fn Transform::matrix(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> Transform {
  { a, b, c, d, e, f }
}

///|
/// Multiply two transforms (self * other)
/// Result: first apply `other`, then apply `self`
pub fn Transform::multiply(self : Transform, other : Transform) -> Transform {
  // Matrix multiplication:
  // | a1 c1 e1 |   | a2 c2 e2 |
  // | b1 d1 f1 | * | b2 d2 f2 |
  // | 0  0  1  |   | 0  0  1  |
  {
    a: self.a * other.a + self.c * other.b,
    b: self.b * other.a + self.d * other.b,
    c: self.a * other.c + self.c * other.d,
    d: self.b * other.c + self.d * other.d,
    e: self.a * other.e + self.c * other.f + self.e,
    f: self.b * other.e + self.d * other.f + self.f,
  }
}

///|
/// Apply transform to a point
pub fn Transform::apply(
  self : Transform,
  x : Double,
  y : Double,
) -> (Double, Double) {
  let new_x = self.a * x + self.c * y + self.e
  let new_y = self.b * x + self.d * y + self.f
  (new_x, new_y)
}

///|
/// Apply transform to a point (struct version)
pub fn Transform::apply_point(
  self : Transform,
  point : (Double, Double),
) -> (Double, Double) {
  self.apply(point.0, point.1)
}

///|
/// Compute the determinant of the transform
pub fn Transform::determinant(self : Transform) -> Double {
  self.a * self.d - self.b * self.c
}

///|
/// Check if the transform is invertible
pub fn Transform::is_invertible(self : Transform) -> Bool {
  let det = self.determinant()
  det != 0.0
}

///|
/// Compute the inverse transform
/// Returns identity if not invertible
pub fn Transform::inverse(self : Transform) -> Transform {
  let det = self.determinant()
  if det == 0.0 {
    return Transform::identity()
  }
  let inv_det = 1.0 / det
  {
    a: self.d * inv_det,
    b: -self.b * inv_det,
    c: -self.c * inv_det,
    d: self.a * inv_det,
    e: (self.c * self.f - self.d * self.e) * inv_det,
    f: (self.b * self.e - self.a * self.f) * inv_det,
  }
}

///|
/// Get the translation component
pub fn Transform::get_translate(self : Transform) -> (Double, Double) {
  (self.e, self.f)
}

///|
/// Get the scale factors (approximate, assumes no rotation)
pub fn Transform::get_scale(self : Transform) -> (Double, Double) {
  let sx = (self.a * self.a + self.b * self.b).sqrt()
  let sy = (self.c * self.c + self.d * self.d).sqrt()
  (sx, sy)
}

///|
/// Get the rotation angle in radians (approximate, assumes uniform scale)
pub fn Transform::get_rotation(self : Transform) -> Double {
  @math.atan2(self.b, self.a)
}

///|
/// Transform a bounding box (returns axis-aligned bounding box of transformed corners)
pub fn Transform::apply_bbox(
  self : Transform,
  bbox : BoundingBox,
) -> BoundingBox {
  if bbox.is_empty() {
    return bbox
  }
  // Transform all 4 corners
  let (x1, y1) = self.apply(bbox.min_x, bbox.min_y)
  let (x2, y2) = self.apply(bbox.max_x, bbox.min_y)
  let (x3, y3) = self.apply(bbox.max_x, bbox.max_y)
  let (x4, y4) = self.apply(bbox.min_x, bbox.max_y)
  // Find axis-aligned bounding box
  let min_x = min(min(x1, x2), min(x3, x4))
  let max_x = max(max(x1, x2), max(x3, x4))
  let min_y = min(min(y1, y2), min(y3, y4))
  let max_y = max(max(y1, y2), max(y3, y4))
  { min_x, min_y, max_x, max_y }
}

///|
/// Convert degrees to radians
pub fn degrees_to_radians(degrees : Double) -> Double {
  degrees * 3.14159265358979323846 / 180.0
}

///|
/// Convert radians to degrees
pub fn radians_to_degrees(radians : Double) -> Double {
  radians * 180.0 / 3.14159265358979323846
}
