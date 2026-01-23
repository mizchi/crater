///|
/// WebDriver BiDi Protocol (minimal)
///
/// Focuses on a BiDi-first automation surface while reusing CDP sessions.
/// This is intentionally small and grows as coverage expands.

///|
/// BiDi request message
pub struct BidiRequest {
  id : Int
  method_name : String
  params : Json?
} derive(Show)

///|
/// BiDi response message
pub struct BidiResponse {
  id : Int
  result : Json?
  error : BidiError?
} derive(Show)

///|
/// BiDi error payload
pub struct BidiError {
  error : String
  message : String
  stacktrace : String
} derive(Show)

///|
/// BiDi event message
pub struct BidiEvent {
  event_method : String
  params : Json
} derive(Show)

///|
/// Outgoing BiDi message
pub enum BidiOutMessage {
  Response(BidiResponse)
  Event(BidiEvent)
} derive(Show)

///|
/// BiDi protocol handler
pub struct BidiProtocol {
  manager : CdpSessionManager
  mut outbox : Array[BidiOutMessage]
  mut session_id : String?
  mut default_context_id : String?
  mut next_navigation_id : Int
  subscriptions : Map[String, Bool] // module-level subscriptions (legacy)
  context_subscriptions : Map[String, Array[String]] // context -> events
  mut global_subscriptions : Array[String] // events subscribed globally
  user_contexts : Map[String, Bool]
  context_user_context : Map[String, String]
}

///|
/// Create new BiDi protocol instance
pub fn BidiProtocol::new() -> BidiProtocol {
  let user_contexts : Map[String, Bool] = {}
  user_contexts["default"] = true
  {
    manager: CdpSessionManager::new(),
    outbox: [],
    session_id: None,
    default_context_id: None,
    next_navigation_id: 1,
    subscriptions: {},
    context_subscriptions: {},
    global_subscriptions: [],
    user_contexts,
    context_user_context: {},
  }
}

///|
/// Process incoming JSON message
pub fn BidiProtocol::process_message(
  self : BidiProtocol,
  json_str : String,
) -> Result[Unit, String] {
  let json = @json.parse(json_str) catch { _ => return Err("Invalid JSON") }
  let id = match get_int_field(json, "id") {
    Some(i) => i
    None => return Err("Missing id field")
  }
  let method_name = match get_string_field(json, "method") {
    Some(m) => m
    None => return Err("Missing method field")
  }
  let params = get_field(json, "params")
  let request : BidiRequest = { id, method_name, params }
  self.dispatch(request)
}

///|
/// Take and clear outgoing messages
pub fn BidiProtocol::take_messages(
  self : BidiProtocol,
) -> Array[BidiOutMessage] {
  let out = self.outbox
  self.outbox = []
  out
}

///|
/// Convert outgoing message to JSON string
pub fn BidiOutMessage::to_json(self : BidiOutMessage) -> String {
  match self {
    Response(resp) => response_to_json(resp)
    Event(evt) => event_to_json(evt)
  }
}

// =============================================================================
// Dispatch
// =============================================================================

