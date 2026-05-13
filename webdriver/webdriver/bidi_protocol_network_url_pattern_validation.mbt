///|
/// Validate one network urlPatterns entry.
fn validate_network_intercept_url_pattern_entry(entry : Json) -> Json? {
  let map = match entry {
    Object(map) => map
    _ => return None
  }
  let pattern_type = match map.get("type") {
    Some(String(name)) => name
    _ => return None
  }
  if pattern_type == "string" {
    match map.get("pattern") {
      Some(String(pattern)) =>
        if is_valid_network_string_url_pattern(pattern) {
          return Some(entry)
        } else {
          return None
        }
      _ => return None
    }
  }
  if pattern_type == "pattern" {
    if is_valid_network_pattern_url_pattern(map) {
      return Some(entry)
    }
  }
  None
}

///|
/// Reject reserved wildcard-like characters when not escaped.
fn has_unescaped_pattern_special_char(value : String) -> Bool {
  value.contains("*") ||
  value.contains("(") ||
  value.contains(")") ||
  value.contains("{") ||
  value.contains("}")
}

///|
/// Validate protocol token (`http`, `HTTPS`, optional trailing `:`).
fn is_valid_network_pattern_protocol_value(value : String) -> Bool {
  if value.length() == 0 {
    return false
  }
  if value.contains("\\") ||
    value.contains("/") ||
    value.contains("#") ||
    value.contains("@") ||
    value.contains("%") {
    return false
  }
  let chars = value.to_array()
  let mut colon_count = 0
  let mut colon_idx = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == ':' {
      colon_count += 1
      colon_idx = i
    }
  }
  if colon_count > 1 {
    return false
  }
  let scheme = if colon_count == 1 {
    if colon_idx != chars.length() - 1 {
      return false
    }
    value.unsafe_substring(start=0, end=colon_idx)
  } else {
    value
  }
  if scheme.length() == 0 {
    return false
  }
  let scheme_chars = scheme.to_array()
  if !is_ascii_alpha(scheme_chars[0]) {
    return false
  }
  for i = 1; i < scheme_chars.length(); i = i + 1 {
    let c = scheme_chars[i]
    if !(is_ascii_alnum(c) || c == '+' || c == '-' || c == '.') {
      return false
    }
  }
  true
}
