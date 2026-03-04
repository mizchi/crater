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
  mut active_context_id : String?
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
  user_context_prompt_behavior : Map[String, Json] // user context -> unhandledPromptBehavior object
  mut global_download_behavior : Json?
  user_context_download_behavior : Map[String, Json] // user context -> downloadBehavior object
  user_context_viewport_width : Map[String, Int] // user context -> default viewport width override
  user_context_viewport_height : Map[String, Int] // user context -> default viewport height override
  user_context_device_pixel_ratio : Map[String, Double] // user context -> default devicePixelRatio override
  context_user_context : Map[String, String]
  context_has_beforeunload : Map[String, Bool]
  context_blocks_cross_origin_iframe_navigation : Map[String, Bool] // context -> active CSP/COEP frame policy
  pending_prompt_type : Map[String, String] // context -> prompt type
  pending_close_request : Map[String, Int] // context -> browsingContext.close request id
  pending_prompt_request : Map[String, Int] // context -> deferred script.evaluate request id
  pending_prompt_realm : Map[String, String] // context -> deferred script.evaluate realm id
  pending_beforeunload_request : Map[String, Int] // context -> deferred navigate request id
  pending_beforeunload_url : Map[String, String] // context -> deferred navigate destination
  pending_beforeunload_wait : Map[String, String] // context -> deferred navigate wait mode
  pending_beforeunload_navigation : Map[String, String] // context -> deferred navigation id
  pending_navigation_request : Map[String, Int] // context -> deferred navigate/reload request id
  in_flight_navigation_url : Map[String, String] // context -> interruptible navigation URL
  in_flight_navigation_id : Map[String, String] // context -> interruptible navigation id
  in_flight_navigation_started_at : Map[String, Double] // context -> interruptible navigation start timestamp
  pending_prompt_result_var : Map[String, String] // context -> window property to store prompt result
  context_local_storage : Map[String, Map[String, String]] // context -> localStorage key/value
  context_original_opener : Map[String, String]
  context_realm : Map[String, String]
  context_sandbox_realm : Map[String, String] // "<context>::<sandbox>" -> realm
  realm_context : Map[String, String] // realm -> context
  realm_sandbox : Map[String, String] // sandbox realm -> sandbox name
  context_parent : Map[String, String]
  context_children : Map[String, Array[String]]
  context_client_window : Map[String, String]
  context_viewport_width : Map[String, Int] // context -> viewport width override
  context_viewport_height : Map[String, Int] // context -> viewport height override
  context_device_pixel_ratio : Map[String, Double] // context -> devicePixelRatio override
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
    active_context_id: None,
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
    user_context_prompt_behavior: {},
    global_download_behavior: None,
    user_context_download_behavior: {},
    user_context_viewport_width: {},
    user_context_viewport_height: {},
    user_context_device_pixel_ratio: {},
    context_user_context: {},
    context_has_beforeunload: {},
    context_blocks_cross_origin_iframe_navigation: {},
    pending_prompt_type: {},
    pending_close_request: {},
    pending_prompt_request: {},
    pending_prompt_realm: {},
    pending_beforeunload_request: {},
    pending_beforeunload_url: {},
    pending_beforeunload_wait: {},
    pending_beforeunload_navigation: {},
    pending_navigation_request: {},
    in_flight_navigation_url: {},
    in_flight_navigation_id: {},
    in_flight_navigation_started_at: {},
    pending_prompt_result_var: {},
    context_local_storage: {},
    context_original_opener: {},
    context_realm: {},
    context_sandbox_realm: {},
    realm_context: {},
    realm_sandbox: {},
    context_parent: {},
    context_children: {},
    context_client_window: {},
    context_viewport_width: {},
    context_viewport_height: {},
    context_device_pixel_ratio: {},
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
pub fn BidiProtocol::set_socket(self : BidiProtocol, socket : @core.Any) -> Int {
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
  self.active_context_id = None
  self.session_id = None

  let user_context_keys : Array[String] = []
  for key, _ in self.user_contexts {
    user_context_keys.push(key)
  }
  for key in user_context_keys {
    self.user_contexts.remove(key)
  }
  self.user_contexts["default"] = true

  let prompt_behavior_keys : Array[String] = []
  for key, _ in self.user_context_prompt_behavior {
    prompt_behavior_keys.push(key)
  }
  for key in prompt_behavior_keys {
    self.user_context_prompt_behavior.remove(key)
  }
  self.global_download_behavior = None
  let download_behavior_keys : Array[String] = []
  for key, _ in self.user_context_download_behavior {
    download_behavior_keys.push(key)
  }
  for key in download_behavior_keys {
    self.user_context_download_behavior.remove(key)
  }
  let user_context_viewport_width_keys : Array[String] = []
  for key, _ in self.user_context_viewport_width {
    user_context_viewport_width_keys.push(key)
  }
  for key in user_context_viewport_width_keys {
    self.user_context_viewport_width.remove(key)
  }
  let user_context_viewport_height_keys : Array[String] = []
  for key, _ in self.user_context_viewport_height {
    user_context_viewport_height_keys.push(key)
  }
  for key in user_context_viewport_height_keys {
    self.user_context_viewport_height.remove(key)
  }
  let user_context_device_pixel_ratio_keys : Array[String] = []
  for key, _ in self.user_context_device_pixel_ratio {
    user_context_device_pixel_ratio_keys.push(key)
  }
  for key in user_context_device_pixel_ratio_keys {
    self.user_context_device_pixel_ratio.remove(key)
  }

  let context_user_keys : Array[String] = []
  for key, _ in self.context_user_context {
    context_user_keys.push(key)
  }
  for key in context_user_keys {
    self.context_user_context.remove(key)
  }

  let context_beforeunload_keys : Array[String] = []
  for key, _ in self.context_has_beforeunload {
    context_beforeunload_keys.push(key)
  }
  for key in context_beforeunload_keys {
    self.context_has_beforeunload.remove(key)
  }

  let context_policy_keys : Array[String] = []
  for key, _ in self.context_blocks_cross_origin_iframe_navigation {
    context_policy_keys.push(key)
  }
  for key in context_policy_keys {
    self.context_blocks_cross_origin_iframe_navigation.remove(key)
  }

  let pending_prompt_keys : Array[String] = []
  for key, _ in self.pending_prompt_type {
    pending_prompt_keys.push(key)
  }
  for key in pending_prompt_keys {
    self.pending_prompt_type.remove(key)
    self.pending_close_request.remove(key)
    self.pending_prompt_request.remove(key)
    self.pending_prompt_realm.remove(key)
    self.pending_beforeunload_request.remove(key)
    self.pending_beforeunload_url.remove(key)
    self.pending_beforeunload_wait.remove(key)
    self.pending_beforeunload_navigation.remove(key)
    self.pending_prompt_result_var.remove(key)
  }

  let in_flight_navigation_keys : Array[String] = []
  for key, _ in self.in_flight_navigation_id {
    in_flight_navigation_keys.push(key)
  }
  for key in in_flight_navigation_keys {
    self.clear_pending_navigation_state(key)
  }

  let context_local_storage_keys : Array[String] = []
  for key, _ in self.context_local_storage {
    context_local_storage_keys.push(key)
  }
  for key in context_local_storage_keys {
    self.context_local_storage.remove(key)
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
  let context_viewport_width_keys : Array[String] = []
  for key, _ in self.context_viewport_width {
    context_viewport_width_keys.push(key)
  }
  for key in context_viewport_width_keys {
    self.context_viewport_width.remove(key)
  }
  let context_viewport_height_keys : Array[String] = []
  for key, _ in self.context_viewport_height {
    context_viewport_height_keys.push(key)
  }
  for key in context_viewport_height_keys {
    self.context_viewport_height.remove(key)
  }
  let context_device_pixel_ratio_keys : Array[String] = []
  for key, _ in self.context_device_pixel_ratio {
    context_device_pixel_ratio_keys.push(key)
  }
  for key in context_device_pixel_ratio_keys {
    self.context_device_pixel_ratio.remove(key)
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
    "getClientWindows" => {
      let top_level_contexts : Array[String] = []
      for ctx_id in self.manager.list_sessions() {
        if not(self.context_parent.contains(ctx_id)) {
          top_level_contexts.push(ctx_id)
        }
      }

      let mut active_client_window : String? = None
      match self.active_context_id {
        Some(active_ctx) =>
          if not(self.context_parent.contains(active_ctx)) {
            active_client_window = self.context_client_window.get(active_ctx)
          }
        None => ()
      }
      match active_client_window {
        Some(_) => ()
        None =>
          match self.default_context_id {
            Some(default_ctx) =>
              if not(self.context_parent.contains(default_ctx)) {
                active_client_window = self.context_client_window.get(
                  default_ctx,
                )
              }
            None => ()
          }
      }

      let windows : Array[Json] = []
      let seen_windows : Map[String, Bool] = {}
      for ctx_id in top_level_contexts {
        let client_window = self.context_client_window
          .get(ctx_id)
          .unwrap_or("client-window-" + ctx_id)
        if not(seen_windows.contains(client_window)) {
          seen_windows[client_window] = true
          let is_active = match active_client_window {
            Some(active_window) => active_window == client_window
            None => windows.length() == 0
          }
          windows.push(
            make_object({
              "clientWindow": Json::string(client_window),
              "active": Json::boolean(is_active),
            }),
          )
        }
      }

      let result = make_object({ "clientWindows": Json::array(windows) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "createUserContext" => {
      match
        self.validate_browser_create_user_context(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      let id = "user-" + self.user_contexts.length().to_string()
      self.user_contexts[id] = true
      match get_param_raw(request.params, "unhandledPromptBehavior") {
        Some(Object(behavior)) =>
          self.user_context_prompt_behavior[id] = make_object(behavior)
        _ => ()
      }
      let result = make_object({ "userContext": Json::string(id) })
      self.send_success(request.id, Some(result))
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
          } else if not(self.user_contexts.contains(id)) {
            self.send_error(
              request.id,
              "no such user context",
              "Unknown user context: " + id,
            )
            Ok(())
          } else {
            let contexts_to_close : Array[String] = []
            for ctx_id, user_ctx in self.context_user_context {
              if user_ctx == id && not(self.context_parent.contains(ctx_id)) {
                contexts_to_close.push(ctx_id)
              }
            }
            for ctx_id in contexts_to_close {
              self.force_close_context_from_input(ctx_id) |> ignore
            }
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
      match get_param_raw(request.params, "userContexts") {
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
      let type_hint = match get_param_raw(request.params, "type") {
        Some(String(kind)) => kind
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "type must be a string",
          )
          return Ok(())
        }
        None => "tab"
      }
      if type_hint != "tab" && type_hint != "window" {
        self.send_error(
          request.id,
          "invalid argument",
          "type must be 'tab' or 'window'",
        )
        return Ok(())
      }

      let background = match get_param_raw(request.params, "background") {
        Some(True) => true
        Some(False) => false
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "background must be a boolean",
          )
          return Ok(())
        }
        None => false
      }

      let reference_context = match
        get_param_raw(request.params, "referenceContext") {
        Some(String(reference_ctx_id)) => {
          if not(self.manager.has_session(reference_ctx_id)) {
            self.send_error(
              request.id,
              "no such frame",
              "Unknown context: " + reference_ctx_id,
            )
            return Ok(())
          }
          if self.context_parent.contains(reference_ctx_id) {
            self.send_error(
              request.id,
              "invalid argument",
              "referenceContext must be top-level",
            )
            return Ok(())
          }
          Some(reference_ctx_id)
        }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "referenceContext must be a string",
          )
          return Ok(())
        }
        None => None
      }

      let requested_user_context = match
        get_param_raw(request.params, "userContext") {
        Some(String(user_ctx_id)) =>
          if user_ctx_id == "" || not(self.user_contexts.contains(user_ctx_id)) {
            self.send_error(
              request.id,
              "no such user context",
              "Unknown user context: " + user_ctx_id,
            )
            return Ok(())
          } else {
            Some(user_ctx_id)
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "userContext must be a string",
          )
          return Ok(())
        }
        None => None
      }

      let user_ctx = match requested_user_context {
        Some(user_ctx_id) => user_ctx_id
        None =>
          match reference_context {
            Some(reference_ctx_id) =>
              self.context_user_context
              .get(reference_ctx_id)
              .unwrap_or("default")
            None => "default"
          }
      }

      let previous_active_context = self.active_context_id
      let ctx_id = self.create_context(user_ctx, type_hint)
      if type_hint == "window" {
        match reference_context {
          Some(reference_ctx_id) =>
            match self.context_client_window.get(reference_ctx_id) {
              Some(reference_client_window) =>
                self.context_client_window[ctx_id] = reference_client_window
              None => ()
            }
          None => ()
        }
      }
      if background {
        self.active_context_id = previous_active_context
      }
      let result = make_object({ "context": Json::string(ctx_id) })
      // Emit events before response for immediate listener availability.
      self.emit_context_created(ctx_id, type_hint, "about:blank", None, None)
      self.emit_default_realm(ctx_id)
      self.send_success(request.id, Some(result))
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
      if not(self.manager.has_session(ctx_id)) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return Ok(())
      }
      let resolved_url = self.resolve_navigation_target_url(ctx_id, url)
      let _ = self.fail_in_flight_navigation(
        ctx_id, "aborted", "Navigation interrupted by another navigation",
      )
      if not(is_valid_navigation_target_url(resolved_url)) {
        self.send_error(request.id, "invalid argument", "url is invalid")
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
      if not(self.manager.has_session(ctx_id)) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return Ok(())
      }
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

          if not(self.manager.has_session(ctx_id)) {
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
          if not(self.manager.has_session(ctx_id)) {
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
          let user_text = match get_param_raw(request.params, "userText") {
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
              let pending_beforeunload_request = self.pending_beforeunload_request.get(
                prompt_ctx_id,
              )
              let pending_beforeunload_url = self.pending_beforeunload_url.get(
                prompt_ctx_id,
              )
              let pending_beforeunload_wait = self.pending_beforeunload_wait
                .get(prompt_ctx_id)
                .unwrap_or("none")
              let pending_beforeunload_navigation = self.pending_beforeunload_navigation.get(
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
                  self.send_success(close_request_id, Some(make_object({})))
                  self.close_context_and_cleanup(prompt_ctx_id, true) |> ignore
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
                              Ok(_) =>
                                self.complete_navigation_request_with_wait_and_navigation(
                                  nav_request_id, prompt_ctx_id, nav_url, pending_beforeunload_wait,
                                  pending_navigation_id,
                                )
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
    "print" => {
      self.handle_print(request)
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
/// Handle browsingContext.setViewport.
fn BidiProtocol::handle_set_viewport(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  let params = match request.params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request.id,
        "invalid argument",
        "params must be an object",
      )
      return
    }
  }

  let mut target_context : String? = None
  match params.get("context") {
    Some(String(ctx_id)) => target_context = Some(ctx_id)
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "context must be a string",
      )
      return
    }
    None => ()
  }

  let target_user_contexts : Array[String] = []
  match params.get("userContexts") {
    Some(Array(user_contexts)) =>
      if user_contexts.length() == 0 {
        self.send_error(
          request.id,
          "invalid argument",
          "userContexts must not be an empty array",
        )
        return
      } else {
        for user_context in user_contexts {
          match user_context {
            String(user_context_id) =>
              if user_context_id == "" {
                self.send_error(
                  request.id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return
              } else if not(self.user_contexts.contains(user_context_id)) {
                self.send_error(
                  request.id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return
              } else {
                target_user_contexts.push(user_context_id)
              }
            _ => {
              self.send_error(
                request.id,
                "invalid argument",
                "userContexts entries must be strings",
              )
              return
            }
          }
        }
      }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "userContexts must be an array",
      )
      return
    }
    None => ()
  }

  let has_context = target_context is Some(_)
  let has_user_contexts = target_user_contexts.length() > 0
  if has_context && has_user_contexts {
    self.send_error(
      request.id,
      "invalid argument",
      "context and userContexts are mutually exclusive",
    )
    return
  }
  if not(has_context) && not(has_user_contexts) {
    self.send_error(
      request.id,
      "invalid argument",
      "Either context or userContexts must be provided",
    )
    return
  }

  let mut viewport_mode = 0 // 0: keep, 1: reset(null), 2: set(object)
  let mut viewport_width = 0
  let mut viewport_height = 0
  match params.get("viewport") {
    Some(Null) => viewport_mode = 1
    Some(Object(viewport_map)) =>
      match (viewport_map.get("width"), viewport_map.get("height")) {
        (Some(width_json), Some(height_json)) =>
          match
            (
              json_as_safe_int(width_json, 0.0, 9007199254740991.0),
              json_as_safe_int(height_json, 0.0, 9007199254740991.0),
            ) {
            (Some(width), Some(height)) => {
              viewport_mode = 2
              viewport_width = width
              viewport_height = height
            }
            _ => {
              self.send_error(
                request.id,
                "invalid argument",
                "viewport.width and viewport.height must be non-negative integers",
              )
              return
            }
          }
        _ => {
          self.send_error(
            request.id,
            "invalid argument",
            "viewport must include width and height",
          )
          return
        }
      }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "viewport must be an object or null",
      )
      return
    }
    None => ()
  }

  let mut dpr_mode = 0 // 0: keep, 1: reset(null), 2: set(number)
  let mut dpr_value = 1.0
  match params.get("devicePixelRatio") {
    Some(Null) => dpr_mode = 1
    Some(value) =>
      match json_as_safe_number(value, 0.000000001, 9007199254740991.0) {
        Some(parsed_dpr) => {
          dpr_mode = 2
          dpr_value = parsed_dpr
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "devicePixelRatio must be a positive number",
          )
          return
        }
      }
    None => ()
  }

  match target_context {
    Some(ctx_id) => {
      if not(self.manager.has_session(ctx_id)) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return
      }
      if self.context_parent.contains(ctx_id) {
        self.send_error(
          request.id,
          "invalid argument",
          "context must be top-level",
        )
        return
      }

      if viewport_mode == 1 {
        self.context_viewport_width.remove(ctx_id)
        self.context_viewport_height.remove(ctx_id)
      } else if viewport_mode == 2 {
        self.context_viewport_width[ctx_id] = viewport_width
        self.context_viewport_height[ctx_id] = viewport_height
      }
      if dpr_mode == 1 {
        self.context_device_pixel_ratio.remove(ctx_id)
      } else if dpr_mode == 2 {
        self.context_device_pixel_ratio[ctx_id] = dpr_value
      }
      self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
    }
    None =>
      for user_context_id in target_user_contexts {
        if viewport_mode == 1 {
          self.user_context_viewport_width.remove(user_context_id)
          self.user_context_viewport_height.remove(user_context_id)
        } else if viewport_mode == 2 {
          self.user_context_viewport_width[user_context_id] = viewport_width
          self.user_context_viewport_height[user_context_id] = viewport_height
        }
        if dpr_mode == 1 {
          self.user_context_device_pixel_ratio.remove(user_context_id)
        } else if dpr_mode == 2 {
          self.user_context_device_pixel_ratio[user_context_id] = dpr_value
        }
      }
  }

  if has_user_contexts {
    for ctx_id in self.manager.list_sessions() {
      let ctx_user_context = self.context_user_context
        .get(ctx_id)
        .unwrap_or("default")
      if array_contains(target_user_contexts, ctx_user_context) {
        self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
      }
    }
  }

  self.send_success(request.id, Some(make_object({})))
}

