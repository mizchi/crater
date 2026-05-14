///|
fn synthetic_navigation_blocked_request_payload(
  input : @crater_network.SyntheticNetworkEventInput,
  phase : String,
  response_event : Json?,
) -> Map[String, Json] {
  let blocked_request : Map[String, Json] = {}
  blocked_request["phase"] = Json::string(phase)
  blocked_request["context_id"] = Json::string(input.context_id)
  blocked_request["url"] = Json::string(input.url)
  blocked_request["method"] = Json::string(input.http_method)
  blocked_request["request_headers"] = synthetic_navigation_header_object_from_entries(
    input.request_headers,
  )
  match input.request_value {
    Some(request_value) => blocked_request["request_value"] = request_value
    None => ()
  }
  blocked_request["redirect_count"] = Json::number(
    input.redirect_count.to_double(),
  )
  blocked_request["navigation"] = match input.navigation {
    Some(navigation) => Json::string(navigation)
    None => Json::null()
  }
  blocked_request["destination"] = Json::string(input.destination)
  blocked_request["initiator_type"] = match input.initiator_type {
    Some(initiator_type) => Json::string(initiator_type)
    None => Json::null()
  }
  blocked_request["is_navigation"] = Json::boolean(true)
  match response_event {
    Some(event) => {
      blocked_request["response_headers"] = Json::array(
        synthetic_navigation_response_headers_from_event(event),
      )
      blocked_request["response_status"] = Json::number(
        synthetic_navigation_response_status_from_event(event).to_double(),
      )
      blocked_request["response_status_text"] = Json::string(
        synthetic_navigation_response_status_text_from_event(event),
      )
    }
    None => ()
  }
  blocked_request
}

///|
fn synthetic_navigation_requires_auth_event(
  response_overrides : @crater_network.SyntheticNetworkResponseOverrides,
) -> Bool {
  response_overrides.status == 401 ||
  response_overrides.status == 407 ||
  response_overrides.auth_challenges != None
}

///|
fn synthetic_navigation_is_unreachable_test_url(url : String) -> Bool {
  url.has_prefix("http://not_a_valid_url.test") ||
  url.has_prefix("https://not_a_valid_url.test")
}

///|
fn synthetic_navigation_header_object_from_entries(
  headers : Array[Json],
) -> Json {
  let object : Map[String, Json] = {}
  for header in headers {
    let name = match synthetic_network_header_entry_name(header) {
      Some(name) => name
      None => continue
    }
    let value = synthetic_network_header_entry_string_value(header).unwrap_or(
      "",
    )
    object[name] = Json::string(value)
  }
  make_object(object)
}

///|
fn synthetic_navigation_response_headers_from_event(
  event : Json,
) -> Array[Json] {
  match get_field(event, "response") {
    Some(Object(response)) =>
      match response.get("headers") {
        Some(Array(headers)) => headers
        _ => []
      }
    _ => []
  }
}

///|
fn synthetic_navigation_response_status_from_event(event : Json) -> Int {
  match get_field(event, "response") {
    Some(Object(response)) =>
      match response.get("status") {
        Some(Number(status, ..)) => status.to_int()
        _ => 200
      }
    _ => 200
  }
}

///|
fn synthetic_navigation_response_status_text_from_event(event : Json) -> String {
  match get_field(event, "response") {
    Some(Object(response)) =>
      match response.get("statusText") {
        Some(String(status_text)) => status_text
        _ => "OK"
      }
    _ => "OK"
  }
}

