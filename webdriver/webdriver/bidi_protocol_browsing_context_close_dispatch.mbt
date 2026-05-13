///|
/// Handle browsingContext.close.
fn BidiProtocol::handle_browsing_context_close(
  self : BidiProtocol,
  request : BidiRequest,
) -> Result[Unit, String] {
  match get_param_raw(request.params, "context") {
    Some(String(ctx_id)) => {
      let prompt_unload = match get_param_raw(request.params, "promptUnload") {
        Some(True) => true
        Some(False) => false
        Some(Null) => false
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "promptUnload must be a boolean",
          )
          return Ok(())
        }
        None => false
      }

      if !self.manager.has_session(ctx_id) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return Ok(())
      }
      if self.context_parent.contains(ctx_id) {
        self.send_error(
          request.id,
          "invalid argument",
          "context must be top-level",
        )
        return Ok(())
      }

      if prompt_unload && self.has_beforeunload_prompt_in_scope(ctx_id) {
        let handler = self.resolve_unhandled_prompt_handler(
          ctx_id, "beforeunload",
        )
        self.clear_pending_prompt_state(ctx_id)
        self.pending_prompt_type[ctx_id] = "beforeunload"
        self.pending_close_request[ctx_id] = request.id
        self.emit_user_prompt_opened(
          ctx_id,
          "beforeunload",
          handler,
          "beforeunload",
          None,
        )
        return Ok(())
      }

      // Send response BEFORE events (BiDi protocol requirement)
      self.send_success(request.id, Some(make_object({})))
      self.close_context_and_cleanup(ctx_id, true) |> ignore
      Ok(())
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
