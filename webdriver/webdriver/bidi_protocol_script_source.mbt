///|
/// Compatibility facade for the canonical find_substring in @protocol.
fn find_substring(haystack : String, needle : String, start : Int) -> Int? {
  @protocol.find_substring(haystack, needle, start)
}

///|
/// Compatibility facade for the canonical extract_quoted_after_marker in @protocol.
fn extract_quoted_after_marker(source : String, marker : String) -> String? {
  @protocol.extract_quoted_after_marker(source, marker)
}

///|
/// Extract second quoted URL/string argument following marker like "prompt(".
fn extract_second_quoted_after_marker(
  source : String,
  marker : String,
) -> String? {
  match find_substring(source, marker, 0) {
    Some(marker_idx) => {
      let chars = source.to_array()
      let mut cursor = marker_idx + marker.length()
      if cursor >= chars.length() {
        return None
      }
      let first_quote = chars[cursor]
      if first_quote != '"' && first_quote != '\'' {
        return None
      }
      cursor += 1
      while cursor < chars.length() && chars[cursor] != first_quote {
        cursor += 1
      }
      if cursor >= chars.length() {
        return None
      }
      cursor += 1
      while cursor < chars.length() &&
            (chars[cursor] == ' ' || chars[cursor] == '\t') {
        cursor += 1
      }
      if cursor >= chars.length() || chars[cursor] != ',' {
        return None
      }
      cursor += 1
      while cursor < chars.length() &&
            (chars[cursor] == ' ' || chars[cursor] == '\t') {
        cursor += 1
      }
      if cursor >= chars.length() {
        return None
      }
      let second_quote = chars[cursor]
      if second_quote != '"' && second_quote != '\'' {
        return None
      }
      let start = cursor + 1
      let mut end = start
      while end < chars.length() && chars[end] != second_quote {
        end += 1
      }
      if end >= chars.length() {
        return None
      }
      let value = source.unsafe_substring(start~, end~)
      if value.length() == 0 {
        Some("")
      } else {
        Some(value)
      }
    }
    None => None
  }
}

///|
/// Extract third quoted URL/string argument following a marker.
fn extract_third_quoted_after_marker(
  source : String,
  marker : String,
) -> String? {
  match find_substring(source, marker, 0) {
    Some(marker_idx) => {
      let chars = source.to_array()
      let mut cursor = marker_idx + marker.length()
      let mut quoted_index = 0
      while cursor < chars.length() {
        let ch = chars[cursor]
        if ch == '"' || ch == '\'' {
          let quote = ch
          let start = cursor + 1
          let mut end = start
          while end < chars.length() && chars[end] != quote {
            end += 1
          }
          if end >= chars.length() {
            return None
          }
          quoted_index += 1
          if quoted_index == 3 {
            let value = source.unsafe_substring(start~, end~)
            return Some(value)
          }
          cursor = end + 1
          continue
        }
        if ch == ')' {
          break
        }
        cursor += 1
      }
      None
    }
    None => None
  }
}
