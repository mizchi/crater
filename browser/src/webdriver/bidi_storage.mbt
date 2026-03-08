///|
priv struct StoredCookie {
  name : String
  value_text : String
  domain : String
  domain_explicit : Bool
  path : String
  http_only : Bool
  secure : Bool
  same_site : String
  expiry : Int?
  context_id : String?
  user_context : String?
  source_origin : String?
}

///|
priv struct StorageCookieFilter {
  domain : String?
  name : String?
  path : String?
  http_only : Bool?
  secure : Bool?
  expiry : Int?
  size : Int?
  same_site : String?
  value_text : String?
}

///|
priv struct StoragePartitionInfo {
  kind : String
  context_id : String?
  user_context : String?
  source_origin : String?
  partition_key : Map[String, Json]
}

///|
extern "js" fn js_parse_cookie_expiry_seconds(value : String) -> Int =
  #| (value) => {
  #|   const text = String(value ?? "").trim();
  #|   if (text.length === 0) return -1;
  #|   const hasZone = /(?:GMT|UTC|[+-]\d{2}:?\d{2})$/i.test(text);
  #|   const parsed = Date.parse(hasZone ? text : `${text} GMT`);
  #|   if (!Number.isFinite(parsed)) return -1;
  #|   return Math.floor(parsed / 1000);
  #| }

///|
fn storage_now_seconds() -> Int {
  (input_now_ms() / 1000.0).to_int()
}

///|
fn storage_slice(value : String, start : Int, end : Int) -> String {
  value[start:end].to_string() catch {
    _ => ""
  }
}

///|
fn storage_slice_from(value : String, start : Int) -> String {
  if start > value.length() {
    ""
  } else {
    value[start:].to_string() catch {
      _ => ""
    }
  }
}

///|
fn storage_strip_leading_dot(value : String) -> String {
  if value.has_prefix(".") {
    storage_slice_from(value, 1)
  } else {
    value
  }
}

///|
fn storage_cookie_size(cookie : StoredCookie) -> Int {
  cookie.name.length() + cookie.value_text.length()
}

///|
fn storage_cookie_value_json(value_text : String) -> Json {
  make_object({
    "type": Json::string("string"),
    "value": Json::string(value_text),
  })
}

///|
fn storage_cookie_to_json(cookie : StoredCookie) -> Json {
  let obj : Map[String, Json] = {}
  obj["name"] = Json::string(cookie.name)
  obj["value"] = storage_cookie_value_json(cookie.value_text)
  obj["domain"] = Json::string(
    if cookie.domain_explicit && cookie.domain.length() > 0 {
      "." + cookie.domain
    } else {
      cookie.domain
    },
  )
  obj["path"] = Json::string(cookie.path)
  obj["httpOnly"] = Json::boolean(cookie.http_only)
  obj["secure"] = Json::boolean(cookie.secure)
  obj["sameSite"] = Json::string(cookie.same_site)
  obj["size"] = Json::number(storage_cookie_size(cookie).to_double())
  match cookie.expiry {
    Some(expiry) => obj["expiry"] = Json::number(expiry.to_double())
    None => ()
  }
  make_object(obj)
}

///|
fn storage_cookie_to_request_json(cookie : StoredCookie) -> Json {
  make_object({
    "name": Json::string(cookie.name),
    "value": storage_cookie_value_json(cookie.value_text),
  })
}

///|
fn storage_same_site_is_valid(value : String) -> Bool {
  value == "none" || value == "lax" || value == "strict" || value == "default"
}

