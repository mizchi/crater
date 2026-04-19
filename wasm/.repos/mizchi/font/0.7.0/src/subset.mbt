///|
/// Subset a TrueType font to include only the given codepoints.
/// Returns a new sfnt binary containing only the required glyphs.
/// Only supports glyf-based TrueType fonts (not CFF/CFF2).
pub fn subset_font(data : Bytes, codepoints : Array[Int]) -> Bytes? {
  // Parse original font
  guard parse_font(data) is Some(font) else { return None }
  // Only glyf-based fonts supported
  if font.cff is Some(_) {
    return None
  }
  if font.loca.is_empty() {
    return None
  }
  let reader = BinaryReader::new(data)
  // Step 1: Build glyph ID set from codepoints
  let glyph_set : Map[Int, Bool] = {}
  glyph_set[0] = true // always include .notdef
  for cp in codepoints {
    let gid = font.glyph_index(cp)
    if gid > 0 {
      glyph_set[gid] = true
    }
  }
  // Step 2: Resolve compound glyph dependencies
  scan_compound_refs(font, glyph_set)
  // Step 3: Build sorted list of old glyph IDs
  let old_gids : Array[Int] = []
  glyph_set.each(fn(gid, _) { old_gids.push(gid) })
  old_gids.sort()
  let new_num_glyphs = old_gids.length()
  // Step 4: Build old->new glyph ID mapping
  let gid_map : Map[Int, Int] = {}
  for i, old_gid in old_gids {
    gid_map[old_gid] = i
  }
  // Step 5: Build new glyf + loca tables
  let (new_glyf, new_loca) = build_glyf_loca(font, old_gids, gid_map)
  // Step 6: Build new cmap
  let new_cmap = build_cmap_format12(font, codepoints, gid_map)
  // Step 7: Build new hmtx
  let new_hmtx = build_hmtx(font, old_gids)
  // Step 8: Build new maxp
  let new_maxp = build_maxp(reader, font, new_num_glyphs)
  // Step 9: Copy head, hhea, name, OS/2, post tables from original
  let tables : Array[(String, Bytes)] = []
  guard analyze_tables(data) is Some(orig_tables) else { return None }
  let copy_tags = ["hhea", "name", "OS/2", "post"]
  for orig in orig_tables {
    if copy_tags.contains(orig.tag) {
      tables.push((orig.tag, bytes_slice(data, orig.offset, orig.length)))
    }
    if orig.tag == "head" {
      // Copy head and set indexToLocFormat = 1 (long) since we use long loca
      let head_data = bytes_slice(data, orig.offset, orig.length)
      let head_out : Array[Byte] = Array::make(head_data.length(), b'\x00')
      for j = 0; j < head_data.length(); j = j + 1 {
        head_out[j] = head_data[j]
      }
      write_be16(head_out, 50, 1) // indexToLocFormat = 1 (long)
      tables.push(("head", Bytes::from_array(head_out[:])))
    }
    if orig.tag == "hhea" {
      // Update numOfLongHorMetrics in hhea (offset 34)
      let idx = tables.length() - 1
      let (tag, hhea_bytes) = tables[idx]
      let hhea_out : Array[Byte] = Array::make(hhea_bytes.length(), b'\x00')
      for j = 0; j < hhea_bytes.length(); j = j + 1 {
        hhea_out[j] = hhea_bytes[j]
      }
      write_be16(hhea_out, 34, new_num_glyphs) // all glyphs have long metrics
      tables[idx] = (tag, Bytes::from_array(hhea_out[:]))
    }
  }
  // Add rebuilt tables
  tables.push(("cmap", new_cmap))
  tables.push(("glyf", new_glyf))
  tables.push(("hmtx", new_hmtx))
  tables.push(("loca", new_loca))
  tables.push(("maxp", new_maxp))
  // Sort tables by tag for proper sfnt ordering
  tables.sort_by(fn(a, b) { a.0.compare(b.0) })
  // Rebuild sfnt with TrueType flavor
  Some(rebuild_sfnt(0x00010000, tables))
}

