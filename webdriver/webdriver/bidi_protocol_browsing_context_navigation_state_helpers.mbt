///|
fn BidiProtocol::handle_browsing_context_prepare_navigate(
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
  self.clear_synthetic_location_href(context_id)
  match self.prepare_navigation_request_internal(request_id, context_id, url) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::handle_browsing_context_finalize_navigate(
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
  let navigation_id : String? = match map.get("navigation") {
    Some(String(navigation_id)) => Some(navigation_id)
    Some(Null) | None => None
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "navigation must be a string",
      )
      return
    }
  }
  let emitted = self.emit_synthetic_navigation_request_sequence(
    context_id, url, navigation_id,
  )
  self.send_success(
    request_id,
    Some(
      make_object({
        "emitted": Json::number(emitted.to_double()),
        "blocked": Json::boolean(
          self.has_network_blocked_navigation_request(context_id, navigation_id),
        ),
      }),
    ),
  )
}

///|
fn BidiProtocol::send_navigation_state_result(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  requested_url : String,
  result_url : String,
  navigation_id : String,
  result : Json,
) -> Unit {
  self.send_navigation_result_with_mode(
    request_id, ctx_id, requested_url, result_url, navigation_id, result, "state",
  )
}

///|
fn BidiProtocol::send_navigation_url_result(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  requested_url : String,
  result_url : String,
  navigation_id : String,
) -> Unit {
  self.send_navigation_result_with_mode(
    request_id,
    ctx_id,
    requested_url,
    result_url,
    navigation_id,
    Json::string(result_url),
    "url",
  )
}

///|
fn BidiProtocol::send_navigation_result_with_mode(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  requested_url : String,
  result_url : String,
  navigation_id : String,
  result : Json,
  response_mode : String,
) -> Unit {
  let _ = self.emit_synthetic_navigation_request_sequence(
    ctx_id,
    requested_url,
    Some(navigation_id),
  )
  if self.has_network_blocked_navigation_request(ctx_id, Some(navigation_id)) {
    self.strip_pending_navigation_lifecycle_events(
      ctx_id, result_url, navigation_id,
    )
    if response_mode == "url" {
      self.pending_navigation_response_mode[ctx_id] = "url"
    } else {
      self.pending_navigation_response_mode.remove(ctx_id)
    }
    self.register_in_flight_navigation(
      ctx_id,
      result_url,
      navigation_id,
      Some(request_id),
    )
  } else {
    self.pending_navigation_response_mode.remove(ctx_id)
    self.send_success(request_id, Some(result))
  }
}

///|
fn BidiProtocol::complete_navigate_with_state(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  requested_url : String,
  resolved_url : String,
  previous_url : String,
  wait_mode : String,
  navigation_id : String?,
) -> Unit {
  self.remember_requested_navigation_url(ctx_id, requested_url)
  if is_fragment_navigation(previous_url, resolved_url) {
    self.clear_pending_navigation_state(ctx_id)
    let nav_id = match navigation_id {
      Some(id) => id
      None => {
        let generated_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        generated_id
      }
    }
    self.emit_fragment_navigated_event(ctx_id, resolved_url, Some(nav_id))
    self.emit_history_updated_event(ctx_id, resolved_url)
    let result = make_object({
      "navigation": Json::string(nav_id),
      "url": Json::string(resolved_url),
    })
    self.send_navigation_state_result(
      request_id, ctx_id, requested_url, resolved_url, nav_id, result,
    )
    return
  }

  let completion = self.build_navigation_completion(
    request_id, ctx_id, resolved_url, wait_mode, navigation_id,
  )
  if completion.deferred_response {
    return
  }
  self.send_navigation_state_result(
    request_id,
    ctx_id,
    requested_url,
    resolved_url,
    completion.navigation_id,
    completion.result,
  )
}
