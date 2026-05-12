///|
/// Validate browser.createUserContext parameters.
fn BidiProtocol::validate_browser_create_user_context(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match params {
    None => ()
    Some(Object(map)) => {
      match
        get_map_field_with_alias(
          map, "acceptInsecureCerts", "accept_insecure_certs",
        ) {
        Some(True) | Some(False) => ()
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "acceptInsecureCerts must be a boolean",
          )
          return Some(())
        }
        None => ()
      }

      match map.get("proxy") {
        Some(Object(proxy)) =>
          match self.validate_browser_proxy_config(request_id, proxy) {
            Some(_) => return Some(())
            None => ()
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "proxy must be an object",
          )
          return Some(())
        }
        None => ()
      }

      match
        get_map_field_with_alias(
          map, "unhandledPromptBehavior", "unhandled_prompt_behavior",
        ) {
        Some(Object(behavior)) =>
          match
            self.validate_browser_unhandled_prompt_behavior(
              request_id, behavior,
            ) {
            Some(_) => return Some(())
            None => ()
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "unhandledPromptBehavior must be an object",
          )
          return Some(())
        }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return Some(())
    }
  }

  None
}

///|
/// Validate browser.createUserContext proxy config.
fn BidiProtocol::validate_browser_proxy_config(
  self : BidiProtocol,
  request_id : Int,
  proxy : Map[String, Json],
) -> Unit? {
  let proxy_type = match proxy.get("proxyType") {
    Some(String(kind)) => kind
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.proxyType must be a string",
      )
      return Some(())
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "proxy.proxyType is required",
      )
      return Some(())
    }
  }

  match proxy_type {
    "system" => ()
    "autodetect" => ()
    "direct" => ()
    "manual" =>
      match self.validate_browser_manual_proxy(request_id, proxy) {
        Some(_) => return Some(())
        None => ()
      }
    "pac" =>
      match proxy.get("proxyAutoconfigUrl") {
        Some(String(_)) => ()
        _ => {
          self.send_error(
            request_id, "invalid argument", "proxy.proxyAutoconfigUrl must be a string",
          )
          return Some(())
        }
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "proxy.proxyType is invalid",
      )
      return Some(())
    }
  }

  None
}

///|
/// Validate manual proxy configuration.
fn BidiProtocol::validate_browser_manual_proxy(
  self : BidiProtocol,
  request_id : Int,
  proxy : Map[String, Json],
) -> Unit? {
  let mut has_socks_proxy = false
  let mut has_socks_version = false

  match proxy.get("httpProxy") {
    Some(String(v)) =>
      if !is_valid_proxy_endpoint_value(v) {
        self.send_error(
          request_id, "invalid argument", "proxy.httpProxy is invalid",
        )
        return Some(())
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.httpProxy must be a string",
      )
      return Some(())
    }
    None => ()
  }

  match proxy.get("sslProxy") {
    Some(String(v)) =>
      if !is_valid_proxy_endpoint_value(v) {
        self.send_error(
          request_id, "invalid argument", "proxy.sslProxy is invalid",
        )
        return Some(())
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.sslProxy must be a string",
      )
      return Some(())
    }
    None => ()
  }

  match proxy.get("socksProxy") {
    Some(String(v)) => {
      has_socks_proxy = true
      if !is_valid_proxy_endpoint_value(v) {
        self.send_error(
          request_id, "invalid argument", "proxy.socksProxy is invalid",
        )
        return Some(())
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.socksProxy must be a string",
      )
      return Some(())
    }
    None => ()
  }

  match proxy.get("socksVersion") {
    Some(Number(n, ..)) => {
      has_socks_version = true
      if n != n.to_int64().to_double() {
        self.send_error(
          request_id, "invalid argument", "proxy.socksVersion must be an integer",
        )
        return Some(())
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.socksVersion must be a number",
      )
      return Some(())
    }
    None => ()
  }

  if has_socks_version && !has_socks_proxy {
    self.send_error(
      request_id, "invalid argument", "proxy.socksProxy is required when socksVersion is set",
    )
    return Some(())
  }
  if has_socks_proxy && !has_socks_version {
    self.send_error(
      request_id, "invalid argument", "proxy.socksVersion is required when socksProxy is set",
    )
    return Some(())
  }

  match proxy.get("noProxy") {
    Some(Array(entries)) =>
      for entry in entries {
        match entry {
          String(_) => ()
          _ => {
            self.send_error(
              request_id, "invalid argument", "proxy.noProxy entries must be strings",
            )
            return Some(())
          }
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "proxy.noProxy must be an array",
      )
      return Some(())
    }
    None => ()
  }

  None
}

