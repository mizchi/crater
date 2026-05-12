///|
fn BidiProtocol::handle_network_remember_blocked_request(
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
  let blocked_request_id = match map.get("request") {
    Some(String(blocked_request_id)) => blocked_request_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "request must be a string",
      )
      return
    }
  }
  let blocked_request = match
    get_map_field_with_alias(map, "blockedRequest", "blocked_request") {
    Some(Object(blocked_request)) => blocked_request
    _ => {
      self.send_error(
        request_id, "invalid argument", "blockedRequest must be an object",
      )
      return
    }
  }
  self.remember_network_blocked_request(blocked_request_id, blocked_request)
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::handle_network_get_blocked_request(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let blocked_request_id = match
    self.synthetic_network_request_lookup_id(request_id, params) {
    Some(blocked_request_id) => blocked_request_id
    None => return
  }
  let blocked_request = match
    self.get_network_blocked_request(blocked_request_id) {
    Some(blocked_request) => make_object(blocked_request)
    None => Json::null()
  }
  self.send_success(
    request_id,
    Some(make_object({ "blockedRequest": blocked_request })),
  )
}

///|
fn BidiProtocol::handle_network_get_blocked_request_phase_value(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match
    self.resolve_network_blocked_request_field(request_id, params, "phase") {
    Some(value) => self.send_success(request_id, Some(value))
    None => ()
  }
}

///|
fn BidiProtocol::handle_network_get_blocked_request_navigation_value(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match
    self.resolve_network_blocked_request_field(request_id, params, "navigation") {
    Some(value) => self.send_success(request_id, Some(value))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_network_blocked_request_field(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
  field_name : String,
) -> Json? {
  let blocked_request_id = match
    self.synthetic_network_request_lookup_id(request_id, params) {
    Some(blocked_request_id) => blocked_request_id
    None => return None
  }
  let blocked_request = match
    self.get_network_blocked_request(blocked_request_id) {
    Some(blocked_request) => blocked_request
    None => return Some(Json::null())
  }
  match blocked_request.get(field_name) {
    Some(value) => Some(value)
    None => Some(Json::null())
  }
}

///|
fn BidiProtocol::handle_network_forget_blocked_request(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let blocked_request_id = match
    self.synthetic_network_request_lookup_id(request_id, params) {
    Some(blocked_request_id) => blocked_request_id
    None => return
  }
  self.forget_network_blocked_request(blocked_request_id)
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::handle_network_has_blocked_navigation_request(
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
  let navigation_id : String? = match map.get("navigation") {
    None | Some(Null) => None
    Some(String(navigation_id)) => Some(navigation_id)
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "navigation must be a string",
      )
      return
    }
  }
  self.send_success(
    request_id,
    Some(
      make_object({
        "blocked": Json::boolean(
          self.has_network_blocked_navigation_request(context_id, navigation_id),
        ),
      }),
    ),
  )
}

///|
fn BidiProtocol::clear_all_network_state(self : BidiProtocol) -> Unit {
  self.network_state.network_cache_behavior_global = "default"
  synthetic_network_replace_string_map(
    self.network_state.network_extra_headers_global,
    {},
  )
  let extra_header_context_keys : Array[String] = []
  for key, _ in self.network_state.network_extra_headers_by_context {
    extra_header_context_keys.push(key)
  }
  for key in extra_header_context_keys {
    self.network_state.network_extra_headers_by_context.remove(key)
  }
  let extra_header_user_context_keys : Array[String] = []
  for key, _ in self.network_state.network_extra_headers_by_user_context {
    extra_header_user_context_keys.push(key)
  }
  for key in extra_header_user_context_keys {
    self.network_state.network_extra_headers_by_user_context.remove(key)
  }
  let behavior_keys : Array[String] = []
  for key, _ in self.network_state.network_cache_behavior_by_context {
    behavior_keys.push(key)
  }
  for key in behavior_keys {
    self.network_state.network_cache_behavior_by_context.remove(key)
  }
  let cache_keys : Array[String] = []
  for key, _ in self.network_state.network_cached_requests_by_context {
    cache_keys.push(key)
  }
  for key in cache_keys {
    self.network_state.network_cached_requests_by_context.remove(key)
  }
  let blocked_keys : Array[String] = []
  for key, _ in self.network_state.network_blocked_requests {
    blocked_keys.push(key)
  }
  for key in blocked_keys {
    self.network_state.network_blocked_requests.remove(key)
  }
}

///|
fn BidiProtocol::clear_network_state_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.network_state.network_extra_headers_by_context.remove(ctx_id)
  self.network_state.network_cache_behavior_by_context.remove(ctx_id)
  self.network_state.network_state_channel_by_context.remove(ctx_id)
  self.network_state.network_cached_requests_by_context.remove(ctx_id)
  let blocked_keys : Array[String] = []
  for request_id, blocked_request in self.network_state.network_blocked_requests {
    match blocked_request {
      Object(map) =>
        match map.get("context_id") {
          Some(String(blocked_ctx_id)) =>
            if blocked_ctx_id == ctx_id {
              blocked_keys.push(request_id)
            }
          _ => ()
        }
      _ => ()
    }
  }
  for request_id in blocked_keys {
    self.network_state.network_blocked_requests.remove(request_id)
  }
}

///|
fn BidiProtocol::remember_network_blocked_request(
  self : BidiProtocol,
  request_id : String,
  payload : Map[String, Json],
) -> Unit {
  let normalized : Map[String, Json] = {}
  for key, value in payload {
    normalized[key] = value
  }
  normalized["request"] = Json::string(request_id)
  self.network_state.network_blocked_requests[request_id] = make_object(
    normalized,
  )
}

///|
fn BidiProtocol::get_network_blocked_request(
  self : BidiProtocol,
  request_id : String,
) -> Map[String, Json]? {
  match self.network_state.network_blocked_requests.get(request_id) {
    Some(Object(blocked_request)) => Some(blocked_request)
    _ => None
  }
}

///|
fn BidiProtocol::forget_network_blocked_request(
  self : BidiProtocol,
  request_id : String,
) -> Unit {
  self.network_state.network_blocked_requests.remove(request_id)
}

///|
fn BidiProtocol::has_network_blocked_navigation_request(
  self : BidiProtocol,
  ctx_id : String,
  navigation_id : String?,
) -> Bool {
  for _, blocked_request in self.network_state.network_blocked_requests {
    match blocked_request {
      Object(map) => {
        let blocked_ctx_id = match map.get("context_id") {
          Some(String(blocked_ctx_id)) => blocked_ctx_id
          _ => continue
        }
        if blocked_ctx_id != ctx_id {
          continue
        }
        match map.get("is_navigation") {
          Some(True) => ()
          _ => continue
        }
        match navigation_id {
          Some(navigation_id) =>
            match map.get("navigation") {
              Some(String(blocked_navigation_id)) =>
                if blocked_navigation_id == navigation_id {
                  return true
                }
              _ => ()
            }
          None => return true
        }
      }
      _ => ()
    }
  }
  false
}
