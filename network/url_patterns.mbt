///|
pub(all) struct CanonicalNetworkHttpUrl {
  scheme : String
  host : String
  port : Int
  path : String
  query : String
}

///|
pub fn network_intercept_matches_phase(
  options : Map[String, Json],
  phase : String,
) -> Bool {
  match options.get("phases") {
    Some(Array(phases)) =>
      for item in phases {
        match item {
          String(name) if name == phase => return true
          _ => ()
        }
      }
    _ => ()
  }
  false
}

///|
pub fn network_option_contexts_match(
  options : Map[String, Json],
  ancestry : Array[String],
) -> Bool {
  match options.get("contexts") {
    Some(Array(contexts)) => {
      if contexts.length() == 0 {
        return true
      }
      for item in contexts {
        match item {
          String(ctx_id) if array_contains_string(ancestry, ctx_id) =>
            return true
          _ => ()
        }
      }
      false
    }
    _ => true
  }
}

///|
pub fn network_url_patterns_match(
  options : Map[String, Json],
  url : String,
) -> Bool {
  match options.get("urlPatterns") {
    Some(Array(patterns)) => {
      if patterns.length() == 0 {
        return true
      }
      for entry in patterns {
        if network_url_pattern_entry_matches(entry, url) {
          return true
        }
      }
      false
    }
    _ => true
  }
}

///|
fn network_url_pattern_entry_matches(entry : Json, url : String) -> Bool {
  match entry {
    Object(map) =>
      match map.get("type") {
        Some(String("string")) =>
          match map.get("pattern") {
            Some(String(pattern)) =>
              network_string_url_pattern_matches(pattern, url)
            _ => false
          }
        Some(String("pattern")) => network_object_url_pattern_matches(map, url)
        _ => false
      }
    _ => false
  }
}

///|
fn network_string_url_pattern_matches(
  pattern_url : String,
  target_url : String,
) -> Bool {
  match
    (
      canonicalize_network_http_url(pattern_url),
      canonicalize_network_http_url(target_url),
    ) {
    (Some(pattern), Some(target)) =>
      pattern.scheme == target.scheme &&
      pattern.host == target.host &&
      pattern.port == target.port &&
      pattern.path == target.path &&
      pattern.query == target.query
    _ => pattern_url == target_url
  }
}

///|
fn network_object_url_pattern_matches(
  pattern : Map[String, Json],
  target_url : String,
) -> Bool {
  let target = match canonicalize_network_http_url(target_url) {
    Some(target) => target
    None => return false
  }
  let target_path_token = if target.path.has_prefix("/") {
    target.path.unsafe_substring(start=1, end=target.path.length())
  } else {
    target.path
  }
  match pattern.get("protocol") {
    Some(String(protocol)) =>
      if normalize_network_pattern_protocol(protocol) != target.scheme {
        return false
      }
    _ => ()
  }
  match pattern.get("hostname") {
    Some(String(hostname)) =>
      if hostname.to_lower() != target.host {
        return false
      }
    _ => ()
  }
  match pattern.get("port") {
    Some(String(port)) => if port != target.port.to_string() { return false }
    _ => ()
  }
  match pattern.get("pathname") {
    Some(String(pathname)) =>
      if pathname == "" {
        if target.path != "" && target.path != "/" {
          return false
        }
      } else if pathname.has_prefix("/") {
        if target.path != pathname {
          return false
        }
      } else if target_path_token != pathname {
        return false
      }
    _ => ()
  }
  match pattern.get("search") {
    Some(String(search)) =>
      if search == "" {
        if target.query != "" {
          return false
        }
      } else if target.query != search {
        return false
      }
    _ => ()
  }
  true
}

///|
pub fn canonicalize_network_http_url(url : String) -> CanonicalNetworkHttpUrl? {
  let scheme = match extract_network_url_scheme(url) {
    Some(scheme) =>
      if scheme == "http" || scheme == "https" {
        scheme
      } else {
        return None
      }
    None => return None
  }
  let authority = match extract_http_url_authority(url) {
    Some(authority) => authority
    None => return None
  }
  let host_port = extract_authority_host_port(authority)
  let (host, port) = match parse_network_host_and_port(host_port, scheme) {
    Some(result) => result
    None => return None
  }
  let path = extract_http_url_path(url).unwrap_or("/")
  let query = extract_network_url_query(url)
  Some({ scheme, host, port, path, query })
}

