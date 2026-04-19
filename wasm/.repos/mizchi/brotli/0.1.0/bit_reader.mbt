///|
let brotli_read_size : Int = 4096

///|
let brotli_ibuf_size : Int = 2 * 4096 + 32

///|
let brotli_ibuf_mask : Int = 2 * 4096 - 1

///|
priv struct BitReader {
  buf : FixedArray[Int]
  data : Bytes
  data_len : Int
  mut data_pos : Int
  mut buf_ptr : Int
  mut val : Int
  mut pos : Int
  mut bit_pos : Int
  mut bit_end_pos : Int
  mut eos : Bool
}

///|
fn BitReader::new(data : Bytes) -> BitReader raise BrotliError {
  let br : BitReader = {
    buf: FixedArray::make(brotli_ibuf_size, 0),
    data,
    data_len: data.length(),
    data_pos: 0,
    buf_ptr: 0,
    val: 0,
    pos: 0,
    bit_pos: 0,
    bit_end_pos: 0,
    eos: false,
  }
  br.read_more_input()
  for i in 0..<4 {
    br.val = br.val | (br.buf[br.pos] << (8 * i))
    br.pos += 1
  }
  br
}

///|
fn BitReader::read_input(self : BitReader, dst : Int, count : Int) -> Int {
  let available = self.data_len - self.data_pos
  let to_read = if count > available { available } else { count }
  for i in 0..<to_read {
    self.buf[dst + i] = self.data[self.data_pos + i].to_int()
  }
  self.data_pos += to_read
  to_read
}

///|
fn BitReader::read_more_input(self : BitReader) -> Unit raise BrotliError {
  if self.bit_end_pos > 256 {
    return
  }
  if self.eos {
    if self.bit_pos > self.bit_end_pos {
      raise BrotliError::InvalidData("Unexpected end of input")
    }
    return
  }
  let dst = self.buf_ptr
  let bytes_read = self.read_input(dst, brotli_read_size)
  if bytes_read < brotli_read_size {
    self.eos = true
    for p in 0..<32 {
      self.buf[dst + bytes_read + p] = 0
    }
  }
  if dst == 0 {
    for p in 0..<32 {
      self.buf[(brotli_read_size << 1) + p] = self.buf[p]
    }
    self.buf_ptr = brotli_read_size
  } else {
    self.buf_ptr = 0
  }
  self.bit_end_pos += bytes_read << 3
}

///|
fn BitReader::fill_bit_window(self : BitReader) -> Unit {
  while self.bit_pos >= 8 {
    self.val = ushr(self.val, 8)
    self.val = self.val | (self.buf[self.pos & brotli_ibuf_mask] << 24)
    self.pos += 1
    self.bit_pos = self.bit_pos - 8
    self.bit_end_pos = self.bit_end_pos - 8
  }
}

///|
fn BitReader::read_bits(self : BitReader, n_bits : Int) -> Int {
  if 32 - self.bit_pos < n_bits {
    self.fill_bit_window()
  }
  let val = ushr(self.val, self.bit_pos) & kBitMask[n_bits]
  self.bit_pos += n_bits
  val
}

///|
fn BitReader::reset(self : BitReader) -> Unit raise BrotliError {
  self.buf_ptr = 0
  self.val = 0
  self.pos = 0
  self.bit_pos = 0
  self.bit_end_pos = 0
  self.eos = false
  self.read_more_input()
  for i in 0..<4 {
    self.val = self.val | (self.buf[self.pos] << (8 * i))
    self.pos += 1
  }
}
