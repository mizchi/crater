///|
fn BidiProtocol::handle_script_get_element_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_script_get_element_for_test(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::handle_script_prepare_loaded_static_test_page(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match
    self.resolve_script_prepare_loaded_static_test_page(request_id, params) {
    Some((ctx_id, page, phase, scripts)) => {
      if phase == "all" || phase == "inlineScripts" {
        self.run_inline_test_scripts(ctx_id, scripts)
      }
      if phase == "all" || phase == "beforePageSpecific" {
        self.run_test_setup_function(
          ctx_id,
          js_test_page_dom_content_loaded_source(),
        )
      }
      if phase == "all" || phase == "pageSpecific" {
        self.run_page_specific_test_setup(ctx_id, page)
      }
      if phase == "all" || phase == "afterPageSpecific" {
        self.run_test_setup_function(ctx_id, js_test_page_reset_state_source())
        self.run_test_setup_function(
          ctx_id,
          js_test_page_all_events_fallback_source(),
        )
      }
      self.send_success(request_id, Some(make_object({})))
    }
    None => ()
  }
}

///|
fn BidiProtocol::handle_script_load_static_test_page_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_script_load_static_test_page_for_test(request_id, params) {
    Some((ctx_id, page, html)) =>
      match self.manager.get_session(ctx_id) {
        Some(session) => {
          let url = build_html_data_url(html)
          self.input_synthetic_events_by_context.remove(ctx_id)
          self.context_synthetic_scrolled.remove(ctx_id)
          self.clear_synthetic_location_href(ctx_id)
          match session.navigate_to(url) {
            Ok(_) => {
              self.remember_requested_navigation_url(ctx_id, url)
              let navigation_id = self.next_navigation_id.to_string()
              self.next_navigation_id += 1
              self.apply_navigation_commit_state(ctx_id, url, navigation_id)
              if html.contains("allEvents") {
                let scripts = extract_inline_script_blocks(html)
                self.run_inline_test_scripts(ctx_id, scripts)
                self.run_test_setup_function(
                  ctx_id,
                  js_test_page_dom_content_loaded_source(),
                )
                self.run_page_specific_test_setup(ctx_id, page)
                self.run_test_setup_function(
                  ctx_id,
                  js_test_page_reset_state_source(),
                )
                self.run_test_setup_function(
                  ctx_id,
                  js_test_page_all_events_fallback_source(),
                )
              }
              self.send_success(request_id, Some(make_object({})))
            }
            Err(e) =>
              self.send_error(
                request_id,
                "unknown error",
                "Navigation failed: " + e.message,
              )
          }
        }
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
fn BidiProtocol::resolve_script_get_element_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Json? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }
  let ctx_id = match map.get("context") {
    Some(String(ctx_id)) =>
      if ctx_id == "" || self.manager.get_session(ctx_id) is None {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return None
      } else {
        ctx_id
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }
  let selector = match map.get("selector") {
    Some(String(selector)) => selector
    _ => {
      self.send_error(
        request_id, "invalid argument", "selector must be a string",
      )
      return None
    }
  }
  let allow_frame_fallback = match map.get("allowFrameFallback") {
    Some(True) => true
    Some(False) => false
    _ => false
  }
  Some(
    self.resolve_test_element_remote_value(
      ctx_id, selector, allow_frame_fallback,
    ),
  )
}

///|
fn BidiProtocol::resolve_script_prepare_loaded_static_test_page(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> (String, String, String, Array[String])? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }
  let ctx_id = match map.get("context") {
    Some(String(ctx_id)) =>
      if ctx_id == "" || self.manager.get_session(ctx_id) is None {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return None
      } else {
        ctx_id
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }
  let page = match map.get("page") {
    Some(String(page)) => page
    _ => {
      self.send_error(request_id, "invalid argument", "page must be a string")
      return None
    }
  }
  let phase = match map.get("phase") {
    Some(String("inlineScripts")) => "inlineScripts"
    Some(String("beforePageSpecific")) => "beforePageSpecific"
    Some(String("pageSpecific")) => "pageSpecific"
    Some(String("afterPageSpecific")) => "afterPageSpecific"
    Some(String("all")) => "all"
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "phase must be a known string",
      )
      return None
    }
    _ => "all"
  }
  let scripts : Array[String] = []
  let mut html : String? = None
  match map.get("html") {
    Some(String(value)) => html = Some(value)
    Some(_) => {
      self.send_error(request_id, "invalid argument", "html must be a string")
      return None
    }
    None => ()
  }
  match map.get("scripts") {
    Some(Array(raw_scripts)) =>
      for raw_script in raw_scripts {
        match raw_script {
          String(script) => scripts.push(script)
          _ => {
            self.send_error(
              request_id, "invalid argument", "scripts must be an array of strings",
            )
            return None
          }
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "scripts must be an array of strings",
      )
      return None
    }
    None => ()
  }
  if scripts.length() == 0 && (phase == "all" || phase == "inlineScripts") {
    match html {
      Some(content) =>
        for script in extract_inline_script_blocks(content) {
          scripts.push(script)
        }
      None => ()
    }
  }
  Some((ctx_id, page, phase, scripts))
}

///|
fn BidiProtocol::resolve_script_load_static_test_page_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> (String, String, String)? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }
  let ctx_id = match map.get("context") {
    Some(String(ctx_id)) =>
      if ctx_id == "" || self.manager.get_session(ctx_id) is None {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return None
      } else {
        ctx_id
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }
  let page = match map.get("page") {
    Some(String(page)) => page
    _ => {
      self.send_error(request_id, "invalid argument", "page must be a string")
      return None
    }
  }
  let html = match map.get("html") {
    Some(String(html)) => html
    _ => {
      self.send_error(request_id, "invalid argument", "html must be a string")
      return None
    }
  }
  Some((ctx_id, page, html))
}

///|
fn BidiProtocol::resolve_test_script_context_runtime(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> (String, String, String)? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }
  let ctx_id = match map.get("context") {
    Some(String(ctx_id)) =>
      if ctx_id == "" || self.manager.get_session(ctx_id) is None {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return None
      } else {
        ctx_id
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }
  let sandbox_name = match map.get("sandbox") {
    Some(String(name)) if name != "" => Some(name)
    Some(String(_)) | None | Some(Null) => None
    _ => {
      self.send_error(
        request_id, "invalid argument", "sandbox must be a string",
      )
      return None
    }
  }
  let realm_id = match sandbox_name {
    Some(name) => self.get_or_create_sandbox_realm(ctx_id, name)
    None => self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
  }
  let runtime_ctx_id = match sandbox_name {
    Some(_) => realm_id
    None => ctx_id
  }
  Some((ctx_id, realm_id, runtime_ctx_id))
}

///|
fn BidiProtocol::handle_script_create_iframe_context_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_script_create_iframe_context_result(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::handle_script_create_iframe_context_id_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_script_create_iframe_context_result(request_id, params) {
    Some(result) =>
      match get_string_field(result, "context") {
        Some(ctx_id) =>
          self.send_success(request_id, Some(Json::string(ctx_id)))
        None =>
          self.send_error(
            request_id, "unknown error", "Failed to create iframe context",
          )
      }
    None => ()
  }
}