///|
fn BidiProtocol::dispatch_storage(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "getCookies" => {
      let cookie_filter = match
        self.normalize_storage_cookie_filter(
          request.id,
          get_param_raw(request.params, "filter"),
        ) {
        Some(filter) => filter
        None => return Ok(())
      }
      let partition = match
        self.normalize_storage_partition(
          request.id,
          get_param_raw(request.params, "partition"),
        ) {
        Some(info) => info
        None => return Ok(())
      }
      let cookies : Array[Json] = []
      for cookie in self.list_storage_cookies() {
        if self.storage_cookie_matches_partition(cookie, partition) &&
          storage_cookie_matches_filter(cookie, cookie_filter) {
          cookies.push(storage_cookie_to_json(cookie))
        }
      }
      let result = make_object({
        "cookies": Json::array(cookies),
        "partitionKey": make_object(partition.partition_key),
      })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "setCookie" => {
      let raw_cookie = match get_param_raw(request.params, "cookie") {
        Some(value) => value
        None => {
          self.send_error(request.id, "invalid argument", "Missing cookie")
          return Ok(())
        }
      }
      let cookie = match
        self.normalize_storage_cookie_input(request.id, raw_cookie) {
        Some(cookie) => cookie
        None => return Ok(())
      }
      let partition = match
        self.normalize_storage_partition(
          request.id,
          get_param_raw(request.params, "partition"),
        ) {
        Some(info) => info
        None => return Ok(())
      }
      let stored_cookie : StoredCookie = {
        ..cookie,
        context_id: partition.context_id,
        user_context: partition.user_context,
        source_origin: partition.source_origin,
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
      let result = make_object({
        "partitionKey": make_object(partition.partition_key),
      })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "deleteCookies" => {
      let cookie_filter = match
        self.normalize_storage_cookie_filter(
          request.id,
          get_param_raw(request.params, "filter"),
        ) {
        Some(filter) => filter
        None => return Ok(())
      }
      let partition = match
        self.normalize_storage_partition(
          request.id,
          get_param_raw(request.params, "partition"),
        ) {
        Some(info) => info
        None => return Ok(())
      }
      self.delete_storage_cookies(cookie_filter, partition)
      let result = make_object({
        "partitionKey": make_object(partition.partition_key),
      })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "resolveRequestCookies" => {
      let context_id = match get_param_raw(request.params, "context") {
        Some(String(context_id)) => context_id
        Some(_) | None => {
          self.send_error(
            request.id,
            "invalid argument",
            "context must be a string",
          )
          return Ok(())
        }
      }
      if not(self.manager.has_session(context_id)) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + context_id,
        )
        return Ok(())
      }
      let request_url : String? = match
        get_param_raw(request.params, "requestUrl") {
        None | Some(Null) => None
        Some(String(url)) => Some(url)
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "requestUrl must be a string",
          )
          return Ok(())
        }
      }
      let cookies = self.resolve_storage_request_cookies(
        context_id, request_url,
      )
      self.send_success(
        request.id,
        Some(make_object({ "cookies": Json::array(cookies) })),
      )
      Ok(())
    }
    "rememberDocumentCookie" => {
      let context_id = match get_param_raw(request.params, "context") {
        Some(String(context_id)) => context_id
        Some(_) | None => {
          self.send_error(
            request.id,
            "invalid argument",
            "context must be a string",
          )
          return Ok(())
        }
      }
      if not(self.manager.has_session(context_id)) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + context_id,
        )
        return Ok(())
      }
      let cookie_assignment = match get_param_raw(request.params, "cookie") {
        Some(String(cookie_assignment)) => cookie_assignment
        Some(_) | None => {
          self.send_error(
            request.id,
            "invalid argument",
            "cookie must be a string",
          )
          return Ok(())
        }
      }
      self.remember_document_cookie(context_id, cookie_assignment)
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "getContextCookieInfo" => {
      let context_id = match get_param_raw(request.params, "context") {
        Some(String(context_id)) => context_id
        Some(_) | None => {
          self.send_error(
            request.id,
            "invalid argument",
            "context must be a string",
          )
          return Ok(())
        }
      }
      if not(self.manager.has_session(context_id)) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + context_id,
        )
        return Ok(())
      }
      let base_url = self.get_context_cookie_base_url(context_id)
      let result : Map[String, Json] = {
        "baseUrl": Json::string(base_url),
        "domain": Json::string(storage_cookie_domain_from_base_url(base_url)),
        "defaultPath": Json::string(storage_cookie_default_path(base_url)),
        "userContext": Json::string(
          self.resolve_storage_user_context(context_id),
        ),
      }
      match storage_cookie_origin_from_base_url(base_url) {
        Some(origin) => result["origin"] = Json::string(origin)
        None => result["origin"] = Json::null()
      }
      self.send_success(request.id, Some(make_object(result)))
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown method: storage." + action,
      )
      Ok(())
    }
  }
}

///|
fn BidiProtocol::normalize_storage_cookie_filter(
  self : BidiProtocol,
  request_id : Int,
  raw_filter : Json?,
) -> StorageCookieFilter? {
  match raw_filter {
    None | Some(Null) =>
      Some({
        domain: None,
        name: None,
        path: None,
        http_only: None,
        secure: None,
        expiry: None,
        size: None,
        same_site: None,
        value_text: None,
      })
    Some(Object(map)) => {
      let mut domain : String? = None
      let mut name : String? = None
      let mut path : String? = None
      let mut http_only : Bool? = None
      let mut secure : Bool? = None
      let mut expiry : Int? = None
      let mut size : Int? = None
      let mut same_site : String? = None
      let mut value_text : String? = None

      match map.get("domain") {
        Some(String(value)) =>
          domain = Some(
            storage_strip_leading_dot(value.trim().to_string().to_lower()),
          )
        Some(Null) | None => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "filter.domain must be a string",
          )
          return None
        }
      }
      match map.get("name") {
        Some(String(value)) => name = Some(value)
        Some(Null) | None => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "filter.name must be a string",
          )
          return None
        }
      }
      match map.get("path") {
        Some(String(value)) => path = Some(value)
        Some(Null) | None => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "filter.path must be a string",
          )
          return None
        }
      }
      match map.get("httpOnly") {
        Some(True) => http_only = Some(true)
        Some(False) => http_only = Some(false)
        Some(Null) | None => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "filter.httpOnly must be a boolean",
          )
          return None
        }
      }
      match map.get("secure") {
        Some(True) => secure = Some(true)
        Some(False) => secure = Some(false)
        Some(Null) | None => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "filter.secure must be a boolean",
          )
          return None
        }
      }
      match map.get("expiry") {
        Some(value) =>
          match storage_json_non_negative_int(value) {
            Some(parsed) => expiry = Some(parsed)
            None => {
              self.send_error(
                request_id, "invalid argument", "filter.expiry must be a non-negative integer",
              )
              return None
            }
          }
        None => ()
      }
      match map.get("size") {
        Some(value) =>
          match storage_json_non_negative_int(value) {
            Some(parsed) => size = Some(parsed)
            None => {
              self.send_error(
                request_id, "invalid argument", "filter.size must be a non-negative integer",
              )
              return None
            }
          }
        None => ()
      }
      match map.get("sameSite") {
        Some(String(value)) =>
          if storage_same_site_is_valid(value) {
            same_site = Some(value)
          } else {
            self.send_error(
              request_id, "invalid argument", "filter.sameSite is invalid",
            )
            return None
          }
        Some(Null) | None => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "filter.sameSite must be a string",
          )
          return None
        }
      }
      match map.get("value") {
        Some(value) =>
          match
            self.storage_value_text_from_json(request_id, value, "filter.value") {
            Some(text) => value_text = Some(text)
            None => return None
          }
        None => ()
      }

      Some({
        domain,
        name,
        path,
        http_only,
        secure,
        expiry,
        size,
        same_site,
        value_text,
      })
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "filter must be an object",
      )
      None
    }
  }
}

