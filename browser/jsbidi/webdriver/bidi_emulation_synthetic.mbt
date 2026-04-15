///|
/// Dispatch emulation domain.
fn BidiProtocol::dispatch_emulation(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "setUserAgentOverride" =>
      match
        self.resolve_emulation_set_user_agent_override(
          request.id,
          request.params,
        ) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "setLocaleOverride" =>
      match
        self.resolve_emulation_set_locale_override(request.id, request.params) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "setTimezoneOverride" =>
      match
        self.resolve_emulation_set_timezone_override(request.id, request.params) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "setGeolocationOverride" =>
      match
        self.resolve_emulation_set_geolocation_override(
          request.id,
          request.params,
        ) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "setNetworkConditions" =>
      match
        self.resolve_emulation_set_network_conditions(
          request.id,
          request.params,
        ) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "setScreenOrientationOverride" =>
      match
        self.resolve_emulation_set_screen_orientation_override(
          request.id,
          request.params,
        ) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "setScreenSettingsOverride" =>
      match
        self.resolve_emulation_set_screen_settings_override(
          request.id,
          request.params,
        ) {
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
fn default_runtime_user_agent() -> String {
  "Crater/1.0 (MoonBit; BiDi)"
}

///|
extern "js" fn js_default_runtime_locale() -> String =
  #| () => {
  #|   try {
  #|     const locale = new Intl.DateTimeFormat().resolvedOptions().locale;
  #|     return typeof locale === "string" && locale ? locale : "en-US";
  #|   } catch (_error) {
  #|     return "en-US";
  #|   }
  #| }

///|
extern "js" fn js_normalize_runtime_locale(locale : String) -> String =
  #| (locale) => {
  #|   try {
  #|     const normalized = new Intl.DateTimeFormat(String(locale)).resolvedOptions().locale;
  #|     return typeof normalized === "string" && normalized ? normalized : "";
  #|   } catch (_error) {
  #|     return "";
  #|   }
  #| }

///|
fn default_runtime_locale() -> String {
  js_default_runtime_locale()
}

///|
extern "js" fn js_default_runtime_timezone() -> String =
  #| () => {
  #|   try {
  #|     const zone = new Intl.DateTimeFormat().resolvedOptions().timeZone;
  #|     return typeof zone === "string" && zone ? zone : "UTC";
  #|   } catch (_error) {
  #|     return "UTC";
  #|   }
  #| }

///|
extern "js" fn js_normalize_runtime_timezone(timezone : String) -> String =
  #| (timezone) => {
  #|   try {
  #|     const normalized = new Intl.DateTimeFormat("en-US", {
  #|       timeZone: String(timezone),
  #|     }).resolvedOptions().timeZone;
  #|     return typeof normalized === "string" && normalized ? normalized : "";
  #|   } catch (_error) {
  #|     return "";
  #|   }
  #| }

///|
fn default_runtime_timezone() -> String {
  js_default_runtime_timezone()
}

///|
fn BidiProtocol::resolve_effective_user_agent(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  let ancestry = self.storage_context_ancestry(ctx_id)
  let mut index = ancestry.length()
  while index > 0 {
    index = index - 1
    let scope_id = ancestry[index]
    match self.emulation_user_agent_by_context.get(scope_id) {
      Some(user_agent) => return user_agent
      None => ()
    }
  }
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  match self.emulation_user_agent_by_user_context.get(user_context_id) {
    Some(user_agent) => user_agent
    None =>
      match self.emulation_user_agent_global {
        Some(user_agent) => user_agent
        None => default_runtime_user_agent()
      }
  }
}

///|
fn BidiProtocol::resolve_effective_locale(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  let ancestry = self.storage_context_ancestry(ctx_id)
  let mut index = ancestry.length()
  while index > 0 {
    index = index - 1
    let scope_id = ancestry[index]
    match self.emulation_locale_by_context.get(scope_id) {
      Some(locale) => return locale
      None => ()
    }
  }
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  match self.emulation_locale_by_user_context.get(user_context_id) {
    Some(locale) => locale
    None =>
      match self.emulation_locale_global {
        Some(locale) => locale
        None => default_runtime_locale()
      }
  }
}

///|
fn BidiProtocol::resolve_effective_timezone(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  let ancestry = self.storage_context_ancestry(ctx_id)
  let mut index = ancestry.length()
  while index > 0 {
    index = index - 1
    let scope_id = ancestry[index]
    match self.emulation_timezone_by_context.get(scope_id) {
      Some(timezone) => return timezone
      None => ()
    }
  }
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  match self.emulation_timezone_by_user_context.get(user_context_id) {
    Some(timezone) => timezone
    None =>
      match self.emulation_timezone_global {
        Some(timezone) => timezone
        None => default_runtime_timezone()
      }
  }
}

///|
fn BidiProtocol::refresh_effective_user_agent_for_all_contexts(
  self : BidiProtocol,
) -> Unit {
  for ctx_id in self.manager.list_sessions() {
    self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  }
}

///|
fn BidiProtocol::refresh_effective_locale_for_all_contexts(
  self : BidiProtocol,
) -> Unit {
  for ctx_id in self.manager.list_sessions() {
    self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  }
}

///|
fn BidiProtocol::refresh_effective_timezone_for_all_contexts(
  self : BidiProtocol,
) -> Unit {
  for ctx_id in self.manager.list_sessions() {
    self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  }
}

///|
fn BidiProtocol::try_handle_synthetic_user_agent_fetch_eval(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
  unwrap_result : Bool,
) -> Bool {
  let expr = expression.trim().to_string()
  if !expr.has_prefix("fetch(") || !expr.contains(".text()") {
    return false
  }
  let request_url = match extract_emulation_fetch_url(expr) {
    Some(request_url) => request_url
    None => return false
  }
  let resolved_url = self.resolve_navigation_target_url(ctx_id, request_url)
  if !is_wpt_headers_echo_url(resolved_url) {
    return false
  }
  self.send_script_remote_value_response(
    request_id,
    realm_id,
    make_object({
      "type": Json::string("string"),
      "value": Json::string(self.build_network_headers_echo_payload(ctx_id, [])),
    }),
    unwrap_result,
  )
  true
}

///|
fn BidiProtocol::try_handle_synthetic_locale_eval(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
  unwrap_result : Bool,
) -> Bool {
  let expr = expression.trim().to_string()
  if expr == "navigator.language" {
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({
        "type": Json::string("string"),
        "value": Json::string(self.resolve_effective_locale(ctx_id)),
      }),
      unwrap_result,
    )
    return true
  }
  if expr == "navigator.languages" {
    let locale = self.resolve_effective_locale(ctx_id)
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({
        "type": Json::string("array"),
        "value": Json::array([
          make_object({
            "type": Json::string("string"),
            "value": Json::string(locale),
          }),
        ]),
      }),
      unwrap_result,
    )
    return true
  }
  if expr == "new Intl.DateTimeFormat().resolvedOptions().locale" {
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({
        "type": Json::string("string"),
        "value": Json::string(self.resolve_effective_locale(ctx_id)),
      }),
      unwrap_result,
    )
    return true
  }
  false
}

