///|
test "gasp/noto_sans_mono_absent" {
  let data = load_fixture("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  // NotoSansMono may not have gasp table - empty array is valid
  let _ = font.gasp
}

///|
test "gasp/parse_round_trip" {
  // Create a minimal gasp table: version=1, numRanges=2
  let buf : Array[Byte] = Array::new(capacity=12)
  // version
  buf.push(b'\x00')
  buf.push(b'\x01')
  // numRanges
  buf.push(b'\x00')
  buf.push(b'\x02')
  // range 1: maxPPEM=8, behavior=0x0002 (DOGRAY)
  buf.push(b'\x00')
  buf.push(b'\x08')
  buf.push(b'\x00')
  buf.push(b'\x02')
  // range 2: maxPPEM=0xFFFF, behavior=0x000F (all flags)
  buf.push(b'\xFF')
  buf.push(b'\xFF')
  buf.push(b'\x00')
  buf.push(b'\x0F')
  let data = Bytes::from_array(buf[:])
  let reader = BinaryReader::new(data)
  let ranges = parse_gasp(reader, 0)
  assert_eq(ranges.length(), 2)
  assert_eq(ranges[0].max_ppem, 8)
  assert_eq(ranges[0].behavior, 2)
  assert_eq(ranges[1].max_ppem, 0xFFFF)
  assert_eq(ranges[1].behavior, 0x0F)
}
