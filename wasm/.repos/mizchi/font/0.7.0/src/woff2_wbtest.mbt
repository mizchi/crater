///|
test "read_uintbase128 - single byte" {
  let data = Bytes::from_array([b'\x3F'])
  let reader = BinaryReader::new(data)
  inspect(read_uintbase128(reader), content="Some(63)")
}

///|
test "read_uintbase128 - two bytes" {
  // 0x81 0x00 = (1 << 7) | 0 = 128
  let data = Bytes::from_array([b'\x81', b'\x00'])
  let reader = BinaryReader::new(data)
  inspect(read_uintbase128(reader), content="Some(128)")
}

///|
test "read_uintbase128 - multi byte" {
  // Encode 16384 = 0x4000 → 0x81 0x80 0x00
  let data = Bytes::from_array([b'\x81', b'\x80', b'\x00'])
  let reader = BinaryReader::new(data)
  inspect(read_uintbase128(reader), content="Some(16384)")
}

///|
test "read_uintbase128 - leading zero error" {
  let data = Bytes::from_array([b'\x80', b'\x01'])
  let reader = BinaryReader::new(data)
  inspect(read_uintbase128(reader), content="None")
}

///|
test "read_255ushort - small value" {
  let data = Bytes::from_array([b'\x0A'])
  let reader = BinaryReader::new(data)
  inspect(read_255ushort(reader), content="10")
}

///|
test "read_255ushort - code 253 (uint16)" {
  // 253 then uint16 = 0x0100 = 256
  let data = Bytes::from_array([b'\xFD', b'\x01', b'\x00'])
  let reader = BinaryReader::new(data)
  inspect(read_255ushort(reader), content="256")
}

///|
test "read_255ushort - code 255 (253 + byte)" {
  // 255 then byte 10 = 253 + 10 = 263
  let data = Bytes::from_array([b'\xFF', b'\x0A'])
  let reader = BinaryReader::new(data)
  inspect(read_255ushort(reader), content="263")
}

///|
test "read_255ushort - code 254 (506 + byte)" {
  // 254 then byte 10 = 506 + 10 = 516
  let data = Bytes::from_array([b'\xFE', b'\x0A'])
  let reader = BinaryReader::new(data)
  inspect(read_255ushort(reader), content="516")
}

///|
test "woff2 magic detection" {
  // "wOF2" = 0x774F4632
  let data = Bytes::from_array([b'\x77', b'\x4F', b'\x46', b'\x32'])
  let magic = (data[0].to_int() << 24) |
    (data[1].to_int() << 16) |
    (data[2].to_int() << 8) |
    data[3].to_int()
  inspect(magic == woff2_magic, content="true")
}

///|
test "parse_woff2 - invalid magic returns None" {
  let data = Bytes::make(48, b'\x00')
  assert_true(parse_woff2(data) is None)
}

///|
test "known_tags indices" {
  inspect(known_tags[0], content="cmap")
  inspect(known_tags[10], content="glyf")
  inspect(known_tags[11], content="loca")
  inspect(known_tags[62], content="Sill")
}

///|
test "write_be16_arr" {
  let out : Array[Byte] = []
  write_be16_arr(out, 0x0102)
  inspect(out[0].to_int(), content="1")
  inspect(out[1].to_int(), content="2")
}

///|
test "write_be16_arr - negative value" {
  let out : Array[Byte] = []
  write_be16_arr(out, -1)
  // -1 as int16 = 0xFFFF
  inspect(out[0].to_int(), content="255")
  inspect(out[1].to_int(), content="255")
}
