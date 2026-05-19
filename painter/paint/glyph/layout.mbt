///|
/// Text layout helpers for glyph-based rendering.

///|
let text_wrap_tolerance : Double = 10.0

///|
pub(all) struct GlyphPlacement {
  bitmap : GlyphBitmap
  x : Double
  y : Double
  line_height : Double
}

///|
pub fn resolve_text_wrap_tolerance(
  max_width : Int,
  font_size : Double,
) -> Double {
  if max_width <= 0 {
    return text_wrap_tolerance
  }
  let width_tolerance = max_width.to_double() * 0.2
  let font_tolerance = if font_size > 0.0 {
    font_size * 1.5
  } else {
    text_wrap_tolerance
  }
  let capped = if width_tolerance < font_tolerance {
    width_tolerance
  } else {
    font_tolerance
  }
  if capped > text_wrap_tolerance {
    capped
  } else {
    text_wrap_tolerance
  }
}

///|
pub fn measure_word_width(
  provider : GlyphProvider,
  word : String,
  font_size : Double,
  is_bold : Bool,
  font_family? : String = "",
  letter_spacing? : Double = 0.0,
  word_spacing? : Double = 0.0,
  font_weight? : Double = 400.0,
) -> Double {
  let effective_font_weight = resolve_effective_font_weight(
    is_bold, font_weight,
  )
  let effective_is_bold = is_bold || is_bold_font_weight(effective_font_weight)
  let mut w = 0.0
  let mut prev_cp = 0
  for c in word {
    let cp = c.to_int()
    if prev_cp != 0 {
      w = w + letter_spacing
      let kern = kern_from_provider(
        provider, prev_cp, cp, font_size, effective_is_bold, font_family, effective_font_weight,
      )
      w = w + kern
    }
    w = w +
      get_advance(
        provider,
        cp,
        font_size,
        effective_is_bold,
        font_family~,
        font_weight=effective_font_weight,
      )
    if cp == ' '.to_int() {
      w = w + word_spacing
    }
    prev_cp = cp
  }
  w
}

///|
pub fn collapsed_space_advance(
  provider : GlyphProvider,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
  letter_spacing : Double,
  word_spacing : Double,
  font_weight : Double,
) -> Double {
  get_advance(
    provider,
    ' '.to_int(),
    font_size,
    is_bold,
    font_family~,
    font_weight~,
  ) +
  word_spacing +
  letter_spacing * 2.0
}

///|
/// Split text into words (by whitespace). Preserves newlines as "\n" tokens.
pub fn split_text_into_words(text : String) -> Array[String] {
  let words : Array[String] = []
  let buf = StringBuilder::new()
  for c in text {
    if c == '\n' {
      if buf.to_string().length() > 0 {
        words.push(buf.to_string())
        buf.reset()
      }
      words.push("\n")
    } else if c == ' ' || c == '\t' || c == '\r' {
      if buf.to_string().length() > 0 {
        words.push(buf.to_string())
        buf.reset()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    words.push(buf.to_string())
  }
  words
}

///|
pub fn layout_glyph_bitmaps(
  provider : GlyphProvider,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  font_size : Double,
  line_height : Double,
  is_bold : Bool,
  font_family? : String = "",
  letter_spacing? : Double = 0.0,
  word_spacing? : Double = 0.0,
  font_weight? : Double = 400.0,
) -> (Array[GlyphPlacement], Int) {
  let effective_font_weight = resolve_effective_font_weight(
    is_bold, font_weight,
  )
  let effective_is_bold = is_bold || is_bold_font_weight(effective_font_weight)
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
  let wrap_tolerance = resolve_text_wrap_tolerance(max_width, font_size)
  let max_x_limit = if max_width > 0 {
    (x + max_width).to_double() + wrap_tolerance
  } else {
    0.0
  }
  let words = split_text_into_words(text)
  let placements : Array[GlyphPlacement] = []
  let mut cur_x = x.to_double()
  let mut cur_y = y.to_double()
  let mut max_y_seen = y.to_double() + effective_line_height
  let space_advance_layout = collapsed_space_advance(
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
    let word_width = measure_word_width(
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
    let mut prev_cp = 0
    for c in word {
      let cp = c.to_int()
      let spacing = if prev_cp != 0 { letter_spacing } else { 0.0 }
      let kern = if prev_cp != 0 {
        kern_from_provider(
          provider, prev_cp, cp, font_size, effective_is_bold, font_family, effective_font_weight,
        )
      } else {
        0.0
      }
      let next_draw_x = cur_x + spacing + kern
      let bitmap = cached_glyph_bitmap(
        provider,
        cp,
        font_size,
        effective_is_bold,
        font_family,
        effective_font_weight,
        baseline_offset,
        subpixel_x=glyph_subpixel_offset(next_draw_x),
        subpixel_y=glyph_subpixel_offset(cur_y),
      )
      let mut draw_x = next_draw_x
      if max_width > 0 &&
        draw_x + bitmap.advance > hard_wrap_limit &&
        cur_x > x.to_double() + 0.01 {
        cur_x = x.to_double()
        cur_y = cur_y + effective_line_height
        max_y_seen = cur_y + effective_line_height
        draw_x = cur_x
        prev_cp = 0
        let wrapped_bitmap = cached_glyph_bitmap(
          provider,
          cp,
          font_size,
          effective_is_bold,
          font_family,
          effective_font_weight,
          baseline_offset,
          subpixel_x=glyph_subpixel_offset(draw_x),
          subpixel_y=glyph_subpixel_offset(cur_y),
        )
        placements.push({
          bitmap: wrapped_bitmap,
          x: draw_x,
          y: cur_y,
          line_height: effective_line_height,
        })
        cur_x = draw_x + wrapped_bitmap.advance
        prev_cp = cp
        continue
      }
      placements.push({
        bitmap,
        x: draw_x,
        y: cur_y,
        line_height: effective_line_height,
      })
      cur_x = draw_x + bitmap.advance
      prev_cp = cp
    }
  }
  (placements, (max_y_seen - y.to_double()).to_int())
}
