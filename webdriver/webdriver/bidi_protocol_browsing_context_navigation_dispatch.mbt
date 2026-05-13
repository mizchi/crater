///|
/// Handle browsingContext.navigate.
fn BidiProtocol::handle_browsing_context_navigate(
  self : BidiProtocol,
  request : BidiRequest,
) -> Result[Unit, String] {
  let ctx_id = match get_param_raw(request.params, "context") {
    Some(String(value)) => value
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "context must be a string",
      )
      return Ok(())
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing context/url")
      return Ok(())
    }
  }
  let url = match get_param_raw(request.params, "url") {
    Some(String(value)) => value
    Some(_) => {
      self.send_error(request.id, "invalid argument", "url must be a string")
      return Ok(())
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing context/url")
      return Ok(())
    }
  }
  let wait_mode = match get_param_raw(request.params, "wait") {
    Some(String(value)) =>
      if value == "none" || value == "interactive" || value == "complete" {
        value
      } else {
        self.send_error(
          request.id,
          "invalid argument",
          "wait must be one of none, interactive, or complete",
        )
        return Ok(())
      }
    Some(_) => {
      self.send_error(request.id, "invalid argument", "wait must be a string")
      return Ok(())
    }
    None => "none"
  }
  if !self.manager.has_session(ctx_id) {
    self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
    return Ok(())
  }
  let resolved_url = self.resolve_effective_navigation_target_url(ctx_id, url)
  self.input_synthetic_events_by_context.remove(ctx_id)
  self.context_synthetic_scrolled.remove(ctx_id)
  self.clear_synthetic_location_href(ctx_id)
  let _ = self.fail_in_flight_navigation(
    ctx_id, "aborted", "Navigation interrupted by another navigation",
  )
  if !is_valid_navigation_target_url(resolved_url) {
    self.send_error(request.id, "invalid argument", "url is invalid")
    return Ok(())
  }
  if self.navigation_blocked_by_network_conditions(ctx_id, resolved_url) {
    let nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
    self.send_error(
      request.id,
      "unknown error",
      "Navigation failed: network offline",
    )
    return Ok(())
  }
  if should_fail_navigation_with_unknown_error(resolved_url) {
    let nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
    self.send_error(
      request.id,
      "unknown error",
      "Navigation failed: navigation target is unreachable",
    )
    return Ok(())
  }
  if self.is_iframe_navigation_blocked(ctx_id, resolved_url) {
    let nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
    self.emit_navigation_failed_event(ctx_id, resolved_url, nav_id)
    self.send_error(
      request.id,
      "unknown error",
      "Navigation failed: blocked by embedding policy",
    )
    return Ok(())
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
        self.pending_beforeunload_request[ctx_id] = request.id
        self.pending_beforeunload_url[ctx_id] = resolved_url
        self.pending_beforeunload_requested_url[ctx_id] = url
        self.pending_beforeunload_wait[ctx_id] = wait_mode
        self.pending_beforeunload_navigation[ctx_id] = nav_id
        self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
        self.emit_user_prompt_opened(
          ctx_id,
          "beforeunload",
          handler,
          "beforeunload",
          None,
        )
        Ok(())
      } else {
        let previous_url = session.get_url()
        match session.navigate_to(resolved_url) {
          Ok(_) => {
            self.remember_requested_navigation_url(ctx_id, url)
            if is_fragment_navigation(previous_url, resolved_url) {
              self.complete_fragment_navigation_request(
                request.id,
                ctx_id,
                resolved_url,
              )
            } else {
              self.complete_navigation_request_with_wait(
                request.id,
                ctx_id,
                resolved_url,
                wait_mode,
              )
            }
            Ok(())
          }
          Err(e) => {
            let nav_id = self.next_navigation_id.to_string()
            self.next_navigation_id += 1
            self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
            self.send_error(
              request.id,
              "unknown error",
              "Navigation failed: " + e.message,
            )
            Ok(())
          }
        }
      }
    None => {
      self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
      Ok(())
    }
  }
}

///|
/// Handle browsingContext.reload.
fn BidiProtocol::handle_browsing_context_reload(
  self : BidiProtocol,
  request : BidiRequest,
) -> Result[Unit, String] {
  let ctx_id = match get_param_raw(request.params, "context") {
    Some(String(value)) => value
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "context must be a string",
      )
      return Ok(())
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing context")
      return Ok(())
    }
  }
  let ignore_cache_raw = match get_param_raw(request.params, "ignoreCache") {
    Some(value) => Some(value)
    None => get_param_raw(request.params, "ignore_cache")
  }
  let _ignore_cache = match ignore_cache_raw {
    Some(True) => true
    Some(False) => false
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "ignoreCache must be a boolean",
      )
      return Ok(())
    }
    None => false
  }
  let wait_mode = match get_param_raw(request.params, "wait") {
    Some(String(value)) =>
      if value == "none" || value == "interactive" || value == "complete" {
        value
      } else {
        self.send_error(
          request.id,
          "invalid argument",
          "wait must be one of none, interactive, or complete",
        )
        return Ok(())
      }
    Some(_) => {
      self.send_error(request.id, "invalid argument", "wait must be a string")
      return Ok(())
    }
    None => "none"
  }
  if !self.manager.has_session(ctx_id) {
    self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
    return Ok(())
  }
  self.input_synthetic_events_by_context.remove(ctx_id)
  self.context_synthetic_scrolled.remove(ctx_id)
  self.clear_synthetic_location_href(ctx_id)
  let _ = self.fail_in_flight_navigation(
    ctx_id, "aborted", "Navigation interrupted by reload",
  )
  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let url = session.get_url()
      if self.has_beforeunload_prompt_in_scope(ctx_id) {
        let handler = self.resolve_unhandled_prompt_handler(
          ctx_id, "beforeunload",
        )
        let nav_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        self.clear_pending_prompt_state(ctx_id)
        self.pending_prompt_type[ctx_id] = "beforeunload"
        self.pending_beforeunload_request[ctx_id] = request.id
        self.pending_beforeunload_url[ctx_id] = url
        self.pending_beforeunload_requested_url[ctx_id] = self.requested_navigation_url(
          ctx_id,
        )
        self.pending_beforeunload_wait[ctx_id] = wait_mode
        self.pending_beforeunload_navigation[ctx_id] = nav_id
        self.emit_navigation_started_event(ctx_id, url, nav_id)
        self.emit_user_prompt_opened(
          ctx_id,
          "beforeunload",
          handler,
          "beforeunload",
          None,
        )
        return Ok(())
      }
      self.complete_navigation_request_with_wait(
        request.id,
        ctx_id,
        url,
        wait_mode,
      )
      Ok(())
    }
    None => {
      self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
      Ok(())
    }
  }
}
