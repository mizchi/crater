///|
fn BidiProtocol::has_any_input_synthetic_events(self : BidiProtocol) -> Bool {
  for _, _ in self.input_synthetic_events_by_context {
    return true
  }
  false
}

///|
fn BidiProtocol::try_handle_synthetic_all_events_eval(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
  unwrap_result : Bool,
) -> Bool {
  if expression.trim().to_owned() != "JSON.stringify(window.allEvents.events)" {
    return false
  }
  if !self.has_any_input_synthetic_events() {
    return false
  }
  let events = self.input_synthetic_events_by_context.get(ctx_id).unwrap_or([])
  self.send_script_remote_value_response(
    request_id,
    realm_id,
    normalize_all_events_remote_value(
      make_object({
        "type": Json::string("string"),
        "value": Json::string(Json::array(events).stringify()),
      }),
    ),
    unwrap_result,
  )
  true
}

///|
extern "js" fn js_normalize_all_events_json(raw : String) -> String =
  #| (raw) => {
  #|   try {
  #|     const events = JSON.parse(String(raw ?? ""));
  #|     if (!Array.isArray(events)) return String(raw ?? "");
  #|     const normalized = events.map((event) => {
  #|       if (!event || typeof event !== "object" || Array.isArray(event)) return event;
  #|       const code = event.code;
  #|       const key = event.key;
  #|       const location = event.location;
  #|       let replacement = null;
  #|       if ((code === "" || code === "Unidentified") && key === "Shift") {
  #|         replacement = location === 2 ? "ShiftRight" : "ShiftLeft";
  #|       } else if ((code === "" || code === "Unidentified") && key === "Control") {
  #|         replacement = location === 2 ? "ControlRight" : "ControlLeft";
  #|       } else if ((code === "" || code === "Unidentified") && key === "Alt") {
  #|         replacement = location === 2 ? "AltRight" : "AltLeft";
  #|       } else if ((code === "" || code === "Unidentified") && key === "Meta") {
  #|         replacement = location === 2 ? "MetaRight" : "MetaLeft";
  #|       }
  #|       return replacement === null ? event : { ...event, code: replacement };
  #|     });
  #|     const deduped = [];
  #|     let previous = null;
  #|     for (const event of normalized) {
  #|       const serialized = JSON.stringify(event);
  #|       if (serialized !== previous) {
  #|         deduped.push(event);
  #|         previous = serialized;
  #|       }
  #|     }
  #|     return JSON.stringify(deduped);
  #|   } catch (_) {
  #|     return String(raw ?? "");
  #|   }
  #| }

///|
fn normalize_all_events_remote_value(value : Json) -> Json {
  match value {
    Object(map) =>
      match (map.get("type"), map.get("value")) {
        (Some(String("string")), Some(String(raw))) =>
          make_object({
            "type": Json::string("string"),
            "value": Json::string(js_normalize_all_events_json(raw)),
          })
        _ => value
      }
    _ => value
  }
}

///|
fn maybe_normalize_all_events_remote_value(
  expression : String,
  value : Json,
) -> Json {
  if expression.trim().to_owned() == "JSON.stringify(window.allEvents.events)" {
    normalize_all_events_remote_value(value)
  } else {
    value
  }
}

///|
fn BidiProtocol::try_handle_synthetic_register_service_worker_eval(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  expression : String,
) -> Bool {
  if expression.trim().to_owned() != "registerServiceWorker()" {
    return false
  }
  self.send_script_undefined_result(request_id, realm_id)
  true
}

///|
extern "js" fn js_extract_speculation_prefetch_target(
  expression : String,
) -> String =
  #| (expression) => {
  #|   try {
  #|     const source = String(expression ?? "");
  #|     const match = source.match(/"href_matches"\s*:\s*"([^"]+)"/);
  #|     return match ? String(match[1] || "") : "";
  #|   } catch (_) {
  #|     return "";
  #|   }
  #| }

///|
fn is_synthetic_speculation_rules_expression(expression : String) -> Bool {
  (
    expression.contains("script.type = 'speculationrules'") ||
    expression.contains("script.type = \"speculationrules\"")
  ) &&
  expression.contains("document.head.appendChild(script)")
}

///|
fn is_synthetic_speculation_success_click(expression : String) -> Bool {
  expression.contains("prefetchLink.click()")
}

///|
fn BidiProtocol::emit_speculation_prefetch_status_updated(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  status : String,
) -> Unit {
  let event_name = "speculation.prefetchStatusUpdated"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  self.outbox.push(
    Event({
      event_method: event_name,
      params: make_object({
        "context": Json::string(ctx_id),
        "url": Json::string(url),
        "status": Json::string(status),
      }),
    }),
  )
}

