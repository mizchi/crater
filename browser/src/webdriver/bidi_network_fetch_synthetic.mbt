///|
priv struct SyntheticFetchPlanEntry {
  url : String
  http_method : String
  request_token : String
  redirect_count : Int
  request_value : Json?
}

///|
priv struct SyntheticFetchStepResult {
  blocked_text : String?
  response_value : Json?
}

///|
priv struct SyntheticFetchCommandResult {
  blocked_text : String?
  response_value : Json
}

///|
fn BidiProtocol::handle_network_perform_synthetic_fetch(
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
  let should_abort = match
    get_map_field_with_alias(map, "shouldAbort", "should_abort") {
    None | Some(Null) => false
    Some(True) => true
    Some(False) => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "shouldAbort must be a boolean",
      )
      return
    }
  }
  let result = self.perform_synthetic_fetch_internal(
    request_id, context_id, url, http_method, request_headers, request_value, should_abort,
  )
  let response : Map[String, Json] = {
    "blocked": Json::boolean(result.blocked_text != None),
    "value": result.response_value,
  }
  match result.blocked_text {
    Some(text) => response["message"] = Json::string(text)
    None => ()
  }
  self.send_success(request_id, Some(make_object(response)))
}

///|
fn BidiProtocol::perform_synthetic_fetch_internal(
  self : BidiProtocol,
  request_id : Int,
  context_id : String,
  url : String,
  http_method : String,
  request_headers : Array[Json],
  request_value : Json?,
  should_abort : Bool,
) -> SyntheticFetchCommandResult {
  let request_plan = self.build_synthetic_fetch_request_plan(
    context_id, url, http_method, request_headers, request_value,
  )
  let mut last_response_value = make_object({
    "type": Json::string("string"),
    "value": Json::string(""),
  })
  for request_step in request_plan {
    let step_result = self.perform_synthetic_fetch_step(
      request_id, context_id, request_step, request_headers, should_abort,
    )
    match step_result.blocked_text {
      Some(text) =>
        return { blocked_text: Some(text), response_value: last_response_value }
      None => ()
    }
    match step_result.response_value {
      Some(response_value) => last_response_value = response_value
      None => ()
    }
  }
  { blocked_text: None, response_value: last_response_value }
}

///|
fn BidiProtocol::build_synthetic_fetch_request_plan(
  self : BidiProtocol,
  context_id : String,
  url : String,
  http_method : String,
  request_headers : Array[Json],
  request_value : Json?,
) -> Array[SyntheticFetchPlanEntry] {
  let requests : Array[SyntheticFetchPlanEntry] = []
  let actual_request_token = self.next_synthetic_network_request_id()
  if synthetic_fetch_requires_preflight(
      self.requested_navigation_url(context_id),
      url,
      http_method,
      request_headers,
    ) {
    requests.push({
      url,
      http_method: "OPTIONS",
      request_token: self.next_synthetic_network_request_id(),
      redirect_count: 0,
      request_value: None,
    })
  }
  requests.push({
    url,
    http_method,
    request_token: actual_request_token,
    redirect_count: 0,
    request_value,
  })

  let path = synthetic_network_request_path(url)
  let redirect_location = synthetic_network_first_query_value(url, "location")
  let redirect_status = synthetic_network_int_query_param(url, "status", 302)
  let should_follow_redirect = path.has_suffix("/redirect.py") ||
    (
      path.has_suffix("/cached.py") &&
      (
        redirect_status == 301 ||
        redirect_status == 302 ||
        redirect_status == 303 ||
        redirect_status == 307 ||
        redirect_status == 308
      )
    )
  if should_follow_redirect {
    match redirect_location {
      Some(redirect_url) if redirect_url != "" =>
        requests.push({
          url: redirect_url,
          http_method,
          request_token: actual_request_token,
          redirect_count: 1,
          request_value: None,
        })
      _ => ()
    }
  }
  requests
}

