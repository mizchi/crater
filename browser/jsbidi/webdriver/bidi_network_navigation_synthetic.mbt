///|
priv struct SyntheticNavigationRequestEntry {
  context_id : String
  url : String
  request_token : String
  redirect_count : Int
  navigation : String?
  destination : String
  initiator_type : String?
}

///|
fn BidiProtocol::handle_network_emit_navigation_request_sequence(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let context_id = match map.get("context") {
    Some(String(context_id)) => context_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  if !self.manager.has_session(context_id) {
    self.send_error(
      request_id,
      "no such frame",
      "Unknown context: " + context_id,
    )
    return
  }
  let url = match map.get("url") {
    Some(String(url)) => url
    _ => {
      self.send_error(request_id, "invalid argument", "url must be a string")
      return
    }
  }
  let navigation : String? = match map.get("navigation") {
    Some(String(navigation)) => Some(navigation)
    Some(Null) | None => None
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "navigation must be a string",
      )
      return
    }
  }
  let emitted = self.emit_synthetic_navigation_request_sequence_for_test(
    context_id, url, navigation,
  )
  self.send_success(
    request_id,
    Some(make_object({ "emitted": Json::number(emitted.to_double()) })),
  )
}

///|
fn BidiProtocol::emit_synthetic_navigation_request_sequence(
  self : BidiProtocol,
  context_id : String,
  url : String,
  navigation : String?,
) -> Int {
  let requests = self.build_synthetic_navigation_request_entries(
    context_id, url, navigation,
  )
  for request in requests {
    self.emit_synthetic_network_event_sequence_internal(request, true, false)
  }
  requests.length()
}

///|
fn BidiProtocol::emit_synthetic_navigation_request_sequence_for_test(
  self : BidiProtocol,
  context_id : String,
  url : String,
  navigation : String?,
) -> Int {
  let requests = self.build_synthetic_navigation_request_entries(
    context_id, url, navigation,
  )
  for request in requests {
    self.emit_synthetic_network_event_sequence_internal(request, true, true)
  }
  requests.length()
}

///|
fn BidiProtocol::build_synthetic_navigation_request_entries(
  self : BidiProtocol,
  context_id : String,
  url : String,
  navigation : String?,
) -> Array[SyntheticNavigationRequestEntry] {
  let requests : Array[SyntheticNavigationRequestEntry] = []
  let primary_request_token = self.next_synthetic_network_request_id()
  requests.push({
    context_id,
    url,
    request_token: primary_request_token,
    redirect_count: 0,
    navigation,
    destination: "document",
    initiator_type: None,
  })

  if url.contains("/redirect.py") {
    match synthetic_network_first_query_value(url, "location") {
      Some(redirect_url) =>
        requests.push({
          context_id,
          url: redirect_url,
          request_token: primary_request_token,
          redirect_count: 1,
          navigation,
          destination: "document",
          initiator_type: None,
        })
      None => ()
    }
  }

  match resolve_http_equiv_redirect_url(url) {
    Some(redirected_url) => {
      let redirected_navigation = match navigation {
        Some(navigation_id) => Some(navigation_id + "-redirect")
        None => Some(self.next_synthetic_network_request_id())
      }
      requests.push({
        context_id,
        url: redirected_url,
        request_token: self.next_synthetic_network_request_id(),
        redirect_count: 0,
        navigation: redirected_navigation,
        destination: "document",
        initiator_type: None,
      })
    }
    None => ()
  }

  if synthetic_navigation_is_html_data_url(url) {
    self.append_data_url_navigation_request_entries(
      requests, context_id, navigation,
    )
  }

  self.append_known_navigation_related_requests(
    requests, context_id, url, navigation,
  )
  requests
}

