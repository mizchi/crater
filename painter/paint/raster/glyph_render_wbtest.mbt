///|
fn kerning_test_provider() -> @glyph.GlyphProvider {
  {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      let advance = if codepoint == ' '.to_int() {
        2.0
      } else if codepoint == 'A'.to_int() || codepoint == 'V'.to_int() {
        6.0
      } else {
        4.0
      }
      (([] : Array[@svg.PathCommand]), advance)
    },
    get_kern: fn(left, right, _font_size, _is_bold) {
      if left == 'A'.to_int() && right == 'V'.to_int() {
        -2.0
      } else {
        0.0
      }
    },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
}

///|
fn static_test_ttfont() -> @font.TTFont {
  let cmap : Map[Int, Int] = {}
  cmap['A'.to_int()] = 1
  {
    units_per_em: 1000,
    index_to_loc_format: 0,
    num_glyphs: 2,
    ascent: 800,
    descent: -200,
    line_gap: 0,
    num_h_metrics: 2,
    glyf_offset: 0,
    data: Bytes::new(0),
    cmap,
    loca: [0, 0, 0],
    advance_widths: [0, 500],
    left_side_bearings: [0, 0],
    cff: None,
    gvar: None,
    var_axes: [],
    kern_pairs: {},
    avar_segments: [],
    name_records: {},
    os2: None,
    post: None,
    vertical: None,
    gasp: [],
    vorg: None,
  }
}

///|
test "measure_word_width includes kerning adjustments" {
  let provider = kerning_test_provider()
  let width = @glyph.measure_word_width(provider, "AV", 12.0, false)
  inspect((width - 10.0).abs() < 0.01, content="true")
}