///|
fn extract_network_url_scheme(url : String) -> String? {
  match find_substring(url, "://", 0) {
    Some(idx) => Some(url.unsafe_substring(start=0, end=idx).to_lower())
    None => None
  }
}

///|
fn parse_network_host_and_port(
  host_port : String,
  scheme : String,
) -> (String, Int)? {
  if host_port == "" {
    return None
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
  if colon_count > 1 {
    return None
  }
  if colon_idx < 0 {
    return Some((host_port.to_lower(), default_port_for_network_scheme(scheme)))
  }
  let host = host_port.unsafe_substring(start=0, end=colon_idx)
  let port_text = host_port.unsafe_substring(
    start=colon_idx + 1,
    end=host_port.length(),
  )
  let port = match parse_decimal_string(port_text) {
    Some(port) => port
    None => return None
  }
  if host == "" || port < 0 || port > 65535 {
    return None
  }
  Some((host.to_lower(), port))
}

///|
fn default_port_for_network_scheme(scheme : String) -> Int {
  if scheme == "https" {
    443
  } else {
    80
  }
}

///|
pub fn extract_network_url_query(url : String) -> String {
  let without_fragment = strip_url_fragment(url)
  match find_substring(without_fragment, "?", 0) {
    Some(idx) =>
      without_fragment.unsafe_substring(
        start=idx + 1,
        end=without_fragment.length(),
      )
    None => ""
  }
}

///|
fn normalize_network_pattern_protocol(protocol : String) -> String {
  if protocol.has_suffix(":") {
    protocol.unsafe_substring(start=0, end=protocol.length() - 1).to_lower()
  } else {
    protocol.to_lower()
  }
}

///|
fn extract_http_url_authority(url : String) -> String? {
  match find_substring(url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let chars = url.to_array()
      let mut host_end = chars.length()
      for i = host_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '/' || ch == '?' || ch == '#' {
          host_end = i
          break
        }
      }
      if host_start >= host_end {
        None
      } else {
        Some(url.unsafe_substring(start=host_start, end=host_end))
      }
    }
    None => None
  }
}

///|
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
fn extract_http_url_path(url : String) -> String? {
  match find_substring(url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let chars = url.to_array()
      let mut path_start = chars.length()
      for i = host_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '/' {
          path_start = i
          break
        }
        if ch == '?' || ch == '#' {
          return Some("/")
        }
      }
      if path_start >= chars.length() {
        return Some("/")
      }
      let mut path_end = chars.length()
      for i = path_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '?' || ch == '#' {
          path_end = i
          break
        }
      }
      Some(url.unsafe_substring(start=path_start, end=path_end))
    }
    None => None
  }
}

///|
fn strip_url_fragment(url : String) -> String {
  match find_substring(url, "#", 0) {
    Some(idx) => url.unsafe_substring(start=0, end=idx)
    None => url
  }
}

///|
fn find_substring(haystack : String, needle : String, start : Int) -> Int? {
  if needle.length() == 0 || start < 0 || start >= haystack.length() {
    return None
  }
  let hay_chars = haystack.to_array()
  let needle_chars = needle.to_array()
  if needle_chars.length() > hay_chars.length() {
    return None
  }
  for i = start; i <= hay_chars.length() - needle_chars.length(); i = i + 1 {
    let mut matched = true
    for j = 0; j < needle_chars.length(); j = j + 1 {
      if hay_chars[i + j] != needle_chars[j] {
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
fn parse_decimal_string(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }
  let mut parsed = 0
  for c in value.iter() {
    if c < '0' || c > '9' {
      return None
    }
    parsed = parsed * 10 + (c.to_int() - '0'.to_int())
  }
  Some(parsed)
}

///|
fn array_contains_string(items : Array[String], target : String) -> Bool {
  for item in items {
    if item == target {
      return true
    }
  }
  false
}
