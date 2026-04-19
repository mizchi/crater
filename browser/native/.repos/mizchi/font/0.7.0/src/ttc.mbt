///|
/// Parse a TTC/OTC font collection, returning all fonts
pub fn parse_font_collection(data : Bytes) -> Array[TTFont]? {
  if data.length() < 12 {
    return None
  }
  let reader = BinaryReader::new(data)
  let tag = reader.read_tag()
  if tag != "ttcf" {
    return None
  }
  let _version = reader.read_uint32()
  let num_fonts = reader.read_uint32()
  let offsets : Array[Int] = []
  for i = 0; i < num_fonts; i = i + 1 {
    offsets.push(reader.read_uint32())
    ignore(i)
  }
  let fonts : Array[TTFont] = []
  for offset in offsets {
    match parse_ttf_at_offset(data, offset) {
      Some(font) => fonts.push(font)
      None => ()
    }
  }
  if fonts.is_empty() {
    None
  } else {
    Some(fonts)
  }
}

///|
/// Parse a single font from a TTC/OTC collection by index
pub fn parse_font_at(data : Bytes, index : Int) -> TTFont? {
  if data.length() < 12 {
    return None
  }
  let reader = BinaryReader::new(data)
  let tag = reader.read_tag()
  if tag != "ttcf" {
    return None
  }
  let _version = reader.read_uint32()
  let num_fonts = reader.read_uint32()
  if index < 0 || index >= num_fonts {
    return None
  }
  // Skip to the desired offset entry
  reader.skip(index * 4)
  let offset = reader.read_uint32()
  parse_ttf_at_offset(data, offset)
}
