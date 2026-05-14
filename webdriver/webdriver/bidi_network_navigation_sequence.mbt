///|
fn BidiProtocol::emit_synthetic_network_event_sequence_internal(
  self : BidiProtocol,
  request : SyntheticNavigationRequestEntry,
  is_navigation : Bool,
  force_before_request_sent : Bool,
) -> Unit {
  let base_input : @crater_network.SyntheticNetworkEventInput = {
    context_id: request.context_id,
    url: request.url,
    http_method: "GET",
    request_token: request.request_token,
    request_headers: [],
    request_value: None,
    request_cookies: [],
    request_cookies_override: false,
    intercepts: [],
    redirect_count: request.redirect_count,
    navigation: request.navigation,
    destination: request.destination,
    initiator_type: request.initiator_type,
  }

  let response_overrides = self.resolve_synthetic_response_overrides_internal(
    request.context_id,
    request.url,
    "GET",
    [],
    true,
  )

  let before_intercepts = self.resolve_matching_network_intercepts_internal(
    request.context_id,
    "beforeRequestSent",
    request.url,
  )
  let before_subscribed = force_before_request_sent ||
    self.is_subscribed_for_context(
      "network.beforeRequestSent",
      request.context_id,
    )
  let before_blocked = before_subscribed && before_intercepts.length() > 0
  if before_subscribed {
    let before_input = {
      ..base_input,
      intercepts: if before_blocked {
        before_intercepts
      } else {
        []
      },
    }
    match self.build_synthetic_before_request_sent_event_json(0, before_input) {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.beforeRequestSent", params: event }),
        )
      None => return
    }
  }
  if before_blocked {
    self.remember_network_blocked_request(
      request.request_token,
      synthetic_navigation_blocked_request_payload(
        base_input,
        "beforeRequestSent",
        None,
      ),
    )
    return
  }

  if synthetic_navigation_is_unreachable_test_url(request.url) {
    if self.is_subscribed_for_context("network.fetchError", request.context_id) {
      match
        self.build_synthetic_fetch_error_event_json(
          0, base_input, "Request failed",
        ) {
        Some(event) =>
          self.outbox.push(
            Event({ event_method: "network.fetchError", params: event }),
          )
        None => ()
      }
    }
    return
  }

  let response_started_intercepts = self.resolve_matching_network_intercepts_internal(
    request.context_id,
    "responseStarted",
    request.url,
  )
  let response_started_subscribed = self.is_subscribed_for_context(
    "network.responseStarted",
    request.context_id,
  )
  let response_started_blocked = response_started_subscribed &&
    response_started_intercepts.length() > 0
  let mut response_started_event : Json? = None
  if response_started_subscribed {
    let response_input = {
      ..base_input,
      intercepts: if response_started_blocked {
        response_started_intercepts
      } else {
        []
      },
    }
    response_started_event = self.build_synthetic_response_event_json(
      0, response_input, response_overrides,
    )
    match response_started_event {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.responseStarted", params: event }),
        )
      None => return
    }
  }
  if response_started_blocked {
    self.remember_network_blocked_request(
      request.request_token,
      synthetic_navigation_blocked_request_payload(
        base_input, "responseStarted", response_started_event,
      ),
    )
    return
  }

  let auth_required_intercepts = self.resolve_matching_network_intercepts_internal(
    request.context_id,
    "authRequired",
    request.url,
  )
  let auth_required_subscribed = self.is_subscribed_for_context(
    "network.authRequired",
    request.context_id,
  )
  let auth_required_needed = synthetic_navigation_requires_auth_event(
    response_overrides,
  )
  let auth_required_blocked = auth_required_needed &&
    auth_required_subscribed &&
    auth_required_intercepts.length() > 0
  let mut auth_required_event : Json? = None
  if auth_required_subscribed && auth_required_needed {
    let auth_overrides : @crater_network.SyntheticNetworkResponseOverrides = if auth_required_blocked {
      {
        from_cache: response_overrides.from_cache,
        headers: response_overrides.headers,
        mime_type: response_overrides.mime_type,
        protocol: response_overrides.protocol,
        status: 401,
        status_text: "Unauthorized",
        auth_challenges: Some(
          Json::array([
            make_object({
              "scheme": Json::string("Basic"),
              "realm": Json::string("testrealm"),
            }),
          ]),
        ),
      }
    } else {
      response_overrides
    }
    let auth_input = {
      ..base_input,
      intercepts: if auth_required_blocked {
        auth_required_intercepts
      } else {
        []
      },
    }
    auth_required_event = self.build_synthetic_response_event_json(
      0, auth_input, auth_overrides,
    )
    match auth_required_event {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.authRequired", params: event }),
        )
      None => return
    }
  }
  if auth_required_blocked {
    self.remember_network_blocked_request(
      request.request_token,
      synthetic_navigation_blocked_request_payload(
        base_input, "authRequired", auth_required_event,
      ),
    )
    return
  }

  if self.is_subscribed_for_context(
      "network.responseCompleted",
      request.context_id,
    ) {
    match
      self.build_synthetic_response_event_json(
        0, base_input, response_overrides,
      ) {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.responseCompleted", params: event }),
        )
      None => return
    }
  }

  self.remember_network_collected_data_internal(
    request.context_id,
    request.request_token,
    None,
    Some(synthetic_navigation_synthesize_response_value(request.url)),
  )
  ignore(is_navigation)
}
