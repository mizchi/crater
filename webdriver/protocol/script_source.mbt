///|
/// Pure helpers for parsing BiDi script source strings.

///|
/// Find substring position in a string from a start offset.
pub fn find_substring(haystack : String, needle : String, start : Int) -> Int? {
  let h = haystack.to_array()
  let n = needle.to_array()
  if n.length() == 0 {
    return Some(start)
  }
  if start < 0 || start >= h.length() || n.length() > h.length() {
    return None
  }
  for i = start; i + n.length() <= h.length(); i = i + 1 {
    let mut matched = true
    for j = 0; j < n.length(); j = j + 1 {
      if h[i + j] != n[j] {
        matched = false
        break
      }
    }
    if matched {
      return Some(i)
    }
  }
  None
}

///|
/// Extract quoted URL argument following a marker like "new Worker(".
pub fn extract_quoted_after_marker(source : String, marker : String) -> String? {
  match find_substring(source, marker, 0) {
    Some(marker_idx) => {
      let chars = source.to_array()
      let quote_start = marker_idx + marker.length()
      if quote_start >= chars.length() {
        return None
      }
      let quote = chars[quote_start]
      if quote != '"' && quote != '\'' {
        return None
      }
      let mut end = quote_start + 1
      while end < chars.length() && chars[end] != quote {
        end += 1
      }
      if end >= chars.length() {
        return None
      }
      let value = source.unsafe_substring(start=quote_start + 1, end~)
      if value.length() == 0 {
        None
      } else {
        Some(value)
      }
    }
    None => None
  }
}
