///|
/// Clip rectangle for overflow clipping.
/// None means no clipping (full framebuffer).
pub(all) struct ClipRect {
  x : Int
  y : Int
  w : Int
  h : Int
}

///|
/// Intersect two clip rectangles. Returns None if they don't overlap.
fn clip_intersect(a : ClipRect, b : ClipRect) -> ClipRect? {
  let x1 = @cmp.maximum(a.x, b.x)
  let y1 = @cmp.maximum(a.y, b.y)
  let x2 = @cmp.minimum(a.x + a.w, b.x + b.w)
  let y2 = @cmp.minimum(a.y + a.h, b.y + b.h)
  if x2 > x1 && y2 > y1 {
    Some({ x: x1, y: y1, w: x2 - x1, h: y2 - y1 })
  } else {
    None
  }
}

///|
/// Check if a pixel is inside the clip rect
fn pixel_in_clip(clip : ClipRect?, px : Int, py : Int) -> Bool {
  match clip {
    None => true
    Some(c) => px >= c.x && px < c.x + c.w && py >= c.y && py < c.y + c.h
  }
}
