///|
/// WebDriver BiDi network runtime state.
pub(all) struct BidiNetworkState {
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
}

///|
pub fn BidiNetworkState::new() -> BidiNetworkState {
  {
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
  }
}
