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
  BoundingBox::from_msvg(@msvg.BoundingBox::empty())
}

///|
pub fn BoundingBox::from_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> BoundingBox {
  BoundingBox::from_msvg(@msvg.BoundingBox::from_rect(x, y, w, h))
}

///|
pub fn BoundingBox::width(self : BoundingBox) -> Double {
  self.to_msvg().width()
}

///|
pub fn BoundingBox::height(self : BoundingBox) -> Double {
  self.to_msvg().height()
}

///|
pub fn BoundingBox::is_empty(self : BoundingBox) -> Bool {
  self.to_msvg().is_empty()
}

///|
pub fn BoundingBox::union(
  self : BoundingBox,
  other : BoundingBox,
) -> BoundingBox {
  BoundingBox::from_msvg(
    self.to_msvg().union(other.to_msvg()),
  )
}

///|
pub fn BoundingBox::expand_by_point(
  self : BoundingBox,
  x : Double,
  y : Double,
) -> BoundingBox {
  BoundingBox::from_msvg(self.to_msvg().expand_by_point(x, y))
}

///|
/// Check if two bounding boxes intersect
pub fn BoundingBox::intersects(self : BoundingBox, other : BoundingBox) -> Bool {
  self.to_msvg().intersects(other.to_msvg())
}

///|
/// Check if this bounding box contains a point
pub fn BoundingBox::contains_point(
  self : BoundingBox,
  x : Double,
  y : Double,
) -> Bool {
  self.to_msvg().contains_point(x, y)
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
  ClipRect::from_msvg(@msvg.ClipRect::new(x, y, width, height))
}

///|
pub fn ClipRect::from_size(width : Int, height : Int) -> ClipRect {
  ClipRect::from_msvg(@msvg.ClipRect::from_size(width, height))
}

///|
/// Check if a point is inside the clip rect
pub fn ClipRect::contains(self : ClipRect, x : Int, y : Int) -> Bool {
  self.to_msvg().contains(x, y)
}

///|
/// Convert to BoundingBox
pub fn ClipRect::to_bbox(self : ClipRect) -> BoundingBox {
  BoundingBox::from_msvg(self.to_msvg().to_bbox())
}

///|
fn BoundingBox::from_msvg(bbox : @msvg.BoundingBox) -> BoundingBox {
  { min_x: bbox.min_x, min_y: bbox.min_y, max_x: bbox.max_x, max_y: bbox.max_y }
}

///|
fn BoundingBox::to_msvg(self : BoundingBox) -> @msvg.BoundingBox {
  @msvg.BoundingBox::{
    min_x: self.min_x,
    min_y: self.min_y,
    max_x: self.max_x,
    max_y: self.max_y,
  }
}

///|
fn BoundingBox::from_msvg_option(
  bbox : @msvg.BoundingBox?,
) -> BoundingBox? {
  match bbox {
    Some(b) => Some(BoundingBox::from_msvg(b))
    None => None
  }
}

///|
fn ClipRect::from_msvg(clip : @msvg.ClipRect) -> ClipRect {
  { x: clip.x, y: clip.y, width: clip.width, height: clip.height }
}

///|
fn ClipRect::to_msvg(self : ClipRect) -> @msvg.ClipRect {
  @msvg.ClipRect::{
    x: self.x,
    y: self.y,
    width: self.width,
    height: self.height,
  }
}
