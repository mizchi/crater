///|
priv struct CanonicalNetworkHttpUrl {
  scheme : String
  host : String
  port : Int
  path : String
  query : String
}

///|
fn BidiProtocol::handle_network_allocate_request_id(
  self : BidiProtocol,
  request_id : Int,
  _params : Json?,
) -> Unit {
  self.send_success(
    request_id,
    Some(
      make_object({
        "request": Json::string(self.next_synthetic_network_request_id()),
      }),
    ),
  )
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
fn BidiProtocol::handle_network_remember_collected_data(
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
  let request_token = match map.get("request") {
    Some(String(request_token)) => request_token
    _ => {
      self.send_error(
        request_id, "invalid argument", "request must be a string",
      )
      return
    }
  }
  let request_value = match
    get_map_field_with_alias(map, "requestData", "request_data") {
    Some(raw_value) =>
      match
        self.normalize_synthetic_network_bytes_value(
          request_id, raw_value, "requestData",
        ) {
        Some(value) => Some(value)
        None => return
      }
    None => None
  }
  let response_value = match
    get_map_field_with_alias(map, "responseData", "response_data") {
    Some(raw_value) =>
      match
        self.normalize_synthetic_network_bytes_value(
          request_id, raw_value, "responseData",
        ) {
        Some(value) => Some(value)
        None => return
      }
    None => None
  }

  self.remember_network_collected_data_internal(
    context_id, request_token, request_value, response_value,
  )
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::handle_network_get_data(
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
  let request_token = match map.get("request") {
    Some(String(request_token)) => request_token
    _ => {
      self.send_error(
        request_id, "invalid argument", "request must be a string",
      )
      return
    }
  }
  let data_type = match get_map_field_with_alias(map, "dataType", "data_type") {
    Some(String(data_type)) =>
      if data_type == "request" || data_type == "response" {
        data_type
      } else {
        self.send_error(request_id, "invalid argument", "dataType is invalid")
        return
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "dataType must be a string",
      )
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing dataType")
      return
    }
  }
  let collector_id : String? = match map.get("collector") {
    Some(Null) | None => None
    Some(String(collector_id)) => Some(collector_id)
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "collector must be a string",
      )
      return
    }
  }
  let disown = match map.get("disown") {
    Some(True) => true
    Some(False) | None => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "disown must be a boolean",
      )
      return
    }
  }
  if disown && collector_id == None {
    self.send_error(
      request_id, "invalid argument", "disown=true requires collector",
    )
    return
  }
  let request_bucket = match self.network_collected_data.get(request_token) {
    Some(request_bucket) => request_bucket
    None => {
      self.send_error(
        request_id,
        "no such network data",
        "Unknown request id: " + request_token,
      )
      return
    }
  }
  let (selected_collector, result) = match collector_id {
    Some(collector_id) => {
      if not(self.network_data_collectors.contains(collector_id)) {
        self.send_error(
          request_id,
          "no such network collector",
          "Unknown collector: " + collector_id,
        )
        return
      }
      match request_bucket.get(collector_id) {
        Some(collector_bucket) =>
          match collector_bucket.get(data_type) {
            Some(result) => (collector_id, result)
            None => {
              self.send_error(
                request_id,
                "no such network data",
                "No collected " + data_type + " for request: " + request_token,
              )
              return
            }
          }
        None => {
          self.send_error(
            request_id,
            "no such network data",
            "No collected " + data_type + " for request: " + request_token,
          )
          return
        }
      }
    }
    None => {
      let mut found : (String, Json)? = None
      for candidate_collector in self.list_active_network_collector_ids() {
        match request_bucket.get(candidate_collector) {
          Some(collector_bucket) =>
            match collector_bucket.get(data_type) {
              Some(result) => {
                found = Some((candidate_collector, result))
                break
              }
              None => ()
            }
          None => ()
        }
      }
      match found {
        Some(found) => found
        None => {
          self.send_error(
            request_id,
            "no such network data",
            "No collected " + data_type + " for request: " + request_token,
          )
          return
        }
      }
    }
  }
  if disown {
    match self.network_collected_data.get(request_token) {
      Some(bucket) =>
        match bucket.get(selected_collector) {
          Some(collector_bucket) => {
            let next_collector_bucket = collector_bucket
            next_collector_bucket.remove(data_type)
            let next_bucket = bucket
            if next_collector_bucket.length() == 0 {
              next_bucket.remove(selected_collector)
            } else {
              next_bucket[selected_collector] = next_collector_bucket
            }
            if next_bucket.length() == 0 {
              self.network_collected_data.remove(request_token)
            } else {
              self.network_collected_data[request_token] = next_bucket
            }
          }
          None => ()
        }
      None => ()
    }
  }
  self.send_success(request_id, Some(result))
}

