///|
/// Dispatch network domain (minimal no-op)
fn BidiProtocol::dispatch_network(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    // Spec-conformant name from WebDriver BiDi specification.
    // Returns `{ intercept: "<id>" }` as required by the spec.
    "addIntercept" => {
      self.handle_network_add_intercept(request.id, request.params)
      Ok(())
    }
    // Internal alias returning the raw id string (no wrapping object).
    // Kept for backwards-compat with existing wbtests; may be retired once
    // all callers migrate to the spec name `addIntercept`.
    "addInterceptId" => {
      self.handle_network_add_intercept_id(request.id, request.params)
      Ok(())
    }
    "removeIntercept" => {
      self.handle_network_remove_intercept(request.id, request.params)
      Ok(())
    }
    "addDataCollector" => {
      self.handle_network_add_data_collector(request.id, request.params)
      Ok(())
    }
    "addDataCollectorId" => {
      self.handle_network_add_data_collector_id(request.id, request.params)
      Ok(())
    }
    "setExtraHeaders" => {
      self.handle_network_set_extra_headers(request.id, request.params)
      Ok(())
    }
    "removeDataCollector" => {
      self.handle_network_remove_data_collector(request.id, request.params)
      Ok(())
    }
    "getData" => {
      self.handle_network_get_data(request.id, request.params)
      Ok(())
    }
    "disownData" => {
      self.handle_network_disown_data(request.id, request.params)
      Ok(())
    }
    "setCacheBehavior" => {
      self.handle_network_set_cache_behavior(request.id, request.params)
      Ok(())
    }
    "buildBeforeRequestSentEvent" => {
      self.handle_network_build_before_request_sent_event(
        request.id,
        request.params,
      )
      Ok(())
    }
    "resolveSyntheticResponseOverrides" => {
      self.handle_network_resolve_synthetic_response_overrides(
        request.id,
        request.params,
      )
      Ok(())
    }
    "rememberBlockedRequest" => {
      self.handle_network_remember_blocked_request(request.id, request.params)
      Ok(())
    }
    "getBlockedRequest" => {
      self.handle_network_get_blocked_request(request.id, request.params)
      Ok(())
    }
    "getBlockedRequestPhaseValue" => {
      self.handle_network_get_blocked_request_phase_value(
        request.id,
        request.params,
      )
      Ok(())
    }
    "getBlockedRequestNavigationValue" => {
      self.handle_network_get_blocked_request_navigation_value(
        request.id,
        request.params,
      )
      Ok(())
    }
    "forgetBlockedRequest" => {
      self.handle_network_forget_blocked_request(request.id, request.params)
      Ok(())
    }
    "hasBlockedNavigationRequest" => {
      self.handle_network_has_blocked_navigation_request(
        request.id,
        request.params,
      )
      Ok(())
    }
    "buildResponseEvent" => {
      self.handle_network_build_response_event(request.id, request.params)
      Ok(())
    }
    "buildFetchErrorEvent" => {
      self.handle_network_build_fetch_error_event(request.id, request.params)
      Ok(())
    }
    "buildHeadersEchoPayload" => {
      self.handle_network_build_headers_echo_payload(request.id, request.params)
      Ok(())
    }
    "failBlockedRequest" => {
      self.handle_network_fail_blocked_request(request.id, request.params)
      Ok(())
    }
    // Spec-conformant name from WebDriver BiDi specification.
    // Routes to the same handler as the internal alias `continueAuthRequest`.
    "continueWithAuth" => {
      self.handle_network_continue_auth_request(request.id, request.params)
      Ok(())
    }
    // Internal alias kept for backwards-compat with the WPT shim
    // (`scripts/crater_bidi_modules.py::NetworkModule.continue_with_auth`)
    // and existing wbtests. Retire once the shim drops its rename and
    // dependent wbtests migrate to the spec name.
    "continueAuthRequest" => {
      self.handle_network_continue_auth_request(request.id, request.params)
      Ok(())
    }
    "continueBlockedRequest" => {
      self.handle_network_continue_blocked_request(request.id, request.params)
      Ok(())
    }
    "continueBlockedResponse" => {
      self.handle_network_continue_blocked_response(request.id, request.params)
      Ok(())
    }
    "prepareNavigationRequest" => {
      self.handle_network_prepare_navigation_request(request.id, request.params)
      Ok(())
    }
    "performSyntheticFetch" => {
      self.handle_network_perform_synthetic_fetch(request.id, request.params)
      Ok(())
    }
    "prepareContextForTest" => {
      self.handle_network_prepare_context_for_test(request.id, request.params)
      Ok(())
    }
    "emitNavigationRequestSequence" => {
      self.handle_network_emit_navigation_request_sequence(
        request.id,
        request.params,
      )
      Ok(())
    }
    "allocateRequestId" => {
      self.handle_network_allocate_request_id(request.id, request.params)
      Ok(())
    }
    "resolveMatchingIntercepts" => {
      self.handle_network_resolve_matching_intercepts(
        request.id,
        request.params,
      )
      Ok(())
    }
    "rememberCollectedData" => {
      self.handle_network_remember_collected_data(request.id, request.params)
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown network method: " + action,
      )
      Ok(())
    }
  }
}
