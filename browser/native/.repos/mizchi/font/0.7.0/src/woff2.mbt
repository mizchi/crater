///|
/// WOFF2 magic number: "wOF2" = 0x774F4632
let woff2_magic : Int = 0x774F4632

///|
/// Known table tags per WOFF2 spec, indexed 0-62
let known_tags : FixedArray[String] = [
  "cmap", "head", "hhea", "hmtx", "maxp", "name", "OS/2", "post", "cvt ", "fpgm",
  "glyf", "loca", "prep", "CFF ", "VORG", "EBDT", "EBLC", "gasp", "hdmx", "kern",
  "LTSH", "PCLT", "VDMX", "vhea", "vmtx", "BASE", "GDEF", "GPOS", "GSUB", "EBSC",
  "JSTF", "MATH", "CBDT", "CBLC", "COLR", "CPAL", "SVG ", "sbix", "acnt", "avar",
  "bdat", "bloc", "bsln", "cvar", "fdsc", "feat", "fmtx", "fvar", "gvar", "hsty",
  "just", "lcar", "mort", "morx", "opbd", "prop", "trak", "Zapf", "Silf", "Glat",
  "Gloc", "Feat", "Sill",
]

///|
/// WOFF2 table directory entry
priv struct Woff2TableEntry {
  tag : String
  transform_version : Int
  src_offset : Int
  src_length : Int
}

///|
/// Read a UIntBase128-encoded value (1-5 bytes, big-endian base-128)
fn read_uintbase128(reader : BinaryReader) -> Int? {
  let mut result = 0
  for i = 0; i < 5; i = i + 1 {
    let b = reader.read_uint8()
    if i == 0 && b == 0x80 {
      return None
    }
    if (result & 0xFE000000) != 0 {
      return None
    }
    result = (result << 7) | (b & 0x7F)
    if (b & 0x80) == 0 {
      return Some(result)
    }
    ignore(i)
  }
  None
}

///|
/// Read a 255UShort-encoded value (variable-length uint16)
fn read_255ushort(reader : BinaryReader) -> Int {
  let code = reader.read_uint8()
  if code == 253 {
    reader.read_uint16()
  } else if code == 255 {
    253 + reader.read_uint8()
  } else if code == 254 {
    506 + reader.read_uint8()
  } else {
    code
  }
}

///|
/// Append a big-endian int16 to an Array[Byte]
fn write_be16_arr(out : Array[Byte], value : Int) -> Unit {
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push((value & 0xFF).to_byte())
}

