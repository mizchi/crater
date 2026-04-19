///|
test "subset/abc_glyph_count" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  // Subset to A, B, C
  guard subset_font(data, [0x41, 0x42, 0x43]) is Some(subset_data)
  guard parse_font(subset_data) is Some(sub_font)
  // Should have .notdef + A + B + C = 4 glyphs
  inspect(sub_font.num_glyphs, content="4")
}

///|
test "subset/cmap_preserved" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard subset_font(data, [0x41, 0x42, 0x43]) is Some(subset_data)
  guard parse_font(subset_data) is Some(sub_font)
  // cmap should map A, B, C to new glyph IDs
  let gid_a = sub_font.glyph_index(0x41)
  let gid_b = sub_font.glyph_index(0x42)
  let gid_c = sub_font.glyph_index(0x43)
  assert_true(gid_a > 0)
  assert_true(gid_b > 0)
  assert_true(gid_c > 0)
  // Unmapped codepoint should return 0
  inspect(sub_font.glyph_index(0x44), content="0")
}

///|
test "subset/outline_matches" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(orig_font)
  guard subset_font(data, [0x41]) is Some(subset_data)
  guard parse_font(subset_data) is Some(sub_font)
  // Get outline of A from both
  let orig_outline = orig_font.char_outline(0x41)
  let sub_gid = sub_font.glyph_index(0x41)
  let sub_outline = sub_font.glyph_outline(sub_gid)
  // Both should have same number of path commands
  inspect(orig_outline.length() == sub_outline.length(), content="true")
  assert_true(orig_outline.length() > 0)
}

///|
test "subset/advance_width_preserved" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(orig_font)
  guard subset_font(data, [0x41]) is Some(subset_data)
  guard parse_font(subset_data) is Some(sub_font)
  let orig_gid = orig_font.glyph_index(0x41)
  let orig_advance = orig_font.glyph_metrics(orig_gid).advance_width
  let sub_gid = sub_font.glyph_index(0x41)
  let sub_advance = sub_font.glyph_metrics(sub_gid).advance_width
  inspect(orig_advance == sub_advance, content="true")
}

///|
test "subset/smaller_than_original" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard subset_font(data, [0x41, 0x42, 0x43]) is Some(subset_data)
  // Subset should be much smaller
  assert_true(subset_data.length() < data.length())
}

///|
test "subset/single_codepoint" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard subset_font(data, [0x41]) is Some(subset_data)
  guard parse_font(subset_data) is Some(sub_font)
  inspect(sub_font.num_glyphs, content="2") // .notdef + A
}

///|
test "subset/empty_codepoints" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard subset_font(data, []) is Some(subset_data)
  guard parse_font(subset_data) is Some(sub_font)
  inspect(sub_font.num_glyphs, content="1") // only .notdef
}
