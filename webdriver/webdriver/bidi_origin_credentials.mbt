///|
/// Maximum length in bytes for stored credential fields. RFC 7617 / 7616
/// don't impose a fixed limit, but capping at 1 KB each prevents a
/// malicious or accidental write from filling the per-session profile.
const CREDENTIAL_FIELD_LIMIT : Int = 1024

///|
/// Validate a candidate credential string (username or password).
/// Reject empty, oversized, or values containing control characters /
/// ANSI escape sequences. Same rules as `validate_header_value` minus
/// the tab allowance — credentials shouldn't contain control whitespace.
fn validate_credential_field(
  value : String,
  field_name : String,
) -> Result[Unit, String] {
  if value.length() == 0 {
    return Err(field_name + " must not be empty")
  }
  if value.length() > CREDENTIAL_FIELD_LIMIT {
    return Err(field_name + " exceeds 1KB limit")
  }
  let chars = value.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let code = chars[i].to_int()
    if code == 0x1b {
      return Err(field_name + " must not contain ANSI escape sequences")
    }
    if code < 0x20 {
      return Err(field_name + " must not contain control characters")
    }
  }
  Ok(())
}

///|
/// Handle `crater.setOriginCredentials`. Persists a username/password
/// pair on the per-session profile under a normalized origin key.
/// Mirror of `handle_crater_set_origin_authorization`; credentials are
/// only consumed by the runtime fetch shim's 401 Digest auto-retry path,
/// never sent unsolicited.
fn BidiProtocol::handle_crater_set_origin_credentials(
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
  let username = match map.get("username") {
    Some(String(v)) => v
    _ => {
      self.send_error(
        request_id, "invalid argument", "username must be a string",
      )
      return
    }
  }
  let password = match map.get("password") {
    Some(String(v)) => v
    _ => {
      self.send_error(
        request_id, "invalid argument", "password must be a string",
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
  match validate_credential_field(username, "username") {
    Ok(_) => ()
    Err(reason) => {
      self.send_error(request_id, "invalid argument", reason)
      return
    }
  }
  match validate_credential_field(password, "password") {
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
  profile.auth_state.set_origin_credentials(normalized, username, password)
  self.push_credentials_snapshot(ctx)
  self.send_success(request_id, Some(make_object({})))
}

///|
/// Handle `crater.clearOriginCredentials`. Removes any stored
/// credentials for the normalized origin from the per-session profile.
fn BidiProtocol::handle_crater_clear_origin_credentials(
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
  profile.auth_state.clear_origin_credentials(normalized)
  self.push_credentials_snapshot(ctx)
  self.send_success(request_id, Some(make_object({})))
}

///|
/// Handle `crater.listOriginCredentials`. Returns the set of registered
/// origins without exposing any username or password.
fn BidiProtocol::handle_crater_list_origin_credentials(
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
  for origin in profile.auth_state.list_credential_origins() {
    origins_json.push(make_object({ "origin": Json::string(origin) }))
  }
  self.send_success(
    request_id,
    Some(make_object({ "origins": Json::array(origins_json) })),
  )
}

///|
/// Serialize the partition's origin_credentials as a JSON object
/// suitable for pushing into globalThis.__bidiContextCredentials[ctxId].
/// Credential values only cross the JS bridge — the WebDriver-facing
/// surface (list / events) never serializes them.
fn BidiProtocol::serialize_credentials_snapshot_for_runtime(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.profile_for_session(ctx_id) {
    Some(profile) => {
      let entries : Map[String, Json] = Map([], capacity=0)
      for origin in profile.auth_state.list_credential_origins() {
        match profile.auth_state.credentials_for_origin(origin) {
          Some(creds) =>
            entries[origin] = make_object({
              "username": Json::string(creds.username),
              "password": Json::string(creds.password),
            })
          None => ()
        }
      }
      make_object(entries).stringify()
    }
    None => "{}"
  }
}

///|
/// Push the per-context credentials snapshot to the JS runtime so the
/// fetch shim's Digest auto-retry can resolve username/password by origin.
fn BidiProtocol::push_credentials_snapshot(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let snapshot = self.serialize_credentials_snapshot_for_runtime(ctx_id)
  set_runtime_context_credentials(ctx_id, snapshot)
}
