///|
/// Maximum length in bytes for a stored Authorization header value.
/// Real-world JWTs are typically under 4 KB; 8 KB leaves headroom
/// without making it cheap to wedge unbounded state.
const AUTH_HEADER_VALUE_LIMIT : Int = 8192

///|
/// Normalize an origin per the spec: only http/https, no path/query/
/// fragment, lowercased scheme and host, default port stripped.
fn normalize_origin(input : String) -> Result[String, String] {
  let trimmed = input.trim().to_owned()
  let scheme_end = match trimmed.find("://") {
    Some(idx) => idx
    None => return Err("origin must be a valid URL (scheme://host[:port])")
  }
  let scheme = trimmed.unsafe_substring(start=0, end=scheme_end).to_lower()
  if scheme != "http" && scheme != "https" {
    return Err("origin must use http or https scheme")
  }
  let host_start = scheme_end + 3
  let rest = trimmed.unsafe_substring(start=host_start, end=trimmed.length())
  // Reject path / query / fragment
  if rest.contains("/") || rest.contains("?") || rest.contains("#") {
    return Err("origin must not contain path / query / fragment")
  }
  if rest.length() == 0 {
    return Err("origin must include a host")
  }
  let lowered_host = rest.to_lower()
  // Strip default port
  let normalized_host_port = if scheme == "http" &&
    lowered_host.has_suffix(":80") {
    lowered_host.unsafe_substring(start=0, end=lowered_host.length() - 3)
  } else if scheme == "https" && lowered_host.has_suffix(":443") {
    lowered_host.unsafe_substring(start=0, end=lowered_host.length() - 4)
  } else {
    lowered_host
  }
  Ok(scheme + "://" + normalized_host_port)
}

///|
/// Validate a candidate header value. Reject empty, oversized, or
/// values containing control characters / ANSI escape sequences. Tab
/// (0x09) is allowed because it is sometimes legitimately used inside
/// scheme parameters.
fn validate_header_value(value : String) -> Result[Unit, String] {
  if value.length() == 0 {
    return Err("headerValue must not be empty")
  }
  if value.length() > AUTH_HEADER_VALUE_LIMIT {
    return Err("headerValue exceeds 8KB limit")
  }
  let chars = value.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let code = chars[i].to_int()
    if code == 0x1b {
      return Err("headerValue must not contain ANSI escape sequences")
    }
    if code < 0x20 && code != 0x09 {
      return Err("headerValue must not contain control characters")
    }
  }
  Ok(())
}

///|
/// Resolve the target context: explicit `context` param wins; otherwise
/// fall back to the active context. Returns None and sends an error
/// when the context argument is malformed or unknown.
fn BidiProtocol::resolve_authorization_context(
  self : BidiProtocol,
  map : Map[String, Json],
  request_id : Int,
) -> String? {
  match map.get("context") {
    Some(String(ctx)) =>
      if !self.manager.has_session(ctx) {
        self.send_error(request_id, "no such frame", "Unknown context: " + ctx)
        None
      } else {
        Some(ctx)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      None
    }
    None =>
      match self.default_context_id {
        Some(ctx) => Some(ctx)
        None => {
          self.send_error(
            request_id, "no such frame", "No active browsing context",
          )
          None
        }
      }
  }
}

///|
/// Handle `crater.setOriginAuthorization`. Persists a header value on
/// the per-session profile under a normalized origin key.
fn BidiProtocol::handle_crater_set_origin_authorization(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(m)) => m
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let raw_origin = match map.get("origin") {
    Some(String(o)) => o
    _ => {
      self.send_error(request_id, "invalid argument", "origin must be a string")
      return
    }
  }
  let header_value = match map.get("headerValue") {
    Some(String(v)) => v
    _ => {
      self.send_error(
        request_id, "invalid argument", "headerValue must be a string",
      )
      return
    }
  }
  let normalized = match normalize_origin(raw_origin) {
    Ok(o) => o
    Err(reason) => {
      self.send_error(request_id, "invalid argument", reason)
      return
    }
  }
  match validate_header_value(header_value) {
    Ok(_) => ()
    Err(reason) => {
      self.send_error(request_id, "invalid argument", reason)
      return
    }
  }
  let ctx_id = self.resolve_authorization_context(map, request_id)
  guard ctx_id is Some(ctx) else { return }
  let profile = match self.profile_for_session(ctx) {
    Some(p) => p
    None => {
      self.send_error(request_id, "no such frame", "Unknown context: " + ctx)
      return
    }
  }
  profile.auth_state().set_origin_header(normalized, header_value)
  self.push_authorization_snapshot(ctx)
  self.send_success(request_id, Some(make_object({})))
}

