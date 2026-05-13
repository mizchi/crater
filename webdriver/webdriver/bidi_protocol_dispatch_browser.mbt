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