///|
fn BidiProtocol::perform_synthetic_fetch_step(
  self : BidiProtocol,
  request_id : Int,
  context_id : String,
  request_step : SyntheticFetchPlanEntry,
  raw_request_headers : Array[Json],
  should_abort : Bool,
) -> SyntheticFetchStepResult {
  let resolved_request_headers = self.resolve_network_extra_header_entries(
    context_id, raw_request_headers,
  )
  let base_input : SyntheticNetworkEventInput = {
    context_id,
    url: request_step.url,
    http_method: request_step.http_method,
    request_token: request_step.request_token,
    request_headers: resolved_request_headers,
    request_value: request_step.request_value,
    request_cookies: [],
    request_cookies_override: false,
    intercepts: [],
    redirect_count: request_step.redirect_count,
    navigation: None,
    destination: "",
    initiator_type: Some("fetch"),
  }
  let response_overrides = self.resolve_synthetic_response_overrides_internal(
    context_id,
    request_step.url,
    request_step.http_method,
    resolved_request_headers,
    true,
  )

  let before_intercepts = self.resolve_matching_network_intercepts_internal(
    context_id,
    "beforeRequestSent",
    request_step.url,
  )
  let before_subscribed = self.is_subscribed_for_context(
    "network.beforeRequestSent", context_id,
  )
  let before_blocked = before_subscribed && before_intercepts.length() > 0
  if before_subscribed {
    let before_input = {
      ..base_input,
      intercepts: if before_blocked {
        before_intercepts
      } else {
        []
      },
    }
    match
      self.build_synthetic_before_request_sent_event_json(
        request_id, before_input,
      ) {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.beforeRequestSent", params: event }),
        )
      None => return { blocked_text: None, response_value: None }
    }
  }
  if before_blocked {
    let blocked_request : Map[String, Json] = {
      "phase": Json::string("beforeRequestSent"),
      "context_id": Json::string(context_id),
      "url": Json::string(request_step.url),
      "method": Json::string(request_step.http_method),
      "request_headers": synthetic_navigation_header_object_from_entries(
        raw_request_headers,
      ),
      "redirect_count": Json::number(request_step.redirect_count.to_double()),
      "navigation": Json::null(),
      "destination": Json::string(""),
      "initiator_type": Json::string("fetch"),
      "is_navigation": Json::boolean(false),
    }
    match request_step.request_value {
      Some(request_value) => blocked_request["request_value"] = request_value
      None => ()
    }
    self.remember_network_blocked_request(
      request_step.request_token,
      blocked_request,
    )
    return {
      blocked_text: Some("Request blocked by network intercept"),
      response_value: None,
    }
  }

  if should_abort ||
    synthetic_navigation_is_unreachable_test_url(request_step.url) {
    if self.is_subscribed_for_context("network.fetchError", context_id) {
      match
        self.build_synthetic_fetch_error_event_json(
          request_id, base_input, "Request failed",
        ) {
        Some(event) =>
          self.outbox.push(
            Event({ event_method: "network.fetchError", params: event }),
          )
        None => ()
      }
    }
    return { blocked_text: None, response_value: None }
  }

  let response_started_intercepts = self.resolve_matching_network_intercepts_internal(
    context_id,
    "responseStarted",
    request_step.url,
  )
  let response_started_subscribed = self.is_subscribed_for_context(
    "network.responseStarted", context_id,
  )
  let response_started_blocked = response_started_subscribed &&
    response_started_intercepts.length() > 0
  let mut response_started_event : Json? = None
  if response_started_subscribed {
    let response_input = {
      ..base_input,
      intercepts: if response_started_blocked {
        response_started_intercepts
      } else {
        []
      },
    }
    response_started_event = self.build_synthetic_response_event_json(
      request_id, response_input, response_overrides,
    )
    match response_started_event {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.responseStarted", params: event }),
        )
      None => return { blocked_text: None, response_value: None }
    }
  }
  if response_started_blocked {
    let blocked_request = synthetic_navigation_blocked_request_payload(
      base_input, "responseStarted", response_started_event,
    )
    blocked_request["is_navigation"] = Json::boolean(false)
    self.remember_network_blocked_request(
      request_step.request_token,
      blocked_request,
    )
    return {
      blocked_text: Some("Request blocked by responseStarted intercept"),
      response_value: None,
    }
  }

  let auth_required_intercepts = self.resolve_matching_network_intercepts_internal(
    context_id,
    "authRequired",
    request_step.url,
  )
  let auth_required_subscribed = self.is_subscribed_for_context(
    "network.authRequired", context_id,
  )
  let auth_required_needed = synthetic_navigation_requires_auth_event(
    response_overrides,
  )
  let auth_required_blocked = auth_required_needed &&
    auth_required_subscribed &&
    auth_required_intercepts.length() > 0
  let mut auth_required_event : Json? = None
  if auth_required_subscribed && auth_required_needed {
    let auth_overrides : SyntheticNetworkResponseOverrides = if auth_required_blocked {
      {
        from_cache: response_overrides.from_cache,
        headers: response_overrides.headers,
        mime_type: response_overrides.mime_type,
        protocol: response_overrides.protocol,
        status: 401,
        status_text: "Unauthorized",
        auth_challenges: Some(
          Json::array([
            make_object({
              "scheme": Json::string("Basic"),
              "realm": Json::string("testrealm"),
            }),
          ]),
        ),
      }
    } else {
      response_overrides
    }
    let auth_input = {
      ..base_input,
      intercepts: if auth_required_blocked {
        auth_required_intercepts
      } else {
        []
      },
    }
    auth_required_event = self.build_synthetic_response_event_json(
      request_id, auth_input, auth_overrides,
    )
    match auth_required_event {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.authRequired", params: event }),
        )
      None => return { blocked_text: None, response_value: None }
    }
  }
  if auth_required_blocked {
    let blocked_request = synthetic_navigation_blocked_request_payload(
      base_input, "authRequired", auth_required_event,
    )
    blocked_request["is_navigation"] = Json::boolean(false)
    self.remember_network_blocked_request(
      request_step.request_token,
      blocked_request,
    )
    return {
      blocked_text: Some("Request blocked by authRequired intercept"),
      response_value: None,
    }
  }

  let response_value = synthetic_fetch_synthesize_response_value(
    request_step.url,
    if synthetic_fetch_is_headers_echo_url(request_step.url) {
      Some(
        self.build_network_headers_echo_payload(
          context_id, resolved_request_headers,
        ),
      )
    } else {
      None
    },
  )
  self.remember_network_collected_data_internal(
    context_id,
    request_step.request_token,
    request_step.request_value,
    Some(response_value),
  )

  if self.is_subscribed_for_context("network.responseCompleted", context_id) {
    match
      self.build_synthetic_response_event_json(
        request_id, base_input, response_overrides,
      ) {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.responseCompleted", params: event }),
        )
      None =>
        return { blocked_text: None, response_value: Some(response_value) }
    }
  }

  { blocked_text: None, response_value: Some(response_value) }
}

