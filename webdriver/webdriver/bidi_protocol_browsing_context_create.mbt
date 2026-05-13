///|
fn BidiProtocol::handle_browsing_context_create_synthetic_child_context(
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
    None =>
      match get_map_field_with_alias(map, "parentContext", "parent_context") {
        Some(String(context_id)) => context_id
        _ => ""
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "parentContext must be a string",
      )
      return
    }
  }
  if context_id == "" {
    self.send_error(
      request_id, "invalid argument", "parentContext must be a string",
    )
    return
  }
  if !self.manager.has_session(context_id) {
    self.send_error(
      request_id,
      "no such frame",
      "Unknown parent context: " + context_id,
    )
    return
  }
  let user_context_id = match
    get_map_field_with_alias(map, "userContext", "user_context") {
    Some(String(user_context_id)) =>
      if user_context_id == "" || !self.user_contexts.contains(user_context_id) {
        self.send_error(
          request_id,
          "no such user context",
          "Unknown user context: " + user_context_id,
        )
        return
      } else {
        user_context_id
      }
    Some(Null) | None =>
      self.context_user_context.get(context_id).unwrap_or("default")
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContext must be a string",
      )
      return
    }
  }
  let requested_url = match map.get("url") {
    Some(String(url)) => url
    Some(Null) | None => "about:blank"
    Some(_) => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return
    }
  }

  let result = self.create_synthetic_child_context_result(
    context_id, requested_url, user_context_id,
  )
  self.send_success(request_id, Some(result))
}

///|
fn BidiProtocol::create_synthetic_child_context_result(
  self : BidiProtocol,
  context_id : String,
  requested_url : String,
  user_context_id : String,
) -> Json {
  let child_ctx_id = self.create_child_context(context_id, user_context_id)
  self.context_had_synthetic_child[context_id] = true
  let resolved_url = self.resolve_navigation_target_url(
    context_id, requested_url,
  )
  let effective_url = self.normalize_wpt_navigation_target_url(
    child_ctx_id, resolved_url,
  )

  self.emit_context_created(
    child_ctx_id,
    "tab",
    "about:blank",
    None,
    Some(context_id),
  )
  let child_nav_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  if self.is_iframe_navigation_blocked(child_ctx_id, effective_url) {
    self.emit_default_realm(child_ctx_id)
    self.emit_navigation_started_event(
      child_ctx_id, effective_url, child_nav_id,
    )
    self.emit_navigation_failed_event(child_ctx_id, effective_url, child_nav_id)
    return make_object({
      "context": Json::string(child_ctx_id),
      "parentContext": Json::string(context_id),
      "userContext": Json::string(user_context_id),
      "url": Json::string(effective_url),
    })
  }
  match self.manager.get_session(child_ctx_id) {
    Some(child_session) => {
      let _ = child_session.navigate_to(effective_url)
    }
    None => ()
  }
  self.load_data_url_content(child_ctx_id, effective_url)
  self.clear_context_sandbox_realms(child_ctx_id)
  let window_realm_id = self.assign_new_realm(child_ctx_id)
  self.emit_default_realm(child_ctx_id)
  self.emit_worker_realms_from_scripts(child_ctx_id, window_realm_id)
  self.apply_preload_scripts_for_context(child_ctx_id)
  self.execute_inline_scripts_for_context(child_ctx_id)
  self.emit_navigation_events(child_ctx_id, effective_url, child_nav_id)
  if effective_url != "about:blank" {
    self.refresh_child_contexts_from_iframes_with_depth(child_ctx_id, 1)
  }
  make_object({
    "context": Json::string(child_ctx_id),
    "parentContext": Json::string(context_id),
    "userContext": Json::string(user_context_id),
    "url": Json::string(effective_url),
  })
}

///|
fn BidiProtocol::handle_browsing_context_create_and_get_info(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.create_top_level_context_from_params(request_id, params) {
    Some(ctx_id) =>
      match self.build_context_entry(ctx_id, true, 0, Some(0)) {
        Some(entry) => self.send_success(request_id, Some(entry))
        None =>
          self.send_error(
            request_id,
            "no such frame",
            "Unknown context: " + ctx_id,
          )
      }
    None => ()
  }
}

///|
fn BidiProtocol::handle_browsing_context_create_and_get_info_value(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.create_top_level_context_from_params(request_id, params) {
    Some(ctx_id) =>
      match self.build_context_entry(ctx_id, true, 0, Some(0)) {
        Some(entry) => self.send_success(request_id, Some(entry))
        None =>
          self.send_error(
            request_id,
            "no such frame",
            "Unknown context: " + ctx_id,
          )
      }
    None => ()
  }
}

///|
fn BidiProtocol::handle_browsing_context_create_context_id(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.create_top_level_context_from_params(request_id, params) {
    Some(ctx_id) => self.send_success(request_id, Some(Json::string(ctx_id)))
    None => ()
  }
}

///|
fn BidiProtocol::create_top_level_context_from_params(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let type_hint = match get_map_field_with_alias(map, "type", "type_hint") {
    Some(String(kind)) => kind
    Some(_) => {
      self.send_error(request_id, "invalid argument", "type must be a string")
      return None
    }
    None => "tab"
  }
  if type_hint != "tab" && type_hint != "window" {
    self.send_error(
      request_id, "invalid argument", "type must be 'tab' or 'window'",
    )
    return None
  }

  let background = match map.get("background") {
    Some(True) => true
    Some(False) => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "background must be a boolean",
      )
      return None
    }
    None => false
  }

  let reference_context = match
    get_map_field_with_alias(map, "referenceContext", "reference_context") {
    Some(String(reference_ctx_id)) => {
      if !self.manager.has_session(reference_ctx_id) {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + reference_ctx_id,
        )
        return None
      }
      if self.context_parent.contains(reference_ctx_id) {
        self.send_error(
          request_id, "invalid argument", "referenceContext must be top-level",
        )
        return None
      }
      Some(reference_ctx_id)
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "referenceContext must be a string",
      )
      return None
    }
    None => None
  }

  let requested_user_context = match
    get_map_field_with_alias(map, "userContext", "user_context") {
    Some(String(user_ctx_id)) =>
      if user_ctx_id == "" || !self.user_contexts.contains(user_ctx_id) {
        self.send_error(
          request_id,
          "no such user context",
          "Unknown user context: " + user_ctx_id,
        )
        return None
      } else {
        Some(user_ctx_id)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContext must be a string",
      )
      return None
    }
    None => None
  }

  let user_ctx = match requested_user_context {
    Some(user_ctx_id) => user_ctx_id
    None =>
      match reference_context {
        Some(reference_ctx_id) =>
          self.context_user_context.get(reference_ctx_id).unwrap_or("default")
        None => "default"
      }
  }

  let previous_active_context = self.active_context_id
  let ctx_id = self.create_context(user_ctx, type_hint)
  if type_hint == "window" {
    match reference_context {
      Some(reference_ctx_id) =>
        match self.context_client_window.get(reference_ctx_id) {
          Some(reference_client_window) =>
            self.context_client_window[ctx_id] = reference_client_window
          None => ()
        }
      None => ()
    }
  }
  if background {
    self.active_context_id = previous_active_context
  }
  self.emit_context_created(ctx_id, type_hint, "about:blank", None, None)
  self.emit_default_realm(ctx_id)
  self.apply_preload_scripts_for_context(ctx_id)
  Some(ctx_id)
}
