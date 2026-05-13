///|
fn BidiProtocol::abort_in_flight_navigation_unless_matching(
  self : BidiProtocol,
  ctx_id : String,
  navigation_id : String?,
  message : String,
) -> Unit {
  let should_abort = match self.in_flight_navigation_id.get(ctx_id) {
    Some(existing_navigation_id) =>
      match navigation_id {
        Some(target_navigation_id) =>
          existing_navigation_id != target_navigation_id
        None => true
      }
    None => false
  }
  if should_abort {
    let _ = self.fail_in_flight_navigation(ctx_id, "aborted", message)
  }
}

///|
fn BidiProtocol::complete_pending_navigation_response(
  self : BidiProtocol,
  ctx_id : String,
  url : String?,
  navigation_id : String?,
) -> Unit {
  let resolved_navigation_id = match navigation_id {
    Some(navigation_id) => navigation_id
    None =>
      match self.in_flight_navigation_id.get(ctx_id) {
        Some(navigation_id) => navigation_id
        None => return
      }
  }
  match self.in_flight_navigation_id.get(ctx_id) {
    Some(current_navigation_id) =>
      if current_navigation_id != resolved_navigation_id {
        return
      }
    None => ()
  }
  let resolved_url = match url {
    Some(url) => url
    None => self.in_flight_navigation_url.get(ctx_id).unwrap_or("about:blank")
  }
  match self.pending_navigation_request.get(ctx_id) {
    Some(request_id) =>
      if self.pending_navigation_response_mode.get(ctx_id).unwrap_or("state") ==
        "url" {
        self.send_success(request_id, Some(Json::string(resolved_url)))
      } else {
        self.send_success(
          request_id,
          Some(
            make_object({
              "navigation": Json::string(resolved_navigation_id),
              "url": Json::string(resolved_url),
            }),
          ),
        )
      }
    None => ()
  }
  self.clear_pending_navigation_state(ctx_id)
}

///|
fn BidiProtocol::fail_pending_navigation_response(
  self : BidiProtocol,
  ctx_id : String,
  navigation_id : String?,
  message : String,
) -> Unit {
  let resolved_navigation_id = match navigation_id {
    Some(navigation_id) => navigation_id
    None =>
      match self.in_flight_navigation_id.get(ctx_id) {
        Some(navigation_id) => navigation_id
        None => return
      }
  }
  match self.in_flight_navigation_id.get(ctx_id) {
    Some(current_navigation_id) =>
      if current_navigation_id != resolved_navigation_id {
        return
      }
    None => ()
  }
  match self.pending_navigation_request.get(ctx_id) {
    Some(request_id) => self.send_error(request_id, "unknown error", message)
    None => ()
  }
  self.clear_pending_navigation_state(ctx_id)
}

///|
fn outbox_message_matches_pending_navigation_lifecycle(
  message : BidiOutMessage,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Bool {
  match message {
    Event(evt) =>
      if evt.event_method == "browsingContext.load" ||
        evt.event_method == "browsingContext.domContentLoaded" {
        get_string_field(evt.params, "context").unwrap_or("") == ctx_id &&
        get_string_field(evt.params, "url").unwrap_or("") == url &&
        get_string_field(evt.params, "navigation").unwrap_or("") ==
        navigation_id
      } else if evt.event_method == "browsingContext.historyUpdated" {
        get_string_field(evt.params, "context").unwrap_or("") == ctx_id &&
        get_string_field(evt.params, "url").unwrap_or("") == url
      } else {
        false
      }
    _ => false
  }
}

///|
fn BidiProtocol::strip_pending_navigation_lifecycle_events(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let retained : Array[BidiOutMessage] = []
  for message in self.outbox {
    if !outbox_message_matches_pending_navigation_lifecycle(
        message, ctx_id, url, navigation_id,
      ) {
      retained.push(message)
    }
  }
  self.outbox = retained
}
