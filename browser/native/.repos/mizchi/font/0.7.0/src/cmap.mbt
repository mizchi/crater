///|
/// Parse cmap table: returns Map[codepoint -> glyph_id]
/// Prefers Format 12 (full Unicode) over Format 4 (BMP only)
pub fn parse_cmap(reader : BinaryReader, offset : Int) -> Map[Int, Int] {
  let result : Map[Int, Int] = {}
  reader.seek(offset)
  let _version = reader.read_uint16()
  let num_tables = reader.read_uint16()
  // Collect candidate subtable offsets
  let mut format12_offset = -1
  let mut format4_offset = -1
  for i = 0; i < num_tables; i = i + 1 {
    let platform_id = reader.read_uint16()
    let encoding_id = reader.read_uint16()
    let sub_offset = reader.read_uint32()
    let abs_offset = offset + sub_offset
    // Format 12 candidates: platformID=0/encodingID>=3, or platformID=3/encodingID=10
    if (platform_id == 0 && encoding_id >= 3) ||
      (platform_id == 3 && encoding_id == 10) {
      format12_offset = abs_offset
    }
    // Format 4 candidates: platformID=0, or platformID=3/encodingID=1
    if platform_id == 0 || (platform_id == 3 && encoding_id == 1) {
      format4_offset = abs_offset
    }
    ignore(i)
  }
  // Prefer Format 12
  if format12_offset >= 0 {
    reader.seek(format12_offset)
    let format = reader.read_uint16()
    if format == 12 {
      parse_cmap_format12(reader, format12_offset, result)
      return result
    }
  }
  // Fallback to Format 4
  if format4_offset >= 0 {
    reader.seek(format4_offset)
    let format = reader.read_uint16()
    if format == 4 {
      parse_cmap_format4(reader, format4_offset, result)
      return result
    }
  }
  // Fallback: scan for Format 0 or Format 6
  for i = 0; i < num_tables; i = i + 1 {
    reader.seek(offset + 4 + i * 8)
    let _pid = reader.read_uint16()
    let _eid = reader.read_uint16()
    let sub_offset = reader.read_uint32()
    let abs_offset = offset + sub_offset
    reader.seek(abs_offset)
    let format = reader.read_uint16()
    if format == 0 && result.is_empty() {
      parse_cmap_format0(reader, abs_offset, result)
      return result
    }
    if format == 6 && result.is_empty() {
      parse_cmap_format6(reader, abs_offset, result)
      return result
    }
  }
  result
}

///|
fn parse_cmap_format12(
  reader : BinaryReader,
  subtable_offset : Int,
  result : Map[Int, Int],
) -> Unit {
  // Format 12: format(u16=12) + reserved(u16) + length(u32) + language(u32) + numGroups(u32)
  reader.seek(subtable_offset + 4) // skip format(u16) + reserved(u16)
  let _length = reader.read_uint32()
  let _language = reader.read_uint32()
  let num_groups = reader.read_uint32()
  for i = 0; i < num_groups; i = i + 1 {
    let start_char_code = reader.read_uint32()
    let end_char_code = reader.read_uint32()
    let start_glyph_id = reader.read_uint32()
    for cp = start_char_code; cp <= end_char_code; cp = cp + 1 {
      let gid = start_glyph_id + (cp - start_char_code)
      if gid != 0 {
        result[cp] = gid
      }
    }
    ignore(i)
  }
}

///|
fn parse_cmap_format4(
  reader : BinaryReader,
  subtable_offset : Int,
  result : Map[Int, Int],
) -> Unit {
  reader.seek(subtable_offset + 2)
  let _length = reader.read_uint16()
  let _language = reader.read_uint16()
  let seg_count_x2 = reader.read_uint16()
  let seg_count = seg_count_x2 / 2
  let _search_range = reader.read_uint16()
  let _entry_selector = reader.read_uint16()
  let _range_shift = reader.read_uint16()
  let end_codes = Array::new(capacity=seg_count)
  for i = 0; i < seg_count; i = i + 1 {
    end_codes.push(reader.read_uint16())
    ignore(i)
  }
  let _reserved_pad = reader.read_uint16()
  let start_codes = Array::new(capacity=seg_count)
  for i = 0; i < seg_count; i = i + 1 {
    start_codes.push(reader.read_uint16())
    ignore(i)
  }
  let id_deltas = Array::new(capacity=seg_count)
  for i = 0; i < seg_count; i = i + 1 {
    id_deltas.push(reader.read_int16())
    ignore(i)
  }
  let id_range_offset_base = reader.position()
  let id_range_offsets = Array::new(capacity=seg_count)
  for i = 0; i < seg_count; i = i + 1 {
    id_range_offsets.push(reader.read_uint16())
    ignore(i)
  }
  for seg = 0; seg < seg_count; seg = seg + 1 {
    let start = start_codes[seg]
    let end = end_codes[seg]
    if start == 0xFFFF {
      // skip sentinel segment (avoid `continue seg` - MoonBit JS codegen bug)
    } else {
      for cp = start; cp <= end; cp = cp + 1 {
        let glyph_id = if id_range_offsets[seg] == 0 {
          (cp + id_deltas[seg]) % 65536
        } else {
          let range_offset_addr = id_range_offset_base + seg * 2
          let glyph_data_offset = range_offset_addr +
            id_range_offsets[seg] +
            (cp - start) * 2
          let gid = reader.peek_uint16_at(glyph_data_offset)
          if gid != 0 {
            (gid + id_deltas[seg]) % 65536
          } else {
            0
          }
        }
        if glyph_id != 0 {
          result[cp] = glyph_id
        }
      }
    }
  }
}

///|
/// Format 0: 256-byte mapping table (Mac Roman)
fn parse_cmap_format0(
  reader : BinaryReader,
  subtable_offset : Int,
  result : Map[Int, Int],
) -> Unit {
  // format(u16=0) + length(u16) + language(u16) + glyphIdArray[256]
  reader.seek(subtable_offset + 6) // skip format + length + language
  for cp = 0; cp < 256; cp = cp + 1 {
    let gid = reader.read_uint8()
    if gid != 0 {
      result[cp] = gid
    }
  }
}

///|
/// Format 6: trimmed table mapping
fn parse_cmap_format6(
  reader : BinaryReader,
  subtable_offset : Int,
  result : Map[Int, Int],
) -> Unit {
  // format(u16=6) + length(u16) + language(u16) + firstCode(u16) + entryCount(u16) + glyphIdArray
  reader.seek(subtable_offset + 6) // skip format + length + language
  let first_code = reader.read_uint16()
  let entry_count = reader.read_uint16()
  for i = 0; i < entry_count; i = i + 1 {
    let gid = reader.read_uint16()
    if gid != 0 {
      result[first_code + i] = gid
    }
  }
}
