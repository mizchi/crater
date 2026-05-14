///|
fn BidiProtocol::normalize_synthetic_network_set_cookie_entries(
  self : BidiProtocol,
  request_id : Int,
  raw_cookies : Json?,
  base_url : String,
) -> SyntheticNetworkSetCookieEntries? {
  let items = match raw_cookies {
    Some(Array(items)) => items
    _ => {
      self.send_error(
        request_id, "invalid argument", "cookies must be an array",
      )
      return None
    }
  }
  let headers : Array[Json] = []
  let cookies : Array[StoredCookie] = []
  for item in items {
    let map = match item {
      Object(map) => map
      _ => {
        self.send_error(
          request_id, "invalid argument", "cookie entry must be an object",
        )
        return None
      }
    }
    let name = match map.get("name") {
      Some(String(name)) => name
      _ => {
        self.send_error(
          request_id, "invalid argument", "cookie name must be a string",
        )
        return None
      }
    }
    let value = match map.get("value") {
      Some(raw_value) =>
        match
          self.synthetic_network_string_from_bytes_value(
            request_id, raw_value, "cookie.value",
          ) {
          Some(value) => value
          None => return None
        }
      None => {
        self.send_error(
          request_id, "invalid argument", "cookie value must be an object",
        )
        return None
      }
    }
    let normalized = match
      @crater_network.synthetic_network_normalize_set_cookie_override_entry(
        map,
        name,
        value,
        base_url,
        storage_now_seconds(),
      ) {
      Ok(normalized) => normalized
      Err(message) => {
        self.send_error(request_id, "invalid argument", message)
        return None
      }
    }
    cookies.push(synthetic_network_cookie_to_stored_cookie(normalized.cookie))
    headers.push(
      synthetic_network_header_string_entry(
        "Set-Cookie",
        normalized.set_cookie_header_value,
      ),
    )
  }
  Some({ headers, cookies })
}
