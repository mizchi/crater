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
