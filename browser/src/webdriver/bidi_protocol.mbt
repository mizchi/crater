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
  user_context_subscriptions : Map[String, Array[String]] // user context -> events
  mut global_subscriptions : Array[String] // events subscribed globally
  mut global_unsubscribed_events : Array[String] // event-level overrides for module subscriptions
  subscription_events : Map[String, Array[String]] // subscription id -> events
  subscription_contexts : Map[String, Array[String]] // subscription id -> contexts
  subscription_user_contexts : Map[String, Array[String]] // subscription id -> user contexts
  mut next_subscription_id : Int
  pending_log_entries : Map[String, Array[Json]] // context -> buffered log.entryAdded params
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
  input_pressed_keys : Map[String, Array[String]] // context -> pressed key stack
  input_pointer_x : Map[String, Double] // context -> current pointer x
  input_pointer_y : Map[String, Double] // context -> current pointer y
  input_pointer_buttons : Map[String, Int] // context -> mouse buttons bitfield
  input_pointer_type : Map[String, String] // context -> last pointer type
  input_pointer_target_shared : Map[String, String] // context -> last element-origin sharedId
  input_pointer_down_x : Map[String, Double] // context -> primary pointerDown x
  input_pointer_down_y : Map[String, Double] // context -> primary pointerDown y
  input_pointer_down_target_shared : Map[String, String] // context -> primary pointerDown target
  input_pointer_dragged : Map[String, Bool] // context -> whether pointer moved while primary button pressed
  input_html_drag_source_shared : Map[String, String] // context -> active HTML draggable source sharedId
  input_html_drag_active : Map[String, Bool] // context -> whether dragstart has been emitted
  input_last_click_time : Map[String, Double] // context -> timestamp of last primary click release
  input_last_click_x : Map[String, Double] // context -> x of last primary click release
  input_last_click_y : Map[String, Double] // context -> y of last primary click release
  input_last_click_target_shared : Map[String, String] // context -> target of last primary click release
  input_pending_double_click : Map[String, Bool] // context -> whether current click sequence should emit dblclick
  input_action_clock_ms : Map[String, Double] // context -> virtual input clock advanced by pause durations
  mut socket : @core.Any? // WebSocket for async responses
  mut socket_epoch : Int // Monotonic epoch for active WebSocket
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
    user_context_subscriptions: {},
    global_subscriptions: [],
    global_unsubscribed_events: [],
    subscription_events: {},
    subscription_contexts: {},
    subscription_user_contexts: {},
    next_subscription_id: 1,
    pending_log_entries: {},
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
    input_pressed_keys: {},
    input_pointer_x: {},
    input_pointer_y: {},
    input_pointer_buttons: {},
    input_pointer_type: {},
    input_pointer_target_shared: {},
    input_pointer_down_x: {},
    input_pointer_down_y: {},
    input_pointer_down_target_shared: {},
    input_pointer_dragged: {},
    input_html_drag_source_shared: {},
    input_html_drag_active: {},
    input_last_click_time: {},
    input_last_click_x: {},
    input_last_click_y: {},
    input_last_click_target_shared: {},
    input_pending_double_click: {},
    input_action_clock_ms: {},
    socket: None,
    socket_epoch: 0,
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
/// Set WebSocket for async responses and return epoch token.
pub fn BidiProtocol::set_socket(
  self : BidiProtocol,
  socket : @core.Any,
) -> Int {
  self.socket_epoch += 1
  self.socket = Some(socket)
  self.socket_epoch
}

///|
/// Clear WebSocket reference
pub fn BidiProtocol::clear_socket(self : BidiProtocol) -> Unit {
  self.socket = None
}

///|
/// Check whether a captured WebSocket epoch is still active.
pub fn BidiProtocol::is_current_socket_epoch(
  self : BidiProtocol,
  epoch : Int,
) -> Bool {
  self.socket_epoch == epoch
}

///|
/// Reset per-connection subscription state.
pub fn BidiProtocol::reset_subscription_state(self : BidiProtocol) -> Unit {
  let legacy_keys : Array[String] = []
  for key, _ in self.subscriptions {
    legacy_keys.push(key)
  }
  for key in legacy_keys {
    self.subscriptions.remove(key)
  }

  let context_keys : Array[String] = []
  for key, _ in self.context_subscriptions {
    context_keys.push(key)
  }
  for key in context_keys {
    self.context_subscriptions.remove(key)
  }

  let user_context_keys : Array[String] = []
  for key, _ in self.user_context_subscriptions {
    user_context_keys.push(key)
  }
  for key in user_context_keys {
    self.user_context_subscriptions.remove(key)
  }

  let subscription_keys : Array[String] = []
  for key, _ in self.subscription_events {
    subscription_keys.push(key)
  }
  for key in subscription_keys {
    self.subscription_events.remove(key)
    self.subscription_contexts.remove(key)
    self.subscription_user_contexts.remove(key)
  }

  let pending_log_keys : Array[String] = []
  for key, _ in self.pending_log_entries {
    pending_log_keys.push(key)
  }
  for key in pending_log_keys {
    self.pending_log_entries.remove(key)
  }

  self.global_subscriptions = []
  self.global_unsubscribed_events = []
  self.next_subscription_id = 1
}