///|
fn BidiProtocol::normalize_storage_cookie_input(
  self : BidiProtocol,
  request_id : Int,
  raw_cookie : Json,
) -> StoredCookie? {
  let map = match raw_cookie {
    Object(map) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "cookie must be an object",
      )
      return None
    }
  }

  let domain = match map.get("domain") {
    Some(String(value)) =>
      storage_strip_leading_dot(value.trim().to_string().to_lower())
    _ => {
      self.send_error(
        request_id, "invalid argument", "cookie.domain must be a string",
      )
      return None
    }
  }
  let domain_explicit = match map.get("domainExplicit") {
    Some(True) => true
    Some(False) | Some(Null) | None => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "cookie.domainExplicit must be a boolean",
      )
      return None
    }
  }

  let name = match map.get("name") {
    Some(String(value)) => value
    _ => {
      self.send_error(
        request_id, "invalid argument", "cookie.name must be a string",
      )
      return None
    }
  }

  let value_text = match map.get("value") {
    Some(value) =>
      match
        self.storage_value_text_from_json(request_id, value, "cookie.value") {
        Some(text) => text
        None => return None
      }
    None => {
      self.send_error(
        request_id, "invalid argument", "cookie.value must be an object",
      )
      return None
    }
  }

  let path = match map.get("path") {
    Some(String(value)) => value
    Some(Null) | None => "/"
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "cookie.path must be a string",
      )
      return None
    }
  }

  let http_only = match map.get("httpOnly") {
    Some(True) => true
    Some(False) => false
    Some(Null) | None => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "cookie.httpOnly must be a boolean",
      )
      return None
    }
  }

  let secure = match map.get("secure") {
    Some(True) => true
    Some(False) => false
    Some(Null) | None => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "cookie.secure must be a boolean",
      )
      return None
    }
  }

  let same_site = match map.get("sameSite") {
    Some(String(value)) =>
      if storage_same_site_is_valid(value) {
        value
      } else {
        self.send_error(
          request_id, "invalid argument", "cookie.sameSite is invalid",
        )
        return None
      }
    Some(Null) | None => "none"
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "cookie.sameSite must be a string",
      )
      return None
    }
  }

  let expiry = match map.get("expiry") {
    Some(value) =>
      match storage_json_non_negative_int(value) {
        Some(parsed) => Some(parsed)
        None => {
          self.send_error(
            request_id, "invalid argument", "cookie.expiry must be a non-negative integer",
          )
          return None
        }
      }
    None => None
  }

  Some({
    name,
    value_text,
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

///|
fn BidiProtocol::storage_value_text_from_json(
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
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".type must be a string",
      )
      return None
    }
    None => {
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
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + ".value must be a string",
      )
      return None
    }
    None => {
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
fn BidiProtocol::normalize_storage_partition(
  self : BidiProtocol,
  request_id : Int,
  raw_partition : Json?,
) -> StoragePartitionInfo? {
  match raw_partition {
    None | Some(Null) =>
      Some({
        kind: "default",
        context_id: None,
        user_context: None,
        source_origin: None,
        partition_key: {},
      })
    Some(Object(map)) => {
      let partition_type = match map.get("type") {
        Some(String(value)) => value
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "partition.type must be a string",
          )
          return None
        }
        None => {
          self.send_error(
            request_id, "invalid argument", "partition.type must be a string",
          )
          return None
        }
      }
      if partition_type == "context" {
        let context_id = match map.get("context") {
          Some(String(context_id)) => context_id
          Some(_) => {
            self.send_error(
              request_id, "invalid argument", "partition.context must be a string",
            )
            return None
          }
          None => {
            self.send_error(
              request_id, "invalid argument", "partition.context must be a string",
            )
            return None
          }
        }
        if not(self.manager.has_session(context_id)) {
          self.send_error(
            request_id,
            "no such frame",
            "Unknown context: " + context_id,
          )
          return None
        }
        let user_context = self.resolve_storage_user_context(context_id)
        let partition_key : Map[String, Json] = {}
        partition_key["userContext"] = Json::string(user_context)
        match
          storage_cookie_origin_from_base_url(
            self.get_context_cookie_base_url(context_id),
          ) {
          Some(source_origin) =>
            if source_origin.length() > 0 {
              partition_key["sourceOrigin"] = Json::string(source_origin)
            }
          None => ()
        }
        Some({
          kind: "context",
          context_id: Some(context_id),
          user_context: Some(user_context),
          source_origin: storage_cookie_origin_from_base_url(
            self.get_context_cookie_base_url(context_id),
          ),
          partition_key,
        })
      } else if partition_type == "storageKey" {
        let partition_key : Map[String, Json] = {}
        let mut user_context : String? = None
        let mut source_origin : String? = None

        match map.get("sourceOrigin") {
          Some(String(origin)) => {
            source_origin = Some(origin)
            partition_key["sourceOrigin"] = Json::string(origin)
          }
          Some(Null) | None => ()
          Some(_) => {
            self.send_error(
              request_id, "invalid argument", "partition.sourceOrigin must be a string",
            )
            return None
          }
        }
        match map.get("userContext") {
          Some(String(user_context_id)) =>
            if self.user_contexts.get(user_context_id).unwrap_or(false) {
              user_context = Some(user_context_id)
              partition_key["userContext"] = Json::string(user_context_id)
            } else {
              self.send_error(
                request_id,
                "no such user context",
                "Unknown user context: " + user_context_id,
              )
              return None
            }
          Some(Null) | None => ()
          Some(_) => {
            self.send_error(
              request_id, "invalid argument", "partition.userContext must be a string",
            )
            return None
          }
        }

        Some({
          kind: "storageKey",
          context_id: None,
          user_context,
          source_origin,
          partition_key,
        })
      } else {
        self.send_error(
          request_id, "invalid argument", "partition.type is invalid",
        )
        None
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "partition must be an object",
      )
      None
    }
  }
}

