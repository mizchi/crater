///|
/// Handle browsingContext.handleUserPrompt.
fn BidiProtocol::handle_browsing_context_user_prompt(
  self : BidiProtocol,
  request : BidiRequest,
) -> Result[Unit, String] {
  match get_param_raw(request.params, "context") {
    Some(String(ctx_id)) => {
      if !self.manager.has_session(ctx_id) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return Ok(())
      }

      let accepted = match get_param_raw(request.params, "accept") {
        Some(True) => true
        Some(False) => false
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "accept must be a boolean",
          )
          return Ok(())
        }
        None => true
      }
      let user_text = match
        get_param_raw_with_alias(request.params, "userText", "user_text") {
        Some(String(v)) => Some(v)
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "userText must be a string",
          )
          return Ok(())
        }
        None => None
      }

      match self.resolve_pending_prompt_context(ctx_id) {
        Some(prompt_ctx_id) =>
          self.resolve_existing_user_prompt(
            request.id,
            prompt_ctx_id,
            accepted,
            user_text,
          )
        None => {
          self.send_error(request.id, "no such alert", "No dialog is showing")
          Ok(())
        }
      }
    }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "context must be a string",
      )
      Ok(())
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing context")
      Ok(())
    }
  }
}

///|
fn BidiProtocol::resolve_existing_user_prompt(
  self : BidiProtocol,
  request_id : Int,
  prompt_ctx_id : String,
  accepted : Bool,
  user_text : String?,
) -> Result[Unit, String] {
  let prompt_type = self.pending_prompt_type
    .get(prompt_ctx_id)
    .unwrap_or("alert")
  let pending_close = self.pending_close_request.get(prompt_ctx_id)
  let pending_script_request = self.pending_prompt_request.get(prompt_ctx_id)
  let pending_script_realm = self.pending_prompt_realm.get(prompt_ctx_id)
  let pending_prompt_unwrap_result = self.pending_prompt_unwrap_result
    .get(prompt_ctx_id)
    .unwrap_or(false)
  let pending_beforeunload_request = self.pending_beforeunload_request.get(
    prompt_ctx_id,
  )
  let pending_beforeunload_url = self.pending_beforeunload_url.get(
    prompt_ctx_id,
  )
  let pending_beforeunload_requested_url = self.pending_beforeunload_requested_url.get(
    prompt_ctx_id,
  )
  let pending_beforeunload_wait = self.pending_beforeunload_wait
    .get(prompt_ctx_id)
    .unwrap_or("none")
  let pending_beforeunload_navigation = self.pending_beforeunload_navigation.get(
    prompt_ctx_id,
  )
  let pending_beforeunload_finalize_mode = self.pending_beforeunload_finalize_mode.get(
    prompt_ctx_id,
  )
  let pending_result_var = self.pending_prompt_result_var.get(prompt_ctx_id)
  self.emit_user_prompt_closed(prompt_ctx_id, prompt_type, accepted, user_text)
  match pending_close {
    Some(close_request_id) => {
      let close_response_mode = self.pending_close_response_mode
        .get(prompt_ctx_id)
        .unwrap_or("wait")
      if close_response_mode == "empty" {
        self.close_context_and_cleanup(prompt_ctx_id, true) |> ignore
        self.send_success(close_request_id, Some(make_object({})))
      } else {
        let close_result = match
          self.pending_close_wait_for_destroyed.get(prompt_ctx_id) {
          Some(wait_for_destroyed) =>
            make_object({
              "waitForDestroyed": Json::boolean(wait_for_destroyed),
            })
          None => make_object({})
        }
        self.send_success(close_request_id, Some(close_result))
        self.close_context_and_cleanup(prompt_ctx_id, true) |> ignore
      }
    }
    None => {
      match pending_result_var {
        Some(var_name) =>
          self.apply_pending_prompt_result_var(
            prompt_ctx_id, var_name, prompt_type, accepted, user_text,
          )
        None => ()
      }
      match
        (
          pending_beforeunload_request, pending_beforeunload_url, pending_beforeunload_navigation,
        ) {
        (Some(nav_request_id), Some(nav_url), pending_navigation_id) =>
          if accepted {
            self.resume_beforeunload_navigation_after_prompt(
              prompt_ctx_id, nav_request_id, nav_url, pending_beforeunload_requested_url,
              pending_beforeunload_wait, pending_navigation_id, pending_beforeunload_finalize_mode,
            )
          } else {
            match pending_navigation_id {
              Some(nav_id) =>
                self.emit_navigation_failed_event(
                  prompt_ctx_id, nav_url, nav_id,
                )
              None => ()
            }
            self.send_error(
              nav_request_id, "unknown error", "Navigation canceled by beforeunload prompt",
            )
          }
        _ => ()
      }
      match pending_script_request {
        Some(eval_request_id) => {
          let realm_id = match pending_script_realm {
            Some(realm) => realm
            None =>
              self.context_realm
              .get(prompt_ctx_id)
              .unwrap_or("realm-" + prompt_ctx_id)
          }
          self.send_script_prompt_result(
            eval_request_id, realm_id, prompt_type, accepted, user_text, pending_prompt_unwrap_result,
          )
        }
        None => ()
      }
      self.clear_pending_prompt_state(prompt_ctx_id)
    }
  }
  self.send_success(request_id, Some(make_object({})))
  Ok(())
}

