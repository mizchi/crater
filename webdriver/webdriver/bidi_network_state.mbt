///|
/// WebDriver BiDi network runtime state.
priv struct BidiNetworkState {
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
fn BidiNetworkState::new() -> BidiNetworkState {
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

///|
fn BidiProtocol::handle_network_allocate_request_id(
  self : BidiProtocol,
  request_id : Int,
  _params : Json?,
) -> Unit {
  self.send_success(
    request_id,
    Some(
      make_object({
        "request": Json::string(self.next_synthetic_network_request_id()),
      }),
    ),
  )
}

///|
fn BidiProtocol::handle_network_remember_collected_data(
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
  let context_id = match map.get("context") {
    Some(String(context_id)) => context_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  let request_token = match map.get("request") {
    Some(String(request_token)) => request_token
    _ => {
      self.send_error(
        request_id, "invalid argument", "request must be a string",
      )
      return
    }
  }
  let request_value = match
    get_map_field_with_alias(map, "requestData", "request_data") {
    Some(raw_value) =>
      match
        self.normalize_synthetic_network_bytes_value(
          request_id, raw_value, "requestData",
        ) {
        Some(value) => Some(value)
        None => return
      }
    None => None
  }
  let response_value = match
    get_map_field_with_alias(map, "responseData", "response_data") {
    Some(raw_value) =>
      match
        self.normalize_synthetic_network_bytes_value(
          request_id, raw_value, "responseData",
        ) {
        Some(value) => Some(value)
        None => return
      }
    None => None
  }

  self.remember_network_collected_data_internal(
    context_id, request_token, request_value, response_value,
  )
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::handle_network_get_data(
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
  let request_token = match map.get("request") {
    Some(String(request_token)) => request_token
    _ => {
      self.send_error(
        request_id, "invalid argument", "request must be a string",
      )
      return
    }
  }
  let data_type = match get_map_field_with_alias(map, "dataType", "data_type") {
    Some(String(data_type)) =>
      if data_type == "request" || data_type == "response" {
        data_type
      } else {
        self.send_error(request_id, "invalid argument", "dataType is invalid")
        return
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "dataType must be a string",
      )
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing dataType")
      return
    }
  }
  let collector_id : String? = match map.get("collector") {
    Some(Null) | None => None
    Some(String(collector_id)) => Some(collector_id)
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "collector must be a string",
      )
      return
    }
  }
  let disown = match map.get("disown") {
    Some(True) => true
    Some(False) | None => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "disown must be a boolean",
      )
      return
    }
  }
  if disown && collector_id == None {
    self.send_error(
      request_id, "invalid argument", "disown=true requires collector",
    )
    return
  }
  let request_bucket = match
    self.network_state.network_collected_data.get(request_token) {
    Some(request_bucket) => request_bucket
    None => {
      self.send_error(
        request_id,
        "no such network data",
        "Unknown request id: " + request_token,
      )
      return
    }
  }
  let (selected_collector, result) = match collector_id {
    Some(collector_id) => {
      if !self.network_state.network_data_collectors.contains(collector_id) {
        self.send_error(
          request_id,
          "no such network collector",
          "Unknown collector: " + collector_id,
        )
        return
      }
      match request_bucket.get(collector_id) {
        Some(collector_bucket) =>
          match collector_bucket.get(data_type) {
            Some(result) => (collector_id, result)
            None => {
              self.send_error(
                request_id,
                "no such network data",
                "No collected " + data_type + " for request: " + request_token,
              )
              return
            }
          }
        None => {
          self.send_error(
            request_id,
            "no such network data",
            "No collected " + data_type + " for request: " + request_token,
          )
          return
        }
      }
    }
    None => {
      let mut found : (String, Json)? = None
      for candidate_collector in self.list_active_network_collector_ids() {
        match request_bucket.get(candidate_collector) {
          Some(collector_bucket) =>
            match collector_bucket.get(data_type) {
              Some(result) => {
                found = Some((candidate_collector, result))
                break
              }
              None => ()
            }
          None => ()
        }
      }
      match found {
        Some(found) => found
        None => {
          self.send_error(
            request_id,
            "no such network data",
            "No collected " + data_type + " for request: " + request_token,
          )
          return
        }
      }
    }
  }
  if disown {
    match self.network_state.network_collected_data.get(request_token) {
      Some(bucket) =>
        match bucket.get(selected_collector) {
          Some(collector_bucket) => {
            let next_collector_bucket = collector_bucket
            next_collector_bucket.remove(data_type)
            let next_bucket = bucket
            if next_collector_bucket.length() == 0 {
              next_bucket.remove(selected_collector)
            } else {
              next_bucket[selected_collector] = next_collector_bucket
            }
            if next_bucket.length() == 0 {
              self.network_state.network_collected_data.remove(request_token)
            } else {
              self.network_state.network_collected_data[request_token] = next_bucket
            }
          }
          None => ()
        }
      None => ()
    }
  }
  self.send_success(request_id, Some(result))
}

