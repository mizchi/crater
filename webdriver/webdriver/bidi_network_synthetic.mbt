///|
extern "js" fn js_utf8_byte_length(value : String) -> Int =
  #| (value) => new TextEncoder().encode(String(value ?? "")).length

///|
extern "js" fn js_base64_byte_length(value : String) -> Int =
  #| (value) => {
  #|   try {
  #|     return Uint8Array.from(atob(String(value ?? "")), (c) => c.charCodeAt(0)).length;
  #|   } catch (_) {
  #|     return 0;
  #|   }
  #| }

///|
extern "js" fn js_decode_query_component(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     const text = value === null || value === undefined ? "" : String(value);
  #|     return decodeURIComponent(text.replace(/\+/g, " "));
  #|   } catch (_) {
  #|     return value === null || value === undefined ? "" : String(value);
  #|   }
  #| }

///|
priv struct SyntheticNetworkCookieOverride {
  enabled : Bool
  cookies : Array[Json]
}

///|
priv struct SyntheticNetworkEventInput {
  context_id : String
  url : String
  http_method : String
  request_token : String
  request_headers : Array[Json]
  request_value : Json?
  request_cookies : Array[Json]
  request_cookies_override : Bool
  intercepts : Array[String]
  redirect_count : Int
  navigation : String?
  destination : String
  initiator_type : String?
}

///|
priv struct SyntheticNetworkResponseOverrides {
  from_cache : Bool
  headers : Array[Json]
  mime_type : String
  protocol : String
  status : Int
  status_text : String
  auth_challenges : Json?
}

///|
priv struct SyntheticNetworkContinueCredentials {
  username : String
  password : String
}

///|
priv struct SyntheticNetworkSetCookieEntries {
  headers : Array[Json]
  cookies : Array[StoredCookie]
}

///|
fn BidiProtocol::handle_network_prepare_navigation_request(
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
  match self.prepare_navigation_request_internal(request_id, context_id, url) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::prepare_navigation_request_internal(
  self : BidiProtocol,
  request_id : Int,
  context_id : String,
  url : String,
) -> Json? {
  let event_name = "network.beforeRequestSent"
  if !self.is_subscribed_for_context(event_name, context_id) {
    return Some(make_object({ "blocked": Json::boolean(false) }))
  }
  let intercepts = self.resolve_matching_network_intercepts_internal(
    context_id, "beforeRequestSent", url,
  )
  if intercepts.length() == 0 {
    return Some(make_object({ "blocked": Json::boolean(false) }))
  }

  let navigation_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  self.remember_requested_navigation_url(context_id, url)
  self.register_in_flight_navigation(
    context_id,
    url,
    navigation_id,
    Some(request_id),
  )
  let input : SyntheticNetworkEventInput = {
    context_id,
    url,
    http_method: "GET",
    request_token: self.next_synthetic_network_request_id(),
    request_headers: [],
    request_value: None,
    request_cookies: [],
    request_cookies_override: false,
    intercepts,
    redirect_count: 0,
    navigation: Some(navigation_id),
    destination: "document",
    initiator_type: None,
  }
  let event = match
    self.build_synthetic_before_request_sent_event_json(request_id, input) {
    Some(event) => event
    None => return None
  }
  self.outbox.push(Event({ event_method: event_name, params: event }))
  let blocked_request : Map[String, Json] = {}
  blocked_request["phase"] = Json::string("beforeRequestSent")
  blocked_request["context_id"] = Json::string(context_id)
  blocked_request["url"] = Json::string(url)
  blocked_request["method"] = Json::string("GET")
  blocked_request["request_headers"] = make_object({})
  blocked_request["redirect_count"] = Json::number(0.0)
  blocked_request["navigation"] = Json::string(navigation_id)
  blocked_request["destination"] = Json::string("document")
  blocked_request["initiator_type"] = Json::null()
  blocked_request["is_navigation"] = Json::boolean(true)
  self.remember_network_blocked_request(input.request_token, blocked_request)
  Some(
    make_object({
      "blocked": Json::boolean(true),
      "navigation": Json::string(navigation_id),
      "url": Json::string(url),
    }),
  )
}

///|
fn BidiProtocol::handle_network_fail_blocked_request(
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
    Some(blocked_request) => blocked_request
    None => {
      self.send_error(request_id, "no such request", "Unknown request")
      return
    }
  }
  match blocked_request.get("phase") {
    Some(String("authRequired")) => {
      self.send_error(
        request_id, "invalid argument", "authRequired requests cannot be failed",
      )
      return
    }
    _ => ()
  }
  let input = match
    self.synthetic_network_event_input_from_blocked_request(
      request_id, blocked_request_id, blocked_request,
    ) {
    Some(input) => input
    None => return
  }
  let error_text = match get_param_raw(params, "errorText") {
    None | Some(Null) => "Request failed"
    Some(String(text)) => text
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "errorText must be a string",
      )
      return
    }
  }
  let event = match
    self.build_synthetic_fetch_error_event_json(request_id, input, error_text) {
    Some(event) => event
    None => return
  }
  let is_navigation = match
    get_map_field_with_alias(blocked_request, "isNavigation", "is_navigation") {
    Some(True) => true
    _ => false
  }
  self.forget_network_blocked_request(blocked_request_id)
  self.send_success(request_id, Some(make_object({ "event": event })))
  self.emit_synthetic_network_event_if_subscribed(
    "network.fetchError",
    Some(event),
  )
  if is_navigation {
    self.fail_pending_navigation_response(
      input.context_id,
      input.navigation,
      "Navigation failed: " + error_text,
    )
  }
}

