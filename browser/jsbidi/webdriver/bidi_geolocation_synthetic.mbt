///|
fn default_geolocation_coordinates_json() -> Json {
  make_object({
    "latitude": Json::number(35.6895),
    "longitude": Json::number(139.6917),
    "accuracy": Json::number(1.0),
  })
}

///|
fn build_geolocation_coordinates_override(coordinates : Json) -> Json {
  make_object({
    "kind": Json::string("coordinates"),
    "coordinates": coordinates,
  })
}

///|
fn build_geolocation_error_override(error_type : String) -> Json {
  make_object({
    "kind": Json::string("error"),
    "error": make_object({ "type": Json::string(error_type) }),
  })
}

///|
fn BidiProtocol::resolve_effective_geolocation_override(
  self : BidiProtocol,
  ctx_id : String,
) -> Json? {
  let ancestry = self.storage_context_ancestry(ctx_id)
  let mut index = ancestry.length()
  while index > 0 {
    index = index - 1
    let scope_id = ancestry[index]
    match self.emulation_geolocation_by_context.get(scope_id) {
      Some(override_value) => return Some(override_value)
      None => ()
    }
  }
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  match self.emulation_geolocation_by_user_context.get(user_context_id) {
    Some(override_value) => Some(override_value)
    None => self.emulation_geolocation_global
  }
}

///|
fn BidiProtocol::resolve_effective_geolocation_error_code(
  self : BidiProtocol,
  ctx_id : String,
) -> Int? {
  if self.resolve_permission_state_for_context("geolocation", ctx_id) !=
    "granted" {
    return Some(1)
  }
  match self.resolve_effective_geolocation_override(ctx_id) {
    Some(Object(override_map)) =>
      match override_map.get("kind") {
        Some(String("error")) => Some(2)
        _ => None
      }
    _ => None
  }
}

///|
fn BidiProtocol::resolve_effective_geolocation_coordinates(
  self : BidiProtocol,
  ctx_id : String,
) -> Json? {
  if self.resolve_permission_state_for_context("geolocation", ctx_id) !=
    "granted" {
    return None
  }
  match self.resolve_effective_geolocation_override(ctx_id) {
    Some(Object(override_map)) =>
      match (override_map.get("kind"), override_map.get("coordinates")) {
        (Some(String("coordinates")), Some(Object(coords_map))) =>
          Some(make_object(coords_map))
        _ => None
      }
    None => Some(default_geolocation_coordinates_json())
    _ => None
  }
}

///|
fn push_geolocation_number_remote_entry(
  entries : Array[Json],
  coordinates_map : Map[String, Json],
  key : String,
) -> Unit {
  match coordinates_map.get(key) {
    Some(Number(value, ..)) =>
      entries.push(
        Json::array([
          Json::string(key),
          make_object({
            "type": Json::string("number"),
            "value": Json::number(value),
          }),
        ]),
      )
    _ => ()
  }
}

///|
fn build_geolocation_coordinates_remote_value(coordinates : Json) -> Json {
  let entries : Array[Json] = []
  match coordinates {
    Object(coordinates_map) => {
      push_geolocation_number_remote_entry(entries, coordinates_map, "latitude")
      push_geolocation_number_remote_entry(
        entries, coordinates_map, "longitude",
      )
      push_geolocation_number_remote_entry(entries, coordinates_map, "accuracy")
      push_geolocation_number_remote_entry(entries, coordinates_map, "altitude")
      push_geolocation_number_remote_entry(
        entries, coordinates_map, "altitudeAccuracy",
      )
      push_geolocation_number_remote_entry(entries, coordinates_map, "heading")
      push_geolocation_number_remote_entry(entries, coordinates_map, "speed")
    }
    _ => ()
  }
  make_object({ "type": Json::string("object"), "value": Json::array(entries) })
}

///|
fn build_geolocation_error_remote_value(code : Int) -> Json {
  make_object({
    "type": Json::string("object"),
    "value": Json::array([
      Json::array([
        Json::string("code"),
        make_object({
          "type": Json::string("number"),
          "value": Json::number(code.to_double()),
        }),
      ]),
    ]),
  })
}

///|
fn geolocation_watch_scope_key(ctx_id : String, watch_id : Int) -> String {
  ctx_id + "|" + watch_id.to_string()
}

///|
fn geolocation_watch_scope_context(scope_key : String) -> String {
  match find_substring(scope_key, "|", 0) {
    Some(separator) => scope_key.unsafe_substring(start=0, end=separator)
    None => scope_key
  }
}