///|
/// Normalize unhandledPromptBehavior string handler.
fn normalize_unhandled_prompt_handler_name(raw_handler : String) -> String? {
  match raw_handler {
    "accept" => Some("accept")
    "accept and notify" => Some("accept")
    "dismiss" => Some("dismiss")
    "dismiss and notify" => Some("dismiss")
    "ignore" => Some("ignore")
    _ => None
  }
}

///|
/// Validate unhandledPromptBehavior object.
fn BidiProtocol::validate_browser_unhandled_prompt_behavior(
  self : BidiProtocol,
  request_id : Int,
  behavior : Map[String, Json],
) -> Unit? {
  for key, raw_value in behavior {
    if key != "alert" &&
      key != "beforeUnload" &&
      key != "confirm" &&
      key != "default" &&
      key != "file" &&
      key != "prompt" {
      self.send_error(
        request_id,
        "invalid argument",
        "unhandledPromptBehavior key is invalid: " + key,
      )
      return Some(())
    }

    match raw_value {
      String(handler) =>
        if handler != "accept" && handler != "dismiss" && handler != "ignore" {
          self.send_error(
            request_id, "invalid argument", "unhandledPromptBehavior handler is invalid",
          )
          return Some(())
        }
      _ => {
        self.send_error(
          request_id, "invalid argument", "unhandledPromptBehavior handler must be a string",
        )
        return Some(())
      }
    }
  }
  None
}

///|
/// Validate browser.setDownloadBehavior parameters.
fn BidiProtocol::validate_browser_set_download_behavior(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  let map = match params {
    Some(Object(m)) => m
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return Some(())
    }
  }

  match map.get("downloadBehavior") {
    Some(Null) => ()
    Some(Object(download_behavior)) => {
      let behavior_type = match download_behavior.get("type") {
        Some(String(kind)) => kind
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "downloadBehavior.type must be a string",
          )
          return Some(())
        }
        None => {
          self.send_error(
            request_id, "invalid argument", "downloadBehavior.type is required",
          )
          return Some(())
        }
      }

      if behavior_type != "allowed" &&
        behavior_type != "denied" &&
        behavior_type != "default" {
        self.send_error(
          request_id, "invalid argument", "downloadBehavior.type is invalid",
        )
        return Some(())
      }

      if behavior_type == "allowed" {
        match download_behavior.get("destinationFolder") {
          Some(String(_)) => ()
          _ => {
            self.send_error(
              request_id, "invalid argument", "downloadBehavior.destinationFolder must be a string",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "downloadBehavior must be an object or null",
      )
      return Some(())
    }
    None => ()
  }

  match get_map_field_with_alias(map, "userContexts", "user_contexts") {
    Some(Array(user_contexts)) => {
      if user_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return Some(())
      }
      for raw_user_context in user_contexts {
        match raw_user_context {
          String(user_context_id) =>
            if !self.user_contexts.contains(user_context_id) {
              self.send_error(
                request_id,
                "no such user context",
                "Unknown user context: " + user_context_id,
              )
              return Some(())
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "userContexts entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return Some(())
    }
    None => ()
  }

  None
}

///|
/// Validate host:port proxy endpoint values.
fn is_valid_proxy_endpoint_value(value : String) -> Bool {
  if value.length() == 0 {
    return false
  }
  if value.has_prefix("http://") || value.has_prefix("https://") {
    return false
  }
  if value.contains("/") || value.contains("?") || value.contains("#") {
    return false
  }

  let chars = value.to_array()
  let mut colon_count = 0
  let mut colon_idx = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == ':' {
      colon_count += 1
      colon_idx = i
    }
  }
  if colon_count != 1 {
    return false
  }
  if colon_idx <= 0 || colon_idx >= chars.length() - 1 {
    return false
  }

  let host = value.unsafe_substring(start=0, end=colon_idx)
  if host.length() == 0 {
    return false
  }

  let port_text = value.unsafe_substring(
    start=colon_idx + 1,
    end=value.length(),
  )
  let port = match parse_decimal_string(port_text) {
    Some(v) => v
    None => return false
  }
  port > 0 && port <= 65535
}

///|
/// Parse decimal ASCII digits to an int.
fn parse_decimal_string(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }

  let mut parsed = 0
  for c in value.iter() {
    if c < '0' || c > '9' {
      return None
    }
    parsed = parsed * 10 + (c.to_int() - '0'.to_int())
  }
  Some(parsed)
}

