///|
/// SVG data URI decoding helpers for raster image rendering.

///|
fn decode_svg_data_uri(src : String) -> String {
  let prefixes = [
    "data:image/svg+xml,", "data:image/svg+xml;utf8,", "data:image/svg+xml;charset=utf-8,",
  ]
  for prefix in prefixes {
    if src.has_prefix(prefix) {
      let encoded = src.unsafe_substring(
        start=prefix.length(),
        end=src.length(),
      )
      return url_decode_simple(encoded)
    }
  }
  ""
}

///|
fn url_decode_simple(s : String) -> String {
  let buf = StringBuilder::new()
  let chars = s.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    if chars[i] == '%' && i + 2 < len {
      let hi = hex_digit(chars[i + 1])
      let lo = hex_digit(chars[i + 2])
      if hi >= 0 && lo >= 0 {
        buf.write_char((hi * 16 + lo).unsafe_to_char())
        i = i + 3
        continue
      }
    }
    buf.write_char(chars[i])
    i = i + 1
  }
  buf.to_string()
}

///|
fn hex_digit(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    -1
  }
}
