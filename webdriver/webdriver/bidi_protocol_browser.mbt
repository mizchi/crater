///|
fn BidiProtocol::handle_browser_has_user_context(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_browser_has_user_context_known(request_id, params) {
    Some(known) =>
      self.send_success(
        request_id,
        Some(make_object({ "known": Json::boolean(known) })),
      )
    None => ()
  }
}

///|
fn BidiProtocol::handle_browser_has_user_context_value(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_browser_has_user_context_known(request_id, params) {
    Some(known) => self.send_success(request_id, Some(Json::boolean(known)))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_browser_has_user_context_known(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }
  let user_context = match map.get("userContext") {
    Some(String(user_context)) => user_context
    _ => {
      self.send_error(
        request_id, "invalid argument", "userContext must be a string",
      )
      return None
    }
  }
  Some(self.user_contexts.contains(user_context))
}

///|
fn BidiProtocol::resolve_browser_user_contexts_list(
  self : BidiProtocol,
) -> Array[Json] {
  let contexts : Array[Json] = []
  for id, _ in self.user_contexts {
    contexts.push(make_object({ "userContext": Json::string(id) }))
  }
  contexts
}

///|
fn BidiProtocol::resolve_browser_client_windows_list(
  self : BidiProtocol,
) -> Array[Json] {
  let top_level_contexts : Array[String] = []
  for ctx_id in self.manager.list_sessions() {
    if !self.context_parent.contains(ctx_id) {
      top_level_contexts.push(ctx_id)
    }
  }

  let mut active_client_window : String? = None
  match self.active_context_id {
    Some(active_ctx) =>
      if !self.context_parent.contains(active_ctx) {
        active_client_window = self.context_client_window.get(active_ctx)
      }
    None => ()
  }
  match active_client_window {
    Some(_) => ()
    None =>
      match self.default_context_id {
        Some(default_ctx) =>
          if !self.context_parent.contains(default_ctx) {
            active_client_window = self.context_client_window.get(default_ctx)
          }
        None => ()
      }
  }

  let windows : Array[Json] = []
  let seen_windows : Map[String, Bool] = {}
  for ctx_id in top_level_contexts {
    let client_window = self.context_client_window
      .get(ctx_id)
      .unwrap_or("client-window-" + ctx_id)
    if !seen_windows.contains(client_window) {
      seen_windows[client_window] = true
      let is_active = match active_client_window {
        Some(active_window) => active_window == client_window
        None => windows.length() == 0
      }
      windows.push(
        make_object({
          "clientWindow": Json::string(client_window),
          "active": Json::boolean(is_active),
        }),
      )
    }
  }
  windows
}

///|
fn BidiProtocol::resolve_browser_create_user_context(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  match self.validate_browser_create_user_context(request_id, params) {
    Some(_) => return None
    None => ()
  }
  let id = "user-" + self.user_contexts.length().to_string()
  self.user_contexts[id] = true
  match
    get_param_raw_with_alias(
      params, "unhandledPromptBehavior", "unhandled_prompt_behavior",
    ) {
    Some(Object(behavior)) =>
      self.user_context_prompt_behavior[id] = make_object(behavior)
    _ => ()
  }
  Some(id)
}