///|
fn synthetic_navigation_synthesize_response_value(url : String) -> Json {
  if url.has_prefix("data:") {
    let payload = url.unsafe_substring(start=5, end=url.length())
    match find_substring(payload, ",", 0) {
      Some(idx) => {
        let meta = payload.unsafe_substring(start=0, end=idx)
        let encoded = payload.unsafe_substring(
          start=idx + 1,
          end=payload.length(),
        )
        let mime = match find_substring(meta, ";", 0) {
          Some(semi_idx) => meta.unsafe_substring(start=0, end=semi_idx)
          None => meta
        }
        if meta.contains(";base64") {
          if mime.has_prefix("image/") {
            return make_object({
              "type": Json::string("base64"),
              "value": Json::string(encoded),
            })
          }
          return make_object({
            "type": Json::string("string"),
            "value": Json::string(decode_base64(encoded)),
          })
        }
        let decoded = js_decode_query_component(encoded)
        return make_object({
          "type": Json::string("string"),
          "value": Json::string(decoded),
        })
      }
      None => ()
    }
  }
  let path = match canonicalize_network_http_url(url) {
    Some(parts) => parts.path
    None => ""
  }
  if path.has_suffix("/empty.txt") {
    return make_object({
      "type": Json::string("string"),
      "value": Json::string("empty\n"),
    })
  }
  if path.has_suffix("/other.txt") {
    return make_object({
      "type": Json::string("string"),
      "value": Json::string("other\n"),
    })
  }
  if path.has_suffix("/empty.png") {
    return make_object({
      "type": Json::string("base64"),
      "value": Json::string(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQIW2P4DwQACfsD/Z8fLAAAAAAASUVORK5CYII=",
      ),
    })
  }
  if path.has_suffix("/cached.py") {
    let response_body = synthetic_network_first_query_value(url, "response").unwrap_or(
      "",
    )
    let raw_response = synthetic_navigation_first_raw_query_value(
      url, "response",
    ).unwrap_or("")
    let content_type = synthetic_network_first_query_value(url, "contenttype")
      .unwrap_or("text/plain")
      .to_lower()
    if content_type.has_prefix("image/") || content_type == "img/png" {
      return make_object({
        "type": Json::string("base64"),
        "value": Json::string(
          if raw_response != "" {
            synthetic_navigation_raw_query_value_to_base64(raw_response)
          } else {
            encode_base64_utf8(response_body)
          },
        ),
      })
    }
    return make_object({
      "type": Json::string("string"),
      "value": Json::string(response_body),
    })
  }
  if path.has_suffix("/headers.py") || path.has_suffix("/charset.py") {
    return make_object({
      "type": Json::string("string"),
      "value": Json::string(
        synthetic_network_first_query_value(url, "content").unwrap_or(""),
      ),
    })
  }
  make_object({ "type": Json::string("string"), "value": Json::string("") })
}

///|
fn synthetic_navigation_first_raw_query_value(
  url : String,
  key : String,
) -> String? {
  let values = synthetic_navigation_raw_query_values(url, key)
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
fn synthetic_navigation_raw_query_values(
  url : String,
  key : String,
) -> Array[String] {
  let values : Array[String] = []
  let query = extract_network_url_query(url)
  if query == "" {
    return values
  }
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
        values.push(raw_value)
      }
      None => if raw == key { values.push("") }
    }
  }
  values
}

///|
extern "js" fn synthetic_navigation_raw_query_value_to_base64(
  value : String,
) -> String =
  #| (value) => {
  #|   const raw = String(value ?? "").replace(/\+/g, " ");
  #|   const bytes = [];
  #|   for (let i = 0; i < raw.length; ) {
  #|     const ch = raw[i];
  #|     if (ch === "%" && i + 2 < raw.length) {
  #|       const hex = raw.slice(i + 1, i + 3);
  #|       const parsed = Number.parseInt(hex, 16);
  #|       if (!Number.isNaN(parsed)) {
  #|         bytes.push(parsed);
  #|         i += 3;
  #|         continue;
  #|       }
  #|     }
  #|     bytes.push(ch.charCodeAt(0));
  #|     i += 1;
  #|   }
  #|   let binary = "";
  #|   for (const byte of bytes) {
  #|     binary += String.fromCharCode(byte);
  #|   }
  #|   return btoa(binary);
  #| }