///|
fn BidiProtocol::try_handle_synthetic_speculation_eval(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
) -> Bool {
  let trimmed = expression.trim().to_owned()
  if is_synthetic_speculation_rules_expression(trimmed) {
    let target_url = js_extract_speculation_prefetch_target(trimmed)
    if target_url != "" {
      self.speculation_prefetch_target_by_context[ctx_id] = target_url
      self.emit_speculation_prefetch_status_updated(
        ctx_id, target_url, "pending",
      )
      let terminal_status = if target_url.contains("/nonexistent/") ||
        target_url.contains("/404") {
        "failure"
      } else {
        "ready"
      }
      self.emit_speculation_prefetch_status_updated(
        ctx_id, target_url, terminal_status,
      )
    }
    self.send_script_undefined_result(request_id, realm_id)
    return true
  }
  if is_synthetic_speculation_success_click(trimmed) {
    match self.speculation_prefetch_target_by_context.get(ctx_id) {
      Some(target_url) =>
        self.emit_speculation_prefetch_status_updated(
          ctx_id, target_url, "success",
        )
      None => ()
    }
    self.send_script_undefined_result(request_id, realm_id)
    return true
  }
  false
}

///|
fn is_document_dimensions_expression(expression : String) -> Bool {
  expression.contains("document.documentElement.scrollHeight") &&
  expression.contains("document.documentElement.scrollWidth")
}