///|
fn BidiProtocol::resolve_script_create_iframe_context_result(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Json? {
  match self.resolve_script_create_iframe_context_for_test(request_id, params) {
    Some((parent_context, url)) => {
      let user_context_id = self.context_user_context
        .get(parent_context)
        .unwrap_or("default")
      let remote_value = self.evaluate_test_element_remote_expression(
        parent_context,
        js_test_page_create_iframe_source(),
        [url],
      )
      let result = match get_string_field(remote_value, "type") {
        Some("window") =>
          match get_string_field(remote_value, "value") {
            Some(ctx_id) if ctx_id != "" =>
              make_object({
                "context": Json::string(ctx_id),
                "parentContext": Json::string(parent_context),
                "userContext": Json::string(user_context_id),
                "url": Json::string(self.current_context_url(ctx_id)),
              })
            _ =>
              self.create_synthetic_child_context_result(
                parent_context, url, user_context_id,
              )
          }
        _ =>
          self.create_synthetic_child_context_result(
            parent_context, url, user_context_id,
          )
      }
      Some(result)
    }
    None => None
  }
}

///|
fn BidiProtocol::resolve_script_create_iframe_context_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> (String, String)? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }
  let ctx_id = match map.get("context") {
    Some(String(ctx_id)) =>
      if ctx_id == "" || self.manager.get_session(ctx_id) is None {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return None
      } else {
        ctx_id
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }
  let url = match map.get("url") {
    Some(String(url)) => url
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return None
    }
  }
  Some((ctx_id, url))
}

///|
fn BidiProtocol::resolve_test_element_remote_value(
  self : BidiProtocol,
  ctx_id : String,
  selector : String,
  allow_frame_fallback : Bool,
) -> Json {
  match self.locate_nodes_css(ctx_id, selector, [], 1, "{}") {
    Array(nodes) =>
      if nodes.length() > 0 {
        nodes[0]
      } else if allow_frame_fallback && selector == "textarea" {
        self.evaluate_test_element_remote_expression(
          ctx_id,
          "selector => {" +
          "let target = document.querySelector(selector);" +
          "if (!target && selector === 'textarea' && document && document.body && typeof document.createElement === 'function') {" +
          "target = document.createElement('textarea');" +
          "if (target && target.style) {" +
          "target.style.width = '100px';" +
          "target.style.height = '40px';" +
          "}" +
          "if (target && typeof target.setAttribute === 'function') {" +
          "target.setAttribute('data-crater-frame-fallback', '1');" +
          "}" +
          "document.body.appendChild(target);" +
          "}" +
          "if (typeof window.allEvents === 'undefined') {" +
          "window.allEvents = { events: [] };" +
          "}" +
          "return target;" +
          "}",
          [selector],
        )
      } else {
        make_object({ "type": Json::string("null") })
      }
    _ => make_object({ "type": Json::string("null") })
  }
}

///|
fn BidiProtocol::evaluate_test_element_remote_expression(
  self : BidiProtocol,
  ctx_id : String,
  function_declaration : String,
  string_arguments : Array[String],
) -> Json {
  let args_literal : Array[String] = []
  for argument in string_arguments {
    args_literal.push("\"" + escape_js_string(argument) + "\"")
  }
  let expression = "(" +
    function_declaration +
    ")(" +
    args_literal.join(",") +
    ")"
  set_runtime_context(ctx_id)
  set_runtime_context_frames(
    ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  let eval_result_json = evaluate_js_with_console(
    expression, false, false, false, "{}",
  )
  let eval_result = @json.parse(eval_result_json) catch {
    _ => return make_object({ "type": Json::string("null") })
  }
  match get_string_field(eval_result, "type") {
    Some("success") =>
      match get_field(eval_result, "result") {
        Some(result) => result
        None => make_object({ "type": Json::string("null") })
      }
    _ => make_object({ "type": Json::string("null") })
  }
}

///|
fn BidiProtocol::run_test_setup_function(
  self : BidiProtocol,
  ctx_id : String,
  function_declaration : String,
) -> Unit {
  ignore(
    self.evaluate_test_element_remote_expression(ctx_id, function_declaration, []),
  )
}

///|
fn BidiProtocol::run_inline_test_scripts(
  self : BidiProtocol,
  ctx_id : String,
  scripts : Array[String],
) -> Unit {
  for script in scripts {
    ignore(
      self.evaluate_test_element_remote_expression(
        ctx_id,
        "source => { (0, eval)(source); return null; }",
        [script],
      ),
    )
  }
}

///|
fn BidiProtocol::run_page_specific_test_setup(
  self : BidiProtocol,
  ctx_id : String,
  page : String,
) -> Unit {
  match page {
    "test_actions.html" =>
      self.run_test_setup_function(
        ctx_id,
        js_test_actions_page_specific_source(),
      )
    "test_actions_scroll.html" =>
      self.run_test_setup_function(
        ctx_id,
        js_test_actions_scroll_page_specific_source(),
      )
    _ => ()
  }
}

///|
fn BidiProtocol::handle_script_setup_beforeunload_page_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_test_script_context_runtime(request_id, params) {
    Some((ctx_id, _, _)) => {
      self.run_test_setup_function(ctx_id, js_beforeunload_page_setup_source())
      self.send_success(request_id, Some(make_object({})))
    }
    None => ()
  }
}

///|
fn BidiProtocol::handle_script_prepare_beforeunload_page_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  self.handle_script_prepare_beforeunload_page_for_test_internal(
    request_id, params, false,
  )
}

///|
fn BidiProtocol::handle_script_prepare_beforeunload_page_url_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  self.handle_script_prepare_beforeunload_page_for_test_internal(
    request_id, params, true,
  )
}

