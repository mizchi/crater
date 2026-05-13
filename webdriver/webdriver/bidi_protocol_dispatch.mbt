///|
/// Parse method into (domain, action)
fn split_method(method_name : String) -> (String, String)? {
  let domain = StringBuilder::new()
  let action = StringBuilder::new()
  let mut in_action = false
  for c in method_name.iter() {
    if c == '.' && !in_action {
      in_action = true
    } else if in_action {
      action.write_char(c)
    } else {
      domain.write_char(c)
    }
  }
  let d = domain.to_string()
  let a = action.to_string()
  if d.length() == 0 || a.length() == 0 {
    None
  } else {
    Some((d, a))
  }
}

// =============================================================================
// Dispatch
// =============================================================================

///|
/// Dispatch request to method handler
fn BidiProtocol::dispatch(
  self : BidiProtocol,
  request : BidiRequest,
) -> Result[Unit, String] {
  self.flush_expired_pending_navigation_requests()
  let parts = split_method(request.method_name)
  let (domain, action) = match parts {
    Some(p) => p
    None => return Err("Invalid method format")
  }
  match domain {
    "session" => self.dispatch_session(request, action)
    "browser" => self.dispatch_browser(request, action)
    "browsingContext" => self.dispatch_browsing_context(request, action)
    "script" => self.dispatch_script(request, action)
    "input" => self.dispatch_input(request, action)
    "network" => self.dispatch_network(request, action)
    "emulation" => self.dispatch_emulation(request, action)
    "bluetooth" => self.dispatch_bluetooth(request, action)
    "permissions" => self.dispatch_permissions(request, action)
    "storage" => self.dispatch_storage(request, action)
    "webExtension" => self.dispatch_web_extension(request, action)
    "log" => self.dispatch_log(request, action)
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown method: " + request.method_name,
      )
      Ok(())
    }
  }
}

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