///|
fn BidiProtocol::handle_network_disown_data(
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
  let request_token = match map.get("request") {
    Some(String(request_token)) => request_token
    _ => {
      self.send_error(
        request_id, "invalid argument", "request must be a string",
      )
      return
    }
  }
  let data_type = match get_map_field_with_alias(map, "dataType", "data_type") {
    Some(String(data_type)) =>
      if data_type == "request" || data_type == "response" {
        data_type
      } else {
        self.send_error(request_id, "invalid argument", "dataType is invalid")
        return
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "dataType must be a string",
      )
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing dataType")
      return
    }
  }
  let collector_id = match map.get("collector") {
    Some(String(collector_id)) => collector_id
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "collector must be a string",
      )
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing collector")
      return
    }
  }
  if not(self.network_data_collectors.contains(collector_id)) {
    self.send_error(
      request_id,
      "no such network collector",
      "Unknown collector: " + collector_id,
    )
    return
  }
  let request_bucket = match self.network_collected_data.get(request_token) {
    Some(request_bucket) => request_bucket
    None => {
      self.send_error(
        request_id,
        "no such network data",
        "Unknown request id: " + request_token,
      )
      return
    }
  }
  let collector_bucket = match request_bucket.get(collector_id) {
    Some(collector_bucket) => collector_bucket
    None => {
      self.send_error(
        request_id,
        "no such network data",
        "No collected " + data_type + " for request: " + request_token,
      )
      return
    }
  }
  if not(collector_bucket.contains(data_type)) {
    self.send_error(
      request_id,
      "no such network data",
      "No collected " + data_type + " for request: " + request_token,
    )
    return
  }
  let next_collector_bucket = collector_bucket
  next_collector_bucket.remove(data_type)
  let next_bucket = request_bucket
  if next_collector_bucket.length() == 0 {
    next_bucket.remove(collector_id)
  } else {
    next_bucket[collector_id] = next_collector_bucket
  }
  if next_bucket.length() == 0 {
    self.network_collected_data.remove(request_token)
  } else {
    self.network_collected_data[request_token] = next_bucket
  }
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::list_active_network_intercept_ids(
  self : BidiProtocol,
) -> Array[String] {
  let ids : Array[String] = []
  for i = 1; i < self.next_network_intercept_id; i = i + 1 {
    let intercept_id = left_pad_with_zero(i.to_string(), 32)
    if self.network_intercepts.contains(intercept_id) {
      ids.push(intercept_id)
    }
  }
  ids
}

///|
fn BidiProtocol::next_synthetic_network_request_id(
  self : BidiProtocol,
) -> String {
  let request_id = "request-" + self.next_network_request_id.to_string()
  self.next_network_request_id += 1
  request_id
}