///|
fn BidiProtocol::resolve_storage_user_context(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.context_user_context.get(ctx_id) {
    Some(user_context) => user_context
    None => {
      let ancestry = self.storage_context_ancestry(ctx_id)
      let mut idx = ancestry.length()
      while idx > 0 {
        idx = idx - 1
        let candidate = ancestry[idx]
        match self.context_user_context.get(candidate) {
          Some(user_context) => return user_context
          None => ()
        }
      }
      "default"
    }
  }
}

///|
fn BidiProtocol::storage_context_ancestry(
  self : BidiProtocol,
  ctx_id : String,
) -> Array[String] {
  let chain : Array[String] = []
  let seen : Map[String, Bool] = {}
  let mut current : String? = Some(ctx_id)
  while current != None {
    match current {
      Some(current_id) =>
        if current_id.length() == 0 || seen.contains(current_id) {
          current = None
        } else {
          chain.push(current_id)
          seen[current_id] = true
          current = self.context_parent.get(current_id)
        }
      None => ()
    }
  }
  let ordered : Array[String] = []
  let mut idx = chain.length()
  while idx > 0 {
    idx = idx - 1
    ordered.push(chain[idx])
  }
  ordered
}

///|
fn BidiProtocol::remember_synthetic_location_href(
  self : BidiProtocol,
  ctx_id : String,
  href : String,
) -> Unit {
  if href == "" {
    self.synthetic_location_href_by_context.remove(ctx_id)
  } else {
    self.synthetic_location_href_by_context[ctx_id] = href
  }
}

///|
fn BidiProtocol::resolve_synthetic_location_href(
  self : BidiProtocol,
  ctx_id : String,
) -> String? {
  self.synthetic_location_href_by_context.get(ctx_id)
}

///|
fn BidiProtocol::clear_synthetic_location_href(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.synthetic_location_href_by_context.remove(ctx_id)
}

///|
fn BidiProtocol::get_context_cookie_base_url(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.resolve_synthetic_location_href(ctx_id) {
    Some(href) if href != "" => return href
    _ => ()
  }
  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let url = session.get_url()
      if url == "about:blank" {
        "http://localhost:8000/webdriver/tests/support/empty.html"
      } else {
        url
      }
    }
    None => "http://localhost:8000/webdriver/tests/support/empty.html"
  }
}

///|
fn storage_json_non_negative_int(value : Json) -> Int? {
  match value {
    Number(n, ..) =>
      if n < 0.0 || n != n.to_int64().to_double() {
        None
      } else {
        Some(n.to_int64().to_int())
      }
    _ => None
  }
}

///|
fn storage_extract_url_fragment_param(url : String, key : String) -> String? {
  match find_substring(url, "#", 0) {
    Some(hash_idx) => {
      let start = hash_idx + 1
      if start >= url.length() {
        return None
      }
      let fragment = url[start:].to_string() catch { _ => "" }
      for part in fragment.split("&") {
        let raw = part.to_string()
        if raw.length() == 0 {
          continue
        }
        match find_substring(raw, "=", 0) {
          Some(eq_idx) => {
            let part_key = raw[:eq_idx].to_string() catch { _ => "" }
            if part_key == key {
              let value_start = eq_idx + 1
              if value_start <= raw.length() {
                return Some(raw[value_start:].to_string() catch { _ => "" })
              }
              return Some("")
            }
          }
          None => if raw == key { return Some("") }
        }
      }
      None
    }
    None => None
  }
}

///|
fn storage_inline_cookie_host(url : String) -> String {
  let domain_value = storage_extract_url_fragment_param(url, "domain").unwrap_or(
    "",
  )
  let base_host = if domain_value == "" || domain_value == "default" {
    "localhost"
  } else if domain_value == "alt" {
    "alt.localhost"
  } else if domain_value.contains(".") || domain_value.contains(":") {
    domain_value
  } else {
    domain_value + ".localhost"
  }
  let subdomain = storage_extract_url_fragment_param(url, "subdomain").unwrap_or(
    "",
  )
  if subdomain == "" {
    base_host
  } else {
    subdomain + "." + base_host
  }
}