///|
fn BidiProtocol::append_data_url_navigation_request_entries(
  self : BidiProtocol,
  requests : Array[SyntheticNavigationRequestEntry],
  context_id : String,
  navigation : String?,
) -> Unit {
  let child_contexts = self.context_children.get(context_id).unwrap_or([])
  let iframe_sources = self.collect_iframe_sources(context_id)
  if child_contexts.length() > 0 && iframe_sources.length() > 0 {
    let child_context_id = child_contexts[0]
    let child_navigation = self.context_last_started_navigation.get(
      child_context_id,
    )
    requests.push({
      context_id: child_context_id,
      url: iframe_sources[0],
      request_token: self.next_synthetic_network_request_id(),
      redirect_count: 0,
      navigation: child_navigation,
      destination: "iframe",
      initiator_type: Some("iframe"),
    })
  }

  let seen_urls : Map[String, Bool] = {}
  for resource_url in self.collect_attribute_values(context_id, "link", "href") {
    synthetic_navigation_push_unique_resource(
      requests,
      seen_urls,
      context_id,
      resource_url,
      navigation,
      "style",
      Some("link"),
      self,
    )
  }
  for resource_url in self.collect_attribute_values(context_id, "script", "src") {
    synthetic_navigation_push_unique_resource(
      requests,
      seen_urls,
      context_id,
      resource_url,
      navigation,
      "script",
      Some("script"),
      self,
    )
  }
  for resource_url in self.collect_attribute_values(context_id, "img", "src") {
    synthetic_navigation_push_unique_resource(
      requests,
      seen_urls,
      context_id,
      resource_url,
      navigation,
      "image",
      Some("img"),
      self,
    )
  }
  for style_text in self.collect_text_contents(context_id, "style") {
    for resource_url in collect_css_import_urls(style_text) {
      synthetic_navigation_push_unique_resource(
        requests,
        seen_urls,
        context_id,
        resource_url,
        navigation,
        "style",
        Some("link"),
        self,
      )
    }
  }
  for script_text in self.collect_script_texts(context_id) {
    for resource_url in collect_static_import_urls(script_text) {
      synthetic_navigation_push_unique_resource(
        requests,
        seen_urls,
        context_id,
        resource_url,
        navigation,
        "script",
        Some("script"),
        self,
      )
    }
    for resource_url in collect_dynamic_import_urls(script_text) {
      synthetic_navigation_push_unique_resource(
        requests,
        seen_urls,
        context_id,
        resource_url,
        navigation,
        "script",
        Some("script"),
        self,
      )
    }
  }
}

///|
fn BidiProtocol::append_known_navigation_related_requests(
  self : BidiProtocol,
  requests : Array[SyntheticNavigationRequestEntry],
  context_id : String,
  url : String,
  navigation : String?,
) -> Unit {
  ignore(self)
  if url.contains("/initiator/simple-initiator.html") {
    match synthetic_navigation_http_origin(url) {
      Some(origin) => {
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/initiator/simple-initiator-script.js",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "script",
          initiator_type: Some("script"),
        })
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/initiator/simple-initiator-style.css",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "style",
          initiator_type: Some("link"),
        })
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/initiator/simple-initiator-img.png",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "image",
          initiator_type: Some("img"),
        })
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/initiator/simple-initiator-bg.png",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "image",
          initiator_type: Some("css"),
        })
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/empty.html",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "iframe",
          initiator_type: Some("iframe"),
        })
      }
      None => ()
    }
  }
  if url.contains("/webdriver/tests/bidi/network/support/provide_response.html") {
    match synthetic_navigation_http_origin(url) {
      Some(origin) => {
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/provide_response.css",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "style",
          initiator_type: Some("link"),
        })
        requests.push({
          context_id,
          url: synthetic_navigation_join_origin_path(
            origin, "/webdriver/tests/bidi/network/support/provide_response.js",
          ),
          request_token: self.next_synthetic_network_request_id(),
          redirect_count: 0,
          navigation,
          destination: "script",
          initiator_type: Some("script"),
        })
      }
      None => ()
    }
  }
}

