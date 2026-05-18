///|
/// Apply effective runtime overrides to runtime context window.
fn BidiProtocol::apply_effective_viewport_to_runtime_context(
  self : BidiProtocol,
  runtime_ctx_id : String,
  logical_ctx_id : String,
) -> Unit {
  let width = self.resolve_effective_viewport_width(logical_ctx_id)
  let height = self.resolve_effective_viewport_height(logical_ctx_id)
  let dpr = self.resolve_effective_device_pixel_ratio(logical_ctx_id)
  set_runtime_context_viewport(runtime_ctx_id, width, height, dpr)
  set_runtime_context_user_agent(
    runtime_ctx_id,
    self.resolve_effective_user_agent(logical_ctx_id),
  )
  set_runtime_context_locale(
    runtime_ctx_id,
    self.resolve_effective_locale(logical_ctx_id),
  )
  set_runtime_context_network_online(
    runtime_ctx_id,
    !self.resolve_effective_network_offline(logical_ctx_id),
  )
  let screen_orientation = self.resolve_effective_screen_orientation(
    logical_ctx_id,
  )
  set_runtime_context_screen_orientation(
    runtime_ctx_id,
    get_string_field(screen_orientation, "type").unwrap_or("portrait-primary"),
    get_int_field(screen_orientation, "angle").unwrap_or(0),
  )
  let screen_area = self.resolve_effective_screen_area(logical_ctx_id)
  set_runtime_context_screen_area(
    runtime_ctx_id,
    get_int_field(screen_area, "width").unwrap_or(width),
    get_int_field(screen_area, "height").unwrap_or(height),
    get_int_field(screen_area, "availWidth").unwrap_or(width),
    get_int_field(screen_area, "availHeight").unwrap_or(height),
  )
  // Push the partition cookie snapshot so the runtime fetch shim's
  // `__bidiResolveCookies` bridge can attach Cookie headers on outbound
  // fetches. Resolves bug.runtime.fetch-no-partition-cookies.
  let cookies = self.cookies_for_context_full_json(logical_ctx_id)
  set_runtime_context_cookies(runtime_ctx_id, Json::array(cookies).stringify())
}

///|
/// Ensure default context exists and return its ID
fn BidiProtocol::ensure_default_context(self : BidiProtocol) -> String {
  match self.default_context_id {
    Some(id) => id
    None => {
      let id = self.create_context("default", "tab")
      self.default_context_id = Some(id)
      id
    }
  }
}

///|
/// Clear all pending prompt state for a context.
fn BidiProtocol::clear_pending_prompt_state(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.pending_prompt_type.remove(ctx_id)
  self.pending_close_request.remove(ctx_id)
  self.pending_close_wait_for_destroyed.remove(ctx_id)
  self.pending_close_response_mode.remove(ctx_id)
  self.pending_prompt_request.remove(ctx_id)
  self.pending_prompt_realm.remove(ctx_id)
  self.pending_prompt_unwrap_result.remove(ctx_id)
  self.pending_beforeunload_request.remove(ctx_id)
  self.pending_beforeunload_url.remove(ctx_id)
  self.pending_beforeunload_requested_url.remove(ctx_id)
  self.pending_beforeunload_wait.remove(ctx_id)
  self.pending_beforeunload_navigation.remove(ctx_id)
  self.pending_beforeunload_finalize_mode.remove(ctx_id)
  self.pending_prompt_result_var.remove(ctx_id)
}

///|
/// Clear pending/in-flight navigation state for a context.
fn BidiProtocol::clear_pending_navigation_state(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.pending_navigation_request.remove(ctx_id)
  self.pending_navigation_response_mode.remove(ctx_id)
  self.in_flight_navigation_url.remove(ctx_id)
  self.in_flight_navigation_id.remove(ctx_id)
  self.in_flight_navigation_started_at.remove(ctx_id)
}

///|
/// Register an interruptible navigation and optional deferred command response.
fn BidiProtocol::register_in_flight_navigation(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
  request_id : Int?,
) -> Unit {
  self.in_flight_navigation_url[ctx_id] = url
  self.in_flight_navigation_id[ctx_id] = navigation_id
  self.in_flight_navigation_started_at[ctx_id] = input_now_ms()
  match request_id {
    Some(id) => self.pending_navigation_request[ctx_id] = id
    None => self.pending_navigation_request.remove(ctx_id)
  }
}

///|
/// Auto-resolve stale in-flight navigations on subsequent requests.
fn BidiProtocol::flush_expired_pending_navigation_requests(
  self : BidiProtocol,
) -> Unit {
  let now = input_now_ms()
  let pending_ctx_ids : Array[String] = []
  for ctx_id, _ in self.in_flight_navigation_started_at {
    pending_ctx_ids.push(ctx_id)
  }
  for ctx_id in pending_ctx_ids {
    let started_at = self.in_flight_navigation_started_at
      .get(ctx_id)
      .unwrap_or(now)
    if now - started_at < 1500 {
      continue
    }
    let navigation_id = self.in_flight_navigation_id.get(ctx_id)
    if self.has_network_blocked_navigation_request(ctx_id, navigation_id) {
      continue
    }
    match self.pending_navigation_request.get(ctx_id) {
      Some(request_id) => {
        let nav_id = navigation_id.unwrap_or("navigation")
        let url = self.in_flight_navigation_url
          .get(ctx_id)
          .unwrap_or("about:blank")
        if self.pending_navigation_response_mode.get(ctx_id).unwrap_or("state") ==
          "url" {
          self.send_success(request_id, Some(Json::string(url)))
        } else {
          self.send_success(
            request_id,
            Some(
              make_object({
                "navigation": Json::string(nav_id),
                "url": Json::string(url),
              }),
            ),
          )
        }
      }
      None => ()
    }
    self.clear_pending_navigation_state(ctx_id)
  }
}

