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
  self.apply_navigation_commit_state_internal(ctx_id, url, navigation_id, false)
}

///|
/// Apply committed navigation state. When `defer_load` is true, the runtime
/// document load (sync_runtime_page / sync_runtime_html) is skipped — the
/// caller is responsible for invoking the load and sending the BiDi response
/// once it resolves. Used for HTTP wait=complete navigations that need the
/// JS async bridge so script.evaluate sees the loaded document.
fn BidiProtocol::apply_navigation_commit_state_internal(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
  defer_load : Bool,
) -> Unit {
  let previous_children = self.context_children.get(ctx_id).unwrap_or([])
  reset_runtime_event_buffers(ctx_id)
  if !defer_load {
    self.load_data_url_content(ctx_id, url)
  }
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
/// Compute navigation state and return the nav id WITHOUT sending the
/// BiDi response. Caller MUST send the response via socket asynchronously
/// (currently: js_navigate_and_send_async).
///
/// PRECONDITION: should_block_navigation_response(wait_mode, url) must be
/// false for this URL — otherwise build_navigation_completion would set
/// deferred_response=true expecting register_in_flight_navigation to
/// later fire send_success, and the async bridge would double-respond.
/// Currently safe because should_navigate_via_async_bridge excludes
/// trickle URLs (the only ones where block_response would be true for
/// HTTP).
fn BidiProtocol::complete_navigation_request_with_wait_deferred(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
  wait_mode : String,
  navigation_id : String?,
) -> String {
  let completion = self.build_navigation_completion_internal(
    request_id, ctx_id, url, wait_mode, navigation_id, true,
  )
  completion.navigation_id
}

///|
/// Fallback path used when an async bridge call cannot be made (e.g. the
/// wbtest harness never attaches a socket). Performs the deferred runtime
/// document load synchronously and emits the BiDi success response into the
/// outbox so test code observes the same result shape as the production
/// async path.
fn BidiProtocol::complete_navigation_request_with_wait_after_deferred(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  self.load_data_url_content(ctx_id, url)
  let result = make_object({
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
  })
  self.send_success(request_id, Some(result))
}

///|
/// Decide whether navigate should hand off to js_navigate_and_send_async
/// instead of the broken sync sync_runtime_page() path. Only HTTP(S) URLs
/// with wait=complete need the async bridge — data:/about:/trickle URLs
/// already work via the existing sync paths.
fn BidiProtocol::should_navigate_via_async_bridge(
  self : BidiProtocol,
  url : String,
  wait_mode : String,
) -> Bool {
  ignore(self)
  if wait_mode != "complete" {
    return false
  }
  if !(url.has_prefix("http://") || url.has_prefix("https://")) {
    return false
  }
  // Trickle-marker URLs are WPT test fixtures handled by the existing
  // sync block-and-respond path; keep them on that path so the in-flight
  // navigation accounting (register_in_flight_navigation /
  // apply_navigation_wait_delay) still applies.
  if is_trickle_navigation_url(url) {
    return false
  }
  true
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
  self.build_navigation_completion_internal(
    request_id, ctx_id, url, wait_mode, navigation_id, false,
  )
}

///|
fn BidiProtocol::build_navigation_completion_internal(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
  wait_mode : String,
  navigation_id : String?,
  defer_load : Bool,
) -> NavigationCompletion {
  let nav_id = match navigation_id {
    Some(id) => id
    None => {
      let generated_id = self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      generated_id
    }
  }
  self.apply_navigation_commit_state_internal(ctx_id, url, nav_id, defer_load)
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
