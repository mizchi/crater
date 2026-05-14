///|
fn BidiProtocol::handle_network_continue_blocked_response(
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
  let mode = match map.get("mode") {
    Some(String(mode)) => mode
    _ => {
      self.send_error(request_id, "invalid argument", "mode must be a string")
      return
    }
  }
  if mode != "continueResponse" && mode != "provideResponse" {
    self.send_error(request_id, "invalid argument", "mode is invalid")
    return
  }
  let blocked_request = match
    self.get_network_blocked_request(blocked_request_id) {
    Some(blocked_request) => blocked_request
    None => {
      self.send_error(request_id, "no such request", "Unknown request")
      return
    }
  }
  let phase = match blocked_request.get("phase") {
    Some(String(phase)) => phase
    _ => {
      self.send_error(request_id, "no such request", "Unknown request")
      return
    }
  }
  if mode == "continueResponse" {
    if phase != "responseStarted" && phase != "authRequired" {
      self.send_error(
        request_id, "invalid argument", "Request is not blocked at responseStarted/authRequired",
      )
      return
    }
  } else if phase != "beforeRequestSent" &&
    phase != "responseStarted" &&
    phase != "authRequired" {
    self.send_error(
      request_id, "invalid argument", "Request is not blocked at beforeRequestSent/responseStarted/authRequired",
    )
    return
  }

  let input = match
    self.synthetic_network_event_input_from_blocked_request(
      request_id, blocked_request_id, blocked_request,
    ) {
    Some(input) => input
    None => return
  }
  let context_id = input.context_id

  let has_headers = map.contains("headers")
  let has_cookies = map.contains("cookies")
  let has_status_code = map.contains("statusCode") ||
    map.contains("status_code")
  let has_reason_phrase = map.contains("reasonPhrase") ||
    map.contains("reason_phrase")
  let has_body = map.contains("body")

  let mut response_headers = if mode == "continueResponse" {
    synthetic_network_blocked_response_headers(blocked_request)
  } else {
    []
  }
  if has_headers {
    match
      self.normalize_synthetic_network_header_entries(
        request_id,
        get_map_field_with_alias(map, "headers", "headers"),
      ) {
      Some(headers) => response_headers = headers
      None => return
    }
  }

  let mut response_cookie_headers : Array[Json] = []
  let mut response_cookies : Array[StoredCookie] = []
  if has_cookies {
    let normalized = match
      self.normalize_synthetic_network_set_cookie_entries(
        request_id,
        map.get("cookies"),
        input.url,
      ) {
      Some(normalized) => normalized
      None => return
    }
    response_cookie_headers = normalized.headers
    response_cookies = normalized.cookies
  }
  let response_headers_with_cookies : Array[Json] = []
  for header in response_headers {
    response_headers_with_cookies.push(header)
  }
  for header in response_cookie_headers {
    response_headers_with_cookies.push(header)
  }
  response_headers = response_headers_with_cookies

  let parsed_header_cookies = synthetic_network_extract_set_cookie_entries(
    response_headers,
    input.url,
  )
  for cookie in parsed_header_cookies {
    response_cookies.push(cookie)
  }

  let mut status_code = if mode == "continueResponse" {
    synthetic_network_blocked_response_status(blocked_request)
  } else {
    200
  }
  let raw_status_code = get_map_field_with_alias(
    map, "statusCode", "status_code",
  )
  match raw_status_code {
    Some(value) =>
      match json_as_safe_int(value, 0.0, 9007199254740991.0) {
        Some(parsed) => status_code = parsed
        None => {
          self.send_error(
            request_id, "invalid argument", "statusCode must be a non-negative integer",
          )
          return
        }
      }
    None => ()
  }

  let mut reason_phrase = if mode == "continueResponse" {
    synthetic_network_blocked_response_status_text(blocked_request, status_code)
  } else {
    "OK"
  }
  let raw_reason_phrase = get_map_field_with_alias(
    map, "reasonPhrase", "reason_phrase",
  )
  match raw_reason_phrase {
    Some(String(value)) => reason_phrase = value
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "reasonPhrase must be a string",
      )
      return
    }
    None => ()
  }

  let mut body_text : String? = None
  let mut response_body_value : Json? = None
  if has_body {
    match map.get("body") {
      Some(raw_body) => {
        let normalized_body = match
          self.normalize_synthetic_network_bytes_value(
            request_id, raw_body, "body",
          ) {
          Some(value) => value
          None => return
        }
        let text = match
          self.synthetic_network_text_from_bytes_value(
            request_id, raw_body, "body",
          ) {
          Some(text) => text
          None => return
        }
        response_body_value = Some(normalized_body)
        body_text = Some(text)
      }
      None => {
        self.send_error(
          request_id, "invalid argument", "body must be an object",
        )
        return
      }
    }
  }

  let mut credentials : @crater_network.SyntheticNetworkContinueCredentials? = None
  if map.contains("credentials") {
    match map.get("credentials") {
      Some(raw_credentials) =>
        match
          self.normalize_synthetic_network_continue_credentials(
            request_id, raw_credentials,
          ) {
          Some(value) => credentials = Some(value)
          None => return
        }
      None => {
        self.send_error(
          request_id, "invalid argument", "credentials must be an object",
        )
        return
      }
    }
  }

  if phase == "authRequired" {
    if mode == "provideResponse" {
      let auth_required_event = match
        self.build_synthetic_auth_required_event_json(
          request_id, input, blocked_request,
        ) {
        Some(event) => event
        None => return
      }
      self.send_continue_blocked_response_result(
        request_id,
        None,
        None,
        Some(auth_required_event),
        None,
        false,
        None,
        None,
        body_text,
      )
      self.emit_synthetic_network_result_events(
        None,
        None,
        Some(auth_required_event),
        None,
      )
      return
    }

    let should_continue = synthetic_network_credentials_match_expected(
      input.url,
      credentials,
    )
    if !should_continue {
      let auth_required_event = match
        self.build_synthetic_auth_required_event_json(
          request_id, input, blocked_request,
        ) {
        Some(event) => event
        None => return
      }
      self.send_continue_blocked_response_result(
        request_id,
        None,
        None,
        Some(auth_required_event),
        None,
        false,
        None,
        None,
        body_text,
      )
      self.emit_synthetic_network_result_events(
        None,
        None,
        Some(auth_required_event),
        None,
      )
      return
    }
    if !has_status_code {
      status_code = 200
    }
    if !has_reason_phrase {
      reason_phrase = "OK"
    }
    if !has_headers && !has_cookies {
      response_headers = []
    }
  }

  let resolved_overrides = self.resolve_synthetic_response_overrides_internal(
    context_id,
    input.url,
    input.http_method,
    input.request_headers,
    false,
  )
  let final_auth_challenges : Json? = if status_code == 401 ||
    status_code == 407 {
    match resolved_overrides.auth_challenges {
      Some(auth_challenges) => Some(auth_challenges)
      None => Some(Json::array([]))
    }
  } else if phase == "authRequired" {
    None
  } else {
    resolved_overrides.auth_challenges
  }
  let response_overrides : @crater_network.SyntheticNetworkResponseOverrides = {
    from_cache: resolved_overrides.from_cache,
    headers: response_headers,
    mime_type: resolved_overrides.mime_type,
    protocol: resolved_overrides.protocol,
    status: status_code,
    status_text: reason_phrase,
    auth_challenges: final_auth_challenges,
  }

  let mut response_started_event : Json? = None
  if mode == "provideResponse" && phase == "beforeRequestSent" {
    response_started_event = self.build_synthetic_response_event_json(
      request_id, input, response_overrides,
    )
    if response_started_event is None {
      return
    }
  }

  let response_completed_event = match
    self.build_synthetic_response_event_json(
      request_id, input, response_overrides,
    ) {
    Some(event) => event
    None => return
  }

  for cookie in response_cookies {
    self.store_synthetic_response_cookie(context_id, cookie)
  }
  if mode == "provideResponse" {
    let response_value = match response_body_value {
      Some(response_value) => response_value
      None => synthetic_navigation_synthesize_response_value(input.url)
    }
    self.remember_network_collected_data_internal(
      context_id,
      blocked_request_id,
      input.request_value,
      Some(response_value),
    )
  }
  self.forget_network_blocked_request(blocked_request_id)

  let is_navigation = match
    get_map_field_with_alias(blocked_request, "isNavigation", "is_navigation") {
    Some(True) => true
    _ => false
  }
  let load_event = if input.navigation is Some(_) || is_navigation {
    Some(
      synthetic_network_load_event_json(context_id, input.navigation, input.url),
    )
  } else {
    None
  }
  let applies_runtime_body_override = input.destination == "document" ||
    input.destination == "script" ||
    input.destination == "style"
  if mode == "provideResponse" &&
    applies_runtime_body_override &&
    body_text is Some(_) {
    self.apply_navigation_provide_response_body_override(
      context_id,
      input.destination,
      body_text.unwrap(),
    )
  }

  self.send_continue_blocked_response_result(
    request_id,
    response_started_event,
    Some(response_completed_event),
    None,
    load_event,
    true,
    Some(status_code),
    Some(reason_phrase),
    body_text,
  )
  self.emit_synthetic_network_result_events(
    response_started_event,
    Some(response_completed_event),
    None,
    load_event,
  )
  if is_navigation {
    self.complete_pending_navigation_response(
      context_id,
      Some(input.url),
      input.navigation,
    )
  }
  if mode == "provideResponse" {
    self.maybe_emit_followup_preflight_blocked_request(blocked_request)
  }
}