///|
fn BidiProtocol::handle_network_continue_auth_request(
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
  let action = match map.get("action") {
    Some(String(action)) => action
    Some(_) => {
      self.send_error(request_id, "invalid argument", "action must be a string")
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "action must be a string")
      return
    }
  }
  if action == "provideCredentials" {
    if !map.contains("credentials") {
      self.send_error(
        request_id, "invalid argument", "credentials must be an object",
      )
      return
    }
    let forwarded : Map[String, Json] = {}
    forwarded["request"] = map.get("request").unwrap_or(Json::null())
    forwarded["mode"] = Json::string("continueResponse")
    forwarded["credentials"] = map.get("credentials").unwrap_or(Json::null())
    self.handle_network_continue_blocked_response(
      request_id,
      Some(Json::object(forwarded)),
    )
    return
  }
  if action != "default" && action != "cancel" {
    self.send_error(request_id, "invalid argument", "action is invalid")
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
  match blocked_request.get("phase") {
    Some(String("authRequired")) => ()
    _ => {
      self.send_error(
        request_id, "invalid argument", "Request is not blocked at authRequired",
      )
      return
    }
  }
  if action == "default" {
    self.send_success(
      request_id,
      Some(
        make_object({ "event": Json::null(), "consumed": Json::boolean(false) }),
      ),
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
  let resolved_overrides = self.resolve_synthetic_response_overrides_internal(
    input.context_id,
    input.url,
    input.http_method,
    input.request_headers,
    false,
  )
  let status = synthetic_network_blocked_response_status(blocked_request)
  let response_overrides : SyntheticNetworkResponseOverrides = {
    from_cache: resolved_overrides.from_cache,
    headers: synthetic_network_blocked_response_headers(blocked_request),
    mime_type: resolved_overrides.mime_type,
    protocol: resolved_overrides.protocol,
    status,
    status_text: synthetic_network_blocked_response_status_text(
      blocked_request, status,
    ),
    auth_challenges: Some(Json::array([])),
  }
  let event = match
    self.build_synthetic_response_event_json(
      request_id, input, response_overrides,
    ) {
    Some(event) => event
    None => return
  }
  self.forget_network_blocked_request(blocked_request_id)
  self.send_success(
    request_id,
    Some(make_object({ "event": event, "consumed": Json::boolean(true) })),
  )
  self.emit_synthetic_network_event_if_subscribed(
    "network.responseCompleted",
    Some(event),
  )
}

///|
fn BidiProtocol::handle_network_continue_blocked_request(
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
    self.get_network_blocked_request(blocked_request_id) {
    Some(blocked_request) => blocked_request
    None => {
      self.send_error(request_id, "no such request", "Unknown request")
      return
    }
  }
  match blocked_request.get("phase") {
    Some(String("beforeRequestSent")) => ()
    _ => {
      self.send_error(
        request_id, "invalid argument", "Request is not blocked at beforeRequestSent",
      )
      return
    }
  }
  let base_input = match
    self.synthetic_network_event_input_from_blocked_request(
      request_id, blocked_request_id, blocked_request,
    ) {
    Some(input) => input
    None => return
  }
  let mut input = base_input
  let mut synthetic_location_href : String? = None
  let mut completed_navigation_url : String? = None
  let is_navigation = match
    get_map_field_with_alias(blocked_request, "isNavigation", "is_navigation") {
    Some(True) => true
    Some(False) => false
    _ => false
  }

  match map.get("body") {
    Some(raw_body) =>
      match
        self.normalize_synthetic_network_bytes_value(
          request_id, raw_body, "body",
        ) {
        Some(body_value) => input = { ..input, request_value: Some(body_value) }
        None => return
      }
    None => ()
  }

  match map.get("method") {
    Some(String(http_method)) =>
      if is_valid_network_header_name_token(http_method) {
        input = { ..input, http_method, }
      } else {
        self.send_error(request_id, "invalid argument", "method is invalid")
        return
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "method must be a string")
      return
    }
    None => ()
  }

  match map.get("url") {
    Some(raw_url) =>
      match self.normalize_synthetic_network_continue_url(request_id, raw_url) {
        Some(url) => input = { ..input, url, }
        None => return
      }
    None => ()
  }

  let has_headers = map.contains("headers")
  let has_cookies = map.contains("cookies")
  if has_headers {
    let normalized_headers = match
      self.normalize_synthetic_network_header_entries(
        request_id,
        map.get("headers"),
      ) {
      Some(headers) => synthetic_network_merge_header_entries(headers)
      None => return
    }
    input = { ..input, request_headers: normalized_headers }
  }
  if has_cookies {
    let cookies_override = match
      self.normalize_synthetic_network_cookie_entries(
        request_id,
        map.get("cookies"),
      ) {
      Some(cookies_override) => cookies_override
      None => return
    }
    input = {
      ..input,
      request_cookies: cookies_override.cookies,
      request_cookies_override: cookies_override.enabled,
    }
  } else if has_headers {
    input = { ..input, request_cookies: [], request_cookies_override: true }
  }

  match map.get("navigation") {
    Some(String(navigation)) =>
      input = { ..input, navigation: Some(navigation) }
    Some(Null) => input = { ..input, navigation: None }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "navigation must be a string",
      )
      return
    }
    None => ()
  }
  match map.get("syntheticLocationHref") {
    Some(String(href)) => synthetic_location_href = Some(href)
    Some(Null) | None => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "syntheticLocationHref must be a string",
      )
      return
    }
  }

  let resolved_overrides = self.resolve_synthetic_response_overrides_internal(
    input.context_id,
    input.url,
    input.http_method,
    input.request_headers,
    false,
  )
  if is_navigation {
    let navigation_id = match input.navigation {
      Some(navigation_id) => {
        input = { ..input, navigation: Some(navigation_id) }
        navigation_id
      }
      None => {
        let generated_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        input = { ..input, navigation: Some(generated_id) }
        generated_id
      }
    }
    let original_url = match blocked_request.get("url") {
      Some(String(url)) => url
      _ => input.url
    }
    let resolved_url = self.resolve_effective_navigation_target_url(
      input.context_id,
      input.url,
    )
    self.input_synthetic_events_by_context.remove(input.context_id)
    self.context_synthetic_scrolled.remove(input.context_id)
    self.clear_synthetic_location_href(input.context_id)
    self.abort_in_flight_navigation_unless_matching(
      input.context_id,
      Some(navigation_id),
      "Navigation interrupted by another navigation",
    )
    if !is_valid_navigation_target_url(resolved_url) {
      self.send_error(request_id, "invalid argument", "url is invalid")
      return
    }
    if should_fail_navigation_with_unknown_error(resolved_url) {
      self.emit_navigation_started_event(
        input.context_id,
        resolved_url,
        navigation_id,
      )
      self.send_error(
        request_id, "unknown error", "Navigation failed: navigation target is unreachable",
      )
      return
    }
    if self.is_iframe_navigation_blocked(input.context_id, resolved_url) {
      self.emit_navigation_started_event(
        input.context_id,
        resolved_url,
        navigation_id,
      )
      self.emit_navigation_failed_event(
        input.context_id,
        resolved_url,
        navigation_id,
      )
      self.send_error(
        request_id, "unknown error", "Navigation failed: blocked by embedding policy",
      )
      return
    }
    match self.manager.get_session(input.context_id) {
      Some(session) =>
        match session.navigate_to(resolved_url) {
          Ok(_) => {
            self.remember_requested_navigation_url(input.context_id, input.url)
            self.apply_navigation_commit_state(
              input.context_id,
              resolved_url,
              navigation_id,
            )
            self.register_in_flight_navigation(
              input.context_id,
              resolved_url,
              navigation_id,
              self.pending_navigation_request.get(input.context_id),
            )
            completed_navigation_url = Some(resolved_url)
            if synthetic_location_href == None && original_url != input.url {
              synthetic_location_href = Some(original_url)
            }
          }
          Err(e) => {
            self.emit_navigation_started_event(
              input.context_id,
              resolved_url,
              navigation_id,
            )
            self.send_error(
              request_id,
              "unknown error",
              "Navigation failed: " + e.message,
            )
            return
          }
        }
      None => {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + input.context_id,
        )
        return
      }
    }
  }
  let response_overrides : SyntheticNetworkResponseOverrides = {
    from_cache: resolved_overrides.from_cache,
    headers: resolved_overrides.headers,
    mime_type: resolved_overrides.mime_type,
    protocol: resolved_overrides.protocol,
    status: resolved_overrides.status,
    status_text: resolved_overrides.status_text,
    auth_challenges: resolved_overrides.auth_challenges,
  }
  let response_started_event = match
    self.build_synthetic_response_event_json(
      request_id, input, response_overrides,
    ) {
    Some(event) => event
    None => return
  }
  let response_completed_event = match
    self.build_synthetic_response_event_json(
      request_id, input, response_overrides,
    ) {
    Some(event) => event
    None => return
  }
  match synthetic_location_href {
    Some(href) => self.remember_synthetic_location_href(input.context_id, href)
    None => ()
  }
  self.forget_network_blocked_request(blocked_request_id)
  self.send_continue_blocked_response_result(
    request_id,
    Some(response_started_event),
    Some(response_completed_event),
    None,
    None,
    true,
    None,
    None,
    None,
  )
  self.emit_synthetic_network_result_events(
    Some(response_started_event),
    Some(response_completed_event),
    None,
    None,
  )
  match completed_navigation_url {
    Some(url) => {
      if !self.is_subscribed_for_context(
          "browsingContext.load",
          input.context_id,
        ) {
        self.outbox.push(
          Event({
            event_method: "browsingContext.load",
            params: synthetic_network_load_event_json(
              input.context_id,
              input.navigation,
              url,
            ),
          }),
        )
      }
      self.complete_pending_navigation_response(
        input.context_id,
        Some(url),
        input.navigation,
      )
    }
    None => ()
  }
}

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

  let mut credentials : SyntheticNetworkContinueCredentials? = None
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
  let response_overrides : SyntheticNetworkResponseOverrides = {
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

///|
fn BidiProtocol::apply_navigation_provide_response_body_override(
  self : BidiProtocol,
  context_id : String,
  destination : String,
  body_text : String,
) -> Unit {
  ignore(self)
  self.prepare_runtime_context_for_browsing_command(context_id)
  match destination {
    "script" =>
      ignore(evaluate_js_with_console(body_text, false, false, false, "{}"))
    "style" => {
      let body_json = Json::string(body_text).stringify()
      let expression = "(() => {" +
        "if (!document.body && document.documentElement && typeof document.createElement === \"function\") {" +
        "const body = document.createElement(\"body\");" +
        "document.documentElement.appendChild(body);" +
        "}" +
        "if (document.body && !document.querySelector(\"div\") && typeof document.createElement === \"function\") {" +
        "const div = document.createElement(\"div\");" +
        "document.body.appendChild(div);" +
        "}" +
        "const style = document.createElement(\"style\");" +
        "style.textContent = " +
        body_json +
        ";" +
        "const parent = document.head || document.documentElement;" +
        "if (parent) parent.appendChild(style);" +
        "const match = /color\\s*:\\s*([^;}\\n]+)/i.exec(style.textContent || \"\");" +
        "const fallbackColor = match && match[1] ? String(match[1]).trim() : \"rgb(0, 0, 0)\";" +
        "const originalGetComputedStyle = typeof globalThis.getComputedStyle === \"function\" ? globalThis.getComputedStyle.bind(globalThis) : null;" +
        "const craterGetComputedStyle = function(el) {" +
        "const base = originalGetComputedStyle ? originalGetComputedStyle(el) : ((el && el._style) || {});" +
        "return new Proxy(base || {}, {" +
        "get(target, prop) {" +
        "if (prop === \"getPropertyValue\") {" +
        "return function(name) {" +
        "const raw = target && target[name] ? target[name] : \"\";" +
        "if (String(name) === \"color\" && !raw) return fallbackColor;" +
        "return raw || \"\";" +
        "};" +
        "}" +
        "if (prop === \"color\") {" +
        "const raw = target && target[prop] ? target[prop] : \"\";" +
        "return raw || fallbackColor;" +
        "}" +
        "return target && target[prop] ? target[prop] : \"\";" +
        "}" +
        "});" +
        "};" +
        "globalThis.getComputedStyle = craterGetComputedStyle;" +
        "window.getComputedStyle = craterGetComputedStyle;" +
        "})()"
      ignore(evaluate_js_with_console(expression, false, false, false, "{}"))
    }
    _ => {
      let body_json = Json::string(body_text).stringify()
      let expression = "(() => {" +
        "if (!document.body && document.documentElement && typeof document.createElement === \"function\") {" +
        "const body = document.createElement(\"body\");" +
        "document.documentElement.appendChild(body);" +
        "}" +
        "if (document.body) {" +
        "document.body.innerHTML = " +
        body_json +
        ";" +
        "}" +
        "})()"
      ignore(evaluate_js_with_console(expression, false, false, false, "{}"))
    }
  }
}

///|
fn BidiProtocol::send_continue_blocked_response_result(
  self : BidiProtocol,
  request_id : Int,
  response_started_event : Json?,
  response_completed_event : Json?,
  auth_required_event : Json?,
  load_event : Json?,
  consumed : Bool,
  status_code : Int?,
  reason_phrase : String?,
  body_text : String?,
) -> Unit {
  let _ = self
  let result : Map[String, Json] = {}
  result["responseStartedEvent"] = match response_started_event {
    Some(event) => event
    None => Json::null()
  }
  result["responseCompletedEvent"] = match response_completed_event {
    Some(event) => event
    None => Json::null()
  }
  result["authRequiredEvent"] = match auth_required_event {
    Some(event) => event
    None => Json::null()
  }
  result["browsingContextLoad"] = match load_event {
    Some(event) => event
    None => Json::null()
  }
  result["consumed"] = Json::boolean(consumed)
  match status_code {
    Some(value) => result["statusCode"] = Json::number(value.to_double())
    None => ()
  }
  match reason_phrase {
    Some(value) => result["reasonPhrase"] = Json::string(value)
    None => ()
  }
  match body_text {
    Some(text) => result["bodyText"] = Json::string(text)
    None => result["bodyText"] = Json::null()
  }
  self.send_success(request_id, Some(make_object(result)))
}

///|
fn BidiProtocol::emit_synthetic_network_event_if_subscribed(
  self : BidiProtocol,
  event_name : String,
  event : Json?,
) -> Unit {
  match event {
    Some(Object(event_map)) =>
      match event_map.get("context") {
        Some(String(context_id)) =>
          if self.is_subscribed_for_context(event_name, context_id) {
            self.outbox.push(
              Event({ event_method: event_name, params: make_object(event_map) }),
            )
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn BidiProtocol::emit_synthetic_network_result_events(
  self : BidiProtocol,
  response_started_event : Json?,
  response_completed_event : Json?,
  auth_required_event : Json?,
  load_event : Json?,
) -> Unit {
  self.emit_synthetic_network_event_if_subscribed(
    "network.responseStarted", response_started_event,
  )
  self.emit_synthetic_network_event_if_subscribed(
    "network.responseCompleted", response_completed_event,
  )
  self.emit_synthetic_network_event_if_subscribed(
    "network.authRequired", auth_required_event,
  )
  match load_event {
    Some(Object(load_map)) =>
      self.outbox.push(
        Event({
          event_method: "browsingContext.load",
          params: make_object(load_map),
        }),
      )
    _ => ()
  }
}

///|
fn BidiProtocol::maybe_emit_followup_preflight_blocked_request(
  self : BidiProtocol,
  blocked_request : Map[String, Json],
) -> Unit {
  let http_method = match blocked_request.get("method") {
    Some(String(name)) => name.to_upper()
    _ => "GET"
  }
  let is_navigation = match
    get_map_field_with_alias(blocked_request, "isNavigation", "is_navigation") {
    Some(True) => true
    _ => false
  }
  if http_method != "OPTIONS" || is_navigation {
    return
  }
  let context_id = match
    get_map_field_with_alias(blocked_request, "contextId", "context_id") {
    Some(String(context_id)) => context_id
    _ => return
  }
  let url = match blocked_request.get("url") {
    Some(String(url)) => url
    _ => return
  }
  let event_name = "network.beforeRequestSent"
  if !self.is_subscribed_for_context(event_name, context_id) {
    return
  }
  let intercepts = self.resolve_matching_network_intercepts_internal(
    context_id, "beforeRequestSent", url,
  )
  if intercepts.length() == 0 {
    return
  }
  let request_token = self.next_synthetic_network_request_id()
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
  let input : SyntheticNetworkEventInput = {
    context_id,
    url,
    http_method: "GET",
    request_token,
    request_headers: resolved_request_headers,
    request_value: None,
    request_cookies: [],
    request_cookies_override: false,
    intercepts,
    redirect_count,
    navigation,
    destination,
    initiator_type,
  }
  let event = match
    self.build_synthetic_before_request_sent_event_json(0, input) {
    Some(event) => event
    None => return
  }
  self.outbox.push(Event({ event_method: event_name, params: event }))
  let followup_blocked_request : Map[String, Json] = {}
  followup_blocked_request["phase"] = Json::string("beforeRequestSent")
  followup_blocked_request["context_id"] = Json::string(context_id)
  followup_blocked_request["url"] = Json::string(url)
  followup_blocked_request["method"] = Json::string("GET")
  followup_blocked_request["request_headers"] = match
    blocked_request.get("request_headers") {
    Some(Object(request_headers)) => make_object(request_headers)
    _ => make_object({})
  }
  followup_blocked_request["redirect_count"] = Json::number(
    redirect_count.to_double(),
  )
  followup_blocked_request["navigation"] = match navigation {
    Some(navigation) => Json::string(navigation)
    None => Json::null()
  }
  followup_blocked_request["destination"] = Json::string(destination)
  followup_blocked_request["initiator_type"] = match initiator_type {
    Some(initiator_type) => Json::string(initiator_type)
    None => Json::null()
  }
  followup_blocked_request["is_navigation"] = Json::boolean(false)
  self.remember_network_blocked_request(request_token, followup_blocked_request)
}

///|
fn BidiProtocol::normalize_synthetic_network_continue_credentials(
  self : BidiProtocol,
  request_id : Int,
  raw_credentials : Json,
) -> SyntheticNetworkContinueCredentials? {
  let map = match raw_credentials {
    Object(map) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "credentials must be an object",
      )
      return None
    }
  }
  let credential_type = match map.get("type") {
    Some(String(credential_type)) => credential_type
    _ => {
      self.send_error(
        request_id, "invalid argument", "credentials.type must be a string",
      )
      return None
    }
  }
  if credential_type != "password" {
    self.send_error(
      request_id, "invalid argument", "credentials.type is invalid",
    )
    return None
  }
  let username = match map.get("username") {
    Some(String(username)) => username
    _ => {
      self.send_error(
        request_id, "invalid argument", "credentials.username must be a string",
      )
      return None
    }
  }
  let password = match map.get("password") {
    Some(String(password)) => password
    _ => {
      self.send_error(
        request_id, "invalid argument", "credentials.password must be a string",
      )
      return None
    }
  }
  Some({ username, password })
}

///|
fn BidiProtocol::normalize_synthetic_network_bytes_value(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json,
  field_name : String,
) -> Json? {
  let map = match raw_value {
    Object(map) => map
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + " must be an object",
      )
      return None
    }
  }
  let value_type = match map.get("type") {
    Some(String(value_type)) => value_type
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".type must be a string",
      )
      return None
    }
  }
  if value_type != "string" && value_type != "base64" {
    self.send_error(
      request_id,
      "invalid argument",
      field_name + ".type is invalid",
    )
    return None
  }
  let payload = match map.get("value") {
    Some(String(payload)) => payload
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".value must be a string",
      )
      return None
    }
  }
  Some(
    make_object({
      "type": Json::string(value_type),
      "value": Json::string(payload),
    }),
  )
}

