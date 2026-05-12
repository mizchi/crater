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

///|
fn synthetic_network_format_set_cookie_header(
  entry : Map[String, Json],
) -> String {
  let parts : Array[String] = []
  let name = match entry.get("name") {
    Some(String(name)) => name
    _ => ""
  }
  let value = match entry.get("value") {
    Some(String(value)) => value
    _ => ""
  }
  parts.push(name + "=" + value)
  match entry.get("path") {
    Some(String(path)) => parts.push("Path=" + path)
    _ => ()
  }
  match entry.get("domain") {
    Some(String(domain)) => parts.push("Domain=" + domain)
    _ => ()
  }
  match entry.get("expiry") {
    Some(String(expiry)) => parts.push("Expires=" + expiry)
    _ => ()
  }
  match entry.get("maxAge") {
    Some(Number(max_age, ..)) =>
      parts.push("Max-Age=" + max_age.to_int().to_string())
    _ => ()
  }
  match entry.get("httpOnly") {
    Some(True) => parts.push("HttpOnly")
    _ => ()
  }
  match entry.get("secure") {
    Some(True) => parts.push("Secure")
    _ => ()
  }
  match entry.get("sameSite") {
    Some(String(raw_same_site)) => {
      let same_site = raw_same_site.to_lower()
      let mapped = if same_site == "none" {
        "None"
      } else if same_site == "lax" {
        "Lax"
      } else if same_site == "strict" {
        "Strict"
      } else {
        raw_same_site
      }
      parts.push("SameSite=" + mapped)
    }
    _ => ()
  }
  parts.join(";")
}

///|
fn synthetic_network_extract_set_cookie_entries(
  headers : Array[Json],
  base_url : String,
) -> Array[StoredCookie] {
  let cookies : Array[StoredCookie] = []
  for header in headers {
    let map = match header {
      Object(map) => map
      _ => continue
    }
    let name = match map.get("name") {
      Some(String(name)) => name
      _ => continue
    }
    if !is_ascii_case_insensitive_equal(name, "set-cookie") {
      continue
    }
    let value_map = match map.get("value") {
      Some(Object(value_map)) => value_map
      _ => continue
    }
    let value_type = match value_map.get("type") {
      Some(String(value_type)) => value_type
      _ => continue
    }
    if value_type != "string" {
      continue
    }
    let header_value = match value_map.get("value") {
      Some(String(header_value)) => header_value
      _ => continue
    }
    match
      synthetic_network_parse_set_cookie_header_value(header_value, base_url) {
      Some(cookie) => cookies.push(cookie)
      None => ()
    }
  }
  cookies
}

///|
fn synthetic_network_parse_set_cookie_header_value(
  header_value : String,
  base_url : String,
) -> StoredCookie? {
  let attributes : Array[String] = []
  let mut first : String? = None
  for raw_part in header_value.split(";") {
    let part = raw_part.trim().to_owned()
    match first {
      Some(_) => attributes.push(part)
      None => first = Some(part)
    }
  }
  let first = match first {
    Some(first) => first
    None => return None
  }
  match find_substring(first, "=", 0) {
    Some(eq_idx) => {
      let name = storage_slice(first, 0, eq_idx).trim().to_owned()
      let value_start = eq_idx + 1
      let value = if value_start <= first.length() {
        storage_slice_from(first, value_start).trim().to_owned()
      } else {
        ""
      }
      if name == "" || !is_valid_network_header_name_token(name) {
        return None
      }
      let mut domain = storage_cookie_domain_from_base_url(base_url)
      let mut domain_explicit = false
      let mut path = "/"
      let mut http_only = false
      let mut secure = false
      let mut same_site = "none"
      let mut expiry : Int? = None

      for raw_attr in attributes {
        let attr = raw_attr.trim().to_owned()
        if attr == "" {
          continue
        }
        let (attr_name, attr_value) = match find_substring(attr, "=", 0) {
          Some(attr_eq_idx) => {
            let attr_value_start = attr_eq_idx + 1
            (
              storage_slice(attr, 0, attr_eq_idx).trim().to_owned().to_lower(),
              if attr_value_start <= attr.length() {
                storage_slice_from(attr, attr_value_start).trim().to_owned()
              } else {
                ""
              },
            )
          }
          None => (attr.to_lower(), "")
        }
        if attr_name == "domain" {
          let normalized_domain = storage_strip_leading_dot(
            attr_value.trim().to_owned().to_lower(),
          )
          if normalized_domain != "" {
            domain = normalized_domain
            domain_explicit = true
          }
        } else if attr_name == "path" {
          if attr_value != "" {
            path = attr_value
          }
        } else if attr_name == "samesite" {
          let lowered = attr_value.to_lower()
          if lowered == "none" || lowered == "lax" || lowered == "strict" {
            same_site = lowered
          }
        } else if attr_name == "max-age" {
          let parsed_max_age : Int? = Some(@string.parse_int(attr_value)) catch {
            _ => None
          }
          match parsed_max_age {
            Some(parsed_max_age) =>
              expiry = Some(storage_now_seconds() + parsed_max_age)
            None => ()
          }
        } else if attr_name == "expires" {
          let parsed_expiry = js_parse_cookie_expiry_seconds(attr_value)
          if parsed_expiry >= 0 {
            expiry = Some(parsed_expiry)
          }
        } else if attr_name == "httponly" {
          http_only = true
        } else if attr_name == "secure" {
          secure = true
        }
      }

      Some({
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
    }
    None => None
  }
}

///|
fn BidiProtocol::store_synthetic_response_cookie(
  self : BidiProtocol,
  context_id : String,
  cookie : StoredCookie,
) -> Unit {
  let stored_cookie : StoredCookie = {
    ..cookie,
    context_id: Some(context_id),
    user_context: Some(self.resolve_storage_user_context(context_id)),
    source_origin: storage_cookie_origin_from_base_url(
      self.get_context_cookie_base_url(context_id),
    ),
  }
  match stored_cookie.expiry {
    Some(expiry) =>
      if expiry <= storage_now_seconds() {
        self.delete_matching_storage_cookie_identity(
          stored_cookie.context_id,
          stored_cookie.user_context,
          stored_cookie.source_origin,
          stored_cookie.name,
          stored_cookie.domain,
          stored_cookie.path,
        )
      } else {
        self.store_storage_cookie(stored_cookie)
      }
    None => self.store_storage_cookie(stored_cookie)
  }
}