///|
fn storage_http_host(url : String, scheme_len : Int) -> String? {
  let chars = url.to_array()
  let mut end = chars.length()
  for i = scheme_len; i < chars.length(); i = i + 1 {
    if chars[i] == '/' || chars[i] == '?' || chars[i] == '#' {
      end = i
      break
    }
  }
  if end <= scheme_len {
    return None
  }
  let host = url[scheme_len:end].to_string() catch { _ => "" }
  if host.length() == 0 {
    None
  } else {
    Some(host)
  }
}

///|
fn storage_strip_port(host : String) -> String {
  match find_substring(host, ":", 0) {
    Some(idx) => host[:idx].to_string() catch { _ => host }
    None => host
  }
}

///|
fn storage_http_path(url : String, scheme_len : Int) -> String {
  let chars = url.to_array()
  let mut start = chars.length()
  for i = scheme_len; i < chars.length(); i = i + 1 {
    if chars[i] == '/' {
      start = i
      break
    }
    if chars[i] == '?' || chars[i] == '#' {
      return "/"
    }
  }
  if start >= chars.length() {
    return "/"
  }
  let mut end = chars.length()
  for i = start; i < chars.length(); i = i + 1 {
    if chars[i] == '?' || chars[i] == '#' {
      end = i
      break
    }
  }
  let path = url[start:end].to_string() catch { _ => "/" }
  if path.length() == 0 {
    "/"
  } else {
    path
  }
}

///|
fn storage_cookie_origin_from_base_url(base_url : String) -> String? {
  if base_url.has_prefix("http://") {
    match storage_http_host(base_url, 7) {
      Some(host) => Some("http://" + host)
      None => None
    }
  } else if base_url.has_prefix("https://") {
    match storage_http_host(base_url, 8) {
      Some(host) => Some("https://" + host)
      None => None
    }
  } else if base_url.has_prefix("data:") {
    let protocol = match
      storage_extract_url_fragment_param(base_url, "protocol") {
      Some("https") => "https"
      _ => "http"
    }
    Some(protocol + "://" + storage_inline_cookie_host(base_url) + ":8000")
  } else {
    None
  }
}

///|
fn storage_cookie_domain_from_base_url(base_url : String) -> String {
  if base_url.has_prefix("http://") {
    match storage_http_host(base_url, 7) {
      Some(host) => storage_strip_port(host).to_lower()
      None => "localhost"
    }
  } else if base_url.has_prefix("https://") {
    match storage_http_host(base_url, 8) {
      Some(host) => storage_strip_port(host).to_lower()
      None => "localhost"
    }
  } else if base_url.has_prefix("data:") {
    storage_inline_cookie_host(base_url).to_lower()
  } else {
    "localhost"
  }
}

///|
fn storage_cookie_default_path(base_url : String) -> String {
  let path = if base_url.has_prefix("http://") {
    storage_http_path(base_url, 7)
  } else if base_url.has_prefix("https://") {
    storage_http_path(base_url, 8)
  } else {
    return "/webdriver/tests/support"
  }
  if path == "/" || not(path.has_prefix("/")) {
    return "/"
  }
  if path.has_suffix("/") {
    let trimmed = path[:path.length() - 1].to_string() catch { _ => "/" }
    if trimmed.length() == 0 {
      "/"
    } else {
      trimmed
    }
  } else {
    match find_last_slash(path) {
      Some(idx) =>
        if idx == 0 {
          "/"
        } else {
          path[:idx].to_string() catch {
            _ => "/"
          }
        }
      None => "/"
    }
  }
}

///|
fn storage_request_path(request_url : String) -> String {
  if request_url.has_prefix("http://") {
    storage_http_path(request_url, 7)
  } else if request_url.has_prefix("https://") {
    storage_http_path(request_url, 8)
  } else {
    storage_cookie_default_path(request_url)
  }
}

///|
fn find_last_slash(value : String) -> Int? {
  let chars = value.to_array()
  let mut idx = chars.length()
  while idx > 0 {
    idx = idx - 1
    if chars[idx] == '/' {
      return Some(idx)
    }
  }
  None
}

///|
fn storage_origin_host(origin : String) -> String? {
  if origin.has_prefix("http://") {
    match storage_http_host(origin, 7) {
      Some(host) => Some(storage_strip_port(host).to_lower())
      None => None
    }
  } else if origin.has_prefix("https://") {
    match storage_http_host(origin, 8) {
      Some(host) => Some(storage_strip_port(host).to_lower())
      None => None
    }
  } else {
    None
  }
}

///|
fn storage_origins_equivalent(lhs : String?, rhs : String?) -> Bool {
  match (lhs, rhs) {
    (Some(left), Some(right)) =>
      if left == right {
        true
      } else {
        match (storage_origin_host(left), storage_origin_host(right)) {
          (Some(left_host), Some(right_host)) =>
            left_host.length() > 0 && left_host == right_host
          _ => false
        }
      }
    (None, None) => true
    _ => false
  }
}

///|
fn storage_make_cookie_identity(cookie : StoredCookie) -> String {
  cookie.name +
  "|" +
  cookie.domain +
  "|" +
  cookie.path +
  "|" +
  cookie.context_id.unwrap_or("") +
  "|" +
  cookie.user_context.unwrap_or("") +
  "|" +
  cookie.source_origin.unwrap_or("")
}