///|
fn BidiProtocol::handle_network_disown_data(
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
  let request_token = match map.get("request") {
    Some(String(request_token)) => request_token
    _ => {
      self.send_error(
        request_id, "invalid argument", "request must be a string",
      )
      return
    }
  }
  let data_type = match get_map_field_with_alias(map, "dataType", "data_type") {
    Some(String(data_type)) =>
      if data_type == "request" || data_type == "response" {
        data_type
      } else {
        self.send_error(request_id, "invalid argument", "dataType is invalid")
        return
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "dataType must be a string",
      )
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing dataType")
      return
    }
  }
  let collector_id = match map.get("collector") {
    Some(String(collector_id)) => collector_id
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "collector must be a string",
      )
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing collector")
      return
    }
  }
  if !self.network_state.network_data_collectors.contains(collector_id) {
    self.send_error(
      request_id,
      "no such network collector",
      "Unknown collector: " + collector_id,
    )
    return
  }
  let request_bucket = match
    self.network_state.network_collected_data.get(request_token) {
    Some(request_bucket) => request_bucket
    None => {
      self.send_error(
        request_id,
        "no such network data",
        "Unknown request id: " + request_token,
      )
      return
    }
  }
  let collector_bucket = match request_bucket.get(collector_id) {
    Some(collector_bucket) => collector_bucket
    None => {
      self.send_error(
        request_id,
        "no such network data",
        "No collected " + data_type + " for request: " + request_token,
      )
      return
    }
  }
  if !collector_bucket.contains(data_type) {
    self.send_error(
      request_id,
      "no such network data",
      "No collected " + data_type + " for request: " + request_token,
    )
    return
  }
  let next_collector_bucket = collector_bucket
  next_collector_bucket.remove(data_type)
  let next_bucket = request_bucket
  if next_collector_bucket.length() == 0 {
    next_bucket.remove(collector_id)
  } else {
    next_bucket[collector_id] = next_collector_bucket
  }
  if next_bucket.length() == 0 {
    self.network_state.network_collected_data.remove(request_token)
  } else {
    self.network_state.network_collected_data[request_token] = next_bucket
  }
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::next_synthetic_network_request_id(
  self : BidiProtocol,
) -> String {
  let request_id = "request-" +
    self.network_state.next_network_request_id.to_string()
  self.network_state.next_network_request_id += 1
  request_id
}

///|
fn BidiProtocol::remember_network_collected_data_internal(
  self : BidiProtocol,
  context_id : String,
  request_token : String,
  request_value : Json?,
  response_value : Json?,
) -> Unit {
  let request_bucket = self.network_state.network_collected_data
    .get(request_token)
    .unwrap_or({})
  let ancestry = self.build_context_scope_ancestry_for_matching(context_id)
  let user_context = self.context_user_context
    .get(context_id)
    .unwrap_or("default")
  let next_bucket = request_bucket
  for collector_id in self.list_active_network_collector_ids() {
    match self.network_state.network_data_collectors.get(collector_id) {
      Some(Object(options)) =>
        if network_collector_matches_scope(options, ancestry, user_context) {
          let collector_bucket = next_bucket.get(collector_id).unwrap_or({})
          let data_types = network_collector_data_types(options)
          let max_size = network_collector_max_encoded_size(options)
          let next_collector_bucket = collector_bucket
          match request_value {
            Some(request_data) =>
              if array_contains_string(data_types, "request") &&
                network_bytes_value_encoded_size(request_data) <= max_size {
                next_collector_bucket["request"] = request_data
              }
            None => ()
          }
          match response_value {
            Some(response_data) =>
              if array_contains_string(data_types, "response") &&
                network_bytes_value_encoded_size(response_data) <= max_size {
                next_collector_bucket["response"] = response_data
              }
            None => ()
          }
          if next_collector_bucket.length() > 0 {
            next_bucket[collector_id] = next_collector_bucket
          }
        }
      _ => ()
    }
  }
  self.network_state.network_collected_data[request_token] = next_bucket
}

///|
fn BidiProtocol::list_active_network_collector_ids(
  self : BidiProtocol,
) -> Array[String] {
  let ids : Array[String] = []
  for i = 1; i < self.network_state.next_network_data_collector_id; i = i + 1 {
    let collector_id = "collector-" + i.to_string()
    if self.network_state.network_data_collectors.contains(collector_id) {
      ids.push(collector_id)
    }
  }
  ids
}

///|
fn network_collector_matches_scope(
  options : Map[String, Json],
  ancestry : Array[String],
  user_context : String,
) -> Bool {
  match options.get("contexts") {
    Some(Array(contexts)) =>
      if contexts.length() > 0 {
        let mut matched = false
        for item in contexts {
          match item {
            String(ctx_id) if array_contains_string(ancestry, ctx_id) => {
              matched = true
              break
            }
            _ => ()
          }
        }
        if !matched {
          return false
        }
      }
    _ => ()
  }
  match options.get("userContexts") {
    Some(Array(user_contexts)) =>
      if user_contexts.length() > 0 {
        let mut matched = false
        for item in user_contexts {
          match item {
            String(candidate) if candidate == user_context => {
              matched = true
              break
            }
            _ => ()
          }
        }
        if !matched {
          return false
        }
      }
    _ => ()
  }
  true
}

///|
fn network_collector_data_types(options : Map[String, Json]) -> Array[String] {
  let data_types : Array[String] = []
  match options.get("dataTypes") {
    Some(Array(items)) =>
      for item in items {
        match item {
          String(name) => data_types.push(name)
          _ => ()
        }
      }
    _ => ()
  }
  data_types
}

///|
fn network_collector_max_encoded_size(options : Map[String, Json]) -> Int {
  match options.get("maxEncodedDataSize") {
    Some(Number(n, ..)) => n.to_int()
    _ => 1000
  }
}

///|
fn network_bytes_value_encoded_size(value : Json) -> Int {
  match value {
    Object(map) =>
      match map.get("value") {
        Some(String(payload)) => js_utf8_byte_length(payload)
        _ => 0
      }
    _ => 0
  }
}
