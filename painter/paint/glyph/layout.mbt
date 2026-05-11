///|
/// Text layout helpers for glyph-based rendering.

///|
let text_wrap_tolerance : Double = 10.0

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
