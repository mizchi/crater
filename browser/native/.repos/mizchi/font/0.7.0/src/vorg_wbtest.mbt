///|
test "vorg/vert_origin_fallback" {
  // NotoSansMono has no VORG table, vert_origin_y should fall back to ascent
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  assert_true(font.vorg is None)
  let origin = font.vert_origin_y(0)
  assert_eq(origin, font.ascent)
}

///|
test "vorg/cff_font" {
  let data = load_fixture("fixtures/NotoSans-subset.otf")
  guard parse_font(data) is Some(font)
  // CFF font may or may not have VORG - just ensure vert_origin_y works
  let origin = font.vert_origin_y(1)
  assert_true(origin > 0)
}