///|
/// Fail an in-flight navigation because it was interrupted.
fn BidiProtocol::fail_in_flight_navigation(
  self : BidiProtocol,
  ctx_id : String,
  event_kind : String,
  message : String,
) -> Bool {
  match self.in_flight_navigation_id.get(ctx_id) {
    Some(navigation_id) => {
      let url = self.in_flight_navigation_url
        .get(ctx_id)
        .unwrap_or("about:blank")
      match self.pending_navigation_request.get(ctx_id) {
        Some(request_id) =>
          self.send_error(request_id, "unknown error", message)
        None => ()
      }
      if event_kind == "aborted" {
        self.emit_navigation_aborted_event(ctx_id, url, navigation_id)
      } else {
        self.emit_navigation_failed_event(ctx_id, url, navigation_id)
      }
      self.clear_pending_navigation_state(ctx_id)
      true
    }
    None => false
  }
}

///|
/// Create a new browsing context backed by a CDP session
fn BidiProtocol::create_context(
  self : BidiProtocol,
  user_context_id : String,
  type_hint : String,
) -> String {
  let id = self.manager.create_session()
  self.context_user_context[id] = user_context_id
  self.context_children[id] = []
  let client_window = if type_hint == "window" {
    "client-window-" + id
  } else {
    match self.active_context_id {
      Some(active_ctx) =>
        self.context_client_window
        .get(active_ctx)
        .unwrap_or("client-window-" + id)
      None => "client-window-" + id
    }
  }
  self.context_client_window[id] = client_window
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
  if !self.user_contexts.contains(user_context_id) {
    self.user_contexts[user_context_id] = true
  }
  self.active_context_id = Some(id)
  self.assign_new_realm(id) |> ignore
  self.apply_effective_viewport_to_runtime_context(id, id)
  id
}

///|
/// Create an iframe browsing context under a parent context.
fn BidiProtocol::create_child_context(
  self : BidiProtocol,
  parent_ctx_id : String,
  user_context_id : String,
) -> String {
  let id = self.manager.create_session()
  self.context_user_context[id] = user_context_id
  self.context_parent[id] = parent_ctx_id
  self.context_children[id] = []
  let parent_children = self.context_children.get(parent_ctx_id).unwrap_or([])
  parent_children.push(id)
  self.context_children[parent_ctx_id] = parent_children
  self.context_client_window[id] = self.context_client_window
    .get(parent_ctx_id)
    .unwrap_or("client-window-" + parent_ctx_id)
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
  if !self.user_contexts.contains(user_context_id) {
    self.user_contexts[user_context_id] = true
  }
  self.assign_new_realm(id) |> ignore
  self.apply_effective_viewport_to_runtime_context(id, id)
  id
}

///|
/// Unlink a context from its parent's children list.
fn BidiProtocol::unlink_from_parent(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) => {
      match self.context_children.get(parent_ctx_id) {
        Some(children) => {
          let filtered : Array[String] = []
          for child_id in children {
            if child_id != ctx_id {
              filtered.push(child_id)
            }
          }
          self.context_children[parent_ctx_id] = filtered
        }
        None => ()
      }
      self.context_parent.remove(ctx_id)
    }
    None => ()
  }
}

///|
/// Clear input state for a browsing context.
fn BidiProtocol::clear_input_state_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.input_pressed_keys.remove(ctx_id)
  self.input_pointer_x.remove(ctx_id)
  self.input_pointer_y.remove(ctx_id)
  self.input_pointer_buttons.remove(ctx_id)
  self.input_pointer_type.remove(ctx_id)
  self.input_pointer_target_shared.remove(ctx_id)
  self.input_pointer_down_x.remove(ctx_id)
  self.input_pointer_down_y.remove(ctx_id)
  self.input_pointer_down_target_shared.remove(ctx_id)
  self.input_pointer_dragged.remove(ctx_id)
  self.input_html_drag_source_shared.remove(ctx_id)
  self.input_html_drag_active.remove(ctx_id)
  self.input_html_drag_over_shared.remove(ctx_id)
  self.input_html_drag_accept_shared.remove(ctx_id)
  let drag_transfer_id = self.input_html_drag_transfer_id
    .get(ctx_id)
    .unwrap_or("")
  if drag_transfer_id != "" {
    input_clear_drag_transfer(drag_transfer_id)
  }
  self.input_html_drag_transfer_id.remove(ctx_id)
  self.input_last_click_time.remove(ctx_id)
  self.input_last_click_x.remove(ctx_id)
  self.input_last_click_y.remove(ctx_id)
  self.input_last_click_target_shared.remove(ctx_id)
  self.input_pending_double_click.remove(ctx_id)
  self.input_action_clock_ms.remove(ctx_id)
  self.input_synthetic_events_by_context.remove(ctx_id)
  self.context_synthetic_scrolled.remove(ctx_id)
}