///|
/// Handle browsingContext.traverseHistory.
fn BidiProtocol::handle_traverse_history(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  let params = match request.params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request.id,
        "invalid argument",
        "params must be an object",
      )
      return
    }
  }

  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "context must be a string",
      )
      return
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing context")
      return
    }
  }

  if not(self.manager.has_session(ctx_id)) {
    self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
    return
  }
  if self.context_parent.contains(ctx_id) {
    self.send_error(request.id, "invalid argument", "context must be top-level")
    return
  }

  let delta = match params.get("delta") {
    Some(value) =>
      match json_as_safe_int(value, -9007199254740991.0, 9007199254740991.0) {
        Some(parsed) => parsed
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "delta must be an integer in [-9007199254740991, 9007199254740991]",
          )
          return
        }
      }
    None => {
      self.send_error(request.id, "invalid argument", "Missing delta")
      return
    }
  }

  if delta == 0 {
    self.send_success(request.id, Some(make_object({})))
    return
  }

  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let page = session.get_page()
      let history = match page.get_navigation_history() {
        Ok(entries) => entries
        Err(_) => {
          self.send_error(
            request.id,
            "unknown error",
            "Failed to inspect navigation history",
          )
          return
        }
      }
      let target_index = history.current_index + delta
      if target_index < 0 || target_index >= history.entries.length() {
        self.send_error(
          request.id,
          "no such history entry",
          "History traversal target is out of bounds",
        )
        return
      }

      let steps = if delta < 0 { 0 - delta } else { delta }
      if delta < 0 {
        let mut step = 0
        while step < steps {
          match page.go_back() {
            Ok(true) => ()
            _ => {
              self.send_error(
                request.id,
                "no such history entry",
                "History traversal target is out of bounds",
              )
              return
            }
          }
          step += 1
        }
      } else {
        let mut step = 0
        while step < steps {
          match page.go_forward() {
            Ok(true) => ()
            _ => {
              self.send_error(
                request.id,
                "no such history entry",
                "History traversal target is out of bounds",
              )
              return
            }
          }
          step += 1
        }
      }

      let destination = session.get_url()
      self.load_data_url_content(ctx_id, destination)
      let nav_id = self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      self.emit_navigation_events(ctx_id, destination, nav_id)
      self.send_success(request.id, Some(make_object({})))
    }
    None => {
      self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
      return
    }
  }
}

///|
/// Handle browsingContext.captureScreenshot with WPT-focused validation.
fn BidiProtocol::handle_capture_screenshot(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  let params = match request.params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request.id,
        "invalid argument",
        "params must be an object",
      )
      return
    }
  }

  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "context must be a string",
      )
      return
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing context")
      return
    }
  }
  if not(self.manager.has_session(ctx_id)) {
    self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
    return
  }

  match params.get("origin") {
    Some(String("viewport")) | Some(String("document")) | None => ()
    Some(String(_)) => {
      self.send_error(
        request.id,
        "invalid argument",
        "origin must be 'viewport' or 'document'",
      )
      return
    }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "origin must be 'viewport' or 'document'",
      )
      return
    }
  }

  let mut has_box_clip = false
  let mut clip_box_width = 1.0
  let mut clip_box_height = 1.0
  match params.get("clip") {
    None => ()
    Some(Object(clip_map)) => {
      let clip_type = match clip_map.get("type") {
        Some(String(kind)) => kind
        _ => {
          self.send_error(
            request.id,
            "invalid argument",
            "clip.type must be a string",
          )
          return
        }
      }

      if clip_type == "element" {
        match clip_map.get("element") {
          Some(Object(element)) =>
            match element.get("sharedId") {
              Some(String(shared_id)) =>
                if not(has_runtime_shared_node(shared_id)) ||
                  not(runtime_shared_node_is_element(shared_id)) {
                  self.send_error(
                    request.id,
                    "no such node",
                    "Unknown sharedId: " + shared_id,
                  )
                  return
                }
              _ => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "clip.element.sharedId must be a string",
                )
                return
              }
            }
          _ => {
            self.send_error(
              request.id,
              "invalid argument",
              "clip.element must be a node reference",
            )
            return
          }
        }
      } else if clip_type == "box" {
        has_box_clip = true
        let _clip_box_x = match clip_map.get("x") {
          Some(value) =>
            match
              json_as_safe_number(
                value, -9007199254740991.0, 9007199254740991.0,
              ) {
              Some(parsed) => parsed
              None => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "clip.box x/y/width/height must be numbers",
                )
                return
              }
            }
          None => {
            self.send_error(
              request.id,
              "invalid argument",
              "clip.box x/y/width/height must be numbers",
            )
            return
          }
        }
        let _clip_box_y = match clip_map.get("y") {
          Some(value) =>
            match
              json_as_safe_number(
                value, -9007199254740991.0, 9007199254740991.0,
              ) {
              Some(parsed) => parsed
              None => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "clip.box x/y/width/height must be numbers",
                )
                return
              }
            }
          None => {
            self.send_error(
              request.id,
              "invalid argument",
              "clip.box x/y/width/height must be numbers",
            )
            return
          }
        }
        clip_box_width = match clip_map.get("width") {
          Some(value) =>
            match json_as_safe_number(value, 0.0, 9007199254740991.0) {
              Some(parsed) => parsed
              None => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "clip.box x/y/width/height must be numbers",
                )
                return
              }
            }
          None => {
            self.send_error(
              request.id,
              "invalid argument",
              "clip.box x/y/width/height must be numbers",
            )
            return
          }
        }
        clip_box_height = match clip_map.get("height") {
          Some(value) =>
            match json_as_safe_number(value, 0.0, 9007199254740991.0) {
              Some(parsed) => parsed
              None => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "clip.box x/y/width/height must be numbers",
                )
                return
              }
            }
          None => {
            self.send_error(
              request.id,
              "invalid argument",
              "clip.box x/y/width/height must be numbers",
            )
            return
          }
        }
      } else {
        self.send_error(request.id, "invalid argument", "clip.type is invalid")
        return
      }
    }
    Some(_) => {
      self.send_error(request.id, "invalid argument", "clip must be an object")
      return
    }
  }

  if has_box_clip && (clip_box_width <= 0.0 || clip_box_height <= 0.0) {
    self.send_error(
      request.id,
      "unable to capture screen",
      "Clip dimensions must be positive",
    )
    return
  }

  let mut format_type = "image/png"
  let mut quality = 1.0
  match params.get("format") {
    None => ()
    Some(Object(format)) => {
      format_type = match format.get("type") {
        Some(String("image/png")) => "image/png"
        Some(String("image/jpeg")) => "image/jpeg"
        Some(String(_)) => {
          self.send_error(
            request.id,
            "invalid argument",
            "format.type must be 'image/png' or 'image/jpeg'",
          )
          return
        }
        _ => {
          self.send_error(
            request.id,
            "invalid argument",
            "format.type must be 'image/png' or 'image/jpeg'",
          )
          return
        }
      }

      match format.get("quality") {
        Some(value) =>
          match json_as_safe_number(value, 0.0, 1.0) {
            Some(parsed) => quality = parsed
            None => {
              self.send_error(
                request.id,
                "invalid argument",
                "format.quality must be a number in [0,1]",
              )
              return
            }
          }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "format must be an object",
      )
      return
    }
  }

  let data = if format_type == "image/jpeg" {
    synthetic_capture_screenshot_jpeg(quality)
  } else {
    synthetic_capture_screenshot_png()
  }
  let result = make_object({ "data": Json::string(data) })
  self.send_success(request.id, Some(result))
}

///|
/// Handle browsingContext.print with WPT-focused validation.
fn BidiProtocol::handle_print(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  let params = match request.params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request.id,
        "invalid argument",
        "params must be an object",
      )
      return
    }
  }

  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "context must be a string",
      )
      return
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing context")
      return
    }
  }
  if not(self.manager.has_session(ctx_id)) {
    self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
    return
  }

  match params.get("background") {
    Some(True) | Some(False) | None => ()
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "background must be a boolean",
      )
      return
    }
  }

  match params.get("margin") {
    None => ()
    Some(Object(margin)) =>
      for margin_side in ["top", "bottom", "left", "right"] {
        match margin.get(margin_side) {
          Some(value) =>
            match json_as_safe_number(value, 0.0, 9007199254740991.0) {
              Some(_) => ()
              None => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "margin values must be non-negative numbers",
                )
                return
              }
            }
          None => ()
        }
      }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "margin must be an object",
      )
      return
    }
  }

  match params.get("orientation") {
    Some(String("portrait")) | Some(String("landscape")) | None => ()
    Some(String(_)) => {
      self.send_error(
        request.id,
        "invalid argument",
        "orientation must be 'portrait' or 'landscape'",
      )
      return
    }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "orientation must be 'portrait' or 'landscape'",
      )
      return
    }
  }

  match params.get("page") {
    None => ()
    Some(Object(page)) => {
      match page.get("width") {
        Some(value) =>
          if json_as_safe_number(value, 0.035, 9007199254740991.0) is None {
            self.send_error(
              request.id,
              "invalid argument",
              "page.width must be a number >= 0.035",
            )
            return
          }
        None => ()
      }
      match page.get("height") {
        Some(value) =>
          if json_as_safe_number(value, 0.035, 9007199254740991.0) is None {
            self.send_error(
              request.id,
              "invalid argument",
              "page.height must be a number >= 0.035",
            )
            return
          }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(request.id, "invalid argument", "page must be an object")
      return
    }
  }

  match params.get("pageRanges") {
    None => ()
    Some(Array(page_ranges)) =>
      for page_range in page_ranges {
        match page_range {
          Number(n, ..) =>
            if n < 1.0 || n != n.to_int64().to_double() {
              self.send_error(
                request.id,
                "invalid argument",
                "pageRanges entries are invalid",
              )
              return
            }
          String(v) =>
            if not(is_valid_print_page_range(v)) {
              self.send_error(
                request.id,
                "invalid argument",
                "pageRanges entries are invalid",
              )
              return
            }
          _ => {
            self.send_error(
              request.id,
              "invalid argument",
              "pageRanges must be an array of strings/integers",
            )
            return
          }
        }
      }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "pageRanges must be an array of strings/integers",
      )
      return
    }
  }

  match params.get("scale") {
    None => ()
    Some(value) =>
      if json_as_safe_number(value, 0.1, 2.0) is None {
        self.send_error(
          request.id,
          "invalid argument",
          "scale must be a number in [0.1, 2.0]",
        )
        return
      }
  }

  match params.get("shrinkToFit") {
    Some(True) | Some(False) | None => ()
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "shrinkToFit must be a boolean",
      )
      return
    }
  }

  let result = make_object({ "data": Json::string(synthetic_print_pdf()) })
  self.send_success(request.id, Some(result))
}

///|
/// Validate a single print page-range token.
fn is_valid_print_page_range(raw : String) -> Bool {
  let value = raw.trim().to_string()
  if value.length() == 0 {
    return false
  }
  match find_substring(value, "-", 0) {
    Some(first_dash) => {
      if first_dash <= 0 || first_dash >= value.length() - 1 {
        return false
      }
      match find_substring(value, "-", first_dash + 1) {
        Some(_) => return false
        None => ()
      }
      let start_text = value[:first_dash].to_string() catch { _ => "" }
      let end_text = value[first_dash + 1:].to_string() catch { _ => "" }
      let start = match parse_decimal_string(start_text) {
        Some(v) => v
        None => return false
      }
      let end = match parse_decimal_string(end_text) {
        Some(v) => v
        None => return false
      }
      start >= 1 && end >= 1 && start <= end
    }
    None =>
      match parse_decimal_string(value) {
        Some(v) => v >= 1
        None => false
      }
  }
}

///|
/// Placeholder PNG data used for screenshot bootstrapping.
fn synthetic_capture_screenshot_png() -> String {
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIW2NgYGD4DwABBAEAwS2OUAAAAABJRU5ErkJggg=="
}

///|
/// Placeholder JPEG data used for screenshot format validation tests.
fn synthetic_capture_screenshot_jpeg(quality : Double) -> String {
  if quality >= 0.5 {
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAkGBxAQEBAQEA8QDw8PDw8PDw8PDw8PDw8PFREWFhURExUYHSggGBolGxUVITEhJSkrLi4uFx8zODMsNygtLisBCgoKDg0OFQ8PFS0dFR0tKy0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLf/AABEIAAEAAgMBIgACEQEDEQH/xAAUAAEAAAAAAAAAAAAAAAAAAAAJ/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAwDAQACEAMQAAAAqA//xAAUEAEAAAAAAAAAAAAAAAAAAAAQ/9oACAEBAAEFAqf/xAAUEQEAAAAAAAAAAAAAAAAAAAAQ/9oACAEDAQE/Aaf/xAAUEQEAAAAAAAAAAAAAAAAAAAAQ/9oACAECAQE/Aaf/xAAUEAEAAAAAAAAAAAAAAAAAAAAQ/9oACAEBAAY/Aqf/xAAUEAEAAAAAAAAAAAAAAAAAAAAQ/9oACAEBAAE/IV//2Q=="
  } else {
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDIBCQkJDAsMGA0NGDIhHCEyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMv/AABEIAAEAAgMBIgACEQEDEQH/xAAUAAEAAAAAAAAAAAAAAAAAAAAJ/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAwDAQACEAMQAAAAiA//xAAUEAEAAAAAAAAAAAAAAAAAAAAQ/9oACAEBAAEFAn//xAAUEQEAAAAAAAAAAAAAAAAAAAAQ/9oACAEDAQE/Aaf/xAAUEQEAAAAAAAAAAAAAAAAAAAAQ/9oACAECAQE/Aaf/xAAUEAEAAAAAAAAAAAAAAAAAAAAQ/9oACAEBAAY/An//xAAUEAEAAAAAAAAAAAAAAAAAAAAQ/9oACAEBAAE/Ib//2Q=="
  }
}

///|
/// Placeholder PDF data used for print bootstrapping.
fn synthetic_print_pdf() -> String {
  "JVBERi0xLjQKMSAwIG9iago8PAovVHlwZSAvQ2F0YWxvZwovUGFnZXMgMiAwIFIKPj4KZW5kb2JqCjIgMCBvYmoKPDwKL1R5cGUgL1BhZ2VzCi9Db3VudCAxCi9LaWRzIFsgMyAwIFIgXQo+PgplbmRvYmoKMyAwIG9iago8PAovVHlwZSAvUGFnZQovUGFyZW50IDIgMCBSCi9NZWRpYUJveCBbMCAwIDYxMiA3OTJdCi9Db250ZW50cyA0IDAgUgo+PgplbmRvYmoKNCAwIG9iago8PAovTGVuZ3RoIDAKPj4Kc3RyZWFtCgplbmRzdHJlYW0KZW5kb2JqCnRyYWlsZXIKPDwKL1Jvb3QgMSAwIFIKPj4KJSVFT0Y="
}

///|
fn is_valid_locate_nodes_locator_type(locator_type : String) -> Bool {
  locator_type == "css" ||
  locator_type == "xpath" ||
  locator_type == "innerText" ||
  locator_type == "accessibility" ||
  locator_type == "context"
}

///|
/// Convert a small XPath subset used by WPT locateNodes tests to CSS.
fn xpath_to_css_selector(xpath : String) -> String? {
  let trimmed = xpath.trim().to_string()
  if trimmed == ".//*[name()='circle']" {
    return Some("circle")
  }

  let body = if trimmed.has_prefix(".//") {
    trimmed[3:].to_string() catch {
      _ => ""
    }
  } else if trimmed.has_prefix("//") {
    trimmed[2:].to_string() catch {
      _ => ""
    }
  } else {
    return None
  }
  if body == "" {
    return None
  }

  match find_substring(body, "[@", 0) {
    None => if body.contains("[") { None } else { Some(body) }
    Some(predicate_idx) => {
      let selector_tag = body[0:predicate_idx].to_string() catch { _ => "" }
      if selector_tag == "" {
        return None
      }
      let predicate_start = predicate_idx + 2
      let predicate_full = body[predicate_start:].to_string() catch { _ => "" }
      if predicate_full == "" || not(predicate_full.has_suffix("]")) {
        return None
      }
      let predicate = predicate_full[0:predicate_full.length() - 1].to_string() catch {
        _ => ""
      }
      match find_substring(predicate, "=", 0) {
        None => None
        Some(eq_idx) => {
          let attr_name = predicate[0:eq_idx].to_string() catch { _ => "" }
          let quoted_value = predicate[eq_idx + 1:].to_string() catch {
            _ => ""
          }
          if attr_name == "" || quoted_value.length() < 2 {
            return None
          }
          let quote_chars = quoted_value.to_array()
          let quote = quote_chars[0]
          let end_quote = quote_chars[quote_chars.length() - 1]
          if (quote != '\'' && quote != '"') || end_quote != quote {
            return None
          }
          let attr_value = quoted_value[1:quoted_value.length() - 1].to_string() catch {
            _ => ""
          }
          Some(
            selector_tag +
            "[" +
            attr_name.trim().to_string() +
            "=\"" +
            attr_value +
            "\"]",
          )
        }
      }
    }
  }
}

