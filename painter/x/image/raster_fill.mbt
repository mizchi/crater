///|
/// Generic clipped fill helpers for raster output.

///|
/// Fill a rect clipped to the given clip rectangle
fn fill_rect_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
) -> Unit {
  match clip {
    None => fill_rect_with_types_color(fb, palette, x, y, w, h, color, opacity)
    Some(c) => {
      let cx1 = @cmp.maximum(x, c.x)
      let cy1 = @cmp.maximum(y, c.y)
      let cx2 = @cmp.minimum(x + w, c.x + c.w)
      let cy2 = @cmp.minimum(y + h, c.y + c.h)
      if cx2 > cx1 && cy2 > cy1 {
        fill_rect_with_types_color(
          fb,
          palette,
          cx1,
          cy1,
          cx2 - cx1,
          cy2 - cy1,
          color,
          opacity,
        )
      }
    }
  }
}
