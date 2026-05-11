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
  let effective_font_weight = @glyph.resolve_effective_font_weight(
    is_bold, font_weight,
  )
  let effective_is_bold = is_bold ||
    @glyph.is_bold_font_weight(effective_font_weight)
  let text_opacity = clamp_opacity(opacity) * color.a.to_double() / 255.0
  let effective_line_height = if line_height > 0.0 {
    line_height
  } else {
    font_size
  }
  let baseline_offset = match provider.get_ascent_for_family {
    Some(get_ascent) if font_family.length() > 0 =>
      get_ascent(font_family) * font_size
    _ => provider.ascent_ratio * font_size
  }
  let wrap_tolerance = @glyph.resolve_text_wrap_tolerance(max_width, font_size)
  let max_x_limit = if max_width > 0 {
    (x + max_width).to_double() + wrap_tolerance
  } else {
    fb.width.to_double()
  }
  let words = @glyph.split_text_into_words(text)
  let mut cur_x = x.to_double()
  let mut cur_y = y.to_double()
  let mut max_y_seen = y.to_double() + effective_line_height
  let space_advance_layout = @glyph.collapsed_space_advance(
    provider, font_size, effective_is_bold, font_family, letter_spacing, word_spacing,
    effective_font_weight,
  )
  for i, word in words {
    if word == "\n" {
      cur_x = x.to_double()
      cur_y = cur_y + effective_line_height
      max_y_seen = cur_y + effective_line_height
      continue
    }
    let word_width = @glyph.measure_word_width(
      provider,
      word,
      font_size,
      effective_is_bold,
      font_family~,
      letter_spacing~,
      word_spacing~,
      font_weight=effective_font_weight,
    )
    let hard_wrap_limit = if max_width > 0 &&
      word_width > max_width.to_double() + wrap_tolerance {
      (x + max_width).to_double()
    } else {
      max_x_limit
    }
    let mut space_width = 0.0
    if i > 0 && word != "\n" && cur_x > x.to_double() + 0.01 {
      space_width = space_advance_layout
    }
    if max_width > 0 {
      let total_width = space_width + word_width
      if cur_x + total_width > max_x_limit && cur_x > x.to_double() + 0.01 {
        cur_x = x.to_double()
        cur_y = cur_y + effective_line_height
        max_y_seen = cur_y + effective_line_height
        space_width = 0.0
      }
    }
    cur_x = cur_x + space_width
    // Pre-compute palette index for this word's color (constant per word)
    let sixel_color = { r: color.r, g: color.g, b: color.b }
    let color_idx = palette.get_or_add(sixel_color)
    let mut prev_cp = 0
    for c in word {
      let cp = c.to_int()
      let bitmap = @glyph.cached_glyph_bitmap(
        provider, cp, font_size, effective_is_bold, font_family, effective_font_weight,
        baseline_offset,
      )
      let kern = if prev_cp != 0 {
        @glyph.kern_from_provider(
          provider, prev_cp, cp, font_size, effective_is_bold, font_family, effective_font_weight,
        )
      } else {
        0.0
      }
      let spacing = if prev_cp != 0 { letter_spacing } else { 0.0 }
      let mut draw_x = cur_x + spacing + kern
      if max_width > 0 &&
        draw_x + bitmap.advance > hard_wrap_limit &&
        cur_x > x.to_double() + 0.01 {
        cur_x = x.to_double()
        cur_y = cur_y + effective_line_height
        max_y_seen = cur_y + effective_line_height
        draw_x = cur_x
        prev_cp = 0
      }
      let line_top = cur_y.to_int()
      let line_bottom = (cur_y + effective_line_height).to_int()
      let in_clip_v = match clip {
        Some(cr) => line_bottom >= cr.y && line_top < cr.y + cr.h
        None => line_bottom >= 0 && line_top < fb.height
      }
      // Blit cached bitmap to framebuffer with antialiasing
      if in_clip_v && bitmap.width > 0 {
        blit_glyph_bitmap(
          fb, palette, bitmap, draw_x, cur_y, sixel_color, color_idx, text_opacity,
          clip,
        )
      }
      cur_x = draw_x + bitmap.advance
      prev_cp = cp
    }
  }
  (max_y_seen - y.to_double()).to_int()
}
