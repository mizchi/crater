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