///|
fn storage_cookie_matches_request_url(
  cookie : StoredCookie,
  request_url : String?,
) -> Bool {
  match request_url {
    None => true
    Some(url) =>
      if url.length() == 0 {
        true
      } else {
        let request_host = storage_cookie_domain_from_base_url(url).to_lower()
        let request_path = storage_request_path(url)
        let normalized_domain = storage_strip_leading_dot(
          cookie.domain.to_lower(),
        )
        if normalized_domain.length() > 0 &&
          request_host != normalized_domain &&
          not(request_host.has_suffix("." + normalized_domain)) {
          return false
        }
        let cookie_path = cookie.path
        if cookie_path.length() == 0 || cookie_path == "/" {
          return true
        }
        if request_path == cookie_path {
          return true
        }
        if not(request_path.has_prefix(cookie_path)) {
          return false
        }
        if cookie_path.has_suffix("/") {
          return true
        }
        if request_path.length() == cookie_path.length() {
          return true
        }
        let request_chars = request_path.to_array()
        cookie_path.length() < request_chars.length() &&
        request_chars[cookie_path.length()] == '/'
      }
  }
}

///|
fn BidiProtocol::store_storage_cookie(
  self : BidiProtocol,
  cookie : StoredCookie,
) -> Unit {
  let scope_id = match cookie.context_id {
    Some(context_id) => context_id
    None =>
      "storage::" +
      cookie.user_context.unwrap_or("default") +
      "::" +
      cookie.source_origin.unwrap_or("")
  }
  let jar : Map[String, StoredCookie] = self.storage_cookies_by_scope
    .get(scope_id)
    .unwrap_or({})
  jar[storage_make_cookie_identity(cookie)] = cookie
  self.storage_cookies_by_scope[scope_id] = jar
}

///|
fn BidiProtocol::delete_matching_storage_cookie_identity(
  self : BidiProtocol,
  context_id : String?,
  user_context : String?,
  source_origin : String?,
  name : String,
  domain : String,
  path : String,
) -> Unit {
  let scope_ids : Array[String] = []
  for scope_id, _ in self.storage_cookies_by_scope {
    scope_ids.push(scope_id)
  }
  for scope_id in scope_ids {
    match self.storage_cookies_by_scope.get(scope_id) {
      Some(jar) => {
        let removal_ids : Array[String] = []
        for cookie_id, cookie in jar {
          if cookie.name != name ||
            cookie.domain != domain ||
            cookie.path != path {
            continue
          }
          match context_id {
            Some(expected_context) =>
              if cookie.context_id != Some(expected_context) {
                continue
              }
            None => ()
          }
          match user_context {
            Some(expected_user_context) =>
              if cookie.user_context != Some(expected_user_context) {
                continue
              }
            None => ()
          }
          match source_origin {
            Some(expected_source_origin) =>
              if cookie.source_origin != Some(expected_source_origin) {
                continue
              }
            None => ()
          }
          removal_ids.push(cookie_id)
        }
        for cookie_id in removal_ids {
          jar.remove(cookie_id)
        }
        if jar.length() == 0 {
          self.storage_cookies_by_scope.remove(scope_id)
        } else {
          self.storage_cookies_by_scope[scope_id] = jar
        }
      }
      None => ()
    }
  }
}

///|
fn BidiProtocol::resolve_storage_request_cookies(
  self : BidiProtocol,
  ctx_id : String,
  request_url : String?,
) -> Array[Json] {
  self.prune_expired_storage_cookies()
  let merged : Map[String, StoredCookie] = {}
  for scope_id in self.storage_context_ancestry(ctx_id) {
    match self.storage_cookies_by_scope.get(scope_id) {
      Some(jar) =>
        for cookie_id, cookie in jar {
          merged[cookie_id] = cookie
        }
      None => ()
    }
  }
  let cookies : Array[Json] = []
  for _, cookie in merged {
    if storage_cookie_matches_request_url(cookie, request_url) {
      cookies.push(storage_cookie_to_request_json(cookie))
    }
  }
  cookies
}

///|
fn BidiProtocol::prune_expired_storage_cookies(self : BidiProtocol) -> Unit {
  let now = storage_now_seconds()
  let scope_ids : Array[String] = []
  for scope_id, _ in self.storage_cookies_by_scope {
    scope_ids.push(scope_id)
  }
  for scope_id in scope_ids {
    match self.storage_cookies_by_scope.get(scope_id) {
      Some(jar) => {
        let removal_ids : Array[String] = []
        for cookie_id, cookie in jar {
          match cookie.expiry {
            Some(expiry) => if expiry <= now { removal_ids.push(cookie_id) }
            None => ()
          }
        }
        for cookie_id in removal_ids {
          jar.remove(cookie_id)
        }
        if jar.length() == 0 {
          self.storage_cookies_by_scope.remove(scope_id)
        } else {
          self.storage_cookies_by_scope[scope_id] = jar
        }
      }
      None => ()
    }
  }
}

///|
fn BidiProtocol::list_storage_cookies(
  self : BidiProtocol,
) -> Array[StoredCookie] {
  self.prune_expired_storage_cookies()
  let cookies : Array[StoredCookie] = []
  for _, jar in self.storage_cookies_by_scope {
    for _, cookie in jar {
      cookies.push(cookie)
    }
  }
  cookies
}

