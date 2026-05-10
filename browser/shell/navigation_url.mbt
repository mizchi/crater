///|
/// Resolve relative URL to absolute
fn resolve_url(base_url : String, href : String) -> String {
  // Skip empty, fragment-only, or javascript URLs
  if href.length() == 0 ||
    href.has_prefix("#") ||
    href.has_prefix("javascript:") ||
    href.has_prefix("mailto:") ||
    href.has_prefix("tel:") {
    return ""
  }
  // Already absolute
  if href.has_prefix("http://") || href.has_prefix("https://") {
    return href
  }
  if href.has_prefix("data:") ||
    href.has_prefix("about:") ||
    href.has_prefix("blob:") ||
    href.has_prefix("file:") {
    return href
  }
  // Protocol-relative
  if href.has_prefix("//") {
    let protocol = if base_url.has_prefix("https://") {
      "https:"
    } else {
      "http:"
    }
    return protocol + href
  }
  // Extract base from URL
  let protocol_end = match base_url.find("://") {
    Some(i) => i
    None => return href
  }
  let after_protocol = base_url.unsafe_substring(
    start=protocol_end + 3,
    end=base_url.length(),
  )
  let path_start = after_protocol.find("/")
  let origin = match path_start {
    Some(i) => base_url.unsafe_substring(start=0, end=protocol_end + 3 + i)
    None => base_url
  }
  // Root-relative
  if href.has_prefix("/") {
    return origin + href
  }
  // Relative - append to current path
  let last_slash = base_url.rev_find("/")
  match last_slash {
    Some(i) if i > protocol_end + 2 =>
      base_url.unsafe_substring(start=0, end=i + 1) + href
    _ => origin + "/" + href
  }
}

///|
fn make_substr(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn hex_digit_to_int(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn percent_decode_data_url_payload(payload : String) -> String {
  let chars = payload.to_array()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '%' && i + 2 < chars.length() {
      match (hex_digit_to_int(chars[i + 1]), hex_digit_to_int(chars[i + 2])) {
        (Some(high), Some(low)) => {
          buf.write_char((high * 16 + low).unsafe_to_char())
          i = i + 3
        }
        _ => {
          buf.write_char(chars[i])
          i = i + 1
        }
      }
    } else {
      buf.write_char(chars[i])
      i = i + 1
    }
  }
  buf.to_string()
}

///|
fn decode_sync_navigable_html_url(url : String) -> String? {
  if url == "about:blank" {
    return Some("")
  }
  if !url.has_prefix("data:") {
    return None
  }
  let chars = url.to_array()
  let mut comma_idx = -1
  for i = 5; i < chars.length(); i = i + 1 {
    if chars[i] == ',' {
      comma_idx = i
      break
    }
  }
  if comma_idx < 0 {
    return None
  }
  let header = make_substr(chars, 5, comma_idx)
  if header.contains(";base64") {
    return None
  }
  let mut payload_end = chars.length()
  for i = comma_idx + 1; i < chars.length(); i = i + 1 {
    if chars[i] == '?' || chars[i] == '#' {
      payload_end = i
      break
    }
  }
  let payload = make_substr(chars, comma_idx + 1, payload_end)
  Some(percent_decode_data_url_payload(payload))
}
