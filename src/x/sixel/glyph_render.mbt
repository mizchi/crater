///|
/// Glyph rendering for text using SVG path-based fonts.
/// Replaces bitmap font rendering when a GlyphProvider is configured.

///|
/// Provides glyph outlines and advance widths for text rendering.
/// Returns SVG path commands for a codepoint at a given font size.
pub(all) struct GlyphProvider {
  /// Get SVG path commands for a glyph. Returns (commands, advance_width).
  get_glyph : (Int, Double) -> (Array[@svg.PathCommand], Double)
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
  let mut cur_x = x.to_double()
  let mut cur_y = y.to_double()
  let mut max_y = y.to_double() + effective_line_height
  let max_x = if max_width > 0 {
    (x + max_width).to_double()
  } else {
    fb.width.to_double()
  }
  for c in text {
    if c == '\n' {
      cur_x = x.to_double()
      cur_y = cur_y + effective_line_height
      max_y = cur_y + effective_line_height
      continue
    }
    if c == '\r' {
      continue
    }
    let cp = c.to_int()
    let (commands, advance) = (provider.get_glyph)(cp, font_size)
    // Do not wrap — text wrapping is handled by the layout engine.
    // Paint layer just renders glyphs at their computed positions.
    // Render glyph if we have commands
    if commands.length() > 0 {
      // Translate commands to current position
      let translated = translate_path_commands(
        commands, cur_x, cur_y,
      )
      @svg.raster_path(translated, Some(color), None, 0.0, setter)
    }
    cur_x = cur_x + advance
  }
  (max_y - y.to_double()).to_int()
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
          x1 + dx, y1 + dy, x2 + dx, y2 + dy, x + dx, y + dy,
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
      // Relative commands don't need translation
      _ => cmd
    }
  })
}
