///|
test "BinaryReader::read_uint8" {
  let data = Bytes::from_array([0x41, 0xFF, 0x00])
  let r = BinaryReader::new(data)
  inspect(r.read_uint8(), content="65")
  inspect(r.read_uint8(), content="255")
  inspect(r.read_uint8(), content="0")
  inspect(r.position(), content="3")
}

///|
test "BinaryReader::read_int8" {
  let data = Bytes::from_array([0x7F, 0x80, 0xFF, 0x01])
  let r = BinaryReader::new(data)
  inspect(r.read_int8(), content="127")
  inspect(r.read_int8(), content="-128")
  inspect(r.read_int8(), content="-1")
  inspect(r.read_int8(), content="1")
}

///|
test "BinaryReader::read_uint16 big-endian" {
  let data = Bytes::from_array([0x00, 0x41, 0xFF, 0xFF])
  let r = BinaryReader::new(data)
  inspect(r.read_uint16(), content="65")
  inspect(r.read_uint16(), content="65535")
}

///|
test "BinaryReader::read_int16 big-endian" {
  let data = Bytes::from_array([0x00, 0x01, 0xFF, 0xFF, 0x80, 0x00])
  let r = BinaryReader::new(data)
  inspect(r.read_int16(), content="1")
  inspect(r.read_int16(), content="-1")
  inspect(r.read_int16(), content="-32768")
}

///|
test "BinaryReader::read_uint32 big-endian" {
  let data = Bytes::from_array([0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00])
  let r = BinaryReader::new(data)
  inspect(r.read_uint32(), content="1")
  inspect(r.read_uint32(), content="65536")
}

///|
test "BinaryReader::read_tag" {
  // "head" = 0x68, 0x65, 0x61, 0x64
  let data = Bytes::from_array([0x68, 0x65, 0x61, 0x64])
  let r = BinaryReader::new(data)
  inspect(r.read_tag(), content="head")
}

///|
test "BinaryReader::seek and skip" {
  let data = Bytes::from_array([0x00, 0x01, 0x02, 0x03, 0x04])
  let r = BinaryReader::new(data)
  r.skip(2)
  inspect(r.position(), content="2")
  inspect(r.read_uint8(), content="2")
  r.seek(0)
  inspect(r.read_uint8(), content="0")
}

///|
test "BinaryReader::peek_uint16_at" {
  let data = Bytes::from_array([0x00, 0x00, 0x00, 0x41])
  let r = BinaryReader::new(data)
  inspect(r.peek_uint16_at(2), content="65")
  // Position should not change
  inspect(r.position(), content="0")
}

///|
test "BinaryReader::peek_int16_at" {
  let data = Bytes::from_array([0xFF, 0xFF])
  let r = BinaryReader::new(data)
  inspect(r.peek_int16_at(0), content="-1")
  inspect(r.position(), content="0")
}

///|
test "BinaryReader::peek_uint32_at" {
  let data = Bytes::from_array([0x00, 0x00, 0x01, 0x00])
  let r = BinaryReader::new(data)
  inspect(r.peek_uint32_at(0), content="256")
  inspect(r.position(), content="0")
}
