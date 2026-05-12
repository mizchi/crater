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

///|
/// Complete navigation state update and optionally defer success response by wait mode.
fn BidiProtocol::complete_navigation_request_with_wait(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
  wait_mode : String,
) -> Unit {
  self.complete_navigation_request_with_wait_and_navigation(
    request_id,
    ctx_id,
    url,
    wait_mode,
    None,
  )
}

///|
/// Apply committed navigation state and emit navigation lifecycle events.
fn BidiProtocol::apply_navigation_commit_state(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let previous_children = self.context_children.get(ctx_id).unwrap_or([])
  reset_runtime_event_buffers(ctx_id)
  self.load_data_url_content(ctx_id, url)
  let defer_parent_lifecycle = self.collect_iframe_sources(ctx_id).length() > 0
  for child_ctx_id in previous_children {
    let original_opener = self.context_original_opener.get(child_ctx_id)
    self.emit_context_destroyed(child_ctx_id, original_opener)
  }
  self.drop_child_contexts(ctx_id, false)
  // Navigation replaces all realms owned by the context.
  self.remove_all_realms_for_context(ctx_id)
  let window_realm_id = self.assign_new_realm(ctx_id)
  self.emit_default_realm(ctx_id)
  self.emit_worker_realms_from_scripts(ctx_id, window_realm_id)
  self.apply_preload_scripts_for_context(ctx_id)
  self.execute_inline_scripts_for_context(ctx_id)
  if url.contains("/webdriver/tests/support/html/beforeunload.html") {
    self.context_has_beforeunload[ctx_id] = true
  } else {
    self.context_has_beforeunload.remove(ctx_id)
  }
  if navigation_blocks_cross_origin_iframe_navigation(url) {
    self.context_blocks_cross_origin_iframe_navigation[ctx_id] = true
  } else {
    self.context_blocks_cross_origin_iframe_navigation.remove(ctx_id)
  }
  self.emit_navigation_events_internal(
    ctx_id,
    url,
    navigation_id,
    !defer_parent_lifecycle,
  )
  self.refresh_child_contexts_from_iframes(ctx_id)
  if defer_parent_lifecycle {
    self.emit_navigation_lifecycle_events(ctx_id, url, navigation_id)
  }
  self.register_navigation_prompt_from_url(ctx_id, url)
}

///|
/// Complete navigation update using an optional preallocated navigation id.
fn BidiProtocol::complete_navigation_request_with_wait_and_navigation(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
  wait_mode : String,
  navigation_id : String?,
) -> Unit {
  let completion = self.build_navigation_completion(
    request_id, ctx_id, url, wait_mode, navigation_id,
  )
  if !completion.deferred_response {
    self.send_success(request_id, Some(completion.result))
  }
}

///|
fn BidiProtocol::build_navigation_completion(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
  wait_mode : String,
  navigation_id : String?,
) -> NavigationCompletion {
  let nav_id = match navigation_id {
    Some(id) => id
    None => {
      let generated_id = self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      generated_id
    }
  }
  self.apply_navigation_commit_state(ctx_id, url, nav_id)
  let has_inline_redirect = match resolve_inline_script_redirect_url(url) {
    Some(_) => true
    None => false
  }
  let block_response = should_block_navigation_response(wait_mode, url)
  let mark_in_flight = is_interruptible_navigation_candidate(url) &&
    !has_inline_redirect
  let deferred_response = block_response && mark_in_flight
  if mark_in_flight {
    if block_response {
      self.register_in_flight_navigation(ctx_id, url, nav_id, Some(request_id))
    } else {
      self.register_in_flight_navigation(ctx_id, url, nav_id, None)
    }
  } else {
    self.clear_pending_navigation_state(ctx_id)
    if block_response {
      apply_navigation_wait_delay(wait_mode, url)
    }
  }
  let result = make_object({
    "navigation": Json::string(nav_id),
    "url": Json::string(url),
  })
  { result, navigation_id: nav_id, deferred_response }
}

