///|
/// Valid network.addIntercept phase names.
fn is_valid_network_intercept_phase(name : String) -> Bool {
  name == "beforeRequestSent" ||
  name == "responseStarted" ||
  name == "authRequired"
}

///|
/// Validate one `network.Header` entry.
fn validate_network_extra_header_entry(entry : Json) -> Json? {
  let map = match entry {
    Object(map) => map
    _ => return None
  }
  let name = match map.get("name") {
    Some(String(name)) =>
      if is_valid_network_header_name_token(name) {
        name
      } else {
        return None
      }
    _ => return None
  }
  let value = match map.get("value") {
    Some(value) =>
      match validate_network_extra_header_value(value) {
        Some(value) => value
        None => return None
      }
    None => return None
  }
  Some(make_object({ "name": Json::string(name), "value": value }))
}

///|
/// Validate one `network.BytesValue` for headers.
fn validate_network_extra_header_value(value : Json) -> Json? {
  let map = match value {
    Object(map) => map
    _ => return None
  }
  let value_type = match map.get("type") {
    Some(String(value_type)) => value_type
    _ => return None
  }
  if value_type != "string" {
    return None
  }
  let raw_value = match map.get("value") {
    Some(String(raw_value)) => raw_value
    _ => return None
  }
  if !is_valid_network_header_string_value(raw_value) {
    return None
  }
  Some(
    make_object({
      "type": Json::string("string"),
      "value": Json::string(raw_value),
    }),
  )
}

///|
/// Validate HTTP header name token (`field-name`).
fn is_valid_network_header_name_token(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  for c in name.iter() {
    if !is_valid_network_header_name_token_char(c) {
      return false
    }
  }
  true
}

///|
/// Validate one `tchar` in RFC9110 token grammar.
fn is_valid_network_header_name_token_char(c : Char) -> Bool {
  let code = c.to_int()
  if (code >= 48 && code <= 57) ||
    (code >= 65 && code <= 90) ||
    (code >= 97 && code <= 122) {
    return true
  }
  match code {
    33 => true // !
    35 => true // #
    36 => true // $
    37 => true // %
    38 => true // &
    39 => true // '
    42 => true // *
    43 => true // +
    45 => true // -
    46 => true // .
    94 => true // ^
    95 => true // _
    96 => true // `
    124 => true // |
    126 => true // ~
    _ => false
  }
}

///|
/// Validate string header value for current WPT constraints.
fn is_valid_network_header_string_value(value : String) -> Bool {
  let chars = value.to_array()
  if chars.length() > 0 {
    let first = chars[0]
    let last = chars[chars.length() - 1]
    if first == ' ' || first == '\t' || last == ' ' || last == '\t' {
      return false
    }
  }
  for c in chars {
    let code = c.to_int()
    if code == 0 || code == 10 || code == 13 {
      return false
    }
  }
  true
}
