///|
test "name/family_from_kern_font" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  // nameID 1 = font family
  guard font.font_name(1) is Some(family)
  inspect(family, content="TestKern")
}

///|
test "name/subfamily_from_kern_font" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  // nameID 2 = font subfamily
  guard font.font_name(2) is Some(subfamily)
  inspect(subfamily, content="Regular")
}

///|
test "name/missing_name_id" {
  let data = Bytes::from_array(minimal_kern_ttf[:])
  guard parse_font(data) is Some(font)
  // Non-existent nameID should return None
  assert_true(font.font_name(999) is None)
}

///|
test "name/cmap12_font_family" {
  let data = Bytes::from_array(minimal_cmap12_ttf[:])
  guard parse_font(data) is Some(font)
  guard font.font_name(1) is Some(family)
  inspect(family, content="TestCmap12")
}

///|
test "name/avar_font_family" {
  let data = Bytes::from_array(minimal_avar_ttf[:])
  guard parse_font(data) is Some(font)
  guard font.font_name(1) is Some(family)
  inspect(family, content="TestAvar")
}

///|
test "name/gvar_font_family" {
  let data = Bytes::from_array(minimal_gvar_ttf[:])
  guard parse_font(data) is Some(font)
  guard font.font_name(1) is Some(family)
  inspect(family, content="TestGvar")
}

///|
test "name/kern_multi_font_family" {
  let data = Bytes::from_array(minimal_kern_multi_ttf[:])
  guard parse_font(data) is Some(font)
  guard font.font_name(1) is Some(family)
  inspect(family, content="TestKernMulti")
}
