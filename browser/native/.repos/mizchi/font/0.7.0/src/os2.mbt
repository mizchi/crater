///|
/// Parse OS/2 table
pub fn parse_os2(reader : BinaryReader, offset : Int) -> OS2Table {
  let version = reader.peek_uint16_at(offset)
  // xAvgCharWidth(2) + usWeightClass(2) + usWidthClass(2)
  let us_weight_class = reader.peek_uint16_at(offset + 4)
  let us_width_class = reader.peek_uint16_at(offset + 6)
  let fs_type = reader.peek_uint16_at(offset + 8)
  // PANOSE: 10 bytes at offset+32
  let panose : FixedArray[Int] = FixedArray::make(10, 0)
  for i in 0..<10 {
    panose[i] = reader.data[offset + 32 + i].to_int()
  }
  // ulUnicodeRange1..4 at offset+42..57 (each 4 bytes)
  let ul_unicode_range1 = reader.peek_uint32_at(offset + 42)
  let ul_unicode_range2 = reader.peek_uint32_at(offset + 46)
  let ul_unicode_range3 = reader.peek_uint32_at(offset + 50)
  let ul_unicode_range4 = reader.peek_uint32_at(offset + 54)
  // fsSelection at offset+62
  let fs_selection = reader.peek_uint16_at(offset + 62)
  // sTypoAscender/Descender/LineGap at offset+68..72
  let s_typo_ascender = reader.peek_int16_at(offset + 68)
  let s_typo_descender = reader.peek_int16_at(offset + 70)
  let s_typo_line_gap = reader.peek_int16_at(offset + 72)
  // usWinAscent/Descent at offset+74..77
  let us_win_ascent = reader.peek_uint16_at(offset + 74)
  let us_win_descent = reader.peek_uint16_at(offset + 76)
  // sxHeight and sCapHeight: v2+ only (offset+86..89)
  let sx_height = if version >= 2 {
    reader.peek_int16_at(offset + 86)
  } else {
    0
  }
  let s_cap_height = if version >= 2 {
    reader.peek_int16_at(offset + 88)
  } else {
    0
  }
  {
    version,
    us_weight_class,
    us_width_class,
    fs_type,
    panose,
    ul_unicode_range1,
    ul_unicode_range2,
    ul_unicode_range3,
    ul_unicode_range4,
    fs_selection,
    s_typo_ascender,
    s_typo_descender,
    s_typo_line_gap,
    us_win_ascent,
    us_win_descent,
    sx_height,
    s_cap_height,
  }
}
