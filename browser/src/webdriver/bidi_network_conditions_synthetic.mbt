///|
fn build_offline_network_conditions_json() -> Json {
  make_object({ "type": Json::string("offline") })
}

///|
fn compact_network_conditions_function_source(
  function_declaration : String,
) -> String {
  let chars = function_declaration.to_array()
  let mut compact = ""
  for ch in chars {
    if ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t' {
      compact = compact + ch.to_string()
    }
  }
  compact
}

///|
fn get_first_string_argument(params : Json?) -> String? {
  match get_param_raw(params, "arguments") {
    Some(Array(arguments)) =>
      if arguments.length() > 0 {
        remote_value_as_string(arguments[0])
      } else {
        None
      }
    _ => None
  }
}

///|
fn BidiProtocol::emit_network_condition_messages_for_contexts(
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
fn BidiProtocol::resolve_effective_network_conditions(
  self : BidiProtocol,
  ctx_id : String,
) -> Json? {
  let ancestry = self.storage_context_ancestry(ctx_id)
  let mut index = ancestry.length()
  while index > 0 {
    index = index - 1
    let scope_id = ancestry[index]
    match self.emulation_network_conditions_by_context.get(scope_id) {
      Some(override_value) => return Some(override_value)
      None => ()
    }
  }
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  match self.emulation_network_conditions_by_user_context.get(user_context_id) {
    Some(override_value) => Some(override_value)
    None => self.emulation_network_conditions_global
  }
}

///|
fn BidiProtocol::resolve_effective_network_offline(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  match self.resolve_effective_network_conditions(ctx_id) {
    Some(Object(conditions_map)) =>
      match conditions_map.get("type") {
        Some(String("offline")) => true
        _ => false
      }
    _ => false
  }
}

///|
fn BidiProtocol::refresh_effective_network_conditions_for_all_contexts(
  self : BidiProtocol,
) -> Unit {
  for ctx_id in self.manager.list_sessions() {
    self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  }
}

///|
fn is_network_conditions_requires_network_transport(url : String) -> Bool {
  url.has_prefix("http://") || url.has_prefix("https://")
}

///|
fn BidiProtocol::navigation_blocked_by_network_conditions(
  self : BidiProtocol,
  ctx_id : String,
  resolved_url : String,
) -> Bool {
  is_network_conditions_requires_network_transport(resolved_url) &&
  self.resolve_effective_network_offline(ctx_id)
}

///|
fn BidiProtocol::try_handle_synthetic_network_conditions_fetch_call(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
  params : Json?,
  unwrap_result : Bool,
) -> Bool {
  if compact_network_conditions_function_source(function_declaration) !=
    "(url)=>fetch(url)" {
    return false
  }
  let request_url = match get_first_string_argument(params) {
    Some(request_url) => request_url
    None => return false
  }
  let resolved_url = self.resolve_navigation_target_url(ctx_id, request_url)
  if self.navigation_blocked_by_network_conditions(ctx_id, resolved_url) {
    self.send_script_exception_result(
      request_id,
      realm_id,
      make_object({
        "exceptionDetails": make_object({
          "text": Json::string("TypeError: Network is offline"),
        }),
      }),
    )
    return true
  }
  if is_network_conditions_requires_network_transport(resolved_url) {
    self.send_script_undefined_response(request_id, realm_id, unwrap_result)
    return true
  }
  false
}

///|
fn BidiProtocol::resolve_emulation_set_network_conditions(
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

  let network_conditions : Json? = match
    get_map_field_with_alias(map, "networkConditions", "network_conditions") {
    Some(Null) => None
    Some(Object(network_conditions_map)) =>
      match network_conditions_map.get("type") {
        Some(String("offline")) => Some(build_offline_network_conditions_json())
        _ => {
          self.send_error(
            request_id, "invalid argument", "networkConditions is invalid",
          )
          return None
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "networkConditions must be an object or null",
      )
      return None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "networkConditions must be provided",
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
      match network_conditions {
        Some(network_conditions) =>
          self.emulation_network_conditions_by_context[ctx_id] = network_conditions
        None => self.emulation_network_conditions_by_context.remove(ctx_id)
      }
    }
    self.refresh_effective_network_conditions_for_all_contexts()
    self.emit_network_condition_messages_for_contexts(
      target_contexts, target_user_contexts,
    )
    return Some(true)
  }

  if target_user_contexts.length() > 0 {
    for user_context_id in target_user_contexts {
      match network_conditions {
        Some(network_conditions) =>
          self.emulation_network_conditions_by_user_context[user_context_id] = network_conditions
        None =>
          self.emulation_network_conditions_by_user_context.remove(
            user_context_id,
          )
      }
    }
    self.refresh_effective_network_conditions_for_all_contexts()
    self.emit_network_condition_messages_for_contexts(
      target_contexts, target_user_contexts,
    )
    return Some(true)
  }

  self.emulation_network_conditions_global = network_conditions
  self.refresh_effective_network_conditions_for_all_contexts()
  self.emit_network_condition_messages_for_contexts(
    target_contexts, target_user_contexts,
  )
  Some(true)
}