///|
/// Scan compound glyphs and add referenced component glyph IDs
fn scan_compound_refs(font : TTFont, glyph_set : Map[Int, Bool]) -> Unit {
  let mut changed = true
  while changed {
    changed = false
    let current_gids : Array[Int] = []
    glyph_set.each(fn(gid, _) { current_gids.push(gid) })
    for gid in current_gids {
      if gid >= font.loca.length() - 1 {
        continue
      }
      let glyf_off = font.loca[gid]
      let next_off = font.loca[gid + 1]
      if glyf_off == next_off {
        continue
      }
      let offset = font.glyf_offset + glyf_off
      let r = BinaryReader::at(font.data, offset)
      let num_contours = r.read_int16()
      if num_contours >= 0 {
        continue // simple glyph
      }
      // Compound glyph: skip bbox (4 x int16 = 8 bytes)
      r.skip(8)
      let mut has_more = true
      while has_more {
        let flags = r.read_uint16()
        let component_gid = r.read_uint16()
        if glyph_set.get(component_gid) is None {
          glyph_set[component_gid] = true
          changed = true
        }
        // Skip arguments
        let arg1_and_2_are_words = (flags & 1) != 0
        if arg1_and_2_are_words {
          r.skip(4)
        } else {
          r.skip(2)
        }
        // Skip transform data
        let we_have_a_scale = (flags & 8) != 0
        let we_have_xy_scale = (flags & 64) != 0
        let we_have_2x2 = (flags & 128) != 0
        if we_have_a_scale {
          r.skip(2)
        } else if we_have_xy_scale {
          r.skip(4)
        } else if we_have_2x2 {
          r.skip(8)
        }
        has_more = (flags & 32) != 0
      }
    }
  }
}

///|
/// Build new glyf and loca tables with remapped glyph IDs
fn build_glyf_loca(
  font : TTFont,
  old_gids : Array[Int],
  gid_map : Map[Int, Int],
) -> (Bytes, Bytes) {
  let glyf_parts : Array[Bytes] = []
  let loca_offsets : Array[Int] = []
  let mut current_offset = 0
  for old_gid in old_gids {
    loca_offsets.push(current_offset)
    if old_gid >= font.loca.length() - 1 {
      // empty glyph
    } else {
      let glyf_off = font.loca[old_gid]
      let next_off = font.loca[old_gid + 1]
      if glyf_off == next_off {
        // empty glyph
      } else {
        let glyph_len = next_off - glyf_off
        let abs_offset = font.glyf_offset + glyf_off
        let glyph_data = bytes_slice(font.data, abs_offset, glyph_len)
        // Check if compound glyph and rewrite component indices
        let r = BinaryReader::new(glyph_data)
        let num_contours = r.read_int16()
        let final_data = if num_contours < 0 {
          rewrite_compound_glyph(glyph_data, gid_map)
        } else {
          glyph_data
        }
        glyf_parts.push(final_data)
        let padded = pad4(final_data.length())
        current_offset = current_offset + padded
      }
    }
  }
  // Final loca entry
  loca_offsets.push(current_offset)
  // Build glyf bytes
  let glyf_out : Array[Byte] = Array::make(current_offset, b'\x00')
  let mut pos = 0
  for part in glyf_parts {
    for j = 0; j < part.length(); j = j + 1 {
      glyf_out[pos + j] = part[j]
    }
    pos += pad4(part.length())
  }
  // Build loca table (long format)
  let loca_len = loca_offsets.length() * 4
  let loca_out : Array[Byte] = Array::make(loca_len, b'\x00')
  for i, off in loca_offsets {
    write_be32(loca_out, i * 4, off)
  }
  (Bytes::from_array(glyf_out[:]), Bytes::from_array(loca_out[:]))
}

///|
/// Rewrite compound glyph component indices to new glyph IDs
fn rewrite_compound_glyph(glyph_data : Bytes, gid_map : Map[Int, Int]) -> Bytes {
  let out : Array[Byte] = Array::make(glyph_data.length(), b'\x00')
  for i = 0; i < glyph_data.length(); i = i + 1 {
    out[i] = glyph_data[i]
  }
  // Skip numContours(2) + bbox(8) = 10 bytes
  let mut pos = 10
  let mut has_more = true
  while has_more && pos + 4 <= glyph_data.length() {
    let flags = (glyph_data[pos].to_int() << 8) | glyph_data[pos + 1].to_int()
    let old_gid = (glyph_data[pos + 2].to_int() << 8) |
      glyph_data[pos + 3].to_int()
    let new_gid = gid_map.get(old_gid).unwrap_or(0)
    // Write new glyph ID
    out[pos + 2] = ((new_gid >> 8) & 0xFF).to_byte()
    out[pos + 3] = (new_gid & 0xFF).to_byte()
    pos += 4 // flags + glyphIndex
    let arg1_and_2_are_words = (flags & 1) != 0
    if arg1_and_2_are_words {
      pos += 4
    } else {
      pos += 2
    }
    if (flags & 8) != 0 {
      pos += 2
    } else if (flags & 64) != 0 {
      pos += 4
    } else if (flags & 128) != 0 {
      pos += 8
    }
    has_more = (flags & 32) != 0
  }
  Bytes::from_array(out[:])
}

