///| Zlib stored blocks implementation (no compression)

///|
/// Errors raised by zlib helpers
pub(all) suberror ZlibError {
  InvalidData(String)
} derive(Show, Eq)

///| Git servers accept uncompressed deflate data

///|
/// Maximum size for a single stored block
let max_block_size : Int = 65535

///|
/// Helper to convert Array[Byte] to Bytes
fn zlib_array_to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(arr.length(), fn(i) { arr[i] }))
}

///|
/// Compute stored deflate size (no wrapper)
fn stored_deflate_len(len : Int) -> Int {
  if len == 0 {
    5
  } else {
    len + ((len - 1) / max_block_size + 1) * 5
  }
}

///|
/// Write deflate stored blocks into preallocated buffer.
/// Returns next offset after writing.
fn write_stored_deflate_blocks(
  out : FixedArray[Byte],
  start : Int,
  data : Bytes,
) -> Int {
  let len = data.length()
  let mut offset = start
  let mut pos = 0
  while pos < len {
    let remaining = len - pos
    let block_size = if remaining > max_block_size {
      max_block_size
    } else {
      remaining
    }
    let is_final = pos + block_size >= len
    out[offset] = if is_final { b'\x01' } else { b'\x00' }
    offset += 1
    out[offset] = (block_size & 0xff).to_byte()
    offset += 1
    out[offset] = ((block_size >> 8) & 0xff).to_byte()
    offset += 1
    let nlen = block_size ^ 0xffff
    out[offset] = (nlen & 0xff).to_byte()
    offset += 1
    out[offset] = ((nlen >> 8) & 0xff).to_byte()
    offset += 1
    for i = 0; i < block_size; i = i + 1 {
      out[offset + i] = data[pos + i]
    }
    offset += block_size
    pos += block_size
  }
  if len == 0 {
    out[offset] = b'\x01'
    out[offset + 1] = b'\x00'
    out[offset + 2] = b'\x00'
    out[offset + 3] = b'\xff'
    out[offset + 4] = b'\xff'
    offset += 5
  }
  offset
}

///|
/// Compress data using zlib stored blocks (no actual compression)
/// Format: CMF(0x78) + FLG(0x01) + blocks + Adler32
pub fn zlib_compress_stored(data : Bytes) -> Bytes {
  let deflate_len = stored_deflate_len(data.length())
  let total_len = 2 + deflate_len + 4
  let result : FixedArray[Byte] = FixedArray::make(total_len, b'\x00')

  // Zlib header: CMF=0x78 (deflate, 32K window), FLG=0x01 (fastest)
  result[0] = b'\x78'
  result[1] = b'\x01'
  let offset = write_stored_deflate_blocks(result, 2, data)

  // Adler-32 checksum (big-endian)
  let checksum = adler32(data)
  write_u32_be(result, offset, checksum)
  Bytes::from_array(result)
}

///|
/// Compress data using zlib (fixed Huffman).
pub fn zlib_compress(data : Bytes) -> Bytes {
  let deflated = deflate_compress(data)
  let total_len = 2 + deflated.length() + 4
  let result : FixedArray[Byte] = FixedArray::make(total_len, b'\x00')
  result[0] = b'\x78'
  result[1] = b'\x01'
  for i = 0; i < deflated.length(); i = i + 1 {
    result[2 + i] = deflated[i]
  }
  let checksum = adler32(data)
  write_u32_be(result, 2 + deflated.length(), checksum)
  Bytes::from_array(result)
}

///|
/// Decompress zlib stored blocks from the given offset.
/// Returns (decompressed_bytes, next_offset).
pub fn zlib_decompress_stored_at(
  data : Bytes,
  start : Int,
) -> (Bytes, Int) raise ZlibError {
  if start < 0 || start + 2 > data.length() {
    raise ZlibError::InvalidData("Zlib data too short")
  }

  // Verify zlib header
  let cmf = data[start].to_int()
  let flg = data[start + 1].to_int()
  if cmf != 0x78 {
    raise ZlibError::InvalidData("Invalid zlib CMF: \{cmf}")
  }
  // FLG should make (CMF * 256 + FLG) % 31 == 0
  if (cmf * 256 + flg) % 31 != 0 {
    raise ZlibError::InvalidData("Invalid zlib FLG checksum")
  }
  let result : Array[Byte] = []
  let mut offset = start + 2

  // Read blocks
  while true {
    if offset >= data.length() {
      raise ZlibError::InvalidData("Unexpected end of zlib data")
    }
    if offset + 5 > data.length() {
      raise ZlibError::InvalidData("Unexpected end of zlib block header")
    }
    let header = data[offset].to_int()
    offset += 1
    let bfinal = header & 1
    let btype = (header >> 1) & 3
    if btype != 0 {
      raise ZlibError::InvalidData(
        "Only stored blocks supported, got BTYPE=\{btype}",
      )
    }

    // Read LEN (little-endian)
    let len_lo = data[offset].to_int()
    let len_hi = data[offset + 1].to_int()
    let block_len = len_lo | (len_hi << 8)
    offset += 2

    // Read NLEN and verify
    let nlen_lo = data[offset].to_int()
    let nlen_hi = data[offset + 1].to_int()
    let nlen = nlen_lo | (nlen_hi << 8)
    offset += 2
    if (block_len ^ nlen) != 0xffff {
      raise ZlibError::InvalidData("Invalid stored block length")
    }
    if offset + block_len > data.length() {
      raise ZlibError::InvalidData("Unexpected end of stored block data")
    }
    // Copy raw data
    for i = 0; i < block_len; i = i + 1 {
      result.push(data[offset])
      offset += 1
    }
    if bfinal == 1 {
      break
    }
  }

  // Verify Adler-32 (big-endian)
  if offset + 4 > data.length() {
    raise ZlibError::InvalidData("Missing Adler-32 checksum")
  }
  let stored_checksum = (data[offset].to_int() << 24) |
    (data[offset + 1].to_int() << 16) |
    (data[offset + 2].to_int() << 8) |
    data[offset + 3].to_int()
  offset += 4
  let result_bytes = zlib_array_to_bytes(result)
  let computed_checksum = adler32(result_bytes)
  if stored_checksum != computed_checksum {
    raise ZlibError::InvalidData(
      "Adler-32 mismatch: stored=\{stored_checksum}, computed=\{computed_checksum}",
    )
  }
  (result_bytes, offset)
}