///|
test "measure_word_width uses family-specific advances" {
  let provider : @glyph.GlyphProvider = {
    get_glyph: fn(_codepoint, _font_size, _is_bold) {
      (([] : Array[@svg.PathCommand]), 10.0)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 0.8,
    get_glyph_for_family: Some(fn(
      _codepoint,
      _font_size,
      _is_bold,
      font_family,
    ) {
      if font_family == "serif" {
        let commands : Array[@svg.PathCommand] = []
        Some((commands, 4.0))
      } else {
        None
      }
    }),
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
  let width = @glyph.measure_word_width(
    provider,
    "AA",
    12.0,
    true,
    font_family="serif",
  )
  inspect(width, content="8")
}

///|
test "measure_word_width uses numeric font weight provider" {
  let provider : @glyph.GlyphProvider = {
    get_glyph: fn(_codepoint, _font_size, _is_bold) {
      (([] : Array[@svg.PathCommand]), 10.0)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: Some(fn(_codepoint, _font_size, font_weight) {
      (([] : Array[@svg.PathCommand]), font_weight / 100.0)
    }),
    get_kern_by_weight: None,
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
  let regular = @glyph.measure_word_width(provider, "AA", 12.0, false)
  let medium = @glyph.measure_word_width(
    provider,
    "AA",
    12.0,
    false,
    font_weight=500.0,
  )
  inspect(regular, content="8")
  inspect(medium, content="10")
}

///|
test "glyph_provider_from_font exposes weight-aware font delegate" {
  let provider = @glyph.glyph_provider_from_font(static_test_ttfont())
  match provider.get_glyph_by_weight {
    Some(glyph_by_weight) => {
      let (_, advance) = glyph_by_weight('A'.to_int(), 100.0, 500.0)
      inspect(advance, content="50")
    }
    None => fail("weight-aware font delegate is missing")
  }
}

///|
test "draw_text_with_glyphs_clipped uses kerning-aware word widths for wrapping" {
  @glyph.clear_glyph_caches()
  let provider = kerning_test_provider()
  let fb = Framebuffer::new(64, 32)
  let palette = DynamicPalette::new()
  let used_height = draw_text_with_glyphs_clipped(
    fb,
    palette,
    provider,
    0,
    0,
    "AV AV",
    22,
    @svg.Color::rgb(0, 0, 0),
    12.0,
    10.0,
    false,
    None,
  )
  inspect(used_height, content="10")
}

///|
test "resolve_glyph_text_wrap_width_keeps_single_layout_line_with_tall_line_height" {
  inspect(
    resolve_glyph_text_wrap_width(130, 21, 14.0, 21.0, "Fast rendering engine"),
    content="0",
  )
}

///|
test "draw_text_with_glyphs_clipped wraps with family-specific advances" {
  @glyph.clear_glyph_caches()
  let provider : @glyph.GlyphProvider = {
    get_glyph: fn(_codepoint, _font_size, _is_bold) {
      (([] : Array[@svg.PathCommand]), 10.0)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 0.8,
    get_glyph_for_family: Some(fn(codepoint, _font_size, is_bold, font_family) {
      if font_family != "serif" || !is_bold {
        return None
      }
      let advance = if codepoint == ' '.to_int() { 2.0 } else { 4.0 }
      let commands : Array[@svg.PathCommand] = []
      Some((commands, advance))
    }),
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
  let fb = Framebuffer::new(64, 32)
  let palette = DynamicPalette::new()
  let used_height = draw_text_with_glyphs_clipped(
    fb,
    palette,
    provider,
    0,
    0,
    "AA AA",
    11,
    @svg.Color::rgb(0, 0, 0),
    12.0,
    10.0,
    true,
    None,
    font_family="serif",
  )
  inspect(used_height, content="10")
}

///|
test "draw_text_with_glyphs_clipped hard-wraps long words when they exceed max width" {
  @glyph.clear_glyph_caches()
  let provider : @glyph.GlyphProvider = {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      let advance = if codepoint == ' '.to_int() { 2.0 } else { 5.0 }
      (([] : Array[@svg.PathCommand]), advance)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
  let fb = Framebuffer::new(64, 64)
  let palette = DynamicPalette::new()
  let used_height = draw_text_with_glyphs_clipped(
    fb,
    palette,
    provider,
    0,
    0,
    "AAAAA",
    12,
    @svg.Color::rgb(0, 0, 0),
    12.0,
    10.0,
    false,
    None,
  )
  inspect(used_height, content="30")
}

///|
test "draw_text_with_glyphs_clipped keeps tiny metric overflow on the same line" {
  @glyph.clear_glyph_caches()
  let provider : @glyph.GlyphProvider = {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      let advance = if codepoint == ' '.to_int() { 2.0 } else { 5.0 }
      (([] : Array[@svg.PathCommand]), advance)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
  let fb = Framebuffer::new(64, 64)
  let palette = DynamicPalette::new()
  let used_height = draw_text_with_glyphs_clipped(
    fb,
    palette,
    provider,
    0,
    0,
    "AAA",
    14,
    @svg.Color::rgb(0, 0, 0),
    12.0,
    10.0,
    false,
    None,
  )
  inspect(used_height, content="10")
}

///|
test "draw_text_with_glyphs_clipped uses word spacing for wrapping" {
  @glyph.clear_glyph_caches()
  let provider : @glyph.GlyphProvider = {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      let advance = if codepoint == ' '.to_int() { 2.0 } else { 5.0 }
      (([] : Array[@svg.PathCommand]), advance)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
  let fb = Framebuffer::new(80, 64)
  let palette = DynamicPalette::new()
  let used_height = draw_text_with_glyphs_clipped(
    fb,
    palette,
    provider,
    0,
    0,
    "AA AA",
    18,
    @svg.Color::rgb(0, 0, 0),
    12.0,
    10.0,
    false,
    None,
    word_spacing=8.0,
  )
  inspect(used_height, content="20")
}

///|
test "draw_text_with_glyphs_clipped tolerates font-sized metric drift" {
  @glyph.clear_glyph_caches()
  let provider : @glyph.GlyphProvider = {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      let advance = if codepoint == ' '.to_int() { 2.0 } else { 11.0 }
      (([] : Array[@svg.PathCommand]), advance)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
  let fb = Framebuffer::new(160, 64)
  let palette = DynamicPalette::new()
  let used_height = draw_text_with_glyphs_clipped(
    fb,
    palette,
    provider,
    0,
    0,
    "AAAAA AAAAA",
    100,
    @svg.Color::rgb(0, 0, 0),
    16.0,
    10.0,
    false,
    None,
  )
  inspect(used_height, content="10")
}

///|
test "draw_text_with_glyphs_clipped preserves expected layout line count" {
  @glyph.clear_glyph_caches()
  let provider : @glyph.GlyphProvider = {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      let advance = if codepoint == ' '.to_int() { 3.0 } else { 6.0 }
      (([] : Array[@svg.PathCommand]), advance)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
  let fb = Framebuffer::new(96, 64)
  let palette = DynamicPalette::new()
  let used_height = draw_text_with_glyphs_clipped(
    fb,
    palette,
    provider,
    0,
    0,
    "AAAA AAAA AAAA",
    30,
    @svg.Color::rgb(0, 0, 0),
    10.0,
    10.0,
    false,
    None,
    expected_line_count=2,
  )
  inspect(used_height, content="20")
}

///|
test "draw_text_with_glyphs_clipped antialiases glyphs without clip" {
  @glyph.clear_glyph_caches()
  let provider : @glyph.GlyphProvider = {
    get_glyph: fn(_codepoint, font_size, _is_bold) {
      let commands : Array[@svg.PathCommand] = [
        MoveTo(0.0, -font_size),
        LineTo(font_size, -font_size),
        LineTo(font_size, 0.0),
        ClosePath,
      ]
      (commands, font_size)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 1.0,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
  let fb = Framebuffer::new(24, 24)
  let palette = DynamicPalette::new()
  let _ = draw_text_with_glyphs_clipped(
    fb,
    palette,
    provider,
    2,
    2,
    "A",
    20,
    @svg.Color::rgb(0, 0, 0),
    12.0,
    12.0,
    false,
    None,
  )
  let mut has_intermediate = false
  for color in palette.colors {
    if color.r > 0 && color.r < 255 {
      has_intermediate = true
    }
  }
  inspect(has_intermediate, content="true")
}

///|
test "draw_text_with_glyphs_clipped preserves fractional glyph x positions" {
  @glyph.clear_glyph_caches()
  let provider : @glyph.GlyphProvider = {
    get_glyph: fn(_codepoint, font_size, _is_bold) {
      let commands : Array[@svg.PathCommand] = [
        MoveTo(0.0, -font_size),
        LineTo(2.0, -font_size),
        LineTo(2.0, 0.0),
        LineTo(0.0, 0.0),
        ClosePath,
      ]
      (commands, 5.5)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 1.0,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
  let fb = Framebuffer::new(16, 12)
  let palette = DynamicPalette::new()
  let _ = draw_text_with_glyphs_clipped(
    fb,
    palette,
    provider,
    0,
    0,
    "AA",
    16,
    @svg.Color::rgb(0, 0, 0),
    8.0,
    8.0,
    false,
    None,
  )
  let edge = palette.colors[fb.get_pixel(5, 4)]
  inspect(edge.r > 0 && edge.r < 255, content="true")
}

///|
test "rasterize_glyph_to_bitmap keeps positive-offset contours" {
  let commands : Array[@svg.PathCommand] = [
    MoveTo(10.0, 10.0),
    LineTo(14.0, 10.0),
    LineTo(14.0, 14.0),
    LineTo(10.0, 14.0),
    ClosePath,
  ]
  let bitmap = @glyph.rasterize_glyph_to_bitmap(commands, 16.0)
  let mut covered = 0
  for has_pixel in bitmap.pixels {
    if has_pixel {
      covered = covered + 1
    }
  }
  inspect(covered > 0, content="true")
}

///|
test "rasterize_glyph_to_bitmap preserves inner contours as holes" {
  let commands : Array[@svg.PathCommand] = [
    MoveTo(0.0, 0.0),
    LineTo(12.0, 0.0),
    LineTo(12.0, 12.0),
    LineTo(0.0, 12.0),
    ClosePath,
    MoveTo(4.0, 4.0),
    LineTo(8.0, 4.0),
    LineTo(8.0, 8.0),
    LineTo(4.0, 8.0),
    ClosePath,
  ]
  let bitmap = @glyph.rasterize_glyph_to_bitmap(commands, 14.0)
  let center_x = 6 - bitmap.offset_x
  let center_y = 6 - bitmap.offset_y
  let edge_x = 2 - bitmap.offset_x
  let edge_y = 2 - bitmap.offset_y
  inspect(bitmap.pixels[center_y * bitmap.width + center_x], content="false")
  inspect(bitmap.pixels[edge_y * bitmap.width + edge_x], content="true")
}
