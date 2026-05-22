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
  line_height : Double,
  text : String,
) -> Int {
  let single_line_height = if line_height > 0.0 {
    line_height
  } else {
    font_size * 1.2
  }
  let mut has_forced_break = false
  for c in text.iter() {
    if c == '\n' || c == '\r' {
      has_forced_break = true
      break
    }
  }
  if !has_forced_break &&
    h.to_double() <= single_line_height * 1.1 &&
    text.length() <= 72 {
    0
  } else {
    w
  }
}

///|
fn resolve_glyph_text_expected_line_count(
  h : Int,
  font_size : Double,
  line_height : Double,
) -> Int {
  let single_line_height = if line_height > 0.0 {
    line_height
  } else {
    font_size * 1.2
  }
  if h <= 0 || single_line_height <= 0.0 {
    return 0
  }
  let lines = (h.to_double() / single_line_height).round().to_int()
  if lines > 0 {
    lines
  } else {
    1
  }
}