///|
/// Valid network.addIntercept phase names.
fn is_valid_network_intercept_phase(name : String) -> Bool {
  name == "beforeRequestSent" ||
  name == "responseStarted" ||
  name == "authRequired"
}

///|
/// Validate one `network.Header` entry.
fn validate_network_extra_header_entry(entry : Json) -> Json? {
  let map = match entry {
    Object(map) => map
    _ => return None
  }
  let name = match map.get("name") {
    Some(String(name)) =>
      if is_valid_network_header_name_token(name) {
        name
      } else {
        return None
      }
    _ => return None
  }
  let value = match map.get("value") {
    Some(value) =>
      match validate_network_extra_header_value(value) {
        Some(value) => value
        None => return None
      }
    None => return None
  }
  Some(make_object({ "name": Json::string(name), "value": value }))
}

///|
/// Validate one `network.BytesValue` for headers.
fn validate_network_extra_header_value(value : Json) -> Json? {
  let map = match value {
    Object(map) => map
    _ => return None
  }
  let value_type = match map.get("type") {
    Some(String(value_type)) => value_type
    _ => return None
  }
  if value_type != "string" {
    return None
  }
  let raw_value = match map.get("value") {
    Some(String(raw_value)) => raw_value
    _ => return None
  }
  if !is_valid_network_header_string_value(raw_value) {
    return None
  }
  Some(
    make_object({
      "type": Json::string("string"),
      "value": Json::string(raw_value),
    }),
  )
}

///|
/// Validate HTTP header name token (`field-name`).
fn is_valid_network_header_name_token(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  for c in name.iter() {
    if !is_valid_network_header_name_token_char(c) {
      return false
    }
  }
  true
}

///|
/// Validate one `tchar` in RFC9110 token grammar.
fn is_valid_network_header_name_token_char(c : Char) -> Bool {
  let code = c.to_int()
  if (code >= 48 && code <= 57) ||
    (code >= 65 && code <= 90) ||
    (code >= 97 && code <= 122) {
    return true
  }
  match code {
    33 => true // !
    35 => true // #
    36 => true // $
    37 => true // %
    38 => true // &
    39 => true // '
    42 => true // *
    43 => true // +
    45 => true // -
    46 => true // .
    94 => true // ^
    95 => true // _
    96 => true // `
    124 => true // |
    126 => true // ~
    _ => false
  }
}

///|
/// Validate string header value for current WPT constraints.
fn is_valid_network_header_string_value(value : String) -> Bool {
  let chars = value.to_array()
  if chars.length() > 0 {
    let first = chars[0]
    let last = chars[chars.length() - 1]
    if first == ' ' || first == '\t' || last == ' ' || last == '\t' {
      return false
    }
  }
  for c in chars {
    let code = c.to_int()
    if code == 0 || code == 10 || code == 13 {
      return false
    }
  }
  true
}

///|
/// Validate one network urlPatterns entry.
fn validate_network_intercept_url_pattern_entry(entry : Json) -> Json? {
  let map = match entry {
    Object(map) => map
    _ => return None
  }
  let pattern_type = match map.get("type") {
    Some(String(name)) => name
    _ => return None
  }
  if pattern_type == "string" {
    match map.get("pattern") {
      Some(String(pattern)) =>
        if is_valid_network_string_url_pattern(pattern) {
          return Some(entry)
        } else {
          return None
        }
      _ => return None
    }
  }
  if pattern_type == "pattern" {
    if is_valid_network_pattern_url_pattern(map) {
      return Some(entry)
    }
  }
  None
}

