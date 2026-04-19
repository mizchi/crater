///| Bit writer for deflate streams (LSB-first)

///|
priv struct BitWriter {
  buf : Array[Byte]
  mut bit_buf : Int
  mut bit_count : Int
}

///|
fn BitWriter::new() -> BitWriter {
  { buf: [], bit_buf: 0, bit_count: 0 }
}

///|
fn BitWriter::write_bits(self : BitWriter, bits : Int, count : Int) -> Unit {
  let mut value = bits
  let mut remaining = count
  while remaining > 0 {
    let available = 8 - self.bit_count
    let take = if remaining < available { remaining } else { available }
    let mask = (1 << take) - 1
    self.bit_buf = self.bit_buf | ((value & mask) << self.bit_count)
    self.bit_count = self.bit_count + take
    value = value >> take
    remaining = remaining - take
    if self.bit_count == 8 {
      self.buf.push((self.bit_buf & 0xff).to_byte())
      self.bit_buf = 0
      self.bit_count = 0
    }
  }
}

///|
fn BitWriter::align_byte(self : BitWriter) -> Unit {
  if self.bit_count > 0 {
    self.buf.push((self.bit_buf & 0xff).to_byte())
    self.bit_buf = 0
    self.bit_count = 0
  }
}

///|
fn BitWriter::finish(self : BitWriter) -> Bytes {
  self.align_byte()
  Bytes::from_array(FixedArray::makei(self.buf.length(), fn(i) { self.buf[i] }))
}
