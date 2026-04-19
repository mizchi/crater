///|
/// Copy a slice of Bytes
pub fn bytes_slice(data : Bytes, offset : Int, length : Int) -> Bytes {
  Bytes::makei(length, fn(i) { data[offset + i] })
}

///|
/// Rebuild an sfnt (TrueType/OpenType) binary from individual table data.
/// Produces: Offset Table (12 bytes) + Table Records (16 bytes x n) + Table Data (4-byte aligned)
pub fn rebuild_sfnt(flavor : Int, tables : Array[(String, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let entry_selector = log2_floor(num_tables)
  let search_range = (1 << entry_selector) * 16
  let range_shift = num_tables * 16 - search_range
  let header_size = 12 + num_tables * 16
  let mut total_size = header_size
  for i = 0; i < num_tables; i = i + 1 {
    let (_, tdata) = tables[i]
    total_size += pad4(tdata.length())
    ignore(i)
  }
  let out : Array[Byte] = Array::make(total_size, b'\x00')
  write_be32(out, 0, flavor)
  write_be16(out, 4, num_tables)
  write_be16(out, 6, search_range)
  write_be16(out, 8, entry_selector)
  write_be16(out, 10, range_shift)
  let mut data_offset = header_size
  for i = 0; i < num_tables; i = i + 1 {
    let (tag, tdata) = tables[i]
    let record_offset = 12 + i * 16
    for j = 0; j < 4; j = j + 1 {
      out[record_offset + j] = tag[j].to_int().to_byte()
    }
    let checksum = calc_table_checksum(tdata)
    write_be32(out, record_offset + 4, checksum)
    write_be32(out, record_offset + 8, data_offset)
    write_be32(out, record_offset + 12, tdata.length())
    for j = 0; j < tdata.length(); j = j + 1 {
      out[data_offset + j] = tdata[j]
    }
    data_offset += pad4(tdata.length())
    ignore(i)
  }
  Bytes::from_array(out[:])
}

///|
/// Calculate table checksum per OpenType spec
pub fn calc_table_checksum(data : Bytes) -> Int {
  let len = pad4(data.length())
  let mut sum = 0
  for i = 0; i < len; i = i + 4 {
    let b0 = if i < data.length() { data[i].to_int() } else { 0 }
    let b1 = if i + 1 < data.length() { data[i + 1].to_int() } else { 0 }
    let b2 = if i + 2 < data.length() { data[i + 2].to_int() } else { 0 }
    let b3 = if i + 3 < data.length() { data[i + 3].to_int() } else { 0 }
    sum = sum + ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)
  }
  sum
}

///|
/// Floor of log2(n), minimum 0
pub fn log2_floor(n : Int) -> Int {
  let mut result = 0
  let mut val = n
  while val > 1 {
    val = val >> 1
    result += 1
  }
  result
}

///|
/// Round up to next multiple of 4
pub fn pad4(n : Int) -> Int {
  (n + 3) & -4
}

///|
/// Write a big-endian uint32 into Array[Byte]
pub fn write_be32(out : Array[Byte], offset : Int, value : Int) -> Unit {
  out[offset] = ((value >> 24) & 0xFF).to_byte()
  out[offset + 1] = ((value >> 16) & 0xFF).to_byte()
  out[offset + 2] = ((value >> 8) & 0xFF).to_byte()
  out[offset + 3] = (value & 0xFF).to_byte()
}

///|
/// Write a big-endian uint16 into Array[Byte]
pub fn write_be16(out : Array[Byte], offset : Int, value : Int) -> Unit {
  out[offset] = ((value >> 8) & 0xFF).to_byte()
  out[offset + 1] = (value & 0xFF).to_byte()
}
