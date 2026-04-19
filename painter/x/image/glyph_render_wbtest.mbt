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
test "draw_text_with_glyphs uses kerning-aware word widths for wrapping" {
  let provider = kerning_test_provider()
  let fb = Framebuffer::new(64, 32)
  let palette = DynamicPalette::new()
  let used_height = draw_text_with_glyphs(
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
  )
  inspect(used_height, content="10")
}

///|
test "draw_text_with_glyphs hard-wraps long words when they exceed max width" {
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
  let used_height = draw_text_with_glyphs(
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
  )
  inspect(used_height, content="30")
}