///|
fn BidiProtocol::synthetic_network_text_from_bytes_value(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json,
  field_name : String,
) -> String? {
  let map = match raw_value {
    Object(map) => map
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + " must be an object",
      )
      return None
    }
  }
  let value_type = match map.get("type") {
    Some(String(value_type)) => value_type
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".type must be a string",
      )
      return None
    }
  }
  let payload = match map.get("value") {
    Some(String(payload)) => payload
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".value must be a string",
      )
      return None
    }
  }
  if value_type == "string" {
    return Some(payload)
  }
  if value_type == "base64" {
    return Some(decode_base64(payload))
  }
  self.send_error(
    request_id,
    "invalid argument",
    field_name + ".type is invalid",
  )
  None
}

///|
fn BidiProtocol::synthetic_network_string_from_bytes_value(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json,
  field_name : String,
) -> String? {
  let map = match raw_value {
    Object(map) => map
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + " must be an object",
      )
      return None
    }
  }
  let value_type = match map.get("type") {
    Some(String(value_type)) => value_type
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".type must be a string",
      )
      return None
    }
  }
  if value_type != "string" {
    self.send_error(
      request_id,
      "invalid argument",
      field_name + ".type is invalid",
    )
    return None
  }
  match map.get("value") {
    Some(String(payload)) => Some(payload)
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".value must be a string",
      )
      None
    }
  }
}

