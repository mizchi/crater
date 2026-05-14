///|
/// Glyph rendering for text using SVG path-based fonts.
/// Replaces bitmap font rendering when a GlyphProvider is configured.

///|
/// Draw text using the glyph provider with clip rect support.
fn draw_text_with_glyphs_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  provider : @glyph.GlyphProvider,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  color : @svg.Color,
  font_size : Double,
  line_height : Double,
  is_bold : Bool,
  clip : ClipRect?,
  font_family? : String = "",
  opacity? : Double = 1.0,
  letter_spacing? : Double = 0.0,
  word_spacing? : Double = 0.0,
  font_weight? : Double = 400.0,
) -> Int {
  let text_opacity = clamp_opacity(opacity) * color.a.to_double() / 255.0
  let (placements, used_height) = @glyph.layout_glyph_bitmaps(
    provider,
    x,
    y,
    text,
    max_width,
    font_size,
    line_height,
    is_bold,
    font_family~,
    letter_spacing~,
    word_spacing~,
    font_weight~,
  )
  let sixel_color = { r: color.r, g: color.g, b: color.b }
  let color_idx = palette.get_or_add(sixel_color)
  for placement in placements {
    let line_top = placement.y.to_int()
    let line_bottom = (placement.y + placement.line_height).to_int()
    let in_clip_v = match clip {
      Some(cr) => line_bottom >= cr.y && line_top < cr.y + cr.h
      None => line_bottom >= 0 && line_top < fb.height
    }
    if in_clip_v && placement.bitmap.width > 0 {
      blit_glyph_bitmap(
        fb,
        palette,
        placement.bitmap,
        placement.x,
        placement.y,
        sixel_color,
        color_idx,
        text_opacity,
        clip,
      )
    }
  }
  used_height
}