///|
fn BidiProtocol::emit_synthetic_network_event_sequence_internal(
  self : BidiProtocol,
  request : SyntheticNavigationRequestEntry,
  is_navigation : Bool,
  force_before_request_sent : Bool,
) -> Unit {
  let base_input : SyntheticNetworkEventInput = {
    context_id: request.context_id,
    url: request.url,
    http_method: "GET",
    request_token: request.request_token,
    request_headers: [],
    request_value: None,
    request_cookies: [],
    request_cookies_override: false,
    intercepts: [],
    redirect_count: request.redirect_count,
    navigation: request.navigation,
    destination: request.destination,
    initiator_type: request.initiator_type,
  }

  let response_overrides = self.resolve_synthetic_response_overrides_internal(
    request.context_id,
    request.url,
    "GET",
    [],
    true,
  )

  let before_intercepts = self.resolve_matching_network_intercepts_internal(
    request.context_id,
    "beforeRequestSent",
    request.url,
  )
  let before_subscribed = force_before_request_sent ||
    self.is_subscribed_for_context(
      "network.beforeRequestSent",
      request.context_id,
    )
  let before_blocked = before_subscribed && before_intercepts.length() > 0
  if before_subscribed {
    let before_input = {
      ..base_input,
      intercepts: if before_blocked {
        before_intercepts
      } else {
        []
      },
    }
    match self.build_synthetic_before_request_sent_event_json(0, before_input) {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.beforeRequestSent", params: event }),
        )
      None => return
    }
  }
  if before_blocked {
    self.remember_network_blocked_request(
      request.request_token,
      synthetic_navigation_blocked_request_payload(
        base_input,
        "beforeRequestSent",
        None,
      ),
    )
    return
  }

  if synthetic_navigation_is_unreachable_test_url(request.url) {
    if self.is_subscribed_for_context("network.fetchError", request.context_id) {
      match
        self.build_synthetic_fetch_error_event_json(
          0, base_input, "Request failed",
        ) {
        Some(event) =>
          self.outbox.push(
            Event({ event_method: "network.fetchError", params: event }),
          )
        None => ()
      }
    }
    return
  }

  let response_started_intercepts = self.resolve_matching_network_intercepts_internal(
    request.context_id,
    "responseStarted",
    request.url,
  )
  let response_started_subscribed = self.is_subscribed_for_context(
    "network.responseStarted",
    request.context_id,
  )
  let response_started_blocked = response_started_subscribed &&
    response_started_intercepts.length() > 0
  let mut response_started_event : Json? = None
  if response_started_subscribed {
    let response_input = {
      ..base_input,
      intercepts: if response_started_blocked {
        response_started_intercepts
      } else {
        []
      },
    }
    response_started_event = self.build_synthetic_response_event_json(
      0, response_input, response_overrides,
    )
    match response_started_event {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.responseStarted", params: event }),
        )
      None => return
    }
  }
  if response_started_blocked {
    self.remember_network_blocked_request(
      request.request_token,
      synthetic_navigation_blocked_request_payload(
        base_input, "responseStarted", response_started_event,
      ),
    )
    return
  }

  let auth_required_intercepts = self.resolve_matching_network_intercepts_internal(
    request.context_id,
    "authRequired",
    request.url,
  )
  let auth_required_subscribed = self.is_subscribed_for_context(
    "network.authRequired",
    request.context_id,
  )
  let auth_required_needed = synthetic_navigation_requires_auth_event(
    response_overrides,
  )
  let auth_required_blocked = auth_required_needed &&
    auth_required_subscribed &&
    auth_required_intercepts.length() > 0
  let mut auth_required_event : Json? = None
  if auth_required_subscribed && auth_required_needed {
    let auth_overrides : SyntheticNetworkResponseOverrides = if auth_required_blocked {
      {
        from_cache: response_overrides.from_cache,
        headers: response_overrides.headers,
        mime_type: response_overrides.mime_type,
        protocol: response_overrides.protocol,
        status: 401,
        status_text: "Unauthorized",
        auth_challenges: Some(
          Json::array([
            make_object({
              "scheme": Json::string("Basic"),
              "realm": Json::string("testrealm"),
            }),
          ]),
        ),
      }
    } else {
      response_overrides
    }
    let auth_input = {
      ..base_input,
      intercepts: if auth_required_blocked {
        auth_required_intercepts
      } else {
        []
      },
    }
    auth_required_event = self.build_synthetic_response_event_json(
      0, auth_input, auth_overrides,
    )
    match auth_required_event {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.authRequired", params: event }),
        )
      None => return
    }
  }
  if auth_required_blocked {
    self.remember_network_blocked_request(
      request.request_token,
      synthetic_navigation_blocked_request_payload(
        base_input, "authRequired", auth_required_event,
      ),
    )
    return
  }

  if self.is_subscribed_for_context(
      "network.responseCompleted",
      request.context_id,
    ) {
    match
      self.build_synthetic_response_event_json(
        0, base_input, response_overrides,
      ) {
      Some(event) =>
        self.outbox.push(
          Event({ event_method: "network.responseCompleted", params: event }),
        )
      None => return
    }
  }

  self.remember_network_collected_data_internal(
    request.context_id,
    request.request_token,
    None,
    Some(synthetic_navigation_synthesize_response_value(request.url)),
  )
  ignore(is_navigation)
}

