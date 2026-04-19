///|
test "layout/empty_string" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  let positions = font.layout_text("", 100.0)
  inspect(positions.length(), content="0")
}

///|
test "layout/single_char" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  let positions = font.layout_text("A", 100.0)
  inspect(positions.length(), content="1")
  inspect(positions[0].x_offset, content="0")
  inspect(positions[0].codepoint, content="65")
}

///|
test "layout/av_kerning" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  // A=gid1, V=gid2, kern=-80, units_per_em=1000
  let positions = font.layout_text("AV", 1000.0)
  inspect(positions.length(), content="2")
  // First glyph at x=0
  inspect(positions[0].x_offset, content="0")
  // Second glyph: advance of A (600) + kern (-80) = 520
  let v_offset = positions[1].x_offset
  // advance_width for A is 600 in minimal_kern_ttf
  assert_true(v_offset < 600.0)
  assert_true(v_offset > 500.0)
}

///|
test "layout/measure_empty" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  let w = font.measure_text("", 100.0)
  inspect(w, content="0")
}

///|
test "layout/measure_single" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  let w = font.measure_text("A", 1000.0)
  // advance_width for A is 600
  inspect(w, content="600")
}

///|
test "layout/measure_av_with_kern" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  let w = font.measure_text("AV", 1000.0)
  // A(600) + kern(-80) + V(600) = 1120
  inspect(w, content="1120")
}

///|
test "layout/noto_monospace_equal_advances" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  let positions = font.layout_text("ABC", 100.0)
  // Monospace font: all advances should be equal
  assert_true(positions.length() == 3)
  let adv0 = positions[0].x_advance
  let adv1 = positions[1].x_advance
  let adv2 = positions[2].x_advance
  inspect(adv0 == adv1, content="true")
  inspect(adv1 == adv2, content="true")
}

///|
test "layout/noto_measure_hello" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  let width = font.measure_text("Hello", 100.0)
  // 5 chars, each with equal advance in monospace
  assert_true(width > 0.0)
  // Each glyph should contribute equally
  let single = font.measure_text("H", 100.0)
  // Total should be ~5x single for monospace
  let ratio = width / single
  assert_true(ratio > 4.9 && ratio < 5.1)
}