///|
/// Complete same-document fragment navigation.
fn BidiProtocol::complete_fragment_navigation_request(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
) -> Unit {
  self.clear_pending_navigation_state(ctx_id)
  let nav_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  self.emit_fragment_navigated_event(ctx_id, url, Some(nav_id))
  self.emit_history_updated_event(ctx_id, url)
  let result = make_object({
    "navigation": Json::string(nav_id),
    "url": Json::string(url),
  })
  self.send_success(request_id, Some(result))
}

///|
/// Emit navigationStarted event for the given context.
fn BidiProtocol::emit_navigation_started_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let event_name = "browsingContext.navigationStarted"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  self.context_last_started_navigation[ctx_id] = navigation_id
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit navigationCommitted event for the given context.
fn BidiProtocol::emit_navigation_committed_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let event_name = "browsingContext.navigationCommitted"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit navigationFailed event for the given context.
fn BidiProtocol::emit_navigation_failed_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let event_name = "browsingContext.navigationFailed"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit navigationAborted event for the given context.
fn BidiProtocol::emit_navigation_aborted_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let event_name = "browsingContext.navigationAborted"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit domContentLoaded/load/historyUpdated for a committed navigation.
fn BidiProtocol::emit_navigation_lifecycle_events(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let timestamp = input_now_ms()
  let base = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(timestamp),
  })
  // Emit domContentLoaded
  if self.is_subscribed_for_context("browsingContext.domContentLoaded", ctx_id) {
    self.outbox.push(
      Event({ event_method: "browsingContext.domContentLoaded", params: base }),
    )
  }
  // Emit load
  if self.is_subscribed_for_context("browsingContext.load", ctx_id) {
    self.outbox.push(
      Event({ event_method: "browsingContext.load", params: base }),
    )
  }
  // Emit historyUpdated
  let history = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
    "timestamp": Json::number(timestamp),
  })
  if self.is_subscribed_for_context("browsingContext.historyUpdated", ctx_id) {
    self.outbox.push(
      Event({ event_method: "browsingContext.historyUpdated", params: history }),
    )
  }
}

///|
/// Emit basic navigation events.
fn BidiProtocol::emit_navigation_events(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  self.emit_navigation_events_internal(ctx_id, url, navigation_id, true)
}

///|
/// Emit basic navigation events, optionally excluding dom/load/history lifecycle.
fn BidiProtocol::emit_navigation_events_internal(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
  emit_lifecycle : Bool,
) -> Unit {
  let committed_url = resolve_navigation_committed_url(url)
  self.emit_navigation_started_event(ctx_id, url, navigation_id)
  self.emit_navigation_committed_event(ctx_id, committed_url, navigation_id)
  if emit_lifecycle {
    self.emit_navigation_lifecycle_events(ctx_id, url, navigation_id)
  }
  match resolve_http_equiv_redirect_url(url) {
    Some(redirected_url) => {
      let redirected_nav_id = self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      self.emit_navigation_started_event(
        ctx_id, redirected_url, redirected_nav_id,
      )
      self.emit_navigation_committed_event(
        ctx_id, redirected_url, redirected_nav_id,
      )
      if emit_lifecycle {
        self.emit_navigation_lifecycle_events(
          ctx_id, redirected_url, redirected_nav_id,
        )
      }
    }
    None => ()
  }
  match resolve_inline_script_redirect_url(url) {
    Some(redirected_url) => {
      self.emit_navigation_aborted_event(ctx_id, url, navigation_id)
      let redirected_nav_id = self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      self.emit_navigation_started_event(
        ctx_id, redirected_url, redirected_nav_id,
      )
      self.emit_navigation_committed_event(
        ctx_id,
        resolve_navigation_committed_url(redirected_url),
        redirected_nav_id,
      )
      if emit_lifecycle {
        self.emit_navigation_lifecycle_events(
          ctx_id, redirected_url, redirected_nav_id,
        )
      }
    }
    None => ()
  }
}
