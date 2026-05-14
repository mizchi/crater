///|
pub fn synthetic_network_header_entries_from_object(
  raw_headers : Map[String, Json],
) -> Array[Json] {
  let headers : Array[Json] = []
  for name, raw_value in raw_headers {
    headers.push(
      synthetic_network_header_string_entry(
        name,
        synthetic_network_header_value_from_json(raw_value),
      ),
    )
  }
  headers
}

///|
pub fn synthetic_network_merge_header_entries(
  headers : Array[Json],
) -> Array[Json] {
  let order : Array[String] = []
  let names : Map[String, String] = {}
  let values : Map[String, String] = {}
  for header in headers {
    let name = match synthetic_network_header_entry_name(header) {
      Some(name) => name
      None => continue
    }
    let value = match synthetic_network_header_entry_string_value(header) {
      Some(value) => value
      None => continue
    }
    let key = name.to_lower()
    if values.contains(key) {
      let merged = values.get(key).unwrap_or("")
      values[key] = merged + ", " + value
    } else {
      order.push(key)
      names[key] = name
      values[key] = value
    }
  }
  let merged : Array[Json] = []
  for key in order {
    let name = names.get(key).unwrap_or(key)
    let value = values.get(key).unwrap_or("")
    merged.push(synthetic_network_header_string_entry(name, value))
  }
  merged
}

///|
pub fn synthetic_network_header_entry_name(header : Json) -> String? {
  match header {
    Object(map) =>
      match map.get("name") {
        Some(String(name)) => Some(name)
        _ => None
      }
    _ => None
  }
}

