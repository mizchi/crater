///|
fn kerning_test_provider() -> GlyphProvider {
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
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_ascent_for_family: None,
  }
}

///|
test "measure_word_width includes kerning adjustments" {
  let provider = kerning_test_provider()
  let width = measure_word_width(provider, "AV", 12.0, false)
  inspect((width - 10.0).abs() < 0.01, content="true")
}

///|
test "measure_word_width uses family-specific advances" {
  let provider : GlyphProvider = {
    get_glyph: fn(_codepoint, _font_size, _is_bold) {
      (([] : Array[@svg.PathCommand]), 10.0)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
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
    get_ascent_for_family: None,
  }
  let width = measure_word_width(
    provider,
    "AA",
    12.0,
    true,
    font_family="serif",
  )
  inspect(width, content="8")
}

///|
test "draw_text_with_glyphs_clipped uses kerning-aware word widths for wrapping" {
  glyph_bitmap_cache.val = {}
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
test "draw_text_with_glyphs_clipped wraps with family-specific advances" {
  glyph_bitmap_cache.val = {}
  let provider : GlyphProvider = {
    get_glyph: fn(_codepoint, _font_size, _is_bold) {
      (([] : Array[@svg.PathCommand]), 10.0)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
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
  glyph_bitmap_cache.val = {}
  let provider = {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      let advance = if codepoint == ' '.to_int() { 2.0 } else { 5.0 }
      (([] : Array[@svg.PathCommand]), advance)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
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
  glyph_bitmap_cache.val = {}
  let provider = {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      let advance = if codepoint == ' '.to_int() { 2.0 } else { 5.0 }
      (([] : Array[@svg.PathCommand]), advance)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
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
  glyph_bitmap_cache.val = {}
  let provider = {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      let advance = if codepoint == ' '.to_int() { 2.0 } else { 5.0 }
      (([] : Array[@svg.PathCommand]), advance)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
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
  glyph_bitmap_cache.val = {}
  let provider = {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      let advance = if codepoint == ' '.to_int() { 2.0 } else { 11.0 }
      (([] : Array[@svg.PathCommand]), advance)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
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
test "draw_text_with_glyphs_clipped antialiases glyphs without clip" {
  glyph_bitmap_cache.val = {}
  let provider = {
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
    ascent_ratio: 1.0,
    get_glyph_for_family: None,
    get_kern_for_family: None,
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
test "rasterize_glyph_to_bitmap keeps positive-offset contours" {
  let commands : Array[@svg.PathCommand] = [
    MoveTo(10.0, 10.0),
    LineTo(14.0, 10.0),
    LineTo(14.0, 14.0),
    LineTo(10.0, 14.0),
    ClosePath,
  ]
  let bitmap = rasterize_glyph_to_bitmap(commands, 16.0)
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
  let bitmap = rasterize_glyph_to_bitmap(commands, 14.0)
  let center_x = 6 - bitmap.offset_x
  let center_y = 6 - bitmap.offset_y
  let edge_x = 2 - bitmap.offset_x
  let edge_y = 2 - bitmap.offset_y
  inspect(bitmap.pixels[center_y * bitmap.width + center_x], content="false")
  inspect(bitmap.pixels[edge_y * bitmap.width + edge_x], content="true")
}
