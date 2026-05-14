///|
fn BidiProtocol::handle_network_set_cache_behavior(
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
  let cache_behavior = match
    get_map_field_with_alias(map, "cacheBehavior", "cache_behavior") {
    Some(String(cache_behavior)) => cache_behavior
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "cacheBehavior must be a string",
      )
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing cacheBehavior")
      return
    }
  }
  if cache_behavior != "default" && cache_behavior != "bypass" {
    self.send_error(request_id, "invalid argument", "cacheBehavior is invalid")
    return
  }
  match map.get("contexts") {
    None | Some(Null) => {
      self.network_state.network_cache_behavior_global = cache_behavior
      let keys : Array[String] = []
      for key, _ in self.network_state.network_cache_behavior_by_context {
        keys.push(key)
      }
      for key in keys {
        self.network_state.network_cache_behavior_by_context.remove(key)
      }
    }
    Some(Array(items)) => {
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be empty",
        )
        return
      }
      for item in items {
        match item {
          String(ctx_id) =>
            if !self.manager.has_session(ctx_id) {
              self.send_error(
                request_id,
                "no such frame",
                "Unknown context: " + ctx_id,
              )
              return
            } else {
              self.network_state.network_cache_behavior_by_context[ctx_id] = cache_behavior
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "contexts entries must be strings",
            )
            return
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return
    }
  }
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::handle_network_resolve_synthetic_response_overrides(
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
  if !self.manager.has_session(context_id) {
    self.send_error(
      request_id,
      "no such frame",
      "Unknown context: " + context_id,
    )
    return
  }
  let url = match map.get("url") {
    Some(String(url)) => url
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return
    }
  }
  let http_method = match map.get("method") {
    Some(String(http_method)) => http_method
    _ => {
      self.send_error(request_id, "invalid argument", "method must be a string")
      return
    }
  }
  let request_headers = match
    self.normalize_synthetic_network_header_entries(
      request_id,
      get_map_field_with_alias(map, "requestHeaders", "request_headers"),
    ) {
    Some(request_headers) => request_headers
    None => return
  }
  let resolved_request_headers = self.resolve_network_extra_header_entries(
    context_id, request_headers,
  )
  let update_cache = match
    get_map_field_with_alias(map, "updateCache", "update_cache") {
    None | Some(Null) => true
    Some(True) => true
    Some(False) => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "updateCache must be a boolean",
      )
      return
    }
  }
  let overrides = self.resolve_synthetic_response_overrides_internal(
    context_id, url, http_method, resolved_request_headers, update_cache,
  )
  self.send_success(
    request_id,
    Some(
      make_object({
        "responseOverrides": self.synthetic_network_response_overrides_to_json(
          overrides,
        ),
      }),
    ),
  )
}

///|
fn BidiProtocol::resolve_synthetic_response_overrides_internal(
  self : BidiProtocol,
  context_id : String,
  url : String,
  http_method : String,
  request_headers : Array[Json],
  update_cache : Bool,
) -> @crater_network.SyntheticNetworkResponseOverrides {
  let mut status = 200
  let mut from_cache = false
  let mut protocol = "http/1.1"
  let mut auth_challenges : Json? = None
  let headers : Array[Json] = []
  let path = synthetic_network_request_path(url)
  let method_upper = http_method.to_upper()
  let cache_enabled = self.synthetic_network_cache_enabled(context_id)
  let cache_key = synthetic_network_cache_key(method_upper, url)
  let context_cache = self.network_state.network_cached_requests_by_context
    .get(context_id)
    .unwrap_or({})

  if url.has_prefix("data:") {
    protocol = "data"
  }

  if path.has_suffix("/redirect.py") {
    status = synthetic_network_int_query_param(url, "status", 302)
  } else if path.has_suffix("/status.py") {
    status = synthetic_network_int_query_param(url, "status", 200)
  } else if path.has_suffix("/cached.py") {
    status = synthetic_network_int_query_param(url, "status", 200)
    if cache_enabled && method_upper == "GET" {
      if context_cache.contains(cache_key) {
        from_cache = true
      } else if update_cache {
        context_cache[cache_key] = true
        self.network_state.network_cached_requests_by_context[context_id] = context_cache
      }
    }
  } else if path.has_suffix("/must-revalidate.py") {
    let return_304 = synthetic_network_request_header_string_value(
      request_headers, "return-304",
    )
    if cache_enabled &&
      (
        method_upper == "GET" ||
        method_upper == "HEAD" ||
        method_upper == "OPTIONS"
      ) &&
      return_304 == Some("true") &&
      context_cache.contains(cache_key) {
      status = 304
    } else {
      status = 200
      if cache_enabled &&
        (
          method_upper == "GET" ||
          method_upper == "HEAD" ||
          method_upper == "OPTIONS"
        ) &&
        update_cache {
        context_cache[cache_key] = true
        self.network_state.network_cached_requests_by_context[context_id] = context_cache
      }
    }
  } else if path.has_suffix("/authentication.py") {
    status = 401
    let realm = synthetic_network_first_query_value(url, "realm").unwrap_or(
      "testrealm",
    )
    auth_challenges = Some(
      Json::array([
        make_object({
          "scheme": Json::string("Basic"),
          "realm": Json::string(realm),
        }),
      ]),
    )
    headers.push(
      synthetic_network_header_string_entry(
        "WWW-Authenticate",
        "Basic realm=\"" + realm + "\"",
      ),
    )
  }

  if path.has_suffix("/headers.py") {
    for raw_header in synthetic_network_query_values(url, "header") {
      match find_substring(raw_header, ":", 0) {
        Some(idx) => {
          let name = raw_header.unsafe_substring(start=0, end=idx)
          let value_start = idx + 1
          let value = if value_start <= raw_header.length() {
            raw_header.unsafe_substring(
              start=value_start,
              end=raw_header.length(),
            )
          } else {
            ""
          }
          headers.push(synthetic_network_header_string_entry(name, value))
        }
        None => ()
      }
    }
  }

  let mime_type = synthetic_network_infer_mime_type(url, path)
  if mime_type != "" {
    headers.push(
      synthetic_network_header_string_entry("Content-Type", mime_type),
    )
  }

  let mut status_text = synthetic_network_status_text_for_code(status)
  if path.has_suffix("/serviceworker.html") {
    status_text = "OK from serviceworker"
  }
  let missing_auth_challenges = match auth_challenges {
    None => true
    Some(_) => false
  }
  if (status == 401 || status == 407) && missing_auth_challenges {
    auth_challenges = Some(Json::array([]))
  }

  {
    from_cache,
    headers,
    mime_type,
    protocol,
    status,
    status_text,
    auth_challenges,
  }
}

///|
fn BidiProtocol::synthetic_network_response_overrides_to_json(
  self : BidiProtocol,
  overrides : @crater_network.SyntheticNetworkResponseOverrides,
) -> Json {
  let _ = self
  @crater_network.synthetic_network_response_overrides_to_json(overrides)
}

///|
fn BidiProtocol::synthetic_network_cache_enabled(
  self : BidiProtocol,
  context_id : String,
) -> Bool {
  self.synthetic_network_cache_behavior(context_id) == "default"
}

///|
fn BidiProtocol::synthetic_network_cache_behavior(
  self : BidiProtocol,
  context_id : String,
) -> String {
  self.network_state.network_cache_behavior_by_context
  .get(context_id)
  .unwrap_or(self.network_state.network_cache_behavior_global)
}
