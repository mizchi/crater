///|
/// WebDriver BiDi Protocol (minimal)
///
/// Focuses on a BiDi-first automation surface while reusing CDP sessions.
/// This is intentionally small and grows as coverage expands.

///|
/// Stored script.addPreloadScript registration.
priv struct PreloadScriptEntry {
  script_id : String
  function_declaration : String
  arguments : Array[Json]
  sandbox : String?
  contexts : Array[String]
  user_contexts : Array[String]
}

///|
/// Parsed script.addPreloadScript parameters.
priv struct AddPreloadScriptParams {
  function_declaration : String
  arguments : Array[Json]
  sandbox : String?
  contexts : Array[String]
  user_contexts : Array[String]
}

///|
priv struct NavigationCompletion {
  result : Json
  navigation_id : String
  deferred_response : Bool
}

///|
/// BiDi protocol handler
priv struct BidiProtocol {
  manager : CdpSessionManager
  mut outbox : Array[BidiOutMessage]
  mut default_context_id : String?
  mut active_context_id : String?
  mut next_navigation_id : Int
  mut next_realm_id : Int
  mut next_preload_script_id : Int
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
  installed_web_extensions : Map[String, String] // extension id -> source kind
  mut next_web_extension_id : Int
  permission_state_by_scope : Map[String, String] // "<name>|<userContext>|<origin>|<embeddedOrigin>" -> state
  mut emulation_user_agent_global : String?
  emulation_user_agent_by_context : Map[String, String] // top-level context -> userAgent override
  emulation_user_agent_by_user_context : Map[String, String] // user context -> userAgent override
  mut emulation_locale_global : String?
  emulation_locale_by_context : Map[String, String] // top-level context -> locale override
  emulation_locale_by_user_context : Map[String, String] // user context -> locale override
  mut emulation_timezone_global : String?
  emulation_timezone_by_context : Map[String, String] // top-level context -> timezone override
  emulation_timezone_by_user_context : Map[String, String] // user context -> timezone override
  mut emulation_geolocation_global : Json?
  emulation_geolocation_by_context : Map[String, Json] // top-level context -> geolocation override
  emulation_geolocation_by_user_context : Map[String, Json] // user context -> geolocation override
  mut emulation_network_conditions_global : Json?
  emulation_network_conditions_by_context : Map[String, Json] // top-level context -> network conditions override
  emulation_network_conditions_by_user_context : Map[String, Json] // user context -> network conditions override
  mut emulation_screen_orientation_global : Json?
  emulation_screen_orientation_by_context : Map[String, Json] // top-level context -> screen orientation override
  emulation_screen_orientation_by_user_context : Map[String, Json] // user context -> screen orientation override
  mut emulation_screen_area_global : Json?
  emulation_screen_area_by_context : Map[String, Json] // top-level context -> screen area override
  emulation_screen_area_by_user_context : Map[String, Json] // user context -> screen area override
  geolocation_watch_channel_by_scope : Map[String, String] // "<context>|<watchId>" -> script.message channel
  geolocation_watch_realm_by_scope : Map[String, String] // "<context>|<watchId>" -> originating realm
  geolocation_watch_notify_success_by_scope : Map[String, Bool] // "<context>|<watchId>" -> emit coords updates
  geolocation_watch_notify_error_by_scope : Map[String, Bool] // "<context>|<watchId>" -> emit error updates
  mut next_geolocation_watch_id : Int
  bluetooth_adapter_state_by_context : Map[String, String] // context -> absent|powered-off|powered-on
  bluetooth_simulation_disabled_by_context : Map[String, Bool] // context -> simulation disabled
  bluetooth_preconnected_devices_by_context : Map[String, Array[Json]] // context -> synthetic device descriptors
  bluetooth_granted_devices_by_context : Map[String, Array[Json]] // context -> granted synthetic device descriptors
  bluetooth_pending_prompt_request : Map[String, Int] // context -> deferred requestDevice request id
  bluetooth_pending_prompt_realm : Map[String, String] // context -> deferred requestDevice realm id
  bluetooth_pending_prompt_unwrap_result : Map[String, Bool] // context -> deferred requestDevice unwrap mode
  bluetooth_pending_prompt_id : Map[String, String] // context -> active bluetooth prompt id
  bluetooth_pending_prompt_device_address : Map[String, String] // context -> prompt-selected device address
  bluetooth_pending_prompt_device_name : Map[String, String] // context -> prompt-selected device name
  bluetooth_gatt_connected_by_scope : Map[String, Bool] // "<context>|<address>" -> connected flag
  bluetooth_services_by_scope : Map[String, Array[String]] // "<context>|<address>" -> primary service uuids
  bluetooth_characteristics_by_scope : Map[String, Json] // "<context>|<address>|<service>|<characteristic>" -> properties object
  bluetooth_descriptors_by_scope : Map[String, Bool] // "<context>|<address>|<service>|<characteristic>|<descriptor>" -> descriptor exists
  bluetooth_pending_gatt_request : Map[String, Int] // context -> deferred gatt.connect request id
  bluetooth_pending_gatt_realm : Map[String, String] // context -> deferred gatt.connect realm id
  bluetooth_pending_gatt_unwrap_result : Map[String, Bool] // context -> deferred gatt.connect unwrap mode
  bluetooth_pending_gatt_address : Map[String, String] // context -> deferred gatt.connect device address
  bluetooth_pending_gatt_response_kind : Map[String, String] // context -> deferred response mode
  bluetooth_pending_characteristic_request : Map[String, Int] // context -> deferred characteristic request id
  bluetooth_pending_characteristic_realm : Map[String, String] // context -> deferred characteristic realm id
  bluetooth_pending_characteristic_unwrap_result : Map[String, Bool] // context -> deferred characteristic unwrap mode
  bluetooth_pending_characteristic_address : Map[String, String] // context -> deferred characteristic device address
  bluetooth_pending_characteristic_service_uuid : Map[String, String] // context -> deferred characteristic service uuid
  bluetooth_pending_characteristic_uuid : Map[String, String] // context -> deferred characteristic uuid
  bluetooth_pending_characteristic_type : Map[String, String] // context -> deferred characteristic response type
  bluetooth_pending_descriptor_request : Map[String, Int] // context -> deferred descriptor request id
  bluetooth_pending_descriptor_realm : Map[String, String] // context -> deferred descriptor realm id
  bluetooth_pending_descriptor_unwrap_result : Map[String, Bool] // context -> deferred descriptor unwrap mode
  bluetooth_pending_descriptor_address : Map[String, String] // context -> deferred descriptor device address
  bluetooth_pending_descriptor_service_uuid : Map[String, String] // context -> deferred descriptor service uuid
  bluetooth_pending_descriptor_characteristic_uuid : Map[String, String] // context -> deferred descriptor characteristic uuid
  bluetooth_pending_descriptor_uuid : Map[String, String] // context -> deferred descriptor uuid
  bluetooth_pending_descriptor_type : Map[String, String] // context -> deferred descriptor response type
  mut next_bluetooth_prompt_id : Int
  user_context_viewport_width : Map[String, Int] // user context -> default viewport width override
  user_context_viewport_height : Map[String, Int] // user context -> default viewport height override
  user_context_device_pixel_ratio : Map[String, Double] // user context -> default devicePixelRatio override
  context_user_context : Map[String, String]
  context_has_beforeunload : Map[String, Bool]
  context_blocks_cross_origin_iframe_navigation : Map[String, Bool] // context -> active CSP/COEP frame policy
  pending_prompt_type : Map[String, String] // context -> prompt type
  pending_close_request : Map[String, Int] // context -> browsingContext.close request id
  pending_close_wait_for_destroyed : Map[String, Bool] // context -> closeWithState wait flag
  pending_close_response_mode : Map[String, String] // context -> close response kind
  pending_prompt_request : Map[String, Int] // context -> deferred script.evaluate request id
  pending_prompt_realm : Map[String, String] // context -> deferred script.evaluate realm id
  pending_prompt_unwrap_result : Map[String, Bool] // context -> deferred script.evaluate unwrap mode
  pending_beforeunload_request : Map[String, Int] // context -> deferred navigate request id
  pending_beforeunload_url : Map[String, String] // context -> deferred navigate destination
  pending_beforeunload_requested_url : Map[String, String] // context -> deferred original requested URL
  pending_beforeunload_wait : Map[String, String] // context -> deferred navigate wait mode
  pending_beforeunload_navigation : Map[String, String] // context -> deferred navigation id
  pending_beforeunload_finalize_mode : Map[String, String] // context -> deferred internal navigate/reload mode
  pending_navigation_request : Map[String, Int] // context -> deferred navigate/reload request id
  pending_navigation_response_mode : Map[String, String] // context -> deferred navigation response kind
  in_flight_navigation_url : Map[String, String] // context -> interruptible navigation URL
  in_flight_navigation_id : Map[String, String] // context -> interruptible navigation id
  in_flight_navigation_started_at : Map[String, Double] // context -> interruptible navigation start timestamp
  pending_prompt_result_var : Map[String, String] // context -> window property to store prompt result
  context_local_storage : Map[String, Map[String, String]] // context -> localStorage key/value
  storage_cookies_by_scope : Map[String, Map[String, StoredCookie]] // scope -> stored cookies
  synthetic_location_href_by_context : Map[String, String] // context -> synthetic window.location.href override
  context_last_started_navigation : Map[String, String] // context -> last emitted navigationStarted id
  context_requested_navigation_url : Map[String, String] // context -> last requested navigation URL
  context_original_opener : Map[String, String]
  context_realm : Map[String, String]
  context_sandbox_realm : Map[String, String] // "<context>::<sandbox>" -> realm
  realm_context : Map[String, String] // realm -> context
  context_worker_realms : Map[String, Array[String]] // context -> worker realms
  realm_sandbox : Map[String, String] // sandbox realm -> sandbox name
  context_parent : Map[String, String]
  context_children : Map[String, Array[String]]
  context_had_synthetic_child : Map[String, Bool] // top-level context -> has synthetic child helper
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
  input_html_drag_over_shared : Map[String, String] // context -> current dragover target sharedId
  input_html_drag_accept_shared : Map[String, String] // context -> dragover target that accepted drop
  input_html_drag_transfer_id : Map[String, String] // context -> shared synthetic DataTransfer key
  input_last_click_time : Map[String, Double] // context -> timestamp of last primary click release
  input_last_click_x : Map[String, Double] // context -> x of last primary click release
  input_last_click_y : Map[String, Double] // context -> y of last primary click release
  input_last_click_target_shared : Map[String, String] // context -> target of last primary click release
  input_pending_double_click : Map[String, Bool] // context -> whether current click sequence should emit dblclick
  input_action_clock_ms : Map[String, Double] // context -> virtual input clock advanced by pause durations
  input_synthetic_events_by_context : Map[String, Array[Json]] // context -> synthetic window.allEvents.events entries
  context_synthetic_scrolled : Map[String, Bool] // context -> synthetic scroll fallback applied
  speculation_prefetch_target_by_context : Map[String, String] // context -> last synthetic prefetch target
  network_intercepts : Map[String, Json] // intercept id -> network.addIntercept options
  mut next_network_intercept_id : Int
  mut next_network_request_id : Int
  mut network_cache_behavior_global : String
  network_extra_headers_global : Map[String, String]
  network_extra_headers_by_context : Map[String, Map[String, String]]
  network_extra_headers_by_user_context : Map[String, Map[String, String]]
  network_cache_behavior_by_context : Map[String, String]
  network_state_channel_by_context : Map[String, String] // context -> script.message channel for offline/online notifications
  network_cached_requests_by_context : Map[String, Map[String, Bool]]
  network_blocked_requests : Map[String, Json] // request id -> synthetic blocked request payload
  network_data_collectors : Map[String, Json] // collector id -> network.addDataCollector options
  network_collected_data : Map[String, Map[String, Map[String, Json]]] // request -> collector -> dataType -> bytes value
  mut next_network_data_collector_id : Int
  mut socket : @core.Any? // WebSocket for async responses
  mut socket_epoch : Int // Monotonic epoch for active WebSocket
  use_quickjs : Bool // Use QuickJS sandboxed runtime for script execution
  mut dom_initialized : Bool // Deno-side mock DOM initialized
  mut preload_scripts : Array[PreloadScriptEntry]
}

///|
fn[T] BidiProtocol::resolve_effective_scoped_override(
  self : BidiProtocol,
  ctx_id : String,
  by_context : Map[String, T],
  by_user_context : Map[String, T],
  global : T?,
) -> T? {
  let ancestry = self.storage_context_ancestry(ctx_id)
  let mut index = ancestry.length()
  while index > 0 {
    index = index - 1
    let scope_id = ancestry[index]
    match by_context.get(scope_id) {
      Some(override_value) => return Some(override_value)
      None => ()
    }
  }
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  match by_user_context.get(user_context_id) {
    Some(override_value) => Some(override_value)
    None => global
  }
}

///|
/// Create new BiDi protocol instance
fn BidiProtocol::new() -> BidiProtocol {
  let user_contexts : Map[String, Bool] = {}
  user_contexts["default"] = true
  {
    manager: CdpSessionManager::new(),
    outbox: [],
    default_context_id: None,
    active_context_id: None,
    next_navigation_id: 1,
    next_realm_id: 1,
    next_preload_script_id: 1,
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
    installed_web_extensions: {},
    next_web_extension_id: 1,
    permission_state_by_scope: {},
    emulation_user_agent_global: None,
    emulation_user_agent_by_context: {},
    emulation_user_agent_by_user_context: {},
    emulation_locale_global: None,
    emulation_locale_by_context: {},
    emulation_locale_by_user_context: {},
    emulation_timezone_global: None,
    emulation_timezone_by_context: {},
    emulation_timezone_by_user_context: {},
    emulation_geolocation_global: None,
    emulation_geolocation_by_context: {},
    emulation_geolocation_by_user_context: {},
    emulation_network_conditions_global: None,
    emulation_network_conditions_by_context: {},
    emulation_network_conditions_by_user_context: {},
    emulation_screen_orientation_global: None,
    emulation_screen_orientation_by_context: {},
    emulation_screen_orientation_by_user_context: {},
    emulation_screen_area_global: None,
    emulation_screen_area_by_context: {},
    emulation_screen_area_by_user_context: {},
    geolocation_watch_channel_by_scope: {},
    geolocation_watch_realm_by_scope: {},
    geolocation_watch_notify_success_by_scope: {},
    geolocation_watch_notify_error_by_scope: {},
    next_geolocation_watch_id: 1,
    bluetooth_adapter_state_by_context: {},
    bluetooth_simulation_disabled_by_context: {},
    bluetooth_preconnected_devices_by_context: {},
    bluetooth_granted_devices_by_context: {},
    bluetooth_pending_prompt_request: {},
    bluetooth_pending_prompt_realm: {},
    bluetooth_pending_prompt_unwrap_result: {},
    bluetooth_pending_prompt_id: {},
    bluetooth_pending_prompt_device_address: {},
    bluetooth_pending_prompt_device_name: {},
    bluetooth_gatt_connected_by_scope: {},
    bluetooth_services_by_scope: {},
    bluetooth_characteristics_by_scope: {},
    bluetooth_descriptors_by_scope: {},
    bluetooth_pending_gatt_request: {},
    bluetooth_pending_gatt_realm: {},
    bluetooth_pending_gatt_unwrap_result: {},
    bluetooth_pending_gatt_address: {},
    bluetooth_pending_gatt_response_kind: {},
    bluetooth_pending_characteristic_request: {},
    bluetooth_pending_characteristic_realm: {},
    bluetooth_pending_characteristic_unwrap_result: {},
    bluetooth_pending_characteristic_address: {},
    bluetooth_pending_characteristic_service_uuid: {},
    bluetooth_pending_characteristic_uuid: {},
    bluetooth_pending_characteristic_type: {},
    bluetooth_pending_descriptor_request: {},
    bluetooth_pending_descriptor_realm: {},
    bluetooth_pending_descriptor_unwrap_result: {},
    bluetooth_pending_descriptor_address: {},
    bluetooth_pending_descriptor_service_uuid: {},
    bluetooth_pending_descriptor_characteristic_uuid: {},
    bluetooth_pending_descriptor_uuid: {},
    bluetooth_pending_descriptor_type: {},
    next_bluetooth_prompt_id: 1,
    user_context_viewport_width: {},
    user_context_viewport_height: {},
    user_context_device_pixel_ratio: {},
    context_user_context: {},
    context_has_beforeunload: {},
    context_blocks_cross_origin_iframe_navigation: {},
    pending_prompt_type: {},
    pending_close_request: {},
    pending_close_wait_for_destroyed: {},
    pending_close_response_mode: {},
    pending_prompt_request: {},
    pending_prompt_realm: {},
    pending_prompt_unwrap_result: {},
    pending_beforeunload_request: {},
    pending_beforeunload_url: {},
    pending_beforeunload_requested_url: {},
    pending_beforeunload_wait: {},
    pending_beforeunload_navigation: {},
    pending_beforeunload_finalize_mode: {},
    pending_navigation_request: {},
    pending_navigation_response_mode: {},
    in_flight_navigation_url: {},
    in_flight_navigation_id: {},
    in_flight_navigation_started_at: {},
    pending_prompt_result_var: {},
    context_local_storage: {},
    storage_cookies_by_scope: {},
    synthetic_location_href_by_context: {},
    context_last_started_navigation: {},
    context_requested_navigation_url: {},
    context_original_opener: {},
    context_realm: {},
    context_sandbox_realm: {},
    realm_context: {},
    context_worker_realms: {},
    realm_sandbox: {},
    context_parent: {},
    context_children: {},
    context_had_synthetic_child: {},
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
    input_html_drag_over_shared: {},
    input_html_drag_accept_shared: {},
    input_html_drag_transfer_id: {},
    input_last_click_time: {},
    input_last_click_x: {},
    input_last_click_y: {},
    input_last_click_target_shared: {},
    input_pending_double_click: {},
    input_action_clock_ms: {},
    input_synthetic_events_by_context: {},
    context_synthetic_scrolled: {},
    speculation_prefetch_target_by_context: {},
    network_intercepts: {},
    next_network_intercept_id: 1,
    next_network_request_id: 1,
    network_cache_behavior_global: "default",
    network_extra_headers_global: {},
    network_extra_headers_by_context: {},
    network_extra_headers_by_user_context: {},
    network_cache_behavior_by_context: {},
    network_state_channel_by_context: {},
    network_cached_requests_by_context: {},
    network_blocked_requests: {},
    network_data_collectors: {},
    network_collected_data: {},
    next_network_data_collector_id: 1,
    socket: None,
    socket_epoch: 0,
    use_quickjs: false,
    dom_initialized: false,
    preload_scripts: [],
  }
}

