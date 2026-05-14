///|
fn BidiProtocol::normalize_synthetic_network_continue_credentials(
  self : BidiProtocol,
  request_id : Int,
  raw_credentials : Json,
) -> @crater_network.SyntheticNetworkContinueCredentials? {
  match
    @crater_network.synthetic_network_normalize_continue_credentials(
      raw_credentials,
    ) {
    Ok(credentials) => Some(credentials)
    Err(message) => {
      self.send_error(request_id, "invalid argument", message)
      None
    }
  }
}

///|
fn BidiProtocol::normalize_synthetic_network_bytes_value(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json,
  field_name : String,
) -> Json? {
  match
    @crater_network.synthetic_network_normalize_bytes_value(
      raw_value, field_name,
    ) {
    Ok(value) => Some(value)
    Err(message) => {
      self.send_error(request_id, "invalid argument", message)
      None
    }
  }
}

///|
fn BidiProtocol::synthetic_network_text_from_bytes_value(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json,
  field_name : String,
) -> String? {
  match
    @crater_network.synthetic_network_text_from_bytes_value(
      raw_value, field_name,
    ) {
    Ok(value) => Some(value)
    Err(message) => {
      self.send_error(request_id, "invalid argument", message)
      None
    }
  }
}

///|
fn BidiProtocol::synthetic_network_string_from_bytes_value(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json,
  field_name : String,
) -> String? {
  match
    @crater_network.synthetic_network_string_from_bytes_value(
      raw_value, field_name,
    ) {
    Ok(value) => Some(value)
    Err(message) => {
      self.send_error(request_id, "invalid argument", message)
      None
    }
  }
}

///|
fn synthetic_network_credentials_match_expected(
  url : String,
  credentials : @crater_network.SyntheticNetworkContinueCredentials?,
) -> Bool {
  @crater_network.synthetic_network_credentials_match_expected(url, credentials)
}
