///|
/// Handle network.addDataCollector
fn BidiProtocol::handle_network_add_data_collector(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let options = match
    self.validate_network_add_data_collector_params(request_id, params) {
    Some(options) => options
    None => return
  }
  let collector_id = "collector-" +
    self.network_state.next_network_data_collector_id.to_string()
  self.network_state.next_network_data_collector_id += 1
  self.network_state.network_data_collectors[collector_id] = make_object(
    options,
  )
  self.send_success(
    request_id,
    Some(make_object({ "collector": Json::string(collector_id) })),
  )
}

///|
fn BidiProtocol::handle_network_add_data_collector_id(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let options = match
    self.validate_network_add_data_collector_params(request_id, params) {
    Some(options) => options
    None => return
  }
  let collector_id = "collector-" +
    self.network_state.next_network_data_collector_id.to_string()
  self.network_state.next_network_data_collector_id += 1
  self.network_state.network_data_collectors[collector_id] = make_object(
    options,
  )
  self.send_success(request_id, Some(Json::string(collector_id)))
}

///|
/// Handle network.removeDataCollector
fn BidiProtocol::handle_network_remove_data_collector(
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
  let collector_id = match map.get("collector") {
    Some(String(id)) => id
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
      "Unknown network collector: " + collector_id,
    )
    return
  }
  self.network_state.network_data_collectors.remove(collector_id)
  let request_keys : Array[String] = []
  for request_key, _ in self.network_state.network_collected_data {
    request_keys.push(request_key)
  }
  for request_key in request_keys {
    match self.network_state.network_collected_data.get(request_key) {
      Some(request_bucket) => {
        let next_bucket = request_bucket
        next_bucket.remove(collector_id)
        if next_bucket.length() == 0 {
          self.network_state.network_collected_data.remove(request_key)
        } else {
          self.network_state.network_collected_data[request_key] = next_bucket
        }
      }
      None => ()
    }
  }
  self.send_success(request_id, Some(make_object({})))
}