///|
/// Decompress zlib stored blocks (single stream)
pub fn zlib_decompress_stored(data : Bytes) -> Bytes raise ZlibError {
  let (result, offset) = zlib_decompress_stored_at(data, 0)
  if offset != data.length() {
    raise ZlibError::InvalidData("Trailing data after zlib stream")
  }
  result
}

///|
/// Compress raw deflate stream using stored blocks (no compression).
pub fn deflate_compress_stored(data : Bytes) -> Bytes {
  let deflate_len = stored_deflate_len(data.length())
  let result : FixedArray[Byte] = FixedArray::make(deflate_len, b'\x00')
  let _ = write_stored_deflate_blocks(result, 0, data)
  Bytes::from_array(result)
}

///|
/// Compress raw deflate stream (fixed Huffman).
pub fn deflate_compress(data : Bytes) -> Bytes {
  deflate_compress_best(data)
}

///|
/// Decompress raw deflate stream from the given offset.
pub fn deflate_decompress_at(
  data : Bytes,
  start : Int,
) -> (Bytes, Int) raise ZlibError {
  inflate_deflate_stream(data, start)
}

///|
/// Decompress a full raw deflate stream.
pub fn deflate_decompress(data : Bytes) -> Bytes raise ZlibError {
  let (result, offset) = deflate_decompress_at(data, 0)
  if offset != data.length() {
    raise ZlibError::InvalidData("Trailing data after deflate stream")
  }
  result
}

///|
/// Decompress a zlib stream (deflate with checksum) from the given offset.
/// Returns (decompressed_bytes, next_offset).
pub fn zlib_decompress_at(
  data : Bytes,
  start : Int,
) -> (Bytes, Int) raise ZlibError {
  if start < 0 || start + 2 > data.length() {
    raise ZlibError::InvalidData("Zlib data too short")
  }
  let cmf = data[start].to_int()
  let flg = data[start + 1].to_int()
  if (cmf & 0x0f) != 8 {
    raise ZlibError::InvalidData("Unsupported compression method")
  }
  if (cmf * 256 + flg) % 31 != 0 {
    raise ZlibError::InvalidData("Invalid zlib FLG checksum")
  }
  let fdict = (flg >> 5) & 1
  if fdict == 1 {
    raise ZlibError::InvalidData("Preset dictionary not supported")
  }
  let deflate_start = start + 2
  let (result, offset) = inflate_deflate_stream(data, deflate_start)
  if offset + 4 > data.length() {
    raise ZlibError::InvalidData("Missing Adler-32 checksum")
  }
  let stored_checksum = (data[offset].to_int() << 24) |
    (data[offset + 1].to_int() << 16) |
    (data[offset + 2].to_int() << 8) |
    data[offset + 3].to_int()
  let computed_checksum = adler32(result)
  if stored_checksum != computed_checksum {
    raise ZlibError::InvalidData(
      "Adler-32 mismatch: stored=\{stored_checksum}, computed=\{computed_checksum}",
    )
  }
  (result, offset + 4)
}

///|
/// Compress gzip stream using stored deflate blocks (no compression).
pub fn gzip_compress_stored(data : Bytes) -> Bytes {
  let deflate_len = stored_deflate_len(data.length())
  let total_len = 10 + deflate_len + 8
  let out : FixedArray[Byte] = FixedArray::make(total_len, b'\x00')
  out[0] = b'\x1f'
  out[1] = b'\x8b'
  out[2] = b'\x08'
  out[3] = b'\x00'
  out[4] = b'\x00'
  out[5] = b'\x00'
  out[6] = b'\x00'
  out[7] = b'\x00'
  out[8] = b'\x00'
  out[9] = b'\xff'
  let offset = write_stored_deflate_blocks(out, 10, data)
  let checksum = crc32(data)
  write_u32_le(out, offset, checksum)
  let size = Int::reinterpret_as_uint(data.length())
  write_u32_le(out, offset + 4, size)
  Bytes::from_array(out)
}

