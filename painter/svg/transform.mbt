///|
/// SVG Transform Operations
/// Optimized 2D affine transformation matrix operations

///|
/// Identity transform (no transformation)
pub fn Transform::identity() -> Transform {
  transform_from_msvg(@msvg.Transform::identity())
}

///|
/// Check if this is an identity transform (optimization)
pub fn Transform::is_identity(self : Transform) -> Bool {
  self.to_msvg().is_identity()
}

///|
/// Create a translation transform
pub fn Transform::translate(tx : Double, ty : Double) -> Transform {
  transform_from_msvg(@msvg.Transform::translate(tx, ty))
}

///|
/// Create a scaling transform
pub fn Transform::scale(sx : Double, sy : Double) -> Transform {
  transform_from_msvg(@msvg.Transform::scale(sx, sy))
}

///|
/// Create a uniform scaling transform
pub fn Transform::scale_uniform(s : Double) -> Transform {
  transform_from_msvg(@msvg.Transform::scale_uniform(s))
}

///|
/// Create a rotation transform (angle in radians)
pub fn Transform::rotate(angle : Double) -> Transform {
  transform_from_msvg(@msvg.Transform::rotate(angle))
}

///|
/// Create a rotation transform around a point (angle in radians)
pub fn Transform::rotate_around(
  angle : Double,
  cx : Double,
  cy : Double,
) -> Transform {
  transform_from_msvg(@msvg.Transform::rotate_around(angle, cx, cy))
}

///|
/// Create a skewX transform (angle in radians)
pub fn Transform::skew_x(angle : Double) -> Transform {
  transform_from_msvg(@msvg.Transform::skew_x(angle))
}

///|
/// Create a skewY transform (angle in radians)
pub fn Transform::skew_y(angle : Double) -> Transform {
  transform_from_msvg(@msvg.Transform::skew_y(angle))
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
  transform_from_msvg(@msvg.Transform::matrix(a, b, c, d, e, f))
}

///|
/// Multiply two transforms (self * other)
/// Result: first apply `other`, then apply `self`
pub fn Transform::multiply(self : Transform, other : Transform) -> Transform {
  transform_from_msvg(self.to_msvg().multiply(other.to_msvg()))
}

///|
/// Apply transform to a point
pub fn Transform::apply(
  self : Transform,
  x : Double,
  y : Double,
) -> (Double, Double) {
  self.to_msvg().apply(x, y)
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
  self.to_msvg().determinant()
}

///|
/// Check if the transform is invertible
pub fn Transform::is_invertible(self : Transform) -> Bool {
  self.to_msvg().is_invertible()
}

///|
/// Compute the inverse transform
/// Returns identity if not invertible
pub fn Transform::inverse(self : Transform) -> Transform {
  transform_from_msvg(self.to_msvg().inverse())
}

///|
/// Get the translation component
pub fn Transform::get_translate(self : Transform) -> (Double, Double) {
  self.to_msvg().get_translate()
}

///|
/// Get the scale factors (approximate, assumes no rotation)
pub fn Transform::get_scale(self : Transform) -> (Double, Double) {
  self.to_msvg().get_scale()
}

///|
/// Get the rotation angle in radians (approximate, assumes uniform scale)
pub fn Transform::get_rotation(self : Transform) -> Double {
  self.to_msvg().get_rotation()
}

///|
/// Transform a bounding box (returns axis-aligned bounding box of transformed corners)
pub fn Transform::apply_bbox(
  self : Transform,
  bbox : BoundingBox,
) -> BoundingBox {
  let transformed = self
    .to_msvg()
    .apply_bbox(@msvg.BoundingBox::{
      min_x: bbox.min_x,
      min_y: bbox.min_y,
      max_x: bbox.max_x,
      max_y: bbox.max_y,
    })
  {
    min_x: transformed.min_x,
    min_y: transformed.min_y,
    max_x: transformed.max_x,
    max_y: transformed.max_y,
  }
}

///|
/// Convert degrees to radians
pub fn degrees_to_radians(degrees : Double) -> Double {
  @msvg.degrees_to_radians(degrees)
}

///|
/// Convert radians to degrees
pub fn radians_to_degrees(radians : Double) -> Double {
  @msvg.radians_to_degrees(radians)
}

///|
fn Transform::to_msvg(self : Transform) -> @msvg.Transform {
  @msvg.Transform::{
    a: self.a,
    b: self.b,
    c: self.c,
    d: self.d,
    e: self.e,
    f: self.f,
  }
}
