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
    self.remove_network_collected_data_internal(
      request_token, selected_collector, data_type,
    )
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
  self.remove_network_collected_data_internal(
    request_token, collector_id, data_type,
  )
  self.send_success(request_id, Some(make_object({})))
}
