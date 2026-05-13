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

///|
fn BidiProtocol::handle_browsing_context_navigate_with_state(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let ctx_id = match get_param_raw(params, "context") {
    Some(String(value)) => value
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing context")
      return
    }
  }
  let url = match get_param_raw(params, "url") {
    Some(String(value)) => value
    Some(_) => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing url")
      return
    }
  }
  let wait_mode = match get_param_raw(params, "wait") {
    Some(String(value)) =>
      if value == "none" || value == "interactive" || value == "complete" {
        value
      } else {
        self.send_error(
          request_id, "invalid argument", "wait must be one of none, interactive, or complete",
        )
        return
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "wait must be a string")
      return
    }
    None => "none"
  }
  if !self.manager.has_session(ctx_id) {
    self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
    return
  }

  match self.prepare_navigation_request_internal(request_id, ctx_id, url) {
    Some(prepared) =>
      match get_field(prepared, "blocked") {
        Some(True) => return
        _ => ()
      }
    None => return
  }

  let resolved_url = self.resolve_effective_navigation_target_url(ctx_id, url)
  self.input_synthetic_events_by_context.remove(ctx_id)
  self.context_synthetic_scrolled.remove(ctx_id)
  self.clear_synthetic_location_href(ctx_id)
  let _ = self.fail_in_flight_navigation(
    ctx_id, "aborted", "Navigation interrupted by another navigation",
  )
  if !is_valid_navigation_target_url(resolved_url) {
    self.send_error(request_id, "invalid argument", "url is invalid")
    return
  }
  if self.navigation_blocked_by_network_conditions(ctx_id, resolved_url) {
    let nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
    self.send_error(
      request_id, "unknown error", "Navigation failed: network offline",
    )
    return
  }
  if should_fail_navigation_with_unknown_error(resolved_url) {
    let nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
    self.send_error(
      request_id, "unknown error", "Navigation failed: navigation target is unreachable",
    )
    return
  }
  if self.is_iframe_navigation_blocked(ctx_id, resolved_url) {
    let nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
    self.emit_navigation_failed_event(ctx_id, resolved_url, nav_id)
    self.send_error(
      request_id, "unknown error", "Navigation failed: blocked by embedding policy",
    )
    return
  }
  match self.manager.get_session(ctx_id) {
    Some(session) =>
      if self.has_beforeunload_prompt_in_scope(ctx_id) {
        let handler = self.resolve_unhandled_prompt_handler(
          ctx_id, "beforeunload",
        )
        let nav_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        self.clear_pending_prompt_state(ctx_id)
        self.pending_prompt_type[ctx_id] = "beforeunload"
        self.pending_beforeunload_request[ctx_id] = request_id
        self.pending_beforeunload_url[ctx_id] = resolved_url
        self.pending_beforeunload_requested_url[ctx_id] = url
        self.pending_beforeunload_wait[ctx_id] = wait_mode
        self.pending_beforeunload_navigation[ctx_id] = nav_id
        self.pending_beforeunload_finalize_mode[ctx_id] = "navigateWithState"
        self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
        self.emit_user_prompt_opened(
          ctx_id,
          "beforeunload",
          handler,
          "beforeunload",
          None,
        )
        return
      } else {
        let previous_url = session.get_url()
        match session.navigate_to(resolved_url) {
          Ok(_) =>
            self.complete_navigate_with_state(
              request_id,
              ctx_id,
              url,
              resolved_url,
              previous_url,
              wait_mode,
              None,
            )
          Err(e) => {
            let nav_id = self.next_navigation_id.to_string()
            self.next_navigation_id += 1
            self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
            self.send_error(
              request_id,
              "unknown error",
              "Navigation failed: " + e.message,
            )
          }
        }
      }
    None => {
      self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
      return
    }
  }
}

///|
fn BidiProtocol::handle_browsing_context_finalize_reload(
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
  let url = self.requested_navigation_url(context_id)
  let emitted = self.emit_synthetic_navigation_request_sequence(
    context_id, url, navigation_id,
  )
  self.send_success(
    request_id,
    Some(
      make_object({
        "url": Json::string(url),
        "emitted": Json::number(emitted.to_double()),
        "blocked": Json::boolean(
          self.has_network_blocked_navigation_request(context_id, navigation_id),
        ),
      }),
    ),
  )
}

///|
fn BidiProtocol::handle_browsing_context_reload_with_state(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let ctx_id = match get_param_raw(params, "context") {
    Some(String(value)) => value
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing context")
      return
    }
  }
  let ignore_cache_raw = match get_param_raw(params, "ignoreCache") {
    Some(value) => Some(value)
    None => get_param_raw(params, "ignore_cache")
  }
  let _ignore_cache = match ignore_cache_raw {
    Some(True) => true
    Some(False) => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "ignoreCache must be a boolean",
      )
      return
    }
    None => false
  }
  let wait_mode = match get_param_raw(params, "wait") {
    Some(String(value)) =>
      if value == "none" || value == "interactive" || value == "complete" {
        value
      } else {
        self.send_error(
          request_id, "invalid argument", "wait must be one of none, interactive, or complete",
        )
        return
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "wait must be a string")
      return
    }
    None => "none"
  }
  if !self.manager.has_session(ctx_id) {
    self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
    return
  }
  self.input_synthetic_events_by_context.remove(ctx_id)
  self.context_synthetic_scrolled.remove(ctx_id)
  self.clear_synthetic_location_href(ctx_id)
  let _ = self.fail_in_flight_navigation(
    ctx_id, "aborted", "Navigation interrupted by reload",
  )
  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let current_url = session.get_url()
      let requested_url = self.requested_navigation_url(ctx_id)
      let url = if requested_url != "" { requested_url } else { current_url }
      if self.has_beforeunload_prompt_in_scope(ctx_id) {
        let handler = self.resolve_unhandled_prompt_handler(
          ctx_id, "beforeunload",
        )
        let nav_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        self.clear_pending_prompt_state(ctx_id)
        self.pending_prompt_type[ctx_id] = "beforeunload"
        self.pending_beforeunload_request[ctx_id] = request_id
        self.pending_beforeunload_url[ctx_id] = url
        self.pending_beforeunload_requested_url[ctx_id] = url
        self.pending_beforeunload_wait[ctx_id] = wait_mode
        self.pending_beforeunload_navigation[ctx_id] = nav_id
        self.pending_beforeunload_finalize_mode[ctx_id] = "reloadWithState"
        self.emit_navigation_started_event(ctx_id, url, nav_id)
        self.emit_user_prompt_opened(
          ctx_id,
          "beforeunload",
          handler,
          "beforeunload",
          None,
        )
        return
      }
      let completion = self.build_navigation_completion(
        request_id,
        ctx_id,
        url,
        wait_mode,
        None,
      )
      let _ = self.emit_synthetic_navigation_request_sequence(
        ctx_id,
        requested_url,
        Some(completion.navigation_id),
      )
      let blocked = self.has_network_blocked_navigation_request(
        ctx_id,
        Some(completion.navigation_id),
      )
      if blocked {
        self.strip_pending_navigation_lifecycle_events(
          ctx_id,
          url,
          completion.navigation_id,
        )
        self.register_in_flight_navigation(
          ctx_id,
          url,
          completion.navigation_id,
          Some(request_id),
        )
        return
      }
      if !completion.deferred_response {
        self.send_success(request_id, Some(completion.result))
      }
    }
    None => {
      self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
      return
    }
  }
}
