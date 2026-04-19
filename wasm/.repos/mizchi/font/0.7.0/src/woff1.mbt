///|
/// WOFF1 magic number: "wOFF" = 0x774F4646
let woff1_magic : Int = 0x774F4646

///|
/// Parse a WOFF1 font, decompress tables, rebuild sfnt, and delegate to parse_ttf
pub fn parse_woff1(data : Bytes) -> TTFont? {
  let reader = BinaryReader::new(data)
  // WOFF1 Header (44 bytes)
  let signature = reader.read_uint32()
  if signature != woff1_magic {
    return None
  }
  let flavor = reader.read_uint32()
  let _length = reader.read_uint32()
  let num_tables = reader.read_uint16()
  let _reserved = reader.read_uint16()
  let _total_sfnt_size = reader.read_uint32()
  let _major_version = reader.read_uint16()
  let _minor_version = reader.read_uint16()
  let _meta_offset = reader.read_uint32()
  let _meta_length = reader.read_uint32()
  let _meta_orig_length = reader.read_uint32()
  let _priv_offset = reader.read_uint32()
  let _priv_length = reader.read_uint32()
  // Read table directory entries (20 bytes each)
  let entries : Array[(String, Int, Int, Int)] = [] // (tag, offset, compLength, origLength)
  for i = 0; i < num_tables; i = i + 1 {
    let tag = reader.read_tag()
    let offset = reader.read_uint32()
    let comp_length = reader.read_uint32()
    let orig_length = reader.read_uint32()
    let _orig_checksum = reader.read_uint32()
    entries.push((tag, offset, comp_length, orig_length))
    ignore(i)
  }
  // Decompress each table
  let tables : Array[(String, Bytes)] = []
  for i = 0; i < entries.length(); i = i + 1 {
    let (tag, offset, comp_length, orig_length) = entries[i]
    let table_data = if comp_length < orig_length {
      // Compressed: extract slice and decompress with zlib
      let compressed = bytes_slice(data, offset, comp_length)
      @zlib.zlib_decompress(compressed) catch {
        _ => return None
      }
    } else {
      // Uncompressed: copy as-is
      bytes_slice(data, offset, orig_length)
    }
    tables.push((tag, table_data))
    ignore(i)
  }
  let sfnt = rebuild_sfnt(flavor, tables)
  parse_ttf(sfnt)
}
