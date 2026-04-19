///|
test "vlayout/basic_vertical" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  let positions = font.layout_text_vertical("AB", 48.0)
  assert_eq(positions.length(), 2)
  // First glyph at y=0
  assert_true(positions[0].y_offset < 0.001)
  // Second glyph below the first
  assert_true(positions[1].y_offset > 0.0)
}

///|
test "vlayout/measure_vertical" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  let h1 = font.measure_text_vertical("A", 48.0)
  let h2 = font.measure_text_vertical("AB", 48.0)
  // Two chars should be roughly twice one char
  assert_true(h2 > h1)
  assert_true((h2 - h1 * 2.0).abs() < 1.0)
}

///|
test "vlayout/empty_string" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  let positions = font.layout_text_vertical("", 48.0)
  assert_eq(positions.length(), 0)
  let height = font.measure_text_vertical("", 48.0)
  assert_true(height < 0.001)
}

///|
test "vlayout/monospace_uniform_height" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  // In a monospace font without vmtx, all glyphs use units_per_em as advance height
  let positions = font.layout_text_vertical("Hello", 48.0)
  // Check all advances are equal
  for i = 1; i < positions.length(); i = i + 1 {
    let gap_prev = positions[i].y_offset - positions[i - 1].y_offset
    let gap_first = positions[1].y_offset - positions[0].y_offset
    assert_true((gap_prev - gap_first).abs() < 0.01)
  }
}
