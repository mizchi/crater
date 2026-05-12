///|
fn BidiProtocol::perform_synthetic_fetch_step(
  self : BidiProtocol,
  request_id : Int,
  context_id : String,
  request_step : SyntheticFetchPlanEntry,
  raw_request_headers : Array[Json],
  should_abort : Bool,
) -> SyntheticFetchStepResult {
  let resolved_request_headers = self.resolve_network_extra_header_entries(
    context_id, raw_request_headers,
  )
  let base_input : SyntheticNetworkEventInput = {
    context_id,
    url: request_step.url,
    http_method: request_step.http_method,
    request_token: request_step.request_token,
    request_headers: resolved_request_headers,
    request_value: request_step.request_value,
    request_cookies: [],
    request_cookies_override: false,
    intercepts: [],
    redirect_count: request_step.redirect_count,
    navigation: None,
    destination: "",
    initiator_type: Some("fetch"),
  }
  let response_overrides = self.resolve_synthetic_response_overrides_internal(
    context_id,
    request_step.url,
    request_step.http_method,
    resolved_request_headers,
    true,
  )

  let before_intercepts = self.resolve_matching_network_intercepts_internal(
    context_id,
    "beforeRequestSent",
    request_step.url,
  )
  let before_subscribed = self.is_subscribed_for_context(
    "network.beforeRequestSent", context_id,
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
    match
      self.build_synthetic_before_request_sent_event_json(
        request_id, before_input,
      ) {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.beforeRequestSent", params: event }),
        )
      None => return { blocked_text: None, response_value: None }
    }
  }
  if before_blocked {
    let blocked_request : Map[String, Json] = {
      "phase": Json::string("beforeRequestSent"),
      "context_id": Json::string(context_id),
      "url": Json::string(request_step.url),
      "method": Json::string(request_step.http_method),
      "request_headers": synthetic_navigation_header_object_from_entries(
        raw_request_headers,
      ),
      "redirect_count": Json::number(request_step.redirect_count.to_double()),
      "navigation": Json::null(),
      "destination": Json::string(""),
      "initiator_type": Json::string("fetch"),
      "is_navigation": Json::boolean(false),
    }
    match request_step.request_value {
      Some(request_value) => blocked_request["request_value"] = request_value
      None => ()
    }
    self.remember_network_blocked_request(
      request_step.request_token,
      blocked_request,
    )
    return {
      blocked_text: Some("Request blocked by network intercept"),
      response_value: None,
    }
  }

  if should_abort ||
    synthetic_navigation_is_unreachable_test_url(request_step.url) {
    if self.is_subscribed_for_context("network.fetchError", context_id) {
      match
        self.build_synthetic_fetch_error_event_json(
          request_id, base_input, "Request failed",
        ) {
        Some(event) =>
          self.outbox.push(
            Event({ event_method: "network.fetchError", params: event }),
          )
        None => ()
      }
    }
    return { blocked_text: None, response_value: None }
  }

  let response_started_intercepts = self.resolve_matching_network_intercepts_internal(
    context_id,
    "responseStarted",
    request_step.url,
  )
  let response_started_subscribed = self.is_subscribed_for_context(
    "network.responseStarted", context_id,
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
      request_id, response_input, response_overrides,
    )
    match response_started_event {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.responseStarted", params: event }),
        )
      None => return { blocked_text: None, response_value: None }
    }
  }
  if response_started_blocked {
    let blocked_request = synthetic_navigation_blocked_request_payload(
      base_input, "responseStarted", response_started_event,
    )
    blocked_request["is_navigation"] = Json::boolean(false)
    self.remember_network_blocked_request(
      request_step.request_token,
      blocked_request,
    )
    return {
      blocked_text: Some("Request blocked by responseStarted intercept"),
      response_value: None,
    }
  }

  let auth_required_intercepts = self.resolve_matching_network_intercepts_internal(
    context_id,
    "authRequired",
    request_step.url,
  )
  let auth_required_subscribed = self.is_subscribed_for_context(
    "network.authRequired", context_id,
  )
  let auth_required_needed = synthetic_navigation_requires_auth_event(
    response_overrides,
  )
  let auth_required_blocked = auth_required_needed &&
    auth_required_subscribed &&
    auth_required_intercepts.length() > 0
  let mut auth_required_event : Json? = None
  if auth_required_subscribed && auth_required_needed {
    let auth_overrides : SyntheticNetworkResponseOverrides = if auth_required_blocked {
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
      request_id, auth_input, auth_overrides,
    )
    match auth_required_event {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.authRequired", params: event }),
        )
      None => return { blocked_text: None, response_value: None }
    }
  }
  if auth_required_blocked {
    let blocked_request = synthetic_navigation_blocked_request_payload(
      base_input, "authRequired", auth_required_event,
    )
    blocked_request["is_navigation"] = Json::boolean(false)
    self.remember_network_blocked_request(
      request_step.request_token,
      blocked_request,
    )
    return {
      blocked_text: Some("Request blocked by authRequired intercept"),
      response_value: None,
    }
  }

  let response_value = synthetic_fetch_synthesize_response_value(
    request_step.url,
    if synthetic_fetch_is_headers_echo_url(request_step.url) {
      Some(
        self.build_network_headers_echo_payload(
          context_id, resolved_request_headers,
        ),
      )
    } else {
      None
    },
  )
  self.remember_network_collected_data_internal(
    context_id,
    request_step.request_token,
    request_step.request_value,
    Some(response_value),
  )

  if self.is_subscribed_for_context("network.responseCompleted", context_id) {
    match
      self.build_synthetic_response_event_json(
        request_id, base_input, response_overrides,
      ) {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.responseCompleted", params: event }),
        )
      None =>
        return { blocked_text: None, response_value: Some(response_value) }
    }
  }

  { blocked_text: None, response_value: Some(response_value) }
}
