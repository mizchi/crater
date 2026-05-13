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
      self.handle_script_disown(request.id, request.params)
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
      self.handle_script_remove_preload_script(request.id, request.params)
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
