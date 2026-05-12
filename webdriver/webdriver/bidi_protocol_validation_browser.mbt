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
