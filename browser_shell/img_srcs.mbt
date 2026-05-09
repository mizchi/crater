///|
fn make_substr(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end && i < chars.length(); i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn ascii_eq_ignore_case(lhs : Char, rhs : Char) -> Bool {
  lhs.to_ascii_lowercase() == rhs.to_ascii_lowercase()
}

///|
fn is_img_tag_start(chars : Array[Char], i : Int) -> Bool {
  if i + 4 >= chars.length() {
    return false
  }
  chars[i] == '<' &&
  ascii_eq_ignore_case(chars[i + 1], 'i') &&
  ascii_eq_ignore_case(chars[i + 2], 'm') &&
  ascii_eq_ignore_case(chars[i + 3], 'g') &&
  (
    chars[i + 4].is_ascii_whitespace() ||
    chars[i + 4] == '>' ||
    chars[i + 4] == '/'
  )
}

///|
fn is_html_attr_name_char(c : Char) -> Bool {
  !(c.is_ascii_whitespace() || c == '=' || c == '>' || c == '/')
}

///|
fn is_src_attr_name(chars : Array[Char], start : Int, end : Int) -> Bool {
  end - start == 3 &&
  ascii_eq_ignore_case(chars[start], 's') &&
  ascii_eq_ignore_case(chars[start + 1], 'r') &&
  ascii_eq_ignore_case(chars[start + 2], 'c')
}

///|
fn read_html_attr_value(chars : Array[Char], start : Int) -> (String, Int)? {
  if start >= chars.length() {
    return None
  }
  let quote = chars[start]
  if quote == '"' || quote == '\'' {
    let value_start = start + 1
    for i = value_start; i < chars.length(); i = i + 1 {
      if chars[i] == quote {
        return Some((make_substr(chars, value_start, i), i + 1))
      }
    }
    None
  } else {
    let mut value_end = start
    while value_end < chars.length() &&
          !chars[value_end].is_ascii_whitespace() &&
          chars[value_end] != '>' {
      value_end = value_end + 1
    }
    if value_end > start {
      Some((make_substr(chars, start, value_end), value_end))
    } else {
      None
    }
  }
}

///|
/// Extract img src attributes from HTML without requiring a full DOM parse.
pub fn extract_img_srcs(html : String) -> Array[String] {
  let srcs : Array[String] = []
  let chars = html.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    if is_img_tag_start(chars, i) {
      let mut j = i + 4
      while j < len && chars[j] != '>' {
        while j < len && chars[j].is_ascii_whitespace() {
          j = j + 1
        }
        if j >= len || chars[j] == '>' {
          break
        }
        if chars[j] == '/' {
          j = j + 1
          continue
        }
        let name_start = j
        while j < len && is_html_attr_name_char(chars[j]) {
          j = j + 1
        }
        let name_end = j
        while j < len && chars[j].is_ascii_whitespace() {
          j = j + 1
        }
        if j < len && chars[j] == '=' {
          j = j + 1
          while j < len && chars[j].is_ascii_whitespace() {
            j = j + 1
          }
          match read_html_attr_value(chars, j) {
            Some((value, next_idx)) => {
              if is_src_attr_name(chars, name_start, name_end) {
                srcs.push(value)
              }
              j = next_idx
            }
            None => ()
          }
        }
      }
      i = j
    } else {
      i = i + 1
    }
  }
  srcs
}
