///|
fn BidiProtocol::normalize_synthetic_network_header_entries(
  self : BidiProtocol,
  request_id : Int,
  raw_headers : Json?,
) -> Array[Json]? {
  match raw_headers {
    None | Some(Null) => Some([])
    Some(Array(items)) => {
      let headers : Array[Json] = []
      for item in items {
        match validate_network_extra_header_entry(item) {
          Some(header) => headers.push(header)
          None => {
            self.send_error(
              request_id, "invalid argument", "requestHeaders entry is invalid",
            )
            return None
          }
        }
      }
      Some(headers)
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "requestHeaders must be an array",
      )
      None
    }
  }
}

///|
fn BidiProtocol::apply_network_extra_headers_options(
  self : BidiProtocol,
  options : Map[String, Json],
) -> Unit {
  let normalized = match options.get("headers") {
    Some(Array(headers)) =>
      synthetic_network_header_string_map_from_entries(headers)
    _ => {}
  }
  match options.get("contexts") {
    Some(Array(items)) => {
      for item in items {
        match item {
          String(ctx_id) =>
            if normalized.length() == 0 {
              self.network_state.network_extra_headers_by_context.remove(ctx_id)
            } else {
              self.network_state.network_extra_headers_by_context[ctx_id] = synthetic_network_copy_string_map(
                normalized,
              )
            }
          _ => ()
        }
      }
      return
    }
    _ => ()
  }
  match options.get("userContexts") {
    Some(Array(items)) => {
      for item in items {
        match item {
          String(user_context_id) =>
            if normalized.length() == 0 {
              self.network_state.network_extra_headers_by_user_context.remove(
                user_context_id,
              )
            } else {
              self.network_state.network_extra_headers_by_user_context[user_context_id] = synthetic_network_copy_string_map(
                normalized,
              )
            }
          _ => ()
        }
      }
      return
    }
    _ => ()
  }
  synthetic_network_replace_string_map(
    self.network_state.network_extra_headers_global,
    normalized,
  )
}

///|
fn BidiProtocol::resolve_network_extra_header_entries(
  self : BidiProtocol,
  context_id : String,
  request_headers : Array[Json],
) -> Array[Json] {
  let merged : Map[String, String] = {}
  synthetic_network_merge_string_map(
    merged,
    self.network_state.network_extra_headers_global,
  )
  let user_context_id = self.resolve_storage_user_context(context_id)
  match
    self.network_state.network_extra_headers_by_user_context.get(
      user_context_id,
    ) {
    Some(headers) => synthetic_network_merge_string_map(merged, headers)
    None => ()
  }
  for scope_id in self.storage_context_ancestry(context_id) {
    match self.network_state.network_extra_headers_by_context.get(scope_id) {
      Some(headers) => synthetic_network_merge_string_map(merged, headers)
      None => ()
    }
  }
  synthetic_network_merge_string_map(
    merged,
    synthetic_network_header_string_map_from_entries(request_headers),
  )
  synthetic_network_header_entries_from_string_map(merged)
}

///|
fn BidiProtocol::build_network_headers_echo_payload(
  self : BidiProtocol,
  context_id : String,
  request_headers : Array[Json],
) -> String {
  let headers : Map[String, Json] = {}
  let mut has_user_agent = false
  let mut has_accept_language = false
  for
    header in self.resolve_network_extra_header_entries(
      context_id, request_headers,
    ) {
    let name = match synthetic_network_header_entry_name(header) {
      Some(name) => name
      None => continue
    }
    let value = match synthetic_network_header_entry_string_value(header) {
      Some(value) => value
      None => continue
    }
    if name == "user-agent" {
      has_user_agent = true
    }
    if name == "accept-language" {
      has_accept_language = true
    }
    headers[name] = Json::array([Json::string(value)])
  }
  if !has_user_agent {
    headers["user-agent"] = Json::array([
      Json::string(self.resolve_effective_user_agent(context_id)),
    ])
  }
  if !has_accept_language {
    headers["accept-language"] = Json::array([
      Json::string(self.resolve_effective_locale(context_id)),
    ])
  }
  make_object({ "headers": make_object(headers) }).stringify()
}

///|
fn synthetic_network_copy_string_map(
  source : Map[String, String],
) -> Map[String, String] {
  let copied : Map[String, String] = {}
  synthetic_network_merge_string_map(copied, source)
  copied
}

///|
fn synthetic_network_replace_string_map(
  target : Map[String, String],
  source : Map[String, String],
) -> Unit {
  let keys : Array[String] = []
  for key, _ in target {
    keys.push(key)
  }
  for key in keys {
    target.remove(key)
  }
  synthetic_network_merge_string_map(target, source)
}

///|
fn synthetic_network_merge_string_map(
  target : Map[String, String],
  source : Map[String, String],
) -> Unit {
  for key, value in source {
    target[key] = value
  }
}

///|
fn synthetic_network_header_string_map_from_entries(
  headers : Array[Json],
) -> Map[String, String] {
  let normalized : Map[String, String] = {}
  for header in headers {
    let name = match synthetic_network_header_entry_name(header) {
      Some(name) => name.to_lower()
      None => continue
    }
    let value = match synthetic_network_header_entry_string_value(header) {
      Some(value) => value
      None => continue
    }
    normalized[name] = value
  }
  normalized
}

///|
fn synthetic_network_header_entries_from_string_map(
  headers : Map[String, String],
) -> Array[Json] {
  let entries : Array[Json] = []
  for name, value in headers {
    entries.push(synthetic_network_header_string_entry(name, value))
  }
  entries
}
