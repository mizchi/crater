///|
fn BidiProtocol::normalize_synthetic_network_cookie_entries(
  self : BidiProtocol,
  request_id : Int,
  raw_cookies : Json?,
) -> @crater_network.SyntheticNetworkCookieOverride? {
  match
    @crater_network.synthetic_network_normalize_request_cookie_entries(
      raw_cookies,
    ) {
    Ok(cookies) => Some(cookies)
    Err(message) => {
      self.send_error(request_id, "invalid argument", message)
      None
    }
  }
}

///|
fn BidiProtocol::normalize_synthetic_network_continue_url(
  self : BidiProtocol,
  request_id : Int,
  raw_url : Json,
) -> String? {
  match @crater_network.synthetic_network_normalize_continue_url(raw_url) {
    Ok(url) => Some(url)
    Err(message) => {
      self.send_error(request_id, "invalid argument", message)
      None
    }
  }
}

///|
fn BidiProtocol::normalize_synthetic_network_string_list(
  self : BidiProtocol,
  request_id : Int,
  raw_list : Json?,
  field_name : String,
) -> Array[String]? {
  match
    @crater_network.synthetic_network_normalize_string_list(
      raw_list, field_name,
    ) {
    Ok(values) => Some(values)
    Err(message) => {
      self.send_error(request_id, "invalid argument", message)
      None
    }
  }
}

///|
fn BidiProtocol::normalize_synthetic_network_response_overrides(
  self : BidiProtocol,
  request_id : Int,
  raw_overrides : Json?,
) -> @crater_network.SyntheticNetworkResponseOverrides? {
  match
    @crater_network.synthetic_network_normalize_response_overrides(
      raw_overrides,
    ) {
    Ok(overrides) => Some(overrides)
    Err(message) => {
      self.send_error(request_id, "invalid argument", message)
      None
    }
  }
}
