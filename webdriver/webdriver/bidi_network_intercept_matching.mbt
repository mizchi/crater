///|
priv struct CanonicalNetworkHttpUrl {
  scheme : String
  host : String
  port : Int
  path : String
  query : String
}

///|
fn BidiProtocol::handle_network_resolve_matching_intercepts(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let context_id = match map.get("context") {
    Some(String(context_id)) => context_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  let phase = match map.get("phase") {
    Some(String(phase)) =>
      if is_valid_network_intercept_phase(phase) {
        phase
      } else {
        self.send_error(request_id, "invalid argument", "phase is invalid")
        return
      }
    _ => {
      self.send_error(request_id, "invalid argument", "phase must be a string")
      return
    }
  }
  let url = match map.get("url") {
    Some(String(url)) => url
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return
    }
  }
  let intercepts : Array[Json] = []
  for
    intercept_id in self.resolve_matching_network_intercepts_internal(
      context_id, phase, url,
    ) {
    intercepts.push(Json::string(intercept_id))
  }
  self.send_success(
    request_id,
    Some(make_object({ "intercepts": Json::array(intercepts) })),
  )
}

///|
fn BidiProtocol::list_active_network_intercept_ids(
  self : BidiProtocol,
) -> Array[String] {
  let ids : Array[String] = []
  for i = 1; i < self.network_state.next_network_intercept_id; i = i + 1 {
    let intercept_id = left_pad_with_zero(i.to_string(), 32)
    if self.network_state.network_intercepts.contains(intercept_id) {
      ids.push(intercept_id)
    }
  }
  ids
}

///|
fn BidiProtocol::build_context_scope_ancestry_for_matching(
  self : BidiProtocol,
  ctx_id : String,
) -> Array[String] {
  let ancestry = if self.manager.has_session(ctx_id) {
    self.build_context_ancestry(ctx_id)
  } else {
    []
  }
  if ctx_id != "" && !array_contains_string(ancestry, ctx_id) {
    ancestry.push(ctx_id)
  }
  ancestry
}

///|
fn BidiProtocol::resolve_matching_network_intercepts_internal(
  self : BidiProtocol,
  context_id : String,
  phase : String,
  url : String,
) -> Array[String] {
  let intercepts : Array[String] = []
  let ancestry = self.build_context_scope_ancestry_for_matching(context_id)
  for intercept_id in self.list_active_network_intercept_ids() {
    match self.network_state.network_intercepts.get(intercept_id) {
      Some(Object(options)) =>
        if network_intercept_matches_phase(options, phase) &&
          network_option_contexts_match(options, ancestry) &&
          network_url_patterns_match(options, url) {
          intercepts.push(intercept_id)
        }
      _ => ()
    }
  }
  intercepts
}

///|
fn network_intercept_matches_phase(
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
fn network_option_contexts_match(
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
fn network_url_patterns_match(
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
fn canonicalize_network_http_url(url : String) -> CanonicalNetworkHttpUrl? {
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
fn extract_network_url_query(url : String) -> String {
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
fn array_contains_string(items : Array[String], target : String) -> Bool {
  for item in items {
    if item == target {
      return true
    }
  }
  false
}