///|
/// Validate `{"type":"string","pattern":"..."}` URL pattern.
fn is_valid_network_string_url_pattern(pattern : String) -> Bool {
  if has_unescaped_pattern_special_char(pattern) || pattern.contains("\\") {
    return false
  }
  if pattern.has_prefix("data:") {
    return true
  }
  let scheme_sep = match find_substring(pattern, "://", 0) {
    Some(idx) => idx
    None => return false
  }
  let scheme = pattern.unsafe_substring(start=0, end=scheme_sep)
  if !is_valid_network_pattern_protocol_value(scheme) {
    return false
  }
  let authority_and_path = pattern.unsafe_substring(
    start=scheme_sep + 3,
    end=pattern.length(),
  )
  if authority_and_path.length() == 0 {
    return false
  }
  let chars = authority_and_path.to_array()
  let mut authority_end = chars.length()
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == '/' || chars[i] == '?' || chars[i] == '#' {
      authority_end = i
      break
    }
  }
  let authority = authority_and_path.unsafe_substring(
    start=0,
    end=authority_end,
  )
  if authority.length() == 0 {
    return false
  }
  let host_port = extract_authority_host_port(authority)
  if host_port.length() == 0 {
    return false
  }
  validate_host_port_pattern(host_port)
}

///|
/// Extract host[:port] from authority, dropping optional userinfo.
fn extract_authority_host_port(authority : String) -> String {
  let chars = authority.to_array()
  let mut at_index = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == '@' {
      at_index = i
    }
  }
  if at_index < 0 {
    return authority
  }
  authority.unsafe_substring(start=at_index + 1, end=authority.length())
}

///|
/// Validate host[:port] syntax for string URL patterns.
fn validate_host_port_pattern(host_port : String) -> Bool {
  if host_port.length() == 0 {
    return false
  }
  let chars = host_port.to_array()
  let mut colon_idx = -1
  let mut colon_count = 0
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == ':' {
      colon_idx = i
      colon_count += 1
    }
  }
  // Keep IPv6 out of scope for now; invalid suite only covers host:port.
  if colon_count > 1 {
    return false
  }
  if colon_idx < 0 {
    return true
  }
  let host = host_port.unsafe_substring(start=0, end=colon_idx)
  if host.length() == 0 || colon_idx >= chars.length() - 1 {
    return false
  }
  let port_text = host_port.unsafe_substring(
    start=colon_idx + 1,
    end=host_port.length(),
  )
  let port = match parse_decimal_string(port_text) {
    Some(port) => port
    None => return false
  }
  port >= 0 && port <= 65535
}

///|
/// Validate `{"type":"pattern", ...}` URL pattern object.
fn is_valid_network_pattern_url_pattern(map : Map[String, Json]) -> Bool {
  let protocol = match map.get("protocol") {
    Some(String(value)) => Some(value)
    Some(_) => return false
    None => None
  }
  let hostname = match map.get("hostname") {
    Some(String(value)) => Some(value)
    Some(_) => return false
    None => None
  }
  let port = match map.get("port") {
    Some(String(value)) => Some(value)
    Some(_) => return false
    None => None
  }
  let pathname = match map.get("pathname") {
    Some(String(value)) => Some(value)
    Some(_) => return false
    None => None
  }
  let search = match map.get("search") {
    Some(String(value)) => Some(value)
    Some(_) => return false
    None => None
  }

  match protocol {
    Some(value) =>
      if has_unescaped_pattern_special_char(value) ||
        !is_valid_network_pattern_protocol_value(value) {
        return false
      } else {
        match hostname {
          Some(_) => if is_network_file_protocol(value) { return false }
          None => ()
        }
      }
    None => ()
  }

  match hostname {
    Some(value) =>
      if has_unescaped_pattern_special_char(value) ||
        !is_valid_network_pattern_hostname(value) {
        return false
      }
    None => ()
  }

  match port {
    Some(value) =>
      if has_unescaped_pattern_special_char(value) ||
        !is_valid_network_pattern_port(value) {
        return false
      }
    None => ()
  }

  match pathname {
    Some(value) =>
      if has_unescaped_pattern_special_char(value) ||
        !is_valid_network_pattern_pathname(value) {
        return false
      }
    None => ()
  }

  match search {
    Some(value) =>
      if has_unescaped_pattern_special_char(value) ||
        !is_valid_network_pattern_search(value) {
        return false
      }
    None => ()
  }

  true
}

