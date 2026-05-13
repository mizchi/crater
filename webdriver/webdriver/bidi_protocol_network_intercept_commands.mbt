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
    self.network_state.next_network_intercept_id.to_string(),
    32,
  )
  self.network_state.next_network_intercept_id += 1
  self.network_state.network_intercepts[intercept_id] = make_object(options)
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
    self.network_state.next_network_intercept_id.to_string(),
    32,
  )
  self.network_state.next_network_intercept_id += 1
  self.network_state.network_intercepts[intercept_id] = make_object(options)
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
  if !self.network_state.network_intercepts.contains(intercept_id) {
    self.send_error(
      request_id,
      "no such intercept",
      "Unknown intercept: " + intercept_id,
    )
    return
  }
  self.network_state.network_intercepts.remove(intercept_id)
  self.send_success(request_id, Some(make_object({})))
}