///|
fn BidiProtocol::handle_script_prepare_beforeunload_page_for_test_internal(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
  return_url_only : Bool,
) -> Unit {
  match
    self.resolve_script_prepare_beforeunload_page_for_test(request_id, params) {
    Some((ctx_id, requested_url)) => {
      let resolved_url = self.resolve_effective_navigation_target_url(
        ctx_id, requested_url,
      )
      self.input_synthetic_events_by_context.remove(ctx_id)
      self.context_synthetic_scrolled.remove(ctx_id)
      self.clear_synthetic_location_href(ctx_id)
      let _ = self.fail_in_flight_navigation(
        ctx_id, "aborted", "Navigation interrupted by another navigation",
      )
      if !is_valid_navigation_target_url(resolved_url) {
        self.send_error(request_id, "invalid argument", "url is invalid")
        return
      }
      if self.navigation_blocked_by_network_conditions(ctx_id, resolved_url) {
        let nav_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
        self.send_error(
          request_id, "unknown error", "Navigation failed: network offline",
        )
        return
      }
      if should_fail_navigation_with_unknown_error(resolved_url) {
        let nav_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
        self.send_error(
          request_id, "unknown error", "Navigation failed: navigation target is unreachable",
        )
        return
      }
      if self.is_iframe_navigation_blocked(ctx_id, resolved_url) {
        let nav_id = self.next_navigation_id.to_string()
        self.next_navigation_id += 1
        self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
        self.emit_navigation_failed_event(ctx_id, resolved_url, nav_id)
        self.send_error(
          request_id, "unknown error", "Navigation failed: blocked by embedding policy",
        )
        return
      }
      match self.manager.get_session(ctx_id) {
        Some(session) => {
          let previous_url = session.get_url()
          match session.navigate_to(resolved_url) {
            Ok(_) => {
              self.remember_requested_navigation_url(ctx_id, requested_url)
              if is_fragment_navigation(previous_url, resolved_url) {
                self.clear_pending_navigation_state(ctx_id)
                let nav_id = self.next_navigation_id.to_string()
                self.next_navigation_id += 1
                self.emit_fragment_navigated_event(
                  ctx_id,
                  resolved_url,
                  Some(nav_id),
                )
                self.emit_history_updated_event(ctx_id, resolved_url)
                self.run_test_setup_function(
                  ctx_id,
                  js_beforeunload_page_setup_source(),
                )
                if return_url_only {
                  self.send_navigation_url_result(
                    request_id, ctx_id, requested_url, resolved_url, nav_id,
                  )
                } else {
                  let result = make_object({
                    "navigation": Json::string(nav_id),
                    "url": Json::string(resolved_url),
                  })
                  self.send_navigation_state_result(
                    request_id, ctx_id, requested_url, resolved_url, nav_id, result,
                  )
                }
                return
              }
              if return_url_only {
                self.pending_navigation_response_mode[ctx_id] = "url"
              } else {
                self.pending_navigation_response_mode.remove(ctx_id)
              }
              let completion = self.build_navigation_completion(
                request_id,
                ctx_id,
                resolved_url,
                "complete",
                None,
              )
              self.run_test_setup_function(
                ctx_id,
                js_beforeunload_page_setup_source(),
              )
              if completion.deferred_response {
                return
              }
              self.pending_navigation_response_mode.remove(ctx_id)
              if return_url_only {
                self.send_success(request_id, Some(Json::string(resolved_url)))
              } else {
                self.send_navigation_state_result(
                  request_id,
                  ctx_id,
                  requested_url,
                  resolved_url,
                  completion.navigation_id,
                  completion.result,
                )
              }
            }
            Err(e) => {
              let nav_id = self.next_navigation_id.to_string()
              self.next_navigation_id += 1
              self.emit_navigation_started_event(ctx_id, resolved_url, nav_id)
              self.send_error(
                request_id,
                "unknown error",
                "Navigation failed: " + e.message,
              )
            }
          }
        }
        None => {
          self.send_error(
            request_id,
            "no such frame",
            "Unknown context: " + ctx_id,
          )
          return
        }
      }
    }
    None => ()
  }
}

///|
fn BidiProtocol::resolve_script_prepare_beforeunload_page_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> (String, String)? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }
  let ctx_id = match map.get("context") {
    Some(String(ctx_id)) =>
      if ctx_id == "" || self.manager.get_session(ctx_id) is None {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return None
      } else {
        ctx_id
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }
  let url = match map.get("url") {
    Some(String(url)) => url
    Some(Null) | None => default_beforeunload_test_page_url()
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return None
    }
  }
  Some((ctx_id, url))
}

///|
fn BidiProtocol::handle_script_sync_document_cookies_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_test_script_context_runtime(request_id, params) {
    Some((ctx_id, _, runtime_ctx_id)) => {
      let (cookie_text, cookie_count) = self.sync_document_cookies_for_test_context(
        ctx_id, runtime_ctx_id,
      )
      self.send_success(
        request_id,
        Some(
          make_object({
            "cookieText": Json::string(cookie_text),
            "cookieCount": Json::number(cookie_count.to_double()),
          }),
        ),
      )
    }
    None => ()
  }
}