///|
fn BidiProtocol::storage_cookie_matches_partition(
  self : BidiProtocol,
  cookie : StoredCookie,
  partition : StoragePartitionInfo,
) -> Bool {
  if partition.kind == "default" {
    return true
  }
  if partition.kind == "context" {
    return cookie.context_id == partition.context_id
  }
  match partition.user_context {
    Some(user_context) =>
      if cookie.user_context != Some(user_context) {
        return false
      }
    None => ()
  }
  match partition.source_origin {
    Some(source_origin) => {
      let candidate_source_origin = self.storage_cookie_effective_source_origin(
        cookie,
      )
      storage_origins_equivalent(candidate_source_origin, Some(source_origin))
    }
    None => true
  }
}

///|
fn BidiProtocol::storage_cookie_effective_source_origin(
  self : BidiProtocol,
  cookie : StoredCookie,
) -> String? {
  match cookie.context_id {
    Some(context_id) =>
      match
        storage_cookie_origin_from_base_url(
          self.get_context_cookie_base_url(context_id),
        ) {
        Some(origin) => Some(origin)
        None => cookie.source_origin
      }
    None => cookie.source_origin
  }
}

///|
fn storage_cookie_matches_filter(
  cookie : StoredCookie,
  filter : StorageCookieFilter,
) -> Bool {
  match filter.domain {
    Some(domain) => if cookie.domain != domain { return false }
    None => ()
  }
  match filter.name {
    Some(name) => if cookie.name != name { return false }
    None => ()
  }
  match filter.path {
    Some(path) => if cookie.path != path { return false }
    None => ()
  }
  match filter.http_only {
    Some(http_only) => if cookie.http_only != http_only { return false }
    None => ()
  }
  match filter.secure {
    Some(secure) => if cookie.secure != secure { return false }
    None => ()
  }
  match filter.expiry {
    Some(expiry) => if cookie.expiry != Some(expiry) { return false }
    None => ()
  }
  match filter.size {
    Some(size) => if storage_cookie_size(cookie) != size { return false }
    None => ()
  }
  match filter.same_site {
    Some(same_site) => if cookie.same_site != same_site { return false }
    None => ()
  }
  match filter.value_text {
    Some(value_text) => if cookie.value_text != value_text { return false }
    None => ()
  }
  true
}

///|
fn BidiProtocol::delete_storage_cookies(
  self : BidiProtocol,
  cookie_filter : StorageCookieFilter,
  partition : StoragePartitionInfo,
) -> Unit {
  self.prune_expired_storage_cookies()
  let scope_ids : Array[String] = []
  for scope_id, _ in self.storage_cookies_by_scope {
    scope_ids.push(scope_id)
  }
  for scope_id in scope_ids {
    match self.storage_cookies_by_scope.get(scope_id) {
      Some(jar) => {
        let removal_ids : Array[String] = []
        for cookie_id, cookie in jar {
          if self.storage_cookie_matches_partition(cookie, partition) &&
            storage_cookie_matches_filter(cookie, cookie_filter) {
            removal_ids.push(cookie_id)
          }
        }
        for cookie_id in removal_ids {
          jar.remove(cookie_id)
        }
        if jar.length() == 0 {
          self.storage_cookies_by_scope.remove(scope_id)
        } else {
          self.storage_cookies_by_scope[scope_id] = jar
        }
      }
      None => ()
    }
  }
}

///|
fn BidiProtocol::remove_storage_cookie_scope(
  self : BidiProtocol,
  scope_id : String,
) -> Unit {
  self.storage_cookies_by_scope.remove(scope_id)
}

///|
fn BidiProtocol::remove_storage_cookies_for_user_context(
  self : BidiProtocol,
  user_context_id : String,
) -> Unit {
  let scope_ids : Array[String] = []
  for scope_id, _ in self.storage_cookies_by_scope {
    scope_ids.push(scope_id)
  }
  for scope_id in scope_ids {
    match self.storage_cookies_by_scope.get(scope_id) {
      Some(jar) => {
        let removal_ids : Array[String] = []
        for cookie_id, cookie in jar {
          if cookie.user_context == Some(user_context_id) {
            removal_ids.push(cookie_id)
          }
        }
        for cookie_id in removal_ids {
          jar.remove(cookie_id)
        }
        if jar.length() == 0 {
          self.storage_cookies_by_scope.remove(scope_id)
        } else {
          self.storage_cookies_by_scope[scope_id] = jar
        }
      }
      None => ()
    }
  }
}

///|
fn BidiProtocol::resolve_document_cookie(
  self : BidiProtocol,
  ctx_id : String,
) -> String? {
  self.prune_expired_storage_cookies()
  let merged : Map[String, StoredCookie] = {}
  for scope_id in self.storage_context_ancestry(ctx_id) {
    match self.storage_cookies_by_scope.get(scope_id) {
      Some(jar) =>
        for cookie_id, cookie in jar {
          merged[cookie_id] = cookie
        }
      None => ()
    }
  }
  let visible : Array[String] = []
  for _, cookie in merged {
    if cookie.http_only {
      continue
    }
    visible.push(cookie.name + "=" + cookie.value_text)
  }
  if visible.length() == 0 {
    None
  } else {
    Some(visible.join("; "))
  }
}

