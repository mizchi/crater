///|
#cfg(not(target="js"))
let base64_chars : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
#cfg(not(target="js"))
fn write_base64_quad(
  buf : StringBuilder,
  b0 : Int,
  b1 : Int,
  b2 : Int,
  padding : Int,
) -> Unit {
  let c0 = (b0 >> 2) & 0x3F
  let c1 = ((b0 << 4) | (b1 >> 4)) & 0x3F
  let c2 = ((b1 << 2) | (b2 >> 6)) & 0x3F
  let c3 = b2 & 0x3F
  buf.write_char(base64_chars[c0].unsafe_to_char())
  buf.write_char(base64_chars[c1].unsafe_to_char())
  if padding >= 2 {
    buf.write_char('=')
  } else {
    buf.write_char(base64_chars[c2].unsafe_to_char())
  }
  if padding >= 1 {
    buf.write_char('=')
  } else {
    buf.write_char(base64_chars[c3].unsafe_to_char())
  }
}

///|
#cfg(not(target="js"))
fn encode_bytes_base64(bytes : Array[Int]) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < bytes.length() {
    let b0 = bytes[i]
    let remaining = bytes.length() - i
    if remaining >= 3 {
      write_base64_quad(out, b0, bytes[i + 1], bytes[i + 2], 0)
      i = i + 3
    } else if remaining == 2 {
      write_base64_quad(out, b0, bytes[i + 1], 0, 1)
      i = i + 2
    } else {
      write_base64_quad(out, b0, 0, 0, 2)
      i = i + 1
    }
  }
  out.to_string()
}