///|
fn extract_script_channel_name(params : Json?) -> String? {
  match get_param_raw(params, "arguments") {
    Some(Array(arguments)) =>
      for argument in arguments {
        match argument {
          Object(argument_map) =>
            match (argument_map.get("type"), argument_map.get("value")) {
              (Some(String("channel")), Some(Object(channel_map))) =>
                match channel_map.get("channel") {
                  Some(String(channel_name)) =>
                    if channel_name != "" {
                      return Some(channel_name)
                    }
                  _ => ()
                }
              _ => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn get_first_numeric_argument(params : Json?) -> Double? {
  match get_param_raw(params, "arguments") {
    Some(Array(arguments)) =>
      if arguments.length() > 0 {
        remote_value_as_number(arguments[0])
      } else {
        None
      }
    _ => None
  }
}

///|
fn BidiProtocol::emit_geolocation_watch_update_for_scope(
  self : BidiProtocol,
  scope_key : String,
) -> Unit {
  let ctx_id = geolocation_watch_scope_context(scope_key)
  let realm_id = match self.geolocation_watch_realm_by_scope.get(scope_key) {
    Some(realm_id) => realm_id
    None => return
  }
  let channel = match self.geolocation_watch_channel_by_scope.get(scope_key) {
    Some(channel) => channel
    None => return
  }
  match self.resolve_effective_geolocation_error_code(ctx_id) {
    Some(code) =>
      if self.geolocation_watch_notify_error_by_scope
        .get(scope_key)
        .unwrap_or(false) {
        self.emit_script_message(
          ctx_id,
          realm_id,
          channel,
          build_geolocation_error_remote_value(code),
        )
      }
    None =>
      if self.geolocation_watch_notify_success_by_scope
        .get(scope_key)
        .unwrap_or(false) {
        let coordinates = self
          .resolve_effective_geolocation_coordinates(ctx_id)
          .unwrap_or(default_geolocation_coordinates_json())
        self.emit_script_message(
          ctx_id,
          realm_id,
          channel,
          build_geolocation_coordinates_remote_value(coordinates),
        )
      }
  }
}

///|
fn BidiProtocol::notify_geolocation_watchers(self : BidiProtocol) -> Unit {
  let watcher_keys : Array[String] = []
  for scope_key, _ in self.geolocation_watch_channel_by_scope {
    watcher_keys.push(scope_key)
  }
  for scope_key in watcher_keys {
    self.emit_geolocation_watch_update_for_scope(scope_key)
  }
}

///|
fn BidiProtocol::register_geolocation_watch(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
  channel : String,
  notify_success : Bool,
  notify_error : Bool,
) -> Int {
  let watch_id = self.next_geolocation_watch_id
  self.next_geolocation_watch_id = self.next_geolocation_watch_id + 1
  let scope_key = geolocation_watch_scope_key(ctx_id, watch_id)
  self.geolocation_watch_channel_by_scope[scope_key] = channel
  self.geolocation_watch_realm_by_scope[scope_key] = realm_id
  self.geolocation_watch_notify_success_by_scope[scope_key] = notify_success
  self.geolocation_watch_notify_error_by_scope[scope_key] = notify_error
  self.emit_geolocation_watch_update_for_scope(scope_key)
  watch_id
}

///|
fn BidiProtocol::clear_geolocation_watch(
  self : BidiProtocol,
  ctx_id : String,
  watch_id : Int,
) -> Unit {
  let scope_key = geolocation_watch_scope_key(ctx_id, watch_id)
  self.geolocation_watch_channel_by_scope.remove(scope_key)
  self.geolocation_watch_realm_by_scope.remove(scope_key)
  self.geolocation_watch_notify_success_by_scope.remove(scope_key)
  self.geolocation_watch_notify_error_by_scope.remove(scope_key)
}

///|
fn normalize_geolocation_number_json(
  value : Json,
  min : Double,
  max : Double,
) -> Double? {
  json_as_safe_number(value, min, max)
}

///|
fn BidiProtocol::parse_geolocation_coordinates_param(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json,
) -> (Bool, Json?) {
  match raw_value {
    Null => (true, None)
    Object(coordinates_map) => {
      let latitude = match coordinates_map.get("latitude") {
        Some(value) =>
          match normalize_geolocation_number_json(value, -90.0, 90.0) {
            Some(parsed) => parsed
            None => {
              self.send_error(
                request_id, "invalid argument", "coordinates.latitude is invalid",
              )
              return (false, None)
            }
          }
        None => {
          self.send_error(
            request_id, "invalid argument", "coordinates.latitude must be provided",
          )
          return (false, None)
        }
      }
      let longitude = match coordinates_map.get("longitude") {
        Some(value) =>
          match normalize_geolocation_number_json(value, -180.0, 180.0) {
            Some(parsed) => parsed
            None => {
              self.send_error(
                request_id, "invalid argument", "coordinates.longitude is invalid",
              )
              return (false, None)
            }
          }
        None => {
          self.send_error(
            request_id, "invalid argument", "coordinates.longitude must be provided",
          )
          return (false, None)
        }
      }
      let accuracy = match coordinates_map.get("accuracy") {
        Some(value) =>
          match
            normalize_geolocation_number_json(value, 0.0, 9007199254740991.0) {
            Some(parsed) => parsed
            None => {
              self.send_error(
                request_id, "invalid argument", "coordinates.accuracy is invalid",
              )
              return (false, None)
            }
          }
        None => 1.0
      }
      let altitude = match coordinates_map.get("altitude") {
        Some(value) =>
          match
            normalize_geolocation_number_json(
              value, -9007199254740991.0, 9007199254740991.0,
            ) {
            Some(parsed) => Some(parsed)
            None => {
              self.send_error(
                request_id, "invalid argument", "coordinates.altitude is invalid",
              )
              return (false, None)
            }
          }
        None => None
      }
      let altitude_accuracy = match
        get_map_field_with_alias(
          coordinates_map, "altitudeAccuracy", "altitude_accuracy",
        ) {
        Some(value) =>
          match
            normalize_geolocation_number_json(value, 0.0, 9007199254740991.0) {
            Some(parsed) => Some(parsed)
            None => {
              self.send_error(
                request_id, "invalid argument", "coordinates.altitudeAccuracy is invalid",
              )
              return (false, None)
            }
          }
        None => None
      }
      if altitude_accuracy is Some(_) && altitude is None {
        self.send_error(
          request_id, "invalid argument", "coordinates.altitudeAccuracy requires altitude",
        )
        return (false, None)
      }
      let heading = match coordinates_map.get("heading") {
        Some(value) =>
          match normalize_geolocation_number_json(value, 0.0, 359.999999999) {
            Some(parsed) => Some(parsed)
            None => {
              self.send_error(
                request_id, "invalid argument", "coordinates.heading is invalid",
              )
              return (false, None)
            }
          }
        None => None
      }
      let speed = match coordinates_map.get("speed") {
        Some(value) =>
          match
            normalize_geolocation_number_json(value, 0.0, 9007199254740991.0) {
            Some(parsed) => Some(parsed)
            None => {
              self.send_error(
                request_id, "invalid argument", "coordinates.speed is invalid",
              )
              return (false, None)
            }
          }
        None => None
      }

      let normalized : Map[String, Json] = {}
      normalized["latitude"] = Json::number(latitude)
      normalized["longitude"] = Json::number(longitude)
      normalized["accuracy"] = Json::number(accuracy)
      match altitude {
        Some(parsed) => normalized["altitude"] = Json::number(parsed)
        None => ()
      }
      match altitude_accuracy {
        Some(parsed) => normalized["altitudeAccuracy"] = Json::number(parsed)
        None => ()
      }
      match heading {
        Some(parsed) => normalized["heading"] = Json::number(parsed)
        None => ()
      }
      match speed {
        Some(parsed) => normalized["speed"] = Json::number(parsed)
        None => ()
      }
      (true, Some(make_object(normalized)))
    }
    _ => {
      self.send_error(
        request_id, "invalid argument", "coordinates must be an object or null",
      )
      (false, None)
    }
  }
}

///|
fn BidiProtocol::parse_geolocation_error_param(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json,
) -> (Bool, String?) {
  match raw_value {
    Null => (true, None)
    Object(error_map) =>
      match error_map.get("type") {
        Some(String("positionUnavailable")) =>
          (true, Some("positionUnavailable"))
        Some(String(_)) => {
          self.send_error(
            request_id, "invalid argument", "error.type is invalid",
          )
          (false, None)
        }
        _ => {
          self.send_error(
            request_id, "invalid argument", "error.type must be provided",
          )
          (false, None)
        }
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "error must be an object or null",
      )
      (false, None)
    }
  }
}

///|
fn BidiProtocol::resolve_emulation_set_geolocation_override(
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

  let has_coordinates = map.contains("coordinates")
  let has_error = map.contains("error")
  if not(has_coordinates) && not(has_error) {
    self.send_error(
      request_id, "invalid argument", "coordinates or error must be provided",
    )
    return None
  }

  let coordinates_override : Json? = if has_coordinates {
    let raw_value = map.get("coordinates").unwrap_or(Json::null())
    let (ok, normalized_coordinates) = self.parse_geolocation_coordinates_param(
      request_id, raw_value,
    )
    if not(ok) {
      return None
    }
    match normalized_coordinates {
      Some(normalized_coordinates) =>
        Some(build_geolocation_coordinates_override(normalized_coordinates))
      None => None
    }
  } else {
    None
  }

  let error_override : Json? = if has_error {
    let raw_value = map.get("error").unwrap_or(Json::null())
    let (ok, error_type) = self.parse_geolocation_error_param(
      request_id, raw_value,
    )
    if not(ok) {
      return None
    }
    match error_type {
      Some(error_type) => Some(build_geolocation_error_override(error_type))
      None => None
    }
  } else {
    None
  }

  if coordinates_override is Some(_) && error_override is Some(_) {
    self.send_error(
      request_id, "invalid argument", "coordinates and error are mutually exclusive",
    )
    return None
  }

  let override_value = match coordinates_override {
    Some(value) => Some(value)
    None => error_override
  }

  let target_contexts : Array[String] = []
  match map.get("contexts") {
    Some(Array(contexts)) =>
      if contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return None
      } else {
        for context in contexts {
          match context {
            String(ctx_id) =>
              if not(self.manager.has_session(ctx_id)) {
                self.send_error(
                  request_id,
                  "no such frame",
                  "Unknown context: " + ctx_id,
                )
                return None
              } else if self.context_parent.contains(ctx_id) {
                self.send_error(
                  request_id, "invalid argument", "contexts must reference top-level browsing contexts",
                )
                return None
              } else if not(array_contains(target_contexts, ctx_id)) {
                target_contexts.push(ctx_id)
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "contexts entries must be strings",
              )
              return None
            }
          }
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return None
    }
    None => ()
  }

  let target_user_contexts : Array[String] = []
  match get_map_field_with_alias(map, "userContexts", "user_contexts") {
    Some(Array(user_contexts)) =>
      if user_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return None
      } else {
        for raw_user_context in user_contexts {
          match raw_user_context {
            String(user_context_id) =>
              if user_context_id == "" ||
                not(self.user_contexts.contains(user_context_id)) {
                self.send_error(
                  request_id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return None
              } else if not(
                  array_contains(target_user_contexts, user_context_id),
                ) {
                target_user_contexts.push(user_context_id)
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "userContexts entries must be strings",
              )
              return None
            }
          }
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return None
    }
    None => ()
  }

  if target_contexts.length() > 0 && target_user_contexts.length() > 0 {
    self.send_error(
      request_id, "invalid argument", "contexts and userContexts are mutually exclusive",
    )
    return None
  }

  if target_contexts.length() > 0 {
    for ctx_id in target_contexts {
      match override_value {
        Some(override_value) =>
          self.emulation_geolocation_by_context[ctx_id] = override_value
        None => self.emulation_geolocation_by_context.remove(ctx_id)
      }
    }
    self.notify_geolocation_watchers()
    return Some(true)
  }

  if target_user_contexts.length() > 0 {
    for user_context_id in target_user_contexts {
      match override_value {
        Some(override_value) =>
          self.emulation_geolocation_by_user_context[user_context_id] = override_value
        None =>
          self.emulation_geolocation_by_user_context.remove(user_context_id)
      }
    }
    self.notify_geolocation_watchers()
    return Some(true)
  }

  self.emulation_geolocation_global = override_value
  self.notify_geolocation_watchers()
  Some(true)
}

///|
fn BidiProtocol::try_handle_synthetic_geolocation_call(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
  params : Json?,
  unwrap_result : Bool,
) -> Bool {
  if function_declaration.contains("navigator.geolocation.clearWatch(") {
    let watch_id = match get_first_numeric_argument(params) {
      Some(value) => value.to_int()
      None => 0
    }
    self.clear_geolocation_watch(ctx_id, watch_id)
    self.send_script_undefined_response(request_id, realm_id, unwrap_result)
    return true
  }

  if function_declaration.contains("navigator.geolocation.watchPosition(") {
    let channel_name = match extract_script_channel_name(params) {
      Some(channel_name) => channel_name
      None => return false
    }
    let notify_success = function_declaration.contains("result.coords.toJSON()")
    let notify_error = function_declaration.contains("error.code")
    if not(notify_success) && not(notify_error) {
      return false
    }
    let watch_id = self.register_geolocation_watch(
      ctx_id, realm_id, channel_name, notify_success, notify_error,
    )
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({
        "type": Json::string("number"),
        "value": Json::number(watch_id.to_double()),
      }),
      unwrap_result,
    )
    return true
  }

  if not(
      function_declaration.contains("navigator.geolocation.getCurrentPosition("),
    ) {
    return false
  }

  match self.resolve_effective_geolocation_error_code(ctx_id) {
    Some(code) =>
      self.send_script_remote_value_response(
        request_id,
        realm_id,
        build_geolocation_error_remote_value(code),
        unwrap_result,
      )
    None => {
      let coordinates = self
        .resolve_effective_geolocation_coordinates(ctx_id)
        .unwrap_or(default_geolocation_coordinates_json())
      self.send_script_remote_value_response(
        request_id,
        realm_id,
        build_geolocation_coordinates_remote_value(coordinates),
        unwrap_result,
      )
    }
  }
  true
}
