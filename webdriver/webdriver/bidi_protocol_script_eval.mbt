///|
fn resolve_sync_await_expression_fallback(expression : String) -> String? {
  let expr = expression.trim().to_owned()
  if expr.has_prefix("Promise.resolve(") && expr.has_suffix(")") {
    return Some(expr.unsafe_substring(start=16, end=expr.length() - 1))
  }
  if expr.contains("await ") ||
    expr.contains("new Promise") ||
    expr.contains("Promise.") ||
    expr.contains(".then(") ||
    expr.contains("fetch(") {
    return None
  }
  Some(expr)
}

///|
fn resolve_sync_await_call_expression(
  function_declaration : String,
  this_json : String,
  args_json : String,
) -> String? {
  let trimmed = function_declaration.trim().to_owned()
  let normalized = if trimmed.has_prefix("async ") {
    let sync_body = trimmed.unsafe_substring(start=6, end=trimmed.length())
    if sync_body.contains("await ") ||
      sync_body.contains("new Promise") ||
      sync_body.contains("Promise.") ||
      sync_body.contains(".then(") ||
      sync_body.contains("fetch(") {
      return None
    }
    sync_body
  } else {
    if trimmed.contains("await ") ||
      trimmed.contains("new Promise") ||
      trimmed.contains("Promise.") ||
      trimmed.contains(".then(") ||
      trimmed.contains("fetch(") {
      return None
    }
    trimmed
  }
  if args_json == "" {
    Some("(" + normalized + ").call(" + this_json + ")")
  } else {
    Some("(" + normalized + ").call(" + this_json + ", " + args_json + ")")
  }
}

///|
fn BidiProtocol::try_send_sync_await_expression_fallback(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
  capture_console : Bool,
  user_activation : Bool,
  root_ownership : Bool,
  serialization_options_json : String,
  unwrap_result : Bool,
) -> Bool {
  let sync_expr = match resolve_sync_await_expression_fallback(expression) {
    Some(sync_expr) => sync_expr
    None => return false
  }
  let eval_result_json = evaluate_js_with_console(
    sync_expr, capture_console, user_activation, root_ownership, serialization_options_json,
  )
  let eval_result = @json.parse(eval_result_json) catch {
    _ => {
      self.send_error(
        request_id, "unknown error", "Failed to parse eval result",
      )
      return true
    }
  }
  if capture_console {
    self.process_console_entries(eval_result, ctx_id, realm_id)
  }
  self.emit_synthetic_mutation_observer_messages(ctx_id, realm_id, expression)
  let eval_result = self.maybe_adjust_document_dimensions_eval_result(
    expression, eval_result,
  )
  match get_string_field(eval_result, "type") {
    Some("success") => {
      self.apply_synthetic_history_state_from_expression(ctx_id, expression)
      let bidi_value = maybe_normalize_all_events_remote_value(
        expression,
        get_field(eval_result, "result").unwrap_or(
          make_object({ "type": Json::string("undefined") }),
        ),
      )
      self.send_script_remote_value_response(
        request_id, realm_id, bidi_value, unwrap_result,
      )
    }
    _ =>
      self.send_script_eval_result_mode(
        request_id, realm_id, eval_result, unwrap_result,
      )
  }
  true
}

///|
fn BidiProtocol::try_send_sync_await_call_fallback(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
  params : Json?,
  this_json : String,
  args_json : String,
  capture_console : Bool,
  user_activation : Bool,
  root_ownership : Bool,
  serialization_options_json : String,
  unwrap_result : Bool,
) -> Bool {
  let sync_call_expr = match
    resolve_sync_await_call_expression(
      function_declaration, this_json, args_json,
    ) {
    Some(sync_call_expr) => sync_call_expr
    None => return false
  }
  let eval_result_json = evaluate_js_with_console(
    sync_call_expr, capture_console, user_activation, root_ownership, serialization_options_json,
  )
  let eval_result = @json.parse(eval_result_json) catch {
    _ => {
      self.send_error(
        request_id, "unknown error", "Failed to parse eval result",
      )
      return true
    }
  }
  if capture_console {
    self.process_console_entries(eval_result, ctx_id, realm_id)
  }
  self.process_channel_messages(ctx_id, realm_id)
  match get_string_field(eval_result, "type") {
    Some("success") => {
      self.apply_synthetic_history_state_from_call(
        ctx_id,
        function_declaration,
        None,
      )
      self.apply_synthetic_location_assignment_from_call(
        ctx_id,
        function_declaration,
        None,
      )
      self.remember_network_state_channel_if_applicable(
        ctx_id, function_declaration, params,
      )
      let bidi_value = get_field(eval_result, "result").unwrap_or(
        make_object({ "type": Json::string("undefined") }),
      )
      if should_capture_focus_target(function_declaration, bidi_value) {
        self.remember_focused_element_remote(bidi_value)
      }
      self.send_script_remote_value_response(
        request_id, realm_id, bidi_value, unwrap_result,
      )
    }
    Some("exception") => {
      if self.try_send_synthetic_scroll_call_fallback(
          request_id, ctx_id, realm_id, function_declaration, capture_console, user_activation,
          root_ownership, serialization_options_json, unwrap_result,
        ) {
        return true
      }
      self.send_script_eval_result_mode(
        request_id, realm_id, eval_result, unwrap_result,
      )
    }
    _ =>
      self.send_script_eval_result_mode(
        request_id, realm_id, eval_result, unwrap_result,
      )
  }
  true
}