///|
fn BidiProtocol::remember_document_cookie(
  self : BidiProtocol,
  ctx_id : String,
  cookie_assignment : String,
) -> Unit {
  let parts : Array[String] = []
  for part in cookie_assignment.split(";") {
    parts.push(part.to_string().trim().to_string())
  }
  if parts.length() == 0 {
    return
  }
  let first_segment = parts[0]
  match find_substring(first_segment, "=", 0) {
    Some(eq_idx) => {
      let name = storage_slice(first_segment, 0, eq_idx)
      let value_start = eq_idx + 1
      let value = storage_slice_from(first_segment, value_start)
      let base_url = self.get_context_cookie_base_url(ctx_id)
      let mut domain = storage_cookie_domain_from_base_url(base_url)
      let mut domain_explicit = false
      let mut path = storage_cookie_default_path(base_url)
      let mut secure = false
      let mut same_site = "default"
      let mut http_only = false
      let mut expiry : Int? = None

      for raw_attr in parts {
        if raw_attr == first_segment || raw_attr.length() == 0 {
          continue
        }
        match find_substring(raw_attr, "=", 0) {
          Some(attr_eq_idx) => {
            let attr_name = storage_slice(raw_attr, 0, attr_eq_idx)
              .trim()
              .to_string()
              .to_lower()
            let attr_value_start = attr_eq_idx + 1
            let attr_value = storage_slice_from(raw_attr, attr_value_start)
              .trim()
              .to_string()
            if attr_name == "domain" {
              let normalized_domain = storage_strip_leading_dot(
                attr_value.trim().to_string().to_lower(),
              )
              if normalized_domain.length() > 0 {
                domain = normalized_domain
                domain_explicit = true
              }
            } else if attr_name == "path" {
              if attr_value.length() > 0 {
                path = attr_value
              }
            } else if attr_name == "expires" {
              let parsed_expiry = js_parse_cookie_expiry_seconds(attr_value)
              if parsed_expiry >= 0 {
                expiry = Some(parsed_expiry)
              }
            } else if attr_name == "max-age" {
              match parse_decimal_string(attr_value) {
                Some(max_age) => expiry = Some(storage_now_seconds() + max_age)
                None => ()
              }
            } else if attr_name == "samesite" {
              let lowered = attr_value.to_lower()
              if lowered == "none" || lowered == "lax" || lowered == "strict" {
                same_site = lowered
              }
            }
          }
          None => {
            let attr_name = raw_attr.trim().to_string().to_lower()
            if attr_name == "secure" {
              secure = true
            } else if attr_name == "httponly" {
              http_only = true
            }
          }
        }
      }

      let user_context = self.resolve_storage_user_context(ctx_id)
      let source_origin = storage_cookie_origin_from_base_url(base_url)
      let cookie : StoredCookie = {
        name: name.trim().to_string(),
        value_text: value.trim().to_string(),
        domain,
        domain_explicit,
        path,
        http_only,
        secure,
        same_site,
        expiry,
        context_id: Some(ctx_id),
        user_context: Some(user_context),
        source_origin,
      }
      match cookie.expiry {
        Some(cookie_expiry) =>
          if cookie_expiry <= storage_now_seconds() {
            self.delete_matching_storage_cookie_identity(
              cookie.context_id,
              cookie.user_context,
              cookie.source_origin,
              cookie.name,
              cookie.domain,
              cookie.path,
            )
          } else {
            self.store_storage_cookie(cookie)
          }
        None => self.store_storage_cookie(cookie)
      }
    }
    None => ()
  }
}

///|
fn extract_document_cookie_assignment(expression : String) -> String? {
  let trimmed = expression.trim().to_string()
  if not(trimmed.has_prefix("document.cookie")) {
    return None
  }
  let eq_idx = match find_substring(trimmed, "=", 0) {
    Some(idx) => idx
    None => return None
  }
  let chars = trimmed.to_array()
  let mut cursor = eq_idx + 1
  while cursor < chars.length() && chars[cursor] == ' ' {
    cursor = cursor + 1
  }
  if cursor >= chars.length() {
    return None
  }
  let quote = chars[cursor]
  if quote != '\'' && quote != '"' {
    return None
  }
  let mut end = cursor + 1
  while end < chars.length() && chars[end] != quote {
    end = end + 1
  }
  if end >= chars.length() {
    return None
  }
  let start = cursor + 1
  if start > end {
    return Some("")
  }
  Some(trimmed[start:end].to_string() catch { _ => "" })
}

///|
fn BidiProtocol::try_handle_synthetic_window_location_href_eval(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
) -> Bool {
  let expr = expression.trim().to_string()
  if expr != "window.location.href" {
    return false
  }
  match self.resolve_synthetic_location_href(ctx_id) {
    Some(href) => {
      let result = make_object({
        "realm": Json::string(realm_id),
        "result": make_object({
          "type": Json::string("string"),
          "value": Json::string(href),
        }),
      })
      self.send_success(request_id, Some(result))
      true
    }
    None => false
  }
}

///|
fn BidiProtocol::try_handle_synthetic_document_cookie_eval(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
) -> Bool {
  let expr = expression.trim().to_string()
  if expr == "document.cookie" {
    let value = self.resolve_document_cookie(ctx_id).unwrap_or("")
    let result = make_object({
      "realm": Json::string(realm_id),
      "result": make_object({
        "type": Json::string("string"),
        "value": Json::string(value),
      }),
    })
    self.send_success(request_id, Some(result))
    return true
  }
  match extract_document_cookie_assignment(expr) {
    Some(cookie_assignment) => {
      self.remember_document_cookie(ctx_id, cookie_assignment)
      self.send_script_undefined_result(request_id, realm_id)
      true
    }
    None => false
  }
}