///|
fn BidiProtocol::normalize_synthetic_network_set_cookie_entries(
  self : BidiProtocol,
  request_id : Int,
  raw_cookies : Json?,
  base_url : String,
) -> SyntheticNetworkSetCookieEntries? {
  let items = match raw_cookies {
    Some(Array(items)) => items
    _ => {
      self.send_error(
        request_id, "invalid argument", "cookies must be an array",
      )
      return None
    }
  }
  let headers : Array[Json] = []
  let cookies : Array[StoredCookie] = []
  for item in items {
    let map = match item {
      Object(map) => map
      _ => {
        self.send_error(
          request_id, "invalid argument", "cookie entry must be an object",
        )
        return None
      }
    }
    let name = match map.get("name") {
      Some(String(name)) =>
        if is_valid_network_header_name_token(name) {
          name
        } else {
          self.send_error(
            request_id, "invalid argument", "cookie name is invalid",
          )
          return None
        }
      _ => {
        self.send_error(
          request_id, "invalid argument", "cookie name must be a string",
        )
        return None
      }
    }
    let value = match map.get("value") {
      Some(raw_value) =>
        match
          self.synthetic_network_string_from_bytes_value(
            request_id, raw_value, "cookie.value",
          ) {
          Some(value) => value
          None => return None
        }
      None => {
        self.send_error(
          request_id, "invalid argument", "cookie value must be an object",
        )
        return None
      }
    }
    let mut domain = storage_cookie_domain_from_base_url(base_url)
    let mut domain_explicit = false
    let mut path = "/"
    let mut http_only = false
    let mut secure = false
    let mut same_site = "none"
    let mut expiry : Int? = None
    let header_entry : Map[String, Json] = {}
    header_entry["name"] = Json::string(name)
    header_entry["value"] = Json::string(value)

    match map.get("domain") {
      Some(String(raw_domain)) => {
        let normalized_domain = storage_strip_leading_dot(
          raw_domain.trim().to_owned().to_lower(),
        )
        domain = normalized_domain
        domain_explicit = normalized_domain != ""
        header_entry["domain"] = Json::string(raw_domain)
      }
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie domain must be a string",
        )
        return None
      }
      None => ()
    }
    match map.get("expiry") {
      Some(String(raw_expiry)) => {
        header_entry["expiry"] = Json::string(raw_expiry)
        let parsed_expiry = js_parse_cookie_expiry_seconds(raw_expiry)
        if parsed_expiry >= 0 {
          expiry = Some(parsed_expiry)
        }
      }
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie expiry must be a string",
        )
        return None
      }
      None => ()
    }
    match map.get("path") {
      Some(String(raw_path)) => {
        path = raw_path
        header_entry["path"] = Json::string(raw_path)
      }
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie path must be a string",
        )
        return None
      }
      None => ()
    }
    match map.get("sameSite") {
      Some(String(raw_same_site)) => {
        let lowered_same_site = raw_same_site.to_lower()
        if lowered_same_site != "none" &&
          lowered_same_site != "lax" &&
          lowered_same_site != "strict" {
          self.send_error(
            request_id, "invalid argument", "cookie sameSite is invalid",
          )
          return None
        }
        same_site = lowered_same_site
        header_entry["sameSite"] = Json::string(lowered_same_site)
      }
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie sameSite must be a string",
        )
        return None
      }
      None => ()
    }
    match map.get("httpOnly") {
      Some(True) => {
        http_only = true
        header_entry["httpOnly"] = Json::boolean(true)
      }
      Some(False) => header_entry["httpOnly"] = Json::boolean(false)
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie httpOnly must be a boolean",
        )
        return None
      }
      None => ()
    }
    match map.get("secure") {
      Some(True) => {
        secure = true
        header_entry["secure"] = Json::boolean(true)
      }
      Some(False) => header_entry["secure"] = Json::boolean(false)
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie secure must be a boolean",
        )
        return None
      }
      None => ()
    }
    match map.get("maxAge") {
      Some(raw_max_age) =>
        match
          json_as_safe_int(raw_max_age, -9007199254740991.0, 9007199254740991.0) {
          Some(max_age) => {
            header_entry["maxAge"] = Json::number(max_age.to_double())
            expiry = Some(storage_now_seconds() + max_age)
          }
          None => {
            self.send_error(
              request_id, "invalid argument", "cookie maxAge must be an integer",
            )
            return None
          }
        }
      None => ()
    }

    cookies.push({
      name,
      value_text: value,
      domain,
      domain_explicit,
      path,
      http_only,
      secure,
      same_site,
      expiry,
      context_id: None,
      user_context: None,
      source_origin: None,
    })
    headers.push(
      synthetic_network_header_string_entry(
        "Set-Cookie",
        synthetic_network_format_set_cookie_header(header_entry),
      ),
    )
  }
  Some({ headers, cookies })
}

