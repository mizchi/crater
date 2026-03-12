///|
fn build_screen_area_json(width : Int, height : Int) -> Json {
  make_object({
    "width": Json::number(width.to_double()),
    "height": Json::number(height.to_double()),
    "availWidth": Json::number(width.to_double()),
    "availHeight": Json::number(height.to_double()),
  })
}

///|
fn normalize_screen_area_json(value : Json) -> Json? {
  let map = match value {
    Object(map) => map
    _ => return None
  }
  let width = match map.get("width") {
    Some(width) => json_as_safe_int(width, 0.0, 9007199254740991.0)
    None => None
  }
  let height = match map.get("height") {
    Some(height) => json_as_safe_int(height, 0.0, 9007199254740991.0)
    None => None
  }
  match (width, height) {
    (Some(width), Some(height)) => Some(build_screen_area_json(width, height))
    _ => None
  }
}

///|
fn BidiProtocol::resolve_effective_screen_area(
  self : BidiProtocol,
  ctx_id : String,
) -> Json {
  let ancestry = self.storage_context_ancestry(ctx_id)
  let mut index = ancestry.length()
  while index > 0 {
    index = index - 1
    let scope_id = ancestry[index]
    match self.emulation_screen_area_by_context.get(scope_id) {
      Some(override_value) => return override_value
      None => ()
    }
  }
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  match self.emulation_screen_area_by_user_context.get(user_context_id) {
    Some(override_value) => override_value
    None =>
      match self.emulation_screen_area_global {
        Some(override_value) => override_value
        None =>
          build_screen_area_json(
            self.resolve_effective_viewport_width(ctx_id),
            self.resolve_effective_viewport_height(ctx_id),
          )
      }
  }
}

///|
fn BidiProtocol::refresh_effective_screen_area_for_all_contexts(
  self : BidiProtocol,
) -> Unit {
  for ctx_id in self.manager.list_sessions() {
    self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  }
}

///|
fn BidiProtocol::resolve_emulation_set_screen_settings_override(
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

  let screen_area : Json? = match
    get_map_field_with_alias(map, "screenArea", "screen_area") {
    Some(Null) => None
    Some(value) =>
      match normalize_screen_area_json(value) {
        Some(normalized) => Some(normalized)
        None => {
          self.send_error(
            request_id, "invalid argument", "screenArea is invalid",
          )
          return None
        }
      }
    None => {
      self.send_error(
        request_id, "invalid argument", "screenArea must be provided",
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
      match screen_area {
        Some(screen_area) =>
          self.emulation_screen_area_by_context[ctx_id] = screen_area
        None => self.emulation_screen_area_by_context.remove(ctx_id)
      }
    }
    self.refresh_effective_screen_area_for_all_contexts()
    return Some(true)
  }

  if target_user_contexts.length() > 0 {
    for user_context_id in target_user_contexts {
      match screen_area {
        Some(screen_area) =>
          self.emulation_screen_area_by_user_context[user_context_id] = screen_area
        None =>
          self.emulation_screen_area_by_user_context.remove(user_context_id)
      }
    }
    self.refresh_effective_screen_area_for_all_contexts()
    return Some(true)
  }

  self.emulation_screen_area_global = screen_area
  self.refresh_effective_screen_area_for_all_contexts()
  Some(true)
}