///|
/// Reject reserved wildcard-like characters when not escaped.
fn has_unescaped_pattern_special_char(value : String) -> Bool {
  value.contains("*") ||
  value.contains("(") ||
  value.contains(")") ||
  value.contains("{") ||
  value.contains("}")
}

///|
/// Validate protocol token (`http`, `HTTPS`, optional trailing `:`).
fn is_valid_network_pattern_protocol_value(value : String) -> Bool {
  if value.length() == 0 {
    return false
  }
  if value.contains("\\") ||
    value.contains("/") ||
    value.contains("#") ||
    value.contains("@") ||
    value.contains("%") {
    return false
  }
  let chars = value.to_array()
  let mut colon_count = 0
  let mut colon_idx = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == ':' {
      colon_count += 1
      colon_idx = i
    }
  }
  if colon_count > 1 {
    return false
  }
  let scheme = if colon_count == 1 {
    if colon_idx != chars.length() - 1 {
      return false
    }
    value.unsafe_substring(start=0, end=colon_idx)
  } else {
    value
  }
  if scheme.length() == 0 {
    return false
  }
  let scheme_chars = scheme.to_array()
  if !is_ascii_alpha(scheme_chars[0]) {
    return false
  }
  for i = 1; i < scheme_chars.length(); i = i + 1 {
    let c = scheme_chars[i]
    if !(is_ascii_alnum(c) || c == '+' || c == '-' || c == '.') {
      return false
    }
  }
  true
}

///|
/// True when protocol token represents `file` (case-insensitive, optional `:`).
fn is_network_file_protocol(value : String) -> Bool {
  let scheme = if value.has_suffix(":") {
    value.unsafe_substring(start=0, end=value.length() - 1)
  } else {
    value
  }
  is_ascii_case_insensitive_equal(scheme, "file")
}

///|
/// Validate hostname token for url pattern object.
fn is_valid_network_pattern_hostname(value : String) -> Bool {
  if value.length() == 0 {
    return false
  }
  if value.contains("/") ||
    value.contains("?") ||
    value.contains("#") ||
    value.contains(":") {
    return false
  }
  !value.contains("::")
}

///|
/// Validate port token (`0`..`65535` digits only).
fn is_valid_network_pattern_port(value : String) -> Bool {
  if value.length() == 0 || value.contains(":") || value.contains(" ") {
    return false
  }
  let parsed = match parse_decimal_string(value) {
    Some(parsed) => parsed
    None => return false
  }
  parsed >= 0 && parsed <= 65535
}

///|
/// Validate pathname token (must not include `?` or `#`).
fn is_valid_network_pattern_pathname(value : String) -> Bool {
  !value.contains("?") && !value.contains("#")
}

///|
/// Validate search token (must not include `#`).
fn is_valid_network_pattern_search(value : String) -> Bool {
  !value.contains("#")
}

///|
/// ASCII alphabetic helper.
fn is_ascii_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
/// ASCII alphanumeric helper.
fn is_ascii_alnum(c : Char) -> Bool {
  is_ascii_alpha(c) || (c >= '0' && c <= '9')
}

///|
/// Case-insensitive ASCII equality.
fn is_ascii_case_insensitive_equal(lhs : String, rhs : String) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  let lhs_chars = lhs.to_array()
  let rhs_chars = rhs.to_array()
  for i = 0; i < lhs_chars.length(); i = i + 1 {
    let l = lhs_chars[i]
    let r = rhs_chars[i]
    if l == r {
      continue
    }
    let l_is_upper = l >= 'A' && l <= 'Z'
    let r_is_upper = r >= 'A' && r <= 'Z'
    if l_is_upper && l.to_int() + 32 == r.to_int() {
      continue
    }
    if r_is_upper && r.to_int() + 32 == l.to_int() {
      continue
    }
    return false
  }
  true
}