///|
/// Decompress gzip stream from the given offset.
pub fn gzip_decompress_at(
  data : Bytes,
  start : Int,
) -> (Bytes, Int) raise ZlibError {
  if start < 0 || start + 10 > data.length() {
    raise ZlibError::InvalidData("Gzip data too short")
  }
  if data[start] != b'\x1f' || data[start + 1] != b'\x8b' {
    raise ZlibError::InvalidData("Invalid gzip header")
  }
  if data[start + 2] != b'\x08' {
    raise ZlibError::InvalidData("Unsupported gzip compression method")
  }
  let flags = data[start + 3].to_int()
  let mut offset = start + 10
  if (flags & 0x04) != 0 {
    let xlen = read_u16_le(data, offset)
    offset += 2
    if offset + xlen > data.length() {
      raise ZlibError::InvalidData("Unexpected end of gzip extra field")
    }
    offset += xlen
  }
  if (flags & 0x08) != 0 {
    while offset < data.length() && data[offset] != b'\x00' {
      offset += 1
    }
    if offset >= data.length() {
      raise ZlibError::InvalidData("Unexpected end of gzip filename")
    }
    offset += 1
  }
  if (flags & 0x10) != 0 {
    while offset < data.length() && data[offset] != b'\x00' {
      offset += 1
    }
    if offset >= data.length() {
      raise ZlibError::InvalidData("Unexpected end of gzip comment")
    }
    offset += 1
  }
  if (flags & 0x02) != 0 {
    if offset + 2 > data.length() {
      raise ZlibError::InvalidData("Unexpected end of gzip header CRC")
    }
    offset += 2
  }
  let (result, end_offset) = inflate_deflate_stream(data, offset)
  if end_offset + 8 > data.length() {
    raise ZlibError::InvalidData("Missing gzip trailer")
  }
  let stored_crc = read_u32_le(data, end_offset)
  let stored_size = read_u32_le(data, end_offset + 4)
  let computed_crc = crc32(result)
  if stored_crc != computed_crc {
    raise ZlibError::InvalidData("CRC32 mismatch in gzip trailer")
  }
  let size = Int::reinterpret_as_uint(result.length())
  if stored_size != size {
    raise ZlibError::InvalidData("ISIZE mismatch in gzip trailer")
  }
  (result, end_offset + 8)
}

///|
/// Decompress a full gzip stream.
pub fn gzip_decompress(data : Bytes) -> Bytes raise ZlibError {
  let (result, offset) = gzip_decompress_at(data, 0)
  if offset != data.length() {
    raise ZlibError::InvalidData("Trailing data after gzip stream")
  }
  result
}

///|
/// Decompress a full zlib stream.
pub fn zlib_decompress(data : Bytes) -> Bytes raise ZlibError {
  let (result, offset) = zlib_decompress_at(data, 0)
  if offset != data.length() {
    raise ZlibError::InvalidData("Trailing data after zlib stream")
  }
  result
}

///|
fn read_u16_le(data : Bytes, start : Int) -> Int raise ZlibError {
  if start < 0 || start + 2 > data.length() {
    raise ZlibError::InvalidData("Unexpected end of data")
  }
  let b0 = data[start].to_int()
  let b1 = data[start + 1].to_int()
  b0 | (b1 << 8)
}

///|
fn read_u32_le(data : Bytes, start : Int) -> UInt raise ZlibError {
  if start < 0 || start + 4 > data.length() {
    raise ZlibError::InvalidData("Unexpected end of data")
  }
  let b0 = Int::reinterpret_as_uint(data[start].to_int())
  let b1 = Int::reinterpret_as_uint(data[start + 1].to_int())
  let b2 = Int::reinterpret_as_uint(data[start + 2].to_int())
  let b3 = Int::reinterpret_as_uint(data[start + 3].to_int())
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
fn write_u32_be(out : FixedArray[Byte], offset : Int, v : Int) -> Unit {
  out[offset] = ((v >> 24) & 0xff).to_byte()
  out[offset + 1] = ((v >> 16) & 0xff).to_byte()
  out[offset + 2] = ((v >> 8) & 0xff).to_byte()
  out[offset + 3] = (v & 0xff).to_byte()
}

///|
fn write_u32_le(out : FixedArray[Byte], offset : Int, v : UInt) -> Unit {
  let mask = Int::reinterpret_as_uint(255)
  out[offset] = (v & mask).to_byte()
  out[offset + 1] = ((v >> 8) & mask).to_byte()
  out[offset + 2] = ((v >> 16) & mask).to_byte()
  out[offset + 3] = ((v >> 24) & mask).to_byte()
}
