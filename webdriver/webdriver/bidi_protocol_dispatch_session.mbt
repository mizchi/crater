///|
/// Dispatch session domain
fn BidiProtocol::dispatch_session(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "status" => {
      self.send_success(
        request.id,
        Some(
          make_object({
            "ready": Json::boolean(true),
            "message": Json::string("Crater WebDriver BiDi is ready"),
          }),
        ),
      )
      Ok(())
    }
    "new" => {
      let mut default_prompt_behavior : Json? = None
      match get_param_raw(request.params, "capabilities") {
        Some(Object(capabilities)) =>
          match capabilities.get("alwaysMatch") {
            Some(Object(always_match)) =>
              match always_match.get("unhandledPromptBehavior") {
                Some(String(handler)) =>
                  match normalize_unhandled_prompt_handler_name(handler) {
                    Some(normalized) => {
                      let behavior : Map[String, Json] = {}
                      behavior["default"] = Json::string(normalized)
                      default_prompt_behavior = Some(make_object(behavior))
                    }
                    None => {
                      self.send_error(
                        request.id,
                        "invalid argument",
                        "unhandledPromptBehavior handler is invalid",
                      )
                      return Ok(())
                    }
                  }
                Some(Object(behavior)) =>
                  match
                    self.validate_browser_unhandled_prompt_behavior(
                      request.id,
                      behavior,
                    ) {
                    Some(_) => return Ok(())
                    None =>
                      default_prompt_behavior = Some(make_object(behavior))
                  }
                Some(_) => {
                  self.send_error(
                    request.id,
                    "invalid argument",
                    "unhandledPromptBehavior must be a string or object",
                  )
                  return Ok(())
                }
                None => ()
              }
            Some(_) => ()
            None => ()
          }
        Some(_) => ()
        None => ()
      }
      self.reset_session_runtime_state()
      match default_prompt_behavior {
        Some(behavior) =>
          self.user_context_prompt_behavior["default"] = behavior
        None => ()
      }
      let session_id = "bidi-" + request.id.to_string()
      let ctx_id = self.ensure_default_context()
      let caps = build_capabilities()
      let result = make_object({
        "sessionId": Json::string(session_id),
        "capabilities": caps,
      })
      // Send response BEFORE events (BiDi protocol requirement)
      self.send_success(request.id, Some(result))
      // Emit initial context + realm events so Puppeteer can bind immediately.
      self.emit_context_created(ctx_id, "tab", "about:blank", None, None)
      self.emit_default_realm(ctx_id)
      Ok(())
    }
    "subscribe" => {
      match self.validate_session_subscribe_params(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      let subscription_id = self.handle_subscribe(request.params)
      self.send_success(
        request.id,
        Some(make_object({ "subscription": Json::string(subscription_id) })),
      )
      Ok(())
    }
    "subscribeId" => {
      match self.validate_session_subscribe_params(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      let subscription_id = self.handle_subscribe(request.params)
      self.send_success(request.id, Some(Json::string(subscription_id)))
      Ok(())
    }
    "unsubscribe" => {
      match
        self.validate_session_unsubscribe_params(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      self.handle_unsubscribe(request.params)
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "isSubscribedForContext" => {
      self.handle_session_is_subscribed_for_context(request.id, request.params)
      Ok(())
    }
    "prepareBaselineContextForTest" => {
      self.handle_session_prepare_baseline_context_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    "getBaselineContextInfoForTest" => {
      self.handle_session_get_baseline_context_info_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    "getBaselineContextInfoValueForTest" => {
      self.handle_session_get_baseline_context_info_value_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    "resetForTest" => {
      self.reset_session_runtime_state()
      let ctx_id = self.ensure_default_context()
      let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
      self.send_success(
        request.id,
        Some(
          make_object({
            "context": Json::string(ctx_id),
            "realm": Json::string(realm_id),
          }),
        ),
      )
      Ok(())
    }
    "end" => {
      self.reset_session_runtime_state()
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown session method: " + action,
      )
      Ok(())
    }
  }
}
