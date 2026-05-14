///|
fn BidiProtocol::normalize_synthetic_network_continue_credentials(
  self : BidiProtocol,
  request_id : Int,
  raw_credentials : Json,
) -> @crater_network.SyntheticNetworkContinueCredentials? {
  let map = match raw_credentials {
    Object(map) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "credentials must be an object",
      )
      return None
    }
  }
  let credential_type = match map.get("type") {
    Some(String(credential_type)) => credential_type
    _ => {
      self.send_error(
        request_id, "invalid argument", "credentials.type must be a string",
      )
      return None
    }
  }
  if credential_type != "password" {
    self.send_error(
      request_id, "invalid argument", "credentials.type is invalid",
    )
    return None
  }
  let username = match map.get("username") {
    Some(String(username)) => username
    _ => {
      self.send_error(
        request_id, "invalid argument", "credentials.username must be a string",
      )
      return None
    }
  }
  let password = match map.get("password") {
    Some(String(password)) => password
    _ => {
      self.send_error(
        request_id, "invalid argument", "credentials.password must be a string",
      )
      return None
    }
  }
  Some({ username, password })
}

///|
fn BidiProtocol::normalize_synthetic_network_bytes_value(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json,
  field_name : String,
) -> Json? {
  let map = match raw_value {
    Object(map) => map
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + " must be an object",
      )
      return None
    }
  }
  let value_type = match map.get("type") {
    Some(String(value_type)) => value_type
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".type must be a string",
      )
      return None
    }
  }
  if value_type != "string" && value_type != "base64" {
    self.send_error(
      request_id,
      "invalid argument",
      field_name + ".type is invalid",
    )
    return None
  }
  let payload = match map.get("value") {
    Some(String(payload)) => payload
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".value must be a string",
      )
      return None
    }
  }
  Some(
    make_object({
      "type": Json::string(value_type),
      "value": Json::string(payload),
    }),
  )
}

///|
fn BidiProtocol::synthetic_network_text_from_bytes_value(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json,
  field_name : String,
) -> String? {
  let map = match raw_value {
    Object(map) => map
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + " must be an object",
      )
      return None
    }
  }
  let value_type = match map.get("type") {
    Some(String(value_type)) => value_type
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".type must be a string",
      )
      return None
    }
  }
  let payload = match map.get("value") {
    Some(String(payload)) => payload
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".value must be a string",
      )
      return None
    }
  }
  if value_type == "string" {
    return Some(payload)
  }
  if value_type == "base64" {
    return Some(decode_base64(payload))
  }
  self.send_error(
    request_id,
    "invalid argument",
    field_name + ".type is invalid",
  )
  None
}

///|
fn BidiProtocol::synthetic_network_string_from_bytes_value(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json,
  field_name : String,
) -> String? {
  let map = match raw_value {
    Object(map) => map
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + " must be an object",
      )
      return None
    }
  }
  let value_type = match map.get("type") {
    Some(String(value_type)) => value_type
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".type must be a string",
      )
      return None
    }
  }
  if value_type != "string" {
    self.send_error(
      request_id,
      "invalid argument",
      field_name + ".type is invalid",
    )
    return None
  }
  match map.get("value") {
    Some(String(payload)) => Some(payload)
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".value must be a string",
      )
      None
    }
  }
}

///|
fn synthetic_network_credentials_match_expected(
  url : String,
  credentials : @crater_network.SyntheticNetworkContinueCredentials?,
) -> Bool {
  match credentials {
    Some(credentials) =>
      match synthetic_network_expected_auth_credentials(url) {
        Some(expected) =>
          credentials.username == expected.username &&
          credentials.password == expected.password
        None => true
      }
    None => false
  }
}

///|
fn synthetic_network_expected_auth_credentials(
  url : String,
) -> @crater_network.SyntheticNetworkContinueCredentials? {
  let username = synthetic_network_first_query_value(url, "username")
  let password = synthetic_network_first_query_value(url, "password")
  match (username, password) {
    (Some(username), Some(password)) => Some({ username, password })
    _ => None
  }
}