///|
/// Dispatch browser domain
fn BidiProtocol::dispatch_browser(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "getUserContexts" => {
      let contexts = self.resolve_browser_user_contexts_list()
      let result = make_object({ "userContexts": Json::array(contexts) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "getUserContextsList" => {
      let contexts = self.resolve_browser_user_contexts_list()
      self.send_success(request.id, Some(Json::array(contexts)))
      Ok(())
    }
    "hasUserContext" => {
      self.handle_browser_has_user_context(request.id, request.params)
      Ok(())
    }
    "hasUserContextValue" => {
      self.handle_browser_has_user_context_value(request.id, request.params)
      Ok(())
    }
    "getClientWindows" => {
      let windows = self.resolve_browser_client_windows_list()
      let result = make_object({ "clientWindows": Json::array(windows) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "getClientWindowsList" => {
      let windows = self.resolve_browser_client_windows_list()
      self.send_success(request.id, Some(Json::array(windows)))
      Ok(())
    }
    "createUserContext" =>
      match
        self.resolve_browser_create_user_context(request.id, request.params) {
        Some(id) => {
          let result = make_object({ "userContext": Json::string(id) })
          self.send_success(request.id, Some(result))
          Ok(())
        }
        None => Ok(())
      }
    "createUserContextId" => {
      match
        self.resolve_browser_create_user_context(request.id, request.params) {
        Some(id) => self.send_success(request.id, Some(Json::string(id)))
        None => ()
      }
      Ok(())
    }
    "removeUserContext" =>
      match get_param_raw(request.params, "userContext") {
        Some(String(id)) =>
          if id == "default" {
            self.send_error(
              request.id,
              "invalid argument",
              "default user context cannot be removed",
            )
            Ok(())
          } else if !self.user_contexts.contains(id) {
            self.send_error(
              request.id,
              "no such user context",
              "Unknown user context: " + id,
            )
            Ok(())
          } else {
            let contexts_to_close : Array[String] = []
            for ctx_id, user_ctx in self.context_user_context {
              if user_ctx == id && !self.context_parent.contains(ctx_id) {
                contexts_to_close.push(ctx_id)
              }
            }
            for ctx_id in contexts_to_close {
              self.force_close_context_from_input(ctx_id) |> ignore
            }
            self.remove_storage_cookies_for_user_context(id)
            self.remove_permission_state_for_user_context(id)
            self.network_state.network_extra_headers_by_user_context.remove(id)
            self.user_contexts.remove(id)
            self.user_context_prompt_behavior.remove(id)
            self.user_context_download_behavior.remove(id)
            self.user_context_viewport_width.remove(id)
            self.user_context_viewport_height.remove(id)
            self.user_context_device_pixel_ratio.remove(id)
            self.send_success(request.id, Some(make_object({})))
            Ok(())
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "userContext must be a string",
          )
          Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing userContext")
          Ok(())
        }
      }
    "setDownloadBehavior" => {
      match
        self.validate_browser_set_download_behavior(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      let download_behavior : Json? = match
        get_param_raw(request.params, "downloadBehavior") {
        Some(Null) => None
        Some(Object(behavior)) => Some(make_object(behavior))
        _ => None
      }
      let target_user_contexts : Array[String] = []
      match
        get_param_raw_with_alias(
          request.params,
          "userContexts",
          "user_contexts",
        ) {
        Some(Array(user_contexts)) =>
          for user_context in user_contexts {
            match user_context {
              String(id) => target_user_contexts.push(id)
              _ => ()
            }
          }
        _ => ()
      }
      if target_user_contexts.length() > 0 {
        for user_context_id in target_user_contexts {
          match download_behavior {
            Some(behavior) =>
              self.user_context_download_behavior[user_context_id] = behavior
            None => self.user_context_download_behavior.remove(user_context_id)
          }
        }
      } else {
        self.global_download_behavior = download_behavior
      }
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "close" => {
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown browser method: " + action,
      )
      Ok(())
    }
  }
}

///|
/// Dispatch browsingContext domain
fn BidiProtocol::dispatch_browsing_context(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "createSyntheticChildContext" => {
      self.handle_browsing_context_create_synthetic_child_context(
        request.id,
        request.params,
      )
      Ok(())
    }
    "createAndGetInfo" => {
      self.handle_browsing_context_create_and_get_info(
        request.id,
        request.params,
      )
      Ok(())
    }
    "createAndGetInfoValue" => {
      self.handle_browsing_context_create_and_get_info_value(
        request.id,
        request.params,
      )
      Ok(())
    }
    "createContextId" => {
      self.handle_browsing_context_create_context_id(request.id, request.params)
      Ok(())
    }
    "getContextScopeInfo" => {
      self.handle_browsing_context_get_context_scope_info(
        request.id,
        request.params,
      )
      Ok(())
    }
    "isKnownContext" => {
      self.handle_browsing_context_is_known_context(request.id, request.params)
      Ok(())
    }
    "getRequestedNavigationUrl" => {
      self.handle_browsing_context_get_requested_navigation_url(
        request.id,
        request.params,
      )
      Ok(())
    }
    "getContextInfo" => {
      self.handle_browsing_context_get_context_info(request.id, request.params)
      Ok(())
    }
    "getTreeContexts" => {
      self.handle_browsing_context_get_tree_contexts(request.id, request.params)
      Ok(())
    }
    "getCurrentUrl" => {
      self.handle_browsing_context_get_current_url(request.id, request.params)
      Ok(())
    }
    "getCurrentUrlValue" => {
      self.handle_browsing_context_get_current_url_value(
        request.id,
        request.params,
      )
      Ok(())
    }
    "closeWithState" => {
      self.handle_browsing_context_close_with_state(request.id, request.params)
      Ok(())
    }
    "closeResult" => {
      self.handle_browsing_context_close_result(request.id, request.params)
      Ok(())
    }
    "prepareNavigate" => {
      self.handle_browsing_context_prepare_navigate(request.id, request.params)
      Ok(())
    }
    "navigateWithState" => {
      self.handle_browsing_context_navigate_with_state(
        request.id,
        request.params,
      )
      Ok(())
    }
    "finalizeNavigate" => {
      self.handle_browsing_context_finalize_navigate(request.id, request.params)
      Ok(())
    }
    "finalizeReload" => {
      self.handle_browsing_context_finalize_reload(request.id, request.params)
      Ok(())
    }
    "reloadWithState" => {
      self.handle_browsing_context_reload_with_state(request.id, request.params)
      Ok(())
    }
    "getCloseMetadata" => {
      self.handle_browsing_context_get_close_metadata(
        request.id,
        request.params,
      )
      Ok(())
    }
    "getTree" =>
      match self.resolve_get_tree_contexts(request.id, request.params) {
        Some(contexts) => {
          let result = make_object({ "contexts": Json::array(contexts) })
          self.send_success(request.id, Some(result))
          Ok(())
        }
        None => Ok(())
      }
    "create" => {
      match
        self.create_top_level_context_from_params(request.id, request.params) {
        Some(ctx_id) =>
          self.send_success(
            request.id,
            Some(make_object({ "context": Json::string(ctx_id) })),
          )
        None => ()
      }
      Ok(())
    }
    "navigate" => {
      let ctx_id = match get_param_raw(request.params, "context") {
        Some(String(value)) => value
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "context must be a string",
          )
          return Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing context/url")
          return Ok(())
        }
      }
      let url = match get_param_raw(request.params, "url") {
        Some(String(value)) => value
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "url must be a string",
          )
          return Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing context/url")
          return Ok(())
        }
      }
      let wait_mode = match get_param_raw(request.params, "wait") {
        Some(String(value)) =>
          if value == "none" || value == "interactive" || value == "complete" {
            value
          } else {
            self.send_error(
              request.id,
              "invalid argument",
              "wait must be one of none, interactive, or complete",
            )
            return Ok(())
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "wait must be a string",
          )
          return Ok(())
        }
        None => "none"
      }
      if !self.manager.has_session(ctx_id) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return Ok(())
      }
      let resolved_url = self.resolve_effective_navigation_target_url(
        ctx_id, url,
      )
      self.input_synthetic_events_by_context.remove(ctx_id)
      self.context_synthetic_scrolled.remove(ctx_id)
      self.clear_synthetic_location_href(ctx_id)
      let _ = self.fail_in_flight_navigation(
        ctx_id, "aborted", "Navigation interrupted by another navigation",
      )
      if !is_valid_navigation_target_url(resolved_url) {
        self.send_error(request.id, "invalid argument", "url is invalid")
        return Ok(())
      }
      if self.navigation_blocked_by_network_conditions(ctx_id, resolved_url) {
        let nav_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
        self.send_error(
          request.id,
          "unknown error",
          "Navigation failed: network offline",
        )
        return Ok(())
      }
      if should_fail_navigation_with_unknown_error(resolved_url) {
        let nav_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
        self.send_error(
          request.id,
          "unknown error",
          "Navigation failed: navigation target is unreachable",
        )
        return Ok(())
      }
      if self.is_iframe_navigation_blocked(ctx_id, resolved_url) {
        let nav_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
        self.emit_navigation_failed_event(ctx_id, resolved_url, nav_id)
        self.send_error(
          request.id,
          "unknown error",
          "Navigation failed: blocked by embedding policy",
        )
        return Ok(())
      }
      match self.manager.get_session(ctx_id) {
        Some(session) =>
          if self.has_beforeunload_prompt_in_scope(ctx_id) {
            let handler = self.resolve_unhandled_prompt_handler(
              ctx_id, "beforeunload",
            )
            let nav_id = self.next_navigation_id.to_string()
            self.next_navigation_id += 1
            self.clear_pending_prompt_state(ctx_id)
            self.pending_prompt_type[ctx_id] = "beforeunload"
            self.pending_beforeunload_request[ctx_id] = request.id
            self.pending_beforeunload_url[ctx_id] = resolved_url
            self.pending_beforeunload_requested_url[ctx_id] = url
            self.pending_beforeunload_wait[ctx_id] = wait_mode
            self.pending_beforeunload_navigation[ctx_id] = nav_id
            self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
            self.emit_user_prompt_opened(
              ctx_id,
              "beforeunload",
              handler,
              "beforeunload",
              None,
            )
            Ok(())
          } else {
            let previous_url = session.get_url()
            match session.navigate_to(resolved_url) {
              Ok(_) => {
                self.remember_requested_navigation_url(ctx_id, url)
                if is_fragment_navigation(previous_url, resolved_url) {
                  self.complete_fragment_navigation_request(
                    request.id,
                    ctx_id,
                    resolved_url,
                  )
                } else {
                  self.complete_navigation_request_with_wait(
                    request.id,
                    ctx_id,
                    resolved_url,
                    wait_mode,
                  )
                }
                Ok(())
              }
              Err(e) => {
                let nav_id = self.next_navigation_id.to_string()
                self.next_navigation_id += 1
                self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
                self.send_error(
                  request.id,
                  "unknown error",
                  "Navigation failed: " + e.message,
                )
                Ok(())
              }
            }
          }
        None => {
          self.send_error(
            request.id,
            "no such frame",
            "Unknown context: " + ctx_id,
          )
          Ok(())
        }
      }
    }
    "reload" => {
      let ctx_id = match get_param_raw(request.params, "context") {
        Some(String(value)) => value
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "context must be a string",
          )
          return Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing context")
          return Ok(())
        }
      }
      let ignore_cache_raw = match
        get_param_raw(request.params, "ignoreCache") {
        Some(value) => Some(value)
        None => get_param_raw(request.params, "ignore_cache")
      }
      let _ignore_cache = match ignore_cache_raw {
        Some(True) => true
        Some(False) => false
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "ignoreCache must be a boolean",
          )
          return Ok(())
        }
        None => false
      }
      let wait_mode = match get_param_raw(request.params, "wait") {
        Some(String(value)) =>
          if value == "none" || value == "interactive" || value == "complete" {
            value
          } else {
            self.send_error(
              request.id,
              "invalid argument",
              "wait must be one of none, interactive, or complete",
            )
            return Ok(())
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "wait must be a string",
          )
          return Ok(())
        }
        None => "none"
      }
      if !self.manager.has_session(ctx_id) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return Ok(())
      }
      self.input_synthetic_events_by_context.remove(ctx_id)
      self.context_synthetic_scrolled.remove(ctx_id)
      self.clear_synthetic_location_href(ctx_id)
      let _ = self.fail_in_flight_navigation(
        ctx_id, "aborted", "Navigation interrupted by reload",
      )
      match self.manager.get_session(ctx_id) {
        Some(session) => {
          let url = session.get_url()
          if self.has_beforeunload_prompt_in_scope(ctx_id) {
            let handler = self.resolve_unhandled_prompt_handler(
              ctx_id, "beforeunload",
            )
            let nav_id = self.next_navigation_id.to_string()
            self.next_navigation_id += 1
            self.clear_pending_prompt_state(ctx_id)
            self.pending_prompt_type[ctx_id] = "beforeunload"
            self.pending_beforeunload_request[ctx_id] = request.id
            self.pending_beforeunload_url[ctx_id] = url
            self.pending_beforeunload_requested_url[ctx_id] = self.requested_navigation_url(
              ctx_id,
            )
            self.pending_beforeunload_wait[ctx_id] = wait_mode
            self.pending_beforeunload_navigation[ctx_id] = nav_id
            self.emit_navigation_started_event(ctx_id, url, nav_id)
            self.emit_user_prompt_opened(
              ctx_id,
              "beforeunload",
              handler,
              "beforeunload",
              None,
            )
            return Ok(())
          }
          self.complete_navigation_request_with_wait(
            request.id,
            ctx_id,
            url,
            wait_mode,
          )
          Ok(())
        }
        None => {
          self.send_error(
            request.id,
            "no such frame",
            "Unknown context: " + ctx_id,
          )
          Ok(())
        }
      }
    }
    "activate" =>
      match get_string_param(request.params, "context") {
        Some(ctx_id) =>
          if self.context_parent.contains(ctx_id) {
            self.send_error(
              request.id,
              "invalid argument",
              "context must be top-level",
            )
            Ok(())
          } else if self.manager.has_session(ctx_id) {
            self.active_context_id = Some(ctx_id)
            self.send_success(request.id, Some(make_object({})))
            Ok(())
          } else {
            self.send_error(
              request.id,
              "no such frame",
              "Unknown context: " + ctx_id,
            )
            Ok(())
          }
        None => {
          self.send_error(request.id, "invalid argument", "Missing context")
          Ok(())
        }
      }
    "close" =>
      match get_param_raw(request.params, "context") {
        Some(String(ctx_id)) => {
          let prompt_unload = match
            get_param_raw(request.params, "promptUnload") {
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
    "handleUserPrompt" =>
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
            Some(prompt_ctx_id) => {
              let prompt_type = self.pending_prompt_type
                .get(prompt_ctx_id)
                .unwrap_or("alert")
              let pending_close = self.pending_close_request.get(prompt_ctx_id)
              let pending_script_request = self.pending_prompt_request.get(
                prompt_ctx_id,
              )
              let pending_script_realm = self.pending_prompt_realm.get(
                prompt_ctx_id,
              )
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
              let pending_result_var = self.pending_prompt_result_var.get(
                prompt_ctx_id,
              )
              self.emit_user_prompt_closed(
                prompt_ctx_id, prompt_type, accepted, user_text,
              )
              match pending_close {
                Some(close_request_id) => {
                  let close_response_mode = self.pending_close_response_mode
                    .get(prompt_ctx_id)
                    .unwrap_or("wait")
                  if close_response_mode == "empty" {
                    self.close_context_and_cleanup(prompt_ctx_id, true)
                    |> ignore
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
                    self.close_context_and_cleanup(prompt_ctx_id, true)
                    |> ignore
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
                        match self.manager.get_session(prompt_ctx_id) {
                          Some(session) =>
                            match session.navigate_to(nav_url) {
                              Ok(_) => {
                                let requested_url = pending_beforeunload_requested_url.unwrap_or(
                                  nav_url,
                                )
                                self.remember_requested_navigation_url(
                                  prompt_ctx_id, requested_url,
                                )
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
                                      self.clear_pending_navigation_state(
                                        prompt_ctx_id,
                                      )
                                    } else if !completion.deferred_response {
                                      self.send_success(
                                        nav_request_id,
                                        Some(completion.result),
                                      )
                                    }
                                  }
                                  Some("navigateWithState") =>
                                    self.complete_navigate_with_state(
                                      nav_request_id, prompt_ctx_id, requested_url,
                                      nav_url, "", pending_beforeunload_wait, pending_navigation_id,
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
                                    self.emit_navigation_failed_event(
                                      prompt_ctx_id, nav_url, nav_id,
                                    )
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
                        eval_request_id, realm_id, prompt_type, accepted, user_text,
                        pending_prompt_unwrap_result,
                      )
                    }
                    None => ()
                  }
                  self.clear_pending_prompt_state(prompt_ctx_id)
                }
              }
              self.send_success(request.id, Some(make_object({})))
              Ok(())
            }
            None => {
              self.send_error(
                request.id,
                "no such alert",
                "No dialog is showing",
              )
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
    "captureScreenshot" => {
      self.handle_capture_screenshot(request)
      Ok(())
    }
    "captureScreenshotData" => {
      self.handle_capture_screenshot_data(request.id, request.params)
      Ok(())
    }
    "capturePaintData" => {
      self.handle_capture_paint_data(request.id, request.params)
      Ok(())
    }
    "capturePaintTree" => {
      self.handle_capture_paint_tree(request.id, request.params)
      Ok(())
    }
    "getResponsiveBreakpoints" => {
      self.handle_get_responsive_breakpoints(request.id, request.params)
      Ok(())
    }
    "getCssRuleViewportMap" => {
      self.handle_get_css_rule_viewport_map(request.id, request.params)
      Ok(())
    }
    "getCssRuleUsage" => {
      self.handle_get_css_rule_usage(request.id, request.params)
      Ok(())
    }
    "getRequiredTestViewports" => {
      self.handle_get_required_test_viewports(request.id, request.params)
      Ok(())
    }
    "batchRender" => {
      self.handle_batch_render(request.id, request.params)
      Ok(())
    }
    "getComputedStyles" => {
      self.handle_get_computed_styles(request.id, request.params)
      Ok(())
    }
    "getAllComputedStyles" => {
      self.handle_get_all_computed_styles(request.id, request.params)
      Ok(())
    }
    "getComputedStylesWithState" => {
      self.handle_get_computed_styles_with_state(request.id, request.params)
      Ok(())
    }
    "print" => {
      self.handle_print(request)
      Ok(())
    }
    "printData" => {
      self.handle_print_data(request.id, request.params)
      Ok(())
    }
    "locateNodes" => {
      self.handle_locate_nodes(request)
      Ok(())
    }
    "setViewport" => {
      self.handle_set_viewport(request)
      Ok(())
    }
    "traverseHistory" => {
      self.handle_traverse_history(request)
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown browsingContext method: " + action,
      )
      Ok(())
    }
  }
}

///|
/// Dispatch script domain
fn BidiProtocol::dispatch_script(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "rememberSyntheticLocationHref" => {
      self.handle_script_remember_synthetic_location_href(
        request.id,
        request.params,
      )
      Ok(())
    }
    "clearSyntheticLocationHref" => {
      self.handle_script_clear_synthetic_location_href(
        request.id,
        request.params,
      )
      Ok(())
    }
    "evaluate" => {
      self.handle_script_evaluate(request, false)
      Ok(())
    }
    "evaluateResult" => {
      self.handle_script_evaluate(request, true)
      Ok(())
    }
    "callFunction" => {
      self.handle_script_call_function(request, false)
      Ok(())
    }
    "callFunctionResult" => {
      self.handle_script_call_function(request, true)
      Ok(())
    }
    "getElementForTest" => {
      self.handle_script_get_element_for_test(request.id, request.params)
      Ok(())
    }
    "createIframeContextForTest" => {
      self.handle_script_create_iframe_context_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    "createIframeContextIdForTest" => {
      self.handle_script_create_iframe_context_id_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    "prepareLoadedStaticTestPage" => {
      self.handle_script_prepare_loaded_static_test_page(
        request.id,
        request.params,
      )
      Ok(())
    }
    "loadStaticTestPageForTest" => {
      self.handle_script_load_static_test_page_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    "setupBeforeunloadPageForTest" => {
      self.handle_script_setup_beforeunload_page_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    "prepareBeforeunloadPageForTest" => {
      self.handle_script_prepare_beforeunload_page_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    "prepareBeforeunloadPageUrlForTest" => {
      self.handle_script_prepare_beforeunload_page_url_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    "syncDocumentCookiesForTest" => {
      self.handle_script_sync_document_cookies_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    "fetchForTest" => {
      self.handle_script_fetch_for_test(request.id, request.params)
      Ok(())
    }
    "fetchFromContextForTest" => {
      self.handle_script_fetch_from_context_for_test(request.id, request.params)
      Ok(())
    }
    "disown" => {
      match self.validate_script_target(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      let raw_handles = match get_param_raw(request.params, "handles") {
        Some(Array(handles)) => handles
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "handles must be an array",
          )
          return Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing handles")
          return Ok(())
        }
      }
      let handles : Array[String] = []
      for raw_handle in raw_handles {
        match raw_handle {
          String(handle_id) => handles.push(handle_id)
          _ => {
            self.send_error(
              request.id,
              "invalid argument",
              "handles entries must be strings",
            )
            return Ok(())
          }
        }
      }
      let (ctx_id_disown, realm_id_disown) = self.resolve_target_context_realm(
        request.params,
      )
      let runtime_ctx_id_disown = resolve_runtime_context_id(
        request.params,
        ctx_id_disown,
        realm_id_disown,
        self.realm_sandbox.get(realm_id_disown) != None,
      )
      set_runtime_context(runtime_ctx_id_disown)
      self.apply_effective_viewport_to_runtime_context(
        runtime_ctx_id_disown, ctx_id_disown,
      )
      for handle_id in handles {
        delete_runtime_handle(handle_id)
      }
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "addPreloadScript" =>
      match self.parse_add_preload_script_params(request.id, request.params) {
        Some(parsed) => {
          let script_id = self.register_preload_script(parsed)
          let result = make_object({ "script": Json::string(script_id) })
          self.send_success(request.id, Some(result))
          Ok(())
        }
        None => Ok(())
      }
    "addPreloadScriptId" =>
      match self.parse_add_preload_script_params(request.id, request.params) {
        Some(parsed) => {
          let script_id = self.register_preload_script(parsed)
          self.send_success(request.id, Some(Json::string(script_id)))
          Ok(())
        }
        None => Ok(())
      }
    "removePreloadScript" => {
      let script_id = match get_param_raw(request.params, "script") {
        Some(String(script_id)) => script_id
        Some(Object(map)) =>
          match map.get("script") {
            Some(String(script_id)) => script_id
            _ => {
              self.send_error(
                request.id,
                "invalid argument",
                "script must be a string",
              )
              return Ok(())
            }
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "script must be a string",
          )
          return Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing script")
          return Ok(())
        }
      }
      let remaining_entries : Array[PreloadScriptEntry] = []
      let mut removed = false
      let mut removed_entry : PreloadScriptEntry? = None
      for entry in self.preload_scripts {
        if !removed && entry.script_id == script_id {
          removed = true
          removed_entry = Some(entry)
        } else {
          remaining_entries.push(entry)
        }
      }
      if !removed {
        self.send_error(
          request.id,
          "no such script",
          "Unknown preload script: " + script_id,
        )
        return Ok(())
      }
      self.preload_scripts = remaining_entries
      match removed_entry {
        Some(entry) => self.cleanup_removed_preload_entry(entry)
        None => ()
      }
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "removeAllPreloadScripts" => {
      self.remove_all_preload_scripts()
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "getRealms" =>
      match self.resolve_realms_list(request.id, request.params) {
        Some(realms) => {
          let result = make_object({ "realms": Json::array(realms) })
          self.send_success(request.id, Some(result))
          Ok(())
        }
        None => Ok(())
      }
    "getRealmsList" =>
      match self.resolve_realms_list(request.id, request.params) {
        Some(realms) => {
          self.send_success(request.id, Some(Json::array(realms)))
          Ok(())
        }
        None => Ok(())
      }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown script method: " + action,
      )
      Ok(())
    }
  }
}

///|
/// Dispatch input domain (partial implementation for automation primitives)
fn BidiProtocol::dispatch_input(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "performActions" =>
      if self.handle_input_perform_actions(request.id, request.params) {
        self.send_success(request.id, Some(make_object({})))
        Ok(())
      } else {
        Ok(())
      }
    "releaseActions" =>
      if self.handle_input_release_actions(request.id, request.params) {
        self.send_success(request.id, Some(make_object({})))
        Ok(())
      } else {
        Ok(())
      }
    "recordSyntheticEvents" => {
      self.handle_input_record_synthetic_events(request.id, request.params)
      Ok(())
    }
    "setFiles" => {
      self.handle_input_set_files(request.id, request.params)
      Ok(())
    }
    "isFileDialogCanceledForTest" => {
      self.handle_input_is_file_dialog_canceled_for_test(
        request.id,
        request.params,
      )
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown input method: " + action,
      )
      Ok(())
    }
  }
}

///|
/// Dispatch log domain (event-only, no commands)
fn BidiProtocol::dispatch_log(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  // Log module has no commands - it's event-driven via log.entryAdded
  self.send_error(
    request.id,
    "unknown command",
    "Unknown log method: " + action,
  )
  Ok(())
}