///|
fn BidiProtocol::resume_beforeunload_navigation_after_prompt(
  self : BidiProtocol,
  prompt_ctx_id : String,
  nav_request_id : Int,
  nav_url : String,
  pending_beforeunload_requested_url : String?,
  pending_beforeunload_wait : String,
  pending_navigation_id : String?,
  pending_beforeunload_finalize_mode : String?,
) -> Unit {
  match self.manager.get_session(prompt_ctx_id) {
    Some(session) =>
      match session.navigate_to(nav_url) {
        Ok(_) => {
          let requested_url = pending_beforeunload_requested_url.unwrap_or(
            nav_url,
          )
          self.remember_requested_navigation_url(prompt_ctx_id, requested_url)
          match pending_beforeunload_finalize_mode {
            Some("reloadWithState") => {
              let completion = self.build_navigation_completion(
                nav_request_id, prompt_ctx_id, nav_url, pending_beforeunload_wait,
                pending_navigation_id,
              )
              let _ = self.emit_synthetic_navigation_request_sequence(
                prompt_ctx_id,
                requested_url,
                Some(completion.navigation_id),
              )
              let blocked = self.has_network_blocked_navigation_request(
                prompt_ctx_id,
                Some(completion.navigation_id),
              )
              if blocked {
                self.strip_pending_navigation_lifecycle_events(
                  prompt_ctx_id,
                  nav_url,
                  completion.navigation_id,
                )
                self.clear_pending_navigation_state(prompt_ctx_id)
              } else if !completion.deferred_response {
                self.send_success(nav_request_id, Some(completion.result))
              }
            }
            Some("navigateWithState") =>
              self.complete_navigate_with_state(
                nav_request_id, prompt_ctx_id, requested_url, nav_url, "", pending_beforeunload_wait,
                pending_navigation_id,
              )
            _ =>
              self.complete_navigation_request_with_wait_and_navigation(
                nav_request_id, prompt_ctx_id, nav_url, pending_beforeunload_wait,
                pending_navigation_id,
              )
          }
        }
        Err(e) => {
          match pending_navigation_id {
            Some(nav_id) =>
              self.emit_navigation_failed_event(prompt_ctx_id, nav_url, nav_id)
            None => ()
          }
          self.send_error(
            nav_request_id,
            "unknown error",
            "Navigation failed: " + e.message,
          )
        }
      }
    None =>
      self.send_error(
        nav_request_id,
        "no such frame",
        "Unknown context: " + prompt_ctx_id,
      )
  }
}