///|
fn BidiProtocol::handle_script_evaluate(
  self : BidiProtocol,
  request : BidiRequest,
  unwrap_result : Bool,
) -> Unit {
  match get_param_raw(request.params, "expression") {
    Some(String(_)) => ()
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "expression must be a string",
      )
      return
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing expression")
      return
    }
  }
  match self.validate_script_target(request.id, request.params) {
    Some(_) => return
    None => ()
  }
  match self.validate_await_promise(request.id, request.params) {
    Some(_) => return
    None => ()
  }
  match self.validate_result_ownership(request.id, request.params) {
    Some(_) => return
    None => ()
  }
  match self.validate_serialization_options(request.id, request.params) {
    Some(_) => return
    None => ()
  }
  match self.validate_user_activation(request.id, request.params) {
    Some(_) => return
    None => ()
  }

  let (ctx_id, realm_id) = self.resolve_target_context_realm(request.params)
  let runtime_ctx_id = resolve_runtime_context_id(
    request.params,
    ctx_id,
    realm_id,
    self.realm_sandbox.get(realm_id) != None,
  )
  let await_promise = match
    get_param_raw_with_alias(request.params, "awaitPromise", "await_promise") {
    Some(True) => true
    _ => false
  }
  let root_ownership = match
    get_param_raw_with_alias(
      request.params,
      "resultOwnership",
      "result_ownership",
    ) {
    Some(String("root")) => true
    _ => false
  }
  let user_activation = get_user_activation_value(request.params)
  let expr = get_string_param(request.params, "expression").unwrap()
  if self.try_handle_synthetic_all_events_eval(
      request.id,
      ctx_id,
      realm_id,
      expr,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_register_service_worker_eval(
      request.id,
      realm_id,
      expr,
    ) {
    return
  }
  if self.try_handle_synthetic_speculation_eval(
      request.id,
      ctx_id,
      realm_id,
      expr,
    ) {
    return
  }
  if self.try_handle_synthetic_user_prompt(
      request.id,
      ctx_id,
      realm_id,
      expr,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_download(request.id, ctx_id, realm_id, expr) {
    return
  }
  if self.try_handle_synthetic_iframe_remove(request.id, ctx_id, realm_id, expr) {
    return
  }
  if self.try_handle_synthetic_document_write_eval(
      request.id,
      ctx_id,
      realm_id,
      expr,
    ) {
    return
  }
  if self.try_handle_synthetic_window_location_href_eval(
      request.id,
      ctx_id,
      realm_id,
      expr,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_bluetooth_availability_eval(
      request.id,
      ctx_id,
      realm_id,
      expr,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_user_agent_fetch_eval(
      request.id,
      ctx_id,
      realm_id,
      expr,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_locale_eval(
      request.id,
      ctx_id,
      realm_id,
      expr,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_timezone_eval(
      request.id,
      ctx_id,
      realm_id,
      expr,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_document_cookie_eval(
      request.id,
      ctx_id,
      realm_id,
      expr,
      unwrap_result,
    ) {
    return
  }
  let serialization_options_json = get_serialization_options_json(
    request.params,
  )
  let has_serialization_options = has_serialization_options_param(
    request.params,
  )
  let capture_console = self.should_capture_console(ctx_id)
  set_runtime_context(runtime_ctx_id)
  set_runtime_context_frames(
    runtime_ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(runtime_ctx_id, ctx_id)
  if self.try_handle_synthetic_file_dialog_eval(
      request.id,
      ctx_id,
      realm_id,
      expr,
      unwrap_result,
      capture_console,
      user_activation,
      root_ownership,
      serialization_options_json,
    ) {
    return
  }
  if self.try_handle_window_open(
      request.id,
      ctx_id,
      realm_id,
      expr,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_iframe_creation(
      request.id,
      ctx_id,
      realm_id,
      expr,
    ) {
    return
  }
  let needs_mutation_observer_sync = expr.contains("setAttribute(") &&
    self.has_mutation_observer_preload_for_context(ctx_id)

  if self.use_quickjs && @runtime.is_quickjs_initialized() && !unwrap_result {
    match self.socket {
      Some(socket) => {
        @runtime.quickjs_eval_ws(socket, request.id, expr, ctx_id)
        return
      }
      None => {
        self.send_error(
          request.id,
          "unknown error",
          "QuickJS requires WebSocket for async evaluation",
        )
        return
      }
    }
  }

  if self.dom_initialized &&
    !capture_console &&
    !await_promise &&
    !root_ownership &&
    !has_serialization_options &&
    !unwrap_result {
    let raw = js_evaluate_expression_fast(
      request.id,
      expr,
      user_activation,
      realm_id,
      ctx_id,
    )
    self.send_raw(raw)
    return
  }

  if await_promise && !needs_mutation_observer_sync {
    if !self.dom_initialized {
      let _ = evaluate_js_with_console("undefined", false, false, false, "{}")
      self.dom_initialized = true
    }
    if !root_ownership &&
      !has_serialization_options &&
      self.try_send_sync_await_expression_fallback(
        request.id,
        ctx_id,
        realm_id,
        expr,
        capture_console,
        user_activation,
        root_ownership,
        serialization_options_json,
        unwrap_result,
      ) {
      return
    }
    match self.socket {
      Some(socket) => {
        eval_and_send_async_with_console(
          socket,
          request.id,
          expr,
          runtime_ctx_id,
          realm_id,
          capture_console,
          user_activation,
          root_ownership,
          unwrap_result,
        )
        return
      }
      None =>
        if !root_ownership && !has_serialization_options {
          let eval_result_json = js_await_promise(
            js_evaluate_expression_async(expr, user_activation, runtime_ctx_id),
          )
          self.dom_initialized = true
          let eval_result = @json.parse(eval_result_json) catch {
            _ => {
              self.send_error(
                request.id,
                "unknown error",
                "Failed to parse eval result",
              )
              return
            }
          }
          if capture_console {
            self.process_console_entries(eval_result, ctx_id, realm_id)
          }
          self.emit_synthetic_mutation_observer_messages(ctx_id, realm_id, expr)
          let eval_result = self.maybe_adjust_document_dimensions_eval_result(
            expr, eval_result,
          )
          match get_string_field(eval_result, "type") {
            Some("success") => {
              self.apply_synthetic_history_state_from_expression(ctx_id, expr)
              let bidi_value = maybe_normalize_all_events_remote_value(
                expr,
                get_field(eval_result, "result").unwrap_or(
                  make_object({ "type": Json::string("undefined") }),
                ),
              )
              self.send_script_remote_value_response(
                request.id,
                realm_id,
                bidi_value,
                unwrap_result,
              )
            }
            _ =>
              self.send_script_eval_result_mode(
                request.id,
                realm_id,
                eval_result,
                unwrap_result,
              )
          }
          return
        }
    }
  }

  let eval_result_json = evaluate_js_with_console(
    expr, capture_console, user_activation, root_ownership, serialization_options_json,
  )
  self.dom_initialized = true
  let eval_result = @json.parse(eval_result_json) catch {
    _ => {
      self.send_error(
        request.id,
        "unknown error",
        "Failed to parse eval result",
      )
      return
    }
  }
  if capture_console {
    self.process_console_entries(eval_result, ctx_id, realm_id)
  }
  self.emit_synthetic_mutation_observer_messages(ctx_id, realm_id, expr)
  let eval_result = self.maybe_adjust_document_dimensions_eval_result(
    expr, eval_result,
  )
  match get_string_field(eval_result, "type") {
    Some("success") => {
      self.apply_synthetic_history_state_from_expression(ctx_id, expr)
      let bidi_value = maybe_normalize_all_events_remote_value(
        expr,
        get_field(eval_result, "result").unwrap_or(
          make_object({ "type": Json::string("undefined") }),
        ),
      )
      self.send_script_remote_value_response(
        request.id,
        realm_id,
        bidi_value,
        unwrap_result,
      )
    }
    _ =>
      self.send_script_eval_result_mode(
        request.id,
        realm_id,
        eval_result,
        unwrap_result,
      )
  }
}

///|
fn BidiProtocol::handle_script_call_function(
  self : BidiProtocol,
  request : BidiRequest,
  unwrap_result : Bool,
) -> Unit {
  match
    get_param_raw_with_alias(
      request.params,
      "functionDeclaration",
      "function_declaration",
    ) {
    Some(String(_)) => ()
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "functionDeclaration must be a string",
      )
      return
    }
    None => {
      self.send_error(
        request.id,
        "invalid argument",
        "Missing functionDeclaration",
      )
      return
    }
  }
  match self.validate_script_target(request.id, request.params) {
    Some(_) => return
    None => ()
  }
  match self.validate_await_promise(request.id, request.params) {
    Some(_) => return
    None => ()
  }
  match self.validate_result_ownership(request.id, request.params) {
    Some(_) => return
    None => ()
  }
  match self.validate_serialization_options(request.id, request.params) {
    Some(_) => return
    None => ()
  }
  match self.validate_user_activation(request.id, request.params) {
    Some(_) => return
    None => ()
  }

  let (ctx_id_call, realm_id_call) = self.resolve_target_context_realm(
    request.params,
  )
  let runtime_ctx_id_call = resolve_runtime_context_id(
    request.params,
    ctx_id_call,
    realm_id_call,
    self.realm_sandbox.get(realm_id_call) != None,
  )
  let capture_console_call = self.should_capture_console(ctx_id_call)
  let await_promise_call = match
    get_param_raw_with_alias(request.params, "awaitPromise", "await_promise") {
    Some(True) => true
    _ => false
  }
  let root_ownership_call = match
    get_param_raw_with_alias(
      request.params,
      "resultOwnership",
      "result_ownership",
    ) {
    Some(String("root")) => true
    _ => false
  }
  let user_activation_call = get_user_activation_value(request.params)
  let serialization_options_json_call = get_serialization_options_json(
    request.params,
  )
  let has_serialization_options_call = has_serialization_options_param(
    request.params,
  )
  set_runtime_context(runtime_ctx_id_call)
  set_runtime_context_frames(
    runtime_ctx_id_call,
    self.context_children.get(ctx_id_call).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(
    runtime_ctx_id_call, ctx_id_call,
  )

  match self.validate_this_param(request.id, request.params) {
    Some(_) => return
    None => ()
  }
  match self.validate_arguments_param(request.id, request.params) {
    Some(_) => return
    None => ()
  }

  let args_json = match get_param_raw(request.params, "arguments") {
    Some(Array(args)) => {
      let parts : Array[String] = []
      for arg in args {
        parts.push(bidi_value_to_js_literal(arg))
      }
      parts.join(", ")
    }
    _ => ""
  }
  let this_json = match get_param_raw(request.params, "this") {
    Some(value) => bidi_value_to_js_literal(value)
    None => "undefined"
  }
  let func = match
    get_param_raw_with_alias(
      request.params,
      "functionDeclaration",
      "function_declaration",
    ) {
    Some(String(func)) => func
    _ => ""
  }
  if self.try_handle_synthetic_document_status_call(
      request.id,
      ctx_id_call,
      realm_id_call,
      func,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_bluetooth_request_device_call(
      request.id,
      ctx_id_call,
      realm_id_call,
      func,
      request.params,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_bluetooth_gatt_call(
      request.id,
      ctx_id_call,
      realm_id_call,
      func,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_window_location_origin_call(
      request.id,
      ctx_id_call,
      realm_id_call,
      func,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_network_conditions_fetch_call(
      request.id,
      ctx_id_call,
      realm_id_call,
      func,
      request.params,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_permissions_query_call(
      request.id,
      ctx_id_call,
      realm_id_call,
      func,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_geolocation_call(
      request.id,
      ctx_id_call,
      realm_id_call,
      func,
      request.params,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_local_storage_call(
      request.id,
      ctx_id_call,
      realm_id_call,
      func,
      request.params,
      unwrap_result,
    ) {
    return
  }
  if self.try_handle_synthetic_history_document_open_call(
      request.id,
      ctx_id_call,
      realm_id_call,
      func,
    ) {
    return
  }
  let function_is_async = func.trim().has_prefix("async")
  let call_expr = if args_json == "" {
    "(" + func + ").call(" + this_json + ")"
  } else {
    "(" + func + ").call(" + this_json + ", " + args_json + ")"
  }

  if self.use_quickjs && @runtime.is_quickjs_initialized() && !unwrap_result {
    match self.socket {
      Some(socket) => {
        @runtime.quickjs_eval_ws(socket, request.id, call_expr, ctx_id_call)
        return
      }
      None => {
        self.send_error(
          request.id,
          "unknown error",
          "QuickJS requires WebSocket for async evaluation",
        )
        return
      }
    }
  }

  if await_promise_call &&
    (!has_serialization_options_call || function_is_async) {
    if !self.dom_initialized {
      let _ = evaluate_js_with_console("undefined", false, false, false, "{}")
      self.dom_initialized = true
    }
    if !root_ownership_call &&
      !has_serialization_options_call &&
      self.try_send_sync_await_call_fallback(
        request.id,
        ctx_id_call,
        realm_id_call,
        func,
        request.params,
        this_json,
        args_json,
        capture_console_call,
        user_activation_call,
        root_ownership_call,
        serialization_options_json_call,
        unwrap_result,
      ) {
      return
    }
    match self.socket {
      Some(socket) => {
        eval_and_send_async_with_console(
          socket,
          request.id,
          call_expr,
          runtime_ctx_id_call,
          realm_id_call,
          capture_console_call,
          user_activation_call,
          root_ownership_call,
          unwrap_result,
        )
        return
      }
      None =>
        if !root_ownership_call && !has_serialization_options_call {
          let eval_result_json = js_await_promise(
            js_evaluate_expression_async(
              call_expr, user_activation_call, runtime_ctx_id_call,
            ),
          )
          let eval_result = @json.parse(eval_result_json) catch {
            _ => {
              self.send_error(
                request.id,
                "unknown error",
                "Failed to parse eval result",
              )
              return
            }
          }
          if capture_console_call {
            self.process_console_entries(
              eval_result, ctx_id_call, realm_id_call,
            )
          }
          self.process_channel_messages(ctx_id_call, realm_id_call)
          match get_string_field(eval_result, "type") {
            Some("success") => {
              self.apply_synthetic_history_state_from_call(
                ctx_id_call,
                func,
                request.params,
              )
              self.apply_synthetic_location_assignment_from_call(
                ctx_id_call,
                func,
                request.params,
              )
              let bidi_value = get_field(eval_result, "result").unwrap_or(
                make_object({ "type": Json::string("undefined") }),
              )
              if should_capture_focus_target(func, bidi_value) {
                self.remember_focused_element_remote(bidi_value)
              }
              self.send_script_remote_value_response(
                request.id,
                realm_id_call,
                bidi_value,
                unwrap_result,
              )
            }
            Some("exception") => {
              if self.try_send_synthetic_scroll_call_fallback(
                  request.id,
                  ctx_id_call,
                  realm_id_call,
                  func,
                  capture_console_call,
                  user_activation_call,
                  root_ownership_call,
                  serialization_options_json_call,
                  unwrap_result,
                ) {
                return
              }
              self.send_script_eval_result_mode(
                request.id,
                realm_id_call,
                eval_result,
                unwrap_result,
              )
            }
            _ =>
              self.send_script_eval_result_mode(
                request.id,
                realm_id_call,
                eval_result,
                unwrap_result,
              )
          }
          return
        }
    }
  }

  let eval_result_json = evaluate_js_with_console(
    call_expr, capture_console_call, user_activation_call, root_ownership_call, serialization_options_json_call,
  )
  let eval_result = @json.parse(eval_result_json) catch {
    _ => {
      self.send_error(
        request.id,
        "unknown error",
        "Failed to parse eval result",
      )
      return
    }
  }
  if capture_console_call {
    self.process_console_entries(eval_result, ctx_id_call, realm_id_call)
  }
  self.process_channel_messages(ctx_id_call, realm_id_call)
  match get_string_field(eval_result, "type") {
    Some("success") => {
      self.apply_synthetic_history_state_from_call(
        ctx_id_call,
        func,
        request.params,
      )
      self.apply_synthetic_location_assignment_from_call(
        ctx_id_call,
        func,
        request.params,
      )
      let bidi_value = get_field(eval_result, "result").unwrap_or(
        make_object({ "type": Json::string("undefined") }),
      )
      if should_capture_focus_target(func, bidi_value) {
        self.remember_focused_element_remote(bidi_value)
      }
      self.send_script_remote_value_response(
        request.id,
        realm_id_call,
        bidi_value,
        unwrap_result,
      )
    }
    Some("exception") => {
      if self.try_send_synthetic_scroll_call_fallback(
          request.id,
          ctx_id_call,
          realm_id_call,
          func,
          capture_console_call,
          user_activation_call,
          root_ownership_call,
          serialization_options_json_call,
          unwrap_result,
        ) {
        return
      }
      self.send_script_eval_result_mode(
        request.id,
        realm_id_call,
        eval_result,
        unwrap_result,
      )
    }
    _ =>
      self.send_script_eval_result_mode(
        request.id,
        realm_id_call,
        eval_result,
        unwrap_result,
      )
  }
}
