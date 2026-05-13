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
    "navigate" => self.handle_browsing_context_navigate(request)
    "reload" => self.handle_browsing_context_reload(request)
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
    "close" => self.handle_browsing_context_close(request)
    "handleUserPrompt" => self.handle_browsing_context_user_prompt(request)
    _ =>
      if self.dispatch_browsing_context_rendering(request, action) {
        Ok(())
      } else {
        self.send_error(
          request.id,
          "unknown command",
          "Unknown browsingContext method: " + action,
        )
        Ok(())
      }
  }
}
