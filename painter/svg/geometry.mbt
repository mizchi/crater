///|
/// Bounding box for a shape
pub(all) struct BoundingBox {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
}

///|
pub fn BoundingBox::empty() -> BoundingBox {
  bounding_box_from_msvg(@msvg.BoundingBox::empty())
}

///|
pub fn BoundingBox::from_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> BoundingBox {
  bounding_box_from_msvg(@msvg.BoundingBox::from_rect(x, y, w, h))
}

///|
pub fn BoundingBox::width(self : BoundingBox) -> Double {
  bounding_box_to_msvg(self).width()
}

///|
pub fn BoundingBox::height(self : BoundingBox) -> Double {
  bounding_box_to_msvg(self).height()
}

///|
pub fn BoundingBox::is_empty(self : BoundingBox) -> Bool {
  bounding_box_to_msvg(self).is_empty()
}

///|
pub fn BoundingBox::union(
  self : BoundingBox,
  other : BoundingBox,
) -> BoundingBox {
  bounding_box_from_msvg(
    bounding_box_to_msvg(self).union(bounding_box_to_msvg(other)),
  )
}

///|
pub fn BoundingBox::expand_by_point(
  self : BoundingBox,
  x : Double,
  y : Double,
) -> BoundingBox {
  bounding_box_from_msvg(bounding_box_to_msvg(self).expand_by_point(x, y))
}

///|
/// Check if two bounding boxes intersect
pub fn BoundingBox::intersects(self : BoundingBox, other : BoundingBox) -> Bool {
  bounding_box_to_msvg(self).intersects(bounding_box_to_msvg(other))
}

///|
/// Check if this bounding box contains a point
pub fn BoundingBox::contains_point(
  self : BoundingBox,
  x : Double,
  y : Double,
) -> Bool {
  bounding_box_to_msvg(self).contains_point(x, y)
}

///|
/// Clipping rectangle for camera/viewport
pub(all) struct ClipRect {
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
pub fn ClipRect::new(x : Int, y : Int, width : Int, height : Int) -> ClipRect {
  clip_rect_from_msvg(@msvg.ClipRect::new(x, y, width, height))
}

///|
pub fn ClipRect::from_size(width : Int, height : Int) -> ClipRect {
  clip_rect_from_msvg(@msvg.ClipRect::from_size(width, height))
}

///|
/// Check if a point is inside the clip rect
pub fn ClipRect::contains(self : ClipRect, x : Int, y : Int) -> Bool {
  clip_rect_to_msvg(self).contains(x, y)
}

///|
/// Convert to BoundingBox
pub fn ClipRect::to_bbox(self : ClipRect) -> BoundingBox {
  bounding_box_from_msvg(clip_rect_to_msvg(self).to_bbox())
}
