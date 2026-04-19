///|
pub(all) struct TableInfo {
  tag : String
  offset : Int
  length : Int
}

///|
/// Analyze sfnt table directory without full parsing
pub fn analyze_tables(data : Bytes) -> Array[TableInfo]? {
  if data.length() < 12 {
    return None
  }
  let reader = BinaryReader::new(data)
  let _sfnt_version = reader.read_uint32()
  let num_tables = reader.read_uint16()
  let _search_range = reader.read_uint16()
  let _entry_selector = reader.read_uint16()
  let _range_shift = reader.read_uint16()
  let tables : Array[TableInfo] = []
  for i = 0; i < num_tables; i = i + 1 {
    let tag = reader.read_tag()
    let _checksum = reader.read_uint32()
    let offset = reader.read_uint32()
    let length = reader.read_uint32()
    tables.push({ tag, offset, length })
    ignore(i)
  }
  Some(tables)
}

///|
/// Get all glyph IDs in the font (0 to num_glyphs-1)
pub fn TTFont::glyph_ids(self : TTFont) -> Array[Int] {
  Array::makei(self.num_glyphs, fn(i) { i })
}

///|
/// Get all codepoints covered by the font's cmap
pub fn TTFont::codepoint_coverage(self : TTFont) -> Array[Int] {
  let cps : Array[Int] = []
  self.cmap.each(fn(cp, _gid) { cps.push(cp) })
  cps.sort()
  cps
}
