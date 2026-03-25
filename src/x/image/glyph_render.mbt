///|
/// Glyph rendering for text using SVG path-based fonts.
/// Replaces bitmap font rendering when a GlyphProvider is configured.

///|
/// Provides glyph outlines and advance widths for text rendering.
pub(all) struct GlyphProvider {
  /// Get SVG path commands for a glyph. Args: (codepoint, font_size, is_bold).
  /// Returns (commands, advance_width).
  get_glyph : (Int, Double, Bool) -> (Array[@svg.PathCommand], Double)
  /// Get kerning adjustment between two codepoints. Args: (cp1, cp2, font_size, is_bold).
  get_kern : (Int, Int, Double, Bool) -> Double
  /// Font ascent in pixels at font_size=1. Multiply by actual font_size.
  ascent_ratio : Double // ascent / units_per_em (e.g. 1854/2048 ≈ 0.905)
}

///|
let glyph_provider_override : Ref[GlyphProvider?] = { val: None }

///|
pub fn set_glyph_provider(provider : GlyphProvider) -> Unit {
  glyph_provider_override.val = Some(provider)
}

///|
pub fn clear_glyph_provider() -> Unit {
  glyph_provider_override.val = None
}

///|
/// Draw text using the glyph provider (SVG path rendering).
/// Handles word-wrapping within max_width and baseline positioning.
/// Returns the total height used.
fn draw_text_with_glyphs(
  fb : Framebuffer,
  palette : DynamicPalette,
  provider : GlyphProvider,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  color : @svg.Color,
  font_size : Double,
  line_height : Double,
  is_bold : Bool,
) -> Int {
  let setter : @svg.PixelSetter = {
    set: fn(px, py, c) {
      if px >= 0 && px < fb.width && py >= 0 && py < fb.height {
        let sixel_color = { r: c.r, g: c.g, b: c.b }
        let idx = palette.get_or_add(sixel_color)
        fb.set_pixel(px, py, idx)
      }
    },
  }
  let effective_line_height = if line_height > 0.0 {
    line_height
  } else {
    font_size
  }
  // Baseline offset: glyphs have Y=0 at baseline, negative Y for ascenders
  let baseline_offset = provider.ascent_ratio * font_size
  let max_x_limit = if max_width > 0 {
    (x + max_width).to_double()
  } else {
    fb.width.to_double()
  }
  // Word-wrap using Regular font metrics (matching layout engine),
  // then render glyphs with the actual weight (bold or regular).
  let words = split_text_into_words(text)
  let mut cur_x = x.to_double()
  let mut cur_y = y.to_double()
  let mut max_y_seen = y.to_double() + effective_line_height
  // Use regular (non-bold) metrics for wrapping to match layout engine
  let space_advance_layout = get_advance(
    provider,
    ' '.to_int(),
    font_size,
    false,
  )
  for i, word in words {
    if word == "\n" {
      cur_x = x.to_double()
      cur_y = cur_y + effective_line_height
      max_y_seen = cur_y + effective_line_height
      continue
    }
    // Measure word with Regular font (matching layout)
    let word_width = measure_word_width(provider, word, font_size, false)
    // Wrap if needed
    if max_width > 0 &&
      cur_x + word_width > max_x_limit &&
      cur_x > x.to_double() + 0.01 {
      cur_x = x.to_double()
      cur_y = cur_y + effective_line_height
      max_y_seen = cur_y + effective_line_height
    }
    // Space before word (except at line start)
    if i > 0 && word != "\n" && cur_x > x.to_double() + 0.01 {
      cur_x = cur_x + space_advance_layout
    }
    // Render each character with actual weight and kerning
    let mut prev_cp = 0
    for c in word {
      let cp = c.to_int()
      // Apply kerning between consecutive characters
      if prev_cp != 0 {
        cur_x = cur_x + (provider.get_kern)(prev_cp, cp, font_size, is_bold)
      }
      let (commands, advance) = (provider.get_glyph)(cp, font_size, is_bold)
      if commands.length() > 0 {
        let translated = translate_path_commands(
          commands,
          cur_x,
          cur_y + baseline_offset,
        )
        @svg.raster_path(translated, Some(color), None, 0.0, setter)
      }
      cur_x = cur_x + advance
      prev_cp = cp
    }
  }
  (max_y_seen - y.to_double()).to_int()
}

///|
fn get_advance(
  provider : GlyphProvider,
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
) -> Double {
  let (_, advance) = (provider.get_glyph)(codepoint, font_size, is_bold)
  advance
}

///|
fn measure_word_width(
  provider : GlyphProvider,
  word : String,
  font_size : Double,
  is_bold : Bool,
) -> Double {
  let mut w = 0.0
  for c in word {
    w = w + get_advance(provider, c.to_int(), font_size, is_bold)
  }
  w
}

///|
/// Split text into words (by whitespace). Preserves newlines as "\n" tokens.
fn split_text_into_words(text : String) -> Array[String] {
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
/// Translate path commands by (dx, dy) offset.
fn translate_path_commands(
  commands : Array[@svg.PathCommand],
  dx : Double,
  dy : Double,
) -> Array[@svg.PathCommand] {
  commands.map(fn(cmd) {
    match cmd {
      MoveTo(x, y) => @svg.PathCommand::MoveTo(x + dx, y + dy)
      LineTo(x, y) => @svg.PathCommand::LineTo(x + dx, y + dy)
      HorizontalLineTo(x) => @svg.PathCommand::HorizontalLineTo(x + dx)
      VerticalLineTo(y) => @svg.PathCommand::VerticalLineTo(y + dy)
      CurveTo(x1, y1, x2, y2, x, y) =>
        @svg.PathCommand::CurveTo(
          x1 + dx,
          y1 + dy,
          x2 + dx,
          y2 + dy,
          x + dx,
          y + dy,
        )
      SmoothCurveTo(x2, y2, x, y) =>
        @svg.PathCommand::SmoothCurveTo(x2 + dx, y2 + dy, x + dx, y + dy)
      QuadraticCurveTo(x1, y1, x, y) =>
        @svg.PathCommand::QuadraticCurveTo(x1 + dx, y1 + dy, x + dx, y + dy)
      SmoothQuadraticCurveTo(x, y) =>
        @svg.PathCommand::SmoothQuadraticCurveTo(x + dx, y + dy)
      ArcTo(rx, ry, rot, large, sweep, x, y) =>
        @svg.PathCommand::ArcTo(rx, ry, rot, large, sweep, x + dx, y + dy)
      ClosePath => @svg.PathCommand::ClosePath
      _ => cmd
    }
  })
}
