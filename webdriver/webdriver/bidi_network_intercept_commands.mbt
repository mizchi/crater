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