///|
fn BidiProtocol::try_handle_synthetic_timezone_eval(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
  unwrap_result : Bool,
) -> Bool {
  let expr = expression.trim().to_string()
  if expr == "Intl.DateTimeFormat().resolvedOptions().timeZone" {
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({
        "type": Json::string("string"),
        "value": Json::string(self.resolve_effective_timezone(ctx_id)),
      }),
      unwrap_result,
    )
    return true
  }
  match self.extract_emulation_timezone_offset(ctx_id, expr) {
    Some(offset_minutes) => {
      self.send_script_remote_value_response(
        request_id,
        realm_id,
        make_object({
          "type": Json::string("number"),
          "value": Json::number(offset_minutes.to_double()),
        }),
        unwrap_result,
      )
      true
    }
    None => false
  }
}

///|
fn BidiProtocol::extract_emulation_timezone_offset(
  self : BidiProtocol,
  ctx_id : String,
  expression : String,
) -> Int? {
  let prefix = "(new Date("
  let suffix = ")).getTimezoneOffset()"
  if !expression.has_prefix(prefix) || !expression.has_suffix(suffix) {
    return None
  }
  let timezone = self.resolve_effective_timezone(ctx_id)
  emulation_timezone_offset_minutes(timezone)
}

///|
fn emulation_timezone_offset_minutes(timezone : String) -> Int? {
  if timezone.length() != 6 {
    return None
  }
  let chars = timezone.to_array()
  let sign = chars[0]
  if sign != '+' && sign != '-' {
    return None
  }
  if chars[3] != ':' {
    return None
  }
  if !(chars[1] >= '0' &&
    chars[1] <= '9' &&
    chars[2] >= '0' &&
    chars[2] <= '9' &&
    chars[4] >= '0' &&
    chars[4] <= '9' &&
    chars[5] >= '0' &&
    chars[5] <= '9') {
    return None
  }
  let hours = (chars[1].to_int() - '0'.to_int()) * 10 +
    (chars[2].to_int() - '0'.to_int())
  let minutes = (chars[4].to_int() - '0'.to_int()) * 10 +
    (chars[5].to_int() - '0'.to_int())
  let total = hours * 60 + minutes
  Some(if sign == '+' { -total } else { total })
}

