///|
/// External font tests: validate cmap12/name against real NotoSansMono fixtures

///|
fn load_fixture(path : String) -> Bytes raise @fs.IOError {
  @fs.read_file_to_bytes(path)
}

// --- NotoSansMono-Regular.ttf: cmap Format 12, name table ---

///|
test "external/noto_regular_parse" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  inspect(font.units_per_em, content="1000")
  assert_true(font.num_glyphs > 3000)
}

///|
test "external/noto_regular_cmap_bmp" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  // 'A' = U+0041 -> gid 36
  inspect(font.glyph_index(0x41), content="36")
  // 'a' = U+0061 -> gid 68
  inspect(font.glyph_index(0x61), content="68")
  // '0' = U+0030 -> gid 19
  inspect(font.glyph_index(0x30), content="19")
  // space = U+0020 -> gid 3
  inspect(font.glyph_index(0x20), content="3")
}

///|
test "external/noto_regular_cmap12_non_bmp" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  // U+10780 (Latin Extended-F) -> gid 3831
  inspect(font.glyph_index(0x10780), content="3831")
  // U+10781 -> gid 3832
  inspect(font.glyph_index(0x10781), content="3832")
  // Unmapped non-BMP char should return 0
  inspect(font.glyph_index(0x1F600), content="0")
}

///|
test "external/noto_regular_non_bmp_count" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  // Count non-BMP entries in cmap (should be 92)
  let mut non_bmp = 0
  font.cmap.each(fn(cp, _gid) { if cp > 0xFFFF { non_bmp += 1 } })
  inspect(non_bmp, content="92")
}

///|
test "external/noto_regular_name" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  guard font.font_name(1) is Some(family)
  inspect(family, content="Noto Sans Mono")
  guard font.font_name(2) is Some(subfamily)
  inspect(subfamily, content="Regular")
  guard font.font_name(6) is Some(ps_name)
  inspect(ps_name, content="NotoSansMono-Regular")
}

///|
test "external/noto_regular_full_name" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  guard font.font_name(4) is Some(full_name)
  inspect(full_name, content="Noto Sans Mono Regular")
}

///|
test "external/noto_regular_outline_non_bmp" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  // Non-BMP char U+10780 should have outline
  let outline = font.char_outline(0x10780)
  assert_true(outline.length() > 0)
}

// --- NotoSansMono-Bold.ttf: different name, non-BMP chars ---

///|
test "external/noto_bold_name" {
  let data = load_fixture("fixtures/NotoSansMono-Bold.ttf")
  guard parse_font(data) is Some(font)
  guard font.font_name(1) is Some(family)
  inspect(family, content="Noto Sans Mono")
  guard font.font_name(2) is Some(subfamily)
  inspect(subfamily, content="Bold")
  guard font.font_name(6) is Some(ps_name)
  inspect(ps_name, content="NotoSansMono-Bold")
}

///|
test "external/noto_bold_cmap12_non_bmp" {
  let data = load_fixture("fixtures/NotoSansMono-Bold.ttf")
  guard parse_font(data) is Some(font)
  // U+1F67C -> gid 3276
  inspect(font.glyph_index(0x1F67C), content="3276")
}

// --- NotoSansMono-Light.ttf: different family name ---

///|
test "external/noto_light_name" {
  let data = load_fixture("fixtures/NotoSansMono-Light.ttf")
  guard parse_font(data) is Some(font)
  guard font.font_name(1) is Some(family)
  inspect(family, content="Noto Sans Mono Light")
  guard font.font_name(6) is Some(ps_name)
  inspect(ps_name, content="NotoSansMono-Light")
}

// --- NotoSans-subset.otf: CFF font, Format 4 only ---

///|
test "external/noto_sans_otf_name" {
  let data = load_fixture("fixtures/NotoSans-subset.otf")
  guard parse_font(data) is Some(font)
  guard font.font_name(1) is Some(family)
  inspect(family, content="Noto Sans")
  guard font.font_name(6) is Some(ps_name)
  inspect(ps_name, content="NotoSans-Regular")
}

///|
test "external/noto_sans_otf_no_non_bmp" {
  let data = load_fixture("fixtures/NotoSans-subset.otf")
  guard parse_font(data) is Some(font)
  // Subset OTF has no non-BMP chars
  let mut non_bmp = 0
  font.cmap.each(fn(cp, _gid) { if cp > 0xFFFF { non_bmp += 1 } })
  inspect(non_bmp, content="0")
}

// --- WOFF1: name table preserved through decompression ---

///|
test "external/woff1_name" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.woff")
  guard parse_font(data) is Some(font)
  guard font.font_name(1) is Some(family)
  inspect(family, content="Noto Sans Mono")
  guard font.font_name(6) is Some(ps_name)
  inspect(ps_name, content="NotoSansMono-Regular")
}

///|
test "external/woff1_cmap12" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.woff")
  guard parse_font(data) is Some(font)
  // Same cmap as TTF: 'A' -> 36
  inspect(font.glyph_index(0x41), content="36")
  // Non-BMP: U+10780 -> 3831
  inspect(font.glyph_index(0x10780), content="3831")
}
