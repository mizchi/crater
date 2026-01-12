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
  subscriptions : Map[String, Bool]
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
      self.emit_context_created(ctx_id, "tab", "about:blank")
      self.emit_default_realm(ctx_id)
      self.send_success(request.id, Some(result))
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
                  self.emit_navigation_events(ctx_id, url, nav_id)
                  self.send_success(request.id, Some(make_object({})))
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
            self.emit_context_destroyed(ctx_id)
            self.send_success(request.id, Some(make_object({})))
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
    "evaluate" | "callFunction" => {
      let result = make_object({
        "type": Json::string("success"),
        "result": make_object({ "type": Json::string("undefined") }),
      })
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
    Some(Object(map)) =>
      match map.get("events") {
        Some(Array(events)) =>
          for evt in events {
            match evt {
              String(s) => self.subscriptions[get_subscription_key(s)] = true
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
}

///|
/// Emit contextCreated event
fn BidiProtocol::emit_context_created(
  self : BidiProtocol,
  ctx_id : String,
  ctx_type : String,
  url : String,
) -> Unit {
  if not(self.is_subscribed("browsingContext")) {
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
  self.outbox.push(
    Event({ event_method: "browsingContext.contextCreated", params }),
  )
}

///|
/// Emit contextDestroyed event
fn BidiProtocol::emit_context_destroyed(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  if not(self.is_subscribed("browsingContext")) {
    return
  }
  let params = make_object({ "context": Json::string(ctx_id) })
  self.outbox.push(
    Event({ event_method: "browsingContext.contextDestroyed", params }),
  )
}

///|
/// Emit default realmCreated event for a context
fn BidiProtocol::emit_default_realm(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  if not(self.is_subscribed("script")) {
    return
  }
  let params = make_object({
    "realm": Json::string("realm-" + ctx_id),
    "type": Json::string("window"),
    "context": Json::string(ctx_id),
    "origin": Json::string("://"),
    "sandbox": Json::null(),
  })
  self.outbox.push(Event({ event_method: "script.realmCreated", params }))
}

///|
/// Emit basic navigation events
fn BidiProtocol::emit_navigation_events(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
  navigation_id : String,
) -> Unit {
  if not(self.is_subscribed("browsingContext")) {
    return
  }
  let base = make_object({
    "context": Json::string(ctx_id),
    "navigation": Json::string(navigation_id),
    "url": Json::string(url),
    "timestamp": Json::number(0.0),
  })
  self.outbox.push(
    Event({ event_method: "browsingContext.navigationStarted", params: base }),
  )
  self.outbox.push(
    Event({ event_method: "browsingContext.domContentLoaded", params: base }),
  )
  self.outbox.push(
    Event({ event_method: "browsingContext.load", params: base }),
  )
  let history = make_object({
    "context": Json::string(ctx_id),
    "url": Json::string(url),
  })
  self.outbox.push(
    Event({ event_method: "browsingContext.historyUpdated", params: history }),
  )
}

///|
/// Check subscription for module/event
fn BidiProtocol::is_subscribed(self : BidiProtocol, key : String) -> Bool {
  self.subscriptions.get(key).unwrap_or(false)
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
