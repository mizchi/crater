///| Bit reader for deflate streams (LSB-first)

///|
priv struct BitReader {
  data : Bytes
  mut byte_pos : Int
  mut bit_buf : UInt64
  mut bit_count : Int
}

///|
fn BitReader::new(data : Bytes, start : Int) -> BitReader {
  { data, byte_pos: start, bit_buf: 0, bit_count: 0 }
}

///|
fn BitReader::ensure_bits(self : BitReader, n : Int) -> Unit raise ZlibError {
  while self.bit_count < n {
    let remaining = self.data.length() - self.byte_pos
    if remaining <= 0 {
      raise ZlibError::InvalidData("Unexpected end of deflate stream")
    }
    // Batch 4 bytes when possible to reduce loop overhead in hot paths.
    // Use UInt64 to keep shifts safe for native targets.
    if remaining >= 4 && self.bit_count <= 32 {
      let b0 = self.data[self.byte_pos].to_uint64()
      let b1 = self.data[self.byte_pos + 1].to_uint64()
      let b2 = self.data[self.byte_pos + 2].to_uint64()
      let b3 = self.data[self.byte_pos + 3].to_uint64()
      self.byte_pos = self.byte_pos + 4
      self.bit_buf = self.bit_buf |
        (b0 << self.bit_count) |
        (b1 << (self.bit_count + 8)) |
        (b2 << (self.bit_count + 16)) |
        (b3 << (self.bit_count + 24))
      self.bit_count = self.bit_count + 32
    } else if remaining >= 2 && self.bit_count <= 48 {
      let b0 = self.data[self.byte_pos].to_uint64()
      let b1 = self.data[self.byte_pos + 1].to_uint64()
      self.byte_pos = self.byte_pos + 2
      self.bit_buf = self.bit_buf |
        (b0 << self.bit_count) |
        (b1 << (self.bit_count + 8))
      self.bit_count = self.bit_count + 16
    } else {
      let b = self.data[self.byte_pos].to_uint64()
      self.byte_pos = self.byte_pos + 1
      self.bit_buf = self.bit_buf | (b << self.bit_count)
      self.bit_count = self.bit_count + 8
    }
  }
}

///|
fn BitReader::peek_bits(self : BitReader, n : Int) -> Int raise ZlibError {
  if n == 0 {
    return 0
  }
  self.ensure_bits(n)
  let one : UInt64 = 1
  let mask : UInt64 = (one << n) - 1
  (self.bit_buf & mask).to_int()
}

///|
fn BitReader::drop_bits(self : BitReader, n : Int) -> Unit {
  if n == 0 {
    return
  }
  self.bit_buf = self.bit_buf >> n
  self.bit_count = self.bit_count - n
}

///|
fn BitReader::read_bits(self : BitReader, n : Int) -> Int raise ZlibError {
  let result = self.peek_bits(n)
  self.drop_bits(n)
  result
}

///|
fn BitReader::align_byte(self : BitReader) -> Unit {
  let full_bytes = self.bit_count / 8
  if full_bytes > 0 {
    self.byte_pos = self.byte_pos - full_bytes
  }
  self.bit_buf = 0
  self.bit_count = 0
}

///|

///|
fn BitReader::read_u16_le_aligned(self : BitReader) -> Int raise ZlibError {
  if self.bit_count != 0 {
    self.align_byte()
  }
  if self.byte_pos + 2 > self.data.length() {
    raise ZlibError::InvalidData("Unexpected end of deflate stream")
  }
  let b0 = self.data[self.byte_pos].to_int()
  let b1 = self.data[self.byte_pos + 1].to_int()
  self.byte_pos = self.byte_pos + 2
  b0 | (b1 << 8)
}

///|
fn BitReader::read_bytes_aligned(
  self : BitReader,
  output : Array[Byte],
  len : Int,
) -> Unit raise ZlibError {
  if self.bit_count != 0 {
    self.align_byte()
  }
  if self.byte_pos + len > self.data.length() {
    raise ZlibError::InvalidData("Unexpected end of deflate stream")
  }
  for i in 0..<len {
    output.push(self.data[self.byte_pos + i])
  }
  self.byte_pos = self.byte_pos + len
}

///|
fn BitReader::offset(self : BitReader) -> Int {
  self.byte_pos
}