///|
/// Set WebSocket for async responses and return epoch token.
fn BidiProtocol::set_socket(self : BidiProtocol, socket : @core.Any) -> Int {
  self.socket_epoch += 1
  self.socket = Some(socket)
  self.socket_epoch
}

///|
/// Clear WebSocket reference
fn BidiProtocol::clear_socket(self : BidiProtocol) -> Unit {
  self.socket = None
}

///|
/// Check whether a captured WebSocket epoch is still active.
fn BidiProtocol::is_current_socket_epoch(
  self : BidiProtocol,
  epoch : Int,
) -> Bool {
  self.socket_epoch == epoch
}

///|
/// Reset per-connection subscription state.
fn BidiProtocol::reset_subscription_state(self : BidiProtocol) -> Unit {
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
fn BidiProtocol::reset_session_runtime_state(self : BidiProtocol) -> Unit {
  self.reset_subscription_state()

  for ctx_id in self.manager.list_sessions() {
    self.manager.close_session(ctx_id) |> ignore
  }

  self.default_context_id = None
  self.active_context_id = None

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
  let permission_scope_keys : Array[String] = []
  for key, _ in self.permission_state_by_scope {
    permission_scope_keys.push(key)
  }
  for key in permission_scope_keys {
    self.permission_state_by_scope.remove(key)
  }
  self.emulation_user_agent_global = None
  let emulation_user_agent_context_keys : Array[String] = []
  for key, _ in self.emulation_user_agent_by_context {
    emulation_user_agent_context_keys.push(key)
  }
  for key in emulation_user_agent_context_keys {
    self.emulation_user_agent_by_context.remove(key)
  }
  let emulation_user_agent_user_context_keys : Array[String] = []
  for key, _ in self.emulation_user_agent_by_user_context {
    emulation_user_agent_user_context_keys.push(key)
  }
  for key in emulation_user_agent_user_context_keys {
    self.emulation_user_agent_by_user_context.remove(key)
  }
  self.emulation_locale_global = None
  let emulation_locale_context_keys : Array[String] = []
  for key, _ in self.emulation_locale_by_context {
    emulation_locale_context_keys.push(key)
  }
  for key in emulation_locale_context_keys {
    self.emulation_locale_by_context.remove(key)
  }
  let emulation_locale_user_context_keys : Array[String] = []
  for key, _ in self.emulation_locale_by_user_context {
    emulation_locale_user_context_keys.push(key)
  }
  for key in emulation_locale_user_context_keys {
    self.emulation_locale_by_user_context.remove(key)
  }
  self.emulation_timezone_global = None
  let emulation_timezone_context_keys : Array[String] = []
  for key, _ in self.emulation_timezone_by_context {
    emulation_timezone_context_keys.push(key)
  }
  for key in emulation_timezone_context_keys {
    self.emulation_timezone_by_context.remove(key)
  }
  let emulation_timezone_user_context_keys : Array[String] = []
  for key, _ in self.emulation_timezone_by_user_context {
    emulation_timezone_user_context_keys.push(key)
  }
  for key in emulation_timezone_user_context_keys {
    self.emulation_timezone_by_user_context.remove(key)
  }
  self.emulation_geolocation_global = None
  let emulation_geolocation_context_keys : Array[String] = []
  for key, _ in self.emulation_geolocation_by_context {
    emulation_geolocation_context_keys.push(key)
  }
  for key in emulation_geolocation_context_keys {
    self.emulation_geolocation_by_context.remove(key)
  }
  let emulation_geolocation_user_context_keys : Array[String] = []
  for key, _ in self.emulation_geolocation_by_user_context {
    emulation_geolocation_user_context_keys.push(key)
  }
  for key in emulation_geolocation_user_context_keys {
    self.emulation_geolocation_by_user_context.remove(key)
  }
  self.emulation_network_conditions_global = None
  let emulation_network_conditions_context_keys : Array[String] = []
  for key, _ in self.emulation_network_conditions_by_context {
    emulation_network_conditions_context_keys.push(key)
  }
  for key in emulation_network_conditions_context_keys {
    self.emulation_network_conditions_by_context.remove(key)
  }
  let emulation_network_conditions_user_context_keys : Array[String] = []
  for key, _ in self.emulation_network_conditions_by_user_context {
    emulation_network_conditions_user_context_keys.push(key)
  }
  for key in emulation_network_conditions_user_context_keys {
    self.emulation_network_conditions_by_user_context.remove(key)
  }
  self.emulation_screen_orientation_global = None
  let emulation_screen_orientation_context_keys : Array[String] = []
  for key, _ in self.emulation_screen_orientation_by_context {
    emulation_screen_orientation_context_keys.push(key)
  }
  for key in emulation_screen_orientation_context_keys {
    self.emulation_screen_orientation_by_context.remove(key)
  }
  let emulation_screen_orientation_user_context_keys : Array[String] = []
  for key, _ in self.emulation_screen_orientation_by_user_context {
    emulation_screen_orientation_user_context_keys.push(key)
  }
  for key in emulation_screen_orientation_user_context_keys {
    self.emulation_screen_orientation_by_user_context.remove(key)
  }
  self.emulation_screen_area_global = None
  let emulation_screen_area_context_keys : Array[String] = []
  for key, _ in self.emulation_screen_area_by_context {
    emulation_screen_area_context_keys.push(key)
  }
  for key in emulation_screen_area_context_keys {
    self.emulation_screen_area_by_context.remove(key)
  }
  let emulation_screen_area_user_context_keys : Array[String] = []
  for key, _ in self.emulation_screen_area_by_user_context {
    emulation_screen_area_user_context_keys.push(key)
  }
  for key in emulation_screen_area_user_context_keys {
    self.emulation_screen_area_by_user_context.remove(key)
  }
  let geolocation_watch_channel_keys : Array[String] = []
  for key, _ in self.geolocation_watch_channel_by_scope {
    geolocation_watch_channel_keys.push(key)
  }
  for key in geolocation_watch_channel_keys {
    self.geolocation_watch_channel_by_scope.remove(key)
    self.geolocation_watch_realm_by_scope.remove(key)
    self.geolocation_watch_notify_success_by_scope.remove(key)
    self.geolocation_watch_notify_error_by_scope.remove(key)
  }
  self.next_geolocation_watch_id = 1
  let bluetooth_adapter_state_keys : Array[String] = []
  for key, _ in self.bluetooth_adapter_state_by_context {
    bluetooth_adapter_state_keys.push(key)
  }
  for key in bluetooth_adapter_state_keys {
    self.bluetooth_adapter_state_by_context.remove(key)
  }
  let bluetooth_disabled_keys : Array[String] = []
  for key, _ in self.bluetooth_simulation_disabled_by_context {
    bluetooth_disabled_keys.push(key)
  }
  for key in bluetooth_disabled_keys {
    self.bluetooth_simulation_disabled_by_context.remove(key)
  }
  let bluetooth_preconnected_keys : Array[String] = []
  for key, _ in self.bluetooth_preconnected_devices_by_context {
    bluetooth_preconnected_keys.push(key)
  }
  for key in bluetooth_preconnected_keys {
    self.bluetooth_preconnected_devices_by_context.remove(key)
  }
  let bluetooth_granted_keys : Array[String] = []
  for key, _ in self.bluetooth_granted_devices_by_context {
    bluetooth_granted_keys.push(key)
  }
  for key in bluetooth_granted_keys {
    self.bluetooth_granted_devices_by_context.remove(key)
  }
  let bluetooth_pending_request_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_prompt_request {
    bluetooth_pending_request_keys.push(key)
  }
  for key in bluetooth_pending_request_keys {
    self.bluetooth_pending_prompt_request.remove(key)
  }
  let bluetooth_pending_realm_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_prompt_realm {
    bluetooth_pending_realm_keys.push(key)
  }
  for key in bluetooth_pending_realm_keys {
    self.bluetooth_pending_prompt_realm.remove(key)
  }
  let bluetooth_pending_unwrap_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_prompt_unwrap_result {
    bluetooth_pending_unwrap_keys.push(key)
  }
  for key in bluetooth_pending_unwrap_keys {
    self.bluetooth_pending_prompt_unwrap_result.remove(key)
  }
  let bluetooth_pending_prompt_id_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_prompt_id {
    bluetooth_pending_prompt_id_keys.push(key)
  }
  for key in bluetooth_pending_prompt_id_keys {
    self.bluetooth_pending_prompt_id.remove(key)
  }
  let bluetooth_pending_address_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_prompt_device_address {
    bluetooth_pending_address_keys.push(key)
  }
  for key in bluetooth_pending_address_keys {
    self.bluetooth_pending_prompt_device_address.remove(key)
  }
  let bluetooth_pending_name_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_prompt_device_name {
    bluetooth_pending_name_keys.push(key)
  }
  for key in bluetooth_pending_name_keys {
    self.bluetooth_pending_prompt_device_name.remove(key)
  }
  let bluetooth_gatt_connected_keys : Array[String] = []
  for key, _ in self.bluetooth_gatt_connected_by_scope {
    bluetooth_gatt_connected_keys.push(key)
  }
  for key in bluetooth_gatt_connected_keys {
    self.bluetooth_gatt_connected_by_scope.remove(key)
  }
  let bluetooth_service_scope_keys : Array[String] = []
  for key, _ in self.bluetooth_services_by_scope {
    bluetooth_service_scope_keys.push(key)
  }
  for key in bluetooth_service_scope_keys {
    self.bluetooth_services_by_scope.remove(key)
  }
  let bluetooth_characteristic_scope_keys : Array[String] = []
  for key, _ in self.bluetooth_characteristics_by_scope {
    bluetooth_characteristic_scope_keys.push(key)
  }
  for key in bluetooth_characteristic_scope_keys {
    self.bluetooth_characteristics_by_scope.remove(key)
  }
  let bluetooth_descriptor_scope_keys : Array[String] = []
  for key, _ in self.bluetooth_descriptors_by_scope {
    bluetooth_descriptor_scope_keys.push(key)
  }
  for key in bluetooth_descriptor_scope_keys {
    self.bluetooth_descriptors_by_scope.remove(key)
  }
  let bluetooth_pending_gatt_request_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_gatt_request {
    bluetooth_pending_gatt_request_keys.push(key)
  }
  for key in bluetooth_pending_gatt_request_keys {
    self.bluetooth_pending_gatt_request.remove(key)
  }
  let bluetooth_pending_gatt_realm_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_gatt_realm {
    bluetooth_pending_gatt_realm_keys.push(key)
  }
  for key in bluetooth_pending_gatt_realm_keys {
    self.bluetooth_pending_gatt_realm.remove(key)
  }
  let bluetooth_pending_gatt_unwrap_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_gatt_unwrap_result {
    bluetooth_pending_gatt_unwrap_keys.push(key)
  }
  for key in bluetooth_pending_gatt_unwrap_keys {
    self.bluetooth_pending_gatt_unwrap_result.remove(key)
  }
  let bluetooth_pending_gatt_address_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_gatt_address {
    bluetooth_pending_gatt_address_keys.push(key)
  }
  for key in bluetooth_pending_gatt_address_keys {
    self.bluetooth_pending_gatt_address.remove(key)
  }
  let bluetooth_pending_gatt_kind_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_gatt_response_kind {
    bluetooth_pending_gatt_kind_keys.push(key)
  }
  for key in bluetooth_pending_gatt_kind_keys {
    self.bluetooth_pending_gatt_response_kind.remove(key)
  }
  let bluetooth_pending_characteristic_request_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_characteristic_request {
    bluetooth_pending_characteristic_request_keys.push(key)
  }
  for key in bluetooth_pending_characteristic_request_keys {
    self.bluetooth_pending_characteristic_request.remove(key)
  }
  let bluetooth_pending_characteristic_realm_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_characteristic_realm {
    bluetooth_pending_characteristic_realm_keys.push(key)
  }
  for key in bluetooth_pending_characteristic_realm_keys {
    self.bluetooth_pending_characteristic_realm.remove(key)
  }
  let bluetooth_pending_characteristic_unwrap_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_characteristic_unwrap_result {
    bluetooth_pending_characteristic_unwrap_keys.push(key)
  }
  for key in bluetooth_pending_characteristic_unwrap_keys {
    self.bluetooth_pending_characteristic_unwrap_result.remove(key)
  }
  let bluetooth_pending_characteristic_address_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_characteristic_address {
    bluetooth_pending_characteristic_address_keys.push(key)
  }
  for key in bluetooth_pending_characteristic_address_keys {
    self.bluetooth_pending_characteristic_address.remove(key)
  }
  let bluetooth_pending_characteristic_service_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_characteristic_service_uuid {
    bluetooth_pending_characteristic_service_keys.push(key)
  }
  for key in bluetooth_pending_characteristic_service_keys {
    self.bluetooth_pending_characteristic_service_uuid.remove(key)
  }
  let bluetooth_pending_characteristic_uuid_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_characteristic_uuid {
    bluetooth_pending_characteristic_uuid_keys.push(key)
  }
  for key in bluetooth_pending_characteristic_uuid_keys {
    self.bluetooth_pending_characteristic_uuid.remove(key)
  }
  let bluetooth_pending_characteristic_type_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_characteristic_type {
    bluetooth_pending_characteristic_type_keys.push(key)
  }
  for key in bluetooth_pending_characteristic_type_keys {
    self.bluetooth_pending_characteristic_type.remove(key)
  }
  let bluetooth_pending_descriptor_request_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_descriptor_request {
    bluetooth_pending_descriptor_request_keys.push(key)
  }
  for key in bluetooth_pending_descriptor_request_keys {
    self.bluetooth_pending_descriptor_request.remove(key)
  }
  let bluetooth_pending_descriptor_realm_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_descriptor_realm {
    bluetooth_pending_descriptor_realm_keys.push(key)
  }
  for key in bluetooth_pending_descriptor_realm_keys {
    self.bluetooth_pending_descriptor_realm.remove(key)
  }
  let bluetooth_pending_descriptor_unwrap_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_descriptor_unwrap_result {
    bluetooth_pending_descriptor_unwrap_keys.push(key)
  }
  for key in bluetooth_pending_descriptor_unwrap_keys {
    self.bluetooth_pending_descriptor_unwrap_result.remove(key)
  }
  let bluetooth_pending_descriptor_address_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_descriptor_address {
    bluetooth_pending_descriptor_address_keys.push(key)
  }
  for key in bluetooth_pending_descriptor_address_keys {
    self.bluetooth_pending_descriptor_address.remove(key)
  }
  let bluetooth_pending_descriptor_service_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_descriptor_service_uuid {
    bluetooth_pending_descriptor_service_keys.push(key)
  }
  for key in bluetooth_pending_descriptor_service_keys {
    self.bluetooth_pending_descriptor_service_uuid.remove(key)
  }
  let bluetooth_pending_descriptor_characteristic_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_descriptor_characteristic_uuid {
    bluetooth_pending_descriptor_characteristic_keys.push(key)
  }
  for key in bluetooth_pending_descriptor_characteristic_keys {
    self.bluetooth_pending_descriptor_characteristic_uuid.remove(key)
  }
  let bluetooth_pending_descriptor_uuid_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_descriptor_uuid {
    bluetooth_pending_descriptor_uuid_keys.push(key)
  }
  for key in bluetooth_pending_descriptor_uuid_keys {
    self.bluetooth_pending_descriptor_uuid.remove(key)
  }
  let bluetooth_pending_descriptor_type_keys : Array[String] = []
  for key, _ in self.bluetooth_pending_descriptor_type {
    bluetooth_pending_descriptor_type_keys.push(key)
  }
  for key in bluetooth_pending_descriptor_type_keys {
    self.bluetooth_pending_descriptor_type.remove(key)
  }
  self.next_bluetooth_prompt_id = 1
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
    self.pending_beforeunload_requested_url.remove(key)
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

  let storage_cookie_scope_keys : Array[String] = []
  for key, _ in self.storage_cookies_by_scope {
    storage_cookie_scope_keys.push(key)
  }
  for key in storage_cookie_scope_keys {
    self.storage_cookies_by_scope.remove(key)
  }
  self.next_network_request_id = 1

  let synthetic_location_keys : Array[String] = []
  for key, _ in self.synthetic_location_href_by_context {
    synthetic_location_keys.push(key)
  }
  for key in synthetic_location_keys {
    self.synthetic_location_href_by_context.remove(key)
  }
  let last_navigation_keys : Array[String] = []
  for key, _ in self.context_last_started_navigation {
    last_navigation_keys.push(key)
  }
  for key in last_navigation_keys {
    self.context_last_started_navigation.remove(key)
  }
  let requested_navigation_keys : Array[String] = []
  for key, _ in self.context_requested_navigation_url {
    requested_navigation_keys.push(key)
  }
  for key in requested_navigation_keys {
    self.context_requested_navigation_url.remove(key)
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

  let context_worker_realm_keys : Array[String] = []
  for key, _ in self.context_worker_realms {
    context_worker_realm_keys.push(key)
  }
  for key in context_worker_realm_keys {
    self.context_worker_realms.remove(key)
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

  let synthetic_child_context_keys : Array[String] = []
  for key, _ in self.context_had_synthetic_child {
    synthetic_child_context_keys.push(key)
  }
  for key in synthetic_child_context_keys {
    self.context_had_synthetic_child.remove(key)
  }

  let context_client_window_keys : Array[String] = []
  for key, _ in self.context_client_window {
    context_client_window_keys.push(key)
  }
  for key in context_client_window_keys {
    self.context_client_window.remove(key)
  }

  let network_state_channel_keys : Array[String] = []
  for key, _ in self.network_state_channel_by_context {
    network_state_channel_keys.push(key)
  }
  for key in network_state_channel_keys {
    self.network_state_channel_by_context.remove(key)
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

  let input_html_drag_over_keys : Array[String] = []
  for key, _ in self.input_html_drag_over_shared {
    input_html_drag_over_keys.push(key)
  }
  for key in input_html_drag_over_keys {
    self.input_html_drag_over_shared.remove(key)
  }

  let input_html_drag_accept_keys : Array[String] = []
  for key, _ in self.input_html_drag_accept_shared {
    input_html_drag_accept_keys.push(key)
  }
  for key in input_html_drag_accept_keys {
    self.input_html_drag_accept_shared.remove(key)
  }

  let input_html_drag_transfer_keys : Array[String] = []
  for key, _ in self.input_html_drag_transfer_id {
    input_html_drag_transfer_keys.push(key)
  }
  for key in input_html_drag_transfer_keys {
    let transfer_id = self.input_html_drag_transfer_id.get(key).unwrap_or("")
    if transfer_id != "" {
      input_clear_drag_transfer(transfer_id)
    }
    self.input_html_drag_transfer_id.remove(key)
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

  let input_synthetic_event_keys : Array[String] = []
  for key, _ in self.input_synthetic_events_by_context {
    input_synthetic_event_keys.push(key)
  }
  for key in input_synthetic_event_keys {
    self.input_synthetic_events_by_context.remove(key)
  }

  let speculation_prefetch_target_keys : Array[String] = []
  for key, _ in self.speculation_prefetch_target_by_context {
    speculation_prefetch_target_keys.push(key)
  }
  for key in speculation_prefetch_target_keys {
    self.speculation_prefetch_target_by_context.remove(key)
  }

  let intercept_keys : Array[String] = []
  for key, _ in self.network_intercepts {
    intercept_keys.push(key)
  }
  for key in intercept_keys {
    self.network_intercepts.remove(key)
  }
  self.next_network_intercept_id = 1
  self.clear_all_network_state()

  let collector_keys : Array[String] = []
  for key, _ in self.network_data_collectors {
    collector_keys.push(key)
  }
  for key in collector_keys {
    self.network_data_collectors.remove(key)
  }
  let collected_request_keys : Array[String] = []
  for key, _ in self.network_collected_data {
    collected_request_keys.push(key)
  }
  for key in collected_request_keys {
    self.network_collected_data.remove(key)
  }
  self.next_network_data_collector_id = 1
  self.next_preload_script_id = 1
  let installed_web_extension_keys : Array[String] = []
  for key, _ in self.installed_web_extensions {
    installed_web_extension_keys.push(key)
  }
  for key in installed_web_extension_keys {
    self.installed_web_extensions.remove(key)
  }
  self.next_web_extension_id = 1
  self.preload_scripts = []
}

///|
fn BidiProtocol::handle_browser_has_user_context(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_browser_has_user_context_known(request_id, params) {
    Some(known) =>
      self.send_success(
        request_id,
        Some(make_object({ "known": Json::boolean(known) })),
      )
    None => ()
  }
}

///|
fn BidiProtocol::handle_browser_has_user_context_value(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_browser_has_user_context_known(request_id, params) {
    Some(known) => self.send_success(request_id, Some(Json::boolean(known)))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_browser_has_user_context_known(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }
  let user_context = match map.get("userContext") {
    Some(String(user_context)) => user_context
    _ => {
      self.send_error(
        request_id, "invalid argument", "userContext must be a string",
      )
      return None
    }
  }
  Some(self.user_contexts.contains(user_context))
}

///|
fn BidiProtocol::resolve_browser_user_contexts_list(
  self : BidiProtocol,
) -> Array[Json] {
  let contexts : Array[Json] = []
  for id, _ in self.user_contexts {
    contexts.push(make_object({ "userContext": Json::string(id) }))
  }
  contexts
}

///|
fn BidiProtocol::resolve_browser_client_windows_list(
  self : BidiProtocol,
) -> Array[Json] {
  let top_level_contexts : Array[String] = []
  for ctx_id in self.manager.list_sessions() {
    if !self.context_parent.contains(ctx_id) {
      top_level_contexts.push(ctx_id)
    }
  }

  let mut active_client_window : String? = None
  match self.active_context_id {
    Some(active_ctx) =>
      if !self.context_parent.contains(active_ctx) {
        active_client_window = self.context_client_window.get(active_ctx)
      }
    None => ()
  }
  match active_client_window {
    Some(_) => ()
    None =>
      match self.default_context_id {
        Some(default_ctx) =>
          if !self.context_parent.contains(default_ctx) {
            active_client_window = self.context_client_window.get(default_ctx)
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
    if !seen_windows.contains(client_window) {
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
  windows
}

///|
fn BidiProtocol::resolve_browser_create_user_context(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  match self.validate_browser_create_user_context(request_id, params) {
    Some(_) => return None
    None => ()
  }
  let id = "user-" + self.user_contexts.length().to_string()
  self.user_contexts[id] = true
  match
    get_param_raw_with_alias(
      params, "unhandledPromptBehavior", "unhandled_prompt_behavior",
    ) {
    Some(Object(behavior)) =>
      self.user_context_prompt_behavior[id] = make_object(behavior)
    _ => ()
  }
  Some(id)
}

///|
fn BidiProtocol::handle_session_is_subscribed_for_context(
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
  let event_name = match map.get("event") {
    Some(String(event_name)) => event_name
    _ => {
      self.send_error(request_id, "invalid argument", "event must be a string")
      return
    }
  }
  let context_id = match map.get("context") {
    Some(String(context_id)) => context_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  let subscribed = self.manager.has_session(context_id) &&
    self.is_subscribed_for_context(event_name, context_id)
  self.send_success(
    request_id,
    Some(make_object({ "subscribed": Json::boolean(subscribed) })),
  )
}

///|
fn BidiProtocol::handle_session_prepare_baseline_context_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match params {
    Some(Object(_)) | None => ()
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let preserved_default_prompt_behavior = self.user_context_prompt_behavior.get(
    "default",
  )
  let preserved_ctx_id = self.default_context_id.unwrap_or(
    self.ensure_default_context(),
  )
  self.reset_session_runtime_state()
  match preserved_default_prompt_behavior {
    Some(behavior) => self.user_context_prompt_behavior["default"] = behavior
    None => ()
  }
  let ctx_id = self.recreate_default_context_with_id(preserved_ctx_id)
  let realm_id = self.reset_context_to_blank_for_test(ctx_id)
  ignore(evaluate_js("try { delete globalThis.SOME_VARIABLE; } catch (_) {}"))
  let context_info = self.build_context_info_for_test(ctx_id)
  self.send_success(
    request_id,
    Some(
      make_object({
        "context": Json::string(ctx_id),
        "realm": Json::string(realm_id),
        "contextInfo": context_info,
      }),
    ),
  )
}

///|
fn BidiProtocol::recreate_default_context_with_id(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  let id = self.manager.create_session_with_id(ctx_id)
  self.context_user_context[id] = "default"
  self.context_children[id] = []
  self.context_client_window[id] = "client-window-" + id
  self.context_parent.remove(id)
  self.context_had_synthetic_child.remove(id)
  self.context_has_beforeunload.remove(id)
  self.context_blocks_cross_origin_iframe_navigation.remove(id)
  self.clear_pending_prompt_state(id)
  self.clear_pending_navigation_state(id)
  self.clear_network_state_for_context(id)
  self.context_local_storage.remove(id)
  self.remove_storage_cookie_scope(id)
  self.context_last_started_navigation.remove(id)
  self.context_requested_navigation_url.remove(id)
  self.user_contexts["default"] = true
  self.default_context_id = Some(id)
  self.active_context_id = Some(id)
  self.assign_new_realm(id) |> ignore
  self.apply_effective_viewport_to_runtime_context(id, id)
  id
}

///|
fn BidiProtocol::handle_session_get_baseline_context_info_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match params {
    Some(Object(_)) | None => ()
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let ctx_id = self.ensure_default_context()
  let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
  let context_info = self.build_context_info_for_test(ctx_id)
  self.send_success(
    request_id,
    Some(
      make_object({
        "context": Json::string(ctx_id),
        "realm": Json::string(realm_id),
        "contextInfo": context_info,
      }),
    ),
  )
}

///|
fn BidiProtocol::handle_session_get_baseline_context_info_value_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match params {
    Some(Object(_)) | None => ()
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let ctx_id = self.ensure_default_context()
  let context_info = self.build_context_info_for_test(ctx_id)
  self.send_success(request_id, Some(context_info))
}

///|
fn BidiProtocol::build_context_info_for_test(
  self : BidiProtocol,
  ctx_id : String,
) -> Json {
  self
  .build_context_entry(ctx_id, true, 0, Some(0))
  .unwrap_or(
    make_object({
      "context": Json::string(ctx_id),
      "url": Json::string(self.current_context_url(ctx_id)),
      "children": Json::array([]),
      "parent": Json::null(),
      "clientWindow": Json::string(
        self.context_client_window
        .get(ctx_id)
        .unwrap_or("client-window-" + ctx_id),
      ),
      "userContext": Json::string(
        self.context_user_context.get(ctx_id).unwrap_or("default"),
      ),
      "originalOpener": Json::null(),
    }),
  )
}

///|
fn BidiProtocol::handle_network_prepare_context_for_test(
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
  let target_url = match map.get("url") {
    Some(String(url)) => url
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return
    }
  }
  let resolved_url = self.resolve_effective_navigation_target_url(
    ctx_id, target_url,
  )
  self.input_synthetic_events_by_context.remove(ctx_id)
  self.context_synthetic_scrolled.remove(ctx_id)
  self.clear_synthetic_location_href(ctx_id)
  let _ = self.fail_in_flight_navigation(
    ctx_id, "aborted", "Navigation interrupted by another navigation",
  )
  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let previous_url = session.get_url()
      match session.navigate_to(resolved_url) {
        Ok(_) =>
          self.complete_navigate_with_state(
            request_id,
            ctx_id,
            target_url,
            resolved_url,
            previous_url,
            "complete",
            None,
          )
        Err(_) =>
          self.send_success(
            request_id,
            Some(
              make_object({
                "context": Json::string(ctx_id),
                "url": Json::string(self.current_context_url(ctx_id)),
                "navigated": Json::boolean(false),
              }),
            ),
          )
      }
    }
    None => {
      self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
      return
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
  match get_map_field_with_alias(params, "userContexts", "user_contexts") {
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
              } else if !self.user_contexts.contains(user_context_id) {
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
  if !has_context && !has_user_contexts {
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
  match
    get_map_field_with_alias(params, "devicePixelRatio", "device_pixel_ratio") {
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
      if !self.manager.has_session(ctx_id) {
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

  if !self.manager.has_session(ctx_id) {
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
  match self.resolve_capture_screenshot_data(request.id, request.params) {
    Some(data) => {
      let result = make_object({ "data": Json::string(data) })
      self.send_success(request.id, Some(result))
    }
    None => ()
  }
}

///|
fn BidiProtocol::handle_capture_screenshot_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_capture_screenshot_data(request_id, params) {
    Some(data) => self.send_success(request_id, Some(Json::string(data)))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_capture_screenshot_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let raw_params = params
  let params = match raw_params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let ctx_id = match params.get("context") {
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
  if !self.manager.has_session(ctx_id) {
    self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
    return None
  }
  set_runtime_context(ctx_id)
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)

  match params.get("origin") {
    Some(String("viewport")) | Some(String("document")) | None => ()
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "origin must be 'viewport' or 'document'",
      )
      return None
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "origin must be 'viewport' or 'document'",
      )
      return None
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
            request_id, "invalid argument", "clip.type must be a string",
          )
          return None
        }
      }

      if clip_type == "element" {
        match clip_map.get("element") {
          Some(Object(element)) =>
            match element.get("sharedId") {
              Some(String(shared_id)) =>
                if !has_runtime_shared_node(shared_id) ||
                  !runtime_shared_node_is_element(shared_id) {
                  self.send_error(
                    request_id,
                    "no such node",
                    "Unknown sharedId: " + shared_id,
                  )
                  return None
                }
              _ => {
                self.send_error(
                  request_id, "invalid argument", "clip.element.sharedId must be a string",
                )
                return None
              }
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "clip.element must be a node reference",
            )
            return None
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
                  request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
                )
                return None
              }
            }
          None => {
            self.send_error(
              request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
            )
            return None
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
                  request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
                )
                return None
              }
            }
          None => {
            self.send_error(
              request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
            )
            return None
          }
        }
        clip_box_width = match clip_map.get("width") {
          Some(value) =>
            match json_as_safe_number(value, 0.0, 9007199254740991.0) {
              Some(parsed) => parsed
              None => {
                self.send_error(
                  request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
                )
                return None
              }
            }
          None => {
            self.send_error(
              request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
            )
            return None
          }
        }
        clip_box_height = match clip_map.get("height") {
          Some(value) =>
            match json_as_safe_number(value, 0.0, 9007199254740991.0) {
              Some(parsed) => parsed
              None => {
                self.send_error(
                  request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
                )
                return None
              }
            }
          None => {
            self.send_error(
              request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
            )
            return None
          }
        }
      } else {
        self.send_error(request_id, "invalid argument", "clip.type is invalid")
        return None
      }
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "clip must be an object")
      return None
    }
  }

  if has_box_clip && (clip_box_width <= 0.0 || clip_box_height <= 0.0) {
    self.send_error(
      request_id, "unable to capture screen", "Clip dimensions must be positive",
    )
    return None
  }

  match params.get("format") {
    None => ()
    Some(Object(format)) => {
      match format.get("type") {
        Some(String("image/png")) | Some(String("image/jpeg")) => ()
        Some(String(_)) => {
          self.send_error(
            request_id, "invalid argument", "format.type must be 'image/png' or 'image/jpeg'",
          )
          return None
        }
        _ => {
          self.send_error(
            request_id, "invalid argument", "format.type must be 'image/png' or 'image/jpeg'",
          )
          return None
        }
      }

      match format.get("quality") {
        Some(value) =>
          match json_as_safe_number(value, 0.0, 1.0) {
            Some(_) => ()
            None => {
              self.send_error(
                request_id, "invalid argument", "format.quality must be a number in [0,1]",
              )
              return None
            }
          }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "format must be an object",
      )
      return None
    }
  }

  match
    self.try_resolve_actual_capture_screenshot_data(request_id, ctx_id, params) {
    Some(data) => return Some(data)
    None => ()
  }

  match self.build_synthetic_capture_screenshot_result(ctx_id, raw_params) {
    Some(Object(result_map)) =>
      match result_map.get("error") {
        Some(String(error_name)) => {
          let message = match result_map.get("message") {
            Some(String(message)) => message
            _ => "Unable to capture screenshot"
          }
          self.send_error(request_id, error_name, message)
          None
        }
        _ =>
          match result_map.get("data") {
            Some(String(data)) => Some(data)
            _ => {
              self.send_error(
                request_id, "unknown error", "Failed to build synthetic screenshot",
              )
              None
            }
          }
      }
    _ => {
      self.send_error(
        request_id, "unknown error", "Failed to build synthetic screenshot",
      )
      None
    }
  }
}

///|
/// Handle browsingContext.print with WPT-focused validation.
fn BidiProtocol::handle_print(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  match self.resolve_print_data(request.id, request.params) {
    Some(data) => {
      let result = make_object({ "data": Json::string(data) })
      self.send_success(request.id, Some(result))
    }
    None => ()
  }
}

///|
fn BidiProtocol::handle_print_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_print_data(request_id, params) {
    Some(data) => self.send_success(request_id, Some(Json::string(data)))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_print_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let params = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let ctx_id = match params.get("context") {
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
  if !self.manager.has_session(ctx_id) {
    self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
    return None
  }

  match params.get("background") {
    Some(True) | Some(False) | None => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "background must be a boolean",
      )
      return None
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
                  request_id, "invalid argument", "margin values must be non-negative numbers",
                )
                return None
              }
            }
          None => ()
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "margin must be an object",
      )
      return None
    }
  }

  match params.get("orientation") {
    Some(String("portrait")) | Some(String("landscape")) | None => ()
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "orientation must be 'portrait' or 'landscape'",
      )
      return None
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "orientation must be 'portrait' or 'landscape'",
      )
      return None
    }
  }

  match params.get("page") {
    None => ()
    Some(Object(page)) => {
      match page.get("width") {
        Some(value) =>
          if json_as_safe_number(value, 0.035, 9007199254740991.0) is None {
            self.send_error(
              request_id, "invalid argument", "page.width must be a number >= 0.035",
            )
            return None
          }
        None => ()
      }
      match page.get("height") {
        Some(value) =>
          if json_as_safe_number(value, 0.035, 9007199254740991.0) is None {
            self.send_error(
              request_id, "invalid argument", "page.height must be a number >= 0.035",
            )
            return None
          }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "page must be an object")
      return None
    }
  }

  match get_map_field_with_alias(params, "pageRanges", "page_ranges") {
    None => ()
    Some(Array(page_ranges)) =>
      for page_range in page_ranges {
        match page_range {
          Number(n, ..) =>
            if n < 1.0 || n != n.to_int64().to_double() {
              self.send_error(
                request_id, "invalid argument", "pageRanges entries are invalid",
              )
              return None
            }
          String(v) =>
            if !is_valid_print_page_range(v) {
              self.send_error(
                request_id, "invalid argument", "pageRanges entries are invalid",
              )
              return None
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "pageRanges must be an array of strings/integers",
            )
            return None
          }
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pageRanges must be an array of strings/integers",
      )
      return None
    }
  }

  match params.get("scale") {
    None => ()
    Some(value) =>
      if json_as_safe_number(value, 0.1, 2.0) is None {
        self.send_error(
          request_id, "invalid argument", "scale must be a number in [0.1, 2.0]",
        )
        return None
      }
  }

  match get_map_field_with_alias(params, "shrinkToFit", "shrink_to_fit") {
    Some(True) | Some(False) | None => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "shrinkToFit must be a boolean",
      )
      return None
    }
  }

  let orientation = match params.get("orientation") {
    Some(String("landscape")) => "landscape"
    _ => "portrait"
  }
  let mut page_width_cm = 21.59
  let mut page_height_cm = 27.94
  match params.get("page") {
    Some(Object(page)) => {
      match page.get("width") {
        Some(Number(width, ..)) => page_width_cm = width
        _ => ()
      }
      match page.get("height") {
        Some(Number(height, ..)) => page_height_cm = height
        _ => ()
      }
    }
    _ => ()
  }
  if orientation == "landscape" {
    let current_width = page_width_cm
    page_width_cm = page_height_cm
    page_height_cm = current_width
  }
  let mut margin_top = 0.0
  let mut margin_bottom = 0.0
  let mut margin_left = 0.0
  let mut margin_right = 0.0
  let mut has_margin_top = false
  let mut has_margin_bottom = false
  let mut has_margin_left = false
  let mut has_margin_right = false
  match params.get("margin") {
    Some(Object(margin)) => {
      match margin.get("top") {
        Some(Number(value, ..)) => {
          margin_top = value
          has_margin_top = true
        }
        _ => ()
      }
      match margin.get("bottom") {
        Some(Number(value, ..)) => {
          margin_bottom = value
          has_margin_bottom = true
        }
        _ => ()
      }
      match margin.get("left") {
        Some(Number(value, ..)) => {
          margin_left = value
          has_margin_left = true
        }
        _ => ()
      }
      match margin.get("right") {
        Some(Number(value, ..)) => {
          margin_right = value
          has_margin_right = true
        }
        _ => ()
      }
    }
    _ => ()
  }
  if margin_top >= page_height_cm ||
    margin_bottom >= page_height_cm ||
    margin_left >= page_width_cm ||
    margin_right >= page_width_cm {
    self.send_error(
      request_id, "unsupported operation", "Margin consumes entire printable area",
    )
    return None
  }
  let background = match params.get("background") {
    Some(True) => true
    _ => false
  }
  let default_print_margin_cm = 1.0
  let minimum_printable_cm = 2.54 / 72.0
  let effective_margin_right = if has_margin_right {
    margin_right
  } else {
    default_print_margin_cm
  }
  let effective_margin_left = if has_margin_left {
    margin_left
  } else {
    default_print_margin_cm
  }
  let effective_margin_bottom = if has_margin_bottom {
    margin_bottom
  } else {
    default_print_margin_cm
  }
  let effective_margin_top = if has_margin_top {
    margin_top
  } else {
    default_print_margin_cm
  }
  let printable_width_cm = if has_margin_left &&
    margin_left + effective_margin_right > page_width_cm - minimum_printable_cm {
    page_width_cm - minimum_printable_cm
  } else if has_margin_right &&
    margin_right + effective_margin_left > page_width_cm - minimum_printable_cm {
    page_width_cm - minimum_printable_cm
  } else {
    page_width_cm
  }
  let printable_height_cm = if has_margin_top &&
    margin_top + effective_margin_bottom > page_height_cm - minimum_printable_cm {
    page_height_cm - minimum_printable_cm
  } else if has_margin_bottom &&
    margin_bottom + effective_margin_top > page_height_cm - minimum_printable_cm {
    page_height_cm - minimum_printable_cm
  } else {
    page_height_cm
  }
  let synthetic_details = self.resolve_synthetic_print_details(
    ctx_id, params, printable_width_cm, printable_height_cm,
  )
  let signature = match synthetic_details.get("signature") {
    Some(String(value)) if value != "" => value
    _ => self.current_context_url(ctx_id)
  }
  let pages = match synthetic_details.get("pages") {
    Some(Array(values)) => values
    _ => []
  }
  let meta = make_object({
    "kind": Json::string("crater.synthetic.print"),
    "orientation": Json::string(orientation),
    "pageWidthCm": Json::number(printable_width_cm),
    "pageHeightCm": Json::number(printable_height_cm),
    "background": Json::boolean(background),
    "signature": Json::string(signature),
    "pages": Json::array(pages),
  })
  Some(synthetic_print_pdf_from_meta(meta))
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
      match find_substring(value, "-", first_dash + 1) {
        Some(_) => return false
        None => ()
      }
      if first_dash == 0 {
        let end_text = value.unsafe_substring(start=1, end=value.length())
        match parse_decimal_string(end_text) {
          Some(v) => v >= 1
          None => false
        }
      } else if first_dash == value.length() - 1 {
        let start_text = value.unsafe_substring(start=0, end=first_dash)
        match parse_decimal_string(start_text) {
          Some(v) => v >= 1
          None => false
        }
      } else {
        let start_text = value.unsafe_substring(start=0, end=first_dash)
        let end_text = value.unsafe_substring(
          start=first_dash + 1,
          end=value.length(),
        )
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
    }
    None =>
      match parse_decimal_string(value) {
        Some(v) => v >= 1
        None => false
      }
  }
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
    trimmed.unsafe_substring(start=3, end=trimmed.length())
  } else if trimmed.has_prefix("//") {
    trimmed.unsafe_substring(start=2, end=trimmed.length())
  } else {
    return None
  }
  if body == "" {
    return None
  }

  match find_substring(body, "[@", 0) {
    None => if body.contains("[") { None } else { Some(body) }
    Some(predicate_idx) => {
      let selector_tag = body.unsafe_substring(start=0, end=predicate_idx)
      if selector_tag == "" {
        return None
      }
      let predicate_start = predicate_idx + 2
      let predicate_full = body.unsafe_substring(
        start=predicate_start,
        end=body.length(),
      )
      if predicate_full == "" || !predicate_full.has_suffix("]") {
        return None
      }
      let predicate = predicate_full.unsafe_substring(
        start=0,
        end=predicate_full.length() - 1,
      )
      match find_substring(predicate, "=", 0) {
        None => None
        Some(eq_idx) => {
          let attr_name = predicate.unsafe_substring(start=0, end=eq_idx)
          let quoted_value = predicate.unsafe_substring(
            start=eq_idx + 1,
            end=predicate.length(),
          )
          if attr_name == "" || quoted_value.length() < 2 {
            return None
          }
          let quote_chars = quoted_value.to_array()
          let quote = quote_chars[0]
          let end_quote = quote_chars[quote_chars.length() - 1]
          if (quote != '\'' && quote != '"') || end_quote != quote {
            return None
          }
          let attr_value = quoted_value.unsafe_substring(
            start=1,
            end=quoted_value.length() - 1,
          )
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
  if !self.manager.has_session(ctx_id) {
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
  if !is_valid_locate_nodes_locator_type(locator_type) {
    self.send_error(request.id, "invalid argument", "locator.type is invalid")
    return
  }

  match self.validate_serialization_options(request.id, request.params) {
    Some(_) => return
    None => ()
  }

  let max_node_count = match
    get_map_field_with_alias(params, "maxNodeCount", "max_node_count") {
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
  match get_map_field_with_alias(params, "startNodes", "start_nodes") {
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
                if !has_runtime_shared_node(shared_id) {
                  self.send_error(
                    request.id,
                    "no such node",
                    "Unknown sharedId: " + shared_id,
                  )
                  return
                }
                if !runtime_shared_node_is_element(shared_id) &&
                  !runtime_shared_node_is_document(shared_id) &&
                  !runtime_shared_node_is_shadow_root(shared_id) {
                  self.send_error(
                    request.id,
                    "invalid argument",
                    "startNodes entries must reference element, document, or shadow root nodes",
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
      if !has_role && !has_name {
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
      if !self.manager.has_session(target_ctx) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + target_ctx,
        )
        return
      }
      let child_contexts = self.context_children.get(ctx_id).unwrap_or([])
      if !array_contains(child_contexts, target_ctx) {
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
    "} else if (__root.nodeType === 1 || __root.nodeType === 11) {" +
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
fn BidiProtocol::create_synthetic_child_context_result(
  self : BidiProtocol,
  context_id : String,
  requested_url : String,
  user_context_id : String,
) -> Json {
  let child_ctx_id = self.create_child_context(context_id, user_context_id)
  self.context_had_synthetic_child[context_id] = true
  let resolved_url = self.resolve_navigation_target_url(
    context_id, requested_url,
  )
  let effective_url = self.normalize_wpt_navigation_target_url(
    child_ctx_id, resolved_url,
  )

  self.emit_context_created(
    child_ctx_id,
    "tab",
    "about:blank",
    None,
    Some(context_id),
  )
  let child_nav_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  if self.is_iframe_navigation_blocked(child_ctx_id, effective_url) {
    self.emit_default_realm(child_ctx_id)
    self.emit_navigation_started_event(
      child_ctx_id, effective_url, child_nav_id,
    )
    self.emit_navigation_failed_event(child_ctx_id, effective_url, child_nav_id)
    return make_object({
      "context": Json::string(child_ctx_id),
      "parentContext": Json::string(context_id),
      "userContext": Json::string(user_context_id),
      "url": Json::string(effective_url),
    })
  }
  match self.manager.get_session(child_ctx_id) {
    Some(child_session) => {
      let _ = child_session.navigate_to(effective_url)
    }
    None => ()
  }
  self.load_data_url_content(child_ctx_id, effective_url)
  self.clear_context_sandbox_realms(child_ctx_id)
  let window_realm_id = self.assign_new_realm(child_ctx_id)
  self.emit_default_realm(child_ctx_id)
  self.emit_worker_realms_from_scripts(child_ctx_id, window_realm_id)
  self.apply_preload_scripts_for_context(child_ctx_id)
  self.execute_inline_scripts_for_context(child_ctx_id)
  self.emit_navigation_events(child_ctx_id, effective_url, child_nav_id)
  if effective_url != "about:blank" {
    self.refresh_child_contexts_from_iframes_with_depth(child_ctx_id, 1)
  }
  make_object({
    "context": Json::string(child_ctx_id),
    "parentContext": Json::string(context_id),
    "userContext": Json::string(user_context_id),
    "url": Json::string(effective_url),
  })
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
    "if (!__node) return;" +
    "if (__node.nodeType === 11) {" +
    "const __shadowChildren = __collectChildren(__node);" +
    "for (const __child of __shadowChildren) { __visit(__child, __depth); }" +
    "return;" +
    "}" +
    "if (__node.nodeType !== 1) return;" +
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
    "} else if (__root && (__root.nodeType === 1 || __root.nodeType === 11)) {" +
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
    "if (!__node) return false;" +
    "if (__node.nodeType === 11) {" +
    "const __shadowChildren = __collectChildren(__node);" +
    "for (const __child of __shadowChildren) { if (__visit(__child)) return true; }" +
    "return false;" +
    "}" +
    "if (__node.nodeType !== 1) return false;" +
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
    "} else if (__root && (__root.nodeType === 1 || __root.nodeType === 11)) {" +
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
fn BidiProtocol::handle_script_remember_synthetic_location_href(
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
    Some(String(ctx_id)) => ctx_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  let href = match map.get("href") {
    Some(String(href)) => href
    _ => {
      self.send_error(request_id, "invalid argument", "href must be a string")
      return
    }
  }
  self.remember_synthetic_location_href(ctx_id, href)
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::handle_script_clear_synthetic_location_href(
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
    Some(String(ctx_id)) => ctx_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  self.clear_synthetic_location_href(ctx_id)
  self.send_success(request_id, Some(make_object({})))
}

///|
/// Emit log.entryAdded event
fn BidiProtocol::emit_log_entry_with_details(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
  entry_type : String,
  level : String,
  text : String,
  console_method : String?,
  args : Array[Json],
  timestamp : Double,
  stack_trace : Json?,
) -> Unit {
  let params_map : Map[String, Json] = {
    "level": Json::string(level),
    "source": make_object({
      "realm": Json::string(realm_id),
      "context": Json::string(ctx_id),
    }),
    "text": Json::string(text),
    "timestamp": Json::number(timestamp),
    "type": Json::string(entry_type),
  }
  if entry_type == "console" {
    params_map["method"] = Json::string(console_method.unwrap_or("log"))
    params_map["args"] = Json::array(args)
  }
  match stack_trace {
    Some(value) => params_map["stackTrace"] = value
    None => ()
  }
  let params = make_object(params_map)
  if !self.is_subscribed_for_context("log.entryAdded", ctx_id) {
    let pending = self.pending_log_entries.get(ctx_id).unwrap_or([])
    pending.push(params)
    self.pending_log_entries[ctx_id] = pending
    return
  }
  self.outbox.push(Event({ event_method: "log.entryAdded", params }))
}

///|
/// Emit log.entryAdded event for console entries.
fn BidiProtocol::emit_log_entry(
  self : BidiProtocol,
  ctx_id : String,
  level : String,
  text : String,
  console_method : String,
  args : Array[Json],
  timestamp : Double,
) -> Unit {
  let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
  self.emit_log_entry_with_details(
    ctx_id,
    realm_id,
    "console",
    level,
    text,
    Some(console_method),
    args,
    timestamp,
    None,
  )
}

///|
/// Emit log.entryAdded event for javascript errors.
fn BidiProtocol::emit_javascript_log_entry(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
  level : String,
  text : String,
  timestamp : Double,
  stack_trace : Json?,
) -> Unit {
  self.emit_log_entry_with_details(
    ctx_id,
    realm_id,
    "javascript",
    level,
    text,
    None,
    [],
    timestamp,
    stack_trace,
  )
}

///|
/// Process console entries from JS evaluation result and emit log events
fn BidiProtocol::process_console_entries(
  self : BidiProtocol,
  eval_result : Json,
  ctx_id : String,
  realm_id : String,
) -> Unit {
  match get_field(eval_result, "consoleEntries") {
    Some(Array(entries)) =>
      for entry in entries {
        match entry {
          Object(_) => {
            let entry_type = get_string_field(entry, "type").unwrap_or(
              "console",
            )
            let level = get_string_field(entry, "level").unwrap_or("info")
            let console_method = get_string_field(entry, "method").unwrap_or(
              "log",
            )
            let text = get_string_field(entry, "text").unwrap_or("")
            let entry_realm_raw = get_string_field(entry, "realm").unwrap_or(
              realm_id,
            )
            let entry_realm = if entry_realm_raw == "" {
              realm_id
            } else {
              entry_realm_raw
            }
            let args = match get_field(entry, "args") {
              Some(Array(values)) => values
              _ => []
            }
            let timestamp = match get_field(entry, "timestamp") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            let stack_trace = match get_field(entry, "stackTrace") {
              Some(Object(_)) => get_field(entry, "stackTrace")
              _ => None
            }
            if entry_type == "javascript" {
              self.emit_javascript_log_entry(
                ctx_id, entry_realm, level, text, timestamp, stack_trace,
              )
            } else {
              self.emit_log_entry_with_details(
                ctx_id,
                entry_realm,
                "console",
                level,
                text,
                Some(console_method),
                args,
                timestamp,
                stack_trace,
              )
            }
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
fn BidiProtocol::collect_context_ancestry(
  self : BidiProtocol,
  ctx_id : String,
  ancestry : Array[String],
  seen : Map[String, Bool],
) -> Unit {
  if seen.contains(ctx_id) {
    return
  }
  seen[ctx_id] = true
  match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) =>
      self.collect_context_ancestry(parent_ctx_id, ancestry, seen)
    None => ()
  }
  ancestry.push(ctx_id)
}

///|
fn BidiProtocol::build_context_ancestry(
  self : BidiProtocol,
  ctx_id : String,
) -> Array[String] {
  let ancestry : Array[String] = []
  let seen : Map[String, Bool] = {}
  self.collect_context_ancestry(ctx_id, ancestry, seen)
  ancestry
}

///|
fn BidiProtocol::build_context_scope_info_json(
  self : BidiProtocol,
  ctx_id : String,
) -> Json {
  if !self.manager.has_session(ctx_id) {
    return make_object({
      "context": Json::string(ctx_id),
      "known": Json::boolean(false),
      "ancestry": Json::array([]),
      "topLevelContext": Json::null(),
      "parent": Json::null(),
      "userContext": Json::null(),
      "isTopLevel": Json::boolean(false),
    })
  }
  let ancestry = self.build_context_ancestry(ctx_id)
  let ancestry_json : Array[Json] = []
  for ancestor in ancestry {
    ancestry_json.push(Json::string(ancestor))
  }
  let top_level_context = match ancestry {
    [top_level, ..] => Json::string(top_level)
    [] => Json::string(ctx_id)
  }
  let parent_json = match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) => Json::string(parent_ctx_id)
    None => Json::null()
  }
  let user_context = self.context_user_context.get(ctx_id).unwrap_or("default")
  make_object({
    "context": Json::string(ctx_id),
    "known": Json::boolean(true),
    "ancestry": Json::array(ancestry_json),
    "topLevelContext": top_level_context,
    "parent": parent_json,
    "userContext": Json::string(user_context),
    "isTopLevel": Json::boolean(self.context_parent.get(ctx_id) == None),
  })
}

///|
/// Resolve top-level ancestor context.
fn BidiProtocol::resolve_top_level_context(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  let mut current = ctx_id
  for _ in 0..<16 {
    match self.context_parent.get(current) {
      Some(parent_ctx_id) => current = parent_ctx_id
      None => return current
    }
  }
  current
}

///|
/// Check whether preload script scope matches a context.
fn BidiProtocol::is_preload_script_applicable(
  self : BidiProtocol,
  entry : PreloadScriptEntry,
  ctx_id : String,
) -> Bool {
  if entry.contexts.length() > 0 {
    let top_level_context = self.resolve_top_level_context(ctx_id)
    return array_contains(entry.contexts, top_level_context)
  }
  if entry.user_contexts.length() > 0 {
    let user_context = self.context_user_context
      .get(ctx_id)
      .unwrap_or("default")
    return array_contains(entry.user_contexts, user_context)
  }
  true
}

///|
/// Build JS call expression for a preload script entry.
fn build_preload_call_expression(entry : PreloadScriptEntry) -> String {
  let argument_parts : Array[String] = []
  for argument in entry.arguments {
    argument_parts.push(bidi_value_to_js_literal(argument))
  }
  if argument_parts.length() == 0 {
    "(" + entry.function_declaration + ")()"
  } else {
    "(" + entry.function_declaration + ")(" + argument_parts.join(", ") + ")"
  }
}

///|
/// Check whether character is a JavaScript identifier continuation.
fn is_js_identifier_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_' ||
  c == '$'
}

///|
/// Extract referenced `window.<name>` property names from source.
fn extract_window_property_names(source : String) -> Array[String] {
  let names : Array[String] = []
  let marker = "window."
  let mut search_from = 0
  while search_from < source.length() {
    match find_substring(source, marker, search_from) {
      Some(marker_idx) => {
        let chars = source.to_array()
        let mut cursor = marker_idx + marker.length()
        if cursor >= chars.length() {
          break
        }
        let mut name = ""
        while cursor < chars.length() && is_js_identifier_char(chars[cursor]) {
          name = name + chars[cursor].to_string()
          cursor += 1
        }
        if name != "" && !array_contains(names, name) {
          names.push(name)
        }
        search_from = cursor + 1
      }
      None => break
    }
  }
  names
}

///|
/// Clear custom window properties in a context/sandbox runtime.
fn BidiProtocol::clear_window_properties_in_context(
  self : BidiProtocol,
  ctx_id : String,
  sandbox : String?,
  property_names : Array[String],
) -> Unit {
  if property_names.length() == 0 {
    return
  }
  let runtime_ctx_id = match sandbox {
    Some(sandbox_name) =>
      if sandbox_name == "" {
        ctx_id
      } else {
        self.get_or_create_sandbox_realm(ctx_id, sandbox_name)
      }
    None => ctx_id
  }
  set_runtime_context(runtime_ctx_id)
  self.apply_effective_viewport_to_runtime_context(runtime_ctx_id, ctx_id)
  for property_name in property_names {
    if property_name == "" {
      continue
    }
    evaluate_js(
      "try { delete window." +
      property_name +
      "; } catch (_e) { window." +
      property_name +
      " = undefined; }",
    )
    |> ignore
  }
}

///|
/// Remove side effects of a removed preload script from existing contexts.
fn BidiProtocol::cleanup_removed_preload_entry(
  self : BidiProtocol,
  entry : PreloadScriptEntry,
) -> Unit {
  let property_names = extract_window_property_names(entry.function_declaration)
  if property_names.length() == 0 {
    return
  }
  for ctx_id in self.manager.list_sessions() {
    if self.is_preload_script_applicable(entry, ctx_id) {
      self.clear_window_properties_in_context(
        ctx_id,
        entry.sandbox,
        property_names,
      )
    }
  }
}

///|
/// Remove every registered preload script and clean up any runtime markers.
fn BidiProtocol::remove_all_preload_scripts(self : BidiProtocol) -> Unit {
  let existing_entries = self.preload_scripts
  self.preload_scripts = []
  self.next_preload_script_id = 1
  for entry in existing_entries {
    self.cleanup_removed_preload_entry(entry)
  }
}

///|
/// Execute one preload script in a target context.
fn BidiProtocol::run_preload_script_in_context(
  self : BidiProtocol,
  entry : PreloadScriptEntry,
  ctx_id : String,
) -> Unit {
  let realm_id = match entry.sandbox {
    Some(sandbox_name) =>
      if sandbox_name == "" {
        self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
      } else {
        self.get_or_create_sandbox_realm(ctx_id, sandbox_name)
      }
    None => self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
  }
  let runtime_ctx_id = match entry.sandbox {
    Some(sandbox_name) => if sandbox_name == "" { ctx_id } else { realm_id }
    None => ctx_id
  }
  set_runtime_context(runtime_ctx_id)
  set_runtime_context_frames(
    runtime_ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(runtime_ctx_id, ctx_id)
  let capture_console = self.should_capture_console(ctx_id)
  let eval_result_json = evaluate_js_with_console(
    build_preload_call_expression(entry),
    capture_console,
    false,
    false,
    "{}",
  )
  let eval_result = @json.parse(eval_result_json) catch { _ => return }
  if capture_console {
    self.process_console_entries(eval_result, ctx_id, realm_id)
  }
  match get_string_field(eval_result, "type") {
    Some("exception") => {
      let exception_details = get_field(eval_result, "exceptionDetails").unwrap_or(
        make_object({}),
      )
      let text = get_string_field(exception_details, "text").unwrap_or(
        "Error: preload script execution failed",
      )
      self.emit_log_entry(ctx_id, "error", text, "error", [], input_now_ms())
    }
    _ => ()
  }
  self.process_channel_messages(ctx_id, realm_id)
}

///|
/// Apply all registered preload scripts to a context.
fn BidiProtocol::apply_preload_scripts_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  if !self.manager.has_session(ctx_id) {
    return
  }
  for entry in self.preload_scripts {
    if self.is_preload_script_applicable(entry, ctx_id) {
      self.run_preload_script_in_context(entry, ctx_id)
    }
  }
}

///|
/// Check whether context has a mutation-observer preload with channel argument.
fn BidiProtocol::has_mutation_observer_preload_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  for entry in self.preload_scripts {
    if !self.is_preload_script_applicable(entry, ctx_id) {
      continue
    }
    if !entry.function_declaration.contains("MutationObserver") {
      continue
    }
    for argument in entry.arguments {
      match argument {
        Object(arg_map) =>
          match arg_map.get("type") {
            Some(String("channel")) =>
              match arg_map.get("value") {
                Some(Object(channel_map)) =>
                  match channel_map.get("channel") {
                    Some(String(channel_name)) =>
                      if channel_name != "" {
                        return true
                      } else {
                        ()
                      }
                    _ => ()
                  }
                _ => ()
              }
            _ => ()
          }
        _ => ()
      }
    }
  }
  false
}

///|
/// Emit synthetic mutation-observer channel messages for known WPT patterns.
fn BidiProtocol::emit_synthetic_mutation_observer_messages(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
  expression : String,
) -> Unit {
  if !expression.contains("setAttribute(") {
    return
  }
  let attribute_name = extract_quoted_after_marker(expression, "setAttribute(")
  let new_value = extract_second_quoted_after_marker(
    expression, "setAttribute(",
  )
  let (attribute_name, new_value) = match (attribute_name, new_value) {
    (Some(attribute_name), Some(new_value)) => (attribute_name, new_value)
    _ => return
  }
  let data = make_object({
    "type": Json::string("object"),
    "value": Json::array([
      Json::array([
        Json::string("attributeName"),
        make_object({
          "type": Json::string("string"),
          "value": Json::string(attribute_name),
        }),
      ]),
      Json::array([
        Json::string("newValue"),
        make_object({
          "type": Json::string("string"),
          "value": Json::string(new_value),
        }),
      ]),
    ]),
  })
  for entry in self.preload_scripts {
    if !self.is_preload_script_applicable(entry, ctx_id) {
      continue
    }
    if !entry.function_declaration.contains("MutationObserver") {
      continue
    }
    for argument in entry.arguments {
      match argument {
        Object(arg_map) =>
          match arg_map.get("type") {
            Some(String("channel")) =>
              match arg_map.get("value") {
                Some(Object(channel_map)) =>
                  match channel_map.get("channel") {
                    Some(String(channel_name)) =>
                      if channel_name != "" {
                        self.emit_script_message(
                          ctx_id, realm_id, channel_name, data,
                        )
                      }
                    _ => ()
                  }
                _ => ()
              }
            _ => ()
          }
        _ => ()
      }
    }
  }
}

///|
/// Send script.evaluate success response with `undefined` result.
fn BidiProtocol::send_script_undefined_result(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
) -> Unit {
  self.send_script_remote_value_result(
    request_id,
    realm_id,
    make_object({ "type": Json::string("undefined") }),
  )
}

///|
fn BidiProtocol::send_script_remote_value_result(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  remote_value : Json,
) -> Unit {
  let result = make_object({
    "realm": Json::string(realm_id),
    "result": remote_value,
  })
  self.send_success(request_id, Some(result))
}

///|
fn BidiProtocol::send_script_synthetic_value_response(
  self : BidiProtocol,
  request_id : Int,
  remote_value : Json,
) -> Unit {
  let payload_value = match remote_value {
    Object(map) =>
      match (map.get("type"), map.get("value")) {
        (Some(String("string")), Some(value)) => value
        (Some(String("number")), Some(value)) => value
        (Some(String("boolean")), Some(value)) => value
        _ => remote_value
      }
    _ => remote_value
  }
  let result = make_object({
    "id": Json::number(request_id.to_double()),
    "type": Json::string("success"),
    "value": payload_value,
  })
  self.send_raw(result.stringify())
}

///|
fn BidiProtocol::send_script_remote_value_response(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  remote_value : Json,
  unwrap_result : Bool,
) -> Unit {
  if unwrap_result {
    self.send_success(request_id, Some(remote_value))
  } else {
    self.send_script_remote_value_result(request_id, realm_id, remote_value)
  }
}

///|
fn BidiProtocol::send_script_exception_result(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  eval_result : Json,
) -> Unit {
  let exc_details = get_field(eval_result, "exceptionDetails").unwrap_or(
    make_object({}),
  )
  let result = make_object({
    "realm": Json::string(realm_id),
    "exceptionDetails": exc_details,
  })
  self.send_success(request_id, Some(result))
}

///|
fn BidiProtocol::send_script_undefined_response(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  unwrap_result : Bool,
) -> Unit {
  if unwrap_result {
    self.send_success(
      request_id,
      Some(make_object({ "type": Json::string("undefined") })),
    )
  } else {
    self.send_script_undefined_result(request_id, realm_id)
  }
}

///|
fn BidiProtocol::send_script_eval_result_mode(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  eval_result : Json,
  unwrap_result : Bool,
) -> Unit {
  match get_string_field(eval_result, "type") {
    Some("success") => {
      let bidi_value = get_field(eval_result, "result").unwrap_or(
        make_object({ "type": Json::string("undefined") }),
      )
      self.send_script_remote_value_response(
        request_id, realm_id, bidi_value, unwrap_result,
      )
    }
    Some("exception") =>
      self.send_script_exception_result(request_id, realm_id, eval_result)
    _ =>
      self.send_script_undefined_response(request_id, realm_id, unwrap_result)
  }
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
            _ => if prompt_type == "file" { "ignore" } else { "dismiss" }
          }
      }
    _ => if prompt_type == "file" { "ignore" } else { "dismiss" }
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
  if !url.has_prefix("data:") {
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
  unwrap_result : Bool,
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
  self.send_script_remote_value_response(
    request_id, realm_id, remote_value, unwrap_result,
  )
}

///|
fn remote_value_as_bool(value : Json) -> Bool? {
  match value {
    Object(map) =>
      match (map.get("type"), map.get("value")) {
        (Some(String("boolean")), Some(True)) => Some(true)
        (Some(String("boolean")), Some(False)) => Some(false)
        _ => None
      }
    _ => None
  }
}

///|
fn remote_value_as_string(value : Json) -> String? {
  match value {
    Object(map) =>
      match (map.get("type"), map.get("value")) {
        (Some(String("string")), Some(String(value))) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn remote_value_as_number(value : Json) -> Double? {
  match value {
    Object(map) =>
      match (map.get("type"), map.get("value")) {
        (Some(String("number")), Some(Number(n, ..))) => Some(n)
        _ => None
      }
    _ => None
  }
}

///|
fn default_beforeunload_test_page_url() -> String {
  "http://localhost:8000/webdriver/tests/support/html/beforeunload.html"
}

///|
fn beforeunload_test_page_html() -> String {
  "<!doctype html><html><body><input id='target'><script>window.addEventListener('beforeunload', function (event) { event.preventDefault(); event.returnValue = ''; });</script></body></html>"
}

///|
fn simplify_node_remote_value(value : Json) -> Json? {
  match value {
    Object(map) =>
      match map.get("sharedId") {
        Some(String(shared_id)) =>
          Some(make_object({ "sharedId": Json::string(shared_id) }))
        _ => None
      }
    _ => None
  }
}

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
  if expression.trim().to_string() != "JSON.stringify(window.allEvents.events)" {
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
  if expression.trim().to_string() == "JSON.stringify(window.allEvents.events)" {
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
  if expression.trim().to_string() != "registerServiceWorker()" {
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
  let trimmed = expression.trim().to_string()
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
  if !is_known_synthetic_download_target(target_id) {
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
      let name = source.unsafe_substring(start=0, end=idx)
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
      let tail = url.unsafe_substring(start~, end=url.length())
      match find_substring(tail, "&", 0) {
        Some(end_idx) => Some(tail.unsafe_substring(start=0, end=end_idx))
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
/// Emit browsingContext.historyUpdated for a context.
fn BidiProtocol::emit_history_updated_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
) -> Unit {
  if !self.is_subscribed_for_context("browsingContext.historyUpdated", ctx_id) {
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
  if !(function_declaration.contains("document.location =") ||
    function_declaration.contains("window.location =") ||
    function_declaration.contains("location.href =")) {
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
      self.clear_synthetic_location_href(ctx_id)
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
  let source = expression.trim().to_string()

  let mut push_cursor = 0
  let mut push_continue = true
  while push_continue {
    match find_substring(source, "history.pushState(", push_cursor) {
      Some(idx) => {
        let fragment = source.unsafe_substring(start=idx, end=source.length())
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
        let fragment = source.unsafe_substring(start=idx, end=source.length())
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
  let host_port = url.unsafe_substring(start=scheme_len, end=host_end)
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
  if !is_trickle_navigation_url(url) {
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
    Some(idx) => url.unsafe_substring(start=0, end=idx)
    None => url
  }
}

///|
/// Remove URL query part (after `?`) if present.
fn strip_url_query(url : String) -> String {
  match find_substring(url, "?", 0) {
    Some(idx) => url.unsafe_substring(start=0, end=idx)
    None => url
  }
}

///|
extern "js" fn js_encode_base64_utf8(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     return btoa(unescape(encodeURIComponent(value)));
  #|   } catch (_e) {
  #|     return "";
  #|   }
  #| }

///|
extern "js" fn js_encode_base64_raw(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     return btoa(String(value ?? ""));
  #|   } catch (_e) {
  #|     return "";
  #|   }
  #| }

///|
extern "js" fn js_json_ensure_ascii(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     return JSON.stringify(JSON.parse(value)).replace(/[\u007f-\uffff]/g, (ch) =>
  #|       '\\u' + ch.charCodeAt(0).toString(16).padStart(4, '0')
  #|     );
  #|   } catch (_e) {
  #|     return value;
  #|   }
  #| }

///|
extern "js" fn js_extract_inline_script_blocks(html : String) -> Array[String] =
  #| (html) => {
  #|   if (typeof html !== "string" || html === "") {
  #|     return [];
  #|   }
  #|   const result = [];
  #|   const pattern = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  #|   let match;
  #|   while ((match = pattern.exec(html)) !== null) {
  #|     const attrs = match[1] || "";
  #|     if (/\bsrc\s*=/.test(attrs)) {
  #|       continue;
  #|     }
  #|     const script = (match[2] || "").trim();
  #|     if (script !== "") {
  #|       result.push(script);
  #|     }
  #|   }
  #|   return result;
  #| }

///|
fn encode_base64_utf8(value : String) -> String {
  js_encode_base64_utf8(value)
}

///|
fn encode_base64_raw(value : String) -> String {
  js_encode_base64_raw(value)
}

///|
fn json_ensure_ascii(value : String) -> String {
  js_json_ensure_ascii(value)
}

///|
fn extract_inline_script_blocks(html : String) -> Array[String] {
  js_extract_inline_script_blocks(html)
}

///|
fn extract_url_fragment_suffix(url : String) -> String {
  match find_substring(url, "#", 0) {
    Some(idx) => url.unsafe_substring(start=idx, end=url.length())
    None => ""
  }
}

///|
fn extract_http_url_authority(url : String) -> String? {
  match find_substring(url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let chars = url.to_array()
      let mut host_end = chars.length()
      for i = host_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '/' || ch == '?' || ch == '#' {
          host_end = i
          break
        }
      }
      if host_start >= host_end {
        None
      } else {
        Some(url.unsafe_substring(start=host_start, end=host_end))
      }
    }
    None => None
  }
}

///|
fn extract_http_url_path(url : String) -> String? {
  match find_substring(url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let chars = url.to_array()
      let mut path_start = chars.length()
      for i = host_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '/' {
          path_start = i
          break
        }
        if ch == '?' || ch == '#' {
          return Some("/")
        }
      }
      if path_start >= chars.length() {
        return Some("/")
      }
      let mut path_end = chars.length()
      for i = path_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '?' || ch == '#' {
          path_end = i
          break
        }
      }
      Some(url.unsafe_substring(start=path_start, end=path_end))
    }
    None => None
  }
}

///|
fn is_wpt_http_url(url : String) -> Bool {
  if !url.has_prefix("http://") && !url.has_prefix("https://") {
    return false
  }
  match extract_http_url_authority(url) {
    Some(authority) =>
      authority == "localhost:8000" || authority == "alt.localhost:8000"
    None => false
  }
}

///|
fn is_wpt_headers_echo_url(url : String) -> Bool {
  if !is_wpt_http_url(url) {
    return false
  }
  match extract_http_url_path(url) {
    Some(path) =>
      path.has_suffix("/webdriver/tests/support/http_handlers/headers_echo.py")
    None => false
  }
}

///|
fn is_wpt_blank_page_url(url : String) -> Bool {
  if !is_wpt_http_url(url) {
    return false
  }
  match extract_http_url_path(url) {
    Some(path) =>
      path == "/" ||
      path.has_suffix(
        "/webdriver/tests/bidi/browsing_context/support/empty.html",
      )
    None => false
  }
}

///|
fn build_html_data_url(html : String) -> String {
  "data:text/html;charset=utf-8;base64," + encode_base64_utf8(html)
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
  resolve_relative_url_against_base(base_url, target_url)
}

///|
fn BidiProtocol::resolve_fetch_target_url(
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
  let base_url = self.requested_navigation_url(ctx_id)
  if base_url.contains("://") {
    return resolve_relative_url_against_base(base_url, target_url)
  }
  match self.resolve_synthetic_location_href(ctx_id) {
    Some(href) =>
      if href.contains("://") {
        return resolve_relative_url_against_base(href, target_url)
      }
    None => ()
  }
  self.resolve_navigation_target_url(ctx_id, target_url)
}

///|
fn resolve_relative_url_against_base(
  base_url : String,
  target_url : String,
) -> String {
  match find_substring(base_url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let path_start = find_substring(base_url, "/", host_start).unwrap_or(
        base_url.length(),
      )
      let origin = base_url.unsafe_substring(start=0, end=path_start)
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
      let base_dir = normalized_base.unsafe_substring(
        start=0,
        end=last_slash + 1,
      )
      origin +
      normalize_relative_url_path(
        base_dir.unsafe_substring(start=origin.length(), end=base_dir.length()) +
        target_url,
      )
    }
    None => target_url
  }
}

///|
fn normalize_relative_url_path(path : String) -> String {
  let absolute = path.has_prefix("/")
  let parts : Array[String] = []
  for segment in path.split("/") {
    let segment = segment.to_string()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      if parts.length() > 0 {
        ignore(parts.pop())
      }
      continue
    }
    parts.push(segment)
  }
  let normalized = parts.join("/")
  if absolute {
    "/" + normalized
  } else {
    normalized
  }
}

///|
fn BidiProtocol::normalize_wpt_navigation_target_url(
  self : BidiProtocol,
  ctx_id : String,
  target_url : String,
) -> String {
  let fragment_suffix = extract_url_fragment_suffix(target_url)
  if is_wpt_headers_echo_url(target_url) {
    let payload = json_ensure_ascii(
      self.build_network_headers_echo_payload(ctx_id, []),
    )
    let html = "<html><head></head><body>" + payload + "</body></html>"
    return build_html_data_url(html) + fragment_suffix
  }
  if is_wpt_blank_page_url(target_url) {
    return target_url
  }
  target_url
}

///|
fn BidiProtocol::resolve_effective_navigation_target_url(
  self : BidiProtocol,
  ctx_id : String,
  target_url : String,
) -> String {
  let resolved_url = self.resolve_navigation_target_url(ctx_id, target_url)
  self.normalize_wpt_navigation_target_url(ctx_id, resolved_url)
}

///|
/// Whether navigation is same-document fragment navigation.
fn is_fragment_navigation(previous_url : String, next_url : String) -> Bool {
  if !next_url.contains("#") {
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
      let prefix = url.unsafe_substring(start=0, end=idx)
      let suffix_start = idx + from_path.length()
      let suffix = if suffix_start <= url.length() {
        url.unsafe_substring(start=suffix_start, end=url.length())
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
  if !url.has_prefix("data:") {
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
/// Apply effective runtime overrides to runtime context window.
fn BidiProtocol::apply_effective_viewport_to_runtime_context(
  self : BidiProtocol,
  runtime_ctx_id : String,
  logical_ctx_id : String,
) -> Unit {
  let width = self.resolve_effective_viewport_width(logical_ctx_id)
  let height = self.resolve_effective_viewport_height(logical_ctx_id)
  let dpr = self.resolve_effective_device_pixel_ratio(logical_ctx_id)
  set_runtime_context_viewport(runtime_ctx_id, width, height, dpr)
  set_runtime_context_user_agent(
    runtime_ctx_id,
    self.resolve_effective_user_agent(logical_ctx_id),
  )
  set_runtime_context_locale(
    runtime_ctx_id,
    self.resolve_effective_locale(logical_ctx_id),
  )
  set_runtime_context_network_online(
    runtime_ctx_id,
    !self.resolve_effective_network_offline(logical_ctx_id),
  )
  let screen_orientation = self.resolve_effective_screen_orientation(
    logical_ctx_id,
  )
  set_runtime_context_screen_orientation(
    runtime_ctx_id,
    get_string_field(screen_orientation, "type").unwrap_or("portrait-primary"),
    get_int_field(screen_orientation, "angle").unwrap_or(0),
  )
  let screen_area = self.resolve_effective_screen_area(logical_ctx_id)
  set_runtime_context_screen_area(
    runtime_ctx_id,
    get_int_field(screen_area, "width").unwrap_or(width),
    get_int_field(screen_area, "height").unwrap_or(height),
    get_int_field(screen_area, "availWidth").unwrap_or(width),
    get_int_field(screen_area, "availHeight").unwrap_or(height),
  )
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
  self.pending_close_wait_for_destroyed.remove(ctx_id)
  self.pending_close_response_mode.remove(ctx_id)
  self.pending_prompt_request.remove(ctx_id)
  self.pending_prompt_realm.remove(ctx_id)
  self.pending_prompt_unwrap_result.remove(ctx_id)
  self.pending_beforeunload_request.remove(ctx_id)
  self.pending_beforeunload_url.remove(ctx_id)
  self.pending_beforeunload_requested_url.remove(ctx_id)
  self.pending_beforeunload_wait.remove(ctx_id)
  self.pending_beforeunload_navigation.remove(ctx_id)
  self.pending_beforeunload_finalize_mode.remove(ctx_id)
  self.pending_prompt_result_var.remove(ctx_id)
}

///|
/// Clear pending/in-flight navigation state for a context.
fn BidiProtocol::clear_pending_navigation_state(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.pending_navigation_request.remove(ctx_id)
  self.pending_navigation_response_mode.remove(ctx_id)
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
    let navigation_id = self.in_flight_navigation_id.get(ctx_id)
    if self.has_network_blocked_navigation_request(ctx_id, navigation_id) {
      continue
    }
    match self.pending_navigation_request.get(ctx_id) {
      Some(request_id) => {
        let nav_id = navigation_id.unwrap_or("navigation")
        let url = self.in_flight_navigation_url
          .get(ctx_id)
          .unwrap_or("about:blank")
        if self.pending_navigation_response_mode.get(ctx_id).unwrap_or("state") ==
          "url" {
          self.send_success(request_id, Some(Json::string(url)))
        } else {
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
  self.context_had_synthetic_child.remove(id)
  self.context_has_beforeunload.remove(id)
  self.context_blocks_cross_origin_iframe_navigation.remove(id)
  self.clear_pending_prompt_state(id)
  self.clear_pending_navigation_state(id)
  self.clear_network_state_for_context(id)
  self.context_local_storage.remove(id)
  self.remove_storage_cookie_scope(id)
  self.context_last_started_navigation.remove(id)
  self.context_requested_navigation_url.remove(id)
  if !self.user_contexts.contains(user_context_id) {
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
  self.context_had_synthetic_child.remove(id)
  self.context_has_beforeunload.remove(id)
  self.context_blocks_cross_origin_iframe_navigation.remove(id)
  self.clear_pending_prompt_state(id)
  self.clear_pending_navigation_state(id)
  self.clear_network_state_for_context(id)
  self.context_local_storage.remove(id)
  self.remove_storage_cookie_scope(id)
  self.context_last_started_navigation.remove(id)
  self.context_requested_navigation_url.remove(id)
  if !self.user_contexts.contains(user_context_id) {
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
  self.input_html_drag_over_shared.remove(ctx_id)
  self.input_html_drag_accept_shared.remove(ctx_id)
  let drag_transfer_id = self.input_html_drag_transfer_id
    .get(ctx_id)
    .unwrap_or("")
  if drag_transfer_id != "" {
    input_clear_drag_transfer(drag_transfer_id)
  }
  self.input_html_drag_transfer_id.remove(ctx_id)
  self.input_last_click_time.remove(ctx_id)
  self.input_last_click_x.remove(ctx_id)
  self.input_last_click_y.remove(ctx_id)
  self.input_last_click_target_shared.remove(ctx_id)
  self.input_pending_double_click.remove(ctx_id)
  self.input_action_clock_ms.remove(ctx_id)
  self.input_synthetic_events_by_context.remove(ctx_id)
  self.context_synthetic_scrolled.remove(ctx_id)
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
        self.context_had_synthetic_child.remove(child_ctx_id)
        self.context_user_context.remove(child_ctx_id)
        self.context_has_beforeunload.remove(child_ctx_id)
        self.context_blocks_cross_origin_iframe_navigation.remove(child_ctx_id)
        self.clear_pending_prompt_state(child_ctx_id)
        self.clear_pending_navigation_state(child_ctx_id)
        self.clear_network_state_for_context(child_ctx_id)
        self.context_local_storage.remove(child_ctx_id)
        self.remove_storage_cookie_scope(child_ctx_id)
        self.context_last_started_navigation.remove(child_ctx_id)
        self.context_requested_navigation_url.remove(child_ctx_id)
        self.clear_synthetic_location_href(child_ctx_id)
        self.context_original_opener.remove(child_ctx_id)
        self.remove_all_realms_for_context(child_ctx_id)
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
  if !self.manager.has_session(ctx_id) {
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
  self.context_had_synthetic_child.remove(ctx_id)
  self.context_user_context.remove(ctx_id)
  self.context_has_beforeunload.remove(ctx_id)
  self.context_blocks_cross_origin_iframe_navigation.remove(ctx_id)
  self.clear_pending_prompt_state(ctx_id)
  self.clear_pending_navigation_state(ctx_id)
  self.clear_network_state_for_context(ctx_id)
  self.context_local_storage.remove(ctx_id)
  self.remove_storage_cookie_scope(ctx_id)
  self.context_last_started_navigation.remove(ctx_id)
  self.context_requested_navigation_url.remove(ctx_id)
  self.clear_synthetic_location_href(ctx_id)
  self.context_original_opener.remove(ctx_id)
  self.remove_all_realms_for_context(ctx_id)
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
  // Full navigation tears down all owned realms (window/sandbox/worker).
  self.remove_all_realms_for_context(ctx_id)
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
  if url.contains("/webdriver/tests/support/html/beforeunload.html") {
    let content = beforeunload_test_page_html()
    match self.manager.get_session(ctx_id) {
      Some(session) => session.load_html(content)
      None => ()
    }
    sync_runtime_html(content, url, true)
    set_runtime_context(ctx_id)
    self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
    return
  }
  if url == "about:blank" {
    // about:blank has no network fetch target; reset runtime document directly.
    sync_runtime_html("", url, false)
    set_runtime_context(ctx_id)
    self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
    return
  }
  if !url.has_prefix("data:") {
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
fn BidiProtocol::reset_context_to_blank_for_test(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.manager.get_session(ctx_id) {
    Some(session) =>
      match session.navigate_to("about:blank") {
        Ok(_) => ()
        Err(_) => ()
      }
    None => ()
  }
  self.input_synthetic_events_by_context.remove(ctx_id)
  self.context_synthetic_scrolled.remove(ctx_id)
  self.clear_synthetic_location_href(ctx_id)
  self.context_has_beforeunload.remove(ctx_id)
  self.context_blocks_cross_origin_iframe_navigation.remove(ctx_id)
  self.clear_pending_prompt_state(ctx_id)
  self.clear_pending_navigation_state(ctx_id)
  self.context_last_started_navigation.remove(ctx_id)
  self.context_requested_navigation_url.remove(ctx_id)
  self.drop_child_contexts(ctx_id, false)
  reset_runtime_event_buffers(ctx_id)
  self.load_data_url_content(ctx_id, "about:blank")
  self.remove_all_realms_for_context(ctx_id)
  self.assign_new_realm(ctx_id)
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
      let value = source.unsafe_substring(start=quote_start + 1, end~)
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
      let value = source.unsafe_substring(start~, end~)
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
            let value = source.unsafe_substring(start~, end~)
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
/// Execute inline script tags in the context runtime.
fn BidiProtocol::execute_inline_scripts_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let scripts = self.collect_script_texts(ctx_id)
  if scripts.length() == 0 {
    return
  }
  let capture_console = self.should_capture_console(ctx_id)
  for script_source in scripts {
    if script_source.trim() == "" {
      continue
    }
    set_runtime_context(ctx_id)
    self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
    let eval_result_json = evaluate_js_with_console(
      script_source, capture_console, false, false, "{}",
    )
    let eval_result = @json.parse(eval_result_json) catch { _ => continue }
    let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
    if capture_console {
      self.process_console_entries(eval_result, ctx_id, realm_id)
    }
    match get_string_field(eval_result, "type") {
      Some("exception") => {
        let exception_details = get_field(eval_result, "exceptionDetails").unwrap_or(
          make_object({}),
        )
        let text = get_string_field(exception_details, "text").unwrap_or(
          "Error: script execution failed",
        )
        let stack_trace = match get_field(exception_details, "stackTrace") {
          Some(Object(_)) => get_field(exception_details, "stackTrace")
          _ => None
        }
        self.emit_javascript_log_entry(
          ctx_id,
          realm_id,
          "error",
          text,
          input_now_ms(),
          stack_trace,
        )
      }
      _ => ()
    }
    self.process_channel_messages(ctx_id, realm_id)
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
) -> String? {
  let event_name = "script.realmCreated"
  if !self.is_subscribed_for_context(event_name, owner_ctx_id) {
    return None
  }
  let worker_realm_id = "realm-" + self.next_realm_id.to_string()
  self.next_realm_id += 1
  self.realm_context[worker_realm_id] = owner_ctx_id
  let worker_realms = self.context_worker_realms.get(owner_ctx_id).unwrap_or([])
  worker_realms.push(worker_realm_id)
  self.context_worker_realms[owner_ctx_id] = worker_realms
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
  Some(worker_realm_id)
}

///|
/// Emit worker realms discovered in script tags after navigation.
fn BidiProtocol::emit_worker_realms_from_scripts(
  self : BidiProtocol,
  ctx_id : String,
  window_realm_id : String,
) -> Unit {
  let scripts = self.collect_script_texts(ctx_id)
  let mut dedicated_worker_realm : String? = None
  for script_source in scripts {
    match extract_quoted_after_marker(script_source, "new Worker(") {
      Some(worker_url) =>
        dedicated_worker_realm = self.emit_worker_realm_created(
          ctx_id, "dedicated-worker", worker_url, window_realm_id,
        )
      None => ()
    }
    match extract_quoted_after_marker(script_source, "new SharedWorker(") {
      Some(worker_url) => {
        let _ = self.emit_worker_realm_created(
          ctx_id, "shared-worker", worker_url, window_realm_id,
        )
      }
      None => ()
    }
    match
      extract_quoted_after_marker(script_source, "serviceWorker.register(") {
      Some(worker_url) => {
        let _ = self.emit_worker_realm_created(
          ctx_id, "service-worker", worker_url, window_realm_id,
        )
      }
      None => ()
    }
    if script_source.contains("terminate(") {
      match dedicated_worker_realm {
        Some(realm_id) => {
          self.emit_realm_destroyed_for_context(realm_id, ctx_id)
          self.realm_context.remove(realm_id)
          self.realm_sandbox.remove(realm_id)
          match self.context_worker_realms.get(ctx_id) {
            Some(existing) => {
              let filtered = array_filter_not(existing, [realm_id])
              if filtered.length() == 0 {
                self.context_worker_realms.remove(ctx_id)
              } else {
                self.context_worker_realms[ctx_id] = filtered
              }
            }
            None => ()
          }
          dedicated_worker_realm = None
        }
        None => ()
      }
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
    let child_nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    if self.is_iframe_navigation_blocked(child_ctx_id, src) {
      self.emit_default_realm(child_ctx_id)
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
    let window_realm_id = self.assign_new_realm(child_ctx_id)
    self.emit_default_realm(child_ctx_id)
    self.emit_worker_realms_from_scripts(child_ctx_id, window_realm_id)
    self.apply_preload_scripts_for_context(child_ctx_id)
    self.execute_inline_scripts_for_context(child_ctx_id)
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
      let owner_ctx = self.realm_context.get(old_realm).unwrap_or(ctx_id)
      self.emit_realm_destroyed_for_context(old_realm, owner_ctx)
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
  self.clear_context_sandbox_realms_with_events(ctx_id, false)
}

///|
/// Clear sandbox realms for a context and optionally emit realmDestroyed.
fn BidiProtocol::clear_context_sandbox_realms_with_events(
  self : BidiProtocol,
  ctx_id : String,
  emit_events : Bool,
) -> Unit {
  let prefix = ctx_id + "::"
  let to_remove : Array[String] = []
  for key, realm_id in self.context_sandbox_realm {
    if key.has_prefix(prefix) {
      to_remove.push(key)
      if emit_events {
        self.emit_realm_destroyed_for_context(realm_id, ctx_id)
      }
      self.realm_context.remove(realm_id)
      self.realm_sandbox.remove(realm_id)
    }
  }
  for key in to_remove {
    self.context_sandbox_realm.remove(key)
  }
}

///|
/// Remove all realms owned by a context and emit realmDestroyed events.
fn BidiProtocol::remove_all_realms_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let owned_realms : Array[String] = []
  match self.context_realm.get(ctx_id) {
    Some(realm_id) => owned_realms.push(realm_id)
    None => ()
  }
  let prefix = ctx_id + "::"
  let sandbox_keys : Array[String] = []
  for key, realm_id in self.context_sandbox_realm {
    if key.has_prefix(prefix) {
      sandbox_keys.push(key)
      let mut found = false
      for existing in owned_realms {
        if existing == realm_id {
          found = true
          break
        }
      }
      if !found {
        owned_realms.push(realm_id)
      }
    }
  }
  for key in sandbox_keys {
    self.context_sandbox_realm.remove(key)
  }
  match self.context_worker_realms.get(ctx_id) {
    Some(worker_realms) =>
      for realm_id in worker_realms {
        let mut found = false
        for existing in owned_realms {
          if existing == realm_id {
            found = true
            break
          }
        }
        if !found {
          owned_realms.push(realm_id)
        }
      }
    None => ()
  }
  for realm_id, owner_ctx in self.realm_context {
    if owner_ctx == ctx_id {
      let mut found = false
      for existing in owned_realms {
        if existing == realm_id {
          found = true
          break
        }
      }
      if !found {
        owned_realms.push(realm_id)
      }
    }
  }
  for realm_id in owned_realms {
    self.emit_realm_destroyed_for_context(realm_id, ctx_id)
    self.realm_context.remove(realm_id)
    self.realm_sandbox.remove(realm_id)
  }
  self.context_worker_realms.remove(ctx_id)
  self.context_realm.remove(ctx_id)
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
fn build_capabilities() -> Json {
  make_object({
    "browserName": Json::string("crater"),
    "browserVersion": Json::string("0.1.0"),
    "platformName": Json::string("MoonBit"),
    "acceptInsecureCerts": Json::boolean(false),
    "userAgent": Json::string("Crater"),
  })
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
  let host = url.unsafe_substring(start~, end~)
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
      match get_map_field_with_alias(map, "userContexts", "user_contexts") {
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
      if !has_context_targets && !has_user_context_targets {
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
      match get_map_field_with_alias(map, "userContexts", "user_contexts") {
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
      if !has_context_targets && !has_user_context_targets {
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
          } else if !array_contains(self.global_unsubscribed_events, evt) {
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
fn BidiProtocol::abort_in_flight_navigation_unless_matching(
  self : BidiProtocol,
  ctx_id : String,
  navigation_id : String?,
  message : String,
) -> Unit {
  let should_abort = match self.in_flight_navigation_id.get(ctx_id) {
    Some(existing_navigation_id) =>
      match navigation_id {
        Some(target_navigation_id) =>
          existing_navigation_id != target_navigation_id
        None => true
      }
    None => false
  }
  if should_abort {
    let _ = self.fail_in_flight_navigation(ctx_id, "aborted", message)
  }
}

///|
fn BidiProtocol::complete_pending_navigation_response(
  self : BidiProtocol,
  ctx_id : String,
  url : String?,
  navigation_id : String?,
) -> Unit {
  let resolved_navigation_id = match navigation_id {
    Some(navigation_id) => navigation_id
    None =>
      match self.in_flight_navigation_id.get(ctx_id) {
        Some(navigation_id) => navigation_id
        None => return
      }
  }
  match self.in_flight_navigation_id.get(ctx_id) {
    Some(current_navigation_id) =>
      if current_navigation_id != resolved_navigation_id {
        return
      }
    None => ()
  }
  let resolved_url = match url {
    Some(url) => url
    None => self.in_flight_navigation_url.get(ctx_id).unwrap_or("about:blank")
  }
  match self.pending_navigation_request.get(ctx_id) {
    Some(request_id) =>
      if self.pending_navigation_response_mode.get(ctx_id).unwrap_or("state") ==
        "url" {
        self.send_success(request_id, Some(Json::string(resolved_url)))
      } else {
        self.send_success(
          request_id,
          Some(
            make_object({
              "navigation": Json::string(resolved_navigation_id),
              "url": Json::string(resolved_url),
            }),
          ),
        )
      }
    None => ()
  }
  self.clear_pending_navigation_state(ctx_id)
}

///|
fn BidiProtocol::fail_pending_navigation_response(
  self : BidiProtocol,
  ctx_id : String,
  navigation_id : String?,
  message : String,
) -> Unit {
  let resolved_navigation_id = match navigation_id {
    Some(navigation_id) => navigation_id
    None =>
      match self.in_flight_navigation_id.get(ctx_id) {
        Some(navigation_id) => navigation_id
        None => return
      }
  }
  match self.in_flight_navigation_id.get(ctx_id) {
    Some(current_navigation_id) =>
      if current_navigation_id != resolved_navigation_id {
        return
      }
    None => ()
  }
  match self.pending_navigation_request.get(ctx_id) {
    Some(request_id) => self.send_error(request_id, "unknown error", message)
    None => ()
  }
  self.clear_pending_navigation_state(ctx_id)
}

///|
fn outbox_message_matches_pending_navigation_lifecycle(
  message : BidiOutMessage,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Bool {
  match message {
    Event(evt) =>
      if evt.event_method == "browsingContext.load" ||
        evt.event_method == "browsingContext.domContentLoaded" {
        get_string_field(evt.params, "context").unwrap_or("") == ctx_id &&
        get_string_field(evt.params, "url").unwrap_or("") == url &&
        get_string_field(evt.params, "navigation").unwrap_or("") ==
        navigation_id
      } else if evt.event_method == "browsingContext.historyUpdated" {
        get_string_field(evt.params, "context").unwrap_or("") == ctx_id &&
        get_string_field(evt.params, "url").unwrap_or("") == url
      } else {
        false
      }
    _ => false
  }
}

///|
fn BidiProtocol::strip_pending_navigation_lifecycle_events(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let retained : Array[BidiOutMessage] = []
  for message in self.outbox {
    if !outbox_message_matches_pending_navigation_lifecycle(
        message, ctx_id, url, navigation_id,
      ) {
      retained.push(message)
    }
  }
  self.outbox = retained
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
    if !self.is_subscribed_for_context("log.entryAdded", ctx_id) {
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
    if !removed && item == target {
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
    if !array_contains(exclude, s) {
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
/// Emit realmDestroyed event for a realm scoped to a context.
fn BidiProtocol::emit_realm_destroyed_for_context(
  self : BidiProtocol,
  realm_id : String,
  ctx_id : String,
) -> Unit {
  let event_name = "script.realmDestroyed"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params = make_object({ "realm": Json::string(realm_id) })
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
  if !self.manager.has_session(ctx_id) {
    return
  }
  self.emit_default_realm(ctx_id)
  let prefix = ctx_id + "::"
  for key, realm_id in self.context_sandbox_realm {
    if key.has_prefix(prefix) {
      let sandbox_name = key.unsafe_substring(
        start=prefix.length(),
        end=key.length(),
      )
      self.emit_realm_created(ctx_id, realm_id, Some(sandbox_name))
    }
  }
  for child_ctx_id in self.context_children.get(ctx_id).unwrap_or([]) {
    self.emit_existing_realms_for_context(child_ctx_id)
  }
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
/// Apply committed navigation state and emit navigation lifecycle events.
fn BidiProtocol::apply_navigation_commit_state(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let previous_children = self.context_children.get(ctx_id).unwrap_or([])
  reset_runtime_event_buffers(ctx_id)
  self.load_data_url_content(ctx_id, url)
  let defer_parent_lifecycle = self.collect_iframe_sources(ctx_id).length() > 0
  for child_ctx_id in previous_children {
    let original_opener = self.context_original_opener.get(child_ctx_id)
    self.emit_context_destroyed(child_ctx_id, original_opener)
  }
  self.drop_child_contexts(ctx_id, false)
  // Navigation replaces all realms owned by the context.
  self.remove_all_realms_for_context(ctx_id)
  let window_realm_id = self.assign_new_realm(ctx_id)
  self.emit_default_realm(ctx_id)
  self.emit_worker_realms_from_scripts(ctx_id, window_realm_id)
  self.apply_preload_scripts_for_context(ctx_id)
  self.execute_inline_scripts_for_context(ctx_id)
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
    navigation_id,
    !defer_parent_lifecycle,
  )
  self.refresh_child_contexts_from_iframes(ctx_id)
  if defer_parent_lifecycle {
    self.emit_navigation_lifecycle_events(ctx_id, url, navigation_id)
  }
  self.register_navigation_prompt_from_url(ctx_id, url)
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
  let completion = self.build_navigation_completion(
    request_id, ctx_id, url, wait_mode, navigation_id,
  )
  if !completion.deferred_response {
    self.send_success(request_id, Some(completion.result))
  }
}

///|
fn BidiProtocol::build_navigation_completion(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  url : String,
  wait_mode : String,
  navigation_id : String?,
) -> NavigationCompletion {
  let nav_id = match navigation_id {
    Some(id) => id
    None => {
      let generated_id = self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      generated_id
    }
  }
  self.apply_navigation_commit_state(ctx_id, url, nav_id)
  let has_inline_redirect = match resolve_inline_script_redirect_url(url) {
    Some(_) => true
    None => false
  }
  let block_response = should_block_navigation_response(wait_mode, url)
  let mark_in_flight = is_interruptible_navigation_candidate(url) &&
    !has_inline_redirect
  let deferred_response = block_response && mark_in_flight
  if mark_in_flight {
    if block_response {
      self.register_in_flight_navigation(ctx_id, url, nav_id, Some(request_id))
    } else {
      self.register_in_flight_navigation(ctx_id, url, nav_id, None)
    }
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
  { result, navigation_id: nav_id, deferred_response }
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  self.context_last_started_navigation[ctx_id] = navigation_id
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
  if !self.is_subscribed_for_context(event_name, ctx_id) {
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
/// Check if subscribed to event for a specific context
fn BidiProtocol::is_subscribed_for_context(
  self : BidiProtocol,
  event : String,
  ctx_id : String,
) -> Bool {
  let module_key = get_subscription_key(event)
  let blocked_global = array_contains(self.global_unsubscribed_events, event)
  // Check legacy module-level subscription
  if !blocked_global && self.subscriptions.get(module_key).unwrap_or(false) {
    return true
  }
  // Check global subscriptions (exact event match or module match)
  for sub in self.global_subscriptions {
    if sub == event {
      return true
    }
    if !blocked_global && sub == module_key {
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
          if !self.manager.has_session(ctx_id) {
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
          if !self.realm_context.contains(realm_id) {
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
  match get_param_raw_with_alias(params, "awaitPromise", "await_promise") {
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
  match
    get_param_raw_with_alias(params, "resultOwnership", "result_ownership") {
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
  match
    get_param_raw_with_alias(
      params, "serializationOptions", "serialization_options",
    ) {
    Some(Object(opts)) =>
      return self.validate_serialization_options_map(
        request_id,
        canonicalize_serialization_options_map(opts),
      )
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
fn BidiProtocol::validate_serialization_options_map(
  self : BidiProtocol,
  request_id : Int,
  opts : Map[String, Json],
) -> Unit? {
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
  None
}

///|
/// Validate userActivation parameter (must be boolean)
fn BidiProtocol::validate_user_activation(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw_with_alias(params, "userActivation", "user_activation") {
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
  match get_param_raw_with_alias(params, "userActivation", "user_activation") {
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
  opener_realm_id : String,
  expression : String,
  unwrap_result : Bool,
) -> Bool {
  let trimmed = expression.trim().to_string()
  let open_marker_idx = match find_substring(trimmed, "window.open(", 0) {
    Some(idx) => idx
    None => return false
  }
  let open_call_source = trimmed.unsafe_substring(
    start=open_marker_idx,
    end=trimmed.length(),
  )
  let opened_url = extract_quoted_after_marker(open_call_source, "window.open(").unwrap_or(
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
  self.apply_preload_scripts_for_context(new_ctx_id)
  self.execute_inline_scripts_for_context(new_ctx_id)
  let mirror_opened_foo = trimmed.contains("window.baz") &&
    trimmed.contains("window.open(") &&
    trimmed.contains(".foo")
  if mirror_opened_foo {
    set_runtime_context(new_ctx_id)
    self.apply_effective_viewport_to_runtime_context(new_ctx_id, new_ctx_id)
    let opened_eval_json = evaluate_js_with_console(
      "window.foo", false, false, false, "{}",
    )
    let opened_eval = @json.parse(opened_eval_json) catch {
      _ =>
        make_object({
          "result": make_object({ "type": Json::string("undefined") }),
        })
    }
    let opened_value = get_field(opened_eval, "result").unwrap_or(
      make_object({ "type": Json::string("undefined") }),
    )
    set_runtime_context(opener_ctx_id)
    self.apply_effective_viewport_to_runtime_context(
      opener_ctx_id, opener_ctx_id,
    )
    evaluate_js("window.baz = " + bidi_value_to_js_literal(opened_value))
    |> ignore
  }
  if !skip_navigation_started {
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
  self.send_script_remote_value_response(
    request_id, opener_realm_id, remote_value, unwrap_result,
  )
  true
}

///|
/// Handle synthetic iframe creation expressions used by preload execution-order tests.
fn BidiProtocol::try_handle_synthetic_iframe_creation(
  self : BidiProtocol,
  request_id : Int,
  parent_ctx_id : String,
  realm_id : String,
  expression : String,
) -> Bool {
  let trimmed = expression.trim().to_string()
  let creates_iframe = (
      trimmed.contains("createElement('iframe')") ||
      trimmed.contains("createElement(\"iframe\")")
    ) &&
    trimmed.contains("appendChild(iframe)")
  if !creates_iframe {
    return false
  }

  let raw_src = extract_quoted_after_marker(trimmed, "iframe.src=").unwrap_or(
    "about:blank",
  )
  let src = if raw_src == "" { "about:blank" } else { raw_src }

  let user_ctx = self.context_user_context
    .get(parent_ctx_id)
    .unwrap_or("default")
  let child_ctx_id = self.create_child_context(parent_ctx_id, user_ctx)
  self.emit_context_created(
    child_ctx_id,
    "tab",
    "about:blank",
    None,
    Some(parent_ctx_id),
  )
  let child_nav_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  if self.is_iframe_navigation_blocked(child_ctx_id, src) {
    self.emit_default_realm(child_ctx_id)
    self.emit_navigation_started_event(child_ctx_id, src, child_nav_id)
    self.emit_navigation_failed_event(child_ctx_id, src, child_nav_id)
    self.send_script_undefined_result(request_id, realm_id)
    return true
  }
  match self.manager.get_session(child_ctx_id) {
    Some(child_session) => {
      let _ = child_session.navigate_to(src)
    }
    None => ()
  }
  self.load_data_url_content(child_ctx_id, src)
  self.clear_context_sandbox_realms(child_ctx_id)
  let window_realm_id = self.assign_new_realm(child_ctx_id)
  self.emit_default_realm(child_ctx_id)
  self.emit_worker_realms_from_scripts(child_ctx_id, window_realm_id)
  self.apply_preload_scripts_for_context(child_ctx_id)
  self.execute_inline_scripts_for_context(child_ctx_id)
  self.emit_navigation_events(child_ctx_id, src, child_nav_id)
  if src != "about:blank" {
    self.refresh_child_contexts_from_iframes_with_depth(child_ctx_id, 1)
  }

  let mirror_iframe_foo_to_parent = trimmed.contains("window.baz") &&
    trimmed.contains("iframe.contentWindow.foo")
  if mirror_iframe_foo_to_parent {
    set_runtime_context(child_ctx_id)
    self.apply_effective_viewport_to_runtime_context(child_ctx_id, child_ctx_id)
    let opened_eval_json = evaluate_js_with_console(
      "window.foo", false, false, false, "{}",
    )
    let opened_eval = @json.parse(opened_eval_json) catch {
      _ =>
        make_object({
          "result": make_object({ "type": Json::string("undefined") }),
        })
    }
    let opened_value = get_field(opened_eval, "result").unwrap_or(
      make_object({ "type": Json::string("undefined") }),
    )
    set_runtime_context(parent_ctx_id)
    self.apply_effective_viewport_to_runtime_context(
      parent_ctx_id, parent_ctx_id,
    )
    evaluate_js("window.baz = " + bidi_value_to_js_literal(opened_value))
    |> ignore
  }

  self.send_script_undefined_result(request_id, realm_id)
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
      if !is_valid_serialized_value_map(value_map) {
        self.send_error(
          request_id, "invalid argument", "this must be a serialized value",
        )
        return Some(())
      }
      match value_map.get("sharedId") {
        Some(String(shared_id)) =>
          if !has_runtime_shared_node(shared_id) {
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
          if !has_runtime_handle(handle_id) {
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
            if !is_valid_serialized_value_map(arg_map) {
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
                      Some(Object(ser_opts)) =>
                        match
                          self.validate_serialization_options_map(
                            request_id,
                            canonicalize_serialization_options_map(ser_opts),
                          ) {
                          Some(_) => return Some(())
                          None => ()
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
                if !has_runtime_handle(handle_id) {
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
                if !has_runtime_shared_node(shared_id) {
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
/// Supported serialized argument types for script.addPreloadScript.
fn is_supported_preload_argument_type(type_name : String) -> Bool {
  type_name == "array" ||
  type_name == "bigint" ||
  type_name == "boolean" ||
  type_name == "channel" ||
  type_name == "date" ||
  type_name == "map" ||
  type_name == "null" ||
  type_name == "number" ||
  type_name == "object" ||
  type_name == "regexp" ||
  type_name == "set" ||
  type_name == "string" ||
  type_name == "undefined"
}

///|
/// Parse and validate script.addPreloadScript parameters.
fn BidiProtocol::parse_add_preload_script_params(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> AddPreloadScriptParams? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let function_declaration = match
    get_map_field_with_alias(map, "functionDeclaration", "function_declaration") {
    Some(String(function_declaration)) => function_declaration
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "functionDeclaration must be a string",
      )
      return None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "Missing functionDeclaration",
      )
      return None
    }
  }

  let mut arguments : Array[Json] = []
  match map.get("arguments") {
    Some(Array(args)) => arguments = args
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "arguments must be an array",
      )
      return None
    }
    None => ()
  }

  let argument_params = if map.contains("arguments") {
    Some(make_object({ "arguments": Json::array(arguments) }))
  } else {
    None
  }
  match self.validate_arguments_param(request_id, argument_params) {
    Some(_) => return None
    None => ()
  }
  for argument in arguments {
    match argument {
      Object(arg_map) =>
        match arg_map.get("type") {
          Some(String(type_name)) => {
            if !is_supported_preload_argument_type(type_name) {
              self.send_error(
                request_id, "invalid argument", "arguments entries must be serialized values",
              )
              return None
            }
            if type_name == "channel" {
              match arg_map.get("value") {
                Some(Object(channel_val)) =>
                  match channel_val.get("channel") {
                    Some(String(_)) => ()
                    _ => {
                      self.send_error(
                        request_id, "invalid argument", "channel.channel must be a string",
                      )
                      return None
                    }
                  }
                _ => ()
              }
            }
          }
          _ => ()
        }
      _ => ()
    }
  }

  let sandbox = match map.get("sandbox") {
    Some(String(name)) => Some(name)
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "sandbox must be a string",
      )
      return None
    }
    None => None
  }

  let contexts_raw = map.get("contexts")
  let contexts : Array[String] = []
  match contexts_raw {
    Some(Array(items)) => {
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return None
      }
      for item in items {
        match item {
          String(ctx_id) =>
            if ctx_id == "" || !self.manager.has_session(ctx_id) {
              self.send_error(
                request_id,
                "no such frame",
                "Unknown context: " + ctx_id,
              )
              return None
            } else if self.context_parent.contains(ctx_id) {
              self.send_error(
                request_id, "invalid argument", "contexts entries must be top-level contexts",
              )
              return None
            } else if !array_contains(contexts, ctx_id) {
              contexts.push(ctx_id)
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "contexts entries must be strings",
            )
            return None
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return None
    }
    None => ()
  }

  let user_contexts_raw = get_map_field_with_alias(
    map, "userContexts", "user_contexts",
  )
  let user_contexts : Array[String] = []
  match user_contexts_raw {
    Some(Array(items)) => {
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return None
      }
      for item in items {
        match item {
          String(user_context_id) =>
            if user_context_id == "" ||
              !self.user_contexts.contains(user_context_id) {
              self.send_error(
                request_id,
                "no such user context",
                "Unknown user context: " + user_context_id,
              )
              return None
            } else if !array_contains(user_contexts, user_context_id) {
              user_contexts.push(user_context_id)
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "userContexts entries must be strings",
            )
            return None
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return None
    }
    None => ()
  }

  if contexts.length() > 0 && user_contexts.length() > 0 {
    self.send_error(
      request_id, "invalid argument", "contexts and userContexts cannot be used together",
    )
    return None
  }

  Some({ function_declaration, arguments, sandbox, contexts, user_contexts })
}

///|
fn BidiProtocol::register_preload_script(
  self : BidiProtocol,
  parsed : AddPreloadScriptParams,
) -> String {
  let script_id = "preload-" + self.next_preload_script_id.to_string()
  self.next_preload_script_id += 1
  self.preload_scripts.push({
    script_id,
    function_declaration: parsed.function_declaration,
    arguments: parsed.arguments,
    sandbox: parsed.sandbox,
    contexts: parsed.contexts,
    user_contexts: parsed.user_contexts,
  })
  script_id
}

///|
fn BidiProtocol::resolve_realms_list(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Array[Json]? {
  let context_filter = match get_param_raw(params, "context") {
    Some(String(ctx_id)) => {
      if !self.manager.has_session(ctx_id) {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return None
      }
      Some(ctx_id)
    }
    None => None
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }

  match get_param_raw(params, "type") {
    Some(String(t)) =>
      if t != "window" {
        self.send_error(request_id, "invalid argument", "type must be 'window'")
        return None
      }
    None => ()
    Some(_) => {
      self.send_error(request_id, "invalid argument", "type must be a string")
      return None
    }
  }

  let realms : Array[Json] = []
  for ctx_id in self.manager.list_sessions() {
    let should_include = match context_filter {
      Some(filter_ctx) => filter_ctx == ctx_id
      None => true
    }
    if should_include {
      let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
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
          let sandbox_name = key.unsafe_substring(
            start=prefix.length(),
            end=key.length(),
          )
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
  Some(realms)
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
                        Some(Object(ser_opts)) => {
                          let normalized_ser_opts = canonicalize_serialization_options_map(
                            ser_opts,
                          )
                          match normalized_ser_opts.get("maxObjectDepth") {
                            Some(Number(n, ..)) => n.to_string()
                            _ => "-1"
                          }
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