///|
/// Parse a WOFF2 font, decompress tables, reconstruct transforms, and delegate to parse_ttf
pub fn parse_woff2(data : Bytes) -> TTFont? {
  let reader = BinaryReader::new(data)
  // WOFF2 Header (48 bytes)
  let signature = reader.read_uint32()
  if signature != woff2_magic {
    return None
  }
  let flavor = reader.read_uint32()
  let _length = reader.read_uint32()
  let num_tables = reader.read_uint16()
  let _reserved = reader.read_uint16()
  let _total_sfnt_size = reader.read_uint32()
  let total_compressed_size = reader.read_uint32()
  let _major_version = reader.read_uint16()
  let _minor_version = reader.read_uint16()
  let _meta_offset = reader.read_uint32()
  let _meta_length = reader.read_uint32()
  let _meta_orig_length = reader.read_uint32()
  let _priv_offset = reader.read_uint32()
  let _priv_length = reader.read_uint32()
  // Read table directory
  let entries : Array[Woff2TableEntry] = []
  let mut src_offset = 0
  for i = 0; i < num_tables; i = i + 1 {
    let flag_byte = reader.read_uint8()
    let tag_index = flag_byte & 0x3F
    let transform_version = (flag_byte >> 6) & 0x03
    let tag = if tag_index == 63 {
      reader.read_tag()
    } else {
      known_tags[tag_index]
    }
    // glyf/loca: xform version 0 = transform applied (default)
    // others: xform version != 0 = transform applied
    let has_transform = if tag == "glyf" || tag == "loca" {
      transform_version == 0
    } else {
      transform_version != 0
    }
    guard read_uintbase128(reader) is Some(orig_length) else { return None }
    let transform_length = if has_transform {
      guard read_uintbase128(reader) is Some(tl) else { return None }
      tl
    } else {
      orig_length
    }
    entries.push({
      tag,
      transform_version,
      src_offset,
      src_length: transform_length,
    })
    src_offset += transform_length
    ignore(i)
  }
  // Decompress all table data with Brotli
  let compressed_offset = reader.position()
  let compressed = bytes_slice(data, compressed_offset, total_compressed_size)
  let decompressed = @brotli.brotli_decompress(compressed) catch {
    _ => return None
  }
  // Find special table entries
  let mut glyf_idx : Int = -1
  let mut loca_idx : Int = -1
  let mut hhea_idx : Int = -1
  let mut hmtx_idx : Int = -1
  for i = 0; i < entries.length(); i = i + 1 {
    let e = entries[i]
    if e.tag == "glyf" {
      glyf_idx = i
    }
    if e.tag == "loca" {
      loca_idx = i
    }
    if e.tag == "hhea" {
      hhea_idx = i
    }
    if e.tag == "hmtx" {
      hmtx_idx = i
    }
    ignore(i)
  }
  // Get numHMetrics from hhea table (offset 34, uint16)
  let num_h_metrics = if hhea_idx >= 0 {
    let hhea = entries[hhea_idx]
    if hhea.src_length >= 36 {
      let hhea_reader = BinaryReader::at(decompressed, hhea.src_offset + 34)
      hhea_reader.read_uint16()
    } else {
      0
    }
  } else {
    0
  }
  // Reconstruct glyf/loca if transformed
  let mut glyf_data : Bytes? = None
  let mut loca_data : Bytes? = None
  let mut x_mins : Array[Int] = []
  if glyf_idx >= 0 && loca_idx >= 0 {
    let glyf_e = entries[glyf_idx]
    if glyf_e.transform_version == 0 {
      match
        reconstruct_glyf_loca(
          decompressed,
          glyf_e.src_offset,
          glyf_e.src_length,
        ) {
        Some((g, l, xm)) => {
          glyf_data = Some(g)
          loca_data = Some(l)
          x_mins = xm
        }
        None => return None
      }
    }
  }
  // Reconstruct hmtx if transformed
  let mut hmtx_data : Bytes? = None
  if hmtx_idx >= 0 {
    let hmtx_e = entries[hmtx_idx]
    // hmtx transform: transform_version != 0 for non-glyf/loca tables
    if hmtx_e.transform_version != 0 {
      hmtx_data = Some(
        reconstruct_hmtx(
          decompressed,
          hmtx_e.src_offset,
          hmtx_e.src_length,
          x_mins.length(),
          num_h_metrics,
          x_mins,
        ),
      )
    }
  }
  // Build table list for sfnt reconstruction
  let tables : Array[(String, Bytes)] = []
  for i = 0; i < entries.length(); i = i + 1 {
    let entry = entries[i]
    let table_data = if entry.tag == "glyf" {
      match glyf_data {
        Some(gd) => gd
        None => bytes_slice(decompressed, entry.src_offset, entry.src_length)
      }
    } else if entry.tag == "loca" {
      match loca_data {
        Some(ld) => ld
        None => bytes_slice(decompressed, entry.src_offset, entry.src_length)
      }
    } else if entry.tag == "hmtx" {
      match hmtx_data {
        Some(hd) => hd
        None => bytes_slice(decompressed, entry.src_offset, entry.src_length)
      }
    } else {
      bytes_slice(decompressed, entry.src_offset, entry.src_length)
    }
    tables.push((entry.tag, table_data))
    ignore(i)
  }
  let sfnt = rebuild_sfnt(flavor, tables)
  parse_ttf(sfnt)
}
