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
fn BidiProtocol::handle_network_build_before_request_sent_event(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let input = match
    self.normalize_synthetic_network_event_input(request_id, params) {
    Some(input) => input
    None => return
  }
  let event = match
    self.build_synthetic_before_request_sent_event_json(request_id, input) {
    Some(event) => event
    None => return
  }
  self.send_success(request_id, Some(make_object({ "event": event })))
}

///|
fn BidiProtocol::handle_network_build_response_event(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let input = match
    self.normalize_synthetic_network_event_input(request_id, params) {
    Some(input) => input
    None => return
  }
  let response_overrides = match
    self.normalize_synthetic_network_response_overrides(
      request_id,
      get_param_raw(params, "responseOverrides"),
    ) {
    Some(response_overrides) => response_overrides
    None => return
  }
  let event = match
    self.build_synthetic_response_event_json(
      request_id, input, response_overrides,
    ) {
    Some(event) => event
    None => return
  }
  self.send_success(request_id, Some(make_object({ "event": event })))
}

///|
fn BidiProtocol::handle_network_build_fetch_error_event(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let input = match
    self.normalize_synthetic_network_event_input(request_id, params) {
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
  self.send_success(request_id, Some(make_object({ "event": event })))
}

///|
fn BidiProtocol::handle_network_build_headers_echo_payload(
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
  if not(self.manager.has_session(context_id)) {
    self.send_error(
      request_id,
      "no such frame",
      "Unknown context: " + context_id,
    )
    return
  }
  let request_headers = match
    self.normalize_synthetic_network_header_entries(
      request_id,
      get_map_field_with_alias(map, "requestHeaders", "request_headers"),
    ) {
    Some(request_headers) => request_headers
    None => return
  }
  let payload = self.build_network_headers_echo_payload(
    context_id, request_headers,
  )
  self.send_success(
    request_id,
    Some(make_object({ "payload": Json::string(payload) })),
  )
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
  if not(self.manager.has_session(context_id)) {
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
  let event_name = "network.beforeRequestSent"
  if not(self.is_subscribed_for_context(event_name, context_id)) {
    self.send_success(
      request_id,
      Some(make_object({ "blocked": Json::boolean(false) })),
    )
    return
  }
  let intercepts = self.resolve_matching_network_intercepts_internal(
    context_id, "beforeRequestSent", url,
  )
  if intercepts.length() == 0 {
    self.send_success(
      request_id,
      Some(make_object({ "blocked": Json::boolean(false) })),
    )
    return
  }

  let navigation_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
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
    None => return
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
  self.send_success(
    request_id,
    Some(
      make_object({
        "blocked": Json::boolean(true),
        "navigation": Json::string(navigation_id),
        "url": Json::string(url),
      }),
    ),
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
  self.forget_network_blocked_request(blocked_request_id)
  self.send_success(request_id, Some(make_object({ "event": event })))
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
  if has_body {
    match map.get("body") {
      Some(raw_body) =>
        match self.normalize_synthetic_network_body_text(request_id, raw_body) {
          Some(text) => body_text = Some(text)
          None => return
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
      return
    }

    let should_continue = synthetic_network_credentials_match_expected(
      input.url,
      credentials,
    )
    if not(should_continue) {
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
      return
    }
    if not(has_status_code) {
      status_code = 200
    }
    if not(has_reason_phrase) {
      reason_phrase = "OK"
    }
    if not(has_headers) && not(has_cookies) {
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
fn BidiProtocol::normalize_synthetic_network_body_text(
  self : BidiProtocol,
  request_id : Int,
  raw_body : Json,
) -> String? {
  self.synthetic_network_text_from_bytes_value(request_id, raw_body, "body")
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
          raw_domain.trim().to_string().to_lower(),
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
    if not(is_ascii_case_insensitive_equal(name, "set-cookie")) {
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
    let part = raw_part.trim().to_string()
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
      let name = storage_slice(first, 0, eq_idx).trim().to_string()
      let value_start = eq_idx + 1
      let value = if value_start <= first.length() {
        storage_slice_from(first, value_start).trim().to_string()
      } else {
        ""
      }
      if name == "" || not(is_valid_network_header_name_token(name)) {
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
        let attr = raw_attr.trim().to_string()
        if attr == "" {
          continue
        }
        let (attr_name, attr_value) = match find_substring(attr, "=", 0) {
          Some(attr_eq_idx) => {
            let attr_value_start = attr_eq_idx + 1
            (
              storage_slice(attr, 0, attr_eq_idx).trim().to_string().to_lower(),
              if attr_value_start <= attr.length() {
                storage_slice_from(attr, attr_value_start).trim().to_string()
              } else {
                ""
              },
            )
          }
          None => (attr.to_lower(), "")
        }
        if attr_name == "domain" {
          let normalized_domain = storage_strip_leading_dot(
            attr_value.trim().to_string().to_lower(),
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
          let parsed_max_age : Int? = Some(@strconv.parse_int(attr_value)) catch {
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
  if not(self.manager.has_session(context_id)) {
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
  if not(self.manager.has_session(context_id)) {
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
              self.network_extra_headers_by_context.remove(ctx_id)
            } else {
              self.network_extra_headers_by_context[ctx_id] = synthetic_network_copy_string_map(
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
              self.network_extra_headers_by_user_context.remove(user_context_id)
            } else {
              self.network_extra_headers_by_user_context[user_context_id] = synthetic_network_copy_string_map(
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
    self.network_extra_headers_global,
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
  synthetic_network_merge_string_map(merged, self.network_extra_headers_global)
  let user_context_id = self.resolve_storage_user_context(context_id)
  match self.network_extra_headers_by_user_context.get(user_context_id) {
    Some(headers) => synthetic_network_merge_string_map(merged, headers)
    None => ()
  }
  for scope_id in self.storage_context_ancestry(context_id) {
    match self.network_extra_headers_by_context.get(scope_id) {
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
    headers[name] = Json::array([Json::string(value)])
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

///|
fn BidiProtocol::normalize_synthetic_network_cookie_entries(
  self : BidiProtocol,
  request_id : Int,
  raw_cookies : Json?,
) -> SyntheticNetworkCookieOverride? {
  match raw_cookies {
    None => Some({ enabled: false, cookies: [] })
    Some(Null) => Some({ enabled: true, cookies: [] })
    Some(Array(items)) => {
      let cookies : Array[Json] = []
      for item in items {
        let map = match item {
          Object(map) => map
          _ => {
            self.send_error(
              request_id, "invalid argument", "requestCookies entry must be an object",
            )
            return None
          }
        }
        let name = match map.get("name") {
          Some(String(name)) => name
          _ => {
            self.send_error(
              request_id, "invalid argument", "requestCookies.name must be a string",
            )
            return None
          }
        }
        let value = match map.get("value") {
          Some(Object(value_map)) => {
            let value_type = match value_map.get("type") {
              Some(String(value_type)) => value_type
              _ => {
                self.send_error(
                  request_id, "invalid argument", "requestCookies.value.type must be a string",
                )
                return None
              }
            }
            let payload = match value_map.get("value") {
              Some(String(payload)) => payload
              _ => {
                self.send_error(
                  request_id, "invalid argument", "requestCookies.value.value must be a string",
                )
                return None
              }
            }
            if value_type != "string" {
              self.send_error(
                request_id, "invalid argument", "requestCookies.value.type is invalid",
              )
              return None
            }
            make_object({
              "type": Json::string("string"),
              "value": Json::string(payload),
            })
          }
          _ => {
            self.send_error(
              request_id, "invalid argument", "requestCookies.value must be an object",
            )
            return None
          }
        }
        cookies.push(
          make_object({ "name": Json::string(name), "value": value }),
        )
      }
      Some({ enabled: true, cookies })
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "requestCookies must be an array",
      )
      None
    }
  }
}

///|
fn BidiProtocol::normalize_synthetic_network_continue_url(
  self : BidiProtocol,
  request_id : Int,
  raw_url : Json,
) -> String? {
  let url = match raw_url {
    String(url) => url
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return None
    }
  }
  if synthetic_network_is_valid_continue_url(url) {
    Some(url)
  } else {
    self.send_error(request_id, "invalid argument", "url is invalid")
    None
  }
}

///|
fn BidiProtocol::normalize_synthetic_network_string_list(
  self : BidiProtocol,
  request_id : Int,
  raw_list : Json?,
  field_name : String,
) -> Array[String]? {
  match raw_list {
    None | Some(Null) => Some([])
    Some(Array(items)) => {
      let values : Array[String] = []
      for item in items {
        match item {
          String(value) => values.push(value)
          _ => {
            self.send_error(
              request_id,
              "invalid argument",
              field_name + " entries must be strings",
            )
            return None
          }
        }
      }
      Some(values)
    }
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + " must be an array",
      )
      None
    }
  }
}

///|
fn BidiProtocol::normalize_synthetic_network_response_overrides(
  self : BidiProtocol,
  request_id : Int,
  raw_overrides : Json?,
) -> SyntheticNetworkResponseOverrides? {
  let overrides = match raw_overrides {
    None | Some(Null) =>
      return Some({
        from_cache: false,
        headers: [],
        mime_type: "text/plain",
        protocol: "http/1.1",
        status: 200,
        status_text: "OK",
        auth_challenges: None,
      })
    Some(Object(map)) => map
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides must be an object",
      )
      return None
    }
  }
  let from_cache = match overrides.get("fromCache") {
    Some(True) => true
    Some(False) | None => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides.fromCache must be a boolean",
      )
      return None
    }
  }
  let headers = match
    self.normalize_synthetic_network_header_entries(
      request_id,
      overrides.get("headers"),
    ) {
    Some(headers) => headers
    None => return None
  }
  let mime_type = match overrides.get("mimeType") {
    Some(String(value)) => value
    None => "text/plain"
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides.mimeType must be a string",
      )
      return None
    }
  }
  let protocol = match overrides.get("protocol") {
    Some(String(value)) => value
    None => "http/1.1"
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides.protocol must be a string",
      )
      return None
    }
  }
  let status = match overrides.get("status") {
    Some(value) =>
      match storage_json_non_negative_int(value) {
        Some(status) => status
        None => {
          self.send_error(
            request_id, "invalid argument", "responseOverrides.status must be a non-negative integer",
          )
          return None
        }
      }
    None => 200
  }
  let status_text = match overrides.get("statusText") {
    Some(String(value)) => value
    None => synthetic_network_status_text_for_code(status)
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides.statusText must be a string",
      )
      return None
    }
  }
  let mut auth_challenges : Json? = match overrides.get("authChallenges") {
    None | Some(Null) => None
    Some(Array(values)) => Some(Json::array(values))
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides.authChallenges must be an array",
      )
      return None
    }
  }
  let missing_auth_challenges = match auth_challenges {
    None => true
    Some(_) => false
  }
  if (status == 401 || status == 407) && missing_auth_challenges {
    auth_challenges = Some(Json::array([]))
  }
  Some({
    from_cache,
    headers,
    mime_type,
    protocol,
    status,
    status_text,
    auth_challenges,
  })
}

///|
fn BidiProtocol::build_synthetic_before_request_sent_event_json(
  self : BidiProtocol,
  request_id : Int,
  input : SyntheticNetworkEventInput,
) -> Json? {
  let now = input_now_ms()
  let request_payload = match
    self.build_synthetic_network_request_payload_json(request_id, input, now) {
    Some(request_payload) => request_payload
    None => return None
  }
  Some(
    make_object(
      self.build_synthetic_network_event_base_map(input, request_payload, now),
    ),
  )
}

///|
fn BidiProtocol::build_synthetic_response_event_json(
  self : BidiProtocol,
  request_id : Int,
  input : SyntheticNetworkEventInput,
  response_overrides : SyntheticNetworkResponseOverrides,
) -> Json? {
  let now = input_now_ms()
  let request_payload = match
    self.build_synthetic_network_request_payload_json(request_id, input, now) {
    Some(request_payload) => request_payload
    None => return None
  }
  let event = self.build_synthetic_network_event_base_map(
    input, request_payload, now,
  )
  event["response"] = self.build_synthetic_network_response_payload_json(
    input.url,
    response_overrides,
  )
  Some(make_object(event))
}

///|
fn BidiProtocol::build_synthetic_fetch_error_event_json(
  self : BidiProtocol,
  request_id : Int,
  input : SyntheticNetworkEventInput,
  error_text : String,
) -> Json? {
  let now = input_now_ms()
  let request_payload = match
    self.build_synthetic_network_request_payload_json(request_id, input, now) {
    Some(request_payload) => request_payload
    None => return None
  }
  let event = self.build_synthetic_network_event_base_map(
    input, request_payload, now,
  )
  event["errorText"] = Json::string(error_text)
  Some(make_object(event))
}

///|
fn BidiProtocol::build_synthetic_network_request_payload_json(
  self : BidiProtocol,
  request_id : Int,
  input : SyntheticNetworkEventInput,
  now : Double,
) -> Json? {
  let body_size = match
    self.synthetic_network_request_body_size(request_id, input.request_value) {
    Some(body_size) => body_size
    None => return None
  }
  let cookies = if input.request_cookies_override {
    input.request_cookies
  } else {
    self.resolve_storage_request_cookies(input.context_id, Some(input.url))
  }
  let request : Map[String, Json] = {}
  request["bodySize"] = Json::number(body_size.to_double())
  request["cookies"] = Json::array(cookies)
  request["destination"] = Json::string(input.destination)
  request["headers"] = Json::array(input.request_headers)
  request["headersSize"] = Json::number(0.0)
  request["initiatorType"] = match input.initiator_type {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  request["method"] = Json::string(input.http_method)
  request["request"] = Json::string(input.request_token)
  request["timings"] = self.build_synthetic_network_timings_json(now)
  request["url"] = Json::string(input.url)
  Some(make_object(request))
}

///|
fn BidiProtocol::build_synthetic_network_event_base_map(
  self : BidiProtocol,
  input : SyntheticNetworkEventInput,
  request_payload : Json,
  now : Double,
) -> Map[String, Json] {
  let _ = self
  let event : Map[String, Json] = {}
  event["context"] = Json::string(input.context_id)
  event["isBlocked"] = Json::boolean(input.intercepts.length() > 0)
  event["navigation"] = match input.navigation {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  event["redirectCount"] = Json::number(input.redirect_count.to_double())
  event["request"] = request_payload
  event["timestamp"] = Json::number(now)
  if input.intercepts.length() > 0 {
    let intercepts : Array[Json] = []
    for intercept in input.intercepts {
      intercepts.push(Json::string(intercept))
    }
    event["intercepts"] = Json::array(intercepts)
  }
  event
}

///|
fn BidiProtocol::build_synthetic_network_timings_json(
  self : BidiProtocol,
  now : Double,
) -> Json {
  let _ = self
  make_object({
    "timeOrigin": Json::number(now),
    "requestTime": Json::number(0.0),
    "redirectStart": Json::number(0.0),
    "redirectEnd": Json::number(0.0),
    "fetchStart": Json::number(0.0),
    "dnsStart": Json::number(0.0),
    "dnsEnd": Json::number(0.0),
    "connectStart": Json::number(0.0),
    "connectEnd": Json::number(0.0),
    "tlsStart": Json::number(0.0),
    "requestStart": Json::number(0.0),
    "responseStart": Json::number(0.0),
    "responseEnd": Json::number(0.0),
  })
}

///|
fn BidiProtocol::build_synthetic_network_response_payload_json(
  self : BidiProtocol,
  url : String,
  response_overrides : SyntheticNetworkResponseOverrides,
) -> Json {
  let _ = self
  let response : Map[String, Json] = {}
  response["bodySize"] = Json::number(0.0)
  response["bytesReceived"] = Json::number(0.0)
  response["content"] = make_object({ "size": Json::number(0.0) })
  response["fromCache"] = Json::boolean(response_overrides.from_cache)
  response["headers"] = Json::array(response_overrides.headers)
  response["headersSize"] = Json::number(0.0)
  response["mimeType"] = Json::string(response_overrides.mime_type)
  response["protocol"] = Json::string(response_overrides.protocol)
  response["status"] = Json::number(response_overrides.status.to_double())
  response["statusText"] = Json::string(response_overrides.status_text)
  response["url"] = Json::string(url)
  match response_overrides.auth_challenges {
    Some(auth_challenges) => response["authChallenges"] = auth_challenges
    None => ()
  }
  make_object(response)
}

///|
fn BidiProtocol::synthetic_network_request_body_size(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json?,
) -> Int? {
  let _ = self
  match raw_value {
    None | Some(Null) => Some(0)
    Some(Object(map)) => {
      let value_type = match map.get("type") {
        Some(String(value_type)) => value_type
        _ => {
          self.send_error(
            request_id, "invalid argument", "requestValue.type must be a string",
          )
          return None
        }
      }
      let payload = match map.get("value") {
        Some(String(payload)) => payload
        _ => {
          self.send_error(
            request_id, "invalid argument", "requestValue.value must be a string",
          )
          return None
        }
      }
      if value_type == "string" {
        return Some(js_utf8_byte_length(payload))
      }
      if value_type == "base64" {
        return Some(js_base64_byte_length(payload))
      }
      self.send_error(
        request_id, "invalid argument", "requestValue.type is invalid",
      )
      None
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "requestValue must be an object",
      )
      None
    }
  }
}

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
  let cache_behavior = match map.get("cacheBehavior") {
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
      self.network_cache_behavior_global = cache_behavior
      let keys : Array[String] = []
      for key, _ in self.network_cache_behavior_by_context {
        keys.push(key)
      }
      for key in keys {
        self.network_cache_behavior_by_context.remove(key)
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
            if not(self.manager.has_session(ctx_id)) {
              self.send_error(
                request_id,
                "no such frame",
                "Unknown context: " + ctx_id,
              )
              return
            } else {
              self.network_cache_behavior_by_context[ctx_id] = cache_behavior
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
  if not(self.manager.has_session(context_id)) {
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
  self.network_cache_behavior_global = "default"
  synthetic_network_replace_string_map(self.network_extra_headers_global, {})
  let extra_header_context_keys : Array[String] = []
  for key, _ in self.network_extra_headers_by_context {
    extra_header_context_keys.push(key)
  }
  for key in extra_header_context_keys {
    self.network_extra_headers_by_context.remove(key)
  }
  let extra_header_user_context_keys : Array[String] = []
  for key, _ in self.network_extra_headers_by_user_context {
    extra_header_user_context_keys.push(key)
  }
  for key in extra_header_user_context_keys {
    self.network_extra_headers_by_user_context.remove(key)
  }
  let behavior_keys : Array[String] = []
  for key, _ in self.network_cache_behavior_by_context {
    behavior_keys.push(key)
  }
  for key in behavior_keys {
    self.network_cache_behavior_by_context.remove(key)
  }
  let cache_keys : Array[String] = []
  for key, _ in self.network_cached_requests_by_context {
    cache_keys.push(key)
  }
  for key in cache_keys {
    self.network_cached_requests_by_context.remove(key)
  }
  let blocked_keys : Array[String] = []
  for key, _ in self.network_blocked_requests {
    blocked_keys.push(key)
  }
  for key in blocked_keys {
    self.network_blocked_requests.remove(key)
  }
}

///|
fn BidiProtocol::clear_network_state_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.network_extra_headers_by_context.remove(ctx_id)
  self.network_cache_behavior_by_context.remove(ctx_id)
  self.network_cached_requests_by_context.remove(ctx_id)
  let blocked_keys : Array[String] = []
  for request_id, blocked_request in self.network_blocked_requests {
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
    self.network_blocked_requests.remove(request_id)
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
  self.network_blocked_requests[request_id] = make_object(normalized)
}

///|
fn BidiProtocol::get_network_blocked_request(
  self : BidiProtocol,
  request_id : String,
) -> Map[String, Json]? {
  match self.network_blocked_requests.get(request_id) {
    Some(Object(blocked_request)) => Some(blocked_request)
    _ => None
  }
}

///|
fn BidiProtocol::forget_network_blocked_request(
  self : BidiProtocol,
  request_id : String,
) -> Unit {
  self.network_blocked_requests.remove(request_id)
}

///|
fn BidiProtocol::has_network_blocked_navigation_request(
  self : BidiProtocol,
  ctx_id : String,
  navigation_id : String?,
) -> Bool {
  for _, blocked_request in self.network_blocked_requests {
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

///|
fn BidiProtocol::resolve_synthetic_response_overrides_internal(
  self : BidiProtocol,
  context_id : String,
  url : String,
  http_method : String,
  request_headers : Array[Json],
  update_cache : Bool,
) -> SyntheticNetworkResponseOverrides {
  let mut status = 200
  let mut from_cache = false
  let mut protocol = "http/1.1"
  let mut auth_challenges : Json? = None
  let headers : Array[Json] = []
  let path = synthetic_network_request_path(url)
  let method_upper = http_method.to_upper()
  let cache_enabled = self.synthetic_network_cache_enabled(context_id)
  let cache_key = synthetic_network_cache_key(method_upper, url)
  let context_cache = self.network_cached_requests_by_context
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
        self.network_cached_requests_by_context[context_id] = context_cache
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
        self.network_cached_requests_by_context[context_id] = context_cache
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
          let name = raw_header[:idx].to_string() catch { _ => "" }
          let value_start = idx + 1
          let value = if value_start <= raw_header.length() {
            raw_header[value_start:].to_string() catch {
              _ => ""
            }
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
  overrides : SyntheticNetworkResponseOverrides,
) -> Json {
  let _ = self
  let result : Map[String, Json] = {}
  result["fromCache"] = Json::boolean(overrides.from_cache)
  result["headers"] = Json::array(overrides.headers)
  result["mimeType"] = Json::string(overrides.mime_type)
  result["protocol"] = Json::string(overrides.protocol)
  result["status"] = Json::number(overrides.status.to_double())
  result["statusText"] = Json::string(overrides.status_text)
  match overrides.auth_challenges {
    Some(auth_challenges) => result["authChallenges"] = auth_challenges
    None => ()
  }
  make_object(result)
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
  self.network_cache_behavior_by_context
  .get(context_id)
  .unwrap_or(self.network_cache_behavior_global)
}

///|
fn synthetic_network_header_entries_from_object(
  raw_headers : Map[String, Json],
) -> Array[Json] {
  let headers : Array[Json] = []
  for name, raw_value in raw_headers {
    headers.push(
      synthetic_network_header_string_entry(
        name,
        synthetic_network_header_value_from_json(raw_value),
      ),
    )
  }
  headers
}

///|
fn synthetic_network_merge_header_entries(headers : Array[Json]) -> Array[Json] {
  let order : Array[String] = []
  let names : Map[String, String] = {}
  let values : Map[String, String] = {}
  for header in headers {
    let name = match synthetic_network_header_entry_name(header) {
      Some(name) => name
      None => continue
    }
    let value = match synthetic_network_header_entry_string_value(header) {
      Some(value) => value
      None => continue
    }
    let key = name.to_lower()
    if values.contains(key) {
      let merged = values.get(key).unwrap_or("")
      values[key] = merged + ", " + value
    } else {
      order.push(key)
      names[key] = name
      values[key] = value
    }
  }
  let merged : Array[Json] = []
  for key in order {
    let name = names.get(key).unwrap_or(key)
    let value = values.get(key).unwrap_or("")
    merged.push(synthetic_network_header_string_entry(name, value))
  }
  merged
}

///|
fn synthetic_network_header_entry_name(header : Json) -> String? {
  match header {
    Object(map) =>
      match map.get("name") {
        Some(String(name)) => Some(name)
        _ => None
      }
    _ => None
  }
}

///|
fn synthetic_network_header_entry_string_value(header : Json) -> String? {
  match header {
    Object(map) =>
      match map.get("value") {
        Some(Object(value_map)) =>
          match value_map.get("value") {
            Some(String(value)) => Some(value)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn synthetic_network_header_value_from_json(raw_value : Json) -> String {
  match raw_value {
    String(value) => value
    Number(value, ..) => value.to_string()
    True => "true"
    False => "false"
    Null => ""
    Array(_) | Object(_) => raw_value.stringify()
  }
}

///|
fn synthetic_network_is_valid_continue_url(url : String) -> Bool {
  if url.has_prefix("data:") {
    return true
  }
  if url.has_prefix("http://") {
    return has_valid_http_host(url, 7)
  }
  if url.has_prefix("https://") {
    return has_valid_http_host(url, 8)
  }
  false
}

///|
fn synthetic_network_cache_key(http_method : String, url : String) -> String {
  http_method + " " + url
}

///|
fn synthetic_network_request_path(url : String) -> String {
  if url.has_prefix("http://") {
    storage_http_path(url, 7)
  } else if url.has_prefix("https://") {
    storage_http_path(url, 8)
  } else {
    ""
  }
}

///|
fn synthetic_network_first_query_value(url : String, key : String) -> String? {
  let values = synthetic_network_query_values(url, key)
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
fn synthetic_network_query_values(url : String, key : String) -> Array[String] {
  let values : Array[String] = []
  match find_substring(url, "?", 0) {
    Some(query_idx) => {
      let query_start = query_idx + 1
      if query_start >= url.length() {
        return values
      }
      let query = url[query_start:].to_string() catch { _ => "" }
      for part in query.split("&") {
        let raw = part.to_string()
        if raw.length() == 0 {
          continue
        }
        match find_substring(raw, "=", 0) {
          Some(eq_idx) => {
            let part_key = raw[:eq_idx].to_string() catch { _ => "" }
            if part_key != key {
              continue
            }
            let value_start = eq_idx + 1
            let raw_value = if value_start <= raw.length() {
              raw[value_start:].to_string() catch {
                _ => ""
              }
            } else {
              ""
            }
            values.push(js_decode_query_component(raw_value))
          }
          None => if raw == key { values.push("") }
        }
      }
      values
    }
    None => values
  }
}

///|
fn synthetic_network_int_query_param(
  url : String,
  key : String,
  default_value : Int,
) -> Int {
  match synthetic_network_first_query_value(url, key) {
    Some(value) =>
      match parse_decimal_string(value) {
        Some(parsed) => parsed
        None => default_value
      }
    None => default_value
  }
}

///|
fn synthetic_network_request_header_string_value(
  headers : Array[Json],
  name : String,
) -> String? {
  let lookup = name.to_lower()
  for header in headers {
    match header {
      Object(map) => {
        let header_name = match map.get("name") {
          Some(String(header_name)) => header_name.to_lower()
          _ => continue
        }
        if header_name != lookup {
          continue
        }
        match map.get("value") {
          Some(Object(value_map)) =>
            match value_map.get("value") {
              Some(String(value)) => return Some(value)
              _ => ()
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn synthetic_network_header_string_entry(name : String, value : String) -> Json {
  make_object({
    "name": Json::string(name),
    "value": make_object({
      "type": Json::string("string"),
      "value": Json::string(value),
    }),
  })
}

///|
fn synthetic_network_infer_mime_type(url : String, path : String) -> String {
  if url.has_prefix("data:") {
    let payload_start = match find_substring(url, ",", 0) {
      Some(payload_start) => payload_start
      None => url.length()
    }
    let prefix = if payload_start > 5 {
      url[5:payload_start].to_string() catch {
        _ => ""
      }
    } else {
      ""
    }
    match find_substring(prefix, ";", 0) {
      Some(idx) => {
        let mime_type = prefix[:idx].to_string() catch { _ => "" }
        if mime_type == "" {
          "text/plain"
        } else {
          mime_type.to_lower()
        }
      }
      None => if prefix == "" { "text/plain" } else { prefix.to_lower() }
    }
  } else if path.has_suffix(".html") {
    "text/html"
  } else if path.has_suffix(".txt") {
    "text/plain"
  } else if path.has_suffix(".js") {
    "text/javascript"
  } else if path.has_suffix(".png") {
    "image/png"
  } else if path.has_suffix(".svg") {
    "image/svg+xml"
  } else if path.has_suffix(".css") {
    "text/css"
  } else if path.has_suffix("/cached.py") {
    synthetic_network_first_query_value(url, "contenttype").unwrap_or(
      "text/plain",
    )
  } else {
    "text/plain"
  }
}

///|
fn synthetic_network_status_text_for_code(status : Int) -> String {
  match status {
    101 => "Switching Protocols"
    200 => "OK"
    201 => "Created"
    202 => "Accepted"
    203 => "Non-Authoritative Information"
    204 => "No Content"
    205 => "Reset Content"
    206 => "Partial Content"
    300 => "Multiple Choices"
    305 => "Use Proxy"
    301 => "Moved Permanently"
    302 => "Found"
    303 => "See Other"
    304 => "Not Modified"
    307 => "Temporary Redirect"
    308 => "Permanent Redirect"
    400 => "Bad Request"
    401 => "Unauthorized"
    402 => "Payment Required"
    403 => "Forbidden"
    404 => "Not Found"
    405 => "Method Not Allowed"
    406 => "Not Acceptable"
    407 => "Proxy Authentication Required"
    408 => "Request Timeout"
    409 => "Conflict"
    410 => "Gone"
    411 => "Length Required"
    412 => "Precondition Failed"
    415 => "Unsupported Media Type"
    417 => "Expectation Failed"
    500 => "Internal Server Error"
    501 => "Not Implemented"
    502 => "Bad Gateway"
    503 => "Service Unavailable"
    504 => "Gateway Timeout"
    505 => "HTTP Version Not Supported"
    _ => if status == 200 { "OK" } else { "" }
  }
}