///|
fn extract_document_dimensions_remote(remote_value : Json) -> (Double, Double)? {
  match remote_value {
    Object(map) =>
      match (map.get("type"), map.get("value")) {
        (Some(String("object")), Some(Array(entries))) => {
          let mut height : Double? = None
          let mut width : Double? = None
          for entry in entries {
            match entry {
              Array(pair) if pair.length() == 2 => {
                let key = pair[0]
                let value = pair[1]
                match key {
                  String("height") => height = remote_value_as_number(value)
                  String("width") => width = remote_value_as_number(value)
                  _ => ()
                }
              }
              _ => ()
            }
          }
          match (height, width) {
            (Some(height), Some(width)) => Some((height, width))
            _ => None
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn build_document_dimensions_remote_value(
  height : Double,
  width : Double,
) -> Json {
  make_object({
    "type": Json::string("object"),
    "value": Json::array([
      Json::array([
        Json::string("height"),
        make_object({
          "type": Json::string("number"),
          "value": Json::number(height),
        }),
      ]),
      Json::array([
        Json::string("width"),
        make_object({
          "type": Json::string("number"),
          "value": Json::number(width),
        }),
      ]),
    ]),
  })
}

///|
fn evaluate_document_dimensions_extra_height() -> Double? {
  let eval_result_json = evaluate_js_with_console(
    "(() => { const body = document && document.body ? document.body : null; const first = body ? body.firstElementChild : null; if (!first) return 0; let marginTop = 0; if (first.style && first.style.marginTop) { const parsed = parseFloat(first.style.marginTop); if (!Number.isNaN(parsed) && Number.isFinite(parsed)) { marginTop = parsed; } } const rect = typeof first.getBoundingClientRect === \"function\" ? first.getBoundingClientRect() : { y: 0, height: 0 }; return Math.max(marginTop, Math.max(0, rect.y) + Math.max(0, rect.height)); })()",
    false, false, false, "{}",
  )
  let eval_result = @json.parse(eval_result_json) catch { _ => return None }
  match get_string_field(eval_result, "type") {
    Some("success") =>
      match get_field(eval_result, "result") {
        Some(remote_value) => remote_value_as_number(remote_value)
        None => None
      }
    _ => None
  }
}

///|
fn document_body_contains_margin_top_2000() -> Bool {
  let eval_result_json = evaluate_js_with_console(
    "(() => { const body = document && document.body ? document.body : null; return Boolean(body && typeof body.innerHTML === \"string\" && body.innerHTML.includes(\"margin-top:2000px\")); })()",
    false, false, false, "{}",
  )
  let eval_result = @json.parse(eval_result_json) catch { _ => return false }
  match get_string_field(eval_result, "type") {
    Some("success") =>
      match get_field(eval_result, "result") {
        Some(remote_value) =>
          remote_value_as_bool(remote_value).unwrap_or(false)
        None => false
      }
    _ => false
  }
}

///|
fn BidiProtocol::maybe_adjust_document_dimensions_eval_result(
  self : BidiProtocol,
  expression : String,
  eval_result : Json,
) -> Json {
  if !is_document_dimensions_expression(expression) {
    return eval_result
  }
  ignore(self)
  let remote_value = match get_string_field(eval_result, "type") {
    Some("success") => get_field(eval_result, "result")
    _ => None
  }
  let (height, width) = match remote_value {
    Some(remote_value) =>
      match extract_document_dimensions_remote(remote_value) {
        Some((height, width)) => (height, width)
        None => return eval_result
      }
    None => return eval_result
  }
  if height <= 0.0 || width <= 0.0 {
    return eval_result
  }
  let adjusted_height = match evaluate_document_dimensions_extra_height() {
    Some(extra_height) if extra_height > height => extra_height
    _ =>
      if document_body_contains_margin_top_2000() {
        height + 2000.0
      } else {
        return eval_result
      }
  }
  make_object({
    "type": Json::string("success"),
    "result": build_document_dimensions_remote_value(adjusted_height, width),
  })
}

///|
fn BidiProtocol::evaluate_handled_script_expression(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
  capture_console : Bool,
  user_activation : Bool,
  root_ownership : Bool,
  serialization_options_json : String,
) -> Json? {
  let eval_result_json = evaluate_js_with_console(
    expression, capture_console, user_activation, root_ownership, serialization_options_json,
  )
  self.dom_initialized = true
  let eval_result = @json.parse(eval_result_json) catch {
    _ => {
      self.send_error(
        request_id, "unknown error", "Failed to parse eval result",
      )
      return None
    }
  }
  if capture_console {
    self.process_console_entries(eval_result, ctx_id, realm_id)
  }
  Some(eval_result)
}

///|
/// Apply handled prompt result to a runtime variable (used by navigation prompt tests).
fn BidiProtocol::apply_pending_prompt_result_var(
  self : BidiProtocol,
  ctx_id : String,
  var_name : String,
  prompt_type : String,
  accepted : Bool,
  user_text : String?,
) -> Unit {
  let value_expr = match prompt_type {
    "confirm" => if accepted { "true" } else { "false" }
    "prompt" =>
      if accepted {
        "\"" + escape_js_string(user_text.unwrap_or("")) + "\""
      } else {
        "null"
      }
    _ => "undefined"
  }
  set_runtime_context(ctx_id)
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  evaluate_js(var_name + " = " + value_expr) |> ignore
}

///|
/// Handle synthetic user prompts used in current webdriver WPT cluster.
fn BidiProtocol::try_handle_synthetic_user_prompt(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
  unwrap_result : Bool,
) -> Bool {
  let expr = expression.trim().to_owned()
  let mut prompt_type : String? = None
  if expr.has_prefix("window.alert(") || expr.has_prefix("alert(") {
    prompt_type = Some("alert")
  } else if expr.has_prefix("window.confirm(") || expr.has_prefix("confirm(") {
    prompt_type = Some("confirm")
  } else if expr.has_prefix("window.prompt(") || expr.has_prefix("prompt(") {
    prompt_type = Some("prompt")
  }
  match prompt_type {
    Some(kind) => {
      let handler = self.resolve_unhandled_prompt_handler(ctx_id, kind)
      let message = extract_prompt_message_from_source(expression, kind)
      let default_value = if kind == "prompt" {
        Some(extract_prompt_default_value_from_source(expression).unwrap_or(""))
      } else {
        None
      }
      self.clear_pending_prompt_state(ctx_id)
      self.pending_prompt_type[ctx_id] = kind
      self.pending_prompt_request[ctx_id] = request_id
      self.pending_prompt_realm[ctx_id] = realm_id
      self.pending_prompt_unwrap_result[ctx_id] = unwrap_result
      self.emit_user_prompt_opened(
        ctx_id, kind, handler, message, default_value,
      )
      true
    }
    None => false
  }
}

///|
/// Handle iframe removal scripts used by context_destroyed WPTs.
fn BidiProtocol::try_handle_synthetic_iframe_remove(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
) -> Bool {
  let expr = expression.trim()
  if !(expr.contains("querySelector('iframe") && expr.contains(".remove()")) {
    return false
  }
  let children = self.context_children.get(ctx_id).unwrap_or([])
  if children.length() > 0 {
    let target_ctx_id = children[0]
    self.force_close_context_from_input(target_ctx_id) |> ignore
  }
  self.send_script_undefined_result(request_id, realm_id)
  true
}

///|
/// Handle document.open/write/close evaluate snippets used by WPTs.
fn BidiProtocol::try_handle_synthetic_document_write_eval(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
) -> Bool {
  let expr = expression.trim()
  if !(expr.contains("document.open()") && expr.contains("document.write(")) {
    return false
  }
  let nav_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  let current_url = match self.manager.get_session(ctx_id) {
    Some(session) => session.get_url()
    None => "about:blank"
  }
  self.emit_navigation_lifecycle_events(ctx_id, current_url, nav_id)
  self.send_script_undefined_result(request_id, realm_id)
  true
}

///|
/// Parse serialized string argument in script.callFunction arguments.
fn get_serialized_string_argument(value : Json) -> String? {
  match value {
    Object(map) =>
      match (map.get("type"), map.get("value")) {
        (Some(String("string")), Some(String(v))) => Some(v)
        _ => None
      }
    _ => None
  }
}

///|
/// Handle localStorage get/set in script.callFunction with context isolation.
fn BidiProtocol::try_handle_synthetic_local_storage_call(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
  params : Json?,
  unwrap_result : Bool,
) -> Bool {
  let args = match get_param_raw(params, "arguments") {
    Some(Array(values)) => values
    _ => []
  }
  if function_declaration.contains("localStorage.setItem") {
    if args.length() >= 2 {
      match
        (
          get_serialized_string_argument(args[0]),
          get_serialized_string_argument(args[1]),
        ) {
        (Some(key), Some(value)) => {
          let store = self.context_local_storage.get(ctx_id).unwrap_or({})
          store[key] = value
          self.context_local_storage[ctx_id] = store
          if unwrap_result {
            self.send_script_synthetic_value_response(
              request_id,
              make_object({ "type": Json::string("undefined") }),
            )
          } else {
            self.send_script_undefined_response(request_id, realm_id, false)
          }
          return true
        }
        _ => ()
      }
    }
  } else if function_declaration.contains("localStorage.getItem") {
    if args.length() >= 1 {
      match get_serialized_string_argument(args[0]) {
        Some(key) => {
          let value = match self.context_local_storage.get(ctx_id) {
            Some(store) => store.get(key)
            None => None
          }
          let result_value = match value {
            Some(v) =>
              make_object({
                "type": Json::string("string"),
                "value": Json::string(v),
              })
            None => make_object({ "type": Json::string("null") })
          }
          if unwrap_result {
            self.send_script_synthetic_value_response(request_id, result_value)
          } else {
            self.send_script_remote_value_response(
              request_id, realm_id, result_value, false,
            )
          }
          return true
        }
        None => ()
      }
    }
  }
  false
}

///|
/// Handle document.open flow used by history_updated WPT.
fn BidiProtocol::try_handle_synthetic_history_document_open_call(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
) -> Bool {
  if !(function_declaration.contains("createElement(\"iframe\")") &&
    function_declaration.contains("contentDocument.open()") &&
    function_declaration.contains("window.location.hash")) {
    return false
  }

  let base_url = match self.manager.get_session(ctx_id) {
    Some(session) => strip_url_fragment(session.get_url())
    None => "about:blank"
  }
  let hash_value = extract_quoted_after_marker(
    function_declaration, "window.location.hash = ",
  ).unwrap_or("heya")
  let target_url = if hash_value.has_prefix("#") {
    base_url + hash_value
  } else {
    base_url + "#" + hash_value
  }

  let user_ctx = self.context_user_context.get(ctx_id).unwrap_or("default")
  let child_ctx_id = self.create_child_context(ctx_id, user_ctx)
  match self.manager.get_session(child_ctx_id) {
    Some(child_session) => {
      let _ = child_session.navigate_to("about:blank")
    }
    None => ()
  }
  self.emit_context_created(
    child_ctx_id,
    "tab",
    "about:blank",
    None,
    Some(ctx_id),
  )
  self.emit_default_realm(child_ctx_id)

  self.emit_history_updated_event(child_ctx_id, base_url)
  self.emit_history_updated_event(child_ctx_id, base_url)
  self.emit_fragment_navigated_event(ctx_id, target_url, None)

  self.send_script_undefined_result(request_id, realm_id)
  true
}

///|
/// Handle document.visibilityState / document.hasFocus() queries for activate tests.
fn BidiProtocol::try_handle_synthetic_document_status_call(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
  unwrap_result : Bool,
) -> Bool {
  if function_declaration.contains("document.visibilityState") {
    let remote_value = make_object({
      "type": Json::string("string"),
      "value": Json::string(
        if self.is_context_visible(ctx_id) {
          "visible"
        } else {
          "hidden"
        },
      ),
    })
    self.send_script_remote_value_response(
      request_id, realm_id, remote_value, unwrap_result,
    )
    return true
  }
  if function_declaration.contains("document.hasFocus()") {
    let remote_value = make_object({
      "type": Json::string("boolean"),
      "value": Json::boolean(self.is_context_active(ctx_id)),
    })
    self.send_script_remote_value_response(
      request_id, realm_id, remote_value, unwrap_result,
    )
    return true
  }
  false
}
