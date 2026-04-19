///|
/// Parse head table: returns (units_per_em, index_to_loc_format)
pub fn parse_head(reader : BinaryReader, offset : Int) -> (Int, Int) {
  let units_per_em = reader.peek_uint16_at(offset + 18)
  let index_to_loc_format = reader.peek_int16_at(offset + 50)
  (units_per_em, index_to_loc_format)
}

///|
/// Parse maxp table: returns num_glyphs
pub fn parse_maxp(reader : BinaryReader, offset : Int) -> Int {
  reader.peek_uint16_at(offset + 4)
}

///|
/// Parse hhea table: returns (ascent, descent, line_gap, num_h_metrics)
pub fn parse_hhea(reader : BinaryReader, offset : Int) -> (Int, Int, Int, Int) {
  let ascent = reader.peek_int16_at(offset + 4)
  let descent = reader.peek_int16_at(offset + 6)
  let line_gap = reader.peek_int16_at(offset + 8)
  let num_h_metrics = reader.peek_uint16_at(offset + 34)
  (ascent, descent, line_gap, num_h_metrics)
}

///|
/// Parse loca table: returns array of glyph offsets into glyf table
pub fn parse_loca(
  reader : BinaryReader,
  offset : Int,
  num_glyphs : Int,
  format : Int,
) -> Array[Int] {
  let loca = Array::new(capacity=num_glyphs + 1)
  reader.seek(offset)
  for i = 0; i <= num_glyphs; i = i + 1 {
    if format == 0 {
      loca.push(reader.read_uint16() * 2)
    } else {
      loca.push(reader.read_uint32())
    }
  }
  loca
}

///|
/// Parse hmtx table: returns (advance_widths, left_side_bearings)
pub fn parse_hmtx(
  reader : BinaryReader,
  offset : Int,
  num_glyphs : Int,
  num_h_metrics : Int,
) -> (Array[Int], Array[Int]) {
  let advance_widths = Array::new(capacity=num_glyphs)
  let left_side_bearings = Array::new(capacity=num_glyphs)
  reader.seek(offset)
  let mut last_advance = 0
  for i = 0; i < num_glyphs; i = i + 1 {
    if i < num_h_metrics {
      last_advance = reader.read_uint16()
      advance_widths.push(last_advance)
      left_side_bearings.push(reader.read_int16())
    } else {
      advance_widths.push(last_advance)
      left_side_bearings.push(reader.read_int16())
    }
  }
  (advance_widths, left_side_bearings)
}

///|
/// Parse kern table (format 0, horizontal only): returns Map[key -> value]
/// Key = (left_gid << 16) | right_gid
pub fn parse_kern(reader : BinaryReader, offset : Int) -> Map[Int, Int] {
  let result : Map[Int, Int] = {}
  reader.seek(offset)
  let version = reader.read_uint16()
  if version == 0 {
    // Microsoft kern table: version(u16) + nTables(u16)
    let n_tables = reader.read_uint16()
    for t = 0; t < n_tables; t = t + 1 {
      let _sub_version = reader.read_uint16()
      let sub_length = reader.read_uint16()
      let coverage = reader.read_uint16()
      let format = coverage >> 8
      let horizontal = (coverage & 1) != 0
      if format == 0 && horizontal {
        let n_pairs = reader.read_uint16()
        let _search_range = reader.read_uint16()
        let _entry_selector = reader.read_uint16()
        let _range_shift = reader.read_uint16()
        for p = 0; p < n_pairs; p = p + 1 {
          let left = reader.read_uint16()
          let right = reader.read_uint16()
          let value = reader.read_int16()
          result[(left << 16) | right] = value
          ignore(p)
        }
      } else {
        // Skip unsupported subtable (sub_length includes header 6 bytes already read)
        reader.skip(sub_length - 6)
      }
      ignore(t)
    }
  }
  // version 1 (Apple) not supported
  result
}

///|
/// Parse avar table: returns per-axis segment maps
pub fn parse_avar(
  reader : BinaryReader,
  offset : Int,
  axis_count : Int,
) -> Array[Array[(Double, Double)]] {
  let segments : Array[Array[(Double, Double)]] = []
  reader.seek(offset)
  let _major = reader.read_uint16()
  let _minor = reader.read_uint16()
  let _reserved = reader.read_uint16()
  let avar_axis_count = reader.read_uint16()
  let count = if avar_axis_count < axis_count {
    avar_axis_count
  } else {
    axis_count
  }
  for i = 0; i < count; i = i + 1 {
    let position_map_count = reader.read_uint16()
    let pairs : Array[(Double, Double)] = []
    for j = 0; j < position_map_count; j = j + 1 {
      let from_coord = reader.read_f2dot14()
      let to_coord = reader.read_f2dot14()
      pairs.push((from_coord, to_coord))
      ignore(j)
    }
    segments.push(pairs)
    ignore(i)
  }
  segments
}