///|
/// Handle `crater.clearOriginAuthorization`. Removes any stored header
/// for the normalized origin from the per-session profile.
fn BidiProtocol::handle_crater_clear_origin_authorization(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(m)) => m
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let raw_origin = match map.get("origin") {
    Some(String(o)) => o
    _ => {
      self.send_error(request_id, "invalid argument", "origin must be a string")
      return
    }
  }
  let normalized = match normalize_origin(raw_origin) {
    Ok(o) => o
    Err(reason) => {
      self.send_error(request_id, "invalid argument", reason)
      return
    }
  }
  let ctx_id = self.resolve_authorization_context(map, request_id)
  guard ctx_id is Some(ctx) else { return }
  let profile = match self.profile_for_session(ctx) {
    Some(p) => p
    None => {
      self.send_error(request_id, "no such frame", "Unknown context: " + ctx)
      return
    }
  }
  profile.auth_state().clear_origin_header(normalized)
  self.push_authorization_snapshot(ctx)
  self.send_success(request_id, Some(make_object({})))
}

///|
/// Handle `crater.listOriginAuthorizations`. Returns the set of
/// registered origins without exposing any header values.
fn BidiProtocol::handle_crater_list_origin_authorizations(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map : Map[String, Json] = match params {
    Some(Object(m)) => m
    _ => Map([], capacity=0)
  }
  let ctx_id = self.resolve_authorization_context(map, request_id)
  guard ctx_id is Some(ctx) else { return }
  let profile = match self.profile_for_session(ctx) {
    Some(p) => p
    None => {
      self.send_error(request_id, "no such frame", "Unknown context: " + ctx)
      return
    }
  }
  let origins_json : Array[Json] = []
  let auth_state = profile.auth_state()
  for origin in auth_state.list_origins() {
    origins_json.push(make_object({ "origin": Json::string(origin) }))
  }
  self.send_success(
    request_id,
    Some(make_object({ "origins": Json::array(origins_json) })),
  )
}

///|
/// Serialize the partition's origin_headers as a JSON object suitable
/// for pushing into globalThis.__bidiContextAuth[ctxId]. Header values
/// only cross the JS bridge — the WebDriver-facing surface (list /
/// events) never serializes them.
fn BidiProtocol::serialize_auth_snapshot_for_runtime(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.profile_for_session(ctx_id) {
    Some(profile) => {
      let auth_state = profile.auth_state()
      let entries : Map[String, Json] = Map([], capacity=0)
      for origin in auth_state.list_origins() {
        match auth_state.header_for_origin(origin) {
          Some(value) => entries[origin] = Json::string(value)
          None => ()
        }
      }
      make_object(entries).stringify()
    }
    None => "{}"
  }
}

///|
/// Push the per-context Authorization snapshot to the JS runtime so
/// the fetch shim can attach the header on outbound requests.
fn BidiProtocol::push_authorization_snapshot(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let snapshot = self.serialize_auth_snapshot_for_runtime(ctx_id)
  set_runtime_context_authorization(ctx_id, snapshot)
}

///|
/// Dispatch crater.* extension commands. Currently scoped to the
/// origin-Authorization injection surface (set / clear / list); other
/// crater.* extensions live as separate dispatch branches today and
/// can be folded in if a second command lands here.
fn BidiProtocol::dispatch_crater(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "setOriginAuthorization" => {
      self.handle_crater_set_origin_authorization(request.id, request.params)
      Ok(())
    }
    "clearOriginAuthorization" => {
      self.handle_crater_clear_origin_authorization(request.id, request.params)
      Ok(())
    }
    "listOriginAuthorizations" => {
      self.handle_crater_list_origin_authorizations(request.id, request.params)
      Ok(())
    }
    "setOriginCredentials" => {
      self.handle_crater_set_origin_credentials(request.id, request.params)
      Ok(())
    }
    "clearOriginCredentials" => {
      self.handle_crater_clear_origin_credentials(request.id, request.params)
      Ok(())
    }
    "listOriginCredentials" => {
      self.handle_crater_list_origin_credentials(request.id, request.params)
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown method: " + request.method_name,
      )
      Ok(())
    }
  }
}