///|
fn synthetic_fetch_requires_preflight(
  source_url : String,
  target_url : String,
  http_method : String,
  request_headers : Array[Json],
) -> Bool {
  let source_origin = match canonicalize_network_http_url(source_url) {
    Some(source) => source
    None => return false
  }
  let target_origin = match canonicalize_network_http_url(target_url) {
    Some(target) => target
    None => return false
  }
  if source_origin.scheme == target_origin.scheme &&
    source_origin.host == target_origin.host &&
    source_origin.port == target_origin.port {
    return false
  }
  let method_upper = http_method.to_upper()
  if method_upper != "GET" && method_upper != "HEAD" && method_upper != "POST" {
    return true
  }
  for header in request_headers {
    let name = match synthetic_network_header_entry_name(header) {
      Some(name) => name.to_lower()
      None => continue
    }
    let value = match synthetic_network_header_entry_string_value(header) {
      Some(value) => value
      None => ""
    }
    if name == "accept" ||
      name == "accept-language" ||
      name == "content-language" {
      continue
    }
    if name == "content-type" &&
      synthetic_fetch_is_cors_safelisted_content_type(value) {
      continue
    }
    return true
  }
  false
}

///|
fn synthetic_fetch_is_cors_safelisted_content_type(value : String) -> Bool {
  let raw_media_type = match find_substring(value, ";", 0) {
    Some(idx) =>
      value[:idx].to_string().to_lower() catch {
        _ => value.to_lower()
      }
    None => value.to_lower()
  }
  let media_type = raw_media_type.trim()
  media_type == "application/x-www-form-urlencoded" ||
  media_type == "multipart/form-data" ||
  media_type == "text/plain"
}

///|
fn synthetic_fetch_is_headers_echo_url(url : String) -> Bool {
  match canonicalize_network_http_url(url) {
    Some(parts) =>
      parts.port == 8000 &&
      (parts.host == "localhost" || parts.host == "alt.localhost") &&
      parts.path.has_suffix(
        "/webdriver/tests/support/http_handlers/headers_echo.py",
      )
    None => false
  }
}

///|
fn synthetic_fetch_synthesize_response_value(
  url : String,
  headers_echo_payload : String?,
) -> Json {
  match headers_echo_payload {
    Some(payload) =>
      make_object({
        "type": Json::string("string"),
        "value": Json::string(payload),
      })
    None => synthetic_navigation_synthesize_response_value(url)
  }
}
