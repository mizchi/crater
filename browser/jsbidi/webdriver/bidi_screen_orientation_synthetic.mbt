///|
fn default_screen_orientation_json() -> Json {
  make_object({
    "natural": Json::string("portrait"),
    "type": Json::string("portrait-primary"),
    "angle": Json::number(0),
  })
}

///|
fn is_valid_screen_orientation_natural(value : String) -> Bool {
  value == "portrait" || value == "landscape"
}

///|
fn is_valid_screen_orientation_type(value : String) -> Bool {
  value == "portrait-primary" ||
  value == "portrait-secondary" ||
  value == "landscape-primary" ||
  value == "landscape-secondary"
}

///|
fn compute_screen_orientation_angle(
  orientation_type : String,
  natural : String,
) -> Int {
  match (natural, orientation_type) {
    ("portrait", "portrait-primary") => 0
    ("portrait", "landscape-primary") => 90
    ("portrait", "portrait-secondary") => 180
    ("portrait", "landscape-secondary") => 270
    ("landscape", "landscape-primary") => 0
    ("landscape", "portrait-primary") => 90
    ("landscape", "landscape-secondary") => 180
    ("landscape", "portrait-secondary") => 270
    _ => 0
  }
}

///|
fn normalize_screen_orientation_json(value : Json) -> Json? {
  let map = match value {
    Object(map) => map
    _ => return None
  }
  let natural = match map.get("natural") {
    Some(String(natural)) if is_valid_screen_orientation_natural(natural) =>
      natural
    _ => return None
  }
  let orientation_type = match map.get("type") {
    Some(String(orientation_type)) =>
      if is_valid_screen_orientation_type(orientation_type) {
        orientation_type
      } else {
        return None
      }
    _ => return None
  }
  Some(
    make_object({
      "natural": Json::string(natural),
      "type": Json::string(orientation_type),
      "angle": Json::number(
        compute_screen_orientation_angle(orientation_type, natural).to_double(),
      ),
    }),
  )
}

///|
fn BidiProtocol::resolve_effective_screen_orientation(
  self : BidiProtocol,
  ctx_id : String,
) -> Json {
  let ancestry = self.storage_context_ancestry(ctx_id)
  let mut index = ancestry.length()
  while index > 0 {
    index = index - 1
    let scope_id = ancestry[index]
    match self.emulation_screen_orientation_by_context.get(scope_id) {
      Some(override_value) => return override_value
      None => ()
    }
  }
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  match self.emulation_screen_orientation_by_user_context.get(user_context_id) {
    Some(override_value) => override_value
    None =>
      match self.emulation_screen_orientation_global {
        Some(override_value) => override_value
        None => default_screen_orientation_json()
      }
  }
}

///|
fn BidiProtocol::refresh_effective_screen_orientation_for_all_contexts(
  self : BidiProtocol,
) -> Unit {
  for ctx_id in self.manager.list_sessions() {
    self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  }
}

///|
fn BidiProtocol::emit_screen_orientation_messages_for_contexts(
  self : BidiProtocol,
  target_contexts : Array[String],
  target_user_contexts : Array[String],
) -> Unit {
  let affected_top_level_contexts : Array[String] = []
  if target_contexts.length() > 0 {
    for ctx_id in target_contexts {
      let top_level_ctx_id = self.resolve_top_level_context(ctx_id)
      if not(array_contains(affected_top_level_contexts, top_level_ctx_id)) {
        affected_top_level_contexts.push(top_level_ctx_id)
      }
    }
  } else {
    for ctx_id in self.manager.list_sessions() {
      let top_level_ctx_id = self.resolve_top_level_context(ctx_id)
      if array_contains(affected_top_level_contexts, top_level_ctx_id) {
        continue
      }
      if target_user_contexts.length() > 0 {
        let user_context_id = self.context_user_context
          .get(top_level_ctx_id)
          .unwrap_or("default")
        if not(array_contains(target_user_contexts, user_context_id)) {
          continue
        }
      }
      affected_top_level_contexts.push(top_level_ctx_id)
    }
  }
  for ctx_id in affected_top_level_contexts {
    let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
    self.process_channel_messages(ctx_id, realm_id)
  }
}

///|
fn BidiProtocol::resolve_emulation_set_screen_orientation_override(
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

  let screen_orientation : Json? = match
    get_map_field_with_alias(map, "screenOrientation", "screen_orientation") {
    Some(Null) => None
    Some(value) =>
      match normalize_screen_orientation_json(value) {
        Some(normalized) => Some(normalized)
        None => {
          self.send_error(
            request_id, "invalid argument", "screenOrientation is invalid",
          )
          return None
        }
      }
    None => {
      self.send_error(
        request_id, "invalid argument", "screenOrientation must be provided",
      )
      return None
    }
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
      match screen_orientation {
        Some(screen_orientation) =>
          self.emulation_screen_orientation_by_context[ctx_id] = screen_orientation
        None => self.emulation_screen_orientation_by_context.remove(ctx_id)
      }
    }
    self.refresh_effective_screen_orientation_for_all_contexts()
    self.emit_screen_orientation_messages_for_contexts(
      target_contexts, target_user_contexts,
    )
    return Some(true)
  }

  if target_user_contexts.length() > 0 {
    for user_context_id in target_user_contexts {
      match screen_orientation {
        Some(screen_orientation) =>
          self.emulation_screen_orientation_by_user_context[user_context_id] = screen_orientation
        None =>
          self.emulation_screen_orientation_by_user_context.remove(
            user_context_id,
          )
      }
    }
    self.refresh_effective_screen_orientation_for_all_contexts()
    self.emit_screen_orientation_messages_for_contexts(
      target_contexts, target_user_contexts,
    )
    return Some(true)
  }

  self.emulation_screen_orientation_global = screen_orientation
  self.refresh_effective_screen_orientation_for_all_contexts()
  self.emit_screen_orientation_messages_for_contexts(
    target_contexts, target_user_contexts,
  )
  Some(true)
}