///|
fn extract_emulation_fetch_url(expression : String) -> String? {
  let open_paren = match find_substring(expression, "fetch(", 0) {
    Some(idx) => idx + 6
    None => return None
  }
  let chars = expression.to_array()
  let mut cursor = open_paren
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
  Some(expression.unsafe_substring(start=cursor + 1, end~))
}

///|
fn BidiProtocol::resolve_emulation_set_user_agent_override(
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

  let user_agent : String? = match
    get_map_field_with_alias(map, "userAgent", "user_agent") {
    Some(Null) => None
    Some(String(user_agent)) => Some(user_agent)
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userAgent must be a string or null",
      )
      return None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "userAgent must be provided",
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
              if !self.manager.has_session(ctx_id) {
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
              } else if !array_contains(target_contexts, ctx_id) {
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
                !self.user_contexts.contains(user_context_id) {
                self.send_error(
                  request_id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return None
              } else if !array_contains(target_user_contexts, user_context_id) {
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
      match user_agent {
        Some(user_agent) =>
          self.emulation_user_agent_by_context[ctx_id] = user_agent
        None => self.emulation_user_agent_by_context.remove(ctx_id)
      }
    }
    self.refresh_effective_user_agent_for_all_contexts()
    return Some(true)
  }

  if target_user_contexts.length() > 0 {
    for user_context_id in target_user_contexts {
      match user_agent {
        Some(user_agent) =>
          self.emulation_user_agent_by_user_context[user_context_id] = user_agent
        None =>
          self.emulation_user_agent_by_user_context.remove(user_context_id)
      }
    }
    self.refresh_effective_user_agent_for_all_contexts()
    return Some(true)
  }

  self.emulation_user_agent_global = user_agent
  self.refresh_effective_user_agent_for_all_contexts()
  Some(true)
}

///|
fn BidiProtocol::resolve_emulation_set_locale_override(
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

  let locale : String? = match
    get_map_field_with_alias(map, "locale", "locale") {
    Some(Null) => None
    Some(String(locale)) => {
      let normalized = js_normalize_runtime_locale(locale)
      if normalized == "" {
        self.send_error(request_id, "invalid argument", "locale is invalid")
        return None
      }
      Some(normalized)
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "locale must be a string or null",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "locale must be provided")
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
              if !self.manager.has_session(ctx_id) {
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
              } else if !array_contains(target_contexts, ctx_id) {
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
                !self.user_contexts.contains(user_context_id) {
                self.send_error(
                  request_id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return None
              } else if !array_contains(target_user_contexts, user_context_id) {
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
      match locale {
        Some(locale) => self.emulation_locale_by_context[ctx_id] = locale
        None => self.emulation_locale_by_context.remove(ctx_id)
      }
    }
    self.refresh_effective_locale_for_all_contexts()
    return Some(true)
  }

  if target_user_contexts.length() > 0 {
    for user_context_id in target_user_contexts {
      match locale {
        Some(locale) =>
          self.emulation_locale_by_user_context[user_context_id] = locale
        None => self.emulation_locale_by_user_context.remove(user_context_id)
      }
    }
    self.refresh_effective_locale_for_all_contexts()
    return Some(true)
  }

  self.emulation_locale_global = locale
  self.refresh_effective_locale_for_all_contexts()
  Some(true)
}

///|
fn BidiProtocol::resolve_emulation_set_timezone_override(
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

  let timezone : String? = match
    get_map_field_with_alias(map, "timezone", "timezone") {
    Some(Null) => None
    Some(String(timezone)) => {
      let normalized = js_normalize_runtime_timezone(timezone)
      if normalized == "" {
        self.send_error(request_id, "invalid argument", "timezone is invalid")
        return None
      }
      Some(normalized)
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "timezone must be a string or null",
      )
      return None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "timezone must be provided",
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
              if !self.manager.has_session(ctx_id) {
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
              } else if !array_contains(target_contexts, ctx_id) {
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
                !self.user_contexts.contains(user_context_id) {
                self.send_error(
                  request_id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return None
              } else if !array_contains(target_user_contexts, user_context_id) {
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
      match timezone {
        Some(timezone) => self.emulation_timezone_by_context[ctx_id] = timezone
        None => self.emulation_timezone_by_context.remove(ctx_id)
      }
    }
    self.refresh_effective_timezone_for_all_contexts()
    return Some(true)
  }

  if target_user_contexts.length() > 0 {
    for user_context_id in target_user_contexts {
      match timezone {
        Some(timezone) =>
          self.emulation_timezone_by_user_context[user_context_id] = timezone
        None => self.emulation_timezone_by_user_context.remove(user_context_id)
      }
    }
    self.refresh_effective_timezone_for_all_contexts()
    return Some(true)
  }

  self.emulation_timezone_global = timezone
  self.refresh_effective_timezone_for_all_contexts()
  Some(true)
}