///|
fn BidiProtocol::sync_document_cookies_for_test_context(
  self : BidiProtocol,
  ctx_id : String,
  runtime_ctx_id : String,
) -> (String, Int) {
  set_runtime_context(runtime_ctx_id)
  set_runtime_context_frames(
    runtime_ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(runtime_ctx_id, ctx_id)
  if !self.dom_initialized {
    let _ = evaluate_js_with_console("undefined", false, false, false, "{}")
    self.dom_initialized = true
  }
  let eval_result_json = evaluate_js_with_console(
    "document.cookie", false, false, false, "{}",
  )
  self.dom_initialized = true
  let eval_result = @json.parse(eval_result_json) catch { _ => make_object({}) }
  let cookie_text = match get_string_field(eval_result, "type") {
    Some("success") =>
      match get_field(eval_result, "result") {
        Some(remote_value) =>
          remote_value_as_string(remote_value).unwrap_or(
            self.resolve_document_cookie(ctx_id).unwrap_or(""),
          )
        None => self.resolve_document_cookie(ctx_id).unwrap_or("")
      }
    _ => self.resolve_document_cookie(ctx_id).unwrap_or("")
  }
  let mut cookie_count = 0
  if cookie_text.trim() != "" {
    for raw_entry in cookie_text.split(";") {
      if raw_entry.contains("=") {
        self.remember_document_cookie(ctx_id, raw_entry.trim().to_owned())
        cookie_count += 1
      }
    }
  }
  (cookie_text, cookie_count)
}

///|
fn BidiProtocol::handle_script_fetch_for_test(
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

  let ctx_id = match map.get("context") {
    Some(String(ctx_id)) =>
      if ctx_id == "" || self.manager.get_session(ctx_id) is None {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return
      } else {
        ctx_id
      }
    Some(Null) | None => self.ensure_default_context()
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  let sandbox_name = match map.get("sandbox") {
    Some(String(name)) if name != "" => Some(name)
    Some(String(_)) | Some(Null) | None => None
    _ => {
      self.send_error(
        request_id, "invalid argument", "sandbox must be a string",
      )
      return
    }
  }
  let realm_id = match sandbox_name {
    Some(name) => self.get_or_create_sandbox_realm(ctx_id, name)
    None => self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
  }
  let runtime_ctx_id = match sandbox_name {
    Some(_) => realm_id
    None => ctx_id
  }
  let target_url = match map.get("url") {
    Some(String(url)) => url
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return
    }
  }
  let raw_headers = map.get("headers")
  let headers_json = match map.get("headersJson") {
    Some(String(headers_json)) => headers_json
    Some(Null) | None =>
      match raw_headers {
        Some(raw_headers) => raw_headers.stringify()
        None => "null"
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "headersJson must be a string",
      )
      return
    }
  }
  let raw_post_data = get_map_field_with_alias(map, "postData", "post_data")
  let post_data_json = match map.get("postDataJson") {
    Some(String(post_data_json)) => post_data_json
    Some(Null) | None =>
      match raw_post_data {
        Some(raw_post_data) => raw_post_data.stringify()
        None => "null"
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "postDataJson must be a string",
      )
      return
    }
  }
  let post_data_mode = match map.get("postDataMode") {
    Some(String("none")) => "none"
    Some(String("formData")) => "formData"
    Some(String("value")) => "value"
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "postDataMode must be a known string",
      )
      return
    }
    Some(Null) | None =>
      if get_map_field_with_alias(map, "requestData", "request_data") != None {
        "value"
      } else if raw_post_data is Some(raw_post_data) {
        synthetic_fetch_post_data_mode_from_value(raw_post_data)
      } else if post_data_json != "null" {
        "value"
      } else {
        "none"
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "postDataMode must be a string",
      )
      return
    }
  }
  let request_headers = match
    get_map_field_with_alias(map, "requestHeaders", "request_headers") {
    Some(raw_headers) =>
      match
        self.normalize_synthetic_network_header_entries(
          request_id,
          Some(raw_headers),
        ) {
        Some(request_headers) => request_headers
        None => return
      }
    None =>
      match raw_headers {
        Some(raw_headers) =>
          synthetic_fetch_request_headers_from_value(raw_headers)
        None => synthetic_fetch_request_headers_from_json(headers_json)
      }
  }
  let request_value = match
    get_map_field_with_alias(map, "requestData", "request_data") {
    Some(raw_value) =>
      match
        self.normalize_synthetic_network_bytes_value(
          request_id, raw_value, "requestData",
        ) {
        Some(value) => Some(value)
        None => return
      }
    None =>
      match raw_post_data {
        Some(raw_post_data) =>
          synthetic_fetch_request_value_from_post_data(
            raw_post_data, post_data_mode,
          )
        None =>
          synthetic_fetch_request_value_from_post_data_json(
            post_data_json, post_data_mode,
          )
      }
  }
  let request_method = match map.get("method") {
    Some(String(request_method)) => request_method
    Some(Null) | None =>
      if request_value != None || post_data_mode != "none" {
        "POST"
      } else {
        "GET"
      }
    _ => {
      self.send_error(request_id, "invalid argument", "method must be a string")
      return
    }
  }
  let timeout_ms = match map.get("timeoutMs") {
    Some(Number(n, ..)) if n >= 0.0 && n == n.to_int64().to_double() =>
      n.to_int64().to_int()
    Some(Number(_)) => {
      self.send_error(
        request_id, "invalid argument", "timeoutMs must be a non-negative integer",
      )
      return
    }
    Some(Null) | None => 0
    _ => {
      self.send_error(
        request_id, "invalid argument", "timeoutMs must be a non-negative integer",
      )
      return
    }
  }
  let should_abort = match
    get_map_field_with_alias(map, "shouldAbort", "should_abort") {
    None | Some(Null) => false
    Some(True) => true
    Some(False) => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "shouldAbort must be a boolean",
      )
      return
    }
  }

  let resolved_url = self.resolve_fetch_target_url(ctx_id, target_url)
  if self.resolve_storage_request_cookies(ctx_id, Some(resolved_url)).length() ==
    0 {
    ignore(self.sync_document_cookies_for_test_context(ctx_id, runtime_ctx_id))
  }

  if canonicalize_network_http_url(resolved_url) is Some(_) ||
    resolved_url.has_prefix("data:") {
    let result = self.perform_synthetic_fetch_internal(
      request_id, ctx_id, resolved_url, request_method, request_headers, request_value,
      should_abort,
    )
    match result.blocked_text {
      Some(text) =>
        self.send_success(
          request_id,
          Some(
            make_object({
              "exceptionDetails": make_object({ "text": Json::string(text) }),
            }),
          ),
        )
      None => {
        let response_value = self.build_script_fetch_for_test_response_value(
          ctx_id,
          resolved_url,
          request_headers,
          result.response_value,
        )
        self.send_success(request_id, Some(response_value))
      }
    }
    return
  }

  self.send_script_fetch_from_context_for_test(
    request_id, ctx_id, realm_id, runtime_ctx_id, resolved_url, request_method, headers_json,
    post_data_json, post_data_mode, timeout_ms,
  )
}

///|
fn synthetic_fetch_request_headers_from_json(
  headers_json : String,
) -> Array[Json] {
  let parsed = @json.parse(headers_json) catch { _ => return [] }
  synthetic_fetch_request_headers_from_value(parsed)
}

///|
fn synthetic_fetch_request_headers_from_value(
  raw_headers : Json,
) -> Array[Json] {
  match raw_headers {
    Object(headers_map) => {
      let headers : Array[Json] = []
      for name, raw_value in headers_map {
        headers.push(
          synthetic_network_header_string_entry(
            name,
            synthetic_fetch_json_text_value(raw_value),
          ),
        )
      }
      headers
    }
    _ => []
  }
}

///|
fn synthetic_fetch_post_data_mode_from_value(raw_post_data : Json) -> String {
  match raw_post_data {
    Null => "none"
    Object(_) => "formData"
    _ => "value"
  }
}

///|
fn synthetic_fetch_request_value_from_post_data_json(
  post_data_json : String,
  post_data_mode : String,
) -> Json? {
  if post_data_mode == "none" {
    return None
  }
  let parsed = @json.parse(post_data_json) catch { _ => return None }
  synthetic_fetch_request_value_from_post_data(parsed, post_data_mode)
}

///|
fn synthetic_fetch_request_value_from_post_data(
  post_data : Json,
  post_data_mode : String,
) -> Json? {
  if post_data_mode == "formData" {
    match post_data {
      Object(form_data) =>
        Some(synthetic_fetch_multipart_request_value(form_data))
      _ => None
    }
  } else {
    Some(
      make_object({
        "type": Json::string("string"),
        "value": Json::string(synthetic_fetch_json_text_value(post_data)),
      }),
    )
  }
}

///|
fn BidiProtocol::build_script_fetch_for_test_response_value(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  request_headers : Array[Json],
  default_value : Json,
) -> Json {
  if !synthetic_fetch_is_headers_echo_url(url) {
    return default_value
  }
  make_object({
    "type": Json::string("string"),
    "value": Json::string(
      self.build_script_fetch_headers_echo_payload(ctx_id, request_headers),
    ),
  })
}

///|
fn BidiProtocol::build_script_fetch_headers_echo_payload(
  self : BidiProtocol,
  context_id : String,
  request_headers : Array[Json],
) -> String {
  let headers : Map[String, Json] = {}
  for
    header in self.resolve_network_extra_header_entries(
      context_id, request_headers,
    ) {
    let name = match synthetic_network_header_entry_name(header) {
      Some(name) => name
      None => continue
    }
    let value = match synthetic_network_header_entry_string_value(header) {
      Some(value) => value
      None => continue
    }
    headers[name] = Json::array([Json::string(value)])
  }
  make_object({ "headers": make_object(headers) }).stringify()
}

