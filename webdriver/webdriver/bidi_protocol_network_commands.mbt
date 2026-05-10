///|
/// Handle network.addIntercept
fn BidiProtocol::handle_network_add_intercept(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let options = match
    self.validate_network_add_intercept_params(request_id, params) {
    Some(options) => options
    None => return
  }
  let intercept_id = left_pad_with_zero(
    self.next_network_intercept_id.to_string(),
    32,
  )
  self.next_network_intercept_id += 1
  self.network_intercepts[intercept_id] = make_object(options)
  self.send_success(
    request_id,
    Some(make_object({ "intercept": Json::string(intercept_id) })),
  )
}

///|
fn BidiProtocol::handle_network_add_intercept_id(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let options = match
    self.validate_network_add_intercept_params(request_id, params) {
    Some(options) => options
    None => return
  }
  let intercept_id = left_pad_with_zero(
    self.next_network_intercept_id.to_string(),
    32,
  )
  self.next_network_intercept_id += 1
  self.network_intercepts[intercept_id] = make_object(options)
  self.send_success(request_id, Some(Json::string(intercept_id)))
}

///|
/// Handle network.removeIntercept
fn BidiProtocol::handle_network_remove_intercept(
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
  let intercept_id = match map.get("intercept") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "intercept must be a string",
      )
      return
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing intercept")
      return
    }
  }
  if !self.network_intercepts.contains(intercept_id) {
    self.send_error(
      request_id,
      "no such intercept",
      "Unknown intercept: " + intercept_id,
    )
    return
  }
  self.network_intercepts.remove(intercept_id)
  self.send_success(request_id, Some(make_object({})))
}

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
    self.next_network_data_collector_id.to_string()
  self.next_network_data_collector_id += 1
  self.network_data_collectors[collector_id] = make_object(options)
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
    self.next_network_data_collector_id.to_string()
  self.next_network_data_collector_id += 1
  self.network_data_collectors[collector_id] = make_object(options)
  self.send_success(request_id, Some(Json::string(collector_id)))
}

///|
/// Handle network.setExtraHeaders
fn BidiProtocol::handle_network_set_extra_headers(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.validate_network_set_extra_headers_params(request_id, params) {
    Some(options) => {
      self.apply_network_extra_headers_options(options)
      self.send_success(request_id, Some(make_object({})))
    }
    None => ()
  }
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
  if !self.network_data_collectors.contains(collector_id) {
    self.send_error(
      request_id,
      "no such network collector",
      "Unknown network collector: " + collector_id,
    )
    return
  }
  self.network_data_collectors.remove(collector_id)
  let request_keys : Array[String] = []
  for request_key, _ in self.network_collected_data {
    request_keys.push(request_key)
  }
  for request_key in request_keys {
    match self.network_collected_data.get(request_key) {
      Some(request_bucket) => {
        let next_bucket = request_bucket
        next_bucket.remove(collector_id)
        if next_bucket.length() == 0 {
          self.network_collected_data.remove(request_key)
        } else {
          self.network_collected_data[request_key] = next_bucket
        }
      }
      None => ()
    }
  }
  self.send_success(request_id, Some(make_object({})))
}
