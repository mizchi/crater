///|
fn BidiProtocol::handle_network_continue_blocked_request(
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
  let blocked_request_id = match map.get("request") {
    Some(String(blocked_request_id)) => blocked_request_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "request must be a string",
      )
      return
    }
  }
  let blocked_request = match
    self.get_network_blocked_request(blocked_request_id) {
    Some(blocked_request) => blocked_request
    None => {
      self.send_error(request_id, "no such request", "Unknown request")
      return
    }
  }
  match blocked_request.get("phase") {
    Some(String("beforeRequestSent")) => ()
    _ => {
      self.send_error(
        request_id, "invalid argument", "Request is not blocked at beforeRequestSent",
      )
      return
    }
  }
  let base_input = match
    self.synthetic_network_event_input_from_blocked_request(
      request_id, blocked_request_id, blocked_request,
    ) {
    Some(input) => input
    None => return
  }
  let mut input = base_input
  let mut synthetic_location_href : String? = None
  let mut completed_navigation_url : String? = None
  let is_navigation = match
    get_map_field_with_alias(blocked_request, "isNavigation", "is_navigation") {
    Some(True) => true
    Some(False) => false
    _ => false
  }

  match map.get("body") {
    Some(raw_body) =>
      match
        self.normalize_synthetic_network_bytes_value(
          request_id, raw_body, "body",
        ) {
        Some(body_value) => input = { ..input, request_value: Some(body_value) }
        None => return
      }
    None => ()
  }

  match map.get("method") {
    Some(String(http_method)) =>
      if is_valid_network_header_name_token(http_method) {
        input = { ..input, http_method, }
      } else {
        self.send_error(request_id, "invalid argument", "method is invalid")
        return
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "method must be a string")
      return
    }
    None => ()
  }

  match map.get("url") {
    Some(raw_url) =>
      match self.normalize_synthetic_network_continue_url(request_id, raw_url) {
        Some(url) => input = { ..input, url, }
        None => return
      }
    None => ()
  }

  let has_headers = map.contains("headers")
  let has_cookies = map.contains("cookies")
  if has_headers {
    let normalized_headers = match
      self.normalize_synthetic_network_header_entries(
        request_id,
        map.get("headers"),
      ) {
      Some(headers) => synthetic_network_merge_header_entries(headers)
      None => return
    }
    input = { ..input, request_headers: normalized_headers }
  }
  if has_cookies {
    let cookies_override = match
      self.normalize_synthetic_network_cookie_entries(
        request_id,
        map.get("cookies"),
      ) {
      Some(cookies_override) => cookies_override
      None => return
    }
    input = {
      ..input,
      request_cookies: cookies_override.cookies,
      request_cookies_override: cookies_override.enabled,
    }
  } else if has_headers {
    input = { ..input, request_cookies: [], request_cookies_override: true }
  }

  match map.get("navigation") {
    Some(String(navigation)) =>
      input = { ..input, navigation: Some(navigation) }
    Some(Null) => input = { ..input, navigation: None }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "navigation must be a string",
      )
      return
    }
    None => ()
  }
  match map.get("syntheticLocationHref") {
    Some(String(href)) => synthetic_location_href = Some(href)
    Some(Null) | None => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "syntheticLocationHref must be a string",
      )
      return
    }
  }

  let resolved_overrides = self.resolve_synthetic_response_overrides_internal(
    input.context_id,
    input.url,
    input.http_method,
    input.request_headers,
    false,
  )
  if is_navigation {
    let navigation_id = match input.navigation {
      Some(navigation_id) => {
        input = { ..input, navigation: Some(navigation_id) }
        navigation_id
      }
      None => {
        let generated_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        input = { ..input, navigation: Some(generated_id) }
        generated_id
      }
    }
    let original_url = match blocked_request.get("url") {
      Some(String(url)) => url
      _ => input.url
    }
    let resolved_url = self.resolve_effective_navigation_target_url(
      input.context_id,
      input.url,
    )
    self.input_synthetic_events_by_context.remove(input.context_id)
    self.context_synthetic_scrolled.remove(input.context_id)
    self.clear_synthetic_location_href(input.context_id)
    self.abort_in_flight_navigation_unless_matching(
      input.context_id,
      Some(navigation_id),
      "Navigation interrupted by another navigation",
    )
    if !is_valid_navigation_target_url(resolved_url) {
      self.send_error(request_id, "invalid argument", "url is invalid")
      return
    }
    if should_fail_navigation_with_unknown_error(resolved_url) {
      self.emit_navigation_started_event(
        input.context_id,
        resolved_url,
        navigation_id,
      )
      self.send_error(
        request_id, "unknown error", "Navigation failed: navigation target is unreachable",
      )
      return
    }
    if self.is_iframe_navigation_blocked(input.context_id, resolved_url) {
      self.emit_navigation_started_event(
        input.context_id,
        resolved_url,
        navigation_id,
      )
      self.emit_navigation_failed_event(
        input.context_id,
        resolved_url,
        navigation_id,
      )
      self.send_error(
        request_id, "unknown error", "Navigation failed: blocked by embedding policy",
      )
      return
    }
    match self.manager.get_session(input.context_id) {
      Some(session) =>
        match session.navigate_to(resolved_url) {
          Ok(_) => {
            self.remember_requested_navigation_url(input.context_id, input.url)
            self.apply_navigation_commit_state(
              input.context_id,
              resolved_url,
              navigation_id,
            )
            self.register_in_flight_navigation(
              input.context_id,
              resolved_url,
              navigation_id,
              self.pending_navigation_request.get(input.context_id),
            )
            completed_navigation_url = Some(resolved_url)
            if synthetic_location_href == None && original_url != input.url {
              synthetic_location_href = Some(original_url)
            }
          }
          Err(e) => {
            self.emit_navigation_started_event(
              input.context_id,
              resolved_url,
              navigation_id,
            )
            self.send_error(
              request_id,
              "unknown error",
              "Navigation failed: " + e.message,
            )
            return
          }
        }
      None => {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + input.context_id,
        )
        return
      }
    }
  }
  let response_overrides : @crater_network.SyntheticNetworkResponseOverrides = {
    from_cache: resolved_overrides.from_cache,
    headers: resolved_overrides.headers,
    mime_type: resolved_overrides.mime_type,
    protocol: resolved_overrides.protocol,
    status: resolved_overrides.status,
    status_text: resolved_overrides.status_text,
    auth_challenges: resolved_overrides.auth_challenges,
  }
  let response_started_event = match
    self.build_synthetic_response_event_json(
      request_id, input, response_overrides,
    ) {
    Some(event) => event
    None => return
  }
  let response_completed_event = match
    self.build_synthetic_response_event_json(
      request_id, input, response_overrides,
    ) {
    Some(event) => event
    None => return
  }
  match synthetic_location_href {
    Some(href) => self.remember_synthetic_location_href(input.context_id, href)
    None => ()
  }
  self.forget_network_blocked_request(blocked_request_id)
  self.send_continue_blocked_response_result(
    request_id,
    Some(response_started_event),
    Some(response_completed_event),
    None,
    None,
    true,
    None,
    None,
    None,
  )
  self.emit_synthetic_network_result_events(
    Some(response_started_event),
    Some(response_completed_event),
    None,
    None,
  )
  match completed_navigation_url {
    Some(url) => {
      if !self.is_subscribed_for_context(
          "browsingContext.load",
          input.context_id,
        ) {
        self.outbox.push(
          Event({
            event_method: "browsingContext.load",
            params: synthetic_network_load_event_json(
              input.context_id,
              input.navigation,
              url,
            ),
          }),
        )
      }
      self.complete_pending_navigation_response(
        input.context_id,
        Some(url),
        input.navigation,
      )
    }
    None => ()
  }
}