///|
pub fn synthetic_network_header_entry_string_value(header : Json) -> String? {
  match header {
    Object(map) =>
      match map.get("value") {
        Some(Object(value_map)) =>
          match value_map.get("value") {
            Some(String(value)) => Some(value)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
pub fn synthetic_network_normalize_header_entries(
  raw_headers : Json?,
  field_name : String,
) -> Result[Array[Json], String] {
  match raw_headers {
    None | Some(Null) => Ok([])
    Some(Array(items)) => {
      let headers : Array[Json] = []
      for item in items {
        match synthetic_network_validate_header_entry(item) {
          Some(header) => headers.push(header)
          None => return Err(field_name + " entry is invalid")
        }
      }
      Ok(headers)
    }
    Some(_) => Err(field_name + " must be an array")
  }
}

///|
pub fn synthetic_network_validate_header_entry(entry : Json) -> Json? {
  let map = match entry {
    Object(map) => map
    _ => return None
  }
  let name = match map.get("name") {
    Some(String(name)) =>
      if synthetic_network_is_valid_header_name_token(name) {
        name
      } else {
        return None
      }
    _ => return None
  }
  let value = match map.get("value") {
    Some(value) =>
      match synthetic_network_validate_header_value(value) {
        Some(value) => value
        None => return None
      }
    None => return None
  }
  Some(Json::object({ "name": Json::string(name), "value": value }))
}

///|
pub fn synthetic_network_validate_header_value(value : Json) -> Json? {
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
  if !synthetic_network_is_valid_header_string_value(raw_value) {
    return None
  }
  Some(
    Json::object({
      "type": Json::string("string"),
      "value": Json::string(raw_value),
    }),
  )
}

///|
pub fn synthetic_network_is_valid_header_name_token(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  for c in name.iter() {
    if !synthetic_network_is_valid_header_name_token_char(c) {
      return false
    }
  }
  true
}

///|
pub fn synthetic_network_is_valid_header_string_value(value : String) -> Bool {
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

///|
fn synthetic_network_header_value_from_json(raw_value : Json) -> String {
  match raw_value {
    String(value) => value
    Number(value, ..) => value.to_string()
    True => "true"
    False => "false"
    Null => ""
    Array(_) | Object(_) => raw_value.stringify()
  }
}

///|
pub fn synthetic_network_is_valid_continue_url(url : String) -> Bool {
  if url.has_prefix("data:") {
    return true
  }
  if url.has_prefix("http://") {
    return has_valid_http_host(url, 7)
  }
  if url.has_prefix("https://") {
    return has_valid_http_host(url, 8)
  }
  false
}

///|
pub fn synthetic_network_normalize_continue_url(
  raw_url : Json,
) -> Result[String, String] {
  let url = match raw_url {
    String(url) => url
    _ => return Err("url must be a string")
  }
  if synthetic_network_is_valid_continue_url(url) {
    Ok(url)
  } else {
    Err("url is invalid")
  }
}

///|
pub fn synthetic_network_cache_key(
  http_method : String,
  url : String,
) -> String {
  http_method + " " + url
}

///|
pub fn synthetic_network_request_path(url : String) -> String {
  match canonicalize_network_http_url(url) {
    Some(parts) => parts.path
    None => ""
  }
}

///|
pub fn synthetic_network_first_query_value(
  url : String,
  key : String,
) -> String? {
  let values = synthetic_network_query_values(url, key)
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
pub fn synthetic_network_query_values(
  url : String,
  key : String,
) -> Array[String] {
  let values : Array[String] = []
  match find_substring(url, "?", 0) {
    Some(query_idx) => {
      let query_start = query_idx + 1
      if query_start >= url.length() {
        return values
      }
      let query = url.unsafe_substring(start=query_start, end=url.length())
      for part in query.split("&") {
        let raw = part.to_owned()
        if raw.length() == 0 {
          continue
        }
        match find_substring(raw, "=", 0) {
          Some(eq_idx) => {
            let part_key = raw.unsafe_substring(start=0, end=eq_idx)
            if part_key != key {
              continue
            }
            let value_start = eq_idx + 1
            let raw_value = if value_start <= raw.length() {
              raw.unsafe_substring(start=value_start, end=raw.length())
            } else {
              ""
            }
            values.push(decode_query_component(raw_value))
          }
          None => if raw == key { values.push("") }
        }
      }
      values
    }
    None => values
  }
}

///|
pub fn synthetic_network_int_query_param(
  url : String,
  key : String,
  default_value : Int,
) -> Int {
  match synthetic_network_first_query_value(url, key) {
    Some(value) =>
      match parse_decimal_string(value) {
        Some(parsed) => parsed
        None => default_value
      }
    None => default_value
  }
}

///|
pub fn synthetic_network_request_header_string_value(
  headers : Array[Json],
  name : String,
) -> String? {
  let lookup = name.to_lower()
  for header in headers {
    match header {
      Object(map) => {
        let header_name = match map.get("name") {
          Some(String(header_name)) => header_name.to_lower()
          _ => continue
        }
        if header_name != lookup {
          continue
        }
        match map.get("value") {
          Some(Object(value_map)) =>
            match value_map.get("value") {
              Some(String(value)) => return Some(value)
              _ => ()
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
pub fn synthetic_network_header_string_entry(
  name : String,
  value : String,
) -> Json {
  Json::object({
    "name": Json::string(name),
    "value": Json::object({
      "type": Json::string("string"),
      "value": Json::string(value),
    }),
  })
}

///|
pub fn synthetic_network_infer_mime_type(url : String, path : String) -> String {
  if url.has_prefix("data:") {
    let payload_start = match find_substring(url, ",", 0) {
      Some(payload_start) => payload_start
      None => url.length()
    }
    let prefix = if payload_start > 5 {
      url.unsafe_substring(start=5, end=payload_start)
    } else {
      ""
    }
    match find_substring(prefix, ";", 0) {
      Some(idx) => {
        let mime_type = prefix.unsafe_substring(start=0, end=idx)
        if mime_type == "" {
          "text/plain"
        } else {
          mime_type.to_lower()
        }
      }
      None => if prefix == "" { "text/plain" } else { prefix.to_lower() }
    }
  } else if path.has_suffix(".html") {
    "text/html"
  } else if path.has_suffix(".txt") {
    "text/plain"
  } else if path.has_suffix(".js") {
    "text/javascript"
  } else if path.has_suffix(".png") {
    "image/png"
  } else if path.has_suffix(".svg") {
    "image/svg+xml"
  } else if path.has_suffix(".css") {
    "text/css"
  } else if path.has_suffix("/cached.py") {
    synthetic_network_first_query_value(url, "contenttype").unwrap_or(
      "text/plain",
    )
  } else {
    "text/plain"
  }
}

///|
pub fn synthetic_network_status_text_for_code(status : Int) -> String {
  match status {
    101 => "Switching Protocols"
    200 => "OK"
    201 => "Created"
    202 => "Accepted"
    203 => "Non-Authoritative Information"
    204 => "No Content"
    205 => "Reset Content"
    206 => "Partial Content"
    300 => "Multiple Choices"
    305 => "Use Proxy"
    301 => "Moved Permanently"
    302 => "Found"
    303 => "See Other"
    304 => "Not Modified"
    307 => "Temporary Redirect"
    308 => "Permanent Redirect"
    400 => "Bad Request"
    401 => "Unauthorized"
    402 => "Payment Required"
    403 => "Forbidden"
    404 => "Not Found"
    405 => "Method Not Allowed"
    406 => "Not Acceptable"
    407 => "Proxy Authentication Required"
    408 => "Request Timeout"
    409 => "Conflict"
    410 => "Gone"
    411 => "Length Required"
    412 => "Precondition Failed"
    415 => "Unsupported Media Type"
    417 => "Expectation Failed"
    500 => "Internal Server Error"
    501 => "Not Implemented"
    502 => "Bad Gateway"
    503 => "Service Unavailable"
    504 => "Gateway Timeout"
    505 => "HTTP Version Not Supported"
    _ => if status == 200 { "OK" } else { "" }
  }
}

///|
pub fn synthetic_network_normalize_response_overrides(
  raw_overrides : Json?,
) -> Result[SyntheticNetworkResponseOverrides, String] {
  let overrides = match raw_overrides {
    None | Some(Null) =>
      return Ok(synthetic_network_default_response_overrides())
    Some(Object(map)) => map
    Some(_) => return Err("responseOverrides must be an object")
  }
  let from_cache = match overrides.get("fromCache") {
    Some(True) => true
    Some(False) | None => false
    Some(_) => return Err("responseOverrides.fromCache must be a boolean")
  }
  let headers = match
    synthetic_network_normalize_header_entries(
      overrides.get("headers"),
      "requestHeaders",
    ) {
    Ok(headers) => headers
    Err(message) => return Err(message)
  }
  let mime_type = match overrides.get("mimeType") {
    Some(String(value)) => value
    None => "text/plain"
    Some(_) => return Err("responseOverrides.mimeType must be a string")
  }
  let protocol = match overrides.get("protocol") {
    Some(String(value)) => value
    None => "http/1.1"
    Some(_) => return Err("responseOverrides.protocol must be a string")
  }
  let status = match overrides.get("status") {
    Some(value) =>
      match synthetic_network_json_as_safe_int(value, 0.0, 9007199254740991.0) {
        Some(status) => status
        None =>
          return Err("responseOverrides.status must be a non-negative integer")
      }
    None => 200
  }
  let status_text = match overrides.get("statusText") {
    Some(String(value)) => value
    None => synthetic_network_status_text_for_code(status)
    Some(_) => return Err("responseOverrides.statusText must be a string")
  }
  let mut auth_challenges : Json? = match overrides.get("authChallenges") {
    None | Some(Null) => None
    Some(Array(values)) => Some(Json::array(values))
    Some(_) => return Err("responseOverrides.authChallenges must be an array")
  }
  let missing_auth_challenges = match auth_challenges {
    None => true
    Some(_) => false
  }
  if (status == 401 || status == 407) && missing_auth_challenges {
    auth_challenges = Some(Json::array([]))
  }
  Ok({
    from_cache,
    headers,
    mime_type,
    protocol,
    status,
    status_text,
    auth_challenges,
  })
}

///|
fn synthetic_network_default_response_overrides() -> SyntheticNetworkResponseOverrides {
  {
    from_cache: false,
    headers: [],
    mime_type: "text/plain",
    protocol: "http/1.1",
    status: 200,
    status_text: "OK",
    auth_challenges: None,
  }
}

///|
fn has_valid_http_host(url : String, scheme_len : Int) -> Bool {
  if url.length() <= scheme_len {
    return false
  }
  let chars = url.to_array()
  let head = chars[scheme_len]
  if head == ':' || head == '#' || head == '/' || head == '?' {
    return false
  }
  true
}

///|
fn synthetic_network_is_valid_header_name_token_char(c : Char) -> Bool {
  let code = c.to_int()
  if (code >= 48 && code <= 57) ||
    (code >= 65 && code <= 90) ||
    (code >= 97 && code <= 122) {
    return true
  }
  match code {
    33 => true
    35 => true
    36 => true
    37 => true
    38 => true
    39 => true
    42 => true
    43 => true
    45 => true
    46 => true
    94 => true
    95 => true
    96 => true
    124 => true
    126 => true
    _ => false
  }
}