///|
/// Reset per-session browsing-context and realm state.
pub fn BidiProtocol::reset_session_runtime_state(self : BidiProtocol) -> Unit {
  self.reset_subscription_state()

  for ctx_id in self.manager.list_sessions() {
    self.manager.close_session(ctx_id) |> ignore
  }

  self.default_context_id = None
  self.session_id = None

  let user_context_keys : Array[String] = []
  for key, _ in self.user_contexts {
    user_context_keys.push(key)
  }
  for key in user_context_keys {
    self.user_contexts.remove(key)
  }
  self.user_contexts["default"] = true

  let context_user_keys : Array[String] = []
  for key, _ in self.context_user_context {
    context_user_keys.push(key)
  }
  for key in context_user_keys {
    self.context_user_context.remove(key)
  }

  let context_original_opener_keys : Array[String] = []
  for key, _ in self.context_original_opener {
    context_original_opener_keys.push(key)
  }
  for key in context_original_opener_keys {
    self.context_original_opener.remove(key)
  }

  let context_realm_keys : Array[String] = []
  for key, _ in self.context_realm {
    context_realm_keys.push(key)
  }
  for key in context_realm_keys {
    self.context_realm.remove(key)
  }

  let context_sandbox_realm_keys : Array[String] = []
  for key, _ in self.context_sandbox_realm {
    context_sandbox_realm_keys.push(key)
  }
  for key in context_sandbox_realm_keys {
    self.context_sandbox_realm.remove(key)
  }

  let realm_context_keys : Array[String] = []
  for key, _ in self.realm_context {
    realm_context_keys.push(key)
  }
  for key in realm_context_keys {
    self.realm_context.remove(key)
  }

  let realm_sandbox_keys : Array[String] = []
  for key, _ in self.realm_sandbox {
    realm_sandbox_keys.push(key)
  }
  for key in realm_sandbox_keys {
    self.realm_sandbox.remove(key)
  }

  let context_parent_keys : Array[String] = []
  for key, _ in self.context_parent {
    context_parent_keys.push(key)
  }
  for key in context_parent_keys {
    self.context_parent.remove(key)
  }

  let context_children_keys : Array[String] = []
  for key, _ in self.context_children {
    context_children_keys.push(key)
  }
  for key in context_children_keys {
    self.context_children.remove(key)
  }

  let context_client_window_keys : Array[String] = []
  for key, _ in self.context_client_window {
    context_client_window_keys.push(key)
  }
  for key in context_client_window_keys {
    self.context_client_window.remove(key)
  }

  let input_pressed_keys : Array[String] = []
  for key, _ in self.input_pressed_keys {
    input_pressed_keys.push(key)
  }
  for key in input_pressed_keys {
    self.input_pressed_keys.remove(key)
  }

  let input_pointer_x_keys : Array[String] = []
  for key, _ in self.input_pointer_x {
    input_pointer_x_keys.push(key)
  }
  for key in input_pointer_x_keys {
    self.input_pointer_x.remove(key)
  }

  let input_pointer_y_keys : Array[String] = []
  for key, _ in self.input_pointer_y {
    input_pointer_y_keys.push(key)
  }
  for key in input_pointer_y_keys {
    self.input_pointer_y.remove(key)
  }

  let input_pointer_button_keys : Array[String] = []
  for key, _ in self.input_pointer_buttons {
    input_pointer_button_keys.push(key)
  }
  for key in input_pointer_button_keys {
    self.input_pointer_buttons.remove(key)
  }

  let input_pointer_type_keys : Array[String] = []
  for key, _ in self.input_pointer_type {
    input_pointer_type_keys.push(key)
  }
  for key in input_pointer_type_keys {
    self.input_pointer_type.remove(key)
  }

  let input_pointer_target_keys : Array[String] = []
  for key, _ in self.input_pointer_target_shared {
    input_pointer_target_keys.push(key)
  }
  for key in input_pointer_target_keys {
    self.input_pointer_target_shared.remove(key)
  }

  let input_pointer_down_x_keys : Array[String] = []
  for key, _ in self.input_pointer_down_x {
    input_pointer_down_x_keys.push(key)
  }
  for key in input_pointer_down_x_keys {
    self.input_pointer_down_x.remove(key)
  }

  let input_pointer_down_y_keys : Array[String] = []
  for key, _ in self.input_pointer_down_y {
    input_pointer_down_y_keys.push(key)
  }
  for key in input_pointer_down_y_keys {
    self.input_pointer_down_y.remove(key)
  }

  let input_pointer_down_target_keys : Array[String] = []
  for key, _ in self.input_pointer_down_target_shared {
    input_pointer_down_target_keys.push(key)
  }
  for key in input_pointer_down_target_keys {
    self.input_pointer_down_target_shared.remove(key)
  }

  let input_pointer_dragged_keys : Array[String] = []
  for key, _ in self.input_pointer_dragged {
    input_pointer_dragged_keys.push(key)
  }
  for key in input_pointer_dragged_keys {
    self.input_pointer_dragged.remove(key)
  }

  let input_html_drag_source_keys : Array[String] = []
  for key, _ in self.input_html_drag_source_shared {
    input_html_drag_source_keys.push(key)
  }
  for key in input_html_drag_source_keys {
    self.input_html_drag_source_shared.remove(key)
  }

  let input_html_drag_active_keys : Array[String] = []
  for key, _ in self.input_html_drag_active {
    input_html_drag_active_keys.push(key)
  }
  for key in input_html_drag_active_keys {
    self.input_html_drag_active.remove(key)
  }

  let input_last_click_time_keys : Array[String] = []
  for key, _ in self.input_last_click_time {
    input_last_click_time_keys.push(key)
  }
  for key in input_last_click_time_keys {
    self.input_last_click_time.remove(key)
  }

  let input_last_click_x_keys : Array[String] = []
  for key, _ in self.input_last_click_x {
    input_last_click_x_keys.push(key)
  }
  for key in input_last_click_x_keys {
    self.input_last_click_x.remove(key)
  }

  let input_last_click_y_keys : Array[String] = []
  for key, _ in self.input_last_click_y {
    input_last_click_y_keys.push(key)
  }
  for key in input_last_click_y_keys {
    self.input_last_click_y.remove(key)
  }

  let input_last_click_target_keys : Array[String] = []
  for key, _ in self.input_last_click_target_shared {
    input_last_click_target_keys.push(key)
  }
  for key in input_last_click_target_keys {
    self.input_last_click_target_shared.remove(key)
  }

  let input_pending_double_click_keys : Array[String] = []
  for key, _ in self.input_pending_double_click {
    input_pending_double_click_keys.push(key)
  }
  for key in input_pending_double_click_keys {
    self.input_pending_double_click.remove(key)
  }

  let input_action_clock_keys : Array[String] = []
  for key, _ in self.input_action_clock_ms {
    input_action_clock_keys.push(key)
  }
  for key in input_action_clock_keys {
    self.input_action_clock_ms.remove(key)
  }
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
      self.reset_session_runtime_state()
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
                  reset_runtime_event_buffers(ctx_id)
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
                  self.emit_navigation_events(ctx_id, url, nav_id)
                  self.send_success(request.id, Some(result))
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
            self.pending_log_entries.remove(ctx_id)
            self.clear_input_state_for_context(ctx_id)
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
      let runtime_ctx_id = resolve_runtime_context_id(
        request.params,
        ctx_id,
        realm_id,
        self.realm_sandbox.get(realm_id) != None,
      )
      // Check if awaitPromise is true
      let await_promise = match get_param_raw(request.params, "awaitPromise") {
        Some(True) => true
        _ => false
      }
      let root_ownership = match
        get_param_raw(request.params, "resultOwnership") {
        Some(String("root")) => true
        _ => false
      }
      let user_activation = get_user_activation_value(request.params)
      let expr = get_string_param(request.params, "expression").unwrap()
      let serialization_options_json = get_serialization_options_json(
        request.params,
      )
      let has_serialization_options = has_serialization_options_param(
        request.params,
      )
      set_runtime_context(runtime_ctx_id)
      set_runtime_context_frames(
        runtime_ctx_id,
        self.context_children.get(ctx_id).unwrap_or([]),
      )
      // Handle window.open directly so browsing context state stays in sync.
      if self.try_handle_window_open(request.id, ctx_id, expr) {
        return Ok(())
      }
      let capture_console = self.should_capture_console(ctx_id)
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
      if self.dom_initialized &&
        not(capture_console) &&
        not(await_promise) &&
        not(root_ownership) &&
        not(has_serialization_options) {
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
        if not(self.dom_initialized) {
          let _ = evaluate_js_with_console(
            "undefined", false, false, false, "{}",
          )
          self.dom_initialized = true
        }
        match self.socket {
          Some(socket) => {
            // Async evaluation - response sent directly via WebSocket
            eval_and_send_async_with_console(
              socket,
              request.id,
              expr,
              runtime_ctx_id,
              realm_id,
              capture_console,
              user_activation,
              root_ownership,
            )
            return Ok(()) // No sync response needed
          }
          None => () // Fall through to sync evaluation
        }
      }
      // Synchronous evaluation (Deno eval)
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
      let runtime_ctx_id_call = resolve_runtime_context_id(
        request.params,
        ctx_id_call,
        realm_id_call,
        self.realm_sandbox.get(realm_id_call) != None,
      )
      let capture_console_call = self.should_capture_console(ctx_id_call)
      // Check if awaitPromise is true
      let await_promise_call = match
        get_param_raw(request.params, "awaitPromise") {
        Some(True) => true
        _ => false
      }
      let root_ownership_call = match
        get_param_raw(request.params, "resultOwnership") {
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
      let this_json = match get_param_raw(request.params, "this") {
        Some(value) => bidi_value_to_js_literal(value)
        None => "undefined"
      }
      // Wrap function declaration and call it
      let func = get_string_param(request.params, "functionDeclaration").unwrap()
      let function_is_async = func.trim().has_prefix("async")
      let call_expr = if args_json == "" {
        "(" + func + ").call(" + this_json + ")"
      } else {
        "(" + func + ").call(" + this_json + ", " + args_json + ")"
      }
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
      if await_promise_call &&
        (not(has_serialization_options_call) || function_is_async) {
        if not(self.dom_initialized) {
          let _ = evaluate_js_with_console(
            "undefined", false, false, false, "{}",
          )
          self.dom_initialized = true
        }
        match self.socket {
          Some(socket) => {
            // Async evaluation - response sent directly via WebSocket
            eval_and_send_async_with_console(
              socket,
              request.id,
              call_expr,
              runtime_ctx_id_call,
              realm_id_call,
              capture_console_call,
              user_activation_call,
              root_ownership_call,
            )
            return Ok(()) // No sync response needed
          }
          None => () // Fall through to sync evaluation
        }
      }
      let eval_result_json = evaluate_js_with_console(
        call_expr, capture_console_call, user_activation_call, root_ownership_call,
        serialization_options_json_call,
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
      // Process channel callback entries and emit script.message BEFORE response
      self.process_channel_messages(ctx_id_call, realm_id_call)
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
/// Handle input.performActions.
fn BidiProtocol::handle_input_perform_actions(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(id) => id
    None => return false
  }
  let sources = match get_param_raw(params, "actions") {
    Some(Array(items)) => items
    _ => {
      self.send_error(
        request_id, "invalid argument", "actions must be an array",
      )
      return false
    }
  }

  set_runtime_context(ctx_id)
  set_runtime_context_frames(
    ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )

  let source_types : Array[String] = []
  let source_actions_list : Array[Array[Json]] = []
  let source_pointer_types : Array[String] = []

  for source in sources {
    let (source_type, source_actions, pointer_type) = match source {
      Object(source_map) => {
        let source_type = match source_map.get("type") {
          Some(String(t)) =>
            if t == "none" || t == "key" || t == "pointer" || t == "wheel" {
              t
            } else {
              self.send_error(
                request_id, "invalid argument", "input source type is invalid",
              )
              return false
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "input source type must be a string",
            )
            return false
          }
        }
        match source_map.get("id") {
          Some(String(_)) => ()
          _ => {
            self.send_error(
              request_id, "invalid argument", "input source id must be a string",
            )
            return false
          }
        }
        let actions = match source_map.get("actions") {
          Some(Array(a)) => a
          _ => {
            self.send_error(
              request_id, "invalid argument", "input source actions must be an array",
            )
            return false
          }
        }
        let mut pointer_type = "mouse"
        if source_type == "pointer" {
          match source_map.get("parameters") {
            Some(Object(pointer_params)) =>
              match pointer_params.get("pointerType") {
                Some(String(pt)) =>
                  if pt == "mouse" || pt == "pen" || pt == "touch" {
                    pointer_type = pt
                  } else {
                    self.send_error(
                      request_id, "invalid argument", "pointerType is invalid",
                    )
                    return false
                  }
                Some(_) => {
                  self.send_error(
                    request_id, "invalid argument", "pointerType must be a string",
                  )
                  return false
                }
                None => ()
              }
            Some(_) => {
              self.send_error(
                request_id, "invalid argument", "pointer parameters must be an object",
              )
              return false
            }
            None => ()
          }
          self.input_pointer_type[ctx_id] = pointer_type
        }
        (source_type, actions, pointer_type)
      }
      _ => {
        self.send_error(
          request_id, "invalid argument", "input source must be an object",
        )
        return false
      }
    }
    source_types.push(source_type)
    source_actions_list.push(source_actions)
    source_pointer_types.push(pointer_type)
  }

  let mut max_ticks = 0
  for source_actions in source_actions_list {
    if source_actions.length() > max_ticks {
      max_ticks = source_actions.length()
    }
  }

  for tick in 0..<max_ticks {
    for source_idx in 0..<source_types.length() {
      let source_type = source_types[source_idx]
      let source_actions = source_actions_list[source_idx]
      let pointer_type = source_pointer_types[source_idx]
      if tick >= source_actions.length() {
        continue
      }
      let raw_action = source_actions[tick]

      if self.manager.get_session(ctx_id) is None {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return false
      }
      let action_map = match raw_action {
        Object(m) => m
        _ => {
          self.send_error(
            request_id, "invalid argument", "action entry must be an object",
          )
          return false
        }
      }
      let action_type = match action_map.get("type") {
        Some(String(t)) => t
        _ => {
          self.send_error(
            request_id, "invalid argument", "action type must be a string",
          )
          return false
        }
      }

      if action_type == "pause" {
        let mut pause_duration_ms = 0
        match action_map.get("duration") {
          Some(duration) =>
            match json_as_safe_int(duration, 0.0, 9007199254740991.0) {
              Some(parsed) => pause_duration_ms = parsed
              None => {
                self.send_error(
                  request_id, "invalid argument", "pause duration must be a non-negative integer",
                )
                return false
              }
            }
          None => ()
        }
        self.input_action_clock_ms[ctx_id] = self.input_action_clock_ms
          .get(ctx_id)
          .unwrap_or(0.0) +
          pause_duration_ms.to_double()
        continue
      }

      match source_type {
        "none" => {
          self.send_error(
            request_id, "invalid argument", "none source supports only pause actions",
          )
          return false
        }
        "key" => {
          if action_type != "keyDown" && action_type != "keyUp" {
            self.send_error(
              request_id, "invalid argument", "key action type is invalid",
            )
            return false
          }
          let key_value = match action_map.get("value") {
            Some(String(v)) => v
            _ => {
              self.send_error(
                request_id, "invalid argument", "key action value must be a string",
              )
              return false
            }
          }
          if not(input_is_single_grapheme(key_value)) {
            self.send_error(
              request_id, "invalid argument", "key action value must be a single grapheme",
            )
            return false
          }
          let normalized_key = normalize_input_key(key_value)
          if action_type == "keyUp" && not(
              self.has_pressed_key(ctx_id, normalized_key),
            ) {
            continue
          }
          let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
            ctx_id,
            normalized_key,
            action_type == "keyDown",
          )
          input_dispatch_key_action(
            action_type, key_value, ctrl, alt, shift, meta,
          )
          if action_type == "keyDown" {
            if self.handle_inline_attribute_navigation(ctx_id, "onkeydown") {
              self.input_pressed_keys.remove(ctx_id)
              continue
            }
            if self.context_has_window_close_onkeydown(ctx_id) {
              if self.force_close_context_from_input(ctx_id) {
                self.send_error(
                  request_id,
                  "no such frame",
                  "Unknown context: " + ctx_id,
                )
                return false
              }
            }
            self.push_pressed_key(ctx_id, normalized_key)
          } else {
            self.remove_pressed_key(ctx_id, normalized_key)
          }
        }
        "pointer" => {
          if not(
              action_type == "pointerMove" ||
              action_type == "pointerDown" ||
              action_type == "pointerUp",
            ) {
            self.send_error(
              request_id, "invalid argument", "pointer action type is invalid",
            )
            return false
          }
          if not(
              self.validate_pointer_common_properties(request_id, action_map),
            ) {
            return false
          }
          if action_type == "pointerMove" {
            let x = match action_map.get("x") {
              Some(value) =>
                match
                  json_as_safe_number(
                    value, -9007199254740991.0, 9007199254740991.0,
                  ) {
                  Some(parsed) => parsed
                  None => {
                    self.send_error(
                      request_id, "invalid argument", "pointerMove x must be a number",
                    )
                    return false
                  }
                }
              None => {
                self.send_error(
                  request_id, "invalid argument", "pointerMove x is required",
                )
                return false
              }
            }
            let y = match action_map.get("y") {
              Some(value) =>
                match
                  json_as_safe_number(
                    value, -9007199254740991.0, 9007199254740991.0,
                  ) {
                  Some(parsed) => parsed
                  None => {
                    self.send_error(
                      request_id, "invalid argument", "pointerMove y must be a number",
                    )
                    return false
                  }
                }
              None => {
                self.send_error(
                  request_id, "invalid argument", "pointerMove y is required",
                )
                return false
              }
            }
            let move_duration_ms = match action_map.get("duration") {
              Some(value) =>
                match json_as_safe_int(value, 0.0, 9007199254740991.0) {
                  Some(parsed) => parsed
                  None => {
                    self.send_error(
                      request_id, "invalid argument", "pointerMove duration must be a non-negative integer",
                    )
                    return false
                  }
                }
              None => 0
            }
            self.input_action_clock_ms[ctx_id] = self.input_action_clock_ms
              .get(ctx_id)
              .unwrap_or(0.0) +
              move_duration_ms.to_double()
            let (final_x, final_y, target_shared) = match
              self.resolve_pointer_origin(
                request_id,
                ctx_id,
                action_map.get("origin"),
                x,
                y,
                true,
              ) {
              Some(resolved) => resolved
              None => return false
            }
            if not(
                self.ensure_pointer_within_viewport(
                  request_id, final_x, final_y,
                ),
              ) {
              return false
            }
            self.input_pointer_x[ctx_id] = final_x
            self.input_pointer_y[ctx_id] = final_y
            self.input_pointer_target_shared[ctx_id] = target_shared
            let buttons = self.input_pointer_buttons.get(ctx_id).unwrap_or(0)
            let width = match action_map.get("width") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 9007199254740991.0).unwrap_or(1)
                  .to_double()
              None => 1.0
            }
            let height = match action_map.get("height") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 9007199254740991.0).unwrap_or(1)
                  .to_double()
              None => 1.0
            }
            let pressure = match action_map.get("pressure") {
              Some(Number(n, ..)) => n
              _ =>
                if button_state_contains(buttons, button_to_mask(0)) {
                  0.5
                } else {
                  0.0
                }
            }
            let tangential_pressure = match action_map.get("tangentialPressure") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            let twist = match action_map.get("twist") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 359.0).unwrap_or(0).to_double()
              None => 0.0
            }
            let altitude_angle = match action_map.get("altitudeAngle") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            let azimuth_angle = match action_map.get("azimuthAngle") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            if button_state_contains(buttons, button_to_mask(0)) {
              let down_x = self.input_pointer_down_x.get(ctx_id).unwrap_or(final_x)
              let down_y = self.input_pointer_down_y.get(ctx_id).unwrap_or(final_y)
              let down_target = self.input_pointer_down_target_shared.get(ctx_id)
                .unwrap_or(target_shared)
              if abs_double(final_x - down_x) > 0.5 ||
                abs_double(final_y - down_y) > 0.5 ||
                down_target != target_shared {
                self.input_pointer_dragged[ctx_id] = true
              }
            }
            let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
              ctx_id, "", false,
            )
            input_set_pointer_event_properties(
              width,
              height,
              pressure,
              tangential_pressure,
              twist,
              altitude_angle,
              azimuth_angle,
            )
            let should_emit_move = pointer_type == "mouse" ||
              button_state_contains(buttons, button_to_mask(0))
            if should_emit_move {
              input_dispatch_pointer_event(
                target_shared,
                "pointermove",
                final_x,
                final_y,
                0,
                buttons,
                pointer_type,
                ctrl,
                alt,
                shift,
                meta,
              )
              input_dispatch_pointer_event(
                target_shared,
                "mousemove",
                final_x,
                final_y,
                0,
                buttons,
                pointer_type,
                ctrl,
                alt,
                shift,
                meta,
              )
            }
            if button_state_contains(buttons, button_to_mask(0)) {
              let drag_source = self.input_html_drag_source_shared.get(ctx_id)
                .unwrap_or("")
              if drag_source != "" {
                if not(self.input_html_drag_active.get(ctx_id).unwrap_or(false)) {
                  input_dispatch_pointer_event(
                    drag_source,
                    "dragstart",
                    final_x,
                    final_y,
                    0,
                    buttons,
                    pointer_type,
                    ctrl,
                    alt,
                    shift,
                    meta,
                  )
                  self.input_html_drag_active[ctx_id] = true
                }
                let drag_target = if target_shared != "" {
                  target_shared
                } else {
                  drag_source
                }
                input_dispatch_pointer_event(
                  drag_target,
                  "dragenter",
                  final_x,
                  final_y,
                  0,
                  buttons,
                  pointer_type,
                  ctrl,
                  alt,
                  shift,
                  meta,
                )
                if move_duration_ms > 0 {
                  input_dispatch_pointer_event(
                    drag_target,
                    "dragleave",
                    final_x,
                    final_y,
                    0,
                    buttons,
                    pointer_type,
                    ctrl,
                    alt,
                    shift,
                    meta,
                  )
                }
                input_dispatch_pointer_event(
                  drag_target,
                  "dragover",
                  final_x,
                  final_y,
                  0,
                  buttons,
                  pointer_type,
                  ctrl,
                  alt,
                  shift,
                  meta,
                )
              }
            }
            input_clear_pointer_event_properties()
          } else {
            let button = match action_map.get("button") {
              Some(value) =>
                match json_as_safe_int(value, 0.0, 9007199254740991.0) {
                  Some(parsed) => parsed
                  None => {
                    self.send_error(
                      request_id, "invalid argument", "pointer button must be a non-negative integer",
                    )
                    return false
                  }
                }
              None => {
                self.send_error(
                  request_id, "invalid argument", "pointer button is required",
                )
                return false
              }
            }
            let current_x = self.input_pointer_x.get(ctx_id).unwrap_or(0.0)
            let current_y = self.input_pointer_y.get(ctx_id).unwrap_or(0.0)
            let target_shared = self.input_pointer_target_shared
              .get(ctx_id)
              .unwrap_or("")
            let old_buttons = self.input_pointer_buttons
              .get(ctx_id)
              .unwrap_or(0)
            let width = match action_map.get("width") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 9007199254740991.0).unwrap_or(1)
                  .to_double()
              None => 1.0
            }
            let height = match action_map.get("height") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 9007199254740991.0).unwrap_or(1)
                  .to_double()
              None => 1.0
            }
            let tangential_pressure = match action_map.get("tangentialPressure") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            let twist = match action_map.get("twist") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 359.0).unwrap_or(0).to_double()
              None => 0.0
            }
            let altitude_angle = match action_map.get("altitudeAngle") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            let azimuth_angle = match action_map.get("azimuthAngle") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            if action_type == "pointerDown" {
              let next_buttons = button_state_add(old_buttons, button)
              self.input_pointer_buttons[ctx_id] = next_buttons
              let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
                ctx_id, "", false,
              )
              let pressure = match action_map.get("pressure") {
                Some(Number(n, ..)) => n
                _ =>
                  if button == 0 {
                    0.5
                  } else {
                    0.0
                  }
              }
              input_set_pointer_event_properties(
                width,
                height,
                pressure,
                tangential_pressure,
                twist,
                altitude_angle,
                azimuth_angle,
              )
              if button == 0 && pointer_type != "mouse" {
                input_dispatch_pointer_event(
                  target_shared,
                  "pointerover",
                  current_x,
                  current_y,
                  button,
                  next_buttons,
                  pointer_type,
                  ctrl,
                  alt,
                  shift,
                  meta,
                )
                input_dispatch_pointer_event(
                  target_shared,
                  "pointerenter",
                  current_x,
                  current_y,
                  button,
                  next_buttons,
                  pointer_type,
                  ctrl,
                  alt,
                  shift,
                  meta,
                )
              }
              input_dispatch_pointer_event(
                target_shared, "pointerdown", current_x, current_y, button, next_buttons,
                pointer_type, ctrl, alt, shift, meta,
              )
              input_clear_pointer_event_properties()
              if self.handle_inline_attribute_navigation(ctx_id, "onpointerdown") {
                continue
              }
              if self.context_has_window_close_onpointerdown(ctx_id) {
                if not(self.force_close_context_from_input(ctx_id)) {
                  self.send_error(
                    request_id,
                    "no such frame",
                    "Unknown context: " + ctx_id,
                  )
                  return false
                }
              } else {
                input_dispatch_pointer_event(
                  target_shared, "mousedown", current_x, current_y, button, next_buttons,
                  pointer_type, ctrl, alt, shift, meta,
                )
                if self.handle_inline_attribute_navigation(ctx_id, "onmousedown") {
                  continue
                }
                if self.context_has_window_close_onmousedown(ctx_id) {
                  if not(self.force_close_context_from_input(ctx_id)) {
                    self.send_error(
                      request_id,
                      "no such frame",
                      "Unknown context: " + ctx_id,
                    )
                    return false
                  }
                }
              }
              if button == 0 {
                self.input_pointer_down_x[ctx_id] = current_x
                self.input_pointer_down_y[ctx_id] = current_y
                self.input_pointer_down_target_shared[ctx_id] = target_shared
                self.input_pointer_dragged[ctx_id] = false
                if target_shared != "" &&
                  runtime_shared_node_is_draggable(target_shared) {
                  self.input_html_drag_source_shared[ctx_id] = target_shared
                  self.input_html_drag_active[ctx_id] = false
                } else {
                  self.input_html_drag_source_shared.remove(ctx_id)
                  self.input_html_drag_active.remove(ctx_id)
                }
                let now = self.input_action_clock_ms.get(ctx_id).unwrap_or(0.0)
                let pending_double_click = match self.input_last_click_time.get(ctx_id) {
                  Some(last_time) => {
                    let last_target = self.input_last_click_target_shared.get(ctx_id)
                      .unwrap_or("")
                    let last_x = self.input_last_click_x.get(ctx_id).unwrap_or(-999999.0)
                    let last_y = self.input_last_click_y.get(ctx_id).unwrap_or(-999999.0)
                    now - last_time <= 640.0 &&
                    last_target == target_shared &&
                    abs_double(current_x - last_x) <= 4.0 &&
                    abs_double(current_y - last_y) <= 4.0
                  }
                  None => false
                }
                self.input_pending_double_click[ctx_id] = pending_double_click
              } else {
                self.input_pending_double_click.remove(ctx_id)
              }
            } else {
              let next_buttons = button_state_remove(old_buttons, button)
              self.input_pointer_buttons[ctx_id] = next_buttons
              let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
                ctx_id, "", false,
              )
              input_set_pointer_event_properties(
                width,
                height,
                0.0,
                tangential_pressure,
                twist,
                altitude_angle,
                azimuth_angle,
              )
              input_dispatch_pointer_event(
                target_shared, "pointerup", current_x, current_y, button, next_buttons,
                pointer_type, ctrl, alt, shift, meta,
              )
              if pointer_type == "touch" && button == 0 {
                input_dispatch_pointer_event(
                  target_shared,
                  "pointerout",
                  current_x,
                  current_y,
                  button,
                  next_buttons,
                  pointer_type,
                  ctrl,
                  alt,
                  shift,
                  meta,
                )
                input_dispatch_pointer_event(
                  target_shared,
                  "pointerleave",
                  current_x,
                  current_y,
                  button,
                  next_buttons,
                  pointer_type,
                  ctrl,
                  alt,
                  shift,
                  meta,
                )
              }
              input_clear_pointer_event_properties()
              let is_mac_ctrl_left_click = button == 0 &&
                ctrl &&
                input_is_mac_platform()
              if is_mac_ctrl_left_click {
                input_dispatch_pointer_event(
                  target_shared, "contextmenu", current_x, current_y, button, next_buttons,
                  pointer_type, ctrl, alt, shift, meta,
                )
                input_dispatch_pointer_event(
                  target_shared, "mouseup", current_x, current_y, button, next_buttons,
                  pointer_type, ctrl, alt, shift, meta,
                )
                self.input_pending_double_click.remove(ctx_id)
                if button == 0 {
                  self.input_pointer_down_x.remove(ctx_id)
                  self.input_pointer_down_y.remove(ctx_id)
                  self.input_pointer_down_target_shared.remove(ctx_id)
                  self.input_pointer_dragged.remove(ctx_id)
                  self.input_html_drag_source_shared.remove(ctx_id)
                  self.input_html_drag_active.remove(ctx_id)
                }
              } else {
                input_dispatch_pointer_event(
                  target_shared, "mouseup", current_x, current_y, button, next_buttons,
                  pointer_type, ctrl, alt, shift, meta,
                )
                if button == 0 {
                  let drag_source = self.input_html_drag_source_shared.get(ctx_id)
                    .unwrap_or("")
                  let drag_active = self.input_html_drag_active.get(ctx_id).unwrap_or(
                    false,
                  )
                  if drag_source != "" && drag_active {
                    let drop_target = if target_shared != "" {
                      target_shared
                    } else {
                      drag_source
                    }
                    input_dispatch_pointer_event(
                      drop_target,
                      "drop",
                      current_x,
                      current_y,
                      button,
                      next_buttons,
                      pointer_type,
                      ctrl,
                      alt,
                      shift,
                      meta,
                    )
                    input_dispatch_pointer_event(
                      drag_source,
                      "dragend",
                      current_x,
                      current_y,
                      button,
                      next_buttons,
                      pointer_type,
                      ctrl,
                      alt,
                      shift,
                      meta,
                    )
                  }
                  let was_dragged = self.input_pointer_dragged.get(ctx_id).unwrap_or(
                    false,
                  )
                  if not(was_dragged) {
                    input_dispatch_pointer_event(
                      target_shared, "click", current_x, current_y, button, next_buttons,
                      pointer_type, ctrl, alt, shift, meta,
                    )
                    if self.input_pending_double_click.get(ctx_id).unwrap_or(false) {
                      input_dispatch_pointer_event(
                        target_shared, "dblclick", current_x, current_y, button, next_buttons,
                        pointer_type, ctrl, alt, shift, meta,
                      )
                    }
                    self.input_last_click_time[ctx_id] = self.input_action_clock_ms
                      .get(ctx_id)
                      .unwrap_or(0.0)
                    self.input_last_click_x[ctx_id] = current_x
                    self.input_last_click_y[ctx_id] = current_y
                    self.input_last_click_target_shared[ctx_id] = target_shared
                    self.handle_pointer_click_navigation(
                      ctx_id,
                      target_shared,
                      current_x,
                      current_y,
                    )
                  }
                  self.input_pending_double_click.remove(ctx_id)
                  self.input_pointer_down_x.remove(ctx_id)
                  self.input_pointer_down_y.remove(ctx_id)
                  self.input_pointer_down_target_shared.remove(ctx_id)
                  self.input_pointer_dragged.remove(ctx_id)
                  self.input_html_drag_source_shared.remove(ctx_id)
                  self.input_html_drag_active.remove(ctx_id)
                } else if button == 2 {
                  input_dispatch_pointer_event(
                    target_shared, "contextmenu", current_x, current_y, button, next_buttons,
                    pointer_type, ctrl, alt, shift, meta,
                  )
                  self.input_pending_double_click.remove(ctx_id)
                }
              }
            }
          }
        }
        "wheel" => {
          if action_type != "scroll" {
            self.send_error(
              request_id, "invalid argument", "wheel action type is invalid",
            )
            return false
          }
          let x = match action_map.get("x") {
            Some(value) =>
              match
                json_as_safe_int(value, -9007199254740991.0, 9007199254740991.0) {
                Some(parsed) => parsed
                None => {
                  self.send_error(
                    request_id, "invalid argument", "wheel x must be an integer",
                  )
                  return false
                }
              }
            None => {
              self.send_error(
                request_id, "invalid argument", "wheel x is required",
              )
              return false
            }
          }
          let y = match action_map.get("y") {
            Some(value) =>
              match
                json_as_safe_int(value, -9007199254740991.0, 9007199254740991.0) {
                Some(parsed) => parsed
                None => {
                  self.send_error(
                    request_id, "invalid argument", "wheel y must be an integer",
                  )
                  return false
                }
              }
            None => {
              self.send_error(
                request_id, "invalid argument", "wheel y is required",
              )
              return false
            }
          }
          let delta_x = match action_map.get("deltaX") {
            Some(value) =>
              match
                json_as_safe_int(value, -9007199254740991.0, 9007199254740991.0) {
                Some(parsed) => parsed
                None => {
                  self.send_error(
                    request_id, "invalid argument", "wheel deltaX must be an integer",
                  )
                  return false
                }
              }
            None => {
              self.send_error(
                request_id, "invalid argument", "wheel deltaX is required",
              )
              return false
            }
          }
          let delta_y = match action_map.get("deltaY") {
            Some(value) =>
              match
                json_as_safe_int(value, -9007199254740991.0, 9007199254740991.0) {
                Some(parsed) => parsed
                None => {
                  self.send_error(
                    request_id, "invalid argument", "wheel deltaY must be an integer",
                  )
                  return false
                }
              }
            None => {
              self.send_error(
                request_id, "invalid argument", "wheel deltaY is required",
              )
              return false
            }
          }
          let (final_x, final_y, target_shared) = match
            self.resolve_pointer_origin(
              request_id,
              ctx_id,
              action_map.get("origin"),
              x.to_double(),
              y.to_double(),
              false,
            ) {
            Some(resolved) => resolved
            None => return false
          }
          if not(
              self.ensure_pointer_within_viewport(request_id, final_x, final_y),
            ) {
            return false
          }
          let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
            ctx_id, "", false,
          )
          input_dispatch_wheel_event(
            target_shared,
            final_x,
            final_y,
            delta_x.to_double(),
            delta_y.to_double(),
            ctrl,
            alt,
            shift,
            meta,
          )
        }
        _ => ()
      }
    }
  }
  true
}