///|
/// Remove all descendant browsing contexts under a parent context.
fn BidiProtocol::drop_child_contexts(
  self : BidiProtocol,
  parent_ctx_id : String,
  emit_destroy_events : Bool,
) -> Unit {
  match self.context_children.get(parent_ctx_id) {
    Some(children) => {
      for child_ctx_id in children {
        let _ = self.fail_in_flight_navigation(
          child_ctx_id, "failed", "Navigation failed: context was destroyed",
        )
        if emit_destroy_events {
          let original_opener = self.context_original_opener.get(child_ctx_id)
          self.emit_context_destroyed(child_ctx_id, original_opener)
        }
        self.drop_child_contexts(child_ctx_id, false)
        self.manager.close_session(child_ctx_id) |> ignore
        self.context_parent.remove(child_ctx_id)
        self.context_children.remove(child_ctx_id)
        self.context_had_synthetic_child.remove(child_ctx_id)
        self.context_user_context.remove(child_ctx_id)
        self.context_has_beforeunload.remove(child_ctx_id)
        self.context_blocks_cross_origin_iframe_navigation.remove(child_ctx_id)
        self.clear_pending_prompt_state(child_ctx_id)
        self.clear_pending_navigation_state(child_ctx_id)
        self.clear_network_state_for_context(child_ctx_id)
        self.context_local_storage.remove(child_ctx_id)
        self.remove_storage_cookie_scope(child_ctx_id)
        self.context_last_started_navigation.remove(child_ctx_id)
        self.context_requested_navigation_url.remove(child_ctx_id)
        self.clear_synthetic_location_href(child_ctx_id)
        self.context_original_opener.remove(child_ctx_id)
        self.remove_all_realms_for_context(child_ctx_id)
        self.context_client_window.remove(child_ctx_id)
        self.context_viewport_width.remove(child_ctx_id)
        self.context_viewport_height.remove(child_ctx_id)
        self.context_device_pixel_ratio.remove(child_ctx_id)
        self.subscription_state.remove_pending_log_entries(child_ctx_id)
        self.clear_input_state_for_context(child_ctx_id)
      }
      self.context_children[parent_ctx_id] = []
    }
    None => ()
  }
}

///|
/// Close a context and release all related state.
fn BidiProtocol::close_context_and_cleanup(
  self : BidiProtocol,
  ctx_id : String,
  emit_destroy_event : Bool,
) -> Bool {
  if !self.manager.has_session(ctx_id) {
    return false
  }
  let _ = self.fail_in_flight_navigation(
    ctx_id, "failed", "Navigation failed: context was destroyed",
  )
  if emit_destroy_event {
    let original_opener = self.context_original_opener.get(ctx_id)
    self.emit_context_destroyed(ctx_id, original_opener)
  }
  self.drop_child_contexts(ctx_id, false)
  self.unlink_from_parent(ctx_id)
  self.manager.close_session(ctx_id) |> ignore
  self.context_parent.remove(ctx_id)
  self.context_children.remove(ctx_id)
  self.context_had_synthetic_child.remove(ctx_id)
  self.context_user_context.remove(ctx_id)
  self.context_has_beforeunload.remove(ctx_id)
  self.context_blocks_cross_origin_iframe_navigation.remove(ctx_id)
  self.clear_pending_prompt_state(ctx_id)
  self.clear_pending_navigation_state(ctx_id)
  self.clear_network_state_for_context(ctx_id)
  self.context_local_storage.remove(ctx_id)
  self.remove_storage_cookie_scope(ctx_id)
  self.context_last_started_navigation.remove(ctx_id)
  self.context_requested_navigation_url.remove(ctx_id)
  self.clear_synthetic_location_href(ctx_id)
  self.context_original_opener.remove(ctx_id)
  self.remove_all_realms_for_context(ctx_id)
  self.context_client_window.remove(ctx_id)
  self.context_viewport_width.remove(ctx_id)
  self.context_viewport_height.remove(ctx_id)
  self.context_device_pixel_ratio.remove(ctx_id)
  self.subscription_state.remove_pending_log_entries(ctx_id)
  self.clear_input_state_for_context(ctx_id)
  self.emulation_state.session_profiles.remove(ctx_id)
  match self.active_context_id {
    Some(active_ctx) =>
      if active_ctx == ctx_id {
        self.active_context_id = None
      }
    None => ()
  }
  match self.default_context_id {
    Some(default_ctx) =>
      if default_ctx == ctx_id {
        self.default_context_id = None
      }
    None => ()
  }
  true
}

///|
/// Close a context without sending a command response (used by synthetic events).
fn BidiProtocol::force_close_context_from_input(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  self.close_context_and_cleanup(ctx_id, true)
}
