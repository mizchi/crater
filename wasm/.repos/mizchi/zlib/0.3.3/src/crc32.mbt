///| CRC32 implementation for gzip

///|
let crc32_poly : UInt = (Int::reinterpret_as_uint(237) << 24) |
  (Int::reinterpret_as_uint(184) << 16) |
  (Int::reinterpret_as_uint(131) << 8) |
  Int::reinterpret_as_uint(32)

///|
fn build_crc32_table() -> FixedArray[UInt] {
  FixedArray::makei(256, fn(i) {
    let mut c = i.reinterpret_as_uint()
    for _ in 0..<8 {
      if (c & Int::reinterpret_as_uint(1)) == Int::reinterpret_as_uint(1) {
        c = (c >> 1) ^ crc32_poly
      } else {
        c = c >> 1
      }
    }
    c
  })
}

///|
let crc32_table : FixedArray[UInt] = build_crc32_table()

///|
pub fn crc32(data : Bytes) -> UInt {
  let mut crc : UInt = Int::reinterpret_as_uint(-1)
  for b in data {
    let idx = UInt::reinterpret_as_int(
      (crc ^ Int::reinterpret_as_uint(b.to_int())) &
      Int::reinterpret_as_uint(255),
    )
    crc = (crc >> 8) ^ crc32_table[idx]
  }
  crc ^ Int::reinterpret_as_uint(-1)
}

///|
pub fn crc32_fixed(data : FixedArray[Byte]) -> UInt {
  crc32(Bytes::from_array(data))
}
