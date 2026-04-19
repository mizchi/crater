///| Fixture loader for benches/tests

///|
fn hex_char_to_int(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    0
  }
}

///|
fn hex_to_bytes(hex : String) -> Bytes {
  let bytes : Array[Byte] = []
  let chars = hex.to_array()
  for i in 0..<(hex.length() / 2) {
    let hi = hex_char_to_int(chars[i * 2])
    let lo = hex_char_to_int(chars[i * 2 + 1])
    bytes.push(((hi << 4) | lo).to_byte())
  }
  Bytes::from_array(FixedArray::makei(bytes.length(), fn(i) { bytes[i] }))
}

///|
fn bytes_to_hex(data : Bytes) -> String {
  let digits = "0123456789abcdef".to_array()
  let out = StringBuilder::new()
  for b in data {
    let v = b.to_int()
    out.write_char(digits[(v >> 4) & 0xf])
    out.write_char(digits[v & 0xf])
  }
  out.to_string()
}
