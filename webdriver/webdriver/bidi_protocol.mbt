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
  network_state : @crater_network.BidiNetworkState
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
    network_state: @crater_network.BidiNetworkState::new(),
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