///|
fn synthetic_network_format_set_cookie_header(
  entry : Map[String, Json],
) -> String {
  let parts : Array[String] = []
  let name = match entry.get("name") {
    Some(String(name)) => name
    _ => ""
  }
  let value = match entry.get("value") {
    Some(String(value)) => value
    _ => ""
  }
  parts.push(name + "=" + value)
  match entry.get("path") {
    Some(String(path)) => parts.push("Path=" + path)
    _ => ()
  }
  match entry.get("domain") {
    Some(String(domain)) => parts.push("Domain=" + domain)
    _ => ()
  }
  match entry.get("expiry") {
    Some(String(expiry)) => parts.push("Expires=" + expiry)
    _ => ()
  }
  match entry.get("maxAge") {
    Some(Number(max_age, ..)) =>
      parts.push("Max-Age=" + max_age.to_int().to_string())
    _ => ()
  }
  match entry.get("httpOnly") {
    Some(True) => parts.push("HttpOnly")
    _ => ()
  }
  match entry.get("secure") {
    Some(True) => parts.push("Secure")
    _ => ()
  }
  match entry.get("sameSite") {
    Some(String(raw_same_site)) => {
      let same_site = raw_same_site.to_lower()
      let mapped = if same_site == "none" {
        "None"
      } else if same_site == "lax" {
        "Lax"
      } else if same_site == "strict" {
        "Strict"
      } else {
        raw_same_site
      }
      parts.push("SameSite=" + mapped)
    }
    _ => ()
  }
  parts.join(";")
}