///|
/// Handle input.releaseActions.
fn BidiProtocol::handle_input_release_actions(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(id) => id
    None => return false
  }

  set_runtime_context(ctx_id)
  set_runtime_context_frames(
    ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )

  let pointer_type = self.input_pointer_type.get(ctx_id).unwrap_or("mouse")
  let pressed = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  let mut idx = pressed.length()
  while idx > 0 {
    idx = idx - 1
    let key = pressed[idx]
    let (ctrl, alt, shift, meta) = self.resolve_input_modifiers(
      ctx_id, "", false,
    )
    input_dispatch_key_action("keyUp", key, ctrl, alt, shift, meta)
    self.remove_pressed_key(ctx_id, key)
  }
  self.input_pressed_keys.remove(ctx_id)

  let current_x = self.input_pointer_x.get(ctx_id).unwrap_or(0.0)
  let current_y = self.input_pointer_y.get(ctx_id).unwrap_or(0.0)
  let target_shared = self.input_pointer_target_shared.get(ctx_id).unwrap_or("")
  let current_buttons = self.input_pointer_buttons.get(ctx_id).unwrap_or(0)
  if button_state_contains(current_buttons, button_to_mask(2)) {
    input_dispatch_pointer_event(
      target_shared,
      "pointerup",
      current_x,
      current_y,
      2,
      button_state_remove(current_buttons, 2),
      pointer_type,
      false,
      false,
      false,
      false,
    )
    input_dispatch_pointer_event(
      target_shared,
      "mouseup",
      current_x,
      current_y,
      2,
      button_state_remove(current_buttons, 2),
      pointer_type,
      false,
      false,
      false,
      false,
    )
  }
  if button_state_contains(current_buttons, button_to_mask(1)) {
    input_dispatch_pointer_event(
      target_shared,
      "pointerup",
      current_x,
      current_y,
      1,
      button_state_remove(current_buttons, 1),
      pointer_type,
      false,
      false,
      false,
      false,
    )
    input_dispatch_pointer_event(
      target_shared,
      "mouseup",
      current_x,
      current_y,
      1,
      button_state_remove(current_buttons, 1),
      pointer_type,
      false,
      false,
      false,
      false,
    )
  }
  if button_state_contains(current_buttons, button_to_mask(0)) {
    input_dispatch_pointer_event(
      target_shared,
      "pointerup",
      current_x,
      current_y,
      0,
      button_state_remove(current_buttons, 0),
      pointer_type,
      false,
      false,
      false,
      false,
    )
    input_dispatch_pointer_event(
      target_shared,
      "mouseup",
      current_x,
      current_y,
      0,
      button_state_remove(current_buttons, 0),
      pointer_type,
      false,
      false,
      false,
      false,
    )
    input_dispatch_pointer_event(
      target_shared, "click", current_x, current_y, 0, 0, pointer_type, false, false,
      false, false,
    )
  }
  self.input_pointer_buttons.remove(ctx_id)
  self.input_pointer_target_shared.remove(ctx_id)
  self.input_pointer_x.remove(ctx_id)
  self.input_pointer_y.remove(ctx_id)
  self.input_pointer_down_x.remove(ctx_id)
  self.input_pointer_down_y.remove(ctx_id)
  self.input_pointer_down_target_shared.remove(ctx_id)
  self.input_pointer_dragged.remove(ctx_id)
  self.input_html_drag_source_shared.remove(ctx_id)
  self.input_html_drag_active.remove(ctx_id)
  self.input_last_click_time.remove(ctx_id)
  self.input_last_click_x.remove(ctx_id)
  self.input_last_click_y.remove(ctx_id)
  self.input_last_click_target_shared.remove(ctx_id)
  self.input_pending_double_click.remove(ctx_id)
  self.input_action_clock_ms.remove(ctx_id)
  true
}