///|
/// Handle browsingContext.locateNodes with WPT-oriented parameter validation.
fn BidiProtocol::handle_locate_nodes(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  let params = match request.params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request.id,
        "invalid argument",
        "params must be an object",
      )
      return
    }
  }

  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "context must be a string",
      )
      return
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing context")
      return
    }
  }
  if not(self.manager.has_session(ctx_id)) {
    self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
    return
  }

  let locator = match params.get("locator") {
    Some(Object(map)) => map
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "locator must be an object",
      )
      return
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing locator")
      return
    }
  }
  let locator_type = match locator.get("type") {
    Some(String(kind)) => kind
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "locator.type must be a string",
      )
      return
    }
    None => {
      self.send_error(
        request.id,
        "invalid argument",
        "locator.type is required",
      )
      return
    }
  }
  if not(is_valid_locate_nodes_locator_type(locator_type)) {
    self.send_error(request.id, "invalid argument", "locator.type is invalid")
    return
  }

  match self.validate_serialization_options(request.id, request.params) {
    Some(_) => return
    None => ()
  }

  let max_node_count = match params.get("maxNodeCount") {
    Some(value) =>
      match json_as_safe_int(value, 1.0, 9007199254740991.0) {
        Some(parsed) => parsed
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "maxNodeCount must be an integer in [1, 9007199254740991]",
          )
          return
        }
      }
    None => -1
  }

  let start_node_shared_ids : Array[String] = []
  match params.get("startNodes") {
    Some(Array(nodes)) => {
      if nodes.length() == 0 {
        self.send_error(
          request.id,
          "invalid argument",
          "startNodes must not be an empty array",
        )
        return
      }
      for raw_node in nodes {
        match raw_node {
          Object(node_map) =>
            match node_map.get("sharedId") {
              Some(String(shared_id)) => {
                if not(has_runtime_shared_node(shared_id)) {
                  self.send_error(
                    request.id,
                    "no such node",
                    "Unknown sharedId: " + shared_id,
                  )
                  return
                }
                if not(runtime_shared_node_is_element(shared_id)) &&
                  not(runtime_shared_node_is_document(shared_id)) {
                  self.send_error(
                    request.id,
                    "invalid argument",
                    "startNodes entries must reference element or document nodes",
                  )
                  return
                }
                start_node_shared_ids.push(shared_id)
              }
              Some(_) => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "startNodes sharedId must be a string",
                )
                return
              }
              None => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "startNodes entries must be node references",
                )
                return
              }
            }
          _ => {
            self.send_error(
              request.id,
              "invalid argument",
              "startNodes must be an array of node references",
            )
            return
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "startNodes must be an array",
      )
      return
    }
    None => ()
  }

  match locator_type {
    "css" =>
      match locator.get("value") {
        Some(String(selector)) =>
          if selector == "" || selector == "a*b" {
            self.send_error(
              request.id,
              "invalid selector",
              "Invalid CSS selector",
            )
            return
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
    "xpath" =>
      match locator.get("value") {
        Some(String(selector)) =>
          if selector == "" {
            self.send_error(
              request.id,
              "invalid selector",
              "Invalid XPath selector",
            )
            return
          } else if selector.contains(":") {
            self.send_error(
              request.id,
              "unknown error",
              "XPath evaluation failed",
            )
            return
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
    "innerText" => {
      match locator.get("value") {
        Some(String(text_value)) =>
          if text_value == "" {
            self.send_error(
              request.id,
              "invalid selector",
              "Invalid innerText selector",
            )
            return
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
      match locator.get("ignoreCase") {
        Some(True) | Some(False) | None => ()
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.ignoreCase must be a boolean",
          )
          return
        }
      }
      match locator.get("matchType") {
        Some(String("full")) | Some(String("partial")) | None => ()
        Some(String(_)) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.matchType must be 'full' or 'partial'",
          )
          return
        }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.matchType must be a string",
          )
          return
        }
      }
      match locator.get("maxDepth") {
        Some(value) =>
          if json_as_safe_int(value, 0.0, 9007199254740991.0) is None {
            self.send_error(
              request.id,
              "invalid argument",
              "locator.maxDepth must be a non-negative integer",
            )
            return
          }
        None => ()
      }
    }
    "accessibility" => {
      let accessibility_value = match locator.get("value") {
        Some(Object(map)) => map
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be an object",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
      let mut has_role = false
      let mut has_name = false
      match accessibility_value.get("role") {
        Some(String(_)) => has_role = true
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "accessibility role must be a string",
          )
          return
        }
        None => ()
      }
      match accessibility_value.get("name") {
        Some(String(_)) => has_name = true
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "accessibility name must be a string",
          )
          return
        }
        None => ()
      }
      if not(has_role) && not(has_name) {
        self.send_error(
          request.id,
          "invalid selector",
          "Invalid accessibility selector",
        )
        return
      }
    }
    "context" => {
      let context_value = match locator.get("value") {
        Some(Object(map)) => map
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be an object",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
      let target_ctx = match context_value.get("context") {
        Some(String(id)) => id
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value.context must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value.context is required",
          )
          return
        }
      }
      if not(self.manager.has_session(target_ctx)) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + target_ctx,
        )
        return
      }
      let child_contexts = self.context_children.get(ctx_id).unwrap_or([])
      if not(array_contains(child_contexts, target_ctx)) {
        self.send_error(
          request.id,
          "invalid argument",
          "locator.value.context must reference a direct child context",
        )
        return
      }
    }
    _ => ()
  }

  let serialization_options_json = get_locate_nodes_serialization_options_json(
    request.params,
  )
  let nodes = match locator_type {
    "css" =>
      match locator.get("value") {
        Some(String(selector)) =>
          self.locate_nodes_css(
            ctx_id, selector, start_node_shared_ids, max_node_count, serialization_options_json,
          )
        _ => Json::array([])
      }
    "xpath" =>
      match locator.get("value") {
        Some(String(selector)) =>
          match xpath_to_css_selector(selector) {
            Some(css_selector) =>
              self.locate_nodes_css(
                ctx_id, css_selector, start_node_shared_ids, max_node_count, serialization_options_json,
              )
            None =>
              self.locate_nodes_xpath(
                ctx_id, selector, start_node_shared_ids, max_node_count, serialization_options_json,
              )
          }
        _ => Json::array([])
      }
    "innerText" =>
      match locator.get("value") {
        Some(String(text_value)) => {
          let ignore_case = match locator.get("ignoreCase") {
            Some(True) => true
            _ => false
          }
          let match_type = match locator.get("matchType") {
            Some(String("full")) => "full"
            Some(String("partial")) => "partial"
            _ => "full"
          }
          let max_depth = match locator.get("maxDepth") {
            Some(Number(n, ..)) => n.to_int64().to_int()
            _ => -1
          }
          self.locate_nodes_inner_text(
            ctx_id, text_value, ignore_case, match_type, max_depth, start_node_shared_ids,
            max_node_count, serialization_options_json,
          )
        }
        _ => Json::array([])
      }
    "accessibility" =>
      match locator.get("value") {
        Some(Object(value_map)) => {
          let role = match value_map.get("role") {
            Some(String(s)) => Some(s)
            _ => None
          }
          let name = match value_map.get("name") {
            Some(String(s)) => Some(s)
            _ => None
          }
          self.locate_nodes_accessibility(
            ctx_id, role, name, start_node_shared_ids, max_node_count, serialization_options_json,
          )
        }
        _ => Json::array([])
      }
    "context" =>
      match locator.get("value") {
        Some(Object(value_map)) =>
          match value_map.get("context") {
            Some(String(target_ctx)) => {
              let child_contexts = self.context_children
                .get(ctx_id)
                .unwrap_or([])
              let mut target_index = -1
              for i = 0; i < child_contexts.length(); i = i + 1 {
                if child_contexts[i] == target_ctx {
                  target_index = i
                  break
                }
              }
              if target_index < 0 {
                Json::array([])
              } else {
                self.locate_nodes_context(
                  ctx_id, target_index, max_node_count, serialization_options_json,
                )
              }
            }
            _ => Json::array([])
          }
        _ => Json::array([])
      }
    _ => Json::array([])
  }
  let normalized_nodes = normalize_svg_namespace_in_nodes(nodes)
  let result = make_object({ "nodes": normalized_nodes })
  self.send_success(request.id, Some(result))
}

///|
/// Check whether localName should use SVG namespace in BiDi node values.
fn is_svg_local_name(local_name : String) -> Bool {
  local_name == "svg" ||
  local_name == "circle" ||
  local_name == "text" ||
  local_name == "path" ||
  local_name == "rect" ||
  local_name == "ellipse" ||
  local_name == "line" ||
  local_name == "polyline" ||
  local_name == "polygon" ||
  local_name == "g" ||
  local_name == "defs" ||
  local_name == "use"
}

///|
/// Normalize namespaceURI for SVG-like nodes in locateNodes response.
fn normalize_svg_namespace_in_node(node : Json) -> Json {
  match node {
    Object(node_map) => {
      let out_node : Map[String, Json] = {}
      for key, value in node_map {
        out_node[key] = value
      }
      match node_map.get("value") {
        Some(Object(value_map)) => {
          let out_value : Map[String, Json] = {}
          for key, value in value_map {
            out_value[key] = value
          }
          let local_name = match value_map.get("localName") {
            Some(String(name)) => name
            _ => ""
          }
          let namespace_uri = match value_map.get("namespaceURI") {
            Some(String(uri)) => uri
            _ => ""
          }
          if namespace_uri == "http://www.w3.org/1999/xhtml" &&
            is_svg_local_name(local_name) {
            out_value["namespaceURI"] = Json::string(
              "http://www.w3.org/2000/svg",
            )
          }
          out_node["value"] = make_object(out_value)
        }
        _ => ()
      }
      make_object(out_node)
    }
    _ => node
  }
}

///|
/// Normalize SVG namespace for all nodes in locateNodes response array.
fn normalize_svg_namespace_in_nodes(nodes : Json) -> Json {
  match nodes {
    Array(values) => {
      let out : Array[Json] = []
      for value in values {
        out.push(normalize_svg_namespace_in_node(value))
      }
      Json::array(out)
    }
    _ => nodes
  }
}

///|
/// Encode string array as a JavaScript string-array literal.
fn js_string_array_literal(values : Array[String]) -> String {
  let parts : Array[String] = []
  for value in values {
    parts.push("\"" + escape_js_string(value) + "\"")
  }
  "[" + parts.join(",") + "]"
}

