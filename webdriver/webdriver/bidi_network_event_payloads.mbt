///|
fn BidiProtocol::build_synthetic_before_request_sent_event_json(
  self : BidiProtocol,
  request_id : Int,
  input : @crater_network.SyntheticNetworkEventInput,
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
  input : @crater_network.SyntheticNetworkEventInput,
  response_overrides : @crater_network.SyntheticNetworkResponseOverrides,
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
  input : @crater_network.SyntheticNetworkEventInput,
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
  input : @crater_network.SyntheticNetworkEventInput,
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
  request["method"] = Json::string(input.http_method)
  request["bodySize"] = Json::number(body_size.to_double())
  request["cookies"] = Json::array(cookies)
  request["destination"] = Json::string(input.destination)
  request["headers"] = Json::array(input.request_headers)
  request["headersSize"] = Json::number(0.0)
  request["initiatorType"] = match input.initiator_type {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  request["request"] = Json::string(input.request_token)
  request["timings"] = self.build_synthetic_network_timings_json(now)
  request["url"] = Json::string(input.url)
  Some(make_object(request))
}

///|
fn BidiProtocol::build_synthetic_network_event_base_map(
  self : BidiProtocol,
  input : @crater_network.SyntheticNetworkEventInput,
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
  response_overrides : @crater_network.SyntheticNetworkResponseOverrides,
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
  match
    @crater_network.synthetic_network_request_body_size(
      raw_value, "requestValue",
    ) {
    Ok(body_size) => Some(body_size)
    Err(message) => {
      self.send_error(request_id, "invalid argument", message)
      None
    }
  }
}