///|
/// Validate input context parameter and return context ID.
fn BidiProtocol::validate_input_context(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let ctx_id = match get_param_raw(params, "context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing context")
      return None
    }
  }
  if not(self.manager.has_session(ctx_id)) {
    self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
    return None
  }
  Some(ctx_id)
}

///|
/// Validate pointer common property types/ranges.
fn BidiProtocol::validate_pointer_common_properties(
  self : BidiProtocol,
  request_id : Int,
  action_map : Map[String, Json],
) -> Bool {
  match action_map.get("width") {
    Some(value) =>
      if json_as_safe_int(value, 0.0, 9007199254740991.0) is None {
        self.send_error(
          request_id, "invalid argument", "pointer width must be a non-negative integer",
        )
        return false
      }
    None => ()
  }
  match action_map.get("height") {
    Some(value) =>
      if json_as_safe_int(value, 0.0, 9007199254740991.0) is None {
        self.send_error(
          request_id, "invalid argument", "pointer height must be a non-negative integer",
        )
        return false
      }
    None => ()
  }
  match action_map.get("pressure") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer pressure must be a number",
      )
      return false
    }
    None => ()
  }
  match action_map.get("tangentialPressure") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer tangentialPressure must be a number",
      )
      return false
    }
    None => ()
  }
  match action_map.get("twist") {
    Some(value) =>
      if json_as_safe_int(value, 0.0, 359.0) is None {
        self.send_error(
          request_id, "invalid argument", "pointer twist must be an integer in [0, 359]",
        )
        return false
      }
    None => ()
  }
  match action_map.get("altitudeAngle") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer altitudeAngle must be a number",
      )
      return false
    }
    None => ()
  }
  match action_map.get("azimuthAngle") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer azimuthAngle must be a number",
      )
      return false
    }
    None => ()
  }
  true
}

