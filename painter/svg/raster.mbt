///|
/// SVG Rasterizer adapter.
/// The raster algorithms live in mizchi/svg; this package keeps crater's
/// existing public types and forwards through the interop layer.

///|
/// Pixel setter callback type
/// (x, y, color) -> Unit
pub(all) struct PixelSetter {
  set : (Int, Int, Color) -> Unit
}

///|
/// Draw a single pixel
pub fn PixelSetter::pixel(
  self : PixelSetter,
  x : Int,
  y : Int,
  color : Color,
) -> Unit {
  (self.set)(x, y, color)
}

///|
/// Create a clipped pixel setter that only draws within the clip rect
pub fn PixelSetter::with_clip(
  self : PixelSetter,
  clip : ClipRect,
) -> PixelSetter {
  pixel_setter_from_msvg(
    pixel_setter_to_msvg(self).with_clip(clip_rect_to_msvg(clip)),
  )
}

///|
/// Create a clipped pixel setter with offset (for camera translation)
pub fn PixelSetter::with_clip_and_offset(
  self : PixelSetter,
  clip : ClipRect,
  offset_x : Int,
  offset_y : Int,
) -> PixelSetter {
  pixel_setter_from_msvg(
    pixel_setter_to_msvg(self).with_clip_and_offset(
      clip_rect_to_msvg(clip),
      offset_x,
      offset_y,
    ),
  )
}

///|
pub fn raster_line(
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_line(
    x0,
    y0,
    x1,
    y1,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_line_dashed(
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  color : Color,
  dasharray : Array[Double],
  dashoffset : Double,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_line_dashed(
    x0,
    y0,
    x1,
    y1,
    color.to_msvg(),
    dasharray,
    dashoffset,
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_polyline_dashed(
  points : Array[(Int, Int)],
  color : Color,
  dasharray : Array[Double],
  dashoffset : Double,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_polyline_dashed(
    points,
    color.to_msvg(),
    dasharray,
    dashoffset,
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_rect_stroke(
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_rect_stroke(
    x,
    y,
    w,
    h,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_rect_fill(
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_rect_fill(
    x,
    y,
    w,
    h,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_rect_gradient(
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  grad : LinearGradient,
  opacity : Double,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_rect_gradient(
    x,
    y,
    w,
    h,
    linear_gradient_to_msvg(grad),
    opacity,
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_rect_radial_gradient(
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  grad : RadialGradient,
  opacity : Double,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_rect_radial_gradient(
    x,
    y,
    w,
    h,
    radial_gradient_to_msvg(grad),
    opacity,
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_circle_radial_gradient(
  cx : Int,
  cy : Int,
  r : Int,
  grad : RadialGradient,
  opacity : Double,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_circle_radial_gradient(
    cx,
    cy,
    r,
    radial_gradient_to_msvg(grad),
    opacity,
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_ellipse_radial_gradient(
  cx : Int,
  cy : Int,
  rx : Int,
  ry : Int,
  grad : RadialGradient,
  opacity : Double,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_ellipse_radial_gradient(
    cx,
    cy,
    rx,
    ry,
    radial_gradient_to_msvg(grad),
    opacity,
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_rounded_rect_stroke(
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  rx : Int,
  ry : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_rounded_rect_stroke(
    x,
    y,
    w,
    h,
    rx,
    ry,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_circle_stroke(
  cx : Int,
  cy : Int,
  r : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_circle_stroke(
    cx,
    cy,
    r,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_circle_fill(
  cx : Int,
  cy : Int,
  r : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_circle_fill(
    cx,
    cy,
    r,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_ellipse_stroke(
  cx : Int,
  cy : Int,
  rx : Int,
  ry : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_ellipse_stroke(
    cx,
    cy,
    rx,
    ry,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_ellipse_fill(
  cx : Int,
  cy : Int,
  rx : Int,
  ry : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_ellipse_fill(
    cx,
    cy,
    rx,
    ry,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_polygon_fill(
  points : Array[(Int, Int)],
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_polygon_fill(
    points,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_polygon_stroke(
  points : Array[(Int, Int)],
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_polygon_stroke(
    points,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_polyline(
  points : Array[(Int, Int)],
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_polyline(
    points,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_thick_line(
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  thickness : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_thick_line(
    x0,
    y0,
    x1,
    y1,
    thickness,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}

///|
pub fn raster_text(
  x : Int,
  y : Int,
  text : String,
  size : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  @msvg.raster_text(
    x,
    y,
    text,
    size,
    color.to_msvg(),
    pixel_setter_to_msvg(setter),
  )
}