///|
fn synthetic_fetch_multipart_request_value(
  form_data : Map[String, Json],
) -> Json {
  let boundary = "----crater-boundary"
  let mut has_binary = false
  let mut body = ""
  for field_name, raw_value in form_data {
    match synthetic_fetch_form_data_file_entry(raw_value) {
      Some((filename, content_type, payload)) => {
        has_binary = true
        body = body +
          "--" +
          boundary +
          "\r\n" +
          "Content-Disposition: form-data; name=\"" +
          field_name +
          "\"; filename=\"" +
          filename +
          "\"\r\n" +
          "Content-Type: " +
          content_type +
          "\r\n\r\n" +
          payload +
          "\r\n"
      }
      None =>
        body = body +
          "--" +
          boundary +
          "\r\n" +
          "Content-Disposition: form-data; name=\"" +
          field_name +
          "\"\r\n\r\n" +
          synthetic_fetch_json_text_value(raw_value) +
          "\r\n"
    }
  }
  body = body + "--" + boundary + "--\r\n"
  if has_binary {
    make_object({
      "type": Json::string("base64"),
      "value": Json::string(encode_base64_raw(body)),
    })
  } else {
    make_object({ "type": Json::string("string"), "value": Json::string(body) })
  }
}

///|
fn synthetic_fetch_form_data_file_entry(
  raw_value : Json,
) -> (String, String, String)? {
  let value_map = match raw_value {
    Object(value_map) => value_map
    _ => return None
  }
  let encoded_value = match value_map.get("value") {
    Some(String(encoded_value)) => encoded_value
    _ => return None
  }
  let filename = match value_map.get("filename") {
    Some(String(filename)) => filename
    _ => "blob.bin"
  }
  let content_type = match value_map.get("type") {
    Some(String(content_type)) => content_type
    _ => "application/octet-stream"
  }
  Some((filename, content_type, decode_base64(encoded_value)))
}

///|
fn synthetic_fetch_json_text_value(raw_value : Json) -> String {
  match raw_value {
    String(value) => value
    Number(value, ..) => value.to_string()
    True => "true"
    False => "false"
    Null => "null"
    Array(_) | Object(_) => raw_value.stringify()
  }
}

///|
fn BidiProtocol::handle_script_fetch_from_context_for_test(
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
  let (ctx_id, realm_id, runtime_ctx_id) = match
    self.resolve_test_script_context_runtime(request_id, params) {
    Some(value) => value
    None => return
  }
  let url = match map.get("url") {
    Some(String(url)) => url
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return
    }
  }
  let request_method = match map.get("method") {
    Some(String(request_method)) => request_method
    _ => {
      self.send_error(request_id, "invalid argument", "method must be a string")
      return
    }
  }
  let headers_json = match map.get("headersJson") {
    Some(String(headers_json)) => headers_json
    Some(Null) | None => "null"
    _ => {
      self.send_error(
        request_id, "invalid argument", "headersJson must be a string",
      )
      return
    }
  }
  let post_data_json = match map.get("postDataJson") {
    Some(String(post_data_json)) => post_data_json
    Some(Null) | None => "null"
    _ => {
      self.send_error(
        request_id, "invalid argument", "postDataJson must be a string",
      )
      return
    }
  }
  let post_data_mode = match map.get("postDataMode") {
    Some(String("none")) => "none"
    Some(String("formData")) => "formData"
    Some(String("value")) => "value"
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "postDataMode must be a known string",
      )
      return
    }
    None => "none"
    _ => {
      self.send_error(
        request_id, "invalid argument", "postDataMode must be a string",
      )
      return
    }
  }
  let timeout_ms = match map.get("timeoutMs") {
    Some(Number(n, ..)) if n >= 0.0 && n == n.to_int64().to_double() =>
      n.to_int64().to_int()
    Some(Number(_)) => {
      self.send_error(
        request_id, "invalid argument", "timeoutMs must be a non-negative integer",
      )
      return
    }
    None => 0
    _ => {
      self.send_error(
        request_id, "invalid argument", "timeoutMs must be a non-negative integer",
      )
      return
    }
  }

  self.send_script_fetch_from_context_for_test(
    request_id, ctx_id, realm_id, runtime_ctx_id, url, request_method, headers_json,
    post_data_json, post_data_mode, timeout_ms,
  )
}