///|
fn BidiProtocol::remember_network_collected_data_internal(
  self : BidiProtocol,
  context_id : String,
  request_token : String,
  request_value : Json?,
  response_value : Json?,
) -> Unit {
  let request_bucket = self.network_collected_data
    .get(request_token)
    .unwrap_or({})
  let ancestry = self.build_context_scope_ancestry_for_matching(context_id)
  let user_context = self.context_user_context
    .get(context_id)
    .unwrap_or("default")
  let next_bucket = request_bucket
  for collector_id in self.list_active_network_collector_ids() {
    match self.network_data_collectors.get(collector_id) {
      Some(Object(options)) =>
        if network_collector_matches_scope(options, ancestry, user_context) {
          let collector_bucket = next_bucket.get(collector_id).unwrap_or({})
          let data_types = network_collector_data_types(options)
          let max_size = network_collector_max_encoded_size(options)
          let next_collector_bucket = collector_bucket
          match request_value {
            Some(request_data) =>
              if array_contains_string(data_types, "request") &&
                network_bytes_value_encoded_size(request_data) <= max_size {
                next_collector_bucket["request"] = request_data
              }
            None => ()
          }
          match response_value {
            Some(response_data) =>
              if array_contains_string(data_types, "response") &&
                network_bytes_value_encoded_size(response_data) <= max_size {
                next_collector_bucket["response"] = response_data
              }
            None => ()
          }
          if next_collector_bucket.length() > 0 {
            next_bucket[collector_id] = next_collector_bucket
          }
        }
      _ => ()
    }
  }
  self.network_collected_data[request_token] = next_bucket
}

///|
fn BidiProtocol::list_active_network_collector_ids(
  self : BidiProtocol,
) -> Array[String] {
  let ids : Array[String] = []
  for i = 1; i < self.next_network_data_collector_id; i = i + 1 {
    let collector_id = "collector-" + i.to_string()
    if self.network_data_collectors.contains(collector_id) {
      ids.push(collector_id)
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
  if ctx_id != "" && not(array_contains_string(ancestry, ctx_id)) {
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
    match self.network_intercepts.get(intercept_id) {
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
    target.path[1:].to_string()
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
    Some(idx) => Some(url[:idx].to_string().to_lower())
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
  let host = host_port[:colon_idx].to_string()
  let port_text = host_port[colon_idx + 1:].to_string()
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
    Some(idx) => without_fragment[idx + 1:].to_string()
    None => ""
  }
}

///|
fn normalize_network_pattern_protocol(protocol : String) -> String {
  if protocol.has_suffix(":") {
    protocol[:protocol.length() - 1].to_string().to_lower()
  } else {
    protocol.to_lower()
  }
}

///|
fn network_collector_matches_scope(
  options : Map[String, Json],
  ancestry : Array[String],
  user_context : String,
) -> Bool {
  match options.get("contexts") {
    Some(Array(contexts)) =>
      if contexts.length() > 0 {
        let mut matched = false
        for item in contexts {
          match item {
            String(ctx_id) if array_contains_string(ancestry, ctx_id) => {
              matched = true
              break
            }
            _ => ()
          }
        }
        if not(matched) {
          return false
        }
      }
    _ => ()
  }
  match options.get("userContexts") {
    Some(Array(user_contexts)) =>
      if user_contexts.length() > 0 {
        let mut matched = false
        for item in user_contexts {
          match item {
            String(candidate) if candidate == user_context => {
              matched = true
              break
            }
            _ => ()
          }
        }
        if not(matched) {
          return false
        }
      }
    _ => ()
  }
  true
}

///|
fn network_collector_data_types(options : Map[String, Json]) -> Array[String] {
  let data_types : Array[String] = []
  match options.get("dataTypes") {
    Some(Array(items)) =>
      for item in items {
        match item {
          String(name) => data_types.push(name)
          _ => ()
        }
      }
    _ => ()
  }
  data_types
}

///|
fn network_collector_max_encoded_size(options : Map[String, Json]) -> Int {
  match options.get("maxEncodedDataSize") {
    Some(Number(n, ..)) => n.to_int()
    _ => 1000
  }
}

///|
fn network_bytes_value_encoded_size(value : Json) -> Int {
  match value {
    Object(map) =>
      match map.get("value") {
        Some(String(payload)) => js_utf8_byte_length(payload)
        _ => 0
      }
    _ => 0
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
