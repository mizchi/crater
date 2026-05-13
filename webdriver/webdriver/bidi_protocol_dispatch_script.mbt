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
