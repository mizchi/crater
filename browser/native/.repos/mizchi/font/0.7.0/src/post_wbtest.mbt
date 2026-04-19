///|
test "post/noto_regular_present" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  assert_true(font.post is Some(_))
}

///|
test "post/noto_regular_fixed_pitch" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  // NotoSansMono has isFixedPitch=0 in post table (despite being monospace)
  inspect(font.is_fixed_pitch(), content="false")
}

///|
test "post/noto_regular_italic_angle" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  // Regular weight should have italic angle = 0
  inspect(font.italic_angle(), content="0")
}

///|
test "post/noto_regular_underline" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  guard font.post is Some(post)
  // underline_thickness should be positive
  assert_true(post.underline_thickness > 0)
}

///|
test "post/minimal_kern_post_values" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  // minimal_kern_ttf has a post table
  assert_true(font.post is Some(_))
}

///|
test "post/glyph_name_fallback" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  // glyph_name for non-existent glyph returns ""
  inspect(font.glyph_name(9999), content="")
}