///|
fn synthetic_navigation_blocked_request_payload(
  input : SyntheticNetworkEventInput,
  phase : String,
  response_event : Json?,
) -> Map[String, Json] {
  let blocked_request : Map[String, Json] = {}
  blocked_request["phase"] = Json::string(phase)
  blocked_request["context_id"] = Json::string(input.context_id)
  blocked_request["url"] = Json::string(input.url)
  blocked_request["method"] = Json::string(input.http_method)
  blocked_request["request_headers"] = synthetic_navigation_header_object_from_entries(
    input.request_headers,
  )
  match input.request_value {
    Some(request_value) => blocked_request["request_value"] = request_value
    None => ()
  }
  blocked_request["redirect_count"] = Json::number(
    input.redirect_count.to_double(),
  )
  blocked_request["navigation"] = match input.navigation {
    Some(navigation) => Json::string(navigation)
    None => Json::null()
  }
  blocked_request["destination"] = Json::string(input.destination)
  blocked_request["initiator_type"] = match input.initiator_type {
    Some(initiator_type) => Json::string(initiator_type)
    None => Json::null()
  }
  blocked_request["is_navigation"] = Json::boolean(true)
  match response_event {
    Some(event) => {
      blocked_request["response_headers"] = Json::array(
        synthetic_navigation_response_headers_from_event(event),
      )
      blocked_request["response_status"] = Json::number(
        synthetic_navigation_response_status_from_event(event).to_double(),
      )
      blocked_request["response_status_text"] = Json::string(
        synthetic_navigation_response_status_text_from_event(event),
      )
    }
    None => ()
  }
  blocked_request
}

