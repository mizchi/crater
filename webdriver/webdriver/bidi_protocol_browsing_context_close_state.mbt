///|
fn BidiProtocol::close_wait_for_destroyed(
  self : BidiProtocol,
  context_id : String,
) -> Bool {
  self.context_children.get(context_id).unwrap_or([]).length() > 0 ||
  self.context_had_synthetic_child.get(context_id).unwrap_or(false)
}

///|
fn BidiProtocol::handle_browsing_context_get_close_metadata(
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
  if self.context_parent.contains(context_id) {
    self.send_error(request_id, "invalid argument", "context must be top-level")
    return
  }
  let wait_for_destroyed = self.close_wait_for_destroyed(context_id)
  self.send_success(
    request_id,
    Some(make_object({ "waitForDestroyed": Json::boolean(wait_for_destroyed) })),
  )
}

///|
fn BidiProtocol::handle_browsing_context_close_with_state(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  self.handle_browsing_context_close_mode(request_id, params, true)
}

///|
fn BidiProtocol::handle_browsing_context_close_result(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  self.handle_browsing_context_close_mode(request_id, params, false)
}

///|
fn BidiProtocol::handle_browsing_context_close_mode(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
  include_wait_for_destroyed : Bool,
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
  let prompt_unload = match
    get_map_field_with_alias(map, "promptUnload", "prompt_unload") {
    Some(True) => true
    Some(False) | Some(Null) | None => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "promptUnload must be a boolean",
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
  if self.context_parent.contains(context_id) {
    self.send_error(request_id, "invalid argument", "context must be top-level")
    return
  }
  let wait_for_destroyed = self.close_wait_for_destroyed(context_id)
  if prompt_unload && self.has_beforeunload_prompt_in_scope(context_id) {
    let handler = self.resolve_unhandled_prompt_handler(
      context_id, "beforeunload",
    )
    self.clear_pending_prompt_state(context_id)
    self.pending_prompt_type[context_id] = "beforeunload"
    self.pending_close_request[context_id] = request_id
    self.pending_close_wait_for_destroyed[context_id] = wait_for_destroyed
    self.pending_close_response_mode[context_id] = if include_wait_for_destroyed {
      "wait"
    } else {
      "empty"
    }
    self.emit_user_prompt_opened(
      context_id,
      "beforeunload",
      handler,
      "beforeunload",
      None,
    )
    return
  }

  if include_wait_for_destroyed {
    self.send_success(
      request_id,
      Some(
        make_object({ "waitForDestroyed": Json::boolean(wait_for_destroyed) }),
      ),
    )
    self.close_context_and_cleanup(context_id, true) |> ignore
  } else {
    self.close_context_and_cleanup(context_id, true) |> ignore
    self.send_success(request_id, Some(make_object({})))
  }
}
