///|
/// Dispatch permissions domain.
fn BidiProtocol::dispatch_permissions(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "setPermission" =>
      match
        self.resolve_permissions_set_permission(request.id, request.params) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
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

///|
fn BidiProtocol::resolve_permissions_set_permission(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let descriptor = match map.get("descriptor") {
    Some(Object(descriptor)) => descriptor
    _ => {
      self.send_error(
        request_id, "invalid argument", "descriptor must be an object",
      )
      return None
    }
  }
  let permission_name = match descriptor.get("name") {
    Some(String(permission_name)) =>
      if @browser_domain.is_supported_permission_name(permission_name) {
        permission_name
      } else {
        self.send_error(
          request_id, "invalid argument", "descriptor.name is invalid",
        )
        return None
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "descriptor.name must be a supported string",
      )
      return None
    }
  }

  let state = match map.get("state") {
    Some(String(state)) =>
      if state == "granted" || state == "denied" || state == "prompt" {
        state
      } else {
        self.send_error(request_id, "invalid argument", "state is invalid")
        return None
      }
    _ => {
      self.send_error(request_id, "invalid argument", "state must be a string")
      return None
    }
  }

  let origin = match map.get("origin") {
    Some(String(origin)) => origin
    _ => {
      self.send_error(request_id, "invalid argument", "origin must be a string")
      return None
    }
  }

  let user_context_id = match
    get_map_field_with_alias(map, "userContext", "user_context") {
    Some(String(user_context_id)) =>
      if !self.user_contexts.contains(user_context_id) {
        self.send_error(
          request_id,
          "no such user context",
          "Unknown user context: " + user_context_id,
        )
        return None
      } else {
        user_context_id
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContext must be a string",
      )
      return None
    }
    None => "default"
  }

  let embedded_origin = match
    get_map_field_with_alias(map, "embeddedOrigin", "embedded_origin") {
    Some(String(embedded_origin)) => embedded_origin
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "embeddedOrigin must be a string",
      )
      return None
    }
    None => ""
  }

  let scope_key = @browser_domain.permission_scope_key(
    permission_name,
    user_context_id,
    @browser_domain.normalize_permission_origin(origin),
    @browser_domain.normalize_permission_origin(embedded_origin),
  )
  if state == "prompt" {
    self.permission_state_by_scope.remove(scope_key)
  } else {
    self.permission_state_by_scope[scope_key] = state
  }
  Some(true)
}

///|
fn BidiProtocol::remove_permission_state_for_user_context(
  self : BidiProtocol,
  user_context_id : String,
) -> Unit {
  let keys : Array[String] = []
  for key, _ in self.permission_state_by_scope {
    if @browser_domain.permission_scope_belongs_to_user_context(
        key, user_context_id,
      ) {
      keys.push(key)
    }
  }
  for key in keys {
    self.permission_state_by_scope.remove(key)
  }
}

///|
fn BidiProtocol::try_handle_synthetic_permissions_query_call(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
  unwrap_result : Bool,
) -> Bool {
  if !function_declaration.contains("navigator.permissions.query(") {
    return false
  }
  let permission_name = match
    @browser_domain.extract_permissions_query_name(function_declaration) {
    Some(permission_name) =>
      if @browser_domain.is_supported_permission_name(permission_name) {
        permission_name
      } else {
        return false
      }
    None => return false
  }

  let state = self.resolve_permission_state_for_context(permission_name, ctx_id)
  let remote_value = make_object({
    "type": Json::string("string"),
    "value": Json::string(state),
  })
  if unwrap_result {
    self.send_script_synthetic_value_response(request_id, remote_value)
  } else {
    self.send_script_remote_value_response(
      request_id, realm_id, remote_value, false,
    )
  }
  true
}

///|
fn BidiProtocol::try_handle_synthetic_window_location_origin_call(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
  unwrap_result : Bool,
) -> Bool {
  if !(function_declaration.contains("window.location.origin") ||
    function_declaration.contains("location.origin")) {
    return false
  }
  let origin = self.permission_query_origin_for_context(ctx_id)
  self.send_script_remote_value_response(
    request_id,
    realm_id,
    make_object({
      "type": Json::string("string"),
      "value": Json::string(origin),
    }),
    unwrap_result,
  )
  true
}

///|
fn BidiProtocol::permission_query_origin_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  @browser_domain.normalize_permission_origin(
    derive_realm_origin(self.requested_navigation_url(ctx_id)),
  )
}

///|
fn BidiProtocol::resolve_permission_state_for_context(
  self : BidiProtocol,
  permission_name : String,
  ctx_id : String,
) -> String {
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  let origin = if permission_name == "storage-access" {
    match self.context_parent.get(ctx_id) {
      Some(parent_ctx_id) =>
        self.permission_query_origin_for_context(parent_ctx_id)
      None => self.permission_query_origin_for_context(ctx_id)
    }
  } else {
    self.permission_query_origin_for_context(ctx_id)
  }
  let embedded_origin = if permission_name == "storage-access" &&
    self.context_parent.contains(ctx_id) {
    self.permission_query_origin_for_context(ctx_id)
  } else {
    ""
  }
  let scope_key = @browser_domain.permission_scope_key(
    permission_name, user_context_id, origin, embedded_origin,
  )
  self.permission_state_by_scope.get(scope_key).unwrap_or("prompt")
}
