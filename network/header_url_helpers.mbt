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