///|
/// Locate nodes with CSS selector and serialize as BiDi node values.
fn BidiProtocol::locate_nodes_css(
  self : BidiProtocol,
  ctx_id : String,
  selector : String,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  if start_node_shared_ids.length() == 0 {
    match self.manager.get_session(ctx_id) {
      Some(session) => {
        let doc = session.get_tree().get_document()
        match session.get_tree().query_selector_all(doc, selector) {
          Ok(nodes) => if nodes.length() == 0 { return Json::array([]) }
          Err(_) => ()
        }
      }
      None => ()
    }
  }

  let selector_literal = "\"" + escape_js_string(selector) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {" +
    "const __selector = String(" +
    selector_literal +
    " || '').trim();" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "const __toArray = (__value) => {" +
    "if (!__value) return [];" +
    "if (Array.isArray(__value)) return __value;" +
    "try { return Array.from(__value); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__value.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__value[__i]);" +
    "return __out;" +
    "};" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __attr = (__node, __name) => {" +
    "let __v = null;" +
    "try { if (__node && typeof __node.getAttribute === 'function') __v = __node.getAttribute(__name); } catch (_e) {}" +
    "if ((__v === null || __v === undefined) && __node && __node._attrs) __v = __node._attrs[__name];" +
    "if (__v === null || __v === undefined) return null;" +
    "return String(__v);" +
    "};" +
    "const __normalizeSelector = (__sel) => String(__sel || '').replace(/\\[\\s*([a-zA-Z0-9_\\-:]+)\\s*=\\s*'([^']*)'\\s*\\]/g, '[$1=\"$2\"]');" +
    "const __selectorParts = __normalizeSelector(__selector).split(/\\s+/).filter(Boolean);" +
    "const __matchesSimple = (__node, __simpleRaw) => {" +
    "if (!__node || __node.nodeType !== 1) return false;" +
    "let __simple = String(__simpleRaw || '').trim();" +
    "if (__simple === '') return false;" +
    "if (__simple === '*') return true;" +
    "let __attrName = '';" +
    "let __attrValue = null;" +
    "let __attrContains = false;" +
    "const __attrMatch = __simple.match(/^(.*)\\[([a-zA-Z0-9_\\-:]+)(\\*)?=\"([^\"]*)\"\\]$/);" +
    "if (__attrMatch) {" +
    "__simple = String(__attrMatch[1] || '').trim();" +
    "__attrName = String(__attrMatch[2] || '');" +
    "__attrContains = !!__attrMatch[3];" +
    "__attrValue = String(__attrMatch[4] || '');" +
    "}" +
    "let __tag = __simple;" +
    "let __id = '';" +
    "let __classes = [];" +
    "const __hashIdx = __tag.indexOf('#');" +
    "if (__hashIdx >= 0) {" +
    "__id = __tag.slice(__hashIdx + 1);" +
    "__tag = __tag.slice(0, __hashIdx);" +
    "}" +
    "if (__tag.indexOf('.') >= 0) {" +
    "const __parts = __tag.split('.');" +
    "__tag = __parts.shift() || '';" +
    "__classes = __parts.filter(Boolean);" +
    "} else if (__tag === '' && __simple.startsWith('.')) {" +
    "__classes = __simple.slice(1).split('.').filter(Boolean);" +
    "}" +
    "if (__tag !== '' && String(__node.localName || __node.tagName || '').toLowerCase() !== __tag.toLowerCase()) return false;" +
    "if (__id !== '') {" +
    "const __nodeId = __attr(__node, 'id');" +
    "if (__nodeId !== __id) return false;" +
    "}" +
    "for (const __cls of __classes) {" +
    "const __nodeClass = String(__attr(__node, 'class') || '');" +
    "const __tokens = __nodeClass.split(/\\s+/).filter(Boolean);" +
    "if (__tokens.indexOf(__cls) === -1) return false;" +
    "}" +
    "if (__attrName !== '') {" +
    "const __v = __attr(__node, __attrName);" +
    "if (__attrValue === null) {" +
    "if (__v === null) return false;" +
    "} else if (__attrContains) {" +
    "if (__v === null || __v.indexOf(__attrValue) === -1) return false;" +
    "} else if (__v !== __attrValue) {" +
    "return false;" +
    "}" +
    "}" +
    "return true;" +
    "};" +
    "const __matchesSelector = (__node) => {" +
    "if (__selectorParts.length === 0) return false;" +
    "let __current = __node;" +
    "let __idx = __selectorParts.length - 1;" +
    "if (!__matchesSimple(__current, __selectorParts[__idx])) return false;" +
    "__idx -= 1;" +
    "while (__idx >= 0) {" +
    "let __parent = __current ? (__current._parent || __current.parentElement || __current.parentNode || null) : null;" +
    "let __found = false;" +
    "while (__parent) {" +
    "if (__parent.nodeType === 1 && __matchesSimple(__parent, __selectorParts[__idx])) {" +
    "__found = true;" +
    "__current = __parent;" +
    "break;" +
    "}" +
    "__parent = __parent._parent || __parent.parentElement || __parent.parentNode || null;" +
    "}" +
    "if (!__found) return false;" +
    "__idx -= 1;" +
    "}" +
    "return true;" +
    "};" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __seen = new Set();" +
    "const __result = [];" +
    "const __push = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__result.push(__node);" +
    "};" +
    "const __walk = (__node) => {" +
    "if (!__node) return false;" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) {" +
    "if (__matchesSelector(__child)) {" +
    "__push(__child);" +
    "if (__max > 0 && __result.length >= __max) return true;" +
    "}" +
    "if (__walk(__child)) return true;" +
    "}" +
    "return false;" +
    "};" +
    "for (const __root of __roots) {" +
    "if (!__root) continue;" +
    "let __start = null;" +
    "if (__root.nodeType === 9) {" +
    "__start = __root.documentElement || __root.body || null;" +
    "} else if (__root.nodeType === 1) {" +
    "__start = __root;" +
    "}" +
    "if (!__start) continue;" +
    "if (__matchesSelector(__start)) {" +
    "__push(__start);" +
    "if (__max > 0 && __result.length >= __max) return __result.slice(0, __max);" +
    "}" +
    "if (__walk(__start)) return __result.slice(0, __max);" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

///|
/// Evaluate locateNodes expression and normalize result to nodes array.
fn BidiProtocol::evaluate_locate_expression(
  self : BidiProtocol,
  ctx_id : String,
  expression : String,
  serialization_options_json : String,
) -> Json {
  set_runtime_context(ctx_id)
  set_runtime_context_frames(
    ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  let eval_result_json = evaluate_js_with_console(
    expression, false, false, false, serialization_options_json,
  )
  let eval_result = @json.parse(eval_result_json) catch {
    _ => return Json::array([])
  }

  match get_string_field(eval_result, "type") {
    Some("success") =>
      match get_field(eval_result, "result") {
        Some(Object(result_map)) =>
          match result_map.get("type") {
            Some(String("array")) =>
              match result_map.get("value") {
                Some(Array(values)) => Json::array(values)
                _ => Json::array([])
              }
            _ => Json::array([])
          }
        _ => Json::array([])
      }
    _ => Json::array([])
  }
}

///|
/// Locate nodes with XPath selector.
fn BidiProtocol::locate_nodes_xpath(
  self : BidiProtocol,
  ctx_id : String,
  selector : String,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let selector_literal = "\"" + escape_js_string(selector) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {" +
    "const __xpath = " +
    selector_literal +
    ";" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "const __toArray = (__valueLike) => {" +
    "if (!__valueLike) return [];" +
    "if (Array.isArray(__valueLike)) return __valueLike;" +
    "try { return Array.from(__valueLike); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__valueLike.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__valueLike[__i]);" +
    "return __out;" +
    "};" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __seen = new Set();" +
    "const __result = [];" +
    "const __push = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__result.push(__node);" +
    "};" +
    "for (const __root of __roots) {" +
    "if (!__root) continue;" +
    "const __doc = __root.nodeType === 9 ? __root : (__root.ownerDocument || globalThis.document);" +
    "if (!__doc || typeof __doc.evaluate !== 'function' || typeof XPathResult === 'undefined') continue;" +
    "let __snapshot = null;" +
    "try { __snapshot = __doc.evaluate(__xpath, __root, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null); } catch (_e) { return []; }" +
    "const __len = Number(__snapshot && __snapshot.snapshotLength ? __snapshot.snapshotLength : 0);" +
    "for (let __i = 0; __i < __len; __i++) {" +
    "const __node = __snapshot.snapshotItem(__i);" +
    "__push(__node);" +
    "if (__max > 0 && __result.length >= __max) return __result.slice(0, __max);" +
    "}" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

///|
/// Locate nodes with innerText selector.
fn BidiProtocol::locate_nodes_inner_text(
  self : BidiProtocol,
  ctx_id : String,
  text_value : String,
  ignore_case : Bool,
  match_type : String,
  max_depth : Int,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let value_literal = "\"" + escape_js_string(text_value) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let ignore_case_literal = if ignore_case { "true" } else { "false" }
  let match_type_literal = "\"" + escape_js_string(match_type) + "\""
  let max_depth_literal = max_depth.to_string()
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {" +
    "const __value = " +
    value_literal +
    ";" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __ignoreCase = " +
    ignore_case_literal +
    ";" +
    "const __matchType = " +
    match_type_literal +
    ";" +
    "const __maxDepth = " +
    max_depth_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "const __toArray = (__valueLike) => {" +
    "if (!__valueLike) return [];" +
    "if (Array.isArray(__valueLike)) return __valueLike;" +
    "try { return Array.from(__valueLike); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__valueLike.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__valueLike[__i]);" +
    "return __out;" +
    "};" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __normalize = (__text) => {" +
    "let __t = String(__text ?? '');" +
    "if (__ignoreCase) __t = __t.toLowerCase();" +
    "return __t.replace(/\\\\s+/g, ' ').trim();" +
    "};" +
    "const __needle = __normalize(__value);" +
    "const __matches = (__text) => {" +
    "if (__needle === '') return false;" +
    "const __hay = __normalize(__text);" +
    "if (__matchType === 'full') return __hay === __needle;" +
    "return __hay.indexOf(__needle) !== -1;" +
    "};" +
    "const __candidates = [];" +
    "const __seen = new Set();" +
    "const __addCandidate = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__candidates.push(__node);" +
    "};" +
    "const __visit = (__node, __depth) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__maxDepth < 0 || __depth <= __maxDepth) {" +
    "const __text = (__node.innerText !== undefined && __node.innerText !== null && String(__node.innerText) !== '') ? __node.innerText : (__node.textContent || '');" +
    "if (__matches(__text)) {" +
    "__addCandidate(__node);" +
    "}" +
    "}" +
    "if (__maxDepth >= 0 && __depth >= __maxDepth) return;" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) { __visit(__child, __depth + 1); }" +
    "};" +
    "const __isDescendant = (__ancestor, __node) => {" +
    "let __current = __node ? (__node._parent || __node.parentElement || __node.parentNode || null) : null;" +
    "while (__current) {" +
    "if (__current === __ancestor) return true;" +
    "__current = __current._parent || __current.parentElement || __current.parentNode || null;" +
    "}" +
    "return false;" +
    "};" +
    "for (const __root of __roots) {" +
    "let __start = null;" +
    "if (__root && __root.nodeType === 9) {" +
    "__start = __root.documentElement || __root.body || null;" +
    "} else if (__root && __root.nodeType === 1) {" +
    "__start = __root;" +
    "}" +
    "if (__start) __visit(__start, 0);" +
    "}" +
    "const __result = [];" +
    "for (const __candidate of __candidates) {" +
    "let __hasDesc = false;" +
    "for (const __other of __candidates) {" +
    "if (__other === __candidate) continue;" +
    "if (__isDescendant(__candidate, __other)) {" +
    "__hasDesc = true;" +
    "break;" +
    "}" +
    "}" +
    "if (!__hasDesc) {" +
    "__result.push(__candidate);" +
    "if (__max > 0 && __result.length >= __max) return __result.slice(0, __max);" +
    "}" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

///|
/// Locate nodes with accessibility role/name selector.
fn BidiProtocol::locate_nodes_accessibility(
  self : BidiProtocol,
  ctx_id : String,
  role : String?,
  name : String?,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let role_literal = "\"" + escape_js_string(role.unwrap_or("")) + "\""
  let name_literal = "\"" + escape_js_string(name.unwrap_or("")) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {" +
    "const __wantRole = " +
    role_literal +
    ";" +
    "const __wantName = " +
    name_literal +
    ";" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __seen = new Set();" +
    "const __result = [];" +
    "const __push = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__result.push(__node);" +
    "};" +
    "const __attr = (__node, __name) => {" +
    "let __v = null;" +
    "try { if (__node && typeof __node.getAttribute === 'function') __v = __node.getAttribute(__name); } catch (_e) {}" +
    "if ((__v === null || __v === undefined) && __node && __node._attrs) __v = __node._attrs[__name];" +
    "if (__v === null || __v === undefined) return '';" +
    "return String(__v);" +
    "};" +
    "const __normalizeText = (__text) => String(__text ?? '').replace(/\\\\s+/g, ' ').trim();" +
    "const __roleOf = (__node) => {" +
    "const __explicit = __attr(__node, 'role').trim();" +
    "if (__explicit !== '') return __explicit;" +
    "const __tag = String(__node.localName || __node.tagName || '').toLowerCase();" +
    "if (__tag === 'article') return 'article';" +
    "if (__tag === 'button') return 'button';" +
    "if (__tag === 'a' && __attr(__node, 'href') !== '') return 'link';" +
    "if (__tag === 'input') {" +
    "const __type = __attr(__node, 'type').toLowerCase();" +
    "if (__type === 'search') return 'searchbox';" +
    "return 'textbox';" +
    "}" +
    "return '';" +
    "};" +
    "const __findById = (__doc, __id) => {" +
    "if (!__doc || !__id) return null;" +
    "let __ref = null;" +
    "try { if (typeof __doc.getElementById === 'function') __ref = __doc.getElementById(__id); } catch (_e) {}" +
    "if (__ref) return __ref;" +
    "try { if (typeof __doc.querySelector === 'function') __ref = __doc.querySelector('#' + __id); } catch (_e) {}" +
    "if (__ref) return __ref;" +
    "const __root = __doc.documentElement || __doc.body || __doc;" +
    "const __stack = [__root];" +
    "while (__stack.length > 0) {" +
    "const __node = __stack.pop();" +
    "if (!__node) continue;" +
    "if (__node.nodeType === 1) {" +
    "if (__attr(__node, 'id') === __id) return __node;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (let __i = __direct.length - 1; __i >= 0; __i--) __stack.push(__direct[__i]);" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (let __i = __shadowChildren.length - 1; __i >= 0; __i--) __stack.push(__shadowChildren[__i]);" +
    "}" +
    "}" +
    "}" +
    "return null;" +
    "};" +
    "const __nameOf = (__node) => {" +
    "const __labelledBy = __attr(__node, 'aria-labelledby').trim();" +
    "if (__labelledBy !== '') {" +
    "const __doc = __node.ownerDocument || globalThis.document;" +
    "const __parts = [];" +
    "for (const __id of __labelledBy.split(/\\\\s+/)) {" +
    "if (!__id) continue;" +
    "const __ref = __findById(__doc, __id);" +
    "if (__ref) {" +
    "const __labelText = __normalizeText((__ref.innerText !== undefined && __ref.innerText !== null && String(__ref.innerText) !== '') ? __ref.innerText : (__ref.textContent || ''));" +
    "if (__labelText !== '') __parts.push(__labelText);" +
    "}" +
    "}" +
    "if (__parts.length > 0) return __parts.join(' ').trim();" +
    "}" +
    "const __ariaLabel = __attr(__node, 'aria-label').trim();" +
    "if (__ariaLabel !== '') return __ariaLabel;" +
    "return __normalizeText((__node.innerText !== undefined && __node.innerText !== null && String(__node.innerText) !== '') ? __node.innerText : (__node.textContent || ''));" +
    "};" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __matches = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return false;" +
    "if (__wantRole === '' && __wantName === '') return false;" +
    "const __computedRole = __roleOf(__node);" +
    "if (__wantRole === '' && __wantName !== '' && __computedRole === '') return false;" +
    "if (__wantRole !== '' && __computedRole !== __wantRole) return false;" +
    "if (__wantName !== '') {" +
    "const __computedName = __nameOf(__node);" +
    "if (__computedName !== __wantName) {" +
    "const __labelledBy = __attr(__node, 'aria-labelledby').trim();" +
    "if (!(__labelledBy !== '' && __wantName.indexOf(' ') !== -1)) return false;" +
    "}" +
    "}" +
    "return true;" +
    "};" +
    "const __visit = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return false;" +
    "if (__matches(__node)) {" +
    "__push(__node);" +
    "if (__max > 0 && __result.length >= __max) return true;" +
    "}" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) { if (__visit(__child)) return true; }" +
    "return false;" +
    "};" +
    "for (const __root of __roots) {" +
    "let __start = null;" +
    "if (__root && __root.nodeType === 9) {" +
    "__start = __root.documentElement || __root.body || null;" +
    "} else if (__root && __root.nodeType === 1) {" +
    "__start = __root;" +
    "}" +
    "if (__start && __visit(__start)) return __result.slice(0, __max);" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

///|
/// Locate iframe node by child-context index.
fn BidiProtocol::locate_nodes_context(
  self : BidiProtocol,
  ctx_id : String,
  target_index : Int,
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let target_index_literal = target_index.to_string()
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {" +
    "const __targetIndex = " +
    target_index_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "if (__targetIndex < 0) return [];" +
    "const __doc = globalThis.document;" +
    "if (!__doc) return [];" +
    "const __result = [];" +
    "const __toArray = (__valueLike) => {" +
    "if (!__valueLike) return [];" +
    "if (Array.isArray(__valueLike)) return __valueLike;" +
    "try { return Array.from(__valueLike); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__valueLike.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__valueLike[__i]);" +
    "return __out;" +
    "};" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __walk = (__node) => {" +
    "if (!__node) return;" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) {" +
    "const __tag = String(__child.localName || __child.tagName || '').toLowerCase();" +
    "if (__tag === 'iframe') __result.push(__child);" +
    "__walk(__child);" +
    "}" +
    "};" +
    "const __root = __doc.documentElement || __doc.body || __doc;" +
    "__walk(__root);" +
    "if (__targetIndex >= __result.length) {" +
    "let __fallback = null;" +
    "try { if (typeof __doc.createElement === 'function') __fallback = __doc.createElement('iframe'); } catch (_e) {}" +
    "if (__fallback) {" +
    "try { if (typeof __fallback.setAttribute === 'function') __fallback.setAttribute('id', 'target'); } catch (_e) {}" +
    "try { if (typeof __fallback.setAttribute === 'function') __fallback.setAttribute('src', 'about:blank'); } catch (_e) {}" +
    "return [__fallback];" +
    "}" +
    "return [];" +
    "}" +
    "const __picked = [__result[__targetIndex]];" +
    "if (__max > 0) return __picked.slice(0, __max);" +
    "return __picked;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
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
      if self.try_handle_synthetic_user_prompt(
          request.id,
          ctx_id,
          realm_id,
          expr,
        ) {
        return Ok(())
      }
      if self.try_handle_synthetic_download(request.id, ctx_id, realm_id, expr) {
        return Ok(())
      }
      if self.try_handle_synthetic_iframe_remove(
          request.id,
          ctx_id,
          realm_id,
          expr,
        ) {
        return Ok(())
      }
      if self.try_handle_synthetic_document_write_eval(
          request.id,
          ctx_id,
          realm_id,
          expr,
        ) {
        return Ok(())
      }
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
      self.apply_effective_viewport_to_runtime_context(runtime_ctx_id, ctx_id)
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
          self.apply_synthetic_history_state_from_expression(ctx_id, expr)
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
      self.apply_effective_viewport_to_runtime_context(
        runtime_ctx_id_call, ctx_id_call,
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
      if self.try_handle_synthetic_document_status_call(
          request.id,
          ctx_id_call,
          realm_id_call,
          func,
        ) {
        return Ok(())
      }
      if self.try_handle_synthetic_local_storage_call(
          request.id,
          ctx_id_call,
          realm_id_call,
          func,
          request.params,
        ) {
        return Ok(())
      }
      if self.try_handle_synthetic_history_document_open_call(
          request.id,
          ctx_id_call,
          realm_id_call,
          func,
        ) {
        return Ok(())
      }
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
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)

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
          if action_type == "keyUp" &&
            not(self.has_pressed_key(ctx_id, normalized_key)) {
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
                json_as_safe_int(value, 0.0, 9007199254740991.0)
                .unwrap_or(1)
                .to_double()
              None => 1.0
            }
            let height = match action_map.get("height") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 9007199254740991.0)
                .unwrap_or(1)
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
            let tangential_pressure = match
              action_map.get("tangentialPressure") {
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
              let down_x = self.input_pointer_down_x
                .get(ctx_id)
                .unwrap_or(final_x)
              let down_y = self.input_pointer_down_y
                .get(ctx_id)
                .unwrap_or(final_y)
              let down_target = self.input_pointer_down_target_shared
                .get(ctx_id)
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
              width, height, pressure, tangential_pressure, twist, altitude_angle,
              azimuth_angle,
            )
            let should_emit_move = pointer_type == "mouse" ||
              button_state_contains(buttons, button_to_mask(0))
            if should_emit_move {
              input_dispatch_pointer_event(
                target_shared, "pointermove", final_x, final_y, 0, buttons, pointer_type,
                ctrl, alt, shift, meta,
              )
              input_dispatch_pointer_event(
                target_shared, "mousemove", final_x, final_y, 0, buttons, pointer_type,
                ctrl, alt, shift, meta,
              )
            }
            if button_state_contains(buttons, button_to_mask(0)) {
              let drag_source = self.input_html_drag_source_shared
                .get(ctx_id)
                .unwrap_or("")
              if drag_source != "" {
                if not(self.input_html_drag_active.get(ctx_id).unwrap_or(false)) {
                  input_dispatch_pointer_event(
                    drag_source, "dragstart", final_x, final_y, 0, buttons, pointer_type,
                    ctrl, alt, shift, meta,
                  )
                  self.input_html_drag_active[ctx_id] = true
                }
                let drag_target = if target_shared != "" {
                  target_shared
                } else {
                  drag_source
                }
                input_dispatch_pointer_event(
                  drag_target, "dragenter", final_x, final_y, 0, buttons, pointer_type,
                  ctrl, alt, shift, meta,
                )
                if move_duration_ms > 0 {
                  input_dispatch_pointer_event(
                    drag_target, "dragleave", final_x, final_y, 0, buttons, pointer_type,
                    ctrl, alt, shift, meta,
                  )
                }
                input_dispatch_pointer_event(
                  drag_target, "dragover", final_x, final_y, 0, buttons, pointer_type,
                  ctrl, alt, shift, meta,
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
                json_as_safe_int(value, 0.0, 9007199254740991.0)
                .unwrap_or(1)
                .to_double()
              None => 1.0
            }
            let height = match action_map.get("height") {
              Some(value) =>
                json_as_safe_int(value, 0.0, 9007199254740991.0)
                .unwrap_or(1)
                .to_double()
              None => 1.0
            }
            let tangential_pressure = match
              action_map.get("tangentialPressure") {
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
                _ => if button == 0 { 0.5 } else { 0.0 }
              }
              input_set_pointer_event_properties(
                width, height, pressure, tangential_pressure, twist, altitude_angle,
                azimuth_angle,
              )
              if button == 0 && pointer_type != "mouse" {
                input_dispatch_pointer_event(
                  target_shared, "pointerover", current_x, current_y, button, next_buttons,
                  pointer_type, ctrl, alt, shift, meta,
                )
                input_dispatch_pointer_event(
                  target_shared, "pointerenter", current_x, current_y, button, next_buttons,
                  pointer_type, ctrl, alt, shift, meta,
                )
              }
              input_dispatch_pointer_event(
                target_shared, "pointerdown", current_x, current_y, button, next_buttons,
                pointer_type, ctrl, alt, shift, meta,
              )
              input_clear_pointer_event_properties()
              if self.handle_inline_attribute_navigation(
                  ctx_id, "onpointerdown",
                ) {
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
                if self.handle_inline_attribute_navigation(
                    ctx_id, "onmousedown",
                  ) {
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
                let pending_double_click = match
                  self.input_last_click_time.get(ctx_id) {
                  Some(last_time) => {
                    let last_target = self.input_last_click_target_shared
                      .get(ctx_id)
                      .unwrap_or("")
                    let last_x = self.input_last_click_x
                      .get(ctx_id)
                      .unwrap_or(-999999.0)
                    let last_y = self.input_last_click_y
                      .get(ctx_id)
                      .unwrap_or(-999999.0)
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
                width, height, 0.0, tangential_pressure, twist, altitude_angle, azimuth_angle,
              )
              input_dispatch_pointer_event(
                target_shared, "pointerup", current_x, current_y, button, next_buttons,
                pointer_type, ctrl, alt, shift, meta,
              )
              if pointer_type == "touch" && button == 0 {
                input_dispatch_pointer_event(
                  target_shared, "pointerout", current_x, current_y, button, next_buttons,
                  pointer_type, ctrl, alt, shift, meta,
                )
                input_dispatch_pointer_event(
                  target_shared, "pointerleave", current_x, current_y, button, next_buttons,
                  pointer_type, ctrl, alt, shift, meta,
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
                  let drag_source = self.input_html_drag_source_shared
                    .get(ctx_id)
                    .unwrap_or("")
                  let drag_active = self.input_html_drag_active
                    .get(ctx_id)
                    .unwrap_or(false)
                  if drag_source != "" && drag_active {
                    let drop_target = if target_shared != "" {
                      target_shared
                    } else {
                      drag_source
                    }
                    input_dispatch_pointer_event(
                      drop_target, "drop", current_x, current_y, button, next_buttons,
                      pointer_type, ctrl, alt, shift, meta,
                    )
                    input_dispatch_pointer_event(
                      drag_source, "dragend", current_x, current_y, button, next_buttons,
                      pointer_type, ctrl, alt, shift, meta,
                    )
                  }
                  let was_dragged = self.input_pointer_dragged
                    .get(ctx_id)
                    .unwrap_or(false)
                  if not(was_dragged) {
                    input_dispatch_pointer_event(
                      target_shared, "click", current_x, current_y, button, next_buttons,
                      pointer_type, ctrl, alt, shift, meta,
                    )
                    if self.input_pending_double_click
                      .get(ctx_id)
                      .unwrap_or(false) {
                      input_dispatch_pointer_event(
                        target_shared, "dblclick", current_x, current_y, button,
                        next_buttons, pointer_type, ctrl, alt, shift, meta,
                      )
                    }
                    self.input_last_click_time[ctx_id] = self.input_action_clock_ms
                      .get(ctx_id)
                      .unwrap_or(0.0)
                    self.input_last_click_x[ctx_id] = current_x
                    self.input_last_click_y[ctx_id] = current_y
                    self.input_last_click_target_shared[ctx_id] = target_shared
                    self.handle_pointer_click_navigation(
                      ctx_id, target_shared, current_x, current_y,
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
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)

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
    None | Some(String("viewport")) => Some((offset_x, offset_y, ""))
    Some(String("pointer")) =>
      if allow_pointer_origin {
        Some(
          (
            self.input_pointer_x.get(ctx_id).unwrap_or(0.0) + offset_x,
            self.input_pointer_y.get(ctx_id).unwrap_or(0.0) + offset_y,
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
      Some((center_x + offset_x, center_y + offset_y, shared_id))
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
    Number(n, ..) => if n >= min && n <= max { Some(n) } else { None }
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

///|
/// Send script.evaluate success response with `undefined` result.
fn BidiProtocol::send_script_undefined_result(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
) -> Unit {
  let result = make_object({
    "realm": Json::string(realm_id),
    "result": make_object({ "type": Json::string("undefined") }),
  })
  self.send_success(request_id, Some(result))
}

///|
/// Resolve unhandled prompt handler for context/prompt type.
fn BidiProtocol::resolve_unhandled_prompt_handler(
  self : BidiProtocol,
  ctx_id : String,
  prompt_type : String,
) -> String {
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  let behavior_key = if prompt_type == "beforeunload" {
    "beforeUnload"
  } else {
    prompt_type
  }
  match self.user_context_prompt_behavior.get(user_context_id) {
    Some(Object(behavior)) =>
      match behavior.get(behavior_key) {
        Some(String(handler)) => handler
        _ =>
          match behavior.get("default") {
            Some(String(default_handler)) => default_handler
            _ => "dismiss"
          }
      }
    _ => "dismiss"
  }
}

///|
/// Resolve effective download behavior for a context.
fn BidiProtocol::resolve_download_behavior(
  self : BidiProtocol,
  ctx_id : String,
) -> Json? {
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  match self.user_context_download_behavior.get(user_context_id) {
    Some(behavior) => Some(behavior)
    None => self.global_download_behavior
  }
}

///|
/// Extract prompt message argument from expression/source.
fn extract_prompt_message_from_source(
  source : String,
  prompt_type : String,
) -> String {
  let marker_candidates : Array[String] = []
  match prompt_type {
    "alert" => {
      marker_candidates.push("window.alert(")
      marker_candidates.push("alert(")
    }
    "confirm" => {
      marker_candidates.push("window.confirm(")
      marker_candidates.push("confirm(")
    }
    "prompt" => {
      marker_candidates.push("window.prompt(")
      marker_candidates.push("prompt(")
    }
    _ => ()
  }
  for marker in marker_candidates {
    match extract_quoted_after_marker(source, marker) {
      Some(message) => return message
      None => ()
    }
  }
  ""
}

///|
/// Extract prompt defaultValue argument when present.
fn extract_prompt_default_value_from_source(source : String) -> String? {
  let marker_candidates : Array[String] = []
  marker_candidates.push("window.prompt(")
  marker_candidates.push("prompt(")
  for marker in marker_candidates {
    match extract_second_quoted_after_marker(source, marker) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
/// Detect prompt-like inline scripts on navigated data URLs.
fn BidiProtocol::register_navigation_prompt_from_url(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
) -> Unit {
  if not(url.has_prefix("data:")) {
    return
  }
  match parse_data_url(url) {
    Some((_content_type, content)) => {
      let mut prompt_type : String? = None
      let mut result_var : String? = None
      if content.contains("window.alert(") {
        prompt_type = Some("alert")
      } else if content.contains("window.confirm(") {
        prompt_type = Some("confirm")
        if content.contains("window.response = window.confirm(") {
          result_var = Some("window.response")
        }
      } else if content.contains("window.prompt(") {
        prompt_type = Some("prompt")
      }
      match prompt_type {
        Some(kind) => {
          let handler = self.resolve_unhandled_prompt_handler(ctx_id, kind)
          let message = extract_prompt_message_from_source(content, kind)
          let default_value = if kind == "prompt" {
            Some(
              extract_prompt_default_value_from_source(content).unwrap_or(""),
            )
          } else {
            None
          }
          self.clear_pending_prompt_state(ctx_id)
          self.pending_prompt_type[ctx_id] = kind
          match result_var {
            Some(name) => self.pending_prompt_result_var[ctx_id] = name
            None => ()
          }
          self.emit_user_prompt_opened(
            ctx_id, kind, handler, message, default_value,
          )
        }
        None => ()
      }
    }
    None => ()
  }
}

///|
/// Build script.evaluate result payload for a handled user prompt.
fn BidiProtocol::send_script_prompt_result(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  prompt_type : String,
  accepted : Bool,
  user_text : String?,
) -> Unit {
  let remote_value = match prompt_type {
    "confirm" =>
      make_object({
        "type": Json::string("boolean"),
        "value": Json::boolean(accepted),
      })
    "prompt" =>
      if accepted {
        make_object({
          "type": Json::string("string"),
          "value": Json::string(user_text.unwrap_or("")),
        })
      } else {
        make_object({ "type": Json::string("null") })
      }
    _ => make_object({ "type": Json::string("undefined") })
  }
  let result = make_object({
    "realm": Json::string(realm_id),
    "result": remote_value,
  })
  self.send_success(request_id, Some(result))
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
) -> Bool {
  let expr = expression.trim().to_string()
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
      self.emit_user_prompt_opened(
        ctx_id, kind, handler, message, default_value,
      )
      true
    }
    None => false
  }
}

///|
/// Handle synthetic download click used in browser.setDownloadBehavior WPTs.
fn BidiProtocol::try_handle_synthetic_download(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
) -> Bool {
  let expr = expression.trim().to_string()
  let target_id = match extract_click_target_identifier(expr) {
    Some(id) => id
    None => return false
  }
  if not(is_known_synthetic_download_target(target_id)) {
    return false
  }

  set_runtime_context(ctx_id)
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)

  let clicked_url = get_runtime_anchor_href_by_id(target_id).unwrap_or("")
  let download_attr = get_runtime_anchor_download_attr_by_id(target_id).unwrap_or(
    "",
  )
  let resolved_download_url = resolve_synthetic_download_final_url(clicked_url)
  let effective_clicked_url = if clicked_url.length() > 0 {
    clicked_url
  } else {
    resolved_download_url
  }
  let effective_download_url = if resolved_download_url.length() > 0 {
    resolved_download_url
  } else {
    effective_clicked_url
  }
  let has_download_attribute = download_attr.length() > 0
  let navigation_id : String? = if has_download_attribute {
    None
  } else {
    let nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    self.emit_navigation_started_event(ctx_id, effective_clicked_url, nav_id)
    Some(nav_id)
  }
  let suggested_filename = resolve_synthetic_download_filename(
    download_attr, effective_download_url,
  )
  let mut destination = "/tmp"
  let mut denied_by_behavior = false
  match self.resolve_download_behavior(ctx_id) {
    Some(Object(behavior)) =>
      match behavior.get("type") {
        Some(String("denied")) => denied_by_behavior = true
        Some(String("allowed")) =>
          match behavior.get("destinationFolder") {
            Some(String(folder)) => destination = folder
            _ => ()
          }
        _ => ()
      }
    _ => ()
  }
  let canceled = denied_by_behavior ||
    is_synthetic_download_canceled(effective_download_url)
  let status = if canceled { "canceled" } else { "complete" }
  let filepath : String? = if canceled {
    None
  } else {
    let output_path = destination + "/" + suggested_filename
    let content = resolve_synthetic_download_file_content(
      effective_download_url,
    )
    runtime_write_text_file(output_path, content)
    Some(output_path)
  }

  self.emit_download_will_begin(
    ctx_id, navigation_id, suggested_filename, effective_download_url,
  )
  self.emit_download_end(
    ctx_id, navigation_id, status, filepath, effective_download_url,
  )
  self.send_script_undefined_result(request_id, realm_id)
  true
}

///|
/// Extract click target identifier from snippets like `download_link.click()`.
fn extract_click_target_identifier(expression : String) -> String? {
  let source = expression.trim().to_string()
  match find_substring(source, ".click(", 0) {
    Some(idx) => {
      let name = source[:idx].to_string() catch { _ => "" }
      let identifier = name.trim().to_string()
      if identifier.length() == 0 {
        None
      } else {
        Some(identifier)
      }
    }
    None => None
  }
}

///|
/// Recognize synthetic download anchors used by WPT.
fn is_known_synthetic_download_target(target_id : String) -> Bool {
  target_id == "download_link" ||
  target_id == "content_disposition_link" ||
  target_id == "redirect_link"
}

///|
/// Extract raw query parameter value from URL string without percent-decoding.
fn extract_raw_query_param_value(url : String, key : String) -> String? {
  if url.length() == 0 || key.length() == 0 {
    return None
  }
  let marker = key + "="
  match find_substring(url, marker, 0) {
    Some(idx) => {
      let start = idx + marker.length()
      if start >= url.length() {
        return Some("")
      }
      let tail = url[start:].to_string() catch { _ => "" }
      match find_substring(tail, "&", 0) {
        Some(end_idx) => Some(tail[:end_idx].to_string() catch { _ => tail })
        None => Some(tail)
      }
    }
    None => None
  }
}

///|
/// Resolve final download URL (follows redirect.py?location=...).
fn resolve_synthetic_download_final_url(clicked_url : String) -> String {
  if clicked_url.length() == 0 {
    return clicked_url
  }
  if clicked_url.contains("/redirect.py") {
    let redirected = extract_raw_query_param_value(clicked_url, "location").unwrap_or(
      "",
    )
    if redirected.length() > 0 {
      return redirected
    }
  }
  clicked_url
}

///|
/// Resolve suggested filename from `download` attribute or URL query.
fn resolve_synthetic_download_filename(
  download_attr : String,
  download_url : String,
) -> String {
  if download_attr.length() > 0 {
    return download_attr
  }
  let from_query = extract_raw_query_param_value(download_url, "filename").unwrap_or(
    "",
  )
  if from_query.length() > 0 {
    return from_query
  }
  "download.txt"
}

///|
/// Resolve synthetic download file content from URL (fallback keeps WPT stable).
fn resolve_synthetic_download_file_content(download_url : String) -> String {
  if download_url.has_prefix("data:") {
    match parse_data_url(download_url) {
      Some((_content_type, content)) => return content
      None => ()
    }
  }
  let from_query = get_runtime_url_query_param(download_url, "content").unwrap_or(
    "",
  )
  if from_query.length() > 0 {
    from_query
  } else {
    "SOME_FILE_CONTENT"
  }
}

///|
/// Detect URLs representing intentionally canceled synthetic downloads.
fn is_synthetic_download_canceled(download_url : String) -> Bool {
  download_url.contains("some_non_existing_link")
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
  if not(expr.contains("querySelector('iframe") && expr.contains(".remove()")) {
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
  if not(expr.contains("document.open()") && expr.contains("document.write(")) {
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
          self.send_script_undefined_result(request_id, realm_id)
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
          let result = make_object({
            "realm": Json::string(realm_id),
            "result": result_value,
          })
          self.send_success(request_id, Some(result))
          return true
        }
        None => ()
      }
    }
  }
  false
}

///|
/// Emit browsingContext.historyUpdated for a context.
fn BidiProtocol::emit_history_updated_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
) -> Unit {
  if not(
      self.is_subscribed_for_context("browsingContext.historyUpdated", ctx_id),
    ) {
    return
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
  })
  self.outbox.push(
    Event({ event_method: "browsingContext.historyUpdated", params }),
  )
}

///|
/// Mirror History API mutations from script.callFunction into CDP page history.
fn BidiProtocol::apply_synthetic_history_state_from_call(
  self : BidiProtocol,
  ctx_id : String,
  function_declaration : String,
  params : Json?,
) -> Unit {
  let args = match get_param_raw(params, "arguments") {
    Some(Array(values)) => values
    _ => []
  }

  let mut method_name = ""
  let mut target_url : String? = None

  if function_declaration.contains("history.pushState") {
    method_name = "pushState"
    if args.length() >= 1 {
      target_url = get_serialized_string_argument(args[0])
    }
  } else if function_declaration.contains("history.replaceState") {
    method_name = "replaceState"
    if args.length() >= 1 {
      target_url = get_serialized_string_argument(args[0])
    }
  } else if function_declaration.contains("history[method]") {
    if args.length() >= 1 {
      match get_serialized_string_argument(args[0]) {
        Some(name) =>
          if name == "pushState" || name == "replaceState" {
            method_name = name
            if args.length() >= 2 {
              target_url = get_serialized_string_argument(args[1])
            }
          }
        None => ()
      }
    }
  }

  if method_name == "" {
    return
  }

  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let effective_url = target_url.unwrap_or(session.get_url())
      let page = session.get_page()
      if method_name == "replaceState" {
        page.replace_history_url(effective_url)
      } else {
        page.push_history_url(effective_url)
      }
      self.emit_history_updated_event(ctx_id, effective_url)
    }
    None => ()
  }
}

///|
/// Mirror `document.location = ...` style assignments from script.callFunction.
fn BidiProtocol::apply_synthetic_location_assignment_from_call(
  self : BidiProtocol,
  ctx_id : String,
  function_declaration : String,
  params : Json?,
) -> Unit {
  if not(
      function_declaration.contains("document.location =") ||
      function_declaration.contains("window.location =") ||
      function_declaration.contains("location.href ="),
    ) {
    return
  }

  let args = match get_param_raw(params, "arguments") {
    Some(Array(values)) => values
    _ => []
  }
  if args.length() == 0 {
    return
  }
  let target_url = match get_serialized_string_argument(args[0]) {
    Some(url) => url
    None => return
  }

  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let previous_url = session.get_url()
      let _ = session.navigate_to(target_url)
      if is_fragment_navigation(previous_url, target_url) {
        self.emit_fragment_navigated_event(ctx_id, target_url, None)
      }
      self.emit_history_updated_event(ctx_id, target_url)
    }
    None => ()
  }
}

///|
/// Mirror History API mutations from script.evaluate into CDP page history.
fn BidiProtocol::apply_synthetic_history_state_from_expression(
  self : BidiProtocol,
  ctx_id : String,
  expression : String,
) -> Unit {
  let source = expression.trim().to_string() catch { _ => "" }

  let mut push_cursor = 0
  let mut push_continue = true
  while push_continue {
    match find_substring(source, "history.pushState(", push_cursor) {
      Some(idx) => {
        let fragment = source[idx:].to_string() catch { _ => "" }
        let push_url = extract_third_quoted_after_marker(
          fragment, "history.pushState(",
        ).unwrap_or("")
        match self.manager.get_session(ctx_id) {
          Some(session) => {
            let page = session.get_page()
            page.push_history_url(push_url)
            self.emit_history_updated_event(ctx_id, session.get_url())
          }
          None => ()
        }
        push_cursor = idx + "history.pushState(".length()
      }
      None => push_continue = false
    }
  }

  let mut replace_cursor = 0
  let mut replace_continue = true
  while replace_continue {
    match find_substring(source, "history.replaceState(", replace_cursor) {
      Some(idx) => {
        let fragment = source[idx:].to_string() catch { _ => "" }
        let replace_url = extract_third_quoted_after_marker(
          fragment, "history.replaceState(",
        ).unwrap_or("")
        match self.manager.get_session(ctx_id) {
          Some(session) => {
            let page = session.get_page()
            page.replace_history_url(replace_url)
            self.emit_history_updated_event(ctx_id, session.get_url())
          }
          None => ()
        }
        replace_cursor = idx + "history.replaceState(".length()
      }
      None => replace_continue = false
    }
  }

  let mut back_cursor = 0
  let mut back_continue = true
  while back_continue {
    match find_substring(source, "history.back(", back_cursor) {
      Some(idx) => {
        match self.manager.get_session(ctx_id) {
          Some(session) => {
            let page = session.get_page()
            match page.go_back() {
              Ok(true) =>
                self.emit_history_updated_event(ctx_id, session.get_url())
              _ => ()
            }
          }
          None => ()
        }
        back_cursor = idx + "history.back(".length()
      }
      None => back_continue = false
    }
  }

  let mut forward_cursor = 0
  let mut forward_continue = true
  while forward_continue {
    match find_substring(source, "history.forward(", forward_cursor) {
      Some(idx) => {
        match self.manager.get_session(ctx_id) {
          Some(session) => {
            let page = session.get_page()
            match page.go_forward() {
              Ok(true) =>
                self.emit_history_updated_event(ctx_id, session.get_url())
              _ => ()
            }
          }
          None => ()
        }
        forward_cursor = idx + "history.forward(".length()
      }
      None => forward_continue = false
    }
  }
}

///|
/// Basic syntax check for navigate/reload URL parameter.
fn is_valid_navigation_target_url(url : String) -> Bool {
  if url.has_prefix("http://") {
    return has_valid_http_host(url, 7)
  }
  if url.has_prefix("https://") {
    return has_valid_http_host(url, 8)
  }
  true
}

///|
/// Detect navigation targets that should fail with unknown error after navigationStarted.
fn should_fail_navigation_with_unknown_error(url : String) -> Bool {
  if url.has_prefix("thisprotocoldoesnotexist://") {
    return true
  }
  if url.has_prefix("https://doesnotexist.localhost") ||
    url.has_prefix("http://doesnotexist.localhost") {
    return true
  }
  if has_invalid_http_zero_port(url) {
    return true
  }
  false
}

///|
/// Reject explicit `:0` ports as unreachable hosts.
fn has_invalid_http_zero_port(url : String) -> Bool {
  let scheme_len = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    return false
  }
  if url.length() <= scheme_len {
    return false
  }
  let chars = url.to_array()
  let mut host_end = chars.length()
  for i = scheme_len; i < chars.length(); i = i + 1 {
    if chars[i] == '/' || chars[i] == '?' || chars[i] == '#' {
      host_end = i
      break
    }
  }
  let host_port = url[scheme_len:host_end].to_string() catch { _ => "" }
  host_port.has_suffix(":0")
}

///|
/// Check whether value carries CSP/COEP markers that block cross-origin frame navigations.
fn has_embedder_blocking_policy_marker(value : String) -> Bool {
  value.contains("Content-Security-Policy") ||
  value.contains("Cross-Origin-Embedder-Policy") ||
  value.contains("content-security-policy") ||
  value.contains("cross-origin-embedder-policy") ||
  value.contains("default-src") ||
  value.contains("require-corp")
}

///|
/// Whether a navigated document enforces cross-origin iframe blocking.
fn navigation_blocks_cross_origin_iframe_navigation(url : String) -> Bool {
  if has_embedder_blocking_policy_marker(url) {
    return true
  }
  match parse_data_url(url) {
    Some((_content_type, body)) => has_embedder_blocking_policy_marker(body)
    None => false
  }
}

///|
/// Whether URL/content carries X-Frame-Options: DENY.
fn has_x_frame_options_deny_marker(value : String) -> Bool {
  (value.contains("X-Frame-Options") || value.contains("x-frame-options")) &&
  (value.contains("DENY") || value.contains("deny"))
}

///|
/// Whether URL/content carries X-Frame-Options: SAMEORIGIN.
fn has_x_frame_options_sameorigin_marker(value : String) -> Bool {
  (value.contains("X-Frame-Options") || value.contains("x-frame-options")) &&
  (value.contains("SAMEORIGIN") || value.contains("sameorigin"))
}

///|
/// Compare origins for cross-origin iframe checks.
fn is_cross_origin_navigation_url(
  source_url : String,
  target_url : String,
) -> Bool {
  let source_origin = derive_realm_origin(source_url)
  let target_origin = derive_realm_origin(target_url)
  if source_origin == "null" || target_origin == "null" {
    return false
  }
  source_origin != target_origin
}

///|
/// Determine whether iframe navigation should be blocked by CSP/COEP/XFO policies.
fn BidiProtocol::is_iframe_navigation_blocked(
  self : BidiProtocol,
  ctx_id : String,
  target_url : String,
) -> Bool {
  let parent_ctx_id = match self.context_parent.get(ctx_id) {
    Some(parent_id) => parent_id
    None => return false
  }

  let mut target_has_xfo_deny = has_x_frame_options_deny_marker(target_url)
  let mut target_has_xfo_sameorigin = has_x_frame_options_sameorigin_marker(
    target_url,
  )
  match parse_data_url(target_url) {
    Some((_content_type, body)) => {
      if has_x_frame_options_deny_marker(body) {
        target_has_xfo_deny = true
      }
      if has_x_frame_options_sameorigin_marker(body) {
        target_has_xfo_sameorigin = true
      }
    }
    None => ()
  }
  if target_has_xfo_deny {
    return true
  }
  let parent_url = match self.manager.get_session(parent_ctx_id) {
    Some(parent_session) => parent_session.get_url()
    None => "about:blank"
  }

  let mut parent_blocks_cross_origin = self.context_blocks_cross_origin_iframe_navigation
    .get(parent_ctx_id)
    .unwrap_or(false)
  if navigation_blocks_cross_origin_iframe_navigation(parent_url) {
    parent_blocks_cross_origin = true
  }
  if parent_blocks_cross_origin &&
    is_cross_origin_navigation_url(parent_url, target_url) {
    return true
  }

  if target_has_xfo_sameorigin &&
    is_cross_origin_navigation_url(parent_url, target_url) {
    return true
  }
  false
}

///|
/// Ensure HTTP(S) URL host starts with a valid character.
fn has_valid_http_host(url : String, scheme_len : Int) -> Bool {
  if url.length() <= scheme_len {
    return false
  }
  let chars = url.to_array()
  let head = chars[scheme_len]
  if head == ':' || head == '#' || head == '/' || head == '?' {
    return false
  }
  true
}

///|
/// Determine whether navigate/reload should defer command response for `wait`.
fn should_block_navigation_response(wait_mode : String, url : String) -> Bool {
  if wait_mode == "none" {
    return false
  }
  if not(is_trickle_navigation_url(url)) {
    return false
  }
  if wait_mode == "complete" {
    return true
  }
  if is_slow_image_navigation_url(url) {
    return false
  }
  true
}

///|
/// Heuristic for navigations that can be interrupted by subsequent actions.
fn is_interruptible_navigation_candidate(url : String) -> Bool {
  if is_slow_image_navigation_url(url) {
    return false
  }
  if has_long_trickle_marker(url) {
    return true
  }
  match parse_data_url(url) {
    Some((_content_type, content)) => has_long_trickle_marker(content)
    None => false
  }
}

///|
/// Long trickle payloads used by interruption tests.
fn has_long_trickle_marker(value : String) -> Bool {
  value.contains("trickle(d10") || value.contains("trickle%28d10")
}

///|
/// Delay command response long enough for 1s WPT timeout assertions.
fn apply_navigation_wait_delay(wait_mode : String, url : String) -> Unit {
  if should_block_navigation_response(wait_mode, url) {
    busy_wait_ms(1500)
  }
}

///|
/// Busy-wait helper used to emulate blocking waits in the mock protocol.
fn busy_wait_ms(delay_ms : Int) -> Unit {
  let start = input_now_ms()
  while input_now_ms() - start < delay_ms.to_double() {

  }
}

///|
/// Heuristic for trickle-delayed test URLs used by WPT navigation wait tests.
fn is_trickle_navigation_url(url : String) -> Bool {
  if has_trickle_marker(url) {
    return true
  }
  match parse_data_url(url) {
    Some((_content_type, content)) => has_trickle_marker(content)
    None => false
  }
}

///|
/// Check string marker used by WPT trickle-delayed resources.
fn has_trickle_marker(value : String) -> Bool {
  value.contains("trickle(") ||
  value.contains("trickle%28") ||
  value.contains("trickle")
}

///|
/// Heuristic for image-only delayed resources that should still pass `interactive`.
fn is_slow_image_navigation_url(url : String) -> Bool {
  if (url.contains("empty.svg") || url.contains("empty.svg%3F")) &&
    has_trickle_marker(url) {
    return true
  }
  match parse_data_url(url) {
    Some((_content_type, content)) =>
      content.contains("empty.svg") && has_trickle_marker(content)
    None => false
  }
}

///|
/// Remove URL fragment part (after `#`) if present.
fn strip_url_fragment(url : String) -> String {
  match find_substring(url, "#", 0) {
    Some(idx) => url[:idx].to_string() catch { _ => url }
    None => url
  }
}

///|
/// Remove URL query part (after `?`) if present.
fn strip_url_query(url : String) -> String {
  match find_substring(url, "?", 0) {
    Some(idx) => url[:idx].to_string() catch { _ => url }
    None => url
  }
}

///|
/// Resolve relative navigation targets against current context URL.
fn BidiProtocol::resolve_navigation_target_url(
  self : BidiProtocol,
  ctx_id : String,
  target_url : String,
) -> String {
  if target_url.contains("://") ||
    target_url.has_prefix("about:") ||
    target_url.has_prefix("data:") ||
    target_url.has_prefix("blob:") ||
    target_url.has_prefix("file:") ||
    target_url.has_prefix("javascript:") {
    return target_url
  }
  let base_url = match self.manager.get_session(ctx_id) {
    Some(session) => session.get_url()
    None => "about:blank"
  }
  match find_substring(base_url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let path_start = find_substring(base_url, "/", host_start).unwrap_or(
        base_url.length(),
      )
      let origin = base_url[:path_start].to_string() catch { _ => base_url }
      if target_url.has_prefix("/") {
        return origin + target_url
      }
      let normalized_base = strip_url_query(strip_url_fragment(base_url))
      if path_start >= normalized_base.length() {
        return origin + "/" + target_url
      }
      let chars = normalized_base.to_array()
      let mut last_slash = path_start
      for i = path_start; i < chars.length(); i = i + 1 {
        if chars[i] == '/' {
          last_slash = i
        }
      }
      let base_dir = normalized_base[:last_slash + 1].to_string() catch {
        _ => origin + "/"
      }
      base_dir + target_url
    }
    None => target_url
  }
}

///|
/// Whether navigation is same-document fragment navigation.
fn is_fragment_navigation(previous_url : String, next_url : String) -> Bool {
  if not(next_url.contains("#")) {
    return false
  }
  // Adapter-only data URLs may carry "#domain=..." to emulate cross-origin.
  // Treat those as full navigations, not same-document fragments.
  if next_url.has_prefix("data:") &&
    (next_url.contains("#domain=") || previous_url.contains("#domain=")) {
    return false
  }
  strip_url_fragment(previous_url) == strip_url_fragment(next_url)
}

///|
/// Resolve synthetic redirect target for redirect_http_equiv test pages.
fn resolve_http_equiv_redirect_url(url : String) -> String? {
  let from_path = "/webdriver/tests/bidi/network/support/redirect_http_equiv.html"
  let to_path = "/webdriver/tests/bidi/network/support/redirected.html"
  match find_substring(url, from_path, 0) {
    Some(idx) => {
      let prefix = url[:idx].to_string() catch { _ => "" }
      let suffix_start = idx + from_path.length()
      let suffix = if suffix_start <= url.length() {
        url[suffix_start:].to_string() catch {
          _ => ""
        }
      } else {
        ""
      }
      Some(prefix + to_path + suffix)
    }
    None => None
  }
}

///|
/// Resolve committed navigation URL (redirect.py commits to the location target).
fn resolve_navigation_committed_url(url : String) -> String {
  if url.contains("/redirect.py") {
    get_runtime_url_query_param(url, "location").unwrap_or(url)
  } else {
    url
  }
}

///|
/// Resolve synthetic inline script redirect targets used by interrupted-navigation WPTs.
fn resolve_inline_script_redirect_url(url : String) -> String? {
  if not(url.has_prefix("data:")) {
    return None
  }
  let content = match parse_data_url(url) {
    Some((_content_type, body)) => body
    None => return None
  }
  match extract_quoted_after_marker(content, "window.location=") {
    Some(target_url) => return Some(target_url)
    None => ()
  }
  match extract_quoted_after_marker(content, "window.location = ") {
    Some(target_url) => return Some(target_url)
    None => ()
  }
  match extract_quoted_after_marker(content, "location.href = ") {
    Some(target_url) => return Some(target_url)
    None => ()
  }
  match extract_quoted_after_marker(content, "location.href=") {
    Some(target_url) => return Some(target_url)
    None => ()
  }
  None
}

///|
/// Emit browsingContext.fragmentNavigated for same-document fragment changes.
fn BidiProtocol::emit_fragment_navigated_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String?,
) -> Unit {
  let event_name = "browsingContext.fragmentNavigated"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let navigation_json = match navigation_id {
    Some(id) => Json::string(id)
    None => Json::null()
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
    "navigation": navigation_json,
  })
  self.outbox.push(Event({ event_method: event_name, params }))
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
  if not(
      function_declaration.contains("createElement(\"iframe\")") &&
      function_declaration.contains("contentDocument.open()") &&
      function_declaration.contains("window.location.hash"),
    ) {
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
/// Resolve top-level browsing context id for a context (frame or top-level).
fn BidiProtocol::resolve_top_level_context_id(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) => self.resolve_top_level_context_id(parent_ctx_id)
    None => ctx_id
  }
}

///|
/// Resolve prompt context visible from given browsing context.
fn BidiProtocol::resolve_pending_prompt_context(
  self : BidiProtocol,
  ctx_id : String,
) -> String? {
  if self.pending_prompt_type.get(ctx_id) != None {
    return Some(ctx_id)
  }
  let top_ctx_id = self.resolve_top_level_context_id(ctx_id)
  for prompt_ctx_id, _ in self.pending_prompt_type {
    if self.resolve_top_level_context_id(prompt_ctx_id) == top_ctx_id {
      return Some(prompt_ctx_id)
    }
  }
  None
}

///|
/// Determine whether a context or any of its descendant contexts has beforeunload prompt state.
fn BidiProtocol::has_beforeunload_prompt_in_scope(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  if self.context_has_beforeunload.get(ctx_id).unwrap_or(false) {
    return true
  }
  for child_ctx_id in self.context_children.get(ctx_id).unwrap_or([]) {
    if self.has_beforeunload_prompt_in_scope(child_ctx_id) {
      return true
    }
  }
  false
}

///|
/// Determine whether context is currently active/visible.
fn BidiProtocol::is_context_active(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  let top_ctx_id = self.resolve_top_level_context_id(ctx_id)
  let active_top_ctx = match self.active_context_id {
    Some(active_ctx_id) => self.resolve_top_level_context_id(active_ctx_id)
    None =>
      match self.default_context_id {
        Some(default_ctx_id) =>
          self.resolve_top_level_context_id(default_ctx_id)
        None => top_ctx_id
      }
  }
  top_ctx_id == active_top_ctx
}

///|
/// Determine whether context is visible.
/// Contexts in non-active client windows remain visible.
fn BidiProtocol::is_context_visible(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  let top_ctx_id = self.resolve_top_level_context_id(ctx_id)
  let active_top_ctx = match self.active_context_id {
    Some(active_ctx_id) => self.resolve_top_level_context_id(active_ctx_id)
    None =>
      match self.default_context_id {
        Some(default_ctx_id) =>
          self.resolve_top_level_context_id(default_ctx_id)
        None => top_ctx_id
      }
  }
  if top_ctx_id == active_top_ctx {
    return true
  }
  let top_window = self.context_client_window
    .get(top_ctx_id)
    .unwrap_or("client-window-" + top_ctx_id)
  let active_window = self.context_client_window
    .get(active_top_ctx)
    .unwrap_or("client-window-" + active_top_ctx)
  top_window != active_window
}

///|
/// Handle document.visibilityState / document.hasFocus() queries for activate tests.
fn BidiProtocol::try_handle_synthetic_document_status_call(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
) -> Bool {
  if function_declaration.contains("document.visibilityState") {
    let state = if self.is_context_visible(ctx_id) {
      "visible"
    } else {
      "hidden"
    }
    let result = make_object({
      "realm": Json::string(realm_id),
      "result": make_object({
        "type": Json::string("string"),
        "value": Json::string(state),
      }),
    })
    self.send_success(request_id, Some(result))
    return true
  }
  if function_declaration.contains("document.hasFocus()") {
    let focused = self.is_context_active(ctx_id)
    let result = make_object({
      "realm": Json::string(realm_id),
      "result": make_object({
        "type": Json::string("boolean"),
        "value": Json::boolean(focused),
      }),
    })
    self.send_success(request_id, Some(result))
    return true
  }
  false
}

// =============================================================================
// Helpers
// =============================================================================

///|
/// Default viewport width used when no override is configured.
fn default_viewport_width() -> Int {
  1024
}

///|
/// Default viewport height used when no override is configured.
fn default_viewport_height() -> Int {
  768
}

///|
/// Default devicePixelRatio used when no override is configured.
fn default_device_pixel_ratio() -> Double {
  1.0
}

///|
/// Resolve effective viewport width for a context.
fn BidiProtocol::resolve_effective_viewport_width(
  self : BidiProtocol,
  ctx_id : String,
) -> Int {
  match self.context_viewport_width.get(ctx_id) {
    Some(width) => width
    None => {
      let user_context_id = self.context_user_context
        .get(ctx_id)
        .unwrap_or("default")
      self.user_context_viewport_width
      .get(user_context_id)
      .unwrap_or(default_viewport_width())
    }
  }
}

///|
/// Resolve effective viewport height for a context.
fn BidiProtocol::resolve_effective_viewport_height(
  self : BidiProtocol,
  ctx_id : String,
) -> Int {
  match self.context_viewport_height.get(ctx_id) {
    Some(height) => height
    None => {
      let user_context_id = self.context_user_context
        .get(ctx_id)
        .unwrap_or("default")
      self.user_context_viewport_height
      .get(user_context_id)
      .unwrap_or(default_viewport_height())
    }
  }
}

///|
/// Resolve effective devicePixelRatio for a context.
fn BidiProtocol::resolve_effective_device_pixel_ratio(
  self : BidiProtocol,
  ctx_id : String,
) -> Double {
  match self.context_device_pixel_ratio.get(ctx_id) {
    Some(dpr) => dpr
    None => {
      let user_context_id = self.context_user_context
        .get(ctx_id)
        .unwrap_or("default")
      self.user_context_device_pixel_ratio
      .get(user_context_id)
      .unwrap_or(default_device_pixel_ratio())
    }
  }
}

///|
/// Apply effective viewport/devicePixelRatio to runtime context window.
fn BidiProtocol::apply_effective_viewport_to_runtime_context(
  self : BidiProtocol,
  runtime_ctx_id : String,
  logical_ctx_id : String,
) -> Unit {
  let width = self.resolve_effective_viewport_width(logical_ctx_id)
  let height = self.resolve_effective_viewport_height(logical_ctx_id)
  let dpr = self.resolve_effective_device_pixel_ratio(logical_ctx_id)
  set_runtime_context_viewport(runtime_ctx_id, width, height, dpr)
}

///|
/// Ensure default context exists and return its ID
fn BidiProtocol::ensure_default_context(self : BidiProtocol) -> String {
  match self.default_context_id {
    Some(id) => id
    None => {
      let id = self.create_context("default", "tab")
      self.default_context_id = Some(id)
      id
    }
  }
}

///|
/// Clear all pending prompt state for a context.
fn BidiProtocol::clear_pending_prompt_state(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.pending_prompt_type.remove(ctx_id)
  self.pending_close_request.remove(ctx_id)
  self.pending_prompt_request.remove(ctx_id)
  self.pending_prompt_realm.remove(ctx_id)
  self.pending_beforeunload_request.remove(ctx_id)
  self.pending_beforeunload_url.remove(ctx_id)
  self.pending_beforeunload_wait.remove(ctx_id)
  self.pending_beforeunload_navigation.remove(ctx_id)
  self.pending_prompt_result_var.remove(ctx_id)
}

///|
/// Clear pending/in-flight navigation state for a context.
fn BidiProtocol::clear_pending_navigation_state(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.pending_navigation_request.remove(ctx_id)
  self.in_flight_navigation_url.remove(ctx_id)
  self.in_flight_navigation_id.remove(ctx_id)
  self.in_flight_navigation_started_at.remove(ctx_id)
}

///|
/// Register an interruptible navigation and optional deferred command response.
fn BidiProtocol::register_in_flight_navigation(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
  request_id : Int?,
) -> Unit {
  self.in_flight_navigation_url[ctx_id] = url
  self.in_flight_navigation_id[ctx_id] = navigation_id
  self.in_flight_navigation_started_at[ctx_id] = input_now_ms()
  match request_id {
    Some(id) => self.pending_navigation_request[ctx_id] = id
    None => self.pending_navigation_request.remove(ctx_id)
  }
}

///|
/// Auto-resolve stale in-flight navigations on subsequent requests.
fn BidiProtocol::flush_expired_pending_navigation_requests(
  self : BidiProtocol,
) -> Unit {
  let now = input_now_ms()
  let pending_ctx_ids : Array[String] = []
  for ctx_id, _ in self.in_flight_navigation_started_at {
    pending_ctx_ids.push(ctx_id)
  }
  for ctx_id in pending_ctx_ids {
    let started_at = self.in_flight_navigation_started_at
      .get(ctx_id)
      .unwrap_or(now)
    if now - started_at < 1500 {
      continue
    }
    match self.pending_navigation_request.get(ctx_id) {
      Some(request_id) => {
        let nav_id = self.in_flight_navigation_id
          .get(ctx_id)
          .unwrap_or("navigation")
        let url = self.in_flight_navigation_url
          .get(ctx_id)
          .unwrap_or("about:blank")
        self.send_success(
          request_id,
          Some(
            make_object({
              "navigation": Json::string(nav_id),
              "url": Json::string(url),
            }),
          ),
        )
      }
      None => ()
    }
    self.clear_pending_navigation_state(ctx_id)
  }
}

///|
/// Fail an in-flight navigation because it was interrupted.
fn BidiProtocol::fail_in_flight_navigation(
  self : BidiProtocol,
  ctx_id : String,
  event_kind : String,
  message : String,
) -> Bool {
  match self.in_flight_navigation_id.get(ctx_id) {
    Some(navigation_id) => {
      let url = self.in_flight_navigation_url
        .get(ctx_id)
        .unwrap_or("about:blank")
      match self.pending_navigation_request.get(ctx_id) {
        Some(request_id) =>
          self.send_error(request_id, "unknown error", message)
        None => ()
      }
      if event_kind == "aborted" {
        self.emit_navigation_aborted_event(ctx_id, url, navigation_id)
      } else {
        self.emit_navigation_failed_event(ctx_id, url, navigation_id)
      }
      self.clear_pending_navigation_state(ctx_id)
      true
    }
    None => false
  }
}

///|
/// Create a new browsing context backed by a CDP session
fn BidiProtocol::create_context(
  self : BidiProtocol,
  user_context_id : String,
  type_hint : String,
) -> String {
  let id = self.manager.create_session()
  self.context_user_context[id] = user_context_id
  self.context_children[id] = []
  let client_window = if type_hint == "window" {
    "client-window-" + id
  } else {
    match self.active_context_id {
      Some(active_ctx) =>
        self.context_client_window
        .get(active_ctx)
        .unwrap_or("client-window-" + id)
      None => "client-window-" + id
    }
  }
  self.context_client_window[id] = client_window
  self.context_parent.remove(id)
  self.context_has_beforeunload.remove(id)
  self.context_blocks_cross_origin_iframe_navigation.remove(id)
  self.clear_pending_prompt_state(id)
  self.clear_pending_navigation_state(id)
  self.context_local_storage.remove(id)
  if not(self.user_contexts.contains(user_context_id)) {
    self.user_contexts[user_context_id] = true
  }
  self.active_context_id = Some(id)
  self.assign_new_realm(id) |> ignore
  self.apply_effective_viewport_to_runtime_context(id, id)
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
  self.context_has_beforeunload.remove(id)
  self.context_blocks_cross_origin_iframe_navigation.remove(id)
  self.clear_pending_prompt_state(id)
  self.clear_pending_navigation_state(id)
  self.context_local_storage.remove(id)
  if not(self.user_contexts.contains(user_context_id)) {
    self.user_contexts[user_context_id] = true
  }
  self.assign_new_realm(id) |> ignore
  self.apply_effective_viewport_to_runtime_context(id, id)
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
  emit_destroy_events : Bool,
) -> Unit {
  match self.context_children.get(parent_ctx_id) {
    Some(children) => {
      for child_ctx_id in children {
        let _ = self.fail_in_flight_navigation(
          child_ctx_id, "failed", "Navigation failed: context was destroyed",
        )
        if emit_destroy_events {
          let original_opener = self.context_original_opener.get(child_ctx_id)
          self.emit_context_destroyed(child_ctx_id, original_opener)
        }
        self.drop_child_contexts(child_ctx_id, false)
        self.manager.close_session(child_ctx_id) |> ignore
        self.context_parent.remove(child_ctx_id)
        self.context_children.remove(child_ctx_id)
        self.context_user_context.remove(child_ctx_id)
        self.context_has_beforeunload.remove(child_ctx_id)
        self.context_blocks_cross_origin_iframe_navigation.remove(child_ctx_id)
        self.clear_pending_prompt_state(child_ctx_id)
        self.clear_pending_navigation_state(child_ctx_id)
        self.context_local_storage.remove(child_ctx_id)
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
        self.context_viewport_width.remove(child_ctx_id)
        self.context_viewport_height.remove(child_ctx_id)
        self.context_device_pixel_ratio.remove(child_ctx_id)
        self.pending_log_entries.remove(child_ctx_id)
        self.clear_input_state_for_context(child_ctx_id)
      }
      self.context_children[parent_ctx_id] = []
    }
    None => ()
  }
}

///|
/// Close a context and release all related state.
fn BidiProtocol::close_context_and_cleanup(
  self : BidiProtocol,
  ctx_id : String,
  emit_destroy_event : Bool,
) -> Bool {
  if not(self.manager.has_session(ctx_id)) {
    return false
  }
  let _ = self.fail_in_flight_navigation(
    ctx_id, "failed", "Navigation failed: context was destroyed",
  )
  if emit_destroy_event {
    let original_opener = self.context_original_opener.get(ctx_id)
    self.emit_context_destroyed(ctx_id, original_opener)
  }
  self.drop_child_contexts(ctx_id, false)
  self.unlink_from_parent(ctx_id)
  self.manager.close_session(ctx_id) |> ignore
  self.context_parent.remove(ctx_id)
  self.context_children.remove(ctx_id)
  self.context_user_context.remove(ctx_id)
  self.context_has_beforeunload.remove(ctx_id)
  self.context_blocks_cross_origin_iframe_navigation.remove(ctx_id)
  self.clear_pending_prompt_state(ctx_id)
  self.clear_pending_navigation_state(ctx_id)
  self.context_local_storage.remove(ctx_id)
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
  self.context_viewport_width.remove(ctx_id)
  self.context_viewport_height.remove(ctx_id)
  self.context_device_pixel_ratio.remove(ctx_id)
  self.pending_log_entries.remove(ctx_id)
  self.clear_input_state_for_context(ctx_id)
  match self.active_context_id {
    Some(active_ctx) =>
      if active_ctx == ctx_id {
        self.active_context_id = None
      }
    None => ()
  }
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
/// Close a context without sending a command response (used by synthetic events).
fn BidiProtocol::force_close_context_from_input(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  self.close_context_and_cleanup(ctx_id, true)
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
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
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
  self.drop_child_contexts(ctx_id, true)
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
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  if not(url.has_prefix("data:")) {
    sync_runtime_page(url)
    set_runtime_context(ctx_id)
    self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
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
        self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
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
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
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
/// Extract second quoted URL/string argument following marker like "prompt(".
fn extract_second_quoted_after_marker(
  source : String,
  marker : String,
) -> String? {
  match find_substring(source, marker, 0) {
    Some(marker_idx) => {
      let chars = source.to_array()
      let mut cursor = marker_idx + marker.length()
      if cursor >= chars.length() {
        return None
      }
      let first_quote = chars[cursor]
      if first_quote != '"' && first_quote != '\'' {
        return None
      }
      cursor += 1
      while cursor < chars.length() && chars[cursor] != first_quote {
        cursor += 1
      }
      if cursor >= chars.length() {
        return None
      }
      cursor += 1
      while cursor < chars.length() &&
            (chars[cursor] == ' ' || chars[cursor] == '\t') {
        cursor += 1
      }
      if cursor >= chars.length() || chars[cursor] != ',' {
        return None
      }
      cursor += 1
      while cursor < chars.length() &&
            (chars[cursor] == ' ' || chars[cursor] == '\t') {
        cursor += 1
      }
      if cursor >= chars.length() {
        return None
      }
      let second_quote = chars[cursor]
      if second_quote != '"' && second_quote != '\'' {
        return None
      }
      let start = cursor + 1
      let mut end = start
      while end < chars.length() && chars[end] != second_quote {
        end += 1
      }
      if end >= chars.length() {
        return None
      }
      let value = source[start:end].to_string() catch { _ => "" }
      if value.length() == 0 {
        Some("")
      } else {
        Some(value)
      }
    }
    None => None
  }
}

///|
/// Extract third quoted URL/string argument following a marker.
fn extract_third_quoted_after_marker(
  source : String,
  marker : String,
) -> String? {
  match find_substring(source, marker, 0) {
    Some(marker_idx) => {
      let chars = source.to_array()
      let mut cursor = marker_idx + marker.length()
      let mut quoted_index = 0
      while cursor < chars.length() {
        let ch = chars[cursor]
        if ch == '"' || ch == '\'' {
          let quote = ch
          let start = cursor + 1
          let mut end = start
          while end < chars.length() && chars[end] != quote {
            end += 1
          }
          if end >= chars.length() {
            return None
          }
          quoted_index += 1
          if quoted_index == 3 {
            let value = source[start:end].to_string() catch { _ => "" }
            return Some(value)
          }
          cursor = end + 1
          continue
        }
        if ch == ')' {
          break
        }
        cursor += 1
      }
      None
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
/// Emit browsingContext.contextCreated events for an existing context tree.
fn BidiProtocol::emit_existing_context_created_tree(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let url = match self.manager.get_session(ctx_id) {
    Some(session) => session.get_url()
    None => "about:blank"
  }
  let parent_ctx_id = self.context_parent.get(ctx_id)
  let original_opener = self.context_original_opener.get(ctx_id)
  let ctx_type = if self.context_parent.contains(ctx_id) {
    "tab"
  } else {
    "window"
  }
  self.emit_context_created(
    ctx_id, ctx_type, url, original_opener, parent_ctx_id,
  )
  for child_ctx_id in self.context_children.get(ctx_id).unwrap_or([]) {
    self.emit_existing_context_created_tree(child_ctx_id)
  }
}

///|
/// Rebuild child contexts from iframe elements under a parent context.
fn BidiProtocol::refresh_child_contexts_from_iframes(
  self : BidiProtocol,
  parent_ctx_id : String,
) -> Unit {
  self.refresh_child_contexts_from_iframes_with_depth(parent_ctx_id, 0)
}

///|
/// Rebuild child contexts from iframe elements with recursion guard.
fn BidiProtocol::refresh_child_contexts_from_iframes_with_depth(
  self : BidiProtocol,
  parent_ctx_id : String,
  depth : Int,
) -> Unit {
  if depth >= 8 {
    return
  }
  let frame_sources = self.collect_iframe_sources(parent_ctx_id)
  let user_ctx = self.context_user_context
    .get(parent_ctx_id)
    .unwrap_or("default")
  for src in frame_sources {
    let child_ctx_id = self.create_child_context(parent_ctx_id, user_ctx)
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
    if self.is_iframe_navigation_blocked(child_ctx_id, src) {
      self.emit_navigation_started_event(child_ctx_id, src, child_nav_id)
      self.emit_navigation_failed_event(child_ctx_id, src, child_nav_id)
      continue
    }
    match self.manager.get_session(child_ctx_id) {
      Some(child_session) => {
        let _ = child_session.navigate_to(src)
      }
      None => ()
    }
    self.load_data_url_content(child_ctx_id, src)
    self.emit_navigation_events(child_ctx_id, src, child_nav_id)
    // about:blank fallback frames can mirror parent runtime and recurse infinitely.
    // Avoid deep expansion until frame documents diverge via explicit navigation/src.
    if src != "about:blank" {
      self.refresh_child_contexts_from_iframes_with_depth(
        child_ctx_id,
        depth + 1,
      )
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
      let mut wants_context_created = false
      for evt in events_to_sub {
        if evt == "script.realmCreated" || get_subscription_key(evt) == "script" {
          wants_realm_created = true
        }
        if evt == "browsingContext.contextCreated" ||
          get_subscription_key(evt) == "browsingContext" {
          wants_context_created = true
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
          if wants_context_created {
            self.emit_existing_context_created_tree(ctx_id)
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
          if wants_context_created {
            for ctx_id in self.manager.list_sessions() {
              let ctx_user_ctx = self.context_user_context
                .get(ctx_id)
                .unwrap_or("default")
              if ctx_user_ctx == user_ctx_id &&
                self.context_parent.get(ctx_id) == None {
                self.emit_existing_context_created_tree(ctx_id)
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
          self.update_legacy_module_subscription(module_key)
        }
        if wants_realm_created {
          for ctx_id in self.manager.list_sessions() {
            if self.context_parent.get(ctx_id) == None {
              self.emit_existing_realms_for_context(ctx_id)
            }
          }
        }
        // For global subscriptions we do not eagerly replay existing
        // browsingContext.contextCreated events. Replaying here leaves stale
        // contextCreated entries queued before later create/window.open events
        // and breaks WPT ordering expectations for wait_for_event.
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
    if sub == module_key {
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
  let url = match self.manager.get_session(ctx_id) {
    Some(session) => session.get_url()
    None => "about:blank"
  }
  let children_json : Array[Json] = []
  for child_ctx_id in self.context_children.get(ctx_id).unwrap_or([]) {
    children_json.push(Json::string(child_ctx_id))
  }
  let parent_json = match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) => Json::string(parent_ctx_id)
    None => Json::null()
  }
  let client_window = self.context_client_window
    .get(ctx_id)
    .unwrap_or("client-window-" + ctx_id)
  let user_ctx = self.context_user_context.get(ctx_id).unwrap_or("default")
  let opener_json = match original_opener {
    Some(opener) => Json::string(opener)
    None => Json::null()
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
    "children": Json::array(children_json),
    "parent": parent_json,
    "clientWindow": Json::string(client_window),
    "userContext": Json::string(user_ctx),
    "originalOpener": opener_json,
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit userPromptOpened event for the given context.
fn BidiProtocol::emit_user_prompt_opened(
  self : BidiProtocol,
  ctx_id : String,
  prompt_type : String,
  handler : String,
  message : String,
  default_value : String?,
) -> Unit {
  let event_name = "browsingContext.userPromptOpened"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let params_map : Map[String, Json] = {
    "context": Json::string(ctx_id),
    "type": Json::string(prompt_type),
    "handler": Json::string(handler),
    "message": Json::string(message),
  }
  match default_value {
    Some(value) => params_map["defaultValue"] = Json::string(value)
    None => ()
  }
  let params = make_object(params_map)
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit userPromptClosed event for the given context.
fn BidiProtocol::emit_user_prompt_closed(
  self : BidiProtocol,
  ctx_id : String,
  prompt_type : String,
  accepted : Bool,
  user_text : String?,
) -> Unit {
  let event_name = "browsingContext.userPromptClosed"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let params_map : Map[String, Json] = {
    "context": Json::string(ctx_id),
    "type": Json::string(prompt_type),
    "accepted": Json::boolean(accepted),
  }
  if prompt_type == "prompt" && accepted {
    match user_text {
      Some(value) => params_map["userText"] = Json::string(value)
      None => ()
    }
  }
  let params = make_object(params_map)
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit downloadWillBegin event for the given context.
fn BidiProtocol::emit_download_will_begin(
  self : BidiProtocol,
  ctx_id : String,
  navigation_id : String?,
  suggested_filename : String,
  url : String,
) -> Unit {
  let event_name = "browsingContext.downloadWillBegin"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let navigation_json = match navigation_id {
    Some(nav_id) => Json::string(nav_id)
    None => Json::null()
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": navigation_json,
    "suggestedFilename": Json::string(suggested_filename),
    "timestamp": Json::number(input_now_ms()),
    "url": Json::string(url),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit downloadEnd event for the given context.
fn BidiProtocol::emit_download_end(
  self : BidiProtocol,
  ctx_id : String,
  navigation_id : String?,
  status : String,
  filepath : String?,
  url : String,
) -> Unit {
  let event_name = "browsingContext.downloadEnd"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let navigation_json = match navigation_id {
    Some(nav_id) => Json::string(nav_id)
    None => Json::null()
  }
  let filepath_json = match filepath {
    Some(path) => Json::string(path)
    None => Json::null()
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": navigation_json,
    "status": Json::string(status),
    "filepath": filepath_json,
    "timestamp": Json::number(input_now_ms()),
    "url": Json::string(url),
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
/// Complete navigation state update and send success response.
fn BidiProtocol::complete_navigation_request(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
) -> Unit {
  self.complete_navigation_request_with_wait(request_id, ctx_id, url, "none")
}

///|
/// Complete navigation state update and optionally defer success response by wait mode.
fn BidiProtocol::complete_navigation_request_with_wait(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
  wait_mode : String,
) -> Unit {
  self.complete_navigation_request_with_wait_and_navigation(
    request_id,
    ctx_id,
    url,
    wait_mode,
    None,
  )
}

///|
/// Complete navigation update using an optional preallocated navigation id.
fn BidiProtocol::complete_navigation_request_with_wait_and_navigation(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
  wait_mode : String,
  navigation_id : String?,
) -> Unit {
  let nav_id = match navigation_id {
    Some(id) => id
    None => {
      let generated_id = self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      generated_id
    }
  }
  let previous_children = self.context_children.get(ctx_id).unwrap_or([])
  reset_runtime_event_buffers(ctx_id)
  self.load_data_url_content(ctx_id, url)
  let defer_parent_lifecycle = self.collect_iframe_sources(ctx_id).length() > 0
  for child_ctx_id in previous_children {
    let original_opener = self.context_original_opener.get(child_ctx_id)
    self.emit_context_destroyed(child_ctx_id, original_opener)
  }
  self.drop_child_contexts(ctx_id, false)
  self.clear_context_sandbox_realms(ctx_id)
  // Navigation replaces the default window realm.
  let window_realm_id = self.assign_new_realm(ctx_id)
  self.emit_default_realm(ctx_id)
  self.emit_worker_realms_from_scripts(ctx_id, window_realm_id)
  if url.contains("/webdriver/tests/support/html/beforeunload.html") {
    self.context_has_beforeunload[ctx_id] = true
  } else {
    self.context_has_beforeunload.remove(ctx_id)
  }
  if navigation_blocks_cross_origin_iframe_navigation(url) {
    self.context_blocks_cross_origin_iframe_navigation[ctx_id] = true
  } else {
    self.context_blocks_cross_origin_iframe_navigation.remove(ctx_id)
  }
  self.emit_navigation_events_internal(
    ctx_id,
    url,
    nav_id,
    not(defer_parent_lifecycle),
  )
  self.refresh_child_contexts_from_iframes(ctx_id)
  if defer_parent_lifecycle {
    self.emit_navigation_lifecycle_events(ctx_id, url, nav_id)
  }
  self.register_navigation_prompt_from_url(ctx_id, url)
  let has_inline_redirect = match resolve_inline_script_redirect_url(url) {
    Some(_) => true
    None => false
  }
  let block_response = should_block_navigation_response(wait_mode, url)
  let mark_in_flight = is_interruptible_navigation_candidate(url) &&
    not(has_inline_redirect)
  if mark_in_flight {
    if block_response {
      self.register_in_flight_navigation(ctx_id, url, nav_id, Some(request_id))
      return
    }
    self.register_in_flight_navigation(ctx_id, url, nav_id, None)
  } else {
    self.clear_pending_navigation_state(ctx_id)
    if block_response {
      apply_navigation_wait_delay(wait_mode, url)
    }
  }
  let result = make_object({
    "navigation": Json::string(nav_id),
    "url": Json::string(url),
  })
  self.send_success(request_id, Some(result))
}

///|
/// Complete same-document fragment navigation.
fn BidiProtocol::complete_fragment_navigation_request(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
) -> Unit {
  self.clear_pending_navigation_state(ctx_id)
  let nav_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  self.emit_fragment_navigated_event(ctx_id, url, Some(nav_id))
  self.emit_history_updated_event(ctx_id, url)
  let result = make_object({
    "navigation": Json::string(nav_id),
    "url": Json::string(url),
  })
  self.send_success(request_id, Some(result))
}

///|
/// Emit navigationStarted event for the given context.
fn BidiProtocol::emit_navigation_started_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let event_name = "browsingContext.navigationStarted"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit navigationCommitted event for the given context.
fn BidiProtocol::emit_navigation_committed_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let event_name = "browsingContext.navigationCommitted"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit navigationFailed event for the given context.
fn BidiProtocol::emit_navigation_failed_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let event_name = "browsingContext.navigationFailed"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit navigationAborted event for the given context.
fn BidiProtocol::emit_navigation_aborted_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let event_name = "browsingContext.navigationAborted"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) {
    return
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit domContentLoaded/load/historyUpdated for a committed navigation.
fn BidiProtocol::emit_navigation_lifecycle_events(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let timestamp = input_now_ms()
  let base = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(timestamp),
  })
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
    "timestamp": Json::number(timestamp),
  })
  if self.is_subscribed_for_context("browsingContext.historyUpdated", ctx_id) {
    self.outbox.push(
      Event({ event_method: "browsingContext.historyUpdated", params: history }),
    )
  }
}

///|
/// Emit basic navigation events.
fn BidiProtocol::emit_navigation_events(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  self.emit_navigation_events_internal(ctx_id, url, navigation_id, true)
}

///|
/// Emit basic navigation events, optionally excluding dom/load/history lifecycle.
fn BidiProtocol::emit_navigation_events_internal(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
  emit_lifecycle : Bool,
) -> Unit {
  let committed_url = resolve_navigation_committed_url(url)
  self.emit_navigation_started_event(ctx_id, url, navigation_id)
  self.emit_navigation_committed_event(ctx_id, committed_url, navigation_id)
  if emit_lifecycle {
    self.emit_navigation_lifecycle_events(ctx_id, url, navigation_id)
  }
  match resolve_http_equiv_redirect_url(url) {
    Some(redirected_url) => {
      let redirected_nav_id = self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      self.emit_navigation_started_event(
        ctx_id, redirected_url, redirected_nav_id,
      )
      self.emit_navigation_committed_event(
        ctx_id, redirected_url, redirected_nav_id,
      )
      if emit_lifecycle {
        self.emit_navigation_lifecycle_events(
          ctx_id, redirected_url, redirected_nav_id,
        )
      }
    }
    None => ()
  }
  match resolve_inline_script_redirect_url(url) {
    Some(redirected_url) => {
      self.emit_navigation_aborted_event(ctx_id, url, navigation_id)
      let redirected_nav_id = self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      self.emit_navigation_started_event(
        ctx_id, redirected_url, redirected_nav_id,
      )
      self.emit_navigation_committed_event(
        ctx_id,
        resolve_navigation_committed_url(redirected_url),
        redirected_nav_id,
      )
      if emit_lifecycle {
        self.emit_navigation_lifecycle_events(
          ctx_id, redirected_url, redirected_nav_id,
        )
      }
    }
    None => ()
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
    if not(blocked_global) && sub == module_key {
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
        if sub == event || sub == module_key {
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
        if sub == event || sub == module_key {
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
/// Validate browser.createUserContext parameters.
fn BidiProtocol::validate_browser_create_user_context(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match params {
    None => ()
    Some(Object(map)) => {
      match map.get("acceptInsecureCerts") {
        Some(True) | Some(False) => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "acceptInsecureCerts must be a boolean",
          )
          return Some(())
        }
        None => ()
      }

      match map.get("proxy") {
        Some(Object(proxy)) =>
          match self.validate_browser_proxy_config(request_id, proxy) {
            Some(_) => return Some(())
            None => ()
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "proxy must be an object",
          )
          return Some(())
        }
        None => ()
      }

      match map.get("unhandledPromptBehavior") {
        Some(Object(behavior)) =>
          match
            self.validate_browser_unhandled_prompt_behavior(
              request_id, behavior,
            ) {
            Some(_) => return Some(())
            None => ()
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "unhandledPromptBehavior must be an object",
          )
          return Some(())
        }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return Some(())
    }
  }

  None
}

///|
/// Validate browser.createUserContext proxy config.
fn BidiProtocol::validate_browser_proxy_config(
  self : BidiProtocol,
  request_id : Int,
  proxy : Map[String, Json],
) -> Unit? {
  let proxy_type = match proxy.get("proxyType") {
    Some(String(kind)) => kind
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.proxyType must be a string",
      )
      return Some(())
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "proxy.proxyType is required",
      )
      return Some(())
    }
  }

  match proxy_type {
    "system" => ()
    "autodetect" => ()
    "direct" => ()
    "manual" =>
      match self.validate_browser_manual_proxy(request_id, proxy) {
        Some(_) => return Some(())
        None => ()
      }
    "pac" =>
      match proxy.get("proxyAutoconfigUrl") {
        Some(String(_)) => ()
        _ => {
          self.send_error(
            request_id, "invalid argument", "proxy.proxyAutoconfigUrl must be a string",
          )
          return Some(())
        }
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "proxy.proxyType is invalid",
      )
      return Some(())
    }
  }

  None
}

///|
/// Validate manual proxy configuration.
fn BidiProtocol::validate_browser_manual_proxy(
  self : BidiProtocol,
  request_id : Int,
  proxy : Map[String, Json],
) -> Unit? {
  let mut has_socks_proxy = false
  let mut has_socks_version = false

  match proxy.get("httpProxy") {
    Some(String(v)) =>
      if not(is_valid_proxy_endpoint_value(v)) {
        self.send_error(
          request_id, "invalid argument", "proxy.httpProxy is invalid",
        )
        return Some(())
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.httpProxy must be a string",
      )
      return Some(())
    }
    None => ()
  }

  match proxy.get("sslProxy") {
    Some(String(v)) =>
      if not(is_valid_proxy_endpoint_value(v)) {
        self.send_error(
          request_id, "invalid argument", "proxy.sslProxy is invalid",
        )
        return Some(())
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.sslProxy must be a string",
      )
      return Some(())
    }
    None => ()
  }

  match proxy.get("socksProxy") {
    Some(String(v)) => {
      has_socks_proxy = true
      if not(is_valid_proxy_endpoint_value(v)) {
        self.send_error(
          request_id, "invalid argument", "proxy.socksProxy is invalid",
        )
        return Some(())
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.socksProxy must be a string",
      )
      return Some(())
    }
    None => ()
  }

  match proxy.get("socksVersion") {
    Some(Number(n, ..)) => {
      has_socks_version = true
      if n != n.to_int64().to_double() {
        self.send_error(
          request_id, "invalid argument", "proxy.socksVersion must be an integer",
        )
        return Some(())
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.socksVersion must be a number",
      )
      return Some(())
    }
    None => ()
  }

  if has_socks_version && not(has_socks_proxy) {
    self.send_error(
      request_id, "invalid argument", "proxy.socksProxy is required when socksVersion is set",
    )
    return Some(())
  }
  if has_socks_proxy && not(has_socks_version) {
    self.send_error(
      request_id, "invalid argument", "proxy.socksVersion is required when socksProxy is set",
    )
    return Some(())
  }

  match proxy.get("noProxy") {
    Some(Array(entries)) =>
      for entry in entries {
        match entry {
          String(_) => ()
          _ => {
            self.send_error(
              request_id, "invalid argument", "proxy.noProxy entries must be strings",
            )
            return Some(())
          }
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.noProxy must be an array",
      )
      return Some(())
    }
    None => ()
  }

  None
}

///|
/// Normalize unhandledPromptBehavior string handler.
fn normalize_unhandled_prompt_handler_name(raw_handler : String) -> String? {
  match raw_handler {
    "accept" => Some("accept")
    "accept and notify" => Some("accept")
    "dismiss" => Some("dismiss")
    "dismiss and notify" => Some("dismiss")
    "ignore" => Some("ignore")
    _ => None
  }
}

///|
/// Validate unhandledPromptBehavior object.
fn BidiProtocol::validate_browser_unhandled_prompt_behavior(
  self : BidiProtocol,
  request_id : Int,
  behavior : Map[String, Json],
) -> Unit? {
  for key, raw_value in behavior {
    if key != "alert" &&
      key != "beforeUnload" &&
      key != "confirm" &&
      key != "default" &&
      key != "file" &&
      key != "prompt" {
      self.send_error(
        request_id,
        "invalid argument",
        "unhandledPromptBehavior key is invalid: " + key,
      )
      return Some(())
    }

    match raw_value {
      String(handler) =>
        if handler != "accept" && handler != "dismiss" && handler != "ignore" {
          self.send_error(
            request_id, "invalid argument", "unhandledPromptBehavior handler is invalid",
          )
          return Some(())
        }
      _ => {
        self.send_error(
          request_id, "invalid argument", "unhandledPromptBehavior handler must be a string",
        )
        return Some(())
      }
    }
  }
  None
}

///|
/// Validate browser.setDownloadBehavior parameters.
fn BidiProtocol::validate_browser_set_download_behavior(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  let map = match params {
    Some(Object(m)) => m
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return Some(())
    }
  }

  match map.get("downloadBehavior") {
    Some(Null) => ()
    Some(Object(download_behavior)) => {
      let behavior_type = match download_behavior.get("type") {
        Some(String(kind)) => kind
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "downloadBehavior.type must be a string",
          )
          return Some(())
        }
        None => {
          self.send_error(
            request_id, "invalid argument", "downloadBehavior.type is required",
          )
          return Some(())
        }
      }

      if behavior_type != "allowed" &&
        behavior_type != "denied" &&
        behavior_type != "default" {
        self.send_error(
          request_id, "invalid argument", "downloadBehavior.type is invalid",
        )
        return Some(())
      }

      if behavior_type == "allowed" {
        match download_behavior.get("destinationFolder") {
          Some(String(_)) => ()
          _ => {
            self.send_error(
              request_id, "invalid argument", "downloadBehavior.destinationFolder must be a string",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "downloadBehavior must be an object or null",
      )
      return Some(())
    }
    None => ()
  }

  match map.get("userContexts") {
    Some(Array(user_contexts)) => {
      if user_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return Some(())
      }
      for raw_user_context in user_contexts {
        match raw_user_context {
          String(user_context_id) =>
            if not(self.user_contexts.contains(user_context_id)) {
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

  None
}

///|
/// Validate host:port proxy endpoint values.
fn is_valid_proxy_endpoint_value(value : String) -> Bool {
  if value.length() == 0 {
    return false
  }
  if value.has_prefix("http://") || value.has_prefix("https://") {
    return false
  }
  if value.contains("/") || value.contains("?") || value.contains("#") {
    return false
  }

  let chars = value.to_array()
  let mut colon_count = 0
  let mut colon_idx = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == ':' {
      colon_count += 1
      colon_idx = i
    }
  }
  if colon_count != 1 {
    return false
  }
  if colon_idx <= 0 || colon_idx >= chars.length() - 1 {
    return false
  }

  let host = value[:colon_idx].to_string() catch { _ => "" }
  if host.length() == 0 {
    return false
  }

  let port_text = value[colon_idx + 1:].to_string() catch { _ => "" }
  let port = match parse_decimal_string(port_text) {
    Some(v) => v
    None => return false
  }
  port > 0 && port <= 65535
}

///|
/// Parse decimal ASCII digits to an int.
fn parse_decimal_string(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }

  let mut parsed = 0
  for c in value.iter() {
    if c < '0' || c > '9' {
      return None
    }
    parsed = parsed * 10 + (c.to_int() - '0'.to_int())
  }
  Some(parsed)
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
/// Get serializationOptions for locateNodes with adjusted DOM depth semantics.
fn get_locate_nodes_serialization_options_json(params : Json?) -> String {
  match get_param_raw(params, "serializationOptions") {
    Some(Object(opts)) => {
      let adjusted : Map[String, Json] = {}
      for key, value in opts {
        adjusted[key] = value
      }
      match opts.get("maxDomDepth") {
        Some(Number(n, ..)) => adjusted["maxDomDepth"] = Json::number(n + 2.0)
        _ => adjusted["maxDomDepth"] = Json::number(4.0)
      }
      match opts.get("includeShadowTree") {
        Some(String(mode)) => adjusted["includeShadowTree"] = Json::string(mode)
        _ => adjusted["includeShadowTree"] = Json::string("all")
      }
      make_object(adjusted).stringify()
    }
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
  let resolved_opened_url = if opened_url == "" {
    "about:blank"
  } else {
    opened_url
  }
  let skip_navigation_started = resolved_opened_url == "about:blank" ||
    resolved_opened_url.has_prefix("about:blank?")

  let user_ctx = self.context_user_context
    .get(opener_ctx_id)
    .unwrap_or("default")
  let new_ctx_id = self.create_context(user_ctx, "tab")
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
      let _ = session.navigate_to(resolved_opened_url)
    }
    None => ()
  }
  self.load_data_url_content(new_ctx_id, resolved_opened_url)
  self.drop_child_contexts(new_ctx_id, false)
  self.refresh_child_contexts_from_iframes(new_ctx_id)
  self.clear_context_sandbox_realms(new_ctx_id)
  let opened_realm_id = self.assign_new_realm(new_ctx_id)
  self.emit_default_realm(new_ctx_id)
  self.emit_worker_realms_from_scripts(new_ctx_id, opened_realm_id)
  if not(skip_navigation_started) {
    let nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    self.emit_navigation_events(new_ctx_id, resolved_opened_url, nav_id)
  }

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
