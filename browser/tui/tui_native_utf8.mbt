///|
/// UTF-8 codec helpers for the native TUI adapter.

///|
fn bytes_to_string(buf : FixedArray[Byte], len : Int) -> String {
  let chars : Array[Char] = []
  let mut i = 0
  while i < len {
    let b0 = buf[i].to_int()
    if b0 < 0x80 {
      chars.push(b0.unsafe_to_char())
      i = i + 1
    } else if (b0 & 0xE0) == 0xC0 && i + 1 < len {
      let b1 = buf[i + 1].to_int()
      let code = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
      chars.push(code.unsafe_to_char())
      i = i + 2
    } else if (b0 & 0xF0) == 0xE0 && i + 2 < len {
      let b1 = buf[i + 1].to_int()
      let b2 = buf[i + 2].to_int()
      let code = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
      chars.push(code.unsafe_to_char())
      i = i + 3
    } else if (b0 & 0xF8) == 0xF0 && i + 3 < len {
      let b1 = buf[i + 1].to_int()
      let b2 = buf[i + 2].to_int()
      let b3 = buf[i + 3].to_int()
      let code = ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F)
      let adjusted = code - 0x10000
      let high = 0xD800 + (adjusted >> 10)
      let low = 0xDC00 + (adjusted & 0x3FF)
      chars.push(high.unsafe_to_char())
      chars.push(low.unsafe_to_char())
      i = i + 4
    } else {
      i = i + 1
    }
  }
  chars.iter().map(fn(c) { c.to_string() }).fold(init="", fn(a, b) { a + b })
}

///|
fn encode_utf8(code : Int, buf : FixedArray[Byte], pos : Int) -> Int {
  if code < 0x80 {
    buf[pos] = code.to_byte()
    1
  } else if code < 0x800 {
    buf[pos] = (0xC0 | (code >> 6)).to_byte()
    buf[pos + 1] = (0x80 | (code & 0x3F)).to_byte()
    2
  } else if code < 0x10000 {
    buf[pos] = (0xE0 | (code >> 12)).to_byte()
    buf[pos + 1] = (0x80 | ((code >> 6) & 0x3F)).to_byte()
    buf[pos + 2] = (0x80 | (code & 0x3F)).to_byte()
    3
  } else {
    buf[pos] = (0xF0 | (code >> 18)).to_byte()
    buf[pos + 1] = (0x80 | ((code >> 12) & 0x3F)).to_byte()
    buf[pos + 2] = (0x80 | ((code >> 6) & 0x3F)).to_byte()
    buf[pos + 3] = (0x80 | (code & 0x3F)).to_byte()
    4
  }
}