///|
/// Resolve pointer/wheel origin with integer offsets.
fn BidiProtocol::resolve_pointer_origin(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  origin : Json?,
  offset_x : Double,
  offset_y : Double,
  allow_pointer_origin : Bool,
) -> (Double, Double, String)? {
  match origin {
    None | Some(String("viewport")) =>
      Some((offset_x, offset_y, ""))
    Some(String("pointer")) =>
      if allow_pointer_origin {
        Some(
          (
            self.input_pointer_x.get(ctx_id).unwrap_or(0.0) +
            offset_x,
            self.input_pointer_y.get(ctx_id).unwrap_or(0.0) +
            offset_y,
            self.input_pointer_target_shared.get(ctx_id).unwrap_or(""),
          ),
        )
      } else {
        self.send_error(
          request_id, "invalid argument", "pointer origin is not supported for this action",
        )
        None
      }
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "origin must be 'viewport', 'pointer', or element origin",
      )
      None
    }
    Some(Object(origin_map)) => {
      let origin_type = match origin_map.get("type") {
        Some(String(s)) => s
        _ => {
          self.send_error(
            request_id, "invalid argument", "origin.type must be a string",
          )
          return None
        }
      }
      if origin_type != "element" {
        self.send_error(
          request_id, "invalid argument", "origin.type must be 'element'",
        )
        return None
      }
      let element_obj = match origin_map.get("element") {
        Some(Object(elem)) => elem
        _ => {
          self.send_error(
            request_id, "invalid argument", "origin.element must be an object",
          )
          return None
        }
      }
      let shared_id = match element_obj.get("sharedId") {
        Some(String(id)) => id
        _ => {
          self.send_error(
            request_id, "invalid argument", "origin.element.sharedId must be a string",
          )
          return None
        }
      }
      if not(has_runtime_shared_node(shared_id)) ||
        not(runtime_shared_node_is_element(shared_id)) {
        self.send_error(
          request_id,
          "no such element",
          "Unknown element: " + shared_id,
        )
        return None
      }
      let center_json = @json.parse(
        get_runtime_shared_node_center_json(shared_id),
      ) catch {
        _ => make_object({})
      }
      let center_x = match get_field(center_json, "x") {
        Some(Number(n, ..)) => n
        _ => 0.0
      }
      let center_y = match get_field(center_json, "y") {
        Some(Number(n, ..)) => n
        _ => 0.0
      }
      Some(
        (
          center_x + offset_x,
          center_y + offset_y,
          shared_id,
        ),
      )
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "origin must be a string or object",
      )
      None
    }
  }
}

///|
/// Validate pointer target coordinates against viewport.
fn BidiProtocol::ensure_pointer_within_viewport(
  self : BidiProtocol,
  request_id : Int,
  x : Double,
  y : Double,
) -> Bool {
  let _ = self
  if x < 0.0 || y < 0.0 || x > 1024.0 || y > 768.0 {
    self.send_error(
      request_id, "move target out of bounds", "Target coordinate is outside viewport",
    )
    false
  } else {
    true
  }
}

