///|
/// WebDriver BiDi Protocol (minimal)
///
/// Focuses on a BiDi-first automation surface while reusing CDP sessions.
/// This is intentionally small and grows as coverage expands.

///|
/// BiDi request message
pub struct BidiRequest {
  id : Int
  method_name : String
  params : Json?
} derive(Show)

///|
/// BiDi response message
pub struct BidiResponse {
  id : Int
  result : Json?
  error : BidiError?
} derive(Show)

///|
/// BiDi error payload
pub struct BidiError {
  error : String
  message : String
  stacktrace : String
} derive(Show)

///|
/// BiDi event message
pub struct BidiEvent {
  event_method : String
  params : Json
} derive(Show)

///|
/// Outgoing BiDi message
pub enum BidiOutMessage {
  Response(BidiResponse)
  Event(BidiEvent)
  Raw(String)
} derive(Show)

///|
/// BiDi protocol handler
pub struct BidiProtocol {
  manager : CdpSessionManager
  mut outbox : Array[BidiOutMessage]
  mut session_id : String?
  mut default_context_id : String?
  mut next_navigation_id : Int
  mut next_realm_id : Int
  subscriptions : Map[String, Bool] // module-level subscriptions (legacy)
  context_subscriptions : Map[String, Array[String]] // context -> events
  mut global_subscriptions : Array[String] // events subscribed globally
  mut global_unsubscribed_events : Array[String] // event-level overrides for module subscriptions
  user_contexts : Map[String, Bool]
  context_user_context : Map[String, String]
  context_original_opener : Map[String, String]
  context_realm : Map[String, String]
  context_sandbox_realm : Map[String, String] // "<context>::<sandbox>" -> realm
  realm_context : Map[String, String] // realm -> context
  realm_sandbox : Map[String, String] // sandbox realm -> sandbox name
  context_parent : Map[String, String]
  context_children : Map[String, Array[String]]
  context_client_window : Map[String, String]
  mut socket : @core.Any? // WebSocket for async responses
  mut use_quickjs : Bool // Use QuickJS sandboxed runtime for script execution
  mut dom_initialized : Bool // Deno-side mock DOM initialized
}

///|
/// Create new BiDi protocol instance
pub fn BidiProtocol::new() -> BidiProtocol {
  let user_contexts : Map[String, Bool] = {}
  user_contexts["default"] = true
  {
    manager: CdpSessionManager::new(),
    outbox: [],
    session_id: None,
    default_context_id: None,
    next_navigation_id: 1,
    next_realm_id: 1,
    subscriptions: {},
    context_subscriptions: {},
    global_subscriptions: [],
    global_unsubscribed_events: [],
    user_contexts,
    context_user_context: {},
    context_original_opener: {},
    context_realm: {},
    context_sandbox_realm: {},
    realm_context: {},
    realm_sandbox: {},
    context_parent: {},
    context_children: {},
    context_client_window: {},
    socket: None,
    use_quickjs: false,
    dom_initialized: false,
  }
}

///|
/// Enable QuickJS sandboxed runtime for script execution
pub fn BidiProtocol::enable_quickjs(self : BidiProtocol) -> Unit {
  self.use_quickjs = true
}

///|
/// Disable QuickJS (use Deno eval)
pub fn BidiProtocol::disable_quickjs(self : BidiProtocol) -> Unit {
  self.use_quickjs = false
}

///|
/// Check if QuickJS is enabled
pub fn BidiProtocol::is_quickjs_enabled(self : BidiProtocol) -> Bool {
  self.use_quickjs
}

///|
/// Set WebSocket for async responses
pub fn BidiProtocol::set_socket(
  self : BidiProtocol,
  socket : @core.Any,
) -> Unit {
  self.socket = Some(socket)
}

///|
/// Clear WebSocket reference
pub fn BidiProtocol::clear_socket(self : BidiProtocol) -> Unit {
  self.socket = None
}

///|
/// Process incoming JSON message
pub fn BidiProtocol::process_message(
  self : BidiProtocol,
  json_str : String,
) -> Result[Unit, String] {
  let json = @json.parse(json_str) catch { _ => return Err("Invalid JSON") }
  let id = match get_int_field(json, "id") {
    Some(i) => i
    None => return Err("Missing id field")
  }
  let method_name = match get_string_field(json, "method") {
    Some(m) => m
    None => return Err("Missing method field")
  }
  let params = get_field(json, "params")
  let request : BidiRequest = { id, method_name, params }
  self.dispatch(request)
}

///|
/// Take and clear outgoing messages
pub fn BidiProtocol::take_messages(
  self : BidiProtocol,
) -> Array[BidiOutMessage] {
  let out = self.outbox
  self.outbox = []
  out
}

