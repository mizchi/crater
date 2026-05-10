///|
fn BidiProtocol::handle_session_is_subscribed_for_context(
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
  let event_name = match map.get("event") {
    Some(String(event_name)) => event_name
    _ => {
      self.send_error(request_id, "invalid argument", "event must be a string")
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
  let subscribed = self.manager.has_session(context_id) &&
    self.is_subscribed_for_context(event_name, context_id)
  self.send_success(
    request_id,
    Some(make_object({ "subscribed": Json::boolean(subscribed) })),
  )
}

///|
fn BidiProtocol::handle_session_prepare_baseline_context_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match params {
    Some(Object(_)) | None => ()
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let preserved_default_prompt_behavior = self.user_context_prompt_behavior.get(
    "default",
  )
  let preserved_ctx_id = self.default_context_id.unwrap_or(
    self.ensure_default_context(),
  )
  self.reset_session_runtime_state()
  match preserved_default_prompt_behavior {
    Some(behavior) => self.user_context_prompt_behavior["default"] = behavior
    None => ()
  }
  let ctx_id = self.recreate_default_context_with_id(preserved_ctx_id)
  let realm_id = self.reset_context_to_blank_for_test(ctx_id)
  ignore(evaluate_js("try { delete globalThis.SOME_VARIABLE; } catch (_) {}"))
  let context_info = self.build_context_info_for_test(ctx_id)
  self.send_success(
    request_id,
    Some(
      make_object({
        "context": Json::string(ctx_id),
        "realm": Json::string(realm_id),
        "contextInfo": context_info,
      }),
    ),
  )
}

///|
fn BidiProtocol::recreate_default_context_with_id(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  let id = self.manager.create_session_with_id(ctx_id)
  self.context_user_context[id] = "default"
  self.context_children[id] = []
  self.context_client_window[id] = "client-window-" + id
  self.context_parent.remove(id)
  self.context_had_synthetic_child.remove(id)
  self.context_has_beforeunload.remove(id)
  self.context_blocks_cross_origin_iframe_navigation.remove(id)
  self.clear_pending_prompt_state(id)
  self.clear_pending_navigation_state(id)
  self.clear_network_state_for_context(id)
  self.context_local_storage.remove(id)
  self.remove_storage_cookie_scope(id)
  self.context_last_started_navigation.remove(id)
  self.context_requested_navigation_url.remove(id)
  self.user_contexts["default"] = true
  self.default_context_id = Some(id)
  self.active_context_id = Some(id)
  self.assign_new_realm(id) |> ignore
  self.apply_effective_viewport_to_runtime_context(id, id)
  id
}

///|
fn BidiProtocol::handle_session_get_baseline_context_info_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match params {
    Some(Object(_)) | None => ()
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let ctx_id = self.ensure_default_context()
  let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
  let context_info = self.build_context_info_for_test(ctx_id)
  self.send_success(
    request_id,
    Some(
      make_object({
        "context": Json::string(ctx_id),
        "realm": Json::string(realm_id),
        "contextInfo": context_info,
      }),
    ),
  )
}

///|
fn BidiProtocol::handle_session_get_baseline_context_info_value_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match params {
    Some(Object(_)) | None => ()
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let ctx_id = self.ensure_default_context()
  let context_info = self.build_context_info_for_test(ctx_id)
  self.send_success(request_id, Some(context_info))
}

///|
fn BidiProtocol::build_context_info_for_test(
  self : BidiProtocol,
  ctx_id : String,
) -> Json {
  self
  .build_context_entry(ctx_id, true, 0, Some(0))
  .unwrap_or(
    make_object({
      "context": Json::string(ctx_id),
      "url": Json::string(self.current_context_url(ctx_id)),
      "children": Json::array([]),
      "parent": Json::null(),
      "clientWindow": Json::string(
        self.context_client_window
        .get(ctx_id)
        .unwrap_or("client-window-" + ctx_id),
      ),
      "userContext": Json::string(
        self.context_user_context.get(ctx_id).unwrap_or("default"),
      ),
      "originalOpener": Json::null(),
    }),
  )
}
