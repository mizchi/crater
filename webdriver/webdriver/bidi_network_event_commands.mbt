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
  if !self.manager.has_session(context_id) {
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
