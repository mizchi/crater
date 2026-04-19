///|
pub(all) struct BinaryReader {
  data : Bytes
  mut pos : Int
}

///|
pub fn BinaryReader::new(data : Bytes) -> BinaryReader {
  { data, pos: 0 }
}

///|
pub fn BinaryReader::at(data : Bytes, pos : Int) -> BinaryReader {
  { data, pos }
}

///|
pub fn BinaryReader::position(self : BinaryReader) -> Int {
  self.pos
}

///|
pub fn BinaryReader::seek(self : BinaryReader, pos : Int) -> Unit {
  self.pos = pos
}

///|
pub fn BinaryReader::skip(self : BinaryReader, n : Int) -> Unit {
  self.pos += n
}

///|
pub fn BinaryReader::read_uint8(self : BinaryReader) -> Int {
  let v = self.data[self.pos]
  self.pos += 1
  v.to_int()
}

///|
pub fn BinaryReader::read_int8(self : BinaryReader) -> Int {
  let v = self.data[self.pos].to_int()
  self.pos += 1
  if v >= 128 {
    v - 256
  } else {
    v
  }
}

///|
pub fn BinaryReader::read_uint16(self : BinaryReader) -> Int {
  let b0 = self.data[self.pos].to_int()
  let b1 = self.data[self.pos + 1].to_int()
  self.pos += 2
  (b0 << 8) | b1
}

///|
pub fn BinaryReader::read_int16(self : BinaryReader) -> Int {
  let v = self.read_uint16()
  if v >= 32768 {
    v - 65536
  } else {
    v
  }
}

///|
pub fn BinaryReader::read_uint32(self : BinaryReader) -> Int {
  let b0 = self.data[self.pos].to_int()
  let b1 = self.data[self.pos + 1].to_int()
  let b2 = self.data[self.pos + 2].to_int()
  let b3 = self.data[self.pos + 3].to_int()
  self.pos += 4
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

///|
pub fn BinaryReader::read_tag(self : BinaryReader) -> String {
  let chars = Array::new(capacity=4)
  for i = 0; i < 4; i = i + 1 {
    chars.push(Int::unsafe_to_char(self.data[self.pos + i].to_int()))
  }
  self.pos += 4
  String::from_array(chars)
}

///|
pub fn BinaryReader::read_f2dot14(self : BinaryReader) -> Double {
  self.read_int16().to_double() / 16384.0
}

///|
pub fn BinaryReader::read_f16dot16(self : BinaryReader) -> Double {
  let hi = self.read_int16()
  let lo = self.read_uint16()
  (hi * 65536 + lo).to_double() / 65536.0
}

///|
pub fn BinaryReader::peek_uint16_at(self : BinaryReader, offset : Int) -> Int {
  let b0 = self.data[offset].to_int()
  let b1 = self.data[offset + 1].to_int()
  (b0 << 8) | b1
}

///|
pub fn BinaryReader::peek_int16_at(self : BinaryReader, offset : Int) -> Int {
  let v = self.peek_uint16_at(offset)
  if v >= 32768 {
    v - 65536
  } else {
    v
  }
}

///|
pub fn BinaryReader::peek_uint32_at(self : BinaryReader, offset : Int) -> Int {
  let b0 = self.data[offset].to_int()
  let b1 = self.data[offset + 1].to_int()
  let b2 = self.data[offset + 2].to_int()
  let b3 = self.data[offset + 3].to_int()
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}