///|
fn synthetic_network_extract_set_cookie_entries(
  headers : Array[Json],
  base_url : String,
) -> Array[StoredCookie] {
  let cookies : Array[StoredCookie] = []
  for header in headers {
    let map = match header {
      Object(map) => map
      _ => continue
    }
    let name = match map.get("name") {
      Some(String(name)) => name
      _ => continue
    }
    if !is_ascii_case_insensitive_equal(name, "set-cookie") {
      continue
    }
    let value_map = match map.get("value") {
      Some(Object(value_map)) => value_map
      _ => continue
    }
    let value_type = match value_map.get("type") {
      Some(String(value_type)) => value_type
      _ => continue
    }
    if value_type != "string" {
      continue
    }
    let header_value = match value_map.get("value") {
      Some(String(header_value)) => header_value
      _ => continue
    }
    match
      synthetic_network_parse_set_cookie_header_value(header_value, base_url) {
      Some(cookie) => cookies.push(cookie)
      None => ()
    }
  }
  cookies
}

///|
fn synthetic_network_parse_set_cookie_header_value(
  header_value : String,
  base_url : String,
) -> StoredCookie? {
  let attributes : Array[String] = []
  let mut first : String? = None
  for raw_part in header_value.split(";") {
    let part = raw_part.trim().to_owned()
    match first {
      Some(_) => attributes.push(part)
      None => first = Some(part)
    }
  }
  let first = match first {
    Some(first) => first
    None => return None
  }
  match find_substring(first, "=", 0) {
    Some(eq_idx) => {
      let name = storage_slice(first, 0, eq_idx).trim().to_owned()
      let value_start = eq_idx + 1
      let value = if value_start <= first.length() {
        storage_slice_from(first, value_start).trim().to_owned()
      } else {
        ""
      }
      if name == "" || !is_valid_network_header_name_token(name) {
        return None
      }
      let mut domain = storage_cookie_domain_from_base_url(base_url)
      let mut domain_explicit = false
      let mut path = "/"
      let mut http_only = false
      let mut secure = false
      let mut same_site = "none"
      let mut expiry : Int? = None

      for raw_attr in attributes {
        let attr = raw_attr.trim().to_owned()
        if attr == "" {
          continue
        }
        let (attr_name, attr_value) = match find_substring(attr, "=", 0) {
          Some(attr_eq_idx) => {
            let attr_value_start = attr_eq_idx + 1
            (
              storage_slice(attr, 0, attr_eq_idx).trim().to_owned().to_lower(),
              if attr_value_start <= attr.length() {
                storage_slice_from(attr, attr_value_start).trim().to_owned()
              } else {
                ""
              },
            )
          }
          None => (attr.to_lower(), "")
        }
        if attr_name == "domain" {
          let normalized_domain = storage_strip_leading_dot(
            attr_value.trim().to_owned().to_lower(),
          )
          if normalized_domain != "" {
            domain = normalized_domain
            domain_explicit = true
          }
        } else if attr_name == "path" {
          if attr_value != "" {
            path = attr_value
          }
        } else if attr_name == "samesite" {
          let lowered = attr_value.to_lower()
          if lowered == "none" || lowered == "lax" || lowered == "strict" {
            same_site = lowered
          }
        } else if attr_name == "max-age" {
          let parsed_max_age : Int? = Some(@string.parse_int(attr_value)) catch {
            _ => None
          }
          match parsed_max_age {
            Some(parsed_max_age) =>
              expiry = Some(storage_now_seconds() + parsed_max_age)
            None => ()
          }
        } else if attr_name == "expires" {
          let parsed_expiry = js_parse_cookie_expiry_seconds(attr_value)
          if parsed_expiry >= 0 {
            expiry = Some(parsed_expiry)
          }
        } else if attr_name == "httponly" {
          http_only = true
        } else if attr_name == "secure" {
          secure = true
        }
      }

      Some({
        name,
        value_text: value,
        domain,
        domain_explicit,
        path,
        http_only,
        secure,
        same_site,
        expiry,
        context_id: None,
        user_context: None,
        source_origin: None,
      })
    }
    None => None
  }
}

