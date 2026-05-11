///|
/// Text-specific raster layout helpers.

///|
fn draw_text_decoration_line(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
) -> Unit {
  if y < 0 || y >= fb.height {
    return
  }
  for px = x; px < x + w && px < fb.width; px = px + 1 {
    if px >= 0 && pixel_in_clip(clip, px, y) {
      blend_types_color_over_pixel(fb, palette, px, y, color, opacity)
    }
  }
}

///|
fn resolve_text_render_box(
  node : @paint_model.PaintNode,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> (Int, Int, Int) {
  if node.tag == "input" {
    let inset = @cmp.maximum(2, (node.paint.font_size * 0.75).round().to_int())
    let vertical_offset = @cmp.maximum(
      0,
      ((h.to_double() - node.paint.font_size) / 2.0).round().to_int(),
    )
    (x + inset, y + vertical_offset, @cmp.maximum(0, w - inset * 2))
  } else {
    (x, y, w)
  }
}

///|
fn resolve_glyph_text_wrap_width(
  w : Int,
  h : Int,
  font_size : Double,
  text : String,
) -> Int {
  if h.to_double() <= font_size * 1.3 && text.length() <= 72 {
    0
  } else {
    w
  }
}
