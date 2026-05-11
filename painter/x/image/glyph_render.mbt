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
  /// Weight-aware glyph provider. Args: (codepoint, font_size, font_weight).
  get_glyph_by_weight : ((Int, Double, Double) -> (
    Array[@svg.PathCommand],
    Double,
  ))?
  /// Weight-aware kerning. Args: (cp1, cp2, font_size, font_weight).
  get_kern_by_weight : ((Int, Int, Double, Double) -> Double)?
  /// Font ascent in pixels at font_size=1. Multiply by actual font_size.
  ascent_ratio : Double // ascent / units_per_em (e.g. 1854/2048 ≈ 0.905)
  /// Multi-font glyph provider. Args: (codepoint, font_size, is_bold, font_family).
  /// Returns (commands, advance_width) or None to fall back to get_glyph.
  get_glyph_for_family : ((Int, Double, Bool, String) -> (
    Array[@svg.PathCommand],
    Double,
  )?)?
  /// Multi-font kerning. Args: (cp1, cp2, font_size, is_bold, font_family).
  get_kern_for_family : ((Int, Int, Double, Bool, String) -> Double)?
  /// Weight-aware multi-font glyph provider.
  get_glyph_for_family_by_weight : ((Int, Double, Double, String) -> (
    Array[@svg.PathCommand],
    Double,
  )?)?
  /// Weight-aware multi-font kerning.
  get_kern_for_family_by_weight : ((Int, Int, Double, Double, String) -> Double)?
  /// Multi-font ascent ratio. Args: (font_family) -> ratio.
  get_ascent_for_family : ((String) -> Double)?
}

///|
let glyph_provider_override : Ref[GlyphProvider?] = { val: None }

///|
pub fn set_glyph_provider(provider : GlyphProvider) -> Unit {
  glyph_provider_override.val = Some(provider)
  clear_glyph_caches()
}

///|
pub fn clear_glyph_provider() -> Unit {
  glyph_provider_override.val = None
  clear_glyph_caches()
}