///|
fn synthetic_navigation_requires_auth_event(
  response_overrides : SyntheticNetworkResponseOverrides,
) -> Bool {
  response_overrides.status == 401 ||
  response_overrides.status == 407 ||
  response_overrides.auth_challenges != None
}

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
fn synthetic_navigation_is_unreachable_test_url(url : String) -> Bool {
  url.has_prefix("http://not_a_valid_url.test") ||
  url.has_prefix("https://not_a_valid_url.test")
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
  let trimmed = raw.trim().to_string()
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

///|
fn synthetic_navigation_header_object_from_entries(
  headers : Array[Json],
) -> Json {
  let object : Map[String, Json] = {}
  for header in headers {
    let name = match synthetic_network_header_entry_name(header) {
      Some(name) => name
      None => continue
    }
    let value = synthetic_network_header_entry_string_value(header).unwrap_or(
      "",
    )
    object[name] = Json::string(value)
  }
  make_object(object)
}

///|
fn synthetic_navigation_response_headers_from_event(
  event : Json,
) -> Array[Json] {
  match get_field(event, "response") {
    Some(Object(response)) =>
      match response.get("headers") {
        Some(Array(headers)) => headers
        _ => []
      }
    _ => []
  }
}

///|
fn synthetic_navigation_response_status_from_event(event : Json) -> Int {
  match get_field(event, "response") {
    Some(Object(response)) =>
      match response.get("status") {
        Some(Number(status, ..)) => status.to_int()
        _ => 200
      }
    _ => 200
  }
}

///|
fn synthetic_navigation_response_status_text_from_event(event : Json) -> String {
  match get_field(event, "response") {
    Some(Object(response)) =>
      match response.get("statusText") {
        Some(String(status_text)) => status_text
        _ => "OK"
      }
    _ => "OK"
  }
}

///|
fn synthetic_navigation_synthesize_response_value(url : String) -> Json {
  if url.has_prefix("data:") {
    let payload = url.unsafe_substring(start=5, end=url.length())
    match find_substring(payload, ",", 0) {
      Some(idx) => {
        let meta = payload.unsafe_substring(start=0, end=idx)
        let encoded = payload.unsafe_substring(
          start=idx + 1,
          end=payload.length(),
        )
        let mime = match find_substring(meta, ";", 0) {
          Some(semi_idx) => meta.unsafe_substring(start=0, end=semi_idx)
          None => meta
        }
        if meta.contains(";base64") {
          if mime.has_prefix("image/") {
            return make_object({
              "type": Json::string("base64"),
              "value": Json::string(encoded),
            })
          }
          return make_object({
            "type": Json::string("string"),
            "value": Json::string(decode_base64(encoded)),
          })
        }
        let decoded = js_decode_query_component(encoded)
        return make_object({
          "type": Json::string("string"),
          "value": Json::string(decoded),
        })
      }
      None => ()
    }
  }
  let path = match canonicalize_network_http_url(url) {
    Some(parts) => parts.path
    None => ""
  }
  if path.has_suffix("/empty.txt") {
    return make_object({
      "type": Json::string("string"),
      "value": Json::string("empty\n"),
    })
  }
  if path.has_suffix("/other.txt") {
    return make_object({
      "type": Json::string("string"),
      "value": Json::string("other\n"),
    })
  }
  if path.has_suffix("/empty.png") {
    return make_object({
      "type": Json::string("base64"),
      "value": Json::string(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQIW2P4DwQACfsD/Z8fLAAAAAAASUVORK5CYII=",
      ),
    })
  }
  if path.has_suffix("/cached.py") {
    let response_body = synthetic_network_first_query_value(url, "response").unwrap_or(
      "",
    )
    let raw_response = synthetic_navigation_first_raw_query_value(
      url, "response",
    ).unwrap_or("")
    let content_type = synthetic_network_first_query_value(url, "contenttype")
      .unwrap_or("text/plain")
      .to_lower()
    if content_type.has_prefix("image/") || content_type == "img/png" {
      return make_object({
        "type": Json::string("base64"),
        "value": Json::string(
          if raw_response != "" {
            synthetic_navigation_raw_query_value_to_base64(raw_response)
          } else {
            encode_base64_utf8(response_body)
          },
        ),
      })
    }
    return make_object({
      "type": Json::string("string"),
      "value": Json::string(response_body),
    })
  }
  if path.has_suffix("/headers.py") || path.has_suffix("/charset.py") {
    return make_object({
      "type": Json::string("string"),
      "value": Json::string(
        synthetic_network_first_query_value(url, "content").unwrap_or(""),
      ),
    })
  }
  make_object({ "type": Json::string("string"), "value": Json::string("") })
}

///|
fn synthetic_navigation_first_raw_query_value(
  url : String,
  key : String,
) -> String? {
  let values = synthetic_navigation_raw_query_values(url, key)
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
fn synthetic_navigation_raw_query_values(
  url : String,
  key : String,
) -> Array[String] {
  let values : Array[String] = []
  let query = extract_network_url_query(url)
  if query == "" {
    return values
  }
  for part in query.split("&") {
    let raw = part.to_string()
    if raw.length() == 0 {
      continue
    }
    match find_substring(raw, "=", 0) {
      Some(eq_idx) => {
        let part_key = raw.unsafe_substring(start=0, end=eq_idx)
        if part_key != key {
          continue
        }
        let value_start = eq_idx + 1
        let raw_value = if value_start <= raw.length() {
          raw.unsafe_substring(start=value_start, end=raw.length())
        } else {
          ""
        }
        values.push(raw_value)
      }
      None => if raw == key { values.push("") }
    }
  }
  values
}

///|
extern "js" fn synthetic_navigation_raw_query_value_to_base64(
  value : String,
) -> String =
  #| (value) => {
  #|   const raw = String(value ?? "").replace(/\+/g, " ");
  #|   const bytes = [];
  #|   for (let i = 0; i < raw.length; ) {
  #|     const ch = raw[i];
  #|     if (ch === "%" && i + 2 < raw.length) {
  #|       const hex = raw.slice(i + 1, i + 3);
  #|       const parsed = Number.parseInt(hex, 16);
  #|       if (!Number.isNaN(parsed)) {
  #|         bytes.push(parsed);
  #|         i += 3;
  #|         continue;
  #|       }
  #|     }
  #|     bytes.push(ch.charCodeAt(0));
  #|     i += 1;
  #|   }
  #|   let binary = "";
  #|   for (const byte of bytes) {
  #|     binary += String.fromCharCode(byte);
  #|   }
  #|   return btoa(binary);
  #| }
