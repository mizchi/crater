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
