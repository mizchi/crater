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
