///|
fn synthetic_network_load_event_json(
  context_id : String,
  navigation : String?,
  url : String,
) -> Json {
  make_object({
    "context": Json::string(context_id),
    "navigation": match navigation {
      Some(navigation) => Json::string(navigation)
      None => Json::null()
    },
    "timestamp": Json::number(input_now_ms()),
    "url": Json::string(url),
  })
}

///|
fn BidiProtocol::normalize_synthetic_network_event_input(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> SyntheticNetworkEventInput? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }
  let context_id = match map.get("context") {
    Some(String(context_id)) => context_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }
  if !self.manager.has_session(context_id) {
    self.send_error(
      request_id,
      "no such frame",
      "Unknown context: " + context_id,
    )
    return None
  }
  let url = match map.get("url") {
    Some(String(url)) => url
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return None
    }
  }
  let http_method = match map.get("method") {
    Some(String(http_method)) => http_method
    _ => {
      self.send_error(request_id, "invalid argument", "method must be a string")
      return None
    }
  }
  let request_token = match
    get_map_field_with_alias(map, "requestId", "request_id") {
    Some(String(request_token)) => request_token
    _ => {
      self.send_error(
        request_id, "invalid argument", "requestId must be a string",
      )
      return None
    }
  }
  let request_headers = match
    self.normalize_synthetic_network_header_entries(
      request_id,
      get_map_field_with_alias(map, "requestHeaders", "request_headers"),
    ) {
    Some(request_headers) => request_headers
    None => return None
  }
  let resolved_request_headers = self.resolve_network_extra_header_entries(
    context_id, request_headers,
  )
  let request_cookies = match
    self.normalize_synthetic_network_cookie_entries(
      request_id,
      get_map_field_with_alias(map, "requestCookies", "request_cookies"),
    ) {
    Some(request_cookies) => request_cookies
    None => return None
  }
  let intercepts = match
    self.normalize_synthetic_network_string_list(
      request_id,
      get_param_raw(params, "intercepts"),
      "intercepts",
    ) {
    Some(intercepts) => intercepts
    None => return None
  }
  let redirect_count = match get_param_raw(params, "redirectCount") {
    None | Some(Null) => 0
    Some(value) =>
      match storage_json_non_negative_int(value) {
        Some(count) => count
        None => {
          self.send_error(
            request_id, "invalid argument", "redirectCount must be a non-negative integer",
          )
          return None
        }
      }
  }
  let navigation : String? = match get_param_raw(params, "navigation") {
    None | Some(Null) => None
    Some(String(value)) => Some(value)
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "navigation must be a string",
      )
      return None
    }
  }
  let destination = match get_param_raw(params, "destination") {
    None | Some(Null) => ""
    Some(String(value)) => value
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "destination must be a string",
      )
      return None
    }
  }
  let initiator_type : String? = match
    get_map_field_with_alias(map, "initiatorType", "initiator_type") {
    None | Some(Null) => None
    Some(String(value)) => Some(value)
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "initiatorType must be a string",
      )
      return None
    }
  }

  Some({
    context_id,
    url,
    http_method,
    request_token,
    request_headers: resolved_request_headers,
    request_value: get_map_field_with_alias(
      map, "requestValue", "request_value",
    ),
    request_cookies: request_cookies.cookies,
    request_cookies_override: request_cookies.enabled,
    intercepts,
    redirect_count,
    navigation,
    destination,
    initiator_type,
  })
}

///|
fn BidiProtocol::synthetic_network_event_input_from_blocked_request(
  self : BidiProtocol,
  request_id : Int,
  blocked_request_id : String,
  blocked_request : Map[String, Json],
) -> SyntheticNetworkEventInput? {
  let context_id = match
    get_map_field_with_alias(blocked_request, "contextId", "context_id") {
    Some(String(context_id)) => context_id
    _ => {
      self.send_error(request_id, "no such request", "Unknown request")
      return None
    }
  }
  if !self.manager.has_session(context_id) {
    self.send_error(request_id, "no such request", "Unknown request")
    return None
  }
  let url = match blocked_request.get("url") {
    Some(String(url)) => url
    _ => ""
  }
  let http_method = match blocked_request.get("method") {
    Some(String(http_method)) => http_method
    _ => "GET"
  }
  let request_headers = match blocked_request.get("request_headers") {
    Some(Object(request_headers)) =>
      synthetic_network_header_entries_from_object(request_headers)
    _ => []
  }
  let resolved_request_headers = self.resolve_network_extra_header_entries(
    context_id, request_headers,
  )
  let redirect_count = match blocked_request.get("redirect_count") {
    Some(redirect_count) =>
      storage_json_non_negative_int(redirect_count).unwrap_or(0)
    None => 0
  }
  let navigation : String? = match blocked_request.get("navigation") {
    Some(String(navigation)) => Some(navigation)
    _ => None
  }
  let destination = match blocked_request.get("destination") {
    Some(String(destination)) => destination
    _ => ""
  }
  let initiator_type : String? = match
    get_map_field_with_alias(blocked_request, "initiatorType", "initiator_type") {
    Some(String(initiator_type)) => Some(initiator_type)
    _ => Some("fetch")
  }
  Some({
    context_id,
    url,
    http_method,
    request_token: blocked_request_id,
    request_headers: resolved_request_headers,
    request_value: get_map_field_with_alias(
      blocked_request, "requestValue", "request_value",
    ),
    request_cookies: [],
    request_cookies_override: false,
    intercepts: [],
    redirect_count,
    navigation,
    destination,
    initiator_type,
  })
}

///|
fn synthetic_network_blocked_response_headers(
  blocked_request : Map[String, Json],
) -> Array[Json] {
  let headers : Array[Json] = []
  match
    get_map_field_with_alias(
      blocked_request, "responseHeaders", "response_headers",
    ) {
    Some(Array(items)) =>
      for item in items {
        match validate_network_extra_header_entry(item) {
          Some(header) => headers.push(header)
          None => ()
        }
      }
    _ => ()
  }
  headers
}

///|
fn synthetic_network_blocked_response_status(
  blocked_request : Map[String, Json],
) -> Int {
  match
    get_map_field_with_alias(
      blocked_request, "responseStatus", "response_status",
    ) {
    Some(status_value) =>
      match storage_json_non_negative_int(status_value) {
        Some(status) => status
        None => 401
      }
    None => 401
  }
}

///|
fn synthetic_network_blocked_response_status_text(
  blocked_request : Map[String, Json],
  status : Int,
) -> String {
  match
    get_map_field_with_alias(
      blocked_request, "responseStatusText", "response_status_text",
    ) {
    Some(String(status_text)) =>
      if status_text == "" {
        synthetic_network_status_text_for_code(status)
      } else {
        status_text
      }
    _ => synthetic_network_status_text_for_code(status)
  }
}
