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
  let url = match raw_url {
    String(url) => url
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return None
    }
  }
  if synthetic_network_is_valid_continue_url(url) {
    Some(url)
  } else {
    self.send_error(request_id, "invalid argument", "url is invalid")
    None
  }
}

///|
fn BidiProtocol::normalize_synthetic_network_string_list(
  self : BidiProtocol,
  request_id : Int,
  raw_list : Json?,
  field_name : String,
) -> Array[String]? {
  match raw_list {
    None | Some(Null) => Some([])
    Some(Array(items)) => {
      let values : Array[String] = []
      for item in items {
        match item {
          String(value) => values.push(value)
          _ => {
            self.send_error(
              request_id,
              "invalid argument",
              field_name + " entries must be strings",
            )
            return None
          }
        }
      }
      Some(values)
    }
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + " must be an array",
      )
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
  let overrides = match raw_overrides {
    None | Some(Null) =>
      return Some({
        from_cache: false,
        headers: [],
        mime_type: "text/plain",
        protocol: "http/1.1",
        status: 200,
        status_text: "OK",
        auth_challenges: None,
      })
    Some(Object(map)) => map
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides must be an object",
      )
      return None
    }
  }
  let from_cache = match overrides.get("fromCache") {
    Some(True) => true
    Some(False) | None => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides.fromCache must be a boolean",
      )
      return None
    }
  }
  let headers = match
    self.normalize_synthetic_network_header_entries(
      request_id,
      overrides.get("headers"),
    ) {
    Some(headers) => headers
    None => return None
  }
  let mime_type = match overrides.get("mimeType") {
    Some(String(value)) => value
    None => "text/plain"
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides.mimeType must be a string",
      )
      return None
    }
  }
  let protocol = match overrides.get("protocol") {
    Some(String(value)) => value
    None => "http/1.1"
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides.protocol must be a string",
      )
      return None
    }
  }
  let status = match overrides.get("status") {
    Some(value) =>
      match storage_json_non_negative_int(value) {
        Some(status) => status
        None => {
          self.send_error(
            request_id, "invalid argument", "responseOverrides.status must be a non-negative integer",
          )
          return None
        }
      }
    None => 200
  }
  let status_text = match overrides.get("statusText") {
    Some(String(value)) => value
    None => synthetic_network_status_text_for_code(status)
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides.statusText must be a string",
      )
      return None
    }
  }
  let mut auth_challenges : Json? = match overrides.get("authChallenges") {
    None | Some(Null) => None
    Some(Array(values)) => Some(Json::array(values))
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "responseOverrides.authChallenges must be an array",
      )
      return None
    }
  }
  let missing_auth_challenges = match auth_challenges {
    None => true
    Some(_) => false
  }
  if (status == 401 || status == 407) && missing_auth_challenges {
    auth_challenges = Some(Json::array([]))
  }
  Some({
    from_cache,
    headers,
    mime_type,
    protocol,
    status,
    status_text,
    auth_challenges,
  })
}
