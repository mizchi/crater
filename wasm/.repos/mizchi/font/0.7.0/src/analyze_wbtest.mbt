///|
test "analyze/noto_table_list" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard analyze_tables(data) is Some(tables)
  // Should have common tables
  let tags : Array[String] = []
  for t in tables {
    tags.push(t.tag)
  }
  assert_true(tags.contains("head"))
  assert_true(tags.contains("cmap"))
  assert_true(tags.contains("glyf"))
  assert_true(tags.contains("OS/2"))
}

///|
test "analyze/noto_table_lengths" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard analyze_tables(data) is Some(tables)
  for t in tables {
    assert_true(t.length > 0)
    assert_true(t.offset >= 0)
  }
}

///|
test "analyze/codepoint_coverage" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  let cps = font.codepoint_coverage()
  // NotoSansMono supports ASCII range
  assert_true(cps.contains(0x41)) // 'A'
  assert_true(cps.contains(0x61)) // 'a'
  assert_true(cps.length() > 100)
}

///|
test "analyze/codepoint_coverage_sorted" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  let cps = font.codepoint_coverage()
  // Should be sorted
  for i = 1; i < cps.length(); i = i + 1 {
    assert_true(cps[i] >= cps[i - 1])
  }
}

///|
test "analyze/small_font" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard analyze_tables(data) is Some(tables)
  assert_true(tables.length() > 0)
}

///|
test "analyze/too_small" {
  let data = Bytes::makei(4, fn(_i) { b'\x00' })
  assert_true(analyze_tables(data) is None)
}

///|
test "analyze/glyph_ids" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  let ids = font.glyph_ids()
  assert_eq(ids.length(), font.num_glyphs)
  assert_eq(ids[0], 0)
  assert_eq(ids[ids.length() - 1], font.num_glyphs - 1)
}

///|
test "analyze/vertical_metrics_absent" {
  // NotoSansMono is horizontal-only, should have no vertical metrics
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  assert_true(font.vertical is None)
}