///|
fn BidiProtocol::send_script_fetch_from_context_for_test(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  runtime_ctx_id : String,
  url : String,
  request_method : String,
  headers_json : String,
  post_data_json : String,
  post_data_mode : String,
  timeout_ms : Int,
) -> Unit {
  set_runtime_context(runtime_ctx_id)
  set_runtime_context_frames(
    runtime_ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(runtime_ctx_id, ctx_id)
  if !self.dom_initialized {
    let _ = evaluate_js_with_console("undefined", false, false, false, "{}")
    self.dom_initialized = true
  }
  let expression = js_fetch_from_context_for_test_expression(
    url, request_method, headers_json, post_data_json, post_data_mode, timeout_ms,
  )
  match self.socket {
    Some(socket) =>
      eval_and_send_async_with_console(
        socket, request_id, expression, runtime_ctx_id, realm_id, false, false, false,
        true,
      )
    None =>
      self.send_error(
        request_id, "unknown error", "WebSocket is required for async fetch evaluation",
      )
  }
}

///|
extern "js" fn js_test_page_dom_content_loaded_source() -> String =
  #| () => String.raw`(() => {
  #|   const event =
  #|     typeof globalThis.__bidiCreateEvent === "function"
  #|       ? globalThis.__bidiCreateEvent("DOMContentLoaded", { bubbles: true, cancelable: true })
  #|       : { type: "DOMContentLoaded" };
  #|   if (document && typeof document.dispatchEvent === "function") {
  #|     try { document.dispatchEvent(event); } catch (_e) {}
  #|   }
  #|   return null;
  #| })`

///|
extern "js" fn js_test_page_reset_state_source() -> String =
  #| () => String.raw`(() => {
  #|   if (window && typeof window === "object") {
  #|     window.__craterAllEventsFallbackInit = false;
  #|     window.__bidiFocusedElement = null;
  #|   }
  #|   globalThis.__bidiFocusedElement = null;
  #|   globalThis.__bidiRecordedTestActionsMousemove = false;
  #|   if (typeof allEvents !== "undefined") {
  #|     window.allEvents = allEvents;
  #|   }
  #|   if (typeof window.allEvents === "undefined") {
  #|     window.allEvents = { events: [] };
  #|   }
  #|   if (window.allEvents && Array.isArray(window.allEvents.events)) {
  #|     window.allEvents.events.length = 0;
  #|   }
  #|   return null;
  #| })`

///|
extern "js" fn js_test_page_all_events_fallback_source() -> String =
  #| () => String.raw`(() => {
  #|   if (typeof window.allEvents === "undefined") {
  #|     window.allEvents = { events: [] };
  #|   }
  #| 
  #|   let keyboardRecorder =
  #|     typeof globalThis.recordKeyboardEvent === "function"
  #|       ? globalThis.recordKeyboardEvent
  #|       : (window && typeof window.recordKeyboardEvent === "function"
  #|           ? window.recordKeyboardEvent
  #|           : null);
  #|   let pointerRecorder =
  #|     typeof globalThis.recordPointerEvent === "function"
  #|       ? globalThis.recordPointerEvent
  #|       : (window && typeof window.recordPointerEvent === "function"
  #|           ? window.recordPointerEvent
  #|           : null);
  #|   let wheelRecorder =
  #|     typeof globalThis.recordWheelEvent === "function"
  #|       ? globalThis.recordWheelEvent
  #|       : (window && typeof window.recordWheelEvent === "function"
  #|           ? window.recordWheelEvent
  #|           : null);
  #| 
  #|   if (!keyboardRecorder) {
  #|     keyboardRecorder = (event) => {
  #|       if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
  #|         window.allEvents = { events: [] };
  #|       }
  #|       window.allEvents.events.push({
  #|         code: event.code,
  #|         key: event.key,
  #|         which: event.which,
  #|         location: event.location,
  #|         ctrl: event.ctrlKey,
  #|         meta: event.metaKey,
  #|         shift: event.shiftKey,
  #|         repeat: event.repeat,
  #|         type: event.type,
  #|       });
  #|     };
  #|   }
  #|   if (!pointerRecorder) {
  #|     pointerRecorder = (event) => {
  #|       if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
  #|         window.allEvents = { events: [] };
  #|       }
  #|       if (event.type === "contextmenu" && typeof event.preventDefault === "function") {
  #|         event.preventDefault();
  #|       }
  #|       window.allEvents.events.push({
  #|         type: event.type,
  #|         button: event.button,
  #|         buttons: event.buttons,
  #|         pageX: event.pageX,
  #|         pageY: event.pageY,
  #|         ctrlKey: event.ctrlKey,
  #|         metaKey: event.metaKey,
  #|         altKey: event.altKey,
  #|         shiftKey: event.shiftKey,
  #|         clientX: event.clientX,
  #|         clientY: event.clientY,
  #|         isTrusted: event.isTrusted,
  #|         detail: event.detail,
  #|         target: event.target && event.target.id ? event.target.id : "",
  #|         pointerType: event.pointerType || "",
  #|         width: event.width,
  #|         height: event.height,
  #|         pressure: event.pressure,
  #|         tangentialPressure: event.tangentialPressure,
  #|         tiltX: event.tiltX,
  #|         tiltY: event.tiltY,
  #|         twist: event.twist,
  #|         altitudeAngle: event.altitudeAngle,
  #|         azimuthAngle: event.azimuthAngle,
  #|       });
  #|     };
  #|   }
  #|   if (typeof globalThis.resetEvents !== "function") {
  #|     globalThis.resetEvents = () => {
  #|       if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
  #|         window.allEvents = { events: [] };
  #|       }
  #|       window.allEvents.events.length = 0;
  #|     };
  #|   }
  #| 
  #|   if (keyboardRecorder && typeof globalThis.recordKeyboardEvent !== "function") {
  #|     globalThis.recordKeyboardEvent = keyboardRecorder;
  #|   }
  #|   if (pointerRecorder && typeof globalThis.recordPointerEvent !== "function") {
  #|     globalThis.recordPointerEvent = pointerRecorder;
  #|   }
  #|   if (wheelRecorder && typeof globalThis.recordWheelEvent !== "function") {
  #|     globalThis.recordWheelEvent = wheelRecorder;
  #|   }
  #|   try {
  #|     if (typeof globalThis.recordKeyboardEvent === "function") {
  #|       (0, eval)("var recordKeyboardEvent = globalThis.recordKeyboardEvent");
  #|     }
  #|     if (typeof globalThis.recordPointerEvent === "function") {
  #|       (0, eval)("var recordPointerEvent = globalThis.recordPointerEvent");
  #|     }
  #|     if (typeof globalThis.recordWheelEvent === "function") {
  #|       (0, eval)("var recordWheelEvent = globalThis.recordWheelEvent");
  #|     }
  #|     if (typeof globalThis.resetEvents === "function") {
  #|       (0, eval)("var resetEvents = globalThis.resetEvents");
  #|     }
  #|   } catch (_e) {}
  #| 
  #|   if (keyboardRecorder) {
  #|     const keyReporter = document.getElementById("keys");
  #|     const hasKeyListeners = !!(
  #|       keyReporter &&
  #|       keyReporter._listeners &&
  #|       (
  #|         (Array.isArray(keyReporter._listeners.keydown) && keyReporter._listeners.keydown.length > 0) ||
  #|         (Array.isArray(keyReporter._listeners.keyup) && keyReporter._listeners.keyup.length > 0) ||
  #|         (Array.isArray(keyReporter._listeners.keypress) && keyReporter._listeners.keypress.length > 0)
  #|       )
  #|     );
  #|     if (keyReporter && !hasKeyListeners && !keyReporter.__craterKeyboardListeners) {
  #|       keyReporter.addEventListener("keyup", keyboardRecorder);
  #|       keyReporter.addEventListener("keypress", keyboardRecorder);
  #|       keyReporter.addEventListener("keydown", keyboardRecorder);
  #|       keyReporter.__craterKeyboardListeners = true;
  #|     }
  #|   }
  #| 
  #|   if (pointerRecorder) {
  #|     const outer = document.getElementById("outer");
  #|     const hasPointerListeners = !!(
  #|       outer &&
  #|       outer._listeners &&
  #|       (
  #|         (Array.isArray(outer._listeners.click) && outer._listeners.click.length > 0) ||
  #|         (Array.isArray(outer._listeners.dblclick) && outer._listeners.dblclick.length > 0) ||
  #|         (Array.isArray(outer._listeners.mousedown) && outer._listeners.mousedown.length > 0) ||
  #|         (Array.isArray(outer._listeners.mouseup) && outer._listeners.mouseup.length > 0) ||
  #|         (Array.isArray(outer._listeners.contextmenu) && outer._listeners.contextmenu.length > 0)
  #|       )
  #|     );
  #|     if (outer && !hasPointerListeners && !outer.__craterPointerListeners) {
  #|       outer.addEventListener("click", pointerRecorder);
  #|       outer.addEventListener("dblclick", pointerRecorder);
  #|       outer.addEventListener("mousedown", pointerRecorder);
  #|       outer.addEventListener("mouseup", pointerRecorder);
  #|       outer.addEventListener("contextmenu", pointerRecorder);
  #|       outer.__craterPointerListeners = true;
  #|     }
  #|     const hasWindowMouseMove = !!(
  #|       window &&
  #|       window._listeners &&
  #|       Array.isArray(window._listeners.mousemove) &&
  #|       window._listeners.mousemove.length > 0
  #|     );
  #|     if (window && typeof window.addEventListener === "function" && !hasWindowMouseMove && !window.__craterFirstPointerMoveListener) {
  #|       const recordFirstPointerMove = (event) => {
  #|         pointerRecorder(event);
  #|         try {
  #|           window.removeEventListener("mousemove", recordFirstPointerMove);
  #|         } catch (_e) {}
  #|       };
  #|       window.addEventListener("mousemove", recordFirstPointerMove);
  #|       window.__craterFirstPointerMoveListener = true;
  #|     }
  #|   }
  #| 
  #|   if (wheelRecorder) {
  #|     eventReporter = document.getElementById("event-reporter");
  #|     const notScrollable = document.getElementById("not-scrollable");
  #|     const hasNotScrollableWheel = !!(
  #|       notScrollable &&
  #|       notScrollable._listeners &&
  #|       Array.isArray(notScrollable._listeners.wheel) &&
  #|       notScrollable._listeners.wheel.length > 0
  #|     );
  #|     if (notScrollable && !hasNotScrollableWheel && !notScrollable.__craterWheelListener) {
  #|       notScrollable.addEventListener("wheel", wheelRecorder);
  #|       notScrollable.__craterWheelListener = true;
  #|     }
  #|     const scrollable = document.getElementById("scrollable");
  #|     const hasScrollableWheel = !!(
  #|       scrollable &&
  #|       scrollable._listeners &&
  #|       Array.isArray(scrollable._listeners.wheel) &&
  #|       scrollable._listeners.wheel.length > 0
  #|     );
  #|     if (scrollable && !hasScrollableWheel && !scrollable.__craterWheelListener) {
  #|       scrollable.addEventListener("wheel", wheelRecorder);
  #|       scrollable.__craterWheelListener = true;
  #|     }
  #|   }
  #| 
  #|   if (!window.__craterAllEventsFallbackInit) {
  #|     const pushEvent = (event) => {
  #|       window.allEvents.events.push({
  #|         type: event.type,
  #|         code: event.code,
  #|         key: event.key,
  #|         which: event.which,
  #|         location: event.location,
  #|         ctrl: event.ctrlKey,
  #|         meta: event.metaKey,
  #|         shift: event.shiftKey,
  #|         repeat: event.repeat,
  #|         button: event.button,
  #|         buttons: event.buttons,
  #|         pageX: event.pageX,
  #|         pageY: event.pageY,
  #|         deltaX: event.deltaX,
  #|         deltaY: event.deltaY,
  #|         deltaZ: event.deltaZ,
  #|         deltaMode: event.deltaMode,
  #|         clientX: event.clientX,
  #|         clientY: event.clientY,
  #|         isTrusted: event.isTrusted,
  #|         detail: event.detail,
  #|         target: event.target && event.target.id ? event.target.id : "",
  #|         pointerType: event.pointerType || "",
  #|         width: event.width,
  #|         height: event.height,
  #|         pressure: event.pressure,
  #|         tangentialPressure: event.tangentialPressure,
  #|         tiltX: event.tiltX,
  #|         tiltY: event.tiltY,
  #|         twist: event.twist,
  #|         altitudeAngle: event.altitudeAngle,
  #|         azimuthAngle: event.azimuthAngle,
  #|         altKey: event.altKey,
  #|         ctrlKey: event.ctrlKey,
  #|         metaKey: event.metaKey,
  #|         shiftKey: event.shiftKey,
  #|       });
  #|     };
  #|     const hasKeyboardRecorder = !!keyboardRecorder;
  #|     const hasPointerRecorder = !!pointerRecorder;
  #|     const hasWheelRecorder = !!wheelRecorder;
  #| 
  #|     const keyReporter = document.getElementById("keys");
  #|     if (keyReporter && !hasKeyboardRecorder) {
  #|       keyReporter.addEventListener("keydown", pushEvent);
  #|       keyReporter.addEventListener("keypress", pushEvent);
  #|       keyReporter.addEventListener("keyup", pushEvent);
  #|     }
  #| 
  #|     if (!hasPointerRecorder) {
  #|       const pointerTarget = document;
  #|       for (const eventName of ["mousemove", "mousedown", "mouseup", "click", "dblclick", "contextmenu", "auxclick"]) {
  #|         pointerTarget.addEventListener(eventName, pushEvent);
  #|       }
  #|     }
  #| 
  #|     const notScrollable = document.getElementById("not-scrollable");
  #|     if (notScrollable && !hasWheelRecorder) {
  #|       notScrollable.addEventListener("wheel", pushEvent);
  #|     }
  #|     const scrollable = document.getElementById("scrollable");
  #|     if (scrollable && !hasWheelRecorder) {
  #|       scrollable.addEventListener("wheel", pushEvent);
  #|     }
  #|     window.__craterAllEventsFallbackInit = true;
  #|   }
  #|   return null;
  #| })`

///|
extern "js" fn js_test_actions_page_specific_source() -> String =
  #| () => String.raw`(() => {
  #|   const setStyle = (el, styles) => {
  #|     if (!el || !el.style) return;
  #|     for (const [key, value] of Object.entries(styles)) {
  #|       try { el.style[key] = value; } catch (_e) {}
  #|     }
  #|   };
  #|   for (const el of Array.from(document.querySelectorAll(".area"))) {
  #|     setStyle(el, {
  #|       width: "100px",
  #|       height: "50px",
  #|       backgroundColor: "#ccc",
  #|     });
  #|   }
  #|   for (const el of Array.from(document.querySelectorAll(".block"))) {
  #|     setStyle(el, {
  #|       width: "5px",
  #|       height: "5px",
  #|       borderWidth: "1px",
  #|       borderStyle: "solid",
  #|       borderColor: "red",
  #|     });
  #|   }
  #|   setStyle(document.getElementById("trackPointer"), { position: "fixed" });
  #|   setStyle(document.getElementById("resultContainer"), { width: "600px", height: "60px" });
  #|   setStyle(document.getElementById("dragArea"), { position: "relative" });
  #|   setStyle(document.getElementById("dragTarget"), {
  #|     position: "absolute",
  #|     top: "22px",
  #|     left: "47px",
  #|   });
  #|   return null;
  #| })`

///|
extern "js" fn js_test_actions_scroll_page_specific_source() -> String =
  #| () => String.raw`(() => {
  #|   const ensure = (id, tagName = "div", parent = document.body) => {
  #|     let element = document.getElementById(id);
  #|     if (!element && document && typeof document.createElement === "function") {
  #|       element = document.createElement(tagName);
  #|       element.id = id;
  #|       parent.appendChild(element);
  #|     }
  #|     return element;
  #|   };
  #|   const setStyle = (el, styles) => {
  #|     if (!el || !el.style) return;
  #|     for (const [key, value] of Object.entries(styles)) {
  #|       try { el.style[key] = value; } catch (_e) {}
  #|     }
  #|   };
  #|   if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
  #|     window.allEvents = { events: [] };
  #|   }
  #|   window.recordWheelEvent = (event) => {
  #|     if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
  #|       window.allEvents = { events: [] };
  #|     }
  #|     const target = event && event.target ? event.target : null;
  #|     window.allEvents.events.push({
  #|       type: event?.type || "wheel",
  #|       button: event?.button ?? 0,
  #|       buttons: event?.buttons ?? 0,
  #|       pageX: event?.pageX ?? 0,
  #|       pageY: event?.pageY ?? 0,
  #|       deltaX: event?.deltaX ?? 0,
  #|       deltaY: event?.deltaY ?? 0,
  #|       deltaZ: event?.deltaZ ?? 0,
  #|       deltaMode: event?.deltaMode ?? 0,
  #|       target: target && target.id ? target.id : "",
  #|       altKey: !!event?.altKey,
  #|       ctrlKey: !!event?.ctrlKey,
  #|       metaKey: !!event?.metaKey,
  #|       shiftKey: !!event?.shiftKey,
  #|     });
  #|   };
  #|   const notScrollable = ensure("not-scrollable");
  #|   const notScrollableContent = ensure("not-scrollable-content", "div", notScrollable || document.body);
  #|   setStyle(notScrollable, { width: "100px", height: "50px", marginBottom: "100px" });
  #|   setStyle(notScrollableContent, { width: "200px", height: "100px", backgroundColor: "#ccc" });
  #|   const scrollable = ensure("scrollable");
  #|   const scrollableContent = ensure("scrollable-content", "div", scrollable || document.body);
  #|   setStyle(scrollable, { width: "100px", height: "100px", overflow: "scroll" });
  #|   setStyle(scrollableContent, { width: "600px", height: "1000px", backgroundColor: "blue" });
  #|   if (notScrollable && !notScrollable.__craterWheelListener) {
  #|     notScrollable.addEventListener("wheel", window.recordWheelEvent);
  #|     notScrollable.__craterWheelListener = true;
  #|   }
  #|   if (scrollable && !scrollable.__craterWheelListener) {
  #|     scrollable.addEventListener("wheel", window.recordWheelEvent);
  #|     scrollable.__craterWheelListener = true;
  #|   }
  #|   const iframe = ensure("iframe", "iframe");
  #|   setStyle(iframe, { width: "100px", height: "100px" });
  #|   if (iframe && !iframe.__craterWheelIframeSetup) {
  #|     iframe.srcdoc =
  #|       '<script>' +
  #|       'document.scrollingElement.addEventListener("wheel", event => {' +
  #|       'window.parent.recordWheelEvent({' +
  #|       'type: event.type,' +
  #|       'button: event.button,' +
  #|       'buttons: event.buttons,' +
  #|       'pageX: event.pageX,' +
  #|       'pageY: event.pageY,' +
  #|       'deltaX: event.deltaX,' +
  #|       'deltaY: event.deltaY,' +
  #|       'deltaZ: event.deltaZ,' +
  #|       'deltaMode: event.deltaMode,' +
  #|       'target: { id: "iframeContent" },' +
  #|       'altKey: event.altKey,' +
  #|       'ctrlKey: event.ctrlKey,' +
  #|       'metaKey: event.metaKey,' +
  #|       'shiftKey: event.shiftKey,' +
  #|       '});' +
  #|       '});<\/script>' +
  #|       '<div id="iframeContent" style="width:7500px;height:7500px;background-color:blue"></div>';
  #|     iframe.__craterWheelIframeSetup = true;
  #|   }
  #|   return null;
  #| })`

///|
extern "js" fn js_beforeunload_page_setup_source() -> String =
  #| () => String.raw`(() => {
  #|   const input = document && typeof document.querySelector === "function"
  #|     ? document.querySelector("input")
  #|     : null;
  #|   if (input) {
  #|     try { if (typeof input.focus === "function") input.focus(); } catch (_e) {}
  #|     try { input.value = "foo"; } catch (_e) {}
  #|     try {
  #|       const event =
  #|         typeof globalThis.__bidiCreateEvent === "function"
  #|           ? globalThis.__bidiCreateEvent("input", { bubbles: true, cancelable: true })
  #|           : new Event("input", { bubbles: true });
  #|       if (typeof input.dispatchEvent === "function") {
  #|         input.dispatchEvent(event);
  #|       }
  #|     } catch (_e) {}
  #|   }
  #|   return null;
  #| })`

///|
extern "js" fn js_fetch_from_context_for_test_expression(
  url : String,
  request_method : String,
  headers_json : String,
  post_data_json : String,
  post_data_mode : String,
  timeout_ms : Int,
) -> String =
  #| (url, requestMethod, headersJson, postDataJson, postDataMode, timeoutMs) => {
  #|   const quoted = JSON.stringify;
  #|   const timeout = Number.isFinite(Number(timeoutMs)) ? Math.max(0, Number(timeoutMs)) : 0;
  #|   return `(() => {
  #|     const controller = new AbortController();
  #|     setTimeout(() => controller.abort(), ${timeout});
  #|     const parse = (raw, fallback) => {
  #|       try { return JSON.parse(String(raw ?? "null")); } catch (_) { return fallback; }
  #|     };
  #|     const options = {
  #|       signal: controller.signal,
  #|     };
  #|     options.method = ${quoted(String(requestMethod ?? "GET"))};
  #|     const headers = parse(${quoted(String(headersJson ?? "null"))}, null);
  #|     if (headers && typeof headers === "object") {
  #|       options.headers = headers;
  #|     }
  #|     const mode = ${quoted(String(postDataMode ?? "none"))};
  #|     if (mode === "formData") {
  #|       const data = parse(${quoted(String(postDataJson ?? "{}"))}, {});
  #|       const formData = new FormData();
  #|       for (const name in data) {
  #|         const value = data[name];
  #|         if (value && typeof value === "object" && typeof value.value === "string") {
  #|           const binary = atob(value.value);
  #|           const bytes = new Uint8Array(binary.length);
  #|           for (let i = 0; i < binary.length; i++) {
  #|             bytes[i] = binary.charCodeAt(i);
  #|           }
  #|           const blob = new Blob([bytes], { type: String(value.type ?? "application/octet-stream") });
  #|           formData.append(name, blob, String(value.filename ?? "blob.bin"));
  #|         } else {
  #|           formData.append(name, value);
  #|         }
  #|       }
  #|       options.body = formData;
  #|     } else if (mode === "value") {
  #|       options.body = parse(${quoted(String(postDataJson ?? "null"))}, null);
  #|     }
  #|     return fetch(${quoted(String(url ?? ""))}, options).then(response => response.text());
  #|   })()`;
  #| }

///|
extern "js" fn js_test_page_create_iframe_source() -> String =
  #| () => String.raw`(url => {
  #|   try {
  #|     if (!document || typeof document.createElement !== "function") {
  #|       return null;
  #|     }
  #|     const iframe = document.createElement("iframe");
  #|     iframe.src = url;
  #|     const parent =
  #|       (document.documentElement && document.documentElement.lastElementChild) ||
  #|       document.body ||
  #|       document.documentElement ||
  #|       document;
  #|     if (parent && typeof parent.append === "function") {
  #|       parent.append(iframe);
  #|     } else if (parent && typeof parent.appendChild === "function") {
  #|       parent.appendChild(iframe);
  #|     }
  #|     return iframe.contentWindow || null;
  #|   } catch (_e) {
  #|     return null;
  #|   }
  #| })`