///|
pub fn glyph_provider_from_delegate(
  delegate : @font_provider.GlyphProvider,
) -> GlyphProvider {
  {
    get_glyph: fn(codepoint, font_size, is_bold) {
      let (commands, advance) = (delegate.get_glyph)(
        codepoint, font_size, is_bold,
      )
      (commands.map(@svg.path_command_from_msvg), advance)
    },
    get_kern: fn(cp1, cp2, font_size, is_bold) {
      (delegate.get_kern)(cp1, cp2, font_size, is_bold)
    },
    get_glyph_by_weight: match delegate.get_glyph_by_weight {
      Some(glyph_by_weight) =>
        Some(fn(codepoint, font_size, font_weight) {
          let (commands, advance) = glyph_by_weight(
            codepoint, font_size, font_weight,
          )
          (commands.map(@svg.path_command_from_msvg), advance)
        })
      None => None
    },
    get_kern_by_weight: match delegate.get_kern_by_weight {
      Some(kern_by_weight) =>
        Some(fn(cp1, cp2, font_size, font_weight) {
          kern_by_weight(cp1, cp2, font_size, font_weight)
        })
      None => None
    },
    ascent_ratio: delegate.ascent_ratio,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
}

///|
/// Create a GlyphProvider from a parsed TTFont.
/// This allows native text rendering without JS FFI.
pub fn glyph_provider_from_font(font : @font.TTFont) -> GlyphProvider {
  glyph_provider_from_delegate(@font_provider.glyph_provider_from_font(font))
}

///|
/// Parse font bytes and create a GlyphProvider.
/// Returns None if font parsing fails.
pub fn glyph_provider_from_bytes(data : Bytes) -> GlyphProvider? {
  match @font_provider.glyph_provider_from_bytes(data) {
    Some(provider) => Some(glyph_provider_from_delegate(provider))
    None => None
  }
}

///|
fn resolve_effective_font_weight(
  is_bold : Bool,
  font_weight : Double,
) -> Double {
  if font_weight != 400.0 || !is_bold {
    font_weight
  } else {
    700.0
  }
}

///|
fn is_bold_font_weight(font_weight : Double) -> Bool {
  font_weight >= 600.0
}

///|
fn glyph_from_provider(
  provider : GlyphProvider,
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
  font_weight : Double,
) -> (Array[@svg.PathCommand], Double) {
  match provider.get_glyph_for_family_by_weight {
    Some(glyph_fn) if font_family.length() > 0 =>
      match glyph_fn(codepoint, font_size, font_weight, font_family) {
        Some(r) => return r
        None => ()
      }
    _ => ()
  }
  match provider.get_glyph_for_family {
    Some(glyph_fn) if font_family.length() > 0 =>
      match glyph_fn(codepoint, font_size, is_bold, font_family) {
        Some(r) => return r
        None => ()
      }
    _ => ()
  }
  match provider.get_glyph_by_weight {
    Some(glyph_fn) => glyph_fn(codepoint, font_size, font_weight)
    None => (provider.get_glyph)(codepoint, font_size, is_bold)
  }
}

///|
fn kern_from_provider(
  provider : GlyphProvider,
  cp1 : Int,
  cp2 : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
  font_weight : Double,
) -> Double {
  match provider.get_kern_for_family_by_weight {
    Some(kern_fn) if font_family.length() > 0 =>
      return kern_fn(cp1, cp2, font_size, font_weight, font_family)
    _ => ()
  }
  match provider.get_kern_for_family {
    Some(kern_fn) if font_family.length() > 0 =>
      return kern_fn(cp1, cp2, font_size, is_bold, font_family)
    _ => ()
  }
  match provider.get_kern_by_weight {
    Some(kern_fn) => kern_fn(cp1, cp2, font_size, font_weight)
    None => (provider.get_kern)(cp1, cp2, font_size, is_bold)
  }
}

///|
fn get_advance(
  provider : GlyphProvider,
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
  font_family? : String = "",
  font_weight? : Double = 400.0,
) -> Double {
  let effective_font_weight = resolve_effective_font_weight(
    is_bold, font_weight,
  )
  let effective_is_bold = is_bold || is_bold_font_weight(effective_font_weight)
  let (_, advance) = glyph_from_provider(
    provider, codepoint, font_size, effective_is_bold, font_family, effective_font_weight,
  )
  advance
}

///|
fn clamp_opacity(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn blend_color_over_pixel_alpha(
  fb : Framebuffer,
  palette : DynamicPalette,
  px : Int,
  py : Int,
  color : Color,
  alpha : Double,
) -> Unit {
  let clamped = clamp_opacity(alpha)
  if clamped <= 0.0 {
    return
  }
  if clamped >= 1.0 {
    let idx = palette.get_or_add(color)
    fb.set_pixel(px, py, idx)
    return
  }
  let bg_idx = fb.pixels[py * fb.width + px]
  let bg_color = palette_color_at(palette, bg_idx)
  let a_byte = (clamped * 255.0).to_int()
  let blended = color.blend(bg_color, a_byte)
  let idx = palette.get_or_add(blended)
  fb.set_pixel(px, py, idx)
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

///|
/// Draw text using the glyph provider with clip rect support.
fn draw_text_with_glyphs_clipped(
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
  clip : ClipRect?,
  font_family? : String = "",
  opacity? : Double = 1.0,
  letter_spacing? : Double = 0.0,
  word_spacing? : Double = 0.0,
  font_weight? : Double = 400.0,
) -> Int {
  let effective_font_weight = resolve_effective_font_weight(
    is_bold, font_weight,
  )
  let effective_is_bold = is_bold || is_bold_font_weight(effective_font_weight)
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
  let wrap_tolerance = resolve_text_wrap_tolerance(max_width, font_size)
  let max_x_limit = if max_width > 0 {
    (x + max_width).to_double() + wrap_tolerance
  } else {
    fb.width.to_double()
  }
  let words = split_text_into_words(text)
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
    // Pre-compute palette index for this word's color (constant per word)
    let sixel_color = { r: color.r, g: color.g, b: color.b }
    let color_idx = palette.get_or_add(sixel_color)
    let mut prev_cp = 0
    for c in word {
      let cp = c.to_int()
      let bitmap = cached_glyph_bitmap(
        provider, cp, font_size, effective_is_bold, font_family, effective_font_weight,
        baseline_offset,
      )
      let kern = if prev_cp != 0 {
        kern_from_provider(
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
        let dx = draw_x.to_int() + bitmap.offset_x
        let dy = cur_y.to_int() + bitmap.offset_y
        let has_coverage = bitmap.coverage.length() ==
          bitmap.width * bitmap.height
        for by = 0; by < bitmap.height; by = by + 1 {
          let py = dy + by
          if py < 0 || py >= fb.height {
            continue
          }
          for bx = 0; bx < bitmap.width; bx = bx + 1 {
            let bi = by * bitmap.width + bx
            if bitmap.pixels[bi] {
              let px = dx + bx
              if px >= 0 && px < fb.width && pixel_in_clip(clip, px, py) {
                if has_coverage {
                  let cov = bitmap.coverage[bi]
                  let max_cov = bitmap.ss_factor * bitmap.ss_factor
                  if cov >= max_cov {
                    // Full coverage: solid pixel
                    if text_opacity >= 1.0 {
                      fb.set_pixel(px, py, color_idx)
                    } else {
                      blend_color_over_pixel_alpha(
                        fb, palette, px, py, sixel_color, text_opacity,
                      )
                    }
                  } else {
                    // Partial coverage: blend with background
                    let alpha = cov.to_double() /
                      max_cov.to_double() *
                      text_opacity
                    blend_color_over_pixel_alpha(
                      fb, palette, px, py, sixel_color, alpha,
                    )
                  }
                } else if text_opacity >= 1.0 {
                  fb.set_pixel(px, py, color_idx)
                } else {
                  blend_color_over_pixel_alpha(
                    fb, palette, px, py, sixel_color, text_opacity,
                  )
                }
              }
            }
          }
        }
      }
      cur_x = draw_x + bitmap.advance
      prev_cp = cp
    }
  }
  (max_y_seen - y.to_double()).to_int()
}
