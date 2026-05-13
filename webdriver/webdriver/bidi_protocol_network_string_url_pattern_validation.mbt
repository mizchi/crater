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
