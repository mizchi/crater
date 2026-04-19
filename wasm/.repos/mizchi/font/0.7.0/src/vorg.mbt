///|
/// Get vertical origin Y for a glyph (design units)
pub fn TTFont::vert_origin_y(self : TTFont, glyph_id : Int) -> Int {
  match self.vorg {
    Some(vorg) =>
      match vorg.vert_origins.get(glyph_id) {
        Some(y) => y
        None => vorg.default_vert_origin_y
      }
    None => self.ascent
  }
}

///|
/// Parse VORG table: returns VorgData with default origin and per-glyph overrides
pub fn parse_vorg(reader : BinaryReader, offset : Int) -> VorgData {
  let default_vert_origin_y = reader.peek_int16_at(offset + 4)
  let num_metrics = reader.peek_uint16_at(offset + 6)
  let vert_origins : Map[Int, Int] = {}
  for i = 0; i < num_metrics; i = i + 1 {
    let rec_offset = offset + 8 + i * 4
    let glyph_index = reader.peek_uint16_at(rec_offset)
    let vert_origin_y = reader.peek_int16_at(rec_offset + 2)
    vert_origins[glyph_index] = vert_origin_y
  }
  { default_vert_origin_y, vert_origins }
}