///|
fn synthetic_network_credentials_match_expected(
  url : String,
  credentials : SyntheticNetworkContinueCredentials?,
) -> Bool {
  match credentials {
    Some(credentials) =>
      match synthetic_network_expected_auth_credentials(url) {
        Some(expected) =>
          credentials.username == expected.username &&
          credentials.password == expected.password
        None => true
      }
    None => false
  }
}

///|
fn synthetic_network_expected_auth_credentials(
  url : String,
) -> SyntheticNetworkContinueCredentials? {
  let username = synthetic_network_first_query_value(url, "username")
  let password = synthetic_network_first_query_value(url, "password")
  match (username, password) {
    (Some(username), Some(password)) => Some({ username, password })
    _ => None
  }
}

///|
fn BidiProtocol::build_synthetic_auth_required_event_json(
  self : BidiProtocol,
  request_id : Int,
  input : SyntheticNetworkEventInput,
  blocked_request : Map[String, Json],
) -> Json? {
  let resolved_overrides = self.resolve_synthetic_response_overrides_internal(
    input.context_id,
    input.url,
    input.http_method,
    input.request_headers,
    false,
  )
  let realm = synthetic_network_first_query_value(input.url, "realm").unwrap_or(
    "testrealm",
  )
  let status = synthetic_network_blocked_response_status(blocked_request)
  let response_overrides : SyntheticNetworkResponseOverrides = {
    from_cache: resolved_overrides.from_cache,
    headers: if synthetic_network_blocked_response_headers(blocked_request).length() >
      0 {
      synthetic_network_blocked_response_headers(blocked_request)
    } else {
      resolved_overrides.headers
    },
    mime_type: resolved_overrides.mime_type,
    protocol: resolved_overrides.protocol,
    status,
    status_text: synthetic_network_blocked_response_status_text(
      blocked_request, status,
    ),
    auth_challenges: Some(
      Json::array([
        make_object({
          "scheme": Json::string("Basic"),
          "realm": Json::string(realm),
        }),
      ]),
    ),
  }
  self.build_synthetic_response_event_json(
    request_id, input, response_overrides,
  )
}