///|
/// Build a cmap table with Format 12
fn build_cmap_format12(
  font : TTFont,
  codepoints : Array[Int],
  gid_map : Map[Int, Int],
) -> Bytes {
  // Build sorted (codepoint, new_gid) pairs
  let pairs : Array[(Int, Int)] = []
  for cp in codepoints {
    let old_gid = font.glyph_index(cp)
    if old_gid > 0 {
      match gid_map.get(old_gid) {
        Some(new_gid) => pairs.push((cp, new_gid))
        None => ()
      }
    }
  }
  pairs.sort_by(fn(a, b) { a.0.compare(b.0) })
  // Build sequential groups
  let groups : Array[(Int, Int, Int)] = [] // (startCharCode, endCharCode, startGlyphID)
  for pair in pairs {
    let (cp, gid) = pair
    let can_extend = if groups.length() > 0 {
      let (_, end_cp, start_gid) = groups[groups.length() - 1]
      cp == end_cp + 1 &&
      gid == start_gid + (cp - groups[groups.length() - 1].0)
    } else {
      false
    }
    if can_extend {
      let idx = groups.length() - 1
      let (start_cp, _, start_gid) = groups[idx]
      groups[idx] = (start_cp, cp, start_gid)
    } else {
      groups.push((cp, cp, gid))
    }
  }
  let num_groups = groups.length()
  // Format 12 subtable: 16 + 12*numGroups bytes
  let subtable_length = 16 + num_groups * 12
  // cmap header: version(2) + numTables(1=2) + encoding record(8) = 12 bytes
  let total = 12 + subtable_length
  let out : Array[Byte] = Array::make(total, b'\x00')
  // cmap header
  write_be16(out, 0, 0) // version
  write_be16(out, 2, 1) // numTables
  // encoding record: platformID=3, encodingID=10, offset=12
  write_be16(out, 4, 3)
  write_be16(out, 6, 10)
  write_be32(out, 8, 12)
  // Format 12 subtable
  let s = 12 // subtable start
  write_be16(out, s, 12) // format
  write_be16(out, s + 2, 0) // reserved
  write_be32(out, s + 4, subtable_length) // length
  write_be32(out, s + 8, 0) // language
  write_be32(out, s + 12, num_groups)
  for i, group in groups {
    let (start_cp, end_cp, start_gid) = group
    let off = s + 16 + i * 12
    write_be32(out, off, start_cp)
    write_be32(out, off + 4, end_cp)
    write_be32(out, off + 8, start_gid)
  }
  Bytes::from_array(out[:])
}

///|
/// Build hmtx table for subset glyphs
fn build_hmtx(font : TTFont, old_gids : Array[Int]) -> Bytes {
  let num_glyphs = old_gids.length()
  // All entries as longHorMetric (4 bytes each)
  let out : Array[Byte] = Array::make(num_glyphs * 4, b'\x00')
  for i, old_gid in old_gids {
    let advance = if old_gid < font.advance_widths.length() {
      font.advance_widths[old_gid]
    } else {
      0
    }
    let lsb = if old_gid < font.left_side_bearings.length() {
      font.left_side_bearings[old_gid]
    } else {
      0
    }
    write_be16(out, i * 4, advance)
    // lsb as signed int16
    write_be16(out, i * 4 + 2, lsb & 0xFFFF)
  }
  Bytes::from_array(out[:])
}

///|
/// Build maxp table (update numGlyphs)
fn build_maxp(
  _reader : BinaryReader,
  font : TTFont,
  new_num_glyphs : Int,
) -> Bytes {
  // Find original maxp table
  guard analyze_tables(font.data) is Some(tables) else {
    // Fallback: minimal maxp
    let out : Array[Byte] = Array::make(6, b'\x00')
    write_be32(out, 0, 0x00010000) // version 1.0
    write_be16(out, 4, new_num_glyphs)
    return Bytes::from_array(out[:])
  }
  let mut maxp_offset = 0
  let mut maxp_length = 0
  for t in tables {
    if t.tag == "maxp" {
      maxp_offset = t.offset
      maxp_length = t.length
    }
  }
  if maxp_length == 0 {
    let out : Array[Byte] = Array::make(6, b'\x00')
    write_be32(out, 0, 0x00010000)
    write_be16(out, 4, new_num_glyphs)
    return Bytes::from_array(out[:])
  }
  // Copy original maxp and update numGlyphs
  let maxp_data = bytes_slice(font.data, maxp_offset, maxp_length)
  let out : Array[Byte] = Array::make(maxp_data.length(), b'\x00')
  for i = 0; i < maxp_data.length(); i = i + 1 {
    out[i] = maxp_data[i]
  }
  write_be16(out, 4, new_num_glyphs)
  Bytes::from_array(out[:])
}
