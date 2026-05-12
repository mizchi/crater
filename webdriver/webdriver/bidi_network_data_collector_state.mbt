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
fn BidiProtocol::remove_network_collected_data_internal(
  self : BidiProtocol,
  request_token : String,
  collector_id : String,
  data_type : String,
) -> Unit {
  match self.network_state.network_collected_data.get(request_token) {
    Some(bucket) =>
      match bucket.get(collector_id) {
        Some(collector_bucket) => {
          let next_collector_bucket = collector_bucket
          next_collector_bucket.remove(data_type)
          let next_bucket = bucket
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
        }
        None => ()
      }
    None => ()
  }
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
