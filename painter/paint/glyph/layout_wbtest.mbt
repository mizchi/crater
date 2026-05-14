///|
fn layout_test_provider() -> GlyphProvider {
  {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      let advance = if codepoint == ' '.to_int() { 2.0 } else { 4.0 }
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
}

///|
test "layout_glyph_bitmaps places wrapped glyphs outside raster" {
  clear_glyph_caches()
  let (placements, used_height) = layout_glyph_bitmaps(
    layout_test_provider(),
    0,
    0,
    "AA BB",
    7,
    10.0,
    10.0,
    false,
  )
  inspect(placements.length(), content="4")
  inspect((placements[0].x - 0.0).abs() < 0.01, content="true")
  inspect((placements[1].x - 4.0).abs() < 0.01, content="true")
  inspect((placements[2].x - 0.0).abs() < 0.01, content="true")
  inspect((placements[2].y - 10.0).abs() < 0.01, content="true")
  inspect(used_height, content="20")
}
