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
      Some(String(name)) =>
        if is_valid_network_header_name_token(name) {
          name
        } else {
          self.send_error(
            request_id, "invalid argument", "cookie name is invalid",
          )
          return None
        }
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
    let mut domain = storage_cookie_domain_from_base_url(base_url)
    let mut domain_explicit = false
    let mut path = "/"
    let mut http_only = false
    let mut secure = false
    let mut same_site = "none"
    let mut expiry : Int? = None
    let header_entry : Map[String, Json] = {}
    header_entry["name"] = Json::string(name)
    header_entry["value"] = Json::string(value)

    match map.get("domain") {
      Some(String(raw_domain)) => {
        let normalized_domain = storage_strip_leading_dot(
          raw_domain.trim().to_owned().to_lower(),
        )
        domain = normalized_domain
        domain_explicit = normalized_domain != ""
        header_entry["domain"] = Json::string(raw_domain)
      }
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie domain must be a string",
        )
        return None
      }
      None => ()
    }
    match map.get("expiry") {
      Some(String(raw_expiry)) => {
        header_entry["expiry"] = Json::string(raw_expiry)
        let parsed_expiry = js_parse_cookie_expiry_seconds(raw_expiry)
        if parsed_expiry >= 0 {
          expiry = Some(parsed_expiry)
        }
      }
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie expiry must be a string",
        )
        return None
      }
      None => ()
    }
    match map.get("path") {
      Some(String(raw_path)) => {
        path = raw_path
        header_entry["path"] = Json::string(raw_path)
      }
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie path must be a string",
        )
        return None
      }
      None => ()
    }
    match map.get("sameSite") {
      Some(String(raw_same_site)) => {
        let lowered_same_site = raw_same_site.to_lower()
        if lowered_same_site != "none" &&
          lowered_same_site != "lax" &&
          lowered_same_site != "strict" {
          self.send_error(
            request_id, "invalid argument", "cookie sameSite is invalid",
          )
          return None
        }
        same_site = lowered_same_site
        header_entry["sameSite"] = Json::string(lowered_same_site)
      }
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie sameSite must be a string",
        )
        return None
      }
      None => ()
    }
    match map.get("httpOnly") {
      Some(True) => {
        http_only = true
        header_entry["httpOnly"] = Json::boolean(true)
      }
      Some(False) => header_entry["httpOnly"] = Json::boolean(false)
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie httpOnly must be a boolean",
        )
        return None
      }
      None => ()
    }
    match map.get("secure") {
      Some(True) => {
        secure = true
        header_entry["secure"] = Json::boolean(true)
      }
      Some(False) => header_entry["secure"] = Json::boolean(false)
      Some(_) => {
        self.send_error(
          request_id, "invalid argument", "cookie secure must be a boolean",
        )
        return None
      }
      None => ()
    }
    match map.get("maxAge") {
      Some(raw_max_age) =>
        match
          json_as_safe_int(raw_max_age, -9007199254740991.0, 9007199254740991.0) {
          Some(max_age) => {
            header_entry["maxAge"] = Json::number(max_age.to_double())
            expiry = Some(storage_now_seconds() + max_age)
          }
          None => {
            self.send_error(
              request_id, "invalid argument", "cookie maxAge must be an integer",
            )
            return None
          }
        }
      None => ()
    }

    cookies.push({
      name,
      value_text: value,
      domain,
      domain_explicit,
      path,
      http_only,
      secure,
      same_site,
      expiry,
      context_id: None,
      user_context: None,
      source_origin: None,
    })
    headers.push(
      synthetic_network_header_string_entry(
        "Set-Cookie",
        synthetic_network_format_set_cookie_header(header_entry),
      ),
    )
  }
  Some({ headers, cookies })
}
