///|
fn BidiProtocol::handle_network_emit_navigation_request_sequence(
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
  let navigation : String? = match map.get("navigation") {
    Some(String(navigation)) => Some(navigation)
    Some(Null) | None => None
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "navigation must be a string",
      )
      return
    }
  }
  let emitted = self.emit_synthetic_navigation_request_sequence_for_test(
    context_id, url, navigation,
  )
  self.send_success(
    request_id,
    Some(make_object({ "emitted": Json::number(emitted.to_double()) })),
  )
}

///|
fn BidiProtocol::emit_synthetic_navigation_request_sequence(
  self : BidiProtocol,
  context_id : String,
  url : String,
  navigation : String?,
) -> Int {
  let requests = self.build_synthetic_navigation_request_entries(
    context_id, url, navigation,
  )
  for request in requests {
    self.emit_synthetic_network_event_sequence_internal(request, true, false)
  }
  requests.length()
}

///|
fn BidiProtocol::emit_synthetic_navigation_request_sequence_for_test(
  self : BidiProtocol,
  context_id : String,
  url : String,
  navigation : String?,
) -> Int {
  let requests = self.build_synthetic_navigation_request_entries(
    context_id, url, navigation,
  )
  for request in requests {
    self.emit_synthetic_network_event_sequence_internal(request, true, true)
  }
  requests.length()
}