///|
/// Validate network.addIntercept parameters.
/// Returns None when an error response has already been sent.
fn BidiProtocol::validate_network_add_intercept_params(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Map[String, Json]? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let options : Map[String, Json] = {}

  let raw_phases = match map.get("phases") {
    Some(raw) => raw
    None => {
      self.send_error(request_id, "invalid argument", "Missing phases")
      return None
    }
  }
  let phases : Array[Json] = []
  match raw_phases {
    Array(items) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "phases must not be an empty array",
        )
        return None
      } else {
        for item in items {
          match item {
            String(phase_name) =>
              if is_valid_network_intercept_phase(phase_name) {
                phases.push(Json::string(phase_name))
              } else {
                self.send_error(
                  request_id, "invalid argument", "phase is invalid",
                )
                return None
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "phases entries must be strings",
              )
              return None
            }
          }
        }
      }
    _ => {
      self.send_error(request_id, "invalid argument", "phases must be an array")
      return None
    }
  }
  options["phases"] = Json::array(phases)

  let raw_url_patterns = get_map_field_with_alias(
    map, "urlPatterns", "url_patterns",
  )
  let url_patterns : Array[Json] = []
  match raw_url_patterns {
    Some(Array(items)) =>
      for item in items {
        let validated = match
          validate_network_intercept_url_pattern_entry(item) {
          Some(validated) => validated
          None => {
            self.send_error(
              request_id, "invalid argument", "urlPatterns entry is invalid",
            )
            return None
          }
        }
        url_patterns.push(validated)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "urlPatterns must be an array",
      )
      return None
    }
    None => ()
  }
  options["urlPatterns"] = Json::array(url_patterns)

  let raw_contexts : Json? = match map.get("contexts") {
    Some(Null) => None
    Some(raw) => Some(raw)
    None => None
  }
  match raw_contexts {
    Some(Array(items)) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return None
      } else {
        let contexts : Array[Json] = []
        for item in items {
          match item {
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
                  request_id, "invalid argument", "context must be top-level",
                )
                return None
              } else {
                contexts.push(Json::string(ctx_id))
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "contexts entries must be strings",
              )
              return None
            }
          }
        }
        options["contexts"] = Json::array(contexts)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return None
    }
    None => ()
  }

  Some(options)
}

///|
/// Validate network.addDataCollector parameters.
/// Returns None when an error response has already been sent.
fn BidiProtocol::validate_network_add_data_collector_params(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Map[String, Json]? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let raw_contexts : Json? = match map.get("contexts") {
    Some(Null) => None
    Some(raw) => Some(raw)
    None => None
  }
  let raw_user_contexts : Json? = match
    get_map_field_with_alias(map, "userContexts", "user_contexts") {
    Some(Null) => None
    Some(raw) => Some(raw)
    None => None
  }
  if raw_contexts is Some(_) && raw_user_contexts is Some(_) {
    self.send_error(
      request_id, "invalid argument", "contexts and userContexts are mutually exclusive",
    )
    return None
  }

  let options : Map[String, Json] = {}

  let raw_data_types = match
    get_map_field_with_alias(map, "dataTypes", "data_types") {
    Some(raw) => raw
    None => {
      self.send_error(request_id, "invalid argument", "Missing dataTypes")
      return None
    }
  }
  let data_types : Array[Json] = []
  match raw_data_types {
    Array(items) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "dataTypes must not be an empty array",
        )
        return None
      } else {
        for item in items {
          match item {
            String(name) =>
              if name == "request" || name == "response" {
                data_types.push(Json::string(name))
              } else {
                self.send_error(
                  request_id, "invalid argument", "dataTypes entry is invalid",
                )
                return None
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "dataTypes entries must be strings",
              )
              return None
            }
          }
        }
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "dataTypes must be an array",
      )
      return None
    }
  }
  options["dataTypes"] = Json::array(data_types)

  let raw_max_encoded_data_size = match
    get_map_field_with_alias(map, "maxEncodedDataSize", "max_encoded_data_size") {
    Some(raw) => raw
    None => {
      self.send_error(
        request_id, "invalid argument", "Missing maxEncodedDataSize",
      )
      return None
    }
  }
  let max_encoded_data_size = match raw_max_encoded_data_size {
    Number(n, ..) => {
      let as_int = n.to_int()
      if as_int.to_double() != n || as_int <= 0 {
        self.send_error(
          request_id, "invalid argument", "maxEncodedDataSize must be a positive integer",
        )
        return None
      }
      if as_int > 1000000000 {
        self.send_error(
          request_id, "invalid argument", "maxEncodedDataSize exceeds the implementation limit",
        )
        return None
      }
      as_int
    }
    _ => {
      self.send_error(
        request_id, "invalid argument", "maxEncodedDataSize must be a positive integer",
      )
      return None
    }
  }
  options["maxEncodedDataSize"] = Json::number(
    max_encoded_data_size.to_double(),
  )

  let collector_type = match
    get_map_field_with_alias(map, "collectorType", "collector_type") {
    Some(String(name)) =>
      if name == "blob" || name == "base64" {
        name
      } else {
        self.send_error(
          request_id, "invalid argument", "collectorType is invalid",
        )
        return None
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "collectorType must be a string",
      )
      return None
    }
    None => "blob"
  }
  options["collectorType"] = Json::string(collector_type)

  match raw_contexts {
    Some(Array(items)) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return None
      } else {
        let contexts : Array[Json] = []
        for item in items {
          match item {
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
                  request_id, "invalid argument", "context must be top-level",
                )
                return None
              } else {
                contexts.push(Json::string(ctx_id))
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "contexts entries must be strings",
              )
              return None
            }
          }
        }
        options["contexts"] = Json::array(contexts)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return None
    }
    None => ()
  }

  match raw_user_contexts {
    Some(Array(items)) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return None
      } else {
        let user_contexts : Array[Json] = []
        for item in items {
          match item {
            String(user_context_id) =>
              if !self.user_contexts.get(user_context_id).unwrap_or(false) {
                self.send_error(
                  request_id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return None
              } else {
                user_contexts.push(Json::string(user_context_id))
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "userContexts entries must be strings",
              )
              return None
            }
          }
        }
        options["userContexts"] = Json::array(user_contexts)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return None
    }
    None => ()
  }

  Some(options)
}