///|
/// Dispatch request to method handler
fn BidiProtocol::dispatch(
  self : BidiProtocol,
  request : BidiRequest,
) -> Result[Unit, String] {
  let parts = split_method(request.method_name)
  let (domain, action) = match parts {
    Some(p) => p
    None => return Err("Invalid method format")
  }
  match domain {
    "session" => self.dispatch_session(request, action)
    "browser" => self.dispatch_browser(request, action)
    "browsingContext" => self.dispatch_browsing_context(request, action)
    "script" => self.dispatch_script(request, action)
    "input" => self.dispatch_input(request, action)
    "network" => self.dispatch_network(request, action)
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
/// Dispatch session domain
fn BidiProtocol::dispatch_session(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "status" => {
      self.send_success(
        request.id,
        Some(
          make_object({
            "ready": Json::boolean(true),
            "message": Json::string("Crater WebDriver BiDi is ready"),
          }),
        ),
      )
      Ok(())
    }
    "new" => {
      let session_id = "bidi-" + request.id.to_string()
      self.session_id = Some(session_id)
      let ctx_id = self.ensure_default_context()
      let caps = self.build_capabilities()
      let result = make_object({
        "sessionId": Json::string(session_id),
        "capabilities": caps,
      })
      // Send response BEFORE events (BiDi protocol requirement)
      self.send_success(request.id, Some(result))
      // Emit initial context + realm events so Puppeteer can bind immediately.
      self.emit_context_created(ctx_id, "tab", "about:blank")
      self.emit_default_realm(ctx_id)
      Ok(())
    }
    "subscribe" => {
      self.handle_subscribe(request.params)
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "unsubscribe" => {
      self.handle_unsubscribe(request.params)
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "end" => {
      self.session_id = None
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown session method: " + action,
      )
      Ok(())
    }
  }
}

///|
/// Dispatch browser domain
fn BidiProtocol::dispatch_browser(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "getUserContexts" => {
      let contexts : Array[Json] = []
      for id, _ in self.user_contexts {
        contexts.push(make_object({ "userContext": Json::string(id) }))
      }
      let result = make_object({ "userContexts": Json::array(contexts) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "createUserContext" => {
      let id = "user-" + self.user_contexts.length().to_string()
      self.user_contexts[id] = true
      let result = make_object({ "userContext": Json::string(id) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "removeUserContext" =>
      match get_string_param(request.params, "userContext") {
        Some(id) => {
          self.user_contexts.remove(id)
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing userContext")
          Ok(())
        }
      }
    "close" => {
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown browser method: " + action,
      )
      Ok(())
    }
  }
}

///|
/// Dispatch browsingContext domain
fn BidiProtocol::dispatch_browsing_context(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "getTree" => {
      // Validate maxDepth parameter type and value
      match get_param_raw(request.params, "maxDepth") {
        Some(Number(n)) => {
          // Check for valid non-negative integer
          // JSON numbers > 2^53 or floats or negative are invalid
          if n < 0.0 {
            self.send_error(
              request.id,
              "invalid argument",
              "maxDepth must be a non-negative integer",
            )
            return Ok(())
          }
          // Check if it's a float (has fractional part)
          let int_val = n.to_int64()
          if n != int_val.to_double() {
            self.send_error(
              request.id,
              "invalid argument",
              "maxDepth must be a non-negative integer",
            )
            return Ok(())
          }
          // Check for safe integer range (2^53)
          if n > 9007199254740991.0 {
            self.send_error(
              request.id,
              "invalid argument",
              "maxDepth must be a non-negative integer",
            )
            return Ok(())
          }
        }
        None => () // Valid: absent
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "maxDepth must be a non-negative integer",
          )
          return Ok(())
        }
      }
      // Validate root parameter - must be a string or absent
      match get_param_raw(request.params, "root") {
        Some(String(root_id)) =>
          // Root must be a known context
          if not(self.manager.has_session(root_id)) {
            self.send_error(
              request.id,
              "no such frame",
              "Unknown context: " + root_id,
            )
            return Ok(())
          }
        Some(True)
        | Some(False)
        | Some(Number(_))
        | Some(Array(_))
        | Some(Object(_))
        | Some(Null) => {
          self.send_error(
            request.id,
            "invalid argument",
            "root must be a string",
          )
          return Ok(())
        }
        None => () // No root specified, return all contexts
      }
      let contexts = self.build_context_tree()
      let result = make_object({ "contexts": Json::array(contexts) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "create" => {
      let user_ctx = get_string_param(request.params, "userContext").unwrap_or(
        "default",
      )
      let ctx_id = self.create_context(user_ctx)
      let result = make_object({ "context": Json::string(ctx_id) })
      // Send response BEFORE events (BiDi protocol requirement)
      self.send_success(request.id, Some(result))
      self.emit_context_created(ctx_id, "tab", "about:blank")
      self.emit_default_realm(ctx_id)
      Ok(())
    }
    "navigate" =>
      match
        (
          get_string_param(request.params, "context"),
          get_string_param(request.params, "url"),
        ) {
        (Some(ctx_id), Some(url)) =>
          match self.manager.get_session(ctx_id) {
            Some(session) =>
              match session.navigate_to(url) {
                Ok(_) => {
                  let nav_id = self.next_navigation_id.to_string()
                  self.next_navigation_id += 1
                  // Load content for data: URLs
                  if url.has_prefix("data:") {
                    match parse_data_url(url) {
                      Some((content_type, content)) =>
                        if content_type.has_prefix("text/html") ||
                          content_type == "" {
                          session.load_html(content)
                        }
                      None => ()
                    }
                  }
                  let result = make_object({
                    "navigation": Json::string(nav_id),
                    "url": Json::string(url),
                  })
                  // Send response BEFORE events (BiDi protocol requirement)
                  self.send_success(request.id, Some(result))
                  self.emit_navigation_events(ctx_id, url, nav_id)
                  Ok(())
                }
                Err(e) => {
                  self.send_error(
                    request.id,
                    "unknown error",
                    "Navigation failed: " + e.message,
                  )
                  Ok(())
                }
              }
            None => {
              self.send_error(
                request.id,
                "invalid argument",
                "Unknown context: " + ctx_id,
              )
              Ok(())
            }
          }
        _ => {
          self.send_error(request.id, "invalid argument", "Missing context/url")
          Ok(())
        }
      }
    "reload" =>
      match get_string_param(request.params, "context") {
        Some(ctx_id) =>
          match self.manager.get_session(ctx_id) {
            Some(session) => {
              let url = session.get_url()
              let nav_id = self.next_navigation_id.to_string()
              self.next_navigation_id += 1
              self.emit_navigation_events(ctx_id, url, nav_id)
              self.send_success(request.id, Some(make_object({})))
              Ok(())
            }
            None => {
              self.send_error(
                request.id,
                "invalid argument",
                "Unknown context: " + ctx_id,
              )
              Ok(())
            }
          }
        None => {
          self.send_error(request.id, "invalid argument", "Missing context")
          Ok(())
        }
      }
    "close" =>
      match get_string_param(request.params, "context") {
        Some(ctx_id) => {
          if self.manager.close_session(ctx_id) {
            // Send response BEFORE events (BiDi protocol requirement)
            self.send_success(request.id, Some(make_object({})))
            self.emit_context_destroyed(ctx_id)
          } else {
            self.send_error(
              request.id,
              "invalid argument",
              "Unknown context: " + ctx_id,
            )
          }
          Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing context")
          Ok(())
        }
      }
    "locateNodes" => {
      let result = make_object({ "nodes": Json::array([]) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown browsingContext method: " + action,
      )
      Ok(())
    }
  }
}

///|
/// Dispatch script domain
fn BidiProtocol::dispatch_script(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "evaluate" => {
      // Validate expression parameter - must be string
      match get_param_raw(request.params, "expression") {
        Some(String(_)) => ()
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "expression must be a string",
          )
          return Ok(())
        }
        None => {
          self.send_error(request.id, "invalid argument", "Missing expression")
          return Ok(())
        }
      }
      // Validate target parameter
      match self.validate_script_target(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate awaitPromise - must be boolean
      match self.validate_await_promise(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate resultOwnership - must be "root" or "none"
      match self.validate_result_ownership(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate serializationOptions
      match self.validate_serialization_options(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate userActivation - must be boolean
      match self.validate_user_activation(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Evaluate the expression using JS runtime
      let expr = get_string_param(request.params, "expression").unwrap()
      let eval_result_json = evaluate_js(expr)
      let eval_result = @json.parse(eval_result_json) catch {
        _ => {
          self.send_error(request.id, "unknown error", "Failed to parse eval result")
          return Ok(())
        }
      }
      // Build response based on evaluation result
      match get_string_field(eval_result, "type") {
        Some("success") => {
          let bidi_value = get_field(eval_result, "result").unwrap_or(
            make_object({ "type": Json::string("undefined") }),
          )
          let result = make_object({
            "realm": Json::string("default-realm"),
            "result": bidi_value,
          })
          self.send_success(request.id, Some(result))
        }
        Some("exception") => {
          let exc_details = get_field(eval_result, "exceptionDetails").unwrap_or(
            make_object({}),
          )
          let result = make_object({
            "realm": Json::string("default-realm"),
            "exceptionDetails": exc_details,
          })
          self.send_success(request.id, Some(result))
        }
        _ => {
          let result = make_object({
            "realm": Json::string("default-realm"),
            "result": make_object({ "type": Json::string("undefined") }),
          })
          self.send_success(request.id, Some(result))
        }
      }
      Ok(())
    }
    "callFunction" => {
      // Validate functionDeclaration - must be string
      match get_param_raw(request.params, "functionDeclaration") {
        Some(String(_)) => ()
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "functionDeclaration must be a string",
          )
          return Ok(())
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "Missing functionDeclaration",
          )
          return Ok(())
        }
      }
      // Validate target parameter
      match self.validate_script_target(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate awaitPromise - must be boolean
      match self.validate_await_promise(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate resultOwnership
      match self.validate_result_ownership(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate serializationOptions
      match self.validate_serialization_options(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Validate userActivation
      match self.validate_user_activation(request.id, request.params) {
        Some(_) => return Ok(())
        None => ()
      }
      // Get arguments if provided
      let args_json = match get_param_raw(request.params, "arguments") {
        Some(Array(args)) => {
          // Convert BiDi values to JS literal representation
          let parts : Array[String] = []
          for arg in args {
            parts.push(bidi_value_to_js_literal(arg))
          }
          parts.join(", ")
        }
        _ => ""
      }
      // Wrap function declaration and call it
      let func = get_string_param(request.params, "functionDeclaration").unwrap()
      let call_expr = "(" + func + ")(" + args_json + ")"
      let eval_result_json = evaluate_js(call_expr)
      let eval_result = @json.parse(eval_result_json) catch {
        _ => {
          self.send_error(request.id, "unknown error", "Failed to parse eval result")
          return Ok(())
        }
      }
      // Build response based on evaluation result
      match get_string_field(eval_result, "type") {
        Some("success") => {
          let bidi_value = get_field(eval_result, "result").unwrap_or(
            make_object({ "type": Json::string("undefined") }),
          )
          let result = make_object({
            "realm": Json::string("default-realm"),
            "result": bidi_value,
          })
          self.send_success(request.id, Some(result))
        }
        Some("exception") => {
          let exc_details = get_field(eval_result, "exceptionDetails").unwrap_or(
            make_object({}),
          )
          let result = make_object({
            "realm": Json::string("default-realm"),
            "exceptionDetails": exc_details,
          })
          self.send_success(request.id, Some(result))
        }
        _ => {
          let result = make_object({
            "realm": Json::string("default-realm"),
            "result": make_object({ "type": Json::string("undefined") }),
          })
          self.send_success(request.id, Some(result))
        }
      }
      Ok(())
    }
    "addPreloadScript" => {
      // Return a fake script ID
      let script_id = "preload-" + self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      let result = make_object({ "script": Json::string(script_id) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    "removePreloadScript" => {
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    "getRealms" => {
      // Return the default realm
      let realm = make_object({
        "realm": Json::string("default-realm"),
        "type": Json::string("window"),
        "origin": Json::string("://"),
      })
      let result = make_object({ "realms": Json::array([realm]) })
      self.send_success(request.id, Some(result))
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown script method: " + action,
      )
      Ok(())
    }
  }
}

///|
/// Dispatch input domain (no-op for now)
fn BidiProtocol::dispatch_input(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "performActions" | "releaseActions" => {
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown input method: " + action,
      )
      Ok(())
    }
  }
}

///|
/// Dispatch network domain (minimal no-op)
fn BidiProtocol::dispatch_network(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "addDataCollector" | "setCacheBehavior" => {
      self.send_success(request.id, Some(make_object({})))
      Ok(())
    }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown network method: " + action,
      )
      Ok(())
    }
  }
}

// =============================================================================
// Helpers
// =============================================================================

///|
/// Ensure default context exists and return its ID
fn BidiProtocol::ensure_default_context(self : BidiProtocol) -> String {
  match self.default_context_id {
    Some(id) => id
    None => {
      let id = self.create_context("default")
      self.default_context_id = Some(id)
      id
    }
  }
}

///|
/// Create a new browsing context backed by a CDP session
fn BidiProtocol::create_context(
  self : BidiProtocol,
  user_context_id : String,
) -> String {
  let id = self.manager.create_session()
  self.context_user_context[id] = user_context_id
  if not(self.user_contexts.contains(user_context_id)) {
    self.user_contexts[user_context_id] = true
  }
  id
}

///|
/// Build capabilities response
fn BidiProtocol::build_capabilities(self : BidiProtocol) -> Json {
  let _ = self
  make_object({
    "browserName": Json::string("crater"),
    "browserVersion": Json::string("0.1.0"),
    "platformName": Json::string("MoonBit"),
    "acceptInsecureCerts": Json::boolean(false),
    "userAgent": Json::string("Crater"),
  })
}

///|
/// Build tree result for browsingContext.getTree
fn BidiProtocol::build_context_tree(self : BidiProtocol) -> Array[Json] {
  let contexts : Array[Json] = []
  for ctx_id in self.manager.list_sessions() {
    match self.manager.get_session(ctx_id) {
      Some(session) =>
        contexts.push(
          make_object({
            "context": Json::string(ctx_id),
            "url": Json::string(session.get_url()),
            "children": Json::array([]),
            "userContext": Json::string(
              self.context_user_context.get(ctx_id).unwrap_or("default"),
            ),
          }),
        )
      None => ()
    }
  }
  contexts
}

///|
/// Handle session.subscribe params
fn BidiProtocol::handle_subscribe(self : BidiProtocol, params : Json?) -> Unit {
  match params {
    Some(Object(map)) => {
      // Get events to subscribe to
      let events_to_sub : Array[String] = []
      match map.get("events") {
        Some(Array(events)) =>
          for evt in events {
            match evt {
              String(s) => {
                events_to_sub.push(s)
                // Also add to legacy subscriptions for backward compatibility
                self.subscriptions[get_subscription_key(s)] = true
              }
              _ => ()
            }
          }
        _ => ()
      }
      // Check if contexts are specified
      match map.get("contexts") {
        Some(Array(contexts)) => {
          // Context-specific subscription
          for ctx in contexts {
            match ctx {
              String(ctx_id) => {
                let existing = self.context_subscriptions.get(ctx_id).unwrap_or([])
                for evt in events_to_sub {
                  if not(array_contains(existing, evt)) {
                    existing.push(evt)
                  }
                }
                self.context_subscriptions[ctx_id] = existing
              }
              _ => ()
            }
          }
        }
        _ => {
          // Global subscription (no contexts specified)
          for evt in events_to_sub {
            if not(array_contains(self.global_subscriptions, evt)) {
              self.global_subscriptions.push(evt)
            }
          }
        }
      }
    }
    _ => ()
  }
}

///|
/// Handle session.unsubscribe params
fn BidiProtocol::handle_unsubscribe(self : BidiProtocol, params : Json?) -> Unit {
  match params {
    Some(Object(map)) => {
      // Get events to unsubscribe from
      let events_to_unsub : Array[String] = []
      match map.get("events") {
        Some(Array(events)) =>
          for evt in events {
            match evt {
              String(s) => {
                events_to_unsub.push(s)
                // Remove from legacy subscriptions
                self.subscriptions.remove(get_subscription_key(s))
              }
              _ => ()
            }
          }
        _ => ()
      }
      // Check if contexts are specified
      match map.get("contexts") {
        Some(Array(contexts)) => {
          // Context-specific unsubscription
          for ctx in contexts {
            match ctx {
              String(ctx_id) =>
                match self.context_subscriptions.get(ctx_id) {
                  Some(existing) => {
                    let filtered = array_filter_not(existing, events_to_unsub)
                    self.context_subscriptions[ctx_id] = filtered
                  }
                  None => ()
                }
              _ => ()
            }
          }
        }
        _ => {
          // Global unsubscription
          self.global_subscriptions = array_filter_not(
            self.global_subscriptions,
            events_to_unsub,
          )
        }
      }
    }
    _ => ()
  }
}

///|
/// Check if array contains a string
fn array_contains(arr : Array[String], item : String) -> Bool {
  for s in arr {
    if s == item {
      return true
    }
  }
  false
}

///|
/// Filter array to exclude items in exclude list
fn array_filter_not(
  arr : Array[String],
  exclude : Array[String],
) -> Array[String] {
  let result : Array[String] = []
  for s in arr {
    if not(array_contains(exclude, s)) {
      result.push(s)
    }
  }
  result
}

///|
/// Emit contextCreated event
fn BidiProtocol::emit_context_created(
  self : BidiProtocol,
  ctx_id : String,
  ctx_type : String,
  url : String,
) -> Unit {
  let event_name = "browsingContext.contextCreated"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) &&
    not(self.is_subscribed("browsingContext")) {
    return
  }
  let user_ctx = self.context_user_context.get(ctx_id).unwrap_or("default")
  let params = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
    "type": Json::string(ctx_type),
    "userContext": Json::string(user_ctx),
    "originalOpener": Json::null(),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit contextDestroyed event
fn BidiProtocol::emit_context_destroyed(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let event_name = "browsingContext.contextDestroyed"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) &&
    not(self.is_subscribed("browsingContext")) {
    return
  }
  let params = make_object({ "context": Json::string(ctx_id) })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit default realmCreated event for a context
fn BidiProtocol::emit_default_realm(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let event_name = "script.realmCreated"
  if not(self.is_subscribed_for_context(event_name, ctx_id)) &&
    not(self.is_subscribed("script")) {
    return
  }
  let params = make_object({
    "realm": Json::string("realm-" + ctx_id),
    "type": Json::string("window"),
    "context": Json::string(ctx_id),
    "origin": Json::string("://"),
    "sandbox": Json::null(),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Emit basic navigation events
fn BidiProtocol::emit_navigation_events(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  let base = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(0.0),
  })
  // Emit navigationStarted
  if self.is_subscribed_for_context("browsingContext.navigationStarted", ctx_id) ||
    self.is_subscribed("browsingContext") {
    self.outbox.push(
      Event({ event_method: "browsingContext.navigationStarted", params: base }),
    )
  }
  // Emit domContentLoaded
  if self.is_subscribed_for_context("browsingContext.domContentLoaded", ctx_id) ||
    self.is_subscribed("browsingContext") {
    self.outbox.push(
      Event({ event_method: "browsingContext.domContentLoaded", params: base }),
    )
  }
  // Emit load
  if self.is_subscribed_for_context("browsingContext.load", ctx_id) ||
    self.is_subscribed("browsingContext") {
    self.outbox.push(
      Event({ event_method: "browsingContext.load", params: base }),
    )
  }
  // Emit historyUpdated
  let history = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
  })
  if self.is_subscribed_for_context("browsingContext.historyUpdated", ctx_id) ||
    self.is_subscribed("browsingContext") {
    self.outbox.push(
      Event({ event_method: "browsingContext.historyUpdated", params: history }),
    )
  }
}

///|
/// Check subscription for module/event (legacy, global only)
fn BidiProtocol::is_subscribed(self : BidiProtocol, key : String) -> Bool {
  self.subscriptions.get(key).unwrap_or(false)
}

///|
/// Check if subscribed to event for a specific context
fn BidiProtocol::is_subscribed_for_context(
  self : BidiProtocol,
  event : String,
  ctx_id : String,
) -> Bool {
  let module_key = get_subscription_key(event)
  // Check legacy module-level subscription
  if self.subscriptions.get(module_key).unwrap_or(false) {
    return true
  }
  // Check global subscriptions (exact event match or module match)
  for sub in self.global_subscriptions {
    if sub == event || get_subscription_key(sub) == module_key {
      return true
    }
  }
  // Check context-specific subscriptions
  match self.context_subscriptions.get(ctx_id) {
    Some(events) =>
      for sub in events {
        if sub == event || get_subscription_key(sub) == module_key {
          return true
        }
      }
    None => ()
  }
  false
}

///|
/// Send success response
fn BidiProtocol::send_success(
  self : BidiProtocol,
  id : Int,
  result : Json?,
) -> Unit {
  let resp : BidiResponse = { id, result, error: None }
  self.outbox.push(Response(resp))
}

///|
/// Send error response
fn BidiProtocol::send_error(
  self : BidiProtocol,
  id : Int,
  code : String,
  message : String,
) -> Unit {
  let err : BidiError = { error: code, message, stacktrace: "" }
  let resp : BidiResponse = { id, result: None, error: Some(err) }
  self.outbox.push(Response(resp))
}

///|
/// Parse method into (domain, action)
fn split_method(method_name : String) -> (String, String)? {
  let domain = StringBuilder::new()
  let action = StringBuilder::new()
  let mut in_action = false
  for c in method_name.iter() {
    if c == '.' && not(in_action) {
      in_action = true
    } else if in_action {
      action.write_char(c)
    } else {
      domain.write_char(c)
    }
  }
  let d = domain.to_string()
  let a = action.to_string()
  if d.length() == 0 || a.length() == 0 {
    None
  } else {
    Some((d, a))
  }
}

///|
/// Normalize subscription key
fn get_subscription_key(name : String) -> String {
  let buf = StringBuilder::new()
  for c in name.iter() {
    if c == '.' {
      break
    }
    buf.write_char(c)
  }
  let key = buf.to_string()
  if key.length() == 0 {
    name
  } else {
    key
  }
}

///|
/// JSON helpers
fn make_object(map : Map[String, Json]) -> Json {
  Json::object(map)
}

///|
fn get_field(json : Json, key : String) -> Json? {
  match json {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn get_string_field(json : Json, key : String) -> String? {
  match get_field(json, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn get_int_field(json : Json, key : String) -> Int? {
  match get_field(json, key) {
    Some(Number(n, ..)) => Some(n.to_int())
    _ => None
  }
}

///|
fn get_string_param(params : Json?, key : String) -> String? {
  match params {
    Some(Object(map)) =>
      match map.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// Get raw parameter value without type conversion
fn get_param_raw(params : Json?, key : String) -> Json? {
  match params {
    Some(Object(map)) => map.get(key)
    _ => None
  }
}

///|
/// Validate script target parameter
/// Returns Some(()) if error was sent, None if valid
fn BidiProtocol::validate_script_target(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "target") {
    None => {
      self.send_error(request_id, "invalid argument", "Missing target")
      return Some(())
    }
    Some(Object(target_map)) => {
      // Check if context is specified
      match target_map.get("context") {
        Some(String(ctx_id)) =>
          if not(self.manager.has_session(ctx_id)) {
            self.send_error(
              request_id,
              "no such frame",
              "Unknown context: " + ctx_id,
            )
            return Some(())
          }
        Some(Null) | Some(True) | Some(False) | Some(Number(_)) | Some(Array(_)) |
        Some(Object(_)) => {
          self.send_error(
            request_id,
            "invalid argument",
            "target.context must be a string",
          )
          return Some(())
        }
        None => ()
      }
      // Check if realm is specified
      match target_map.get("realm") {
        Some(String(realm_id)) =>
          // Currently we only have "default-realm"
          if realm_id != "default-realm" &&
            not(realm_id.has_prefix("realm-")) {
            self.send_error(
              request_id,
              "no such frame",
              "Unknown realm: " + realm_id,
            )
            return Some(())
          }
        Some(Null) | Some(True) | Some(False) | Some(Number(_)) | Some(Array(_)) |
        Some(Object(_)) => {
          self.send_error(
            request_id,
            "invalid argument",
            "target.realm must be a string",
          )
          return Some(())
        }
        None => ()
      }
      // Target must have either context or realm
      if target_map.get("context") is None && target_map.get("realm") is None {
        self.send_error(
          request_id,
          "invalid argument",
          "target must have either context or realm",
        )
        return Some(())
      }
      // Validate sandbox if present (must be string)
      match target_map.get("sandbox") {
        Some(String(_)) => ()
        Some(Null) => () // null is allowed
        Some(True) | Some(False) | Some(Number(_)) | Some(Array(_)) | Some(Object(_)) => {
          self.send_error(
            request_id,
            "invalid argument",
            "target.sandbox must be a string",
          )
          return Some(())
        }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "target must be an object")
      return Some(())
    }
  }
  None
}

///|
/// Validate awaitPromise parameter (must be boolean)
fn BidiProtocol::validate_await_promise(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "awaitPromise") {
    Some(True) | Some(False) => ()
    None => () // Optional, defaults to false
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        "awaitPromise must be a boolean",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate resultOwnership parameter (must be "root" or "none")
fn BidiProtocol::validate_result_ownership(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "resultOwnership") {
    Some(String(s)) =>
      if s != "root" && s != "none" {
        self.send_error(
          request_id,
          "invalid argument",
          "resultOwnership must be 'root' or 'none'",
        )
        return Some(())
      }
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        "resultOwnership must be a string",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate serializationOptions parameter
fn BidiProtocol::validate_serialization_options(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "serializationOptions") {
    Some(Object(opts)) => {
      // Validate maxDomDepth
      match opts.get("maxDomDepth") {
        Some(Number(n, ..)) =>
          if n < 0.0 || n != n.to_int64().to_double() {
            self.send_error(
              request_id,
              "invalid argument",
              "maxDomDepth must be a non-negative integer",
            )
            return Some(())
          }
        Some(Null) => ()
        Some(_) => {
          self.send_error(
            request_id,
            "invalid argument",
            "maxDomDepth must be a non-negative integer",
          )
          return Some(())
        }
        None => ()
      }
      // Validate maxObjectDepth
      match opts.get("maxObjectDepth") {
        Some(Number(n, ..)) =>
          if n < 0.0 || n != n.to_int64().to_double() {
            self.send_error(
              request_id,
              "invalid argument",
              "maxObjectDepth must be a non-negative integer",
            )
            return Some(())
          }
        Some(Null) => ()
        Some(_) => {
          self.send_error(
            request_id,
            "invalid argument",
            "maxObjectDepth must be a non-negative integer",
          )
          return Some(())
        }
        None => ()
      }
      // Validate includeShadowTree
      match opts.get("includeShadowTree") {
        Some(String(s)) =>
          if s != "none" && s != "open" && s != "all" {
            self.send_error(
              request_id,
              "invalid argument",
              "includeShadowTree must be 'none', 'open', or 'all'",
            )
            return Some(())
          }
        Some(Null) => ()
        Some(_) => {
          self.send_error(
            request_id,
            "invalid argument",
            "includeShadowTree must be a string",
          )
          return Some(())
        }
        None => ()
      }
    }
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        "serializationOptions must be an object",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate userActivation parameter (must be boolean)
fn BidiProtocol::validate_user_activation(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "userActivation") {
    Some(True) | Some(False) => ()
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id,
        "invalid argument",
        "userActivation must be a boolean",
      )
      return Some(())
    }
  }
  None
}

///|
/// Convert BiDi remote value to JS literal for function arguments
fn bidi_value_to_js_literal(value : Json) -> String {
  match value {
    Object(map) =>
      match map.get("type") {
        Some(String("undefined")) => "undefined"
        Some(String("null")) => "null"
        Some(String("boolean")) =>
          match map.get("value") {
            Some(True) => "true"
            Some(False) => "false"
            _ => "false"
          }
        Some(String("number")) =>
          match map.get("value") {
            Some(Number(n, ..)) => n.to_string()
            Some(String(s)) => s // NaN, Infinity, etc.
            _ => "0"
          }
        Some(String("string")) =>
          match map.get("value") {
            Some(String(s)) => "\"" + escape_js_string(s) + "\""
            _ => "\"\""
          }
        Some(String("bigint")) =>
          match map.get("value") {
            Some(String(s)) => s + "n"
            _ => "0n"
          }
        Some(String("array")) =>
          match map.get("value") {
            Some(Array(items)) => {
              let parts : Array[String] = []
              for item in items {
                parts.push(bidi_value_to_js_literal(item))
              }
              "[" + parts.join(", ") + "]"
            }
            _ => "[]"
          }
        Some(String("object")) =>
          match map.get("value") {
            Some(Array(entries)) => {
              let parts : Array[String] = []
              for entry in entries {
                match entry {
                  Array(kv) if kv.length() >= 2 => {
                    let key = match kv[0] {
                      String(s) => "\"" + escape_js_string(s) + "\""
                      _ => bidi_value_to_js_literal(kv[0])
                    }
                    let val = bidi_value_to_js_literal(kv[1])
                    parts.push(key + ": " + val)
                  }
                  _ => ()
                }
              }
              "{" + parts.join(", ") + "}"
            }
            _ => "{}"
          }
        _ => "undefined"
      }
    _ => "undefined"
  }
}

///|
/// Escape special characters in JS string
fn escape_js_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s.iter() {
    match c {
      '\\' => buf.write_string("\\\\")
      '"' => buf.write_string("\\\"")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Response JSON serialization
fn response_to_json(resp : BidiResponse) -> String {
  let obj : Map[String, Json] = {}
  obj["id"] = Json::number(resp.id.to_double())
  match resp.error {
    Some(err) => {
      obj["type"] = Json::string("error")
      obj["error"] = Json::string(err.error)
      obj["message"] = Json::string(err.message)
      obj["stacktrace"] = Json::string(err.stacktrace)
    }
    None => {
      obj["type"] = Json::string("success")
      match resp.result {
        Some(r) => obj["result"] = r
        None => obj["result"] = make_object({})
      }
    }
  }
  make_object(obj).stringify()
}

///|
/// Event JSON serialization
fn event_to_json(evt : BidiEvent) -> String {
  let obj : Map[String, Json] = {}
  obj["type"] = Json::string("event")
  obj["method"] = Json::string(evt.event_method)
  obj["params"] = evt.params
  make_object(obj).stringify()
}
