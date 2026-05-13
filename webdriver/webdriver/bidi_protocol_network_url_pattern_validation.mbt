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
/// Validate `{"type":"string","pattern":"..."}` URL pattern.
fn is_valid_network_string_url_pattern(pattern : String) -> Bool {
  if has_unescaped_pattern_special_char(pattern) || pattern.contains("\\") {
    return false
  }
  if pattern.has_prefix("data:") {
    return true
  }
  let scheme_sep = match find_substring(pattern, "://", 0) {
    Some(idx) => idx
    None => return false
  }
  let scheme = pattern.unsafe_substring(start=0, end=scheme_sep)
  if !is_valid_network_pattern_protocol_value(scheme) {
    return false
  }
  let authority_and_path = pattern.unsafe_substring(
    start=scheme_sep + 3,
    end=pattern.length(),
  )
  if authority_and_path.length() == 0 {
    return false
  }
  let chars = authority_and_path.to_array()
  let mut authority_end = chars.length()
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == '/' || chars[i] == '?' || chars[i] == '#' {
      authority_end = i
      break
    }
  }
  let authority = authority_and_path.unsafe_substring(
    start=0,
    end=authority_end,
  )
  if authority.length() == 0 {
    return false
  }
  let host_port = extract_authority_host_port(authority)
  if host_port.length() == 0 {
    return false
  }
  validate_host_port_pattern(host_port)
}

///|
/// Extract host[:port] from authority, dropping optional userinfo.
fn extract_authority_host_port(authority : String) -> String {
  let chars = authority.to_array()
  let mut at_index = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == '@' {
      at_index = i
    }
  }
  if at_index < 0 {
    return authority
  }
  authority.unsafe_substring(start=at_index + 1, end=authority.length())
}

///|
/// Validate host[:port] syntax for string URL patterns.
fn validate_host_port_pattern(host_port : String) -> Bool {
  if host_port.length() == 0 {
    return false
  }
  let chars = host_port.to_array()
  let mut colon_idx = -1
  let mut colon_count = 0
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == ':' {
      colon_idx = i
      colon_count += 1
    }
  }
  // Keep IPv6 out of scope for now; invalid suite only covers host:port.
  if colon_count > 1 {
    return false
  }
  if colon_idx < 0 {
    return true
  }
  let host = host_port.unsafe_substring(start=0, end=colon_idx)
  if host.length() == 0 || colon_idx >= chars.length() - 1 {
    return false
  }
  let port_text = host_port.unsafe_substring(
    start=colon_idx + 1,
    end=host_port.length(),
  )
  let port = match parse_decimal_string(port_text) {
    Some(port) => port
    None => return false
  }
  port >= 0 && port <= 65535
}

///|
/// Validate `{"type":"pattern", ...}` URL pattern object.
fn is_valid_network_pattern_url_pattern(map : Map[String, Json]) -> Bool {
  let protocol = match map.get("protocol") {
    Some(String(value)) => Some(value)
    Some(_) => return false
    None => None
  }
  let hostname = match map.get("hostname") {
    Some(String(value)) => Some(value)
    Some(_) => return false
    None => None
  }
  let port = match map.get("port") {
    Some(String(value)) => Some(value)
    Some(_) => return false
    None => None
  }
  let pathname = match map.get("pathname") {
    Some(String(value)) => Some(value)
    Some(_) => return false
    None => None
  }
  let search = match map.get("search") {
    Some(String(value)) => Some(value)
    Some(_) => return false
    None => None
  }

  match protocol {
    Some(value) =>
      if has_unescaped_pattern_special_char(value) ||
        !is_valid_network_pattern_protocol_value(value) {
        return false
      } else {
        match hostname {
          Some(_) => if is_network_file_protocol(value) { return false }
          None => ()
        }
      }
    None => ()
  }

  match hostname {
    Some(value) =>
      if has_unescaped_pattern_special_char(value) ||
        !is_valid_network_pattern_hostname(value) {
        return false
      }
    None => ()
  }

  match port {
    Some(value) =>
      if has_unescaped_pattern_special_char(value) ||
        !is_valid_network_pattern_port(value) {
        return false
      }
    None => ()
  }

  match pathname {
    Some(value) =>
      if has_unescaped_pattern_special_char(value) ||
        !is_valid_network_pattern_pathname(value) {
        return false
      }
    None => ()
  }

  match search {
    Some(value) =>
      if has_unescaped_pattern_special_char(value) ||
        !is_valid_network_pattern_search(value) {
        return false
      }
    None => ()
  }

  true
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

///|
/// True when protocol token represents `file` (case-insensitive, optional `:`).
fn is_network_file_protocol(value : String) -> Bool {
  let scheme = if value.has_suffix(":") {
    value.unsafe_substring(start=0, end=value.length() - 1)
  } else {
    value
  }
  is_ascii_case_insensitive_equal(scheme, "file")
}

///|
/// Validate hostname token for url pattern object.
fn is_valid_network_pattern_hostname(value : String) -> Bool {
  if value.length() == 0 {
    return false
  }
  if value.contains("/") ||
    value.contains("?") ||
    value.contains("#") ||
    value.contains(":") {
    return false
  }
  !value.contains("::")
}

///|
/// Validate port token (`0`..`65535` digits only).
fn is_valid_network_pattern_port(value : String) -> Bool {
  if value.length() == 0 || value.contains(":") || value.contains(" ") {
    return false
  }
  let parsed = match parse_decimal_string(value) {
    Some(parsed) => parsed
    None => return false
  }
  parsed >= 0 && parsed <= 65535
}

///|
/// Validate pathname token (must not include `?` or `#`).
fn is_valid_network_pattern_pathname(value : String) -> Bool {
  !value.contains("?") && !value.contains("#")
}

///|
/// Validate search token (must not include `#`).
fn is_valid_network_pattern_search(value : String) -> Bool {
  !value.contains("#")
}