///|
/// Validate network.setExtraHeaders parameters.
/// Returns None when an error response has already been sent.
fn BidiProtocol::validate_network_set_extra_headers_params(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Map[String, Json]? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let raw_contexts = map.get("contexts")
  let raw_user_contexts = get_map_field_with_alias(
    map, "userContexts", "user_contexts",
  )
  if raw_contexts is Some(_) && raw_user_contexts is Some(_) {
    self.send_error(
      request_id, "invalid argument", "contexts and userContexts are mutually exclusive",
    )
    return None
  }

  let raw_headers = match map.get("headers") {
    Some(raw) => raw
    None => {
      self.send_error(request_id, "invalid argument", "Missing headers")
      return None
    }
  }

  let options : Map[String, Json] = {}

  let headers : Array[Json] = []
  match raw_headers {
    Array(items) =>
      for item in items {
        let header = match validate_network_extra_header_entry(item) {
          Some(header) => header
          None => {
            self.send_error(
              request_id, "invalid argument", "headers entry is invalid",
            )
            return None
          }
        }
        headers.push(header)
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "headers must be an array",
      )
      return None
    }
  }
  options["headers"] = Json::array(headers)

  match raw_contexts {
    Some(Array(items)) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return None
      } else {
        let contexts : Array[Json] = []
        for item in items {
          match item {
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
                  request_id, "invalid argument", "context must be top-level",
                )
                return None
              } else {
                contexts.push(Json::string(ctx_id))
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "contexts entries must be strings",
              )
              return None
            }
          }
        }
        options["contexts"] = Json::array(contexts)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return None
    }
    None => ()
  }

  match raw_user_contexts {
    Some(Array(items)) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return None
      } else {
        let user_contexts : Array[Json] = []
        for item in items {
          match item {
            String(user_context_id) =>
              if !self.user_contexts.get(user_context_id).unwrap_or(false) {
                self.send_error(
                  request_id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return None
              } else {
                user_contexts.push(Json::string(user_context_id))
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "userContexts entries must be strings",
              )
              return None
            }
          }
        }
        options["userContexts"] = Json::array(user_contexts)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return None
    }
    None => ()
  }

  Some(options)
}