///|
/// Convert outgoing message to JSON string
pub fn BidiOutMessage::to_json(self : BidiOutMessage) -> String {
  match self {
    Response(resp) => response_to_json(resp)
    Event(evt) => event_to_json(evt)
    Raw(raw) => raw
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
      let session_id = "bidi-" + request.id.to_string()
      self.session_id = Some(session_id)
      let ctx_id = self.ensure_default_context()
      let caps = self.build_capabilities()
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
      self.handle_subscribe(request.params)
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "unsubscribe" => {
      self.handle_unsubscribe(request.params)
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "end" => {
      self.session_id = None
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
      let contexts : Array[Json] = []
      for id, _ in self.user_contexts {
        contexts.push(make_object({ "userContext": Json::string(id) }))
      }
      let result = make_object({ "userContexts": Json::array(contexts) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "createUserContext" => {
      let id = "user-" + self.user_contexts.length().to_string()
      self.user_contexts[id] = true
      let result = make_object({ "userContext": Json::string(id) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "removeUserContext" =>
      match get_string_param(request.params, "userContext") {
        Some(id) => {
          self.user_contexts.remove(id)
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing userContext")
          Ok(())
        }
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
    "getTree" => {
      // Validate maxDepth parameter type and value
      match get_param_raw(request.params, "maxDepth") {
        Some(Number(n, ..)) => {
          // Check for valid non-negative integer
          // JSON numbers > 2^53 or floats or negative are invalid
          if n < 0.0 {
            self.send_error(
              request.id,
              "invalid argument",
              "maxDepth must be a non-negative integer",
            )
            return Ok(())
          }
          // Check if it's a float (has fractional part)
          let int_val = n.to_int64()
          if n != int_val.to_double() {
            self.send_error(
              request.id,
              "invalid argument",
              "maxDepth must be a non-negative integer",
            )
            return Ok(())
          }
          // Check for safe integer range (2^53)
          if n > 9007199254740991.0 {
            self.send_error(
              request.id,
              "invalid argument",
              "maxDepth must be a non-negative integer",
            )
            return Ok(())
          }
        }
        None => () // Valid: absent
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "maxDepth must be a non-negative integer",
          )
          return Ok(())
        }
      }
      // Validate root parameter - must be a string or absent
      match get_param_raw(request.params, "root") {
        Some(String(root_id)) =>
          // Root must be a known context
          if not(self.manager.has_session(root_id)) {
            self.send_error(
              request.id,
              "no such frame",
              "Unknown context: " + root_id,
            )
            return Ok(())
          }
        Some(True)
        | Some(False)
        | Some(Number(_))
        | Some(Array(_))
        | Some(Object(_))
        | Some(Null) => {
          self.send_error(
            request.id,
            "invalid argument",
            "root must be a string",
          )
          return Ok(())
        }
        None => () // No root specified, return all contexts
      }
      let max_depth = match get_param_raw(request.params, "maxDepth") {
        Some(Number(n, ..)) => Some(n.to_int64().to_int())
        _ => None
      }
      let contexts = match get_string_param(request.params, "root") {
        Some(root_id) =>
          match self.build_context_entry(root_id, true, 0, max_depth) {
            Some(entry) => {
              let single : Array[Json] = []
              single.push(entry)
              single
            }
            None => []
          }
        None => self.build_context_tree(max_depth)
      }
      let result = make_object({ "contexts": Json::array(contexts) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "create" => {
      let user_ctx = get_string_param(request.params, "userContext").unwrap_or(
        "default",
      )
      let ctx_id = self.create_context(user_ctx)
      let result = make_object({ "context": Json::string(ctx_id) })
      // Emit events before response for immediate listener availability.
      self.emit_context_created(ctx_id, "tab", "about:blank", None, None)
      self.emit_default_realm(ctx_id)
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "navigate" =>
      match
        (
          get_string_param(request.params, "context"),
          get_string_param(request.params, "url"),
        ) {
        (Some(ctx_id), Some(url)) =>
          match self.manager.get_session(ctx_id) {
            Some(session) =>
              match session.navigate_to(url) {
                Ok(_) => {
                  let nav_id = self.next_navigation_id.to_string()
                  self.next_navigation_id += 1
                  self.load_data_url_content(ctx_id, url)
                  self.drop_child_contexts(ctx_id)
                  self.refresh_child_contexts_from_iframes(ctx_id)
                  self.clear_context_sandbox_realms(ctx_id)
                  // Navigation replaces the default window realm.
                  let window_realm_id = self.assign_new_realm(ctx_id)
                  self.emit_default_realm(ctx_id)
                  self.emit_worker_realms_from_scripts(ctx_id, window_realm_id)
                  let result = make_object({
                    "navigation": Json::string(nav_id),
                    "url": Json::string(url),
                  })
                  // Send response BEFORE events (BiDi protocol requirement)
                  self.send_success(request.id, Some(result))
                  self.emit_navigation_events(ctx_id, url, nav_id)
                  Ok(())
                }
                Err(e) => {
                  self.send_error(
                    request.id,
                    "unknown error",
                    "Navigation failed: " + e.message,
                  )
                  Ok(())
                }
              }
            None => {
              self.send_error(
                request.id,
                "invalid argument",
                "Unknown context: " + ctx_id,
              )
              Ok(())
            }
          }
        _ => {
          self.send_error(request.id, "invalid argument", "Missing context/url")
          Ok(())
        }
      }
    "reload" =>
      match get_string_param(request.params, "context") {
        Some(ctx_id) =>
          match self.manager.get_session(ctx_id) {
            Some(session) => {
              let url = session.get_url()
              let nav_id = self.next_navigation_id.to_string()
              self.next_navigation_id += 1
              self.clear_context_sandbox_realms(ctx_id)
              // Reload creates a new realm.
              self.assign_new_realm(ctx_id) |> ignore
              self.emit_default_realm(ctx_id)
              self.emit_navigation_events(ctx_id, url, nav_id)
              self.send_success(request.id, Some(make_object({})))
              Ok(())
            }
            None => {
              self.send_error(
                request.id,
                "invalid argument",
                "Unknown context: " + ctx_id,
              )
              Ok(())
            }
          }
        None => {
          self.send_error(request.id, "invalid argument", "Missing context")
          Ok(())
        }
      }
    "close" =>
      match get_string_param(request.params, "context") {
        Some(ctx_id) => {
          let original_opener = self.context_original_opener.get(ctx_id)
          self.drop_child_contexts(ctx_id)
          self.unlink_from_parent(ctx_id)
          if self.manager.close_session(ctx_id) {
            // Send response BEFORE events (BiDi protocol requirement)
            self.send_success(request.id, Some(make_object({})))
            self.emit_context_destroyed(ctx_id, original_opener)
            self.context_parent.remove(ctx_id)
            self.context_children.remove(ctx_id)
            self.context_user_context.remove(ctx_id)
            self.context_original_opener.remove(ctx_id)
            match self.context_realm.get(ctx_id) {
              Some(realm_id) => {
                self.realm_context.remove(realm_id)
                self.realm_sandbox.remove(realm_id)
              }
              None => ()
            }
            self.context_realm.remove(ctx_id)
            self.clear_context_sandbox_realms(ctx_id)
            self.context_client_window.remove(ctx_id)
            match self.default_context_id {
              Some(default_ctx) =>
                if default_ctx == ctx_id {
                  self.default_context_id = None
                }
              None => ()
            }
          } else {
            self.send_error(
              request.id,
              "invalid argument",
              "Unknown context: " + ctx_id,
            )
          }
          Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing context")
          Ok(())
        }
      }
    "locateNodes" => {
      let result = make_object({ "nodes": Json::array([]) })
      self.send_success(request.id, Some(result))
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
    "evaluate" => {
      // Validate expression parameter - must be string
      match get_param_raw(request.params, "expression") {
        Some(String(_)) => ()
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "expression must be a string",
          )
          return Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing expression")
          return Ok(())
        }
      }
      // Validate target parameter
      match self.validate_script_target(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate awaitPromise - must be boolean
      match self.validate_await_promise(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate resultOwnership - must be "root" or "none"
      match self.validate_result_ownership(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate serializationOptions
      match self.validate_serialization_options(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate userActivation - must be boolean
      match self.validate_user_activation(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Resolve target context/realm for evaluation.
      let (ctx_id, realm_id) = self.resolve_target_context_realm(request.params)
      // Check if awaitPromise is true
      let await_promise = match get_param_raw(request.params, "awaitPromise") {
        Some(True) => true
        _ => false
      }
      let user_activation = get_user_activation_value(request.params)
      let expr = get_string_param(request.params, "expression").unwrap()
      // Handle window.open directly so browsing context state stays in sync.
      if self.try_handle_window_open(request.id, ctx_id, expr) {
        return Ok(())
      }
      let capture_console = self.is_subscribed_for_context(
          "log.entryAdded", ctx_id,
        ) ||
        self.is_subscribed("log")
      // Use QuickJS for sandboxed execution if enabled
      if self.use_quickjs && is_quickjs_initialized() {
        match self.socket {
          Some(socket) => {
            // QuickJS always needs async (due to ASYNCIFY)
            quickjs_eval_ws(socket, request.id, expr, ctx_id)
            return Ok(())
          }
          None => {
            // No socket - can't do sync evaluation with QuickJS ASYNCIFY
            self.send_error(
              request.id,
              "unknown error",
              "QuickJS requires WebSocket for async evaluation",
            )
            return Ok(())
          }
        }
      }
      // Fast path: no console capture, no awaitPromise, no QuickJS
      if self.dom_initialized && not(capture_console) && not(await_promise) {
        let raw = js_evaluate_expression_fast(
          request.id,
          expr,
          user_activation,
          realm_id,
        )
        self.send_raw(raw)
        return Ok(())
      }
      // If awaitPromise is true and we have a socket, use async evaluation
      if await_promise {
        match self.socket {
          Some(socket) => {
            // Async evaluation - response sent directly via WebSocket
            eval_and_send_async_with_console(
              socket,
              request.id,
              expr,
              ctx_id,
              capture_console,
              user_activation,
            )
            return Ok(()) // No sync response needed
          }
          None => () // Fall through to sync evaluation
        }
      }
      // Synchronous evaluation (Deno eval)
      let eval_result_json = evaluate_js_with_console(
        expr, capture_console, user_activation,
      )
      self.dom_initialized = true
      let eval_result = @json.parse(eval_result_json) catch {
        _ => {
          self.send_error(
            request.id,
            "unknown error",
            "Failed to parse eval result",
          )
          return Ok(())
        }
      }
      // Process console entries and emit log events BEFORE response
      if capture_console {
        self.process_console_entries(eval_result, ctx_id)
      }
      // Build response based on evaluation result
      match get_string_field(eval_result, "type") {
        Some("success") => {
          let bidi_value = get_field(eval_result, "result").unwrap_or(
            make_object({ "type": Json::string("undefined") }),
          )
          let result = make_object({
            "realm": Json::string(realm_id),
            "result": bidi_value,
          })
          self.send_success(request.id, Some(result))
        }
        Some("exception") => {
          let exc_details = get_field(eval_result, "exceptionDetails").unwrap_or(
            make_object({}),
          )
          let result = make_object({
            "realm": Json::string(realm_id),
            "exceptionDetails": exc_details,
          })
          self.send_success(request.id, Some(result))
        }
        _ => {
          let result = make_object({
            "realm": Json::string(realm_id),
            "result": make_object({ "type": Json::string("undefined") }),
          })
          self.send_success(request.id, Some(result))
        }
      }
      Ok(())
    }
    "callFunction" => {
      // Validate functionDeclaration - must be string
      match get_param_raw(request.params, "functionDeclaration") {
        Some(String(_)) => ()
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "functionDeclaration must be a string",
          )
          return Ok(())
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "Missing functionDeclaration",
          )
          return Ok(())
        }
      }
      // Validate target parameter
      match self.validate_script_target(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate awaitPromise - must be boolean
      match self.validate_await_promise(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate resultOwnership
      match self.validate_result_ownership(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate serializationOptions
      match self.validate_serialization_options(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate userActivation
      match self.validate_user_activation(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate this parameter - must be a serialized value (object with type)
      match self.validate_this_param(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate arguments parameter - must be array of serialized values
      match self.validate_arguments_param(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Resolve target context/realm for function call.
      let (ctx_id_call, realm_id_call) = self.resolve_target_context_realm(
        request.params,
      )
      let capture_console_call = self.is_subscribed_for_context(
          "log.entryAdded", ctx_id_call,
        ) ||
        self.is_subscribed("log")
      // Check if awaitPromise is true
      let await_promise_call = match
        get_param_raw(request.params, "awaitPromise") {
        Some(True) => true
        _ => false
      }
      let user_activation_call = get_user_activation_value(request.params)
      // Get arguments if provided
      let args_json = match get_param_raw(request.params, "arguments") {
        Some(Array(args)) => {
          // Convert BiDi values to JS literal representation
          let parts : Array[String] = []
          for arg in args {
            parts.push(bidi_value_to_js_literal(arg))
          }
          parts.join(", ")
        }
        _ => ""
      }
      // Wrap function declaration and call it
      let func = get_string_param(request.params, "functionDeclaration").unwrap()
      let call_expr = "(" + func + ")(" + args_json + ")"
      // Use QuickJS for sandboxed execution if enabled
      if self.use_quickjs && is_quickjs_initialized() {
        match self.socket {
          Some(socket) => {
            // QuickJS always needs async (due to ASYNCIFY)
            quickjs_eval_ws(socket, request.id, call_expr, ctx_id_call)
            return Ok(())
          }
          None => {
            self.send_error(
              request.id,
              "unknown error",
              "QuickJS requires WebSocket for async evaluation",
            )
            return Ok(())
          }
        }
      }
      // If awaitPromise is true and we have a socket, use async evaluation
      if await_promise_call {
        match self.socket {
          Some(socket) => {
            // Async evaluation - response sent directly via WebSocket
            eval_and_send_async_with_console(
              socket,
              request.id,
              call_expr,
              ctx_id_call,
              capture_console_call,
              user_activation_call,
            )
            return Ok(()) // No sync response needed
          }
          None => () // Fall through to sync evaluation
        }
      }
      let eval_result_json = evaluate_js_with_console(
        call_expr, capture_console_call, user_activation_call,
      )
      let eval_result = @json.parse(eval_result_json) catch {
        _ => {
          self.send_error(
            request.id,
            "unknown error",
            "Failed to parse eval result",
          )
          return Ok(())
        }
      }
      // Process console entries and emit log events BEFORE response
      if capture_console_call {
        self.process_console_entries(eval_result, ctx_id_call)
      }
      // Build response based on evaluation result
      match get_string_field(eval_result, "type") {
        Some("success") => {
          let bidi_value = get_field(eval_result, "result").unwrap_or(
            make_object({ "type": Json::string("undefined") }),
          )
          let result = make_object({
            "realm": Json::string(realm_id_call),
            "result": bidi_value,
          })
          self.send_success(request.id, Some(result))
        }
        Some("exception") => {
          let exc_details = get_field(eval_result, "exceptionDetails").unwrap_or(
            make_object({}),
          )
          let result = make_object({
            "realm": Json::string(realm_id_call),
            "exceptionDetails": exc_details,
          })
          self.send_success(request.id, Some(result))
        }
        _ => {
          let result = make_object({
            "realm": Json::string(realm_id_call),
            "result": make_object({ "type": Json::string("undefined") }),
          })
          self.send_success(request.id, Some(result))
        }
      }
      Ok(())
    }
    "addPreloadScript" => {
      // Return a fake script ID
      let script_id = "preload-" + self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      let result = make_object({ "script": Json::string(script_id) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "removePreloadScript" => {
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "getRealms" => {
      // Validate optional context parameter
      let context_filter = match get_param_raw(request.params, "context") {
        Some(String(ctx_id)) => {
          if not(self.manager.has_session(ctx_id)) {
            self.send_error(
              request.id,
              "no such frame",
              "Unknown context: " + ctx_id,
            )
            return Ok(())
          }
          Some(ctx_id)
        }
        None => None
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "context must be a string",
          )
          return Ok(())
        }
      }
      // Validate optional type parameter
      match get_param_raw(request.params, "type") {
        Some(String(t)) =>
          if t != "window" {
            self.send_error(
              request.id,
              "invalid argument",
              "type must be 'window'",
            )
            return Ok(())
          }
        None => ()
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "type must be a string",
          )
          return Ok(())
        }
      }

      // Return one realm per known top-level context.
      let realms : Array[Json] = []
      for ctx_id in self.manager.list_sessions() {
        let should_include = match context_filter {
          Some(filter_ctx) => filter_ctx == ctx_id
          None => true
        }
        if should_include {
          let realm_id = self.context_realm
            .get(ctx_id)
            .unwrap_or("realm-" + ctx_id)
          let origin = self.get_context_origin(ctx_id)
          realms.push(
            make_object({
              "realm": Json::string(realm_id),
              "context": Json::string(ctx_id),
              "type": Json::string("window"),
              "origin": Json::string(origin),
              "sandbox": Json::null(),
            }),
          )
          let prefix = ctx_id + "::"
          for key, sandbox_realm in self.context_sandbox_realm {
            if key.has_prefix(prefix) {
              let sandbox_name = key[prefix.length():].to_string() catch {
                _ => ""
              }
              realms.push(
                make_object({
                  "realm": Json::string(sandbox_realm),
                  "context": Json::string(ctx_id),
                  "type": Json::string("window"),
                  "origin": Json::string(origin),
                  "sandbox": Json::string(sandbox_name),
                }),
              )
            }
          }
        }
      }
      let result = make_object({ "realms": Json::array(realms) })
      self.send_success(request.id, Some(result))
      Ok(())
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
/// Dispatch input domain (no-op for now)
fn BidiProtocol::dispatch_input(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "performActions" | "releaseActions" => {
      self.send_success(request.id, Some(make_object({})))
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
/// Dispatch network domain (minimal no-op)
fn BidiProtocol::dispatch_network(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "addDataCollector" | "setCacheBehavior" => {
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown network method: " + action,
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

///|
/// Emit log.entryAdded event
pub fn BidiProtocol::emit_log_entry(
  self : BidiProtocol,
  ctx_id : String,
  level : String,
  text : String,
  console_method : String,
) -> Unit {
  if not(self.is_subscribed_for_context("log.entryAdded", ctx_id)) {
    return
  }
  let timestamp = 0.0 // Would be actual timestamp in real impl
  let params = make_object({
    "level": Json::string(level),
    "source": make_object({
      "realm": Json::string("realm-" + ctx_id),
      "context": Json::string(ctx_id),
    }),
    "text": Json::string(text),
    "timestamp": Json::number(timestamp),
    "method": Json::string(console_method),
    "args": Json::array([]),
    "type": Json::string("console"),
  })
  self.outbox.push(Event({ event_method: "log.entryAdded", params }))
}

///|
/// Process console entries from JS evaluation result and emit log events
fn BidiProtocol::process_console_entries(
  self : BidiProtocol,
  eval_result : Json,
  ctx_id : String,
) -> Unit {
  match get_field(eval_result, "consoleEntries") {
    Some(Array(entries)) =>
      for entry in entries {
        match entry {
          Object(_) => {
            let level = get_string_field(entry, "level").unwrap_or("info")
            let console_method = get_string_field(entry, "method").unwrap_or(
              "log",
            )
            let text = get_string_field(entry, "text").unwrap_or("")
            self.emit_log_entry(ctx_id, level, text, console_method)
          }
          _ => ()
        }
      }
    _ => ()
  }
}

// =============================================================================
// Helpers
// =============================================================================

///|
/// Ensure default context exists and return its ID
fn BidiProtocol::ensure_default_context(self : BidiProtocol) -> String {
  match self.default_context_id {
    Some(id) => id
    None => {
      let id = self.create_context("default")
      self.default_context_id = Some(id)
      id
    }
  }
}

///|
/// Create a new browsing context backed by a CDP session
fn BidiProtocol::create_context(
  self : BidiProtocol,
  user_context_id : String,
) -> String {
  let id = self.manager.create_session()
  self.context_user_context[id] = user_context_id
  self.context_children[id] = []
  self.context_client_window[id] = "client-window-" + id
  self.context_parent.remove(id)
  if not(self.user_contexts.contains(user_context_id)) {
    self.user_contexts[user_context_id] = true
  }
  self.assign_new_realm(id) |> ignore
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
  if not(self.user_contexts.contains(user_context_id)) {
    self.user_contexts[user_context_id] = true
  }
  self.assign_new_realm(id) |> ignore
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
/// Remove all descendant browsing contexts under a parent context.
fn BidiProtocol::drop_child_contexts(
  self : BidiProtocol,
  parent_ctx_id : String,
) -> Unit {
  match self.context_children.get(parent_ctx_id) {
    Some(children) => {
      for child_ctx_id in children {
        self.drop_child_contexts(child_ctx_id)
        self.manager.close_session(child_ctx_id) |> ignore
        self.context_parent.remove(child_ctx_id)
        self.context_children.remove(child_ctx_id)
        self.context_user_context.remove(child_ctx_id)
        self.context_original_opener.remove(child_ctx_id)
        match self.context_realm.get(child_ctx_id) {
          Some(realm_id) => {
            self.realm_context.remove(realm_id)
            self.realm_sandbox.remove(realm_id)
          }
          None => ()
        }
        self.context_realm.remove(child_ctx_id)
        self.clear_context_sandbox_realms(child_ctx_id)
        self.context_client_window.remove(child_ctx_id)
      }
      self.context_children[parent_ctx_id] = []
    }
    None => ()
  }
}

///|
/// Load inline HTML content when URL is a data URL.
fn BidiProtocol::load_data_url_content(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
) -> Unit {
  if not(url.has_prefix("data:")) {
    match self.manager.get_session(ctx_id) {
      Some(session) => session.load_html("")
      None => ()
    }
    return
  }
  match parse_data_url(url) {
    Some((content_type, content)) =>
      if content_type.has_prefix("text/html") || content_type == "" {
        match self.manager.get_session(ctx_id) {
          Some(session) => session.load_html(content)
          None => ()
        }
      }
    None => ()
  }
}

///|
/// Collect iframe src values from a context document.
fn BidiProtocol::collect_iframe_sources(
  self : BidiProtocol,
  ctx_id : String,
) -> Array[String] {
  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let doc = session.get_tree().get_document()
      match session.get_tree().query_selector_all(doc, "iframe") {
        Ok(nodes) => {
          let sources : Array[String] = []
          for node in nodes {
            match session.get_tree().get_attribute(node, "src") {
              Ok(Some(src)) => sources.push(src)
              _ => sources.push("about:blank")
            }
          }
          sources
        }
        Err(_) => []
      }
    }
    None => []
  }
}

///|
/// Find substring position in a string from a start offset.
fn find_substring(haystack : String, needle : String, start : Int) -> Int? {
  let h = haystack.to_array()
  let n = needle.to_array()
  if n.length() == 0 {
    return Some(start)
  }
  if start < 0 || start >= h.length() || n.length() > h.length() {
    return None
  }
  for i = start; i + n.length() <= h.length(); i = i + 1 {
    let mut matched = true
    for j = 0; j < n.length(); j = j + 1 {
      if h[i + j] != n[j] {
        matched = false
        break
      }
    }
    if matched {
      return Some(i)
    }
  }
  None
}

///|
/// Extract quoted URL argument following a marker like "new Worker(".
fn extract_quoted_after_marker(source : String, marker : String) -> String? {
  match find_substring(source, marker, 0) {
    Some(marker_idx) => {
      let chars = source.to_array()
      let quote_start = marker_idx + marker.length()
      if quote_start >= chars.length() {
        return None
      }
      let quote = chars[quote_start]
      if quote != '"' && quote != '\'' {
        return None
      }
      let mut end = quote_start + 1
      while end < chars.length() && chars[end] != quote {
        end += 1
      }
      if end >= chars.length() {
        return None
      }
      let value = source[quote_start + 1:end].to_string() catch { _ => "" }
      if value.length() == 0 {
        None
      } else {
        Some(value)
      }
    }
    None => None
  }
}

///|
/// Collect inline script source texts from a context document.
fn BidiProtocol::collect_script_texts(
  self : BidiProtocol,
  ctx_id : String,
) -> Array[String] {
  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let doc = session.get_tree().get_document()
      match session.get_tree().query_selector_all(doc, "script") {
        Ok(nodes) => {
          let scripts : Array[String] = []
          for node in nodes {
            match session.get_tree().get_text_content(node) {
              Ok(text) => scripts.push(text)
              Err(_) => ()
            }
          }
          scripts
        }
        Err(_) => []
      }
    }
    None => []
  }
}

///|
/// Emit worker realmCreated event derived from script source.
fn BidiProtocol::emit_worker_realm_created(
  self : BidiProtocol,
  owner_ctx_id : String,
  worker_type : String,
  worker_origin : String,
  owner_realm_id : String,
) -> Unit {
  let event_name = "script.realmCreated"
  if not(self.is_subscribed_for_context(event_name, owner_ctx_id)) {
    return
  }
  let worker_realm_id = "realm-" + self.next_realm_id.to_string()
  self.next_realm_id += 1
  self.realm_context[worker_realm_id] = owner_ctx_id
  let params = if worker_type == "dedicated-worker" {
    let owners : Array[Json] = []
    owners.push(Json::string(owner_realm_id))
    make_object({
      "realm": Json::string(worker_realm_id),
      "type": Json::string(worker_type),
      "origin": Json::string(worker_origin),
      "owners": Json::array(owners),
    })
  } else {
    make_object({
      "realm": Json::string(worker_realm_id),
      "type": Json::string(worker_type),
      "origin": Json::string(worker_origin),
    })
  }
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit worker realms discovered in script tags after navigation.
fn BidiProtocol::emit_worker_realms_from_scripts(
  self : BidiProtocol,
  ctx_id : String,
  window_realm_id : String,
) -> Unit {
  let scripts = self.collect_script_texts(ctx_id)
  for script_source in scripts {
    match extract_quoted_after_marker(script_source, "new Worker(") {
      Some(worker_url) =>
        self.emit_worker_realm_created(
          ctx_id, "dedicated-worker", worker_url, window_realm_id,
        )
      None => ()
    }
    match extract_quoted_after_marker(script_source, "new SharedWorker(") {
      Some(worker_url) =>
        self.emit_worker_realm_created(
          ctx_id, "shared-worker", worker_url, window_realm_id,
        )
      None => ()
    }
    match
      extract_quoted_after_marker(script_source, "serviceWorker.register(") {
      Some(worker_url) =>
        self.emit_worker_realm_created(
          ctx_id, "service-worker", worker_url, window_realm_id,
        )
      None => ()
    }
  }
}

///|
/// Rebuild child contexts from iframe elements under a parent context.
fn BidiProtocol::refresh_child_contexts_from_iframes(
  self : BidiProtocol,
  parent_ctx_id : String,
) -> Unit {
  let frame_sources = self.collect_iframe_sources(parent_ctx_id)
  let user_ctx = self.context_user_context
    .get(parent_ctx_id)
    .unwrap_or("default")
  for src in frame_sources {
    let child_ctx_id = self.create_child_context(parent_ctx_id, user_ctx)
    match self.manager.get_session(child_ctx_id) {
      Some(child_session) => {
        let _ = child_session.navigate_to(src)
      }
      None => ()
    }
    self.load_data_url_content(child_ctx_id, src)
    self.emit_context_created(
      child_ctx_id,
      "tab",
      "about:blank",
      None,
      Some(parent_ctx_id),
    )
    self.emit_default_realm(child_ctx_id)
    let child_nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    self.emit_navigation_events(child_ctx_id, src, child_nav_id)
    self.refresh_child_contexts_from_iframes(child_ctx_id)
  }
}

///|
/// Assign a new realm id for a browsing context.
fn BidiProtocol::assign_new_realm(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.context_realm.get(ctx_id) {
    Some(old_realm) => {
      self.realm_context.remove(old_realm)
      self.realm_sandbox.remove(old_realm)
    }
    None => ()
  }
  let realm_id = "realm-" + self.next_realm_id.to_string()
  self.next_realm_id += 1
  self.context_realm[ctx_id] = realm_id
  self.realm_context[realm_id] = ctx_id
  realm_id
}

///|
/// Compute key for sandbox realm mapping.
fn make_sandbox_key(ctx_id : String, sandbox_name : String) -> String {
  ctx_id + "::" + sandbox_name
}

///|
/// Clear sandbox realms for a context.
fn BidiProtocol::clear_context_sandbox_realms(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let prefix = ctx_id + "::"
  let to_remove : Array[String] = []
  for key, realm_id in self.context_sandbox_realm {
    if key.has_prefix(prefix) {
      to_remove.push(key)
      self.realm_context.remove(realm_id)
      self.realm_sandbox.remove(realm_id)
    }
  }
  for key in to_remove {
    self.context_sandbox_realm.remove(key)
  }
}

///|
/// Get or create a sandbox realm for a context.
fn BidiProtocol::get_or_create_sandbox_realm(
  self : BidiProtocol,
  ctx_id : String,
  sandbox_name : String,
) -> String {
  let key = make_sandbox_key(ctx_id, sandbox_name)
  match self.context_sandbox_realm.get(key) {
    Some(realm_id) => realm_id
    None => {
      let realm_id = "realm-" + self.next_realm_id.to_string()
      self.next_realm_id += 1
      self.context_sandbox_realm[key] = realm_id
      self.realm_context[realm_id] = ctx_id
      self.realm_sandbox[realm_id] = sandbox_name
      self.emit_realm_created(ctx_id, realm_id, Some(sandbox_name))
      realm_id
    }
  }
}

///|
/// Build capabilities response
fn BidiProtocol::build_capabilities(self : BidiProtocol) -> Json {
  let _ = self
  make_object({
    "browserName": Json::string("crater"),
    "browserVersion": Json::string("0.1.0"),
    "platformName": Json::string("MoonBit"),
    "acceptInsecureCerts": Json::boolean(false),
    "userAgent": Json::string("Crater"),
  })
}

///|
/// Build tree result for browsingContext.getTree
fn BidiProtocol::build_context_tree(
  self : BidiProtocol,
  max_depth : Int?,
) -> Array[Json] {
  let contexts : Array[Json] = []
  for ctx_id in self.manager.list_sessions() {
    if self.context_parent.get(ctx_id) == None {
      match self.build_context_entry(ctx_id, true, 0, max_depth) {
        Some(entry) => contexts.push(entry)
        None => ()
      }
    }
  }
  contexts
}

///|
/// Build a single context entry recursively.
fn BidiProtocol::build_context_entry(
  self : BidiProtocol,
  ctx_id : String,
  include_parent : Bool,
  depth : Int,
  max_depth : Int?,
) -> Json? {
  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let truncate_children = match max_depth {
        Some(max_d) => depth >= max_d
        None => false
      }
      let children_json = if truncate_children {
        Json::null()
      } else {
        let children : Array[Json] = []
        for child_ctx_id in self.context_children.get(ctx_id).unwrap_or([]) {
          match
            self.build_context_entry(child_ctx_id, false, depth + 1, max_depth) {
            Some(child_entry) => children.push(child_entry)
            None => ()
          }
        }
        Json::array(children)
      }
      let original_opener = match self.context_original_opener.get(ctx_id) {
        Some(opener) => Json::string(opener)
        None => Json::null()
      }
      let parent_json = match self.context_parent.get(ctx_id) {
        Some(parent_ctx_id) => Json::string(parent_ctx_id)
        None => Json::null()
      }
      let client_window = self.context_client_window
        .get(ctx_id)
        .unwrap_or("client-window-" + ctx_id)
      let user_ctx = self.context_user_context.get(ctx_id).unwrap_or("default")
      let entry = if include_parent {
        make_object({
          "context": Json::string(ctx_id),
          "url": Json::string(session.get_url()),
          "children": children_json,
          "parent": parent_json,
          "clientWindow": Json::string(client_window),
          "userContext": Json::string(user_ctx),
          "originalOpener": original_opener,
        })
      } else {
        make_object({
          "context": Json::string(ctx_id),
          "url": Json::string(session.get_url()),
          "children": children_json,
          "clientWindow": Json::string(client_window),
          "userContext": Json::string(user_ctx),
          "originalOpener": original_opener,
        })
      }
      Some(entry)
    }
    None => None
  }
}

///|
/// Resolve the realm origin for a browsing context.
fn BidiProtocol::get_context_origin(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.manager.get_session(ctx_id) {
    Some(session) => derive_realm_origin(session.get_url())
    None => "null"
  }
}

///|
/// Convert a context URL into a realm origin string.
fn derive_realm_origin(url : String) -> String {
  if url.has_prefix("about:") {
    return "null"
  }
  if url.has_prefix("data:") {
    if url.contains("#domain=alt") {
      return "http://alt.localhost:8000/"
    }
    return "http://localhost:8000/"
  }
  if url.has_prefix("http://") {
    return extract_http_origin(url, "http://", 7)
  }
  if url.has_prefix("https://") {
    return extract_http_origin(url, "https://", 8)
  }
  "null"
}

///|
/// Extract scheme + host + slash origin from an absolute HTTP(S) URL.
fn extract_http_origin(url : String, scheme : String, start : Int) -> String {
  let chars = url.to_array()
  let mut end = chars.length()
  for i = start; i < chars.length(); i = i + 1 {
    if chars[i] == '/' || chars[i] == '?' || chars[i] == '#' {
      end = i
      break
    }
  }
  let host = url[start:end].to_string() catch { _ => "" }
  if host.length() == 0 {
    "null"
  } else {
    scheme + host + "/"
  }
}

///|
/// Handle session.subscribe params
fn BidiProtocol::handle_subscribe(self : BidiProtocol, params : Json?) -> Unit {
  match params {
    Some(Object(map)) => {
      // Get events to subscribe to
      let events_to_sub : Array[String] = []
      match map.get("events") {
        Some(Array(events)) =>
          for evt in events {
            match evt {
              String(s) => events_to_sub.push(s)
              _ => ()
            }
          }
        _ => ()
      }
      let mut wants_realm_created = false
      for evt in events_to_sub {
        if evt == "script.realmCreated" || get_subscription_key(evt) == "script" {
          wants_realm_created = true
          break
        }
      }
      // Check if contexts are specified
      match map.get("contexts") {
        Some(Array(contexts)) =>
          // Context-specific subscription
          for ctx in contexts {
            match ctx {
              String(ctx_id) => {
                let existing = self.context_subscriptions
                  .get(ctx_id)
                  .unwrap_or([])
                for evt in events_to_sub {
                  if not(array_contains(existing, evt)) {
                    existing.push(evt)
                  }
                }
                self.context_subscriptions[ctx_id] = existing
                if wants_realm_created {
                  self.emit_existing_realms_for_context(ctx_id)
                }
              }
              _ => ()
            }
          }
        // Global subscription (no contexts specified)
        _ => {
          for evt in events_to_sub {
            let module_key = get_subscription_key(evt)
            if module_key == evt {
              self.global_unsubscribed_events = array_filter_by_module(
                self.global_unsubscribed_events,
                module_key,
              )
            } else {
              self.global_unsubscribed_events = array_filter_not(
                self.global_unsubscribed_events,
                [evt],
              )
            }
            if not(array_contains(self.global_subscriptions, evt)) {
              self.global_subscriptions.push(evt)
            }
            self.subscriptions[module_key] = true
          }
          if wants_realm_created {
            for ctx_id in self.manager.list_sessions() {
              if self.context_parent.get(ctx_id) == None {
                self.emit_existing_realms_for_context(ctx_id)
              }
            }
          }
        }
      }
    }
    _ => ()
  }
}

///|
/// Handle session.unsubscribe params
fn BidiProtocol::handle_unsubscribe(
  self : BidiProtocol,
  params : Json?,
) -> Unit {
  match params {
    Some(Object(map)) => {
      // Get events to unsubscribe from
      let events_to_unsub : Array[String] = []
      match map.get("events") {
        Some(Array(events)) =>
          for evt in events {
            match evt {
              String(s) => events_to_unsub.push(s)
              _ => ()
            }
          }
        _ => ()
      }
      // Check if contexts are specified
      match map.get("contexts") {
        Some(Array(contexts)) =>
          // Context-specific unsubscription
          for ctx in contexts {
            match ctx {
              String(ctx_id) =>
                match self.context_subscriptions.get(ctx_id) {
                  Some(existing) => {
                    let filtered = array_filter_not(existing, events_to_unsub)
                    self.context_subscriptions[ctx_id] = filtered
                  }
                  None => ()
                }
              _ => ()
            }
          }
        // Global unsubscription
        _ => {
          self.global_subscriptions = array_filter_not(
            self.global_subscriptions,
            events_to_unsub,
          )
          for evt in events_to_unsub {
            let module_key = get_subscription_key(evt)
            if module_key == evt {
              self.global_unsubscribed_events = array_filter_by_module(
                self.global_unsubscribed_events,
                module_key,
              )
            } else if not(array_contains(self.global_unsubscribed_events, evt)) {
              self.global_unsubscribed_events.push(evt)
            }
            let mut has_same_module = false
            for sub in self.global_subscriptions {
              if sub == evt || get_subscription_key(sub) == module_key {
                has_same_module = true
                break
              }
            }
            if not(has_same_module) {
              self.subscriptions.remove(module_key)
            }
          }
        }
      }
    }
    _ => ()
  }
}

///|
/// Check if array contains a string
fn array_contains(arr : Array[String], item : String) -> Bool {
  for s in arr {
    if s == item {
      return true
    }
  }
  false
}

///|
/// Filter array to exclude items in exclude list
fn array_filter_not(
  arr : Array[String],
  exclude : Array[String],
) -> Array[String] {
  let result : Array[String] = []
  for s in arr {
    if not(array_contains(exclude, s)) {
      result.push(s)
    }
  }
  result
}

///|
/// Filter array to keep events outside the given module
fn array_filter_by_module(arr : Array[String], module_key : String) -> Array[String] {
  let result : Array[String] = []
  for s in arr {
    if get_subscription_key(s) != module_key {
      result.push(s)
    }
  }
  result
}

///|
/// Emit contextCreated event
fn BidiProtocol::emit_context_created(
  self : BidiProtocol,
  ctx_id : String,
  ctx_type : String,
  url : String,
  original_opener : String?,
  parent_ctx_id : String?,
) -> Unit {
  let event_name = "browsingContext.contextCreated"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let user_ctx = self.context_user_context.get(ctx_id).unwrap_or("default")
  let opener_json = match original_opener {
    Some(opener) => Json::string(opener)
    None => Json::null()
  }
  let parent_json = match parent_ctx_id {
    Some(parent_id) => Json::string(parent_id)
    None => Json::null()
  }
  let client_window = self.context_client_window
    .get(ctx_id)
    .unwrap_or("client-window-" + ctx_id)
  let params = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
    "type": Json::string(ctx_type),
    "children": Json::null(),
    "parent": parent_json,
    "clientWindow": Json::string(client_window),
    "userContext": Json::string(user_ctx),
    "originalOpener": opener_json,
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit contextDestroyed event
fn BidiProtocol::emit_context_destroyed(
  self : BidiProtocol,
  ctx_id : String,
  original_opener : String?,
) -> Unit {
  let event_name = "browsingContext.contextDestroyed"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let opener_json = match original_opener {
    Some(opener) => Json::string(opener)
    None => Json::null()
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "originalOpener": opener_json,
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit realmCreated event for a context realm.
fn BidiProtocol::emit_realm_created(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
  sandbox_name : String?,
) -> Unit {
  let event_name = "script.realmCreated"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let sandbox_json = match sandbox_name {
    Some(name) => Json::string(name)
    None => Json::null()
  }
  let params = make_object({
    "realm": Json::string(realm_id),
    "type": Json::string("window"),
    "context": Json::string(ctx_id),
    "origin": Json::string(self.get_context_origin(ctx_id)),
    "sandbox": sandbox_json,
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit default realmCreated event for a context.
fn BidiProtocol::emit_default_realm(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
  self.emit_realm_created(ctx_id, realm_id, None)
}

///|
/// Emit all existing realms for a context subtree.
fn BidiProtocol::emit_existing_realms_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  if not(self.manager.has_session(ctx_id)) {
    return
  }
  self.emit_default_realm(ctx_id)
  let prefix = ctx_id + "::"
  for key, realm_id in self.context_sandbox_realm {
    if key.has_prefix(prefix) {
      let sandbox_name = key[prefix.length():].to_string() catch { _ => "" }
      self.emit_realm_created(ctx_id, realm_id, Some(sandbox_name))
    }
  }
  for child_ctx_id in self.context_children.get(ctx_id).unwrap_or([]) {
    self.emit_existing_realms_for_context(child_ctx_id)
  }
}

///|
/// Emit basic navigation events
fn BidiProtocol::emit_navigation_events(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let base = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(0.0),
  })
  // Emit navigationStarted
  if self.is_subscribed_for_context("browsingContext.navigationStarted", ctx_id) {
    self.outbox.push(
      Event({ event_method: "browsingContext.navigationStarted", params: base }),
    )
  }
  // Emit domContentLoaded
  if self.is_subscribed_for_context("browsingContext.domContentLoaded", ctx_id) {
    self.outbox.push(
      Event({ event_method: "browsingContext.domContentLoaded", params: base }),
    )
  }
  // Emit load
  if self.is_subscribed_for_context("browsingContext.load", ctx_id) {
    self.outbox.push(
      Event({ event_method: "browsingContext.load", params: base }),
    )
  }
  // Emit historyUpdated
  let history = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
  })
  if self.is_subscribed_for_context("browsingContext.historyUpdated", ctx_id) {
    self.outbox.push(
      Event({ event_method: "browsingContext.historyUpdated", params: history }),
    )
  }
}

///|
/// Check subscription for module/event (legacy, global only)
fn BidiProtocol::is_subscribed(self : BidiProtocol, key : String) -> Bool {
  self.subscriptions.get(key).unwrap_or(false)
}

///|
/// Check if subscribed to event for a specific context
fn BidiProtocol::is_subscribed_for_context(
  self : BidiProtocol,
  event : String,
  ctx_id : String,
) -> Bool {
  let module_key = get_subscription_key(event)
  let blocked_global = array_contains(self.global_unsubscribed_events, event)
  // Check legacy module-level subscription
  if not(blocked_global) &&
    self.subscriptions.get(module_key).unwrap_or(false) {
    return true
  }
  // Check global subscriptions (exact event match or module match)
  for sub in self.global_subscriptions {
    if sub == event {
      return true
    }
    if not(blocked_global) && get_subscription_key(sub) == module_key {
      return true
    }
  }
  // Check context-specific subscriptions (including ancestors).
  self.is_subscribed_for_context_chain(event, module_key, ctx_id)
}

///|
/// Check context-specific subscriptions for context and its ancestors.
fn BidiProtocol::is_subscribed_for_context_chain(
  self : BidiProtocol,
  event : String,
  module_key : String,
  ctx_id : String,
) -> Bool {
  match self.context_subscriptions.get(ctx_id) {
    Some(events) =>
      for sub in events {
        if sub == event || get_subscription_key(sub) == module_key {
          return true
        }
      }
    None => ()
  }
  match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) =>
      self.is_subscribed_for_context_chain(event, module_key, parent_ctx_id)
    None => false
  }
}

///|
/// Send success response
fn BidiProtocol::send_success(
  self : BidiProtocol,
  id : Int,
  result : Json?,
) -> Unit {
  let resp : BidiResponse = { id, result, error: None }
  self.outbox.push(Response(resp))
}

///|
/// Send a pre-serialized response JSON string
fn BidiProtocol::send_raw(self : BidiProtocol, json : String) -> Unit {
  self.outbox.push(Raw(json))
}

///|
/// Send error response
fn BidiProtocol::send_error(
  self : BidiProtocol,
  id : Int,
  code : String,
  message : String,
) -> Unit {
  let err : BidiError = { error: code, message, stacktrace: "" }
  let resp : BidiResponse = { id, result: None, error: Some(err) }
  self.outbox.push(Response(resp))
}

///|
/// Parse method into (domain, action)
fn split_method(method_name : String) -> (String, String)? {
  let domain = StringBuilder::new()
  let action = StringBuilder::new()
  let mut in_action = false
  for c in method_name.iter() {
    if c == '.' && not(in_action) {
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

///|
/// Normalize subscription key
fn get_subscription_key(name : String) -> String {
  let buf = StringBuilder::new()
  for c in name.iter() {
    if c == '.' {
      break
    }
    buf.write_char(c)
  }
  let key = buf.to_string()
  if key.length() == 0 {
    name
  } else {
    key
  }
}

///|
/// JSON helpers
fn make_object(map : Map[String, Json]) -> Json {
  Json::object(map)
}

///|
fn get_field(json : Json, key : String) -> Json? {
  match json {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn get_string_field(json : Json, key : String) -> String? {
  match get_field(json, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn get_int_field(json : Json, key : String) -> Int? {
  match get_field(json, key) {
    Some(Number(n, ..)) => Some(n.to_int())
    _ => None
  }
}

///|
fn get_string_param(params : Json?, key : String) -> String? {
  match params {
    Some(Object(map)) =>
      match map.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// Get raw parameter value without type conversion
fn get_param_raw(params : Json?, key : String) -> Json? {
  match params {
    Some(Object(map)) => map.get(key)
    _ => None
  }
}

///|
/// Validate script target parameter
/// Returns Some(()) if error was sent, None if valid
fn BidiProtocol::validate_script_target(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "target") {
    None => {
      self.send_error(request_id, "invalid argument", "Missing target")
      return Some(())
    }
    Some(Object(target_map)) => {
      // Check if context is specified
      match target_map.get("context") {
        Some(String(ctx_id)) =>
          if not(self.manager.has_session(ctx_id)) {
            self.send_error(
              request_id,
              "no such frame",
              "Unknown context: " + ctx_id,
            )
            return Some(())
          }
        Some(Null)
        | Some(True)
        | Some(False)
        | Some(Number(_))
        | Some(Array(_))
        | Some(Object(_)) => {
          self.send_error(
            request_id, "invalid argument", "target.context must be a string",
          )
          return Some(())
        }
        None => ()
      }
      // Check if realm is specified
      match target_map.get("realm") {
        Some(String(realm_id)) =>
          if not(self.realm_context.contains(realm_id)) {
            self.send_error(
              request_id,
              "no such frame",
              "Unknown realm: " + realm_id,
            )
            return Some(())
          }
        Some(Null)
        | Some(True)
        | Some(False)
        | Some(Number(_))
        | Some(Array(_))
        | Some(Object(_)) => {
          self.send_error(
            request_id, "invalid argument", "target.realm must be a string",
          )
          return Some(())
        }
        None => ()
      }
      // Target must have either context or realm
      if target_map.get("context") is None && target_map.get("realm") is None {
        self.send_error(
          request_id, "invalid argument", "target must have either context or realm",
        )
        return Some(())
      }
      // Validate sandbox if present (must be string)
      match target_map.get("sandbox") {
        Some(String(_)) => ()
        Some(Null) => () // null is allowed
        Some(True)
        | Some(False)
        | Some(Number(_))
        | Some(Array(_))
        | Some(Object(_)) => {
          self.send_error(
            request_id, "invalid argument", "target.sandbox must be a string",
          )
          return Some(())
        }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "target must be an object",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate awaitPromise parameter (must be boolean)
fn BidiProtocol::validate_await_promise(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "awaitPromise") {
    Some(True) | Some(False) => ()
    None => () // Optional, defaults to false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "awaitPromise must be a boolean",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate resultOwnership parameter (must be "root" or "none")
fn BidiProtocol::validate_result_ownership(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "resultOwnership") {
    Some(String(s)) =>
      if s != "root" && s != "none" {
        self.send_error(
          request_id, "invalid argument", "resultOwnership must be 'root' or 'none'",
        )
        return Some(())
      }
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "resultOwnership must be a string",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate serializationOptions parameter
fn BidiProtocol::validate_serialization_options(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "serializationOptions") {
    Some(Object(opts)) => {
      // Validate maxDomDepth
      match opts.get("maxDomDepth") {
        Some(Number(n, ..)) =>
          if n < 0.0 || n != n.to_int64().to_double() {
            self.send_error(
              request_id, "invalid argument", "maxDomDepth must be a non-negative integer",
            )
            return Some(())
          }
        Some(Null) => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "maxDomDepth must be a non-negative integer",
          )
          return Some(())
        }
        None => ()
      }
      // Validate maxObjectDepth
      match opts.get("maxObjectDepth") {
        Some(Number(n, ..)) =>
          if n < 0.0 || n != n.to_int64().to_double() {
            self.send_error(
              request_id, "invalid argument", "maxObjectDepth must be a non-negative integer",
            )
            return Some(())
          }
        Some(Null) => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "maxObjectDepth must be a non-negative integer",
          )
          return Some(())
        }
        None => ()
      }
      // Validate includeShadowTree
      match opts.get("includeShadowTree") {
        Some(String(s)) =>
          if s != "none" && s != "open" && s != "all" {
            self.send_error(
              request_id, "invalid argument", "includeShadowTree must be 'none', 'open', or 'all'",
            )
            return Some(())
          }
        Some(Null) => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "includeShadowTree must be a string",
          )
          return Some(())
        }
        None => ()
      }
    }
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "serializationOptions must be an object",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate userActivation parameter (must be boolean)
fn BidiProtocol::validate_user_activation(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "userActivation") {
    Some(True) | Some(False) => ()
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userActivation must be a boolean",
      )
      return Some(())
    }
  }
  None
}

///|
/// Resolve target context/realm pair from script target.
fn BidiProtocol::resolve_target_context_realm(
  self : BidiProtocol,
  params : Json?,
) -> (String, String) {
  match get_param_raw(params, "target") {
    Some(Object(target_map)) => {
      let context_id = match target_map.get("context") {
        Some(String(id)) => Some(id)
        _ => None
      }
      let realm_id = match target_map.get("realm") {
        Some(String(id)) => Some(id)
        _ => None
      }
      let sandbox_name = match target_map.get("sandbox") {
        Some(String(name)) => Some(name)
        _ => None
      }
      match realm_id {
        Some(realm) => {
          let fallback_ctx = self.default_context_id.unwrap_or(
            self.ensure_default_context(),
          )
          let resolved_ctx = self.realm_context
            .get(realm)
            .unwrap_or(context_id.unwrap_or(fallback_ctx))
          (resolved_ctx, realm)
        }
        None =>
          match context_id {
            Some(ctx_id) =>
              match sandbox_name {
                Some(name) =>
                  (ctx_id, self.get_or_create_sandbox_realm(ctx_id, name))
                None =>
                  (
                    ctx_id,
                    self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id),
                  )
              }
            None => {
              let fallback_ctx = self.default_context_id.unwrap_or(
                self.ensure_default_context(),
              )
              (
                fallback_ctx,
                self.context_realm
                .get(fallback_ctx)
                .unwrap_or("realm-" + fallback_ctx),
              )
            }
          }
      }
    }
    _ => {
      let fallback_ctx = self.default_context_id.unwrap_or(
        self.ensure_default_context(),
      )
      (
        fallback_ctx,
        self.context_realm.get(fallback_ctx).unwrap_or("realm-" + fallback_ctx),
      )
    }
  }
}

///|
/// Extract userActivation parameter with default false.
fn get_user_activation_value(params : Json?) -> Bool {
  match get_param_raw(params, "userActivation") {
    Some(True) => true
    _ => false
  }
}

///|
/// Handle top-level `window.open(...)` evaluate calls and keep browsing context
/// state synchronized with BiDi events.
fn BidiProtocol::try_handle_window_open(
  self : BidiProtocol,
  request_id : Int,
  opener_ctx_id : String,
  expression : String,
) -> Bool {
  let trimmed = expression.trim().to_string()
  if not(trimmed.has_prefix("window.open(")) {
    return false
  }

  let user_ctx = self.context_user_context
    .get(opener_ctx_id)
    .unwrap_or("default")
  let new_ctx_id = self.create_context(user_ctx)
  self.context_original_opener[new_ctx_id] = opener_ctx_id

  // WPT expects contextCreated.url to stay about:blank for window.open flows.
  self.emit_context_created(
    new_ctx_id,
    "tab",
    "about:blank",
    Some(opener_ctx_id),
    None,
  )
  self.emit_default_realm(new_ctx_id)

  let returns_null = trimmed.contains("noopener") ||
    trimmed.contains("noreferrer")
  let remote_value = if returns_null {
    make_object({ "type": Json::string("null") })
  } else {
    make_object({
      "type": Json::string("window"),
      "value": make_object({ "context": Json::string(new_ctx_id) }),
    })
  }
  let result = make_object({
    "realm": Json::string(
      self.context_realm.get(opener_ctx_id).unwrap_or("realm-" + opener_ctx_id),
    ),
    "result": remote_value,
  })
  self.send_success(request_id, Some(result))
  true
}

///|
/// Validate this parameter for callFunction (must be a serialized value object)
fn BidiProtocol::validate_this_param(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "this") {
    Some(Object(_)) => () // Valid serialized value
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "this must be a serialized value",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate arguments parameter for callFunction (must be array of serialized values)
fn BidiProtocol::validate_arguments_param(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "arguments") {
    Some(Array(args)) =>
      // Each argument must be a serialized value (object)
      for arg in args {
        match arg {
          Object(arg_map) => {
            // Check for channel type special validation
            match arg_map.get("type") {
              Some(String("channel")) =>
                // Validate channel value
                match arg_map.get("value") {
                  Some(Object(channel_val)) => {
                    // Validate channel.channel (must be string)
                    match channel_val.get("channel") {
                      Some(String(_)) => ()
                      Some(_) => {
                        self.send_error(
                          request_id, "invalid argument", "channel.channel must be a string",
                        )
                        return Some(())
                      }
                      None => () // May be omitted
                    }
                    // Validate channel.ownership (must be "root" or "none")
                    match channel_val.get("ownership") {
                      Some(String(s)) =>
                        if s != "root" && s != "none" {
                          self.send_error(
                            request_id, "invalid argument", "channel.ownership must be 'root' or 'none'",
                          )
                          return Some(())
                        }
                      Some(_) => {
                        self.send_error(
                          request_id, "invalid argument", "channel.ownership must be a string",
                        )
                        return Some(())
                      }
                      None => ()
                    }
                    // Validate channel.serializationOptions
                    match channel_val.get("serializationOptions") {
                      Some(Object(ser_opts)) => {
                        // Validate maxDomDepth
                        match ser_opts.get("maxDomDepth") {
                          Some(Number(n, ..)) =>
                            if n < 0.0 {
                              self.send_error(
                                request_id, "invalid argument", "maxDomDepth must be a non-negative integer",
                              )
                              return Some(())
                            }
                          Some(Null) => ()
                          Some(_) => {
                            self.send_error(
                              request_id, "invalid argument", "maxDomDepth must be a non-negative integer",
                            )
                            return Some(())
                          }
                          None => ()
                        }
                        // Validate maxObjectDepth
                        match ser_opts.get("maxObjectDepth") {
                          Some(Number(n, ..)) =>
                            if n < 0.0 {
                              self.send_error(
                                request_id, "invalid argument", "maxObjectDepth must be a non-negative integer",
                              )
                              return Some(())
                            }
                          Some(Null) => ()
                          Some(_) => {
                            self.send_error(
                              request_id, "invalid argument", "maxObjectDepth must be a non-negative integer",
                            )
                            return Some(())
                          }
                          None => ()
                        }
                        // Validate includeShadowTree
                        match ser_opts.get("includeShadowTree") {
                          Some(String(s)) =>
                            if s != "none" && s != "open" && s != "all" {
                              self.send_error(
                                request_id, "invalid argument", "includeShadowTree must be 'none', 'open', or 'all'",
                              )
                              return Some(())
                            }
                          Some(Null) => ()
                          Some(_) => {
                            self.send_error(
                              request_id, "invalid argument", "includeShadowTree must be a string",
                            )
                            return Some(())
                          }
                          None => ()
                        }
                      }
                      Some(_) => {
                        self.send_error(
                          request_id, "invalid argument", "serializationOptions must be an object",
                        )
                        return Some(())
                      }
                      None => ()
                    }
                  }
                  Some(_) => {
                    self.send_error(
                      request_id, "invalid argument", "channel value must be an object",
                    )
                    return Some(())
                  }
                  None => {
                    self.send_error(
                      request_id, "invalid argument", "channel type requires value",
                    )
                    return Some(())
                  }
                }
              _ => () // Other types don't need special validation here
            }
            // Validate handle if present
            match arg_map.get("handle") {
              Some(String(_)) => () // Will be validated during execution
              Some(_) => {
                self.send_error(
                  request_id, "invalid argument", "handle must be a string",
                )
                return Some(())
              }
              None => ()
            }
            // Validate sharedId if present
            match arg_map.get("sharedId") {
              Some(String(_)) => ()
              Some(_) => {
                self.send_error(
                  request_id, "invalid argument", "sharedId must be a string",
                )
                return Some(())
              }
              None => ()
            }
          }
          _ => {
            self.send_error(
              request_id, "invalid argument", "arguments entries must be serialized values",
            )
            return Some(())
          }
        }
      }
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "arguments must be an array",
      )
      return Some(())
    }
  }
  None
}

///|
/// Convert BiDi remote value to JS literal for function arguments
fn bidi_value_to_js_literal(value : Json) -> String {
  match value {
    Object(map) =>
      match map.get("type") {
        Some(String("undefined")) => "undefined"
        Some(String("null")) => "null"
        Some(String("boolean")) =>
          match map.get("value") {
            Some(True) => "true"
            Some(False) => "false"
            _ => "false"
          }
        Some(String("number")) =>
          match map.get("value") {
            Some(Number(n, ..)) => n.to_string()
            Some(String(s)) => s // NaN, Infinity, etc.
            _ => "0"
          }
        Some(String("string")) =>
          match map.get("value") {
            Some(String(s)) => "\"" + escape_js_string(s) + "\""
            _ => "\"\""
          }
        Some(String("bigint")) =>
          match map.get("value") {
            Some(String(s)) => s + "n"
            _ => "0n"
          }
        Some(String("array")) =>
          match map.get("value") {
            Some(Array(items)) => {
              let parts : Array[String] = []
              for item in items {
                parts.push(bidi_value_to_js_literal(item))
              }
              "[" + parts.join(", ") + "]"
            }
            _ => "[]"
          }
        Some(String("object")) =>
          match map.get("value") {
            Some(Array(entries)) => {
              let parts : Array[String] = []
              for entry in entries {
                match entry {
                  Array(kv) if kv.length() >= 2 => {
                    let key = match kv[0] {
                      String(s) => "\"" + escape_js_string(s) + "\""
                      _ => bidi_value_to_js_literal(kv[0])
                    }
                    let val = bidi_value_to_js_literal(kv[1])
                    parts.push(key + ": " + val)
                  }
                  _ => ()
                }
              }
              "{" + parts.join(", ") + "}"
            }
            _ => "{}"
          }
        _ => "undefined"
      }
    _ => "undefined"
  }
}

///|
/// Escape special characters in JS string
fn escape_js_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s.iter() {
    match c {
      '\\' => buf.write_string("\\\\")
      '"' => buf.write_string("\\\"")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Response JSON serialization
fn response_to_json(resp : BidiResponse) -> String {
  let obj : Map[String, Json] = {}
  obj["id"] = Json::number(resp.id.to_double())
  match resp.error {
    Some(err) => {
      obj["type"] = Json::string("error")
      obj["error"] = Json::string(err.error)
      obj["message"] = Json::string(err.message)
      obj["stacktrace"] = Json::string(err.stacktrace)
    }
    None => {
      obj["type"] = Json::string("success")
      match resp.result {
        Some(r) => obj["result"] = r
        None => obj["result"] = make_object({})
      }
    }
  }
  make_object(obj).stringify()
}

///|
/// Event JSON serialization
fn event_to_json(evt : BidiEvent) -> String {
  let obj : Map[String, Json] = {}
  obj["type"] = Json::string("event")
  obj["method"] = Json::string(evt.event_method)
  obj["params"] = evt.params
  make_object(obj).stringify()
}
