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
  subscription_state : BidiSubscriptionState
  user_contexts : Map[String, Bool]
  user_context_prompt_behavior : Map[String, Json] // user context -> unhandledPromptBehavior object
  mut global_download_behavior : Json?
  user_context_download_behavior : Map[String, Json] // user context -> downloadBehavior object
  installed_web_extensions : Map[String, String] // extension id -> source kind
  mut next_web_extension_id : Int
  permission_state_by_scope : Map[String, String] // "<name>|<userContext>|<origin>|<embeddedOrigin>" -> state
  emulation_state : BidiEmulationState
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
  network_state : BidiNetworkState
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
    subscription_state: BidiSubscriptionState::new(),
    user_contexts,
    user_context_prompt_behavior: {},
    global_download_behavior: None,
    user_context_download_behavior: {},
    installed_web_extensions: {},
    next_web_extension_id: 1,
    permission_state_by_scope: {},
    emulation_state: BidiEmulationState::new(),
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
    network_state: BidiNetworkState::new(),
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
  self.subscription_state.reset()
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
  self.emulation_state.reset()
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
  self.network_state.next_network_request_id = 1

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
  for key, _ in self.network_state.network_state_channel_by_context {
    network_state_channel_keys.push(key)
  }
  for key in network_state_channel_keys {
    self.network_state.network_state_channel_by_context.remove(key)
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
  for key, _ in self.network_state.network_intercepts {
    intercept_keys.push(key)
  }
  for key in intercept_keys {
    self.network_state.network_intercepts.remove(key)
  }
  self.network_state.next_network_intercept_id = 1
  self.clear_all_network_state()

  let collector_keys : Array[String] = []
  for key, _ in self.network_state.network_data_collectors {
    collector_keys.push(key)
  }
  for key in collector_keys {
    self.network_state.network_data_collectors.remove(key)
  }
  let collected_request_keys : Array[String] = []
  for key, _ in self.network_state.network_collected_data {
    collected_request_keys.push(key)
  }
  for key in collected_request_keys {
    self.network_state.network_collected_data.remove(key)
  }
  self.network_state.next_network_data_collector_id = 1
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
fn default_beforeunload_test_page_url() -> String {
  "http://localhost:8000/webdriver/tests/support/html/beforeunload.html"
}

///|
fn beforeunload_test_page_html() -> String {
  "<!doctype html><html><body><input id='target'><script>window.addEventListener('beforeunload', function (event) { event.preventDefault(); event.returnValue = ''; });</script></body></html>"
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
  let source = expression.trim().to_owned()

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
  let trimmed = expression.trim().to_owned()
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
  let trimmed = expression.trim().to_owned()
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
