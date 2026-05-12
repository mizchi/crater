///|
fn synthetic_navigation_is_html_data_url(url : String) -> Bool {
  if !url.has_prefix("data:") {
    return false
  }
  match parse_data_url(url) {
    Some((content_type, _)) =>
      content_type.has_prefix("text/html") ||
      content_type.has_prefix("text/xml") ||
      content_type.has_prefix("application/xml") ||
      content_type.has_prefix("application/xhtml+xml") ||
      content_type == ""
    None => false
  }
}

///|
fn synthetic_navigation_http_origin(url : String) -> String? {
  if url.has_prefix("http://") {
    return Some(extract_http_origin(url, "http://", 7))
  }
  if url.has_prefix("https://") {
    return Some(extract_http_origin(url, "https://", 8))
  }
  None
}

///|
fn synthetic_navigation_join_origin_path(
  origin : String,
  path : String,
) -> String {
  if origin.has_suffix("/") && path.has_prefix("/") {
    origin + path.unsafe_substring(start=1, end=path.length())
  } else {
    origin + path
  }
}

///|
fn synthetic_navigation_push_unique_resource(
  requests : Array[SyntheticNavigationRequestEntry],
  seen_urls : Map[String, Bool],
  context_id : String,
  resource_url : String,
  navigation : String?,
  destination : String,
  initiator_type : String?,
  proto : BidiProtocol,
) -> Unit {
  let cleaned = strip_wrapping_quotes_and_spaces(resource_url)
  if cleaned == "" || seen_urls.contains(cleaned) {
    return
  }
  seen_urls[cleaned] = true
  requests.push({
    context_id,
    url: cleaned,
    request_token: proto.next_synthetic_network_request_id(),
    redirect_count: 0,
    navigation,
    destination,
    initiator_type,
  })
}

///|
fn strip_wrapping_quotes_and_spaces(raw : String) -> String {
  let trimmed = raw.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() >= 2 {
    let first = chars[0]
    let last = chars[chars.length() - 1]
    if (first == '"' && last == '"') || (first == '\'' && last == '\'') {
      return trimmed.unsafe_substring(start=1, end=trimmed.length() - 1)
    }
  }
  trimmed
}

///|
fn BidiProtocol::collect_attribute_values(
  self : BidiProtocol,
  ctx_id : String,
  selector : String,
  attribute_name : String,
) -> Array[String] {
  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let doc = session.get_tree().get_document()
      match session.get_tree().query_selector_all(doc, selector) {
        Ok(nodes) => {
          let values : Array[String] = []
          for node in nodes {
            match session.get_tree().get_attribute(node, attribute_name) {
              Ok(Some(value)) => values.push(value)
              _ => ()
            }
          }
          values
        }
        Err(_) => []
      }
    }
    None => []
  }
}

///|
fn BidiProtocol::collect_text_contents(
  self : BidiProtocol,
  ctx_id : String,
  selector : String,
) -> Array[String] {
  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let doc = session.get_tree().get_document()
      match session.get_tree().query_selector_all(doc, selector) {
        Ok(nodes) => {
          let texts : Array[String] = []
          for node in nodes {
            match session.get_tree().get_text_content(node) {
              Ok(text) => texts.push(text)
              Err(_) => ()
            }
          }
          texts
        }
        Err(_) => []
      }
    }
    None => []
  }
}

///|
fn collect_css_import_urls(source : String) -> Array[String] {
  let urls : Array[String] = []
  let chars = source.to_array()
  let mut start = 0
  while start < source.length() {
    match find_substring(source, "@import", start) {
      Some(idx) => {
        let mut cursor = idx + 7
        while cursor < chars.length() &&
              (
                chars[cursor] == ' ' ||
                chars[cursor] == '\n' ||
                chars[cursor] == '\t' ||
                chars[cursor] == '\r'
              ) {
          cursor += 1
        }
        if cursor + 4 <= chars.length() {
          let marker = source.unsafe_substring(start=cursor, end=cursor + 4)
          if marker == "url(" {
            cursor += 4
            while cursor < chars.length() &&
                  (
                    chars[cursor] == ' ' ||
                    chars[cursor] == '\n' ||
                    chars[cursor] == '\t' ||
                    chars[cursor] == '\r'
                  ) {
              cursor += 1
            }
            let value_start = cursor
            while cursor < chars.length() && chars[cursor] != ')' {
              cursor += 1
            }
            if cursor <= chars.length() {
              let raw_value = source.unsafe_substring(
                start=value_start,
                end=cursor,
              )
              let cleaned = strip_wrapping_quotes_and_spaces(raw_value)
              if cleaned != "" {
                urls.push(cleaned)
              }
            }
          }
        }
        start = idx + 7
      }
      None => break
    }
  }
  urls
}

///|
fn collect_static_import_urls(source : String) -> Array[String] {
  collect_quoted_values_after_marker(source, "from", true)
}

///|
fn collect_dynamic_import_urls(source : String) -> Array[String] {
  let values : Array[String] = []
  let chars = source.to_array()
  let mut start = 0
  while start < source.length() {
    match find_substring(source, "import", start) {
      Some(idx) => {
        let mut cursor = idx + 6
        while cursor < chars.length() &&
              (
                chars[cursor] == ' ' ||
                chars[cursor] == '\n' ||
                chars[cursor] == '\t' ||
                chars[cursor] == '\r'
              ) {
          cursor += 1
        }
        if cursor < chars.length() && chars[cursor] == '(' {
          cursor += 1
          while cursor < chars.length() &&
                (
                  chars[cursor] == ' ' ||
                  chars[cursor] == '\n' ||
                  chars[cursor] == '\t' ||
                  chars[cursor] == '\r'
                ) {
            cursor += 1
          }
          if cursor < chars.length() &&
            (chars[cursor] == '"' || chars[cursor] == '\'') {
            let quote = chars[cursor]
            let value_start = cursor + 1
            cursor += 1
            while cursor < chars.length() && chars[cursor] != quote {
              cursor += 1
            }
            if cursor <= chars.length() {
              let value = source.unsafe_substring(start=value_start, end=cursor)
              if value != "" {
                values.push(value)
              }
            }
          }
        }
        start = idx + 6
      }
      None => break
    }
  }
  values
}

///|
fn collect_quoted_values_after_marker(
  source : String,
  marker : String,
  allow_whitespace : Bool,
) -> Array[String] {
  let values : Array[String] = []
  let chars = source.to_array()
  let mut start = 0
  while start < source.length() {
    match find_substring(source, marker, start) {
      Some(idx) => {
        let mut cursor = idx + marker.length()
        if allow_whitespace {
          while cursor < chars.length() &&
                (
                  chars[cursor] == ' ' ||
                  chars[cursor] == '\n' ||
                  chars[cursor] == '\t' ||
                  chars[cursor] == '\r'
                ) {
            cursor += 1
          }
        }
        if cursor < chars.length() &&
          (chars[cursor] == '"' || chars[cursor] == '\'') {
          let quote = chars[cursor]
          let value_start = cursor + 1
          cursor += 1
          while cursor < chars.length() && chars[cursor] != quote {
            cursor += 1
          }
          if cursor <= chars.length() {
            let value = source.unsafe_substring(start=value_start, end=cursor)
            if value != "" {
              values.push(value)
            }
          }
        }
        start = idx + marker.length()
      }
      None => break
    }
  }
  values
}