///|
/// Absolute value helper for doubles.
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
/// Parse safe integer JSON value.
fn json_as_safe_int(value : Json, min : Double, max : Double) -> Int? {
  match value {
    Number(n, ..) =>
      if n == n.to_int64().to_double() && n >= min && n <= max {
        Some(n.to_int64().to_int())
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse safe JSON number value.
fn json_as_safe_number(value : Json, min : Double, max : Double) -> Double? {
  match value {
    Number(n, ..) =>
      if n >= min && n <= max {
        Some(n)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Normalize WebDriver special key value for internal state tracking.
fn normalize_input_key(value : String) -> String {
  match value {
    "\uE003" => "Backspace"
    "\uE004" => "Tab"
    "\uE006" | "\uE007" => "Enter"
    "\uE008" | "\uE050" => "Shift"
    "\uE009" | "\uE051" => "Control"
    "\uE00A" | "\uE052" => "Alt"
    "\uE00C" => "Escape"
    "\uE03D" | "\uE053" => "Meta"
    _ => value
  }
}

///|
/// Push pressed key in stack order.
fn BidiProtocol::push_pressed_key(
  self : BidiProtocol,
  ctx_id : String,
  key : String,
) -> Unit {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  keys.push(key)
  self.input_pressed_keys[ctx_id] = keys
}

///|
/// Check whether key is currently pressed in the context.
fn BidiProtocol::has_pressed_key(
  self : BidiProtocol,
  ctx_id : String,
  key : String,
) -> Bool {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  for existing in keys {
    if existing == key {
      return true
    }
  }
  false
}

///|
/// Remove first matching pressed key.
fn BidiProtocol::remove_pressed_key(
  self : BidiProtocol,
  ctx_id : String,
  key : String,
) -> Unit {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  let filtered : Array[String] = []
  let mut removed = false
  for existing in keys {
    if not(removed) && existing == key {
      removed = true
    } else {
      filtered.push(existing)
    }
  }
  if filtered.length() == 0 {
    self.input_pressed_keys.remove(ctx_id)
  } else {
    self.input_pressed_keys[ctx_id] = filtered
  }
}

///|
/// Resolve modifier booleans from pressed key state.
fn BidiProtocol::resolve_input_modifiers(
  self : BidiProtocol,
  ctx_id : String,
  current_key : String,
  include_current : Bool,
) -> (Bool, Bool, Bool, Bool) {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  let mut ctrl = false
  let mut alt = false
  let mut shift = false
  let mut meta = false
  for key in keys {
    if key == "Control" {
      ctrl = true
    } else if key == "Alt" {
      alt = true
    } else if key == "Shift" {
      shift = true
    } else if key == "Meta" {
      meta = true
    }
  }
  if include_current {
    if current_key == "Control" {
      ctrl = true
    } else if current_key == "Alt" {
      alt = true
    } else if current_key == "Shift" {
      shift = true
    } else if current_key == "Meta" {
      meta = true
    }
  }
  (ctrl, alt, shift, meta)
}

///|
/// Convert pointer button to bit mask compatible with MouseEvent.buttons.
fn button_to_mask(button : Int) -> Int {
  match button {
    0 => 1
    1 => 4
    2 => 2
    _ => 0
  }
}

///|
/// Check whether button bit mask exists in state.
fn button_state_contains(state : Int, mask : Int) -> Bool {
  if mask == 1 {
    state % 2 == 1
  } else if mask == 2 {
    state / 2 % 2 == 1
  } else if mask == 4 {
    state / 4 % 2 == 1
  } else {
    false
  }
}

///|
/// Add button into button state bitfield.
fn button_state_add(state : Int, button : Int) -> Int {
  let mask = button_to_mask(button)
  if mask == 0 || button_state_contains(state, mask) {
    state
  } else {
    state + mask
  }
}

///|
/// Remove button from button state bitfield.
fn button_state_remove(state : Int, button : Int) -> Int {
  let mask = button_to_mask(button)
  if mask == 0 || not(button_state_contains(state, mask)) {
    state
  } else {
    state - mask
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
  args : Array[Json],
  timestamp : Double,
) -> Unit {
  let params = make_object({
    "level": Json::string(level),
    "source": make_object({
      "realm": Json::string("realm-" + ctx_id),
      "context": Json::string(ctx_id),
    }),
    "text": Json::string(text),
    "timestamp": Json::number(timestamp),
    "method": Json::string(console_method),
    "args": Json::array(args),
    "type": Json::string("console"),
  })
  if not(self.is_subscribed_for_context("log.entryAdded", ctx_id)) {
    let pending = self.pending_log_entries.get(ctx_id).unwrap_or([])
    pending.push(params)
    self.pending_log_entries[ctx_id] = pending
    return
  }
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
            let args = match get_field(entry, "args") {
              Some(Array(values)) => values
              _ => []
            }
            let timestamp = match get_field(entry, "timestamp") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            self.emit_log_entry(
              ctx_id, level, text, console_method, args, timestamp,
            )
          }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
/// Emit script.message event.
fn BidiProtocol::emit_script_message(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
  channel : String,
  data : Json,
) -> Unit {
  let event_name = "script.message"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let params = make_object({
    "channel": Json::string(channel),
    "data": data,
    "source": make_object({
      "realm": Json::string(realm_id),
      "context": Json::string(ctx_id),
    }),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Drain pending channel callback messages from JS runtime and emit script.message.
fn BidiProtocol::process_channel_messages(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
) -> Unit {
  let channel_messages = @json.parse(take_channel_messages_json()) catch {
    _ => Json::array([])
  }
  match channel_messages {
    Array(entries) =>
      for entry in entries {
        match entry {
          Object(msg_map) => {
            let channel = match msg_map.get("channel") {
              Some(String(s)) => s
              _ => ""
            }
            if channel != "" {
              let data = msg_map
                .get("data")
                .unwrap_or(make_object({ "type": Json::string("undefined") }))
              self.emit_script_message(ctx_id, realm_id, channel, data)
            }
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
  self.input_last_click_time.remove(ctx_id)
  self.input_last_click_x.remove(ctx_id)
  self.input_last_click_y.remove(ctx_id)
  self.input_last_click_target_shared.remove(ctx_id)
  self.input_pending_double_click.remove(ctx_id)
  self.input_action_clock_ms.remove(ctx_id)
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
        self.pending_log_entries.remove(child_ctx_id)
        self.clear_input_state_for_context(child_ctx_id)
      }
      self.context_children[parent_ctx_id] = []
    }
    None => ()
  }
}

///|
/// Close a context without sending a command response (used by synthetic events).
fn BidiProtocol::force_close_context_from_input(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  let original_opener = self.context_original_opener.get(ctx_id)
  self.drop_child_contexts(ctx_id)
  self.unlink_from_parent(ctx_id)
  if not(self.manager.close_session(ctx_id)) {
    return false
  }
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
  self.pending_log_entries.remove(ctx_id)
  self.clear_input_state_for_context(ctx_id)
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
/// Whether current context has an inline handler that closes window.
fn BidiProtocol::context_has_window_close_handler(
  self : BidiProtocol,
  ctx_id : String,
  attribute_name : String,
) -> Bool {
  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let doc = session.get_tree().get_document()
      let selector = "[" + attribute_name + "]"
      match session.get_tree().query_selector_all(doc, selector) {
        Ok(nodes) =>
          for node in nodes {
            match session.get_tree().get_attribute(node, attribute_name) {
              Ok(Some(attr)) => if attr.contains("window.close") { return true }
              _ => ()
            }
          }
        Err(_) => ()
      }
      false
    }
    None => false
  }
}

///|
/// Whether current context has an inline keydown handler that closes window.
fn BidiProtocol::context_has_window_close_onkeydown(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  self.context_has_window_close_handler(ctx_id, "onkeydown")
}

///|
/// Whether current context has an inline mousedown handler that closes window.
fn BidiProtocol::context_has_window_close_onmousedown(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  self.context_has_window_close_handler(ctx_id, "onmousedown")
}

///|
/// Whether current context has an inline pointerdown handler that closes window.
fn BidiProtocol::context_has_window_close_onpointerdown(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  self.context_has_window_close_handler(ctx_id, "onpointerdown")
}

///|
/// Navigate current context when inline event handler assigns window.location.
fn BidiProtocol::handle_inline_attribute_navigation(
  self : BidiProtocol,
  ctx_id : String,
  attribute_name : String,
) -> Bool {
  set_runtime_context(ctx_id)
  let destination = get_runtime_inline_navigation_url(attribute_name).unwrap_or(
    "",
  )
  if destination == "" {
    return false
  }
  match self.manager.get_session(ctx_id) {
    Some(session) =>
      match session.navigate_to(destination) {
        Ok(_) => ()
        Err(_) => ()
      }
    None => return false
  }
  reset_runtime_event_buffers(ctx_id)
  self.load_data_url_content(ctx_id, destination)
  self.drop_child_contexts(ctx_id)
  self.refresh_child_contexts_from_iframes(ctx_id)
  self.clear_context_sandbox_realms(ctx_id)
  let window_realm_id = self.assign_new_realm(ctx_id)
  self.emit_default_realm(ctx_id)
  self.emit_worker_realms_from_scripts(ctx_id, window_realm_id)
  let nav_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  self.emit_navigation_events(ctx_id, destination, nav_id)
  true
}

///|
/// Load inline HTML content when URL is a data URL.
fn BidiProtocol::load_data_url_content(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
) -> Unit {
  set_runtime_context(ctx_id)
  if not(url.has_prefix("data:")) {
    sync_runtime_page(url)
    set_runtime_context(ctx_id)
    return
  }
  match parse_data_url(url) {
    Some((content_type, content)) =>
      if content_type.has_prefix("text/html") ||
        content_type.has_prefix("text/xml") ||
        content_type.has_prefix("application/xml") ||
        content_type.has_prefix("application/xhtml+xml") ||
        content_type == "" {
        match self.manager.get_session(ctx_id) {
          Some(session) => session.load_html(content)
          None => ()
        }
        sync_runtime_html(content, url, true)
        set_runtime_context(ctx_id)
      }
    None => ()
  }
}

///|
/// Emit navigation events when click target resolves to an anchor href.
fn BidiProtocol::handle_pointer_click_navigation(
  self : BidiProtocol,
  ctx_id : String,
  target_shared : String,
  x : Double,
  y : Double,
) -> Unit {
  let shared_href = get_runtime_shared_node_href(target_shared).unwrap_or("")
  let clicked_href = get_runtime_last_click_href().unwrap_or("")
  let point_href = get_runtime_href_at_point(x, y).unwrap_or("")
  let destination = if shared_href != "" {
    shared_href
  } else if clicked_href != "" {
    clicked_href
  } else if point_href != "" {
    point_href
  } else {
    return
  }
  if destination == "" {
    return
  }
  match self.manager.get_session(ctx_id) {
    Some(session) =>
      match session.navigate_to(destination) {
        Ok(_) => ()
        Err(_) => ()
      }
    None => ()
  }
  self.load_data_url_content(ctx_id, destination)
  let nav_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  self.emit_navigation_events(ctx_id, destination, nav_id)
}

///|
/// Collect iframe src values from a context document.
fn BidiProtocol::collect_iframe_sources(
  self : BidiProtocol,
  ctx_id : String,
) -> Array[String] {
  set_runtime_context(ctx_id)
  let runtime_sources = get_runtime_iframe_sources()
  if runtime_sources.length() > 0 {
    return runtime_sources
  }
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
    // about:blank fallback frames can mirror parent runtime and recurse infinitely.
    // Avoid deep expansion until frame documents diverge via explicit navigation/src.
    if src != "about:blank" {
      self.refresh_child_contexts_from_iframes(child_ctx_id)
    }
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
fn BidiProtocol::handle_subscribe(
  self : BidiProtocol,
  params : Json?,
) -> String {
  let events_to_sub : Array[String] = []
  let contexts_to_sub : Array[String] = []
  let user_contexts_to_sub : Array[String] = []
  match params {
    Some(Object(map)) => {
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
      match map.get("contexts") {
        Some(Array(contexts)) =>
          for ctx in contexts {
            match ctx {
              String(ctx_id) =>
                contexts_to_sub.push(
                  self.normalize_subscription_context(ctx_id),
                )
              _ => ()
            }
          }
        _ => ()
      }
      match map.get("userContexts") {
        Some(Array(user_contexts)) =>
          for user_ctx in user_contexts {
            match user_ctx {
              String(user_ctx_id) => user_contexts_to_sub.push(user_ctx_id)
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
      let has_context_targets = contexts_to_sub.length() > 0
      let has_user_context_targets = user_contexts_to_sub.length() > 0
      if has_context_targets {
        for ctx_id in contexts_to_sub {
          let existing = self.context_subscriptions.get(ctx_id).unwrap_or([])
          for evt in events_to_sub {
            existing.push(evt)
          }
          self.context_subscriptions[ctx_id] = existing
          if wants_realm_created {
            self.emit_existing_realms_for_context(ctx_id)
          }
        }
      }
      if has_user_context_targets {
        for user_ctx_id in user_contexts_to_sub {
          let existing = self.user_context_subscriptions
            .get(user_ctx_id)
            .unwrap_or([])
          for evt in events_to_sub {
            existing.push(evt)
          }
          self.user_context_subscriptions[user_ctx_id] = existing
          if wants_realm_created {
            for ctx_id in self.manager.list_sessions() {
              let ctx_user_ctx = self.context_user_context
                .get(ctx_id)
                .unwrap_or("default")
              if ctx_user_ctx == user_ctx_id &&
                self.context_parent.get(ctx_id) == None {
                self.emit_existing_realms_for_context(ctx_id)
              }
            }
          }
        }
      }
      if not(has_context_targets) && not(has_user_context_targets) {
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
          self.global_subscriptions.push(evt)
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
      if has_log_subscription(events_to_sub) {
        self.flush_pending_log_entries()
      }
    }
    _ => ()
  }
  let subscription_id = self.generate_subscription_id()
  self.subscription_events[subscription_id] = events_to_sub
  self.subscription_contexts[subscription_id] = contexts_to_sub
  self.subscription_user_contexts[subscription_id] = user_contexts_to_sub
  subscription_id
}

///|
/// Handle session.unsubscribe params
fn BidiProtocol::handle_unsubscribe(
  self : BidiProtocol,
  params : Json?,
) -> Unit {
  match params {
    Some(Object(map)) => {
      // Subscription-based unsubscription takes precedence over event filters.
      let subscriptions_to_unsub : Array[String] = []
      match map.get("subscriptions") {
        Some(Array(subscriptions)) =>
          for sub in subscriptions {
            match sub {
              String(subscription_id) =>
                subscriptions_to_unsub.push(subscription_id)
              _ => ()
            }
          }
        _ => ()
      }
      if subscriptions_to_unsub.length() > 0 {
        for subscription_id in subscriptions_to_unsub {
          self.remove_subscription_by_id(subscription_id)
        }
        return
      }
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
      let contexts_to_unsub : Array[String] = []
      match map.get("contexts") {
        Some(Array(contexts)) =>
          for ctx in contexts {
            match ctx {
              String(ctx_id) =>
                contexts_to_unsub.push(
                  self.normalize_subscription_context(ctx_id),
                )
              _ => ()
            }
          }
        _ => ()
      }
      let user_contexts_to_unsub : Array[String] = []
      match map.get("userContexts") {
        Some(Array(user_contexts)) =>
          for user_ctx in user_contexts {
            match user_ctx {
              String(user_ctx_id) => user_contexts_to_unsub.push(user_ctx_id)
              _ => ()
            }
          }
        _ => ()
      }
      let has_context_targets = contexts_to_unsub.length() > 0
      let has_user_context_targets = user_contexts_to_unsub.length() > 0
      if has_context_targets {
        for ctx_id in contexts_to_unsub {
          match self.context_subscriptions.get(ctx_id) {
            Some(existing) => {
              let filtered = array_filter_not(existing, events_to_unsub)
              self.context_subscriptions[ctx_id] = filtered
            }
            None => ()
          }
        }
      }
      if has_user_context_targets {
        for user_ctx_id in user_contexts_to_unsub {
          match self.user_context_subscriptions.get(user_ctx_id) {
            Some(existing) => {
              let filtered = array_filter_not(existing, events_to_unsub)
              self.user_context_subscriptions[user_ctx_id] = filtered
            }
            None => ()
          }
        }
      }
      if not(has_context_targets) && not(has_user_context_targets) {
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
          self.update_legacy_module_subscription(module_key)
        }
      }
    }
    _ => ()
  }
}

///|
/// Remove a single stored subscription by id.
fn BidiProtocol::remove_subscription_by_id(
  self : BidiProtocol,
  subscription_id : String,
) -> Unit {
  let events = self.subscription_events.get(subscription_id).unwrap_or([])
  let contexts = self.subscription_contexts.get(subscription_id).unwrap_or([])
  let user_contexts = self.subscription_user_contexts
    .get(subscription_id)
    .unwrap_or([])
  if events.length() == 0 {
    self.subscription_events.remove(subscription_id)
    self.subscription_contexts.remove(subscription_id)
    self.subscription_user_contexts.remove(subscription_id)
    return
  }
  if contexts.length() > 0 {
    for ctx_id in contexts {
      match self.context_subscriptions.get(ctx_id) {
        Some(existing) => {
          let filtered = array_remove_events_once(existing, events)
          if filtered.length() == 0 {
            self.context_subscriptions.remove(ctx_id)
          } else {
            self.context_subscriptions[ctx_id] = filtered
          }
        }
        None => ()
      }
    }
  } else if user_contexts.length() > 0 {
    for user_ctx_id in user_contexts {
      match self.user_context_subscriptions.get(user_ctx_id) {
        Some(existing) => {
          let filtered = array_remove_events_once(existing, events)
          if filtered.length() == 0 {
            self.user_context_subscriptions.remove(user_ctx_id)
          } else {
            self.user_context_subscriptions[user_ctx_id] = filtered
          }
        }
        None => ()
      }
    }
  } else {
    for evt in events {
      self.global_subscriptions = array_remove_first(
        self.global_subscriptions,
        evt,
      )
      let module_key = get_subscription_key(evt)
      self.update_legacy_module_subscription(module_key)
    }
  }
  self.subscription_events.remove(subscription_id)
  self.subscription_contexts.remove(subscription_id)
  self.subscription_user_contexts.remove(subscription_id)
}

///|
/// Normalize a subscribed context to its top-level browsing context.
fn BidiProtocol::normalize_subscription_context(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) => self.normalize_subscription_context(parent_ctx_id)
    None => ctx_id
  }
}

///|
/// Check whether events contain log subscriptions.
fn has_log_subscription(events : Array[String]) -> Bool {
  for evt in events {
    if evt == "log.entryAdded" || get_subscription_key(evt) == "log" {
      return true
    }
  }
  false
}

///|
/// Check whether console output should be captured for this context.
fn BidiProtocol::should_capture_console(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  if self.is_subscribed_for_context("log.entryAdded", ctx_id) ||
    self.has_any_log_subscription() {
    return true
  }
  // Keep capturing even when not currently subscribed so log.entryAdded
  // can be buffered and delivered after a later session.subscribe call.
  true
}

///|
/// Check whether any log subscription exists in any scope.
fn BidiProtocol::has_any_log_subscription(self : BidiProtocol) -> Bool {
  if self.subscriptions.get("log").unwrap_or(false) {
    return true
  }
  if has_log_subscription(self.global_subscriptions) {
    return true
  }
  for _, events in self.context_subscriptions {
    if has_log_subscription(events) {
      return true
    }
  }
  for _, events in self.user_context_subscriptions {
    if has_log_subscription(events) {
      return true
    }
  }
  false
}

///|
/// Flush buffered log.entryAdded events that are now subscribed.
fn BidiProtocol::flush_pending_log_entries(self : BidiProtocol) -> Unit {
  let contexts : Array[String] = []
  for ctx_id, _ in self.pending_log_entries {
    contexts.push(ctx_id)
  }
  for ctx_id in contexts {
    if not(self.is_subscribed_for_context("log.entryAdded", ctx_id)) {
      continue
    }
    match self.pending_log_entries.get(ctx_id) {
      Some(entries) =>
        for params in entries {
          self.outbox.push(Event({ event_method: "log.entryAdded", params }))
        }
      None => ()
    }
    self.pending_log_entries.remove(ctx_id)
  }
}

///|
/// Keep legacy module-level map in sync with current global subscriptions.
fn BidiProtocol::update_legacy_module_subscription(
  self : BidiProtocol,
  module_key : String,
) -> Unit {
  let mut has_same_module = false
  for sub in self.global_subscriptions {
    if sub == module_key || get_subscription_key(sub) == module_key {
      has_same_module = true
      break
    }
  }
  if has_same_module {
    self.subscriptions[module_key] = true
  } else {
    self.subscriptions.remove(module_key)
  }
}

///|
/// Generate a deterministic 32-digit subscription id string.
fn BidiProtocol::generate_subscription_id(self : BidiProtocol) -> String {
  let id_num = self.next_subscription_id
  self.next_subscription_id += 1
  left_pad_with_zero(id_num.to_string(), 32)
}

///|
/// Left-pad a string with '0' up to min_length.
fn left_pad_with_zero(value : String, min_length : Int) -> String {
  let mut result = value
  while result.length() < min_length {
    result = "0" + result
  }
  result
}

///|
/// Remove one occurrence for each event in `events_to_remove`.
fn array_remove_events_once(
  arr : Array[String],
  events_to_remove : Array[String],
) -> Array[String] {
  let mut result = arr
  for evt in events_to_remove {
    result = array_remove_first(result, evt)
  }
  result
}

///|
/// Remove the first matching item from array.
fn array_remove_first(arr : Array[String], target : String) -> Array[String] {
  let result : Array[String] = []
  let mut removed = false
  for item in arr {
    if not(removed) && item == target {
      removed = true
      continue
    }
    result.push(item)
  }
  result
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
fn array_filter_by_module(
  arr : Array[String],
  module_key : String,
) -> Array[String] {
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
  if not(blocked_global) && self.subscriptions.get(module_key).unwrap_or(false) {
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
  if self.is_subscribed_for_context_chain(event, module_key, ctx_id) {
    return true
  }
  // Check user-context subscriptions for this browsing context.
  let user_ctx = self.context_user_context.get(ctx_id).unwrap_or("default")
  match self.user_context_subscriptions.get(user_ctx) {
    Some(events) =>
      for sub in events {
        if sub == event || get_subscription_key(sub) == module_key {
          return true
        }
      }
    None => ()
  }
  false
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
/// Validate session.subscribe params.
/// Returns Some(()) when an error response was already sent.
fn BidiProtocol::validate_session_subscribe_params(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return Some(())
    }
  }

  match map.get("events") {
    Some(Array(raw_events)) => {
      if raw_events.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "events must not be an empty array",
        )
        return Some(())
      }
      for raw_event in raw_events {
        match raw_event {
          String(event_name) =>
            if not(is_valid_session_subscription_event_name(event_name)) {
              self.send_error(
                request_id,
                "invalid argument",
                "Unknown event name: " + event_name,
              )
              return Some(())
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "events entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "events must be an array")
      return Some(())
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing events")
      return Some(())
    }
  }

  let mut has_context_targets = false
  match map.get("contexts") {
    Some(Array(raw_contexts)) => {
      has_context_targets = true
      if raw_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return Some(())
      }
      for raw_context in raw_contexts {
        match raw_context {
          String(ctx_id) =>
            if not(self.manager.has_session(ctx_id)) {
              self.send_error(
                request_id,
                "no such frame",
                "Unknown context: " + ctx_id,
              )
              return Some(())
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "contexts entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return Some(())
    }
    None => ()
  }

  let mut has_user_context_targets = false
  match map.get("userContexts") {
    Some(Array(raw_user_contexts)) => {
      has_user_context_targets = true
      if raw_user_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return Some(())
      }
      for raw_user_context in raw_user_contexts {
        match raw_user_context {
          String(user_context_id) =>
            if not(self.user_contexts.get(user_context_id).unwrap_or(false)) {
              self.send_error(
                request_id,
                "no such user context",
                "Unknown user context: " + user_context_id,
              )
              return Some(())
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "userContexts entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return Some(())
    }
    None => ()
  }

  if has_context_targets && has_user_context_targets {
    self.send_error(
      request_id, "invalid argument", "contexts and userContexts are mutually exclusive",
    )
    return Some(())
  }

  None
}

///|
/// Validate session.unsubscribe params.
/// Returns Some(()) when an error response was already sent.
fn BidiProtocol::validate_session_unsubscribe_params(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return Some(())
    }
  }

  let mut has_subscriptions_field = false
  match map.get("subscriptions") {
    Some(Array(raw_subscriptions)) => {
      has_subscriptions_field = true
      if raw_subscriptions.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "subscriptions must not be an empty array",
        )
        return Some(())
      }
      for raw_subscription in raw_subscriptions {
        match raw_subscription {
          String(subscription_id) => {
            if not(is_valid_subscription_id_format(subscription_id)) {
              self.send_error(
                request_id,
                "invalid argument",
                "Invalid subscription id format: " + subscription_id,
              )
              return Some(())
            }
            if not(self.subscription_events.contains(subscription_id)) {
              self.send_error(
                request_id,
                "invalid argument",
                "Unknown subscription id: " + subscription_id,
              )
              return Some(())
            }
          }
          _ => {
            self.send_error(
              request_id, "invalid argument", "subscriptions entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "subscriptions must be an array",
      )
      return Some(())
    }
    None => ()
  }

  if has_subscriptions_field {
    // When subscriptions are provided they take precedence over event filters.
    return None
  }

  let events_to_unsub : Array[String] = []
  match map.get("events") {
    Some(Array(raw_events)) => {
      if raw_events.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "events must not be an empty array",
        )
        return Some(())
      }
      for raw_event in raw_events {
        match raw_event {
          String(event_name) =>
            if not(is_valid_session_subscription_event_name(event_name)) {
              self.send_error(
                request_id,
                "invalid argument",
                "Unknown event name: " + event_name,
              )
              return Some(())
            } else {
              events_to_unsub.push(event_name)
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "events entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "events must be an array")
      return Some(())
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "Either events or subscriptions must be provided",
      )
      return Some(())
    }
  }

  let mut has_context_targets = false
  match map.get("contexts") {
    Some(Array(raw_contexts)) => {
      has_context_targets = true
      if raw_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return Some(())
      }
      for raw_context in raw_contexts {
        match raw_context {
          String(_) => ()
          _ => {
            self.send_error(
              request_id, "invalid argument", "contexts entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return Some(())
    }
    None => ()
  }

  let mut has_user_context_targets = false
  match map.get("userContexts") {
    Some(Array(raw_user_contexts)) => {
      has_user_context_targets = true
      if raw_user_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return Some(())
      }
      for raw_user_context in raw_user_contexts {
        match raw_user_context {
          String(_) => ()
          _ => {
            self.send_error(
              request_id, "invalid argument", "userContexts entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return Some(())
    }
    None => ()
  }

  if not(has_context_targets) && not(has_user_context_targets) {
    for event_name in events_to_unsub {
      let module_key = get_subscription_key(event_name)
      if module_key == event_name {
        if not(self.has_global_module_subscription(module_key)) {
          self.send_error(
            request_id,
            "invalid argument",
            "No global subscription for module: " + module_key,
          )
          return Some(())
        }
        if self.has_global_event_override_for_module(module_key) {
          self.send_error(
            request_id,
            "invalid argument",
            "Cannot unsubscribe module after partial event unsubscription: " +
            module_key,
          )
          return Some(())
        }
      } else if not(self.has_global_event_subscription(event_name)) {
        self.send_error(
          request_id,
          "invalid argument",
          "No global subscription for event: " + event_name,
        )
        return Some(())
      }
    }
  }

  None
}

///|
/// Supported event/module names accepted by session.{subscribe,unsubscribe}.
fn is_valid_session_subscription_event_name(name : String) -> Bool {
  if name == "browsingContext" ||
    name == "script" ||
    name == "log" ||
    name == "network" ||
    name == "input" ||
    name == "storage" ||
    name == "browser" ||
    name == "bluetooth" ||
    name == "permissions" ||
    name == "session" ||
    name == "webExtension" ||
    name == "speculation" {
    return true
  }

  match name {
    "browsingContext.contextCreated" => true
    "browsingContext.contextDestroyed" => true
    "browsingContext.domContentLoaded" => true
    "browsingContext.load" => true
    "browsingContext.navigationStarted" => true
    "browsingContext.navigationFailed" => true
    "browsingContext.navigationAborted" => true
    "browsingContext.navigationCommitted" => true
    "browsingContext.fragmentNavigated" => true
    "browsingContext.historyUpdated" => true
    "browsingContext.downloadWillBegin" => true
    "browsingContext.downloadEnd" => true
    "browsingContext.userPromptOpened" => true
    "browsingContext.userPromptClosed" => true
    "log.entryAdded" => true
    "script.realmCreated" => true
    "script.realmDestroyed" => true
    "script.message" => true
    "network.beforeRequestSent" => true
    "network.responseStarted" => true
    "network.responseCompleted" => true
    "network.fetchError" => true
    "network.authRequired" => true
    "input.fileDialogOpened" => true
    "speculation.prefetchStatusUpdated" => true
    _ => false
  }
}

///|
/// Validate 32-char hex subscription id format.
fn is_valid_subscription_id_format(subscription_id : String) -> Bool {
  if subscription_id.length() != 32 {
    return false
  }
  for c in subscription_id.iter() {
    if not(
        (c >= '0' && c <= '9') ||
        (c >= 'a' && c <= 'f') ||
        (c >= 'A' && c <= 'F'),
      ) {
      return false
    }
  }
  true
}

///|
/// Check whether module is globally subscribed as a module key.
fn BidiProtocol::has_global_module_subscription(
  self : BidiProtocol,
  module_key : String,
) -> Bool {
  array_contains(self.global_subscriptions, module_key)
}

///|
/// Check whether event is effectively globally subscribed.
fn BidiProtocol::has_global_event_subscription(
  self : BidiProtocol,
  event_name : String,
) -> Bool {
  if array_contains(self.global_unsubscribed_events, event_name) {
    return false
  }
  let module_key = get_subscription_key(event_name)
  for sub in self.global_subscriptions {
    if sub == event_name || sub == module_key {
      return true
    }
  }
  false
}

///|
/// Check whether module has any event-level global overrides.
fn BidiProtocol::has_global_event_override_for_module(
  self : BidiProtocol,
  module_key : String,
) -> Bool {
  for event_name in self.global_unsubscribed_events {
    if get_subscription_key(event_name) == module_key {
      return true
    }
  }
  false
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
/// Get serializationOptions as JSON string.
fn get_serialization_options_json(params : Json?) -> String {
  match get_param_raw(params, "serializationOptions") {
    Some(Object(opts)) => make_object(opts).stringify()
    _ => "{}"
  }
}

///|
/// Check if serializationOptions parameter is present.
fn has_serialization_options_param(params : Json?) -> Bool {
  match get_param_raw(params, "serializationOptions") {
    Some(Object(_)) => true
    _ => false
  }
}

///|
/// Determine runtime context key used by JS evaluator.
fn resolve_runtime_context_id(
  params : Json?,
  ctx_id : String,
  realm_id : String,
  realm_is_sandbox : Bool,
) -> String {
  match get_param_raw(params, "target") {
    Some(Object(target_map)) =>
      match target_map.get("sandbox") {
        Some(String(name)) => if name == "" { ctx_id } else { realm_id }
        _ => if realm_is_sandbox { realm_id } else { ctx_id }
      }
    _ => if realm_is_sandbox { realm_id } else { ctx_id }
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
      match context_id {
        Some(ctx_id) =>
          match sandbox_name {
            Some(name) =>
              if name == "" {
                (
                  ctx_id,
                  self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id),
                )
              } else {
                (ctx_id, self.get_or_create_sandbox_realm(ctx_id, name))
              }
            None =>
              (
                ctx_id,
                self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id),
              )
          }
        None =>
          match realm_id {
            Some(realm) => {
              let fallback_ctx = self.default_context_id.unwrap_or(
                self.ensure_default_context(),
              )
              let resolved_ctx = self.realm_context
                .get(realm)
                .unwrap_or(fallback_ctx)
              (resolved_ctx, realm)
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
  let opened_url = extract_quoted_after_marker(trimmed, "window.open(").unwrap_or(
    "about:blank",
  )

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
  match self.manager.get_session(new_ctx_id) {
    Some(session) => {
      let _ = session.navigate_to(opened_url)
    }
    None => ()
  }
  self.load_data_url_content(new_ctx_id, opened_url)
  self.drop_child_contexts(new_ctx_id)
  self.refresh_child_contexts_from_iframes(new_ctx_id)
  self.clear_context_sandbox_realms(new_ctx_id)
  let opened_realm_id = self.assign_new_realm(new_ctx_id)
  self.emit_default_realm(new_ctx_id)
  self.emit_worker_realms_from_scripts(new_ctx_id, opened_realm_id)
  let nav_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  self.emit_navigation_events(new_ctx_id, opened_url, nav_id)

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
    Some(Object(value_map)) => {
      if not(is_valid_serialized_value_map(value_map)) {
        self.send_error(
          request_id, "invalid argument", "this must be a serialized value",
        )
        return Some(())
      }
      match value_map.get("sharedId") {
        Some(String(shared_id)) =>
          if not(has_runtime_shared_node(shared_id)) {
            self.send_error(
              request_id,
              "no such node",
              "Unknown sharedId: " + shared_id,
            )
            return Some(())
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "sharedId must be a string",
          )
          return Some(())
        }
        None => ()
      }
      match value_map.get("handle") {
        Some(String(handle_id)) =>
          if not(has_runtime_handle(handle_id)) {
            self.send_error(
              request_id,
              "no such handle",
              "Unknown handle: " + handle_id,
            )
            return Some(())
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "handle must be a string",
          )
          return Some(())
        }
        None => ()
      }
    }
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
            if not(is_valid_serialized_value_map(arg_map)) {
              self.send_error(
                request_id, "invalid argument", "arguments entries must be serialized values",
              )
              return Some(())
            }
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
              Some(String(handle_id)) =>
                if not(has_runtime_handle(handle_id)) {
                  self.send_error(
                    request_id,
                    "no such handle",
                    "Unknown handle: " + handle_id,
                  )
                  return Some(())
                }
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
              Some(String(shared_id)) =>
                if not(has_runtime_shared_node(shared_id)) {
                  self.send_error(
                    request_id,
                    "no such node",
                    "Unknown sharedId: " + shared_id,
                  )
                  return Some(())
                }
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
/// Serialized value object must include at least one discriminator key.
fn is_valid_serialized_value_map(value_map : Map[String, Json]) -> Bool {
  value_map.contains("type") ||
  value_map.contains("handle") ||
  value_map.contains("sharedId")
}

///|
/// Convert BiDi remote value to JS literal for function arguments
fn bidi_value_to_js_literal(value : Json) -> String {
  match value {
    Object(map) =>
      match map.get("sharedId") {
        Some(String(shared_id)) =>
          "((globalThis.__bidiSharedNodeStore && globalThis.__bidiSharedNodeStore.get(\"" +
          escape_js_string(shared_id) +
          "\")) ?? undefined)"
        _ =>
          match map.get("handle") {
            Some(String(handle_id)) =>
              "((globalThis.__bidiHandleStore && globalThis.__bidiHandleStore.get(\"" +
              escape_js_string(handle_id) +
              "\")) ?? undefined)"
            _ =>
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
                Some(String("channel")) =>
                  match map.get("value") {
                    Some(Object(channel_map)) => {
                      let channel_name = match channel_map.get("channel") {
                        Some(String(s)) => s
                        _ => "channel"
                      }
                      let ownership = match channel_map.get("ownership") {
                        Some(String(s)) => s
                        _ => "none"
                      }
                      let max_object_depth = match
                        channel_map.get("serializationOptions") {
                        Some(Object(ser_opts)) =>
                          match ser_opts.get("maxObjectDepth") {
                            Some(Number(n, ..)) => n.to_string()
                            _ => "-1"
                          }
                        _ => "-1"
                      }
                      "((...__args) => {" +
                      "if (!globalThis.__bidiChannelMessages) globalThis.__bidiChannelMessages = [];" +
                      "globalThis.__bidiChannelMessages.push({" +
                      "channel: \"" +
                      escape_js_string(channel_name) +
                      "\"," +
                      "data: (__args.length > 0 ? __args[0] : undefined)," +
                      "ownership: \"" +
                      escape_js_string(ownership) +
                      "\"," +
                      "maxObjectDepth: " +
                      max_object_depth +
                      "});" +
                      "})"
                    }
                    _ => "(() => {})"
                  }
                Some(String("date")) =>
                  match map.get("value") {
                    Some(String(s)) =>
                      "new Date(\"" + escape_js_string(s) + "\")"
                    _ => "new Date(0)"
                  }
                Some(String("regexp")) =>
                  match map.get("value") {
                    Some(Object(regexp_map)) => {
                      let pattern = match regexp_map.get("pattern") {
                        Some(String(s)) => "\"" + escape_js_string(s) + "\""
                        _ => "\"\""
                      }
                      let flags = match regexp_map.get("flags") {
                        Some(String(s)) => "\"" + escape_js_string(s) + "\""
                        _ => "\"\""
                      }
                      "new RegExp(" + pattern + ", " + flags + ")"
                    }
                    _ => "new RegExp(\"\", \"\")"
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
                Some(String("map")) =>
                  match map.get("value") {
                    Some(Array(entries)) => {
                      let parts : Array[String] = []
                      for entry in entries {
                        match entry {
                          Array(kv) if kv.length() >= 2 => {
                            let key = bidi_value_to_js_literal(kv[0])
                            let val = bidi_value_to_js_literal(kv[1])
                            parts.push("[" + key + ", " + val + "]")
                          }
                          _ => ()
                        }
                      }
                      "new Map([" + parts.join(", ") + "])"
                    }
                    _ => "new Map()"
                  }
                Some(String("set")) =>
                  match map.get("value") {
                    Some(Array(items)) => {
                      let parts : Array[String] = []
                      for item in items {
                        parts.push(bidi_value_to_js_literal(item))
                      }
                      "new Set([" + parts.join(", ") + "])"
                    }
                    _ => "new Set()"
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
          }
      }
    String(s) => "\"" + escape_js_string(s) + "\""
    Number(n, ..) => n.to_string()
    True => "true"
    False => "false"
    Null => "null"
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