///|
/// Parse name table: returns Map[nameID -> string]
/// Prefers platformID=3/encodingID=1 (Windows Unicode BMP, UTF-16BE)
pub fn parse_name(reader : BinaryReader, offset : Int) -> Map[Int, String] {
  let result : Map[Int, String] = {}
  reader.seek(offset)
  let _format = reader.read_uint16()
  let count = reader.read_uint16()
  let string_offset = reader.read_uint16()
  let storage_offset = offset + string_offset
  // Collect records, prioritize Windows Unicode
  let records : Array[(Int, Int, Int, Int, Int, Int)] = []
  for i = 0; i < count; i = i + 1 {
    let platform_id = reader.read_uint16()
    let encoding_id = reader.read_uint16()
    let _language_id = reader.read_uint16()
    let name_id = reader.read_uint16()
    let length = reader.read_uint16()
    let str_offset = reader.read_uint16()
    records.push(
      (platform_id, encoding_id, name_id, length, str_offset, _language_id),
    )
    ignore(i)
  }
  // First pass: Windows Unicode (platformID=3, encodingID=1)
  for rec in records {
    let (platform_id, encoding_id, name_id, length, str_offset, _language_id) = rec
    if platform_id == 3 && encoding_id == 1 {
      let s = decode_utf16be(reader, storage_offset + str_offset, length)
      result[name_id] = s
    }
  }
  // Second pass: Unicode platform (platformID=0) for missing entries
  for rec in records {
    let (platform_id, _encoding_id, name_id, length, str_offset, _language_id) = rec
    if platform_id == 0 && result.get(name_id) is None {
      let s = decode_utf16be(reader, storage_offset + str_offset, length)
      result[name_id] = s
    }
  }
  // Third pass: Mac Roman (platformID=1, encodingID=0) for remaining missing entries
  for rec in records {
    let (platform_id, encoding_id, name_id, length, str_offset, _language_id) = rec
    if platform_id == 1 && encoding_id == 0 && result.get(name_id) is None {
      let s = decode_ascii(reader, storage_offset + str_offset, length)
      result[name_id] = s
    }
  }
  result
}

///|
fn decode_utf16be(reader : BinaryReader, offset : Int, length : Int) -> String {
  let chars : Array[Char] = []
  let num_units = length / 2
  for i = 0; i < num_units; i = i + 1 {
    let code_unit = reader.peek_uint16_at(offset + i * 2)
    // Handle surrogate pairs
    if code_unit >= 0xD800 && code_unit <= 0xDBFF && i + 1 < num_units {
      let lo = reader.peek_uint16_at(offset + (i + 1) * 2)
      if lo >= 0xDC00 && lo <= 0xDFFF {
        let cp = 0x10000 + ((code_unit - 0xD800) << 10) + (lo - 0xDC00)
        chars.push(Int::unsafe_to_char(cp))
        continue i + 2
      }
    }
    chars.push(Int::unsafe_to_char(code_unit))
  }
  String::from_array(chars)
}

///|
fn decode_ascii(reader : BinaryReader, offset : Int, length : Int) -> String {
  let chars : Array[Char] = []
  for i = 0; i < length; i = i + 1 {
    let b = reader.data[offset + i].to_int()
    chars.push(Int::unsafe_to_char(b))
    ignore(i)
  }
  String::from_array(chars)
}

///|
/// Parse fvar table: returns array of variation axes
pub fn parse_fvar(reader : BinaryReader, offset : Int) -> Array[VarAxis] {
  reader.seek(offset)
  let _major = reader.read_uint16()
  let _minor = reader.read_uint16()
  let axis_array_offset = reader.read_uint16()
  let _reserved = reader.read_uint16()
  let axis_count = reader.read_uint16()
  let _axis_size = reader.read_uint16()
  let axes : Array[VarAxis] = []
  reader.seek(offset + axis_array_offset)
  for i = 0; i < axis_count; i = i + 1 {
    let tag = reader.read_tag()
    let min_value = reader.read_f16dot16()
    let default_value = reader.read_f16dot16()
    let max_value = reader.read_f16dot16()
    let _flags = reader.read_uint16()
    let _name_id = reader.read_uint16()
    axes.push({ tag, min_value, default_value, max_value })
    ignore(i)
  }
  axes
}
