///|
test "os2/noto_regular_weight_class" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  inspect(font.weight_class(), content="400")
}

///|
test "os2/noto_regular_os2_present" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  assert_true(font.os2 is Some(_))
}

///|
test "os2/noto_regular_sx_height" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  // sxHeight should be positive for a well-formed font
  assert_true(font.x_height() > 0)
}

///|
test "os2/noto_regular_cap_height" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  assert_true(font.cap_height() > 0)
}

///|
test "os2/noto_regular_version" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  guard font.os2 is Some(os2)
  // OS/2 version should be >= 2 for modern fonts
  assert_true(os2.version >= 2)
}

///|
test "os2/noto_regular_typo_metrics" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  guard font.os2 is Some(os2)
  // sTypoAscender should be positive
  assert_true(os2.s_typo_ascender > 0)
  // sTypoDescender should be negative
  assert_true(os2.s_typo_descender < 0)
}

///|
test "os2/noto_regular_fs_selection" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  guard font.os2 is Some(os2)
  // Bit 6 (REGULAR) should be set for a regular font
  assert_true((os2.fs_selection & 0x40) != 0)
}

///|
test "os2/minimal_kern_no_os2" {
  // minimal_kern_ttf doesn't have an OS/2 table
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  inspect(font.weight_class(), content="400")
  inspect(font.x_height(), content="0")
}
