///|
fn BidiProtocol::handle_script_remember_synthetic_location_href(
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
  let ctx_id = match map.get("context") {
    Some(String(ctx_id)) => ctx_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  let href = match map.get("href") {
    Some(String(href)) => href
    _ => {
      self.send_error(request_id, "invalid argument", "href must be a string")
      return
    }
  }
  self.remember_synthetic_location_href(ctx_id, href)
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::handle_script_clear_synthetic_location_href(
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
  let ctx_id = match map.get("context") {
    Some(String(ctx_id)) => ctx_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  self.clear_synthetic_location_href(ctx_id)
  self.send_success(request_id, Some(make_object({})))
}

///|
fn default_beforeunload_test_page_url() -> String {
  "http://localhost:8000/webdriver/tests/support/html/beforeunload.html"
}

///|
fn beforeunload_test_page_html() -> String {
  "<!doctype html><html><body><input id='target'><script>window.addEventListener('beforeunload', function (event) { event.preventDefault(); event.returnValue = ''; });</script></body></html>"
}

///|
/// Emit browsingContext.historyUpdated for a context.
fn BidiProtocol::emit_history_updated_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
) -> Unit {
  if !self.is_subscribed_for_context("browsingContext.historyUpdated", ctx_id) {
    return
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
  })
  self.outbox.push(
    Event({ event_method: "browsingContext.historyUpdated", params }),
  )
}

///|
/// Mirror History API mutations from script.callFunction into CDP page history.
fn BidiProtocol::apply_synthetic_history_state_from_call(
  self : BidiProtocol,
  ctx_id : String,
  function_declaration : String,
  params : Json?,
) -> Unit {
  let args = match get_param_raw(params, "arguments") {
    Some(Array(values)) => values
    _ => []
  }

  let mut method_name = ""
  let mut target_url : String? = None

  if function_declaration.contains("history.pushState") {
    method_name = "pushState"
    if args.length() >= 1 {
      target_url = get_serialized_string_argument(args[0])
    }
  } else if function_declaration.contains("history.replaceState") {
    method_name = "replaceState"
    if args.length() >= 1 {
      target_url = get_serialized_string_argument(args[0])
    }
  } else if function_declaration.contains("history[method]") {
    if args.length() >= 1 {
      match get_serialized_string_argument(args[0]) {
        Some(name) =>
          if name == "pushState" || name == "replaceState" {
            method_name = name
            if args.length() >= 2 {
              target_url = get_serialized_string_argument(args[1])
            }
          }
        None => ()
      }
    }
  }

  if method_name == "" {
    return
  }

  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let effective_url = target_url.unwrap_or(session.get_url())
      let page = session.get_page()
      if method_name == "replaceState" {
        page.replace_history_url(effective_url)
      } else {
        page.push_history_url(effective_url)
      }
      self.emit_history_updated_event(ctx_id, effective_url)
    }
    None => ()
  }
}

///|
/// Mirror `document.location = ...` style assignments from script.callFunction.
fn BidiProtocol::apply_synthetic_location_assignment_from_call(
  self : BidiProtocol,
  ctx_id : String,
  function_declaration : String,
  params : Json?,
) -> Unit {
  if !(function_declaration.contains("document.location =") ||
    function_declaration.contains("window.location =") ||
    function_declaration.contains("location.href =")) {
    return
  }

  let args = match get_param_raw(params, "arguments") {
    Some(Array(values)) => values
    _ => []
  }
  if args.length() == 0 {
    return
  }
  let target_url = match get_serialized_string_argument(args[0]) {
    Some(url) => url
    None => return
  }

  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let previous_url = session.get_url()
      self.clear_synthetic_location_href(ctx_id)
      let _ = session.navigate_to(target_url)
      if is_fragment_navigation(previous_url, target_url) {
        self.emit_fragment_navigated_event(ctx_id, target_url, None)
      }
      self.emit_history_updated_event(ctx_id, target_url)
    }
    None => ()
  }
}

///|
/// Mirror History API mutations from script.evaluate into CDP page history.
fn BidiProtocol::apply_synthetic_history_state_from_expression(
  self : BidiProtocol,
  ctx_id : String,
  expression : String,
) -> Unit {
  let source = expression.trim().to_owned()

  let mut push_cursor = 0
  let mut push_continue = true
  while push_continue {
    match find_substring(source, "history.pushState(", push_cursor) {
      Some(idx) => {
        let fragment = source.unsafe_substring(start=idx, end=source.length())
        let push_url = extract_third_quoted_after_marker(
          fragment, "history.pushState(",
        ).unwrap_or("")
        match self.manager.get_session(ctx_id) {
          Some(session) => {
            let page = session.get_page()
            page.push_history_url(push_url)
            self.emit_history_updated_event(ctx_id, session.get_url())
          }
          None => ()
        }
        push_cursor = idx + "history.pushState(".length()
      }
      None => push_continue = false
    }
  }

  let mut replace_cursor = 0
  let mut replace_continue = true
  while replace_continue {
    match find_substring(source, "history.replaceState(", replace_cursor) {
      Some(idx) => {
        let fragment = source.unsafe_substring(start=idx, end=source.length())
        let replace_url = extract_third_quoted_after_marker(
          fragment, "history.replaceState(",
        ).unwrap_or("")
        match self.manager.get_session(ctx_id) {
          Some(session) => {
            let page = session.get_page()
            page.replace_history_url(replace_url)
            self.emit_history_updated_event(ctx_id, session.get_url())
          }
          None => ()
        }
        replace_cursor = idx + "history.replaceState(".length()
      }
      None => replace_continue = false
    }
  }

  let mut back_cursor = 0
  let mut back_continue = true
  while back_continue {
    match find_substring(source, "history.back(", back_cursor) {
      Some(idx) => {
        match self.manager.get_session(ctx_id) {
          Some(session) => {
            let page = session.get_page()
            match page.go_back() {
              Ok(true) =>
                self.emit_history_updated_event(ctx_id, session.get_url())
              _ => ()
            }
          }
          None => ()
        }
        back_cursor = idx + "history.back(".length()
      }
      None => back_continue = false
    }
  }

  let mut forward_cursor = 0
  let mut forward_continue = true
  while forward_continue {
    match find_substring(source, "history.forward(", forward_cursor) {
      Some(idx) => {
        match self.manager.get_session(ctx_id) {
          Some(session) => {
            let page = session.get_page()
            match page.go_forward() {
              Ok(true) =>
                self.emit_history_updated_event(ctx_id, session.get_url())
              _ => ()
            }
          }
          None => ()
        }
        forward_cursor = idx + "history.forward(".length()
      }
      None => forward_continue = false
    }
  }
}

///|
/// Emit browsingContext.fragmentNavigated for same-document fragment changes.
fn BidiProtocol::emit_fragment_navigated_event(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String?,
) -> Unit {
  let event_name = "browsingContext.fragmentNavigated"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let navigation_json = match navigation_id {
    Some(id) => Json::string(id)
    None => Json::null()
  }
  let params = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
    "timestamp": Json::number(input_now_ms()),
    "navigation": navigation_json,
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}
