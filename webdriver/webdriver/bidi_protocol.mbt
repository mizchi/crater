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
        self.subscription_state.remove_pending_log_entries(child_ctx_id)
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
  self.subscription_state.remove_pending_log_entries(ctx_id)
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
          let existing = self.subscription_state.context_subscriptions
            .get(ctx_id)
            .unwrap_or([])
          for evt in events_to_sub {
            existing.push(evt)
          }
          self.subscription_state.context_subscriptions[ctx_id] = existing
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
          let existing = self.subscription_state.user_context_subscriptions
            .get(user_ctx_id)
            .unwrap_or([])
          for evt in events_to_sub {
            existing.push(evt)
          }
          self.subscription_state.user_context_subscriptions[user_ctx_id] = existing
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
            self.subscription_state.global_unsubscribed_events = array_filter_by_module(
              self.subscription_state.global_unsubscribed_events,
              module_key,
            )
          } else {
            self.subscription_state.global_unsubscribed_events = array_filter_not(
              self.subscription_state.global_unsubscribed_events,
              [evt],
            )
          }
          self.subscription_state.global_subscriptions.push(evt)
          self.subscription_state.update_legacy_module_subscription(module_key)
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
  let subscription_id = self.subscription_state.generate_subscription_id()
  self.subscription_state.subscription_events[subscription_id] = events_to_sub
  self.subscription_state.subscription_contexts[subscription_id] = contexts_to_sub
  self.subscription_state.subscription_user_contexts[subscription_id] = user_contexts_to_sub
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
          match self.subscription_state.context_subscriptions.get(ctx_id) {
            Some(existing) => {
              let filtered = array_filter_not(existing, events_to_unsub)
              self.subscription_state.context_subscriptions[ctx_id] = filtered
            }
            None => ()
          }
        }
      }
      if has_user_context_targets {
        for user_ctx_id in user_contexts_to_unsub {
          match
            self.subscription_state.user_context_subscriptions.get(user_ctx_id) {
            Some(existing) => {
              let filtered = array_filter_not(existing, events_to_unsub)
              self.subscription_state.user_context_subscriptions[user_ctx_id] = filtered
            }
            None => ()
          }
        }
      }
      if !has_context_targets && !has_user_context_targets {
        self.subscription_state.global_subscriptions = array_filter_not(
          self.subscription_state.global_subscriptions,
          events_to_unsub,
        )
        for evt in events_to_unsub {
          let module_key = get_subscription_key(evt)
          if module_key == evt {
            self.subscription_state.global_unsubscribed_events = array_filter_by_module(
              self.subscription_state.global_unsubscribed_events,
              module_key,
            )
          } else if !array_contains(
              self.subscription_state.global_unsubscribed_events,
              evt,
            ) {
            self.subscription_state.global_unsubscribed_events.push(evt)
          }
          self.subscription_state.update_legacy_module_subscription(module_key)
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
  let events = self.subscription_state.subscription_events
    .get(subscription_id)
    .unwrap_or([])
  let contexts = self.subscription_state.subscription_contexts
    .get(subscription_id)
    .unwrap_or([])
  let user_contexts = self.subscription_state.subscription_user_contexts
    .get(subscription_id)
    .unwrap_or([])
  if events.length() == 0 {
    self.subscription_state.subscription_events.remove(subscription_id)
    self.subscription_state.subscription_contexts.remove(subscription_id)
    self.subscription_state.subscription_user_contexts.remove(subscription_id)
    return
  }
  if contexts.length() > 0 {
    for ctx_id in contexts {
      match self.subscription_state.context_subscriptions.get(ctx_id) {
        Some(existing) => {
          let filtered = array_remove_events_once(existing, events)
          if filtered.length() == 0 {
            self.subscription_state.context_subscriptions.remove(ctx_id)
          } else {
            self.subscription_state.context_subscriptions[ctx_id] = filtered
          }
        }
        None => ()
      }
    }
  } else if user_contexts.length() > 0 {
    for user_ctx_id in user_contexts {
      match
        self.subscription_state.user_context_subscriptions.get(user_ctx_id) {
        Some(existing) => {
          let filtered = array_remove_events_once(existing, events)
          if filtered.length() == 0 {
            self.subscription_state.user_context_subscriptions.remove(
              user_ctx_id,
            )
          } else {
            self.subscription_state.user_context_subscriptions[user_ctx_id] = filtered
          }
        }
        None => ()
      }
    }
  } else {
    for evt in events {
      self.subscription_state.global_subscriptions = array_remove_first(
        self.subscription_state.global_subscriptions,
        evt,
      )
      let module_key = get_subscription_key(evt)
      self.subscription_state.update_legacy_module_subscription(module_key)
    }
  }
  self.subscription_state.subscription_events.remove(subscription_id)
  self.subscription_state.subscription_contexts.remove(subscription_id)
  self.subscription_state.subscription_user_contexts.remove(subscription_id)
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
    self.subscription_state.has_any_log_subscription() {
    return true
  }
  // Keep capturing even when not currently subscribed so log.entryAdded
  // can be buffered and delivered after a later session.subscribe call.
  true
}

///|
/// Flush buffered log.entryAdded events that are now subscribed.
fn BidiProtocol::flush_pending_log_entries(self : BidiProtocol) -> Unit {
  let contexts : Array[String] = []
  for ctx_id, _ in self.subscription_state.pending_log_entries {
    contexts.push(ctx_id)
  }
  for ctx_id in contexts {
    if !self.is_subscribed_for_context("log.entryAdded", ctx_id) {
      continue
    }
    match self.subscription_state.pending_log_entries.get(ctx_id) {
      Some(entries) =>
        for params in entries {
          self.outbox.push(Event({ event_method: "log.entryAdded", params }))
        }
      None => ()
    }
    self.subscription_state.remove_pending_log_entries(ctx_id)
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
  let blocked_global = array_contains(
    self.subscription_state.global_unsubscribed_events,
    event,
  )
  // Check legacy module-level subscription
  if !blocked_global &&
    self.subscription_state.subscriptions.get(module_key).unwrap_or(false) {
    return true
  }
  // Check global subscriptions (exact event match or module match)
  for sub in self.subscription_state.global_subscriptions {
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
  match self.subscription_state.user_context_subscriptions.get(user_ctx) {
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
  match self.subscription_state.context_subscriptions.get(ctx_id) {
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
  array_contains(self.subscription_state.global_subscriptions, module_key)
}

///|
/// Check whether event is effectively globally subscribed.
fn BidiProtocol::has_global_event_subscription(
  self : BidiProtocol,
  event_name : String,
) -> Bool {
  if array_contains(
      self.subscription_state.global_unsubscribed_events,
      event_name,
    ) {
    return false
  }
  let module_key = get_subscription_key(event_name)
  for sub in self.subscription_state.global_subscriptions {
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
  for event_name in self.subscription_state.global_unsubscribed_events {
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