///|
fn BidiProtocol::store_synthetic_response_cookie(
  self : BidiProtocol,
  context_id : String,
  cookie : StoredCookie,
) -> Unit {
  let stored_cookie : StoredCookie = {
    ..cookie,
    context_id: Some(context_id),
    user_context: Some(self.resolve_storage_user_context(context_id)),
    source_origin: storage_cookie_origin_from_base_url(
      self.get_context_cookie_base_url(context_id),
    ),
  }
  match stored_cookie.expiry {
    Some(expiry) =>
      if expiry <= storage_now_seconds() {
        self.delete_matching_storage_cookie_identity(
          stored_cookie.context_id,
          stored_cookie.user_context,
          stored_cookie.source_origin,
          stored_cookie.name,
          stored_cookie.domain,
          stored_cookie.path,
        )
      } else {
        self.store_storage_cookie(stored_cookie)
      }
    None => self.store_storage_cookie(stored_cookie)
  }
}

///|
fn BidiProtocol::synthetic_network_request_lookup_id(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let _ = self
  match params {
    Some(Object(map)) =>
      match map.get("request") {
        Some(String(request_lookup_id)) => Some(request_lookup_id)
        _ => {
          self.send_error(
            request_id, "invalid argument", "request must be a string",
          )
          None
        }
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      None
    }
  }
}
