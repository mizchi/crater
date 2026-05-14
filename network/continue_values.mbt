///|
pub fn synthetic_network_normalize_continue_credentials(
  raw_credentials : Json,
) -> Result[SyntheticNetworkContinueCredentials, String] {
  let map = match raw_credentials {
    Object(map) => map
    _ => return Err("credentials must be an object")
  }
  let credential_type = match map.get("type") {
    Some(String(credential_type)) => credential_type
    _ => return Err("credentials.type must be a string")
  }
  if credential_type != "password" {
    return Err("credentials.type is invalid")
  }
  let username = match map.get("username") {
    Some(String(username)) => username
    _ => return Err("credentials.username must be a string")
  }
  let password = match map.get("password") {
    Some(String(password)) => password
    _ => return Err("credentials.password must be a string")
  }
  Ok({ username, password })
}

///|
pub fn synthetic_network_normalize_bytes_value(
  raw_value : Json,
  field_name : String,
) -> Result[Json, String] {
  let map = match raw_value {
    Object(map) => map
    _ => return Err(field_name + " must be an object")
  }
  let value_type = match map.get("type") {
    Some(String(value_type)) => value_type
    _ => return Err(field_name + ".type must be a string")
  }
  if value_type != "string" && value_type != "base64" {
    return Err(field_name + ".type is invalid")
  }
  let payload = match map.get("value") {
    Some(String(payload)) => payload
    _ => return Err(field_name + ".value must be a string")
  }
  Ok(
    Json::object({
      "type": Json::string(value_type),
      "value": Json::string(payload),
    }),
  )
}

///|
pub fn synthetic_network_text_from_bytes_value(
  raw_value : Json,
  field_name : String,
) -> Result[String, String] {
  let map = match raw_value {
    Object(map) => map
    _ => return Err(field_name + " must be an object")
  }
  let value_type = match map.get("type") {
    Some(String(value_type)) => value_type
    _ => return Err(field_name + ".type must be a string")
  }
  let payload = match map.get("value") {
    Some(String(payload)) => payload
    _ => return Err(field_name + ".value must be a string")
  }
  if value_type == "string" {
    return Ok(payload)
  }
  if value_type == "base64" {
    return Ok(synthetic_network_decode_base64(payload))
  }
  Err(field_name + ".type is invalid")
}

///|
pub fn synthetic_network_string_from_bytes_value(
  raw_value : Json,
  field_name : String,
) -> Result[String, String] {
  let map = match raw_value {
    Object(map) => map
    _ => return Err(field_name + " must be an object")
  }
  let value_type = match map.get("type") {
    Some(String(value_type)) => value_type
    _ => return Err(field_name + ".type must be a string")
  }
  if value_type != "string" {
    return Err(field_name + ".type is invalid")
  }
  match map.get("value") {
    Some(String(payload)) => Ok(payload)
    _ => Err(field_name + ".value must be a string")
  }
}

///|
pub fn synthetic_network_credentials_match_expected(
  url : String,
  credentials : SyntheticNetworkContinueCredentials?,
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
pub fn synthetic_network_expected_auth_credentials(
  url : String,
) -> SyntheticNetworkContinueCredentials? {
  let username = synthetic_network_first_query_value(url, "username")
  let password = synthetic_network_first_query_value(url, "password")
  match (username, password) {
    (Some(username), Some(password)) => Some({ username, password })
    _ => None
  }
}
