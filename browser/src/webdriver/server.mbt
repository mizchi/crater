///|
/// WebDriver Server Handler
/// Dispatches WebDriver commands to the browser implementation

///|
/// Session manager
pub(all) struct SessionManager {
  sessions : Map[String, SessionState]
  mut next_id : Int
}

///|
/// Session state
pub(all) struct SessionState {
  id : String
  capabilities : Capabilities
  mut current_url : String
  mut title : String
  window_rect : WindowRect
}

///|
/// Create new session manager
pub fn SessionManager::new() -> SessionManager {
  { sessions: {}, next_id: 1 }
}

///|
/// Generate new session ID
pub fn SessionManager::generate_id(self : SessionManager) -> String {
  let id = "session-" + self.next_id.to_string()
  self.next_id = self.next_id + 1
  id
}

///|
/// Create a new session
pub fn SessionManager::create_session(
  self : SessionManager,
  _body : String
) -> WebDriverResponse {
  let id = self.generate_id()
  let capabilities : Capabilities = {
    browser_name: "crater",
    browser_version: "0.1.0",
    platform_name: "MoonBit",
    accept_insecure_certs: false,
    page_load_strategy: Normal,
    proxy: None,
    timeouts: Timeouts::default(),
  }
  let state : SessionState = {
    id,
    capabilities,
    current_url: "about:blank",
    title: "",
    window_rect: { x: 0, y: 0, width: 800, height: 600 },
  }
  self.sessions[id] = state

  // Return session info
  let map : Map[String, WebDriverValue] = {}
  map["sessionId"] = String(id)
  map["capabilities"] = capabilities_to_value(capabilities)
  success_object(map)
}

///|
/// Convert capabilities to WebDriverValue
fn capabilities_to_value(cap : Capabilities) -> WebDriverValue {
  let map : Map[String, WebDriverValue] = {}
  map["browserName"] = String(cap.browser_name)
  map["browserVersion"] = String(cap.browser_version)
  map["platformName"] = String(cap.platform_name)
  map["acceptInsecureCerts"] = Bool(cap.accept_insecure_certs)
  map["pageLoadStrategy"] = String(cap.page_load_strategy.to_json_string())
  Object(map)
}

///|
/// Delete a session
pub fn SessionManager::delete_session(
  self : SessionManager,
  session_id : String
) -> WebDriverResponse {
  match self.sessions.get(session_id) {
    Some(_) => {
      self.sessions.remove(session_id)
      success_null()
    }
    None => error_response(InvalidSessionId, "Session not found: " + session_id)
  }
}

///|
/// Get session state
pub fn SessionManager::get_session(
  self : SessionManager,
  session_id : String
) -> SessionState? {
  self.sessions.get(session_id)
}

///|
/// Handle WebDriver request
pub fn SessionManager::handle_request(
  self : SessionManager,
  request : WebDriverRequest
) -> (Int, WebDriverResponse) {
  match request.command {
    // Status endpoint (no session required)
    Status => (200, self.handle_status())

    // Session management
    NewSession => {
      let resp = self.create_session(request.body)
      (200, resp)
    }
    DeleteSession(session_id~) => {
      let resp = self.delete_session(session_id)
      match resp {
        Success(_) => (200, resp)
        Error(err) => (err.error.http_status(), resp)
      }
    }
    GetSession(session_id~) =>
      match self.get_session(session_id) {
        Some(state) => {
          let map : Map[String, WebDriverValue] = {}
          map["sessionId"] = String(state.id)
          map["capabilities"] = capabilities_to_value(state.capabilities)
          (200, success_object(map))
        }
        None =>
          (
            404,
            error_response(InvalidSessionId, "Session not found: " + session_id),
          )
      }

    // Timeouts
    GetTimeouts(session_id~) =>
      match self.get_session(session_id) {
        Some(state) => {
          let map : Map[String, WebDriverValue] = {}
          map["script"] = Number(state.capabilities.timeouts.script.to_double())
          map["pageLoad"] = Number(
            state.capabilities.timeouts.page_load.to_double(),
          )
          map["implicit"] = Number(
            state.capabilities.timeouts.implicit.to_double(),
          )
          (200, success_object(map))
        }
        None =>
          (
            404,
            error_response(InvalidSessionId, "Session not found: " + session_id),
          )
      }

    // Navigation
    GetCurrentUrl(session_id~) =>
      match self.get_session(session_id) {
        Some(state) => (200, success_string(state.current_url))
        None =>
          (
            404,
            error_response(InvalidSessionId, "Session not found: " + session_id),
          )
      }
    NavigateTo(session_id~) =>
      match self.sessions.get(session_id) {
        Some(state) => {
          // TODO: Parse URL from body and actually navigate
          // For now, just update the URL
          state.current_url = "https://example.com"
          state.title = "Example Domain"
          (200, success_null())
        }
        None =>
          (
            404,
            error_response(InvalidSessionId, "Session not found: " + session_id),
          )
      }
    GetTitle(session_id~) =>
      match self.get_session(session_id) {
        Some(state) => (200, success_string(state.title))
        None =>
          (
            404,
            error_response(InvalidSessionId, "Session not found: " + session_id),
          )
      }

    // Window
    GetWindowRect(session_id~) =>
      match self.get_session(session_id) {
        Some(state) => {
          let map : Map[String, WebDriverValue] = {}
          map["x"] = Number(state.window_rect.x.to_double())
          map["y"] = Number(state.window_rect.y.to_double())
          map["width"] = Number(state.window_rect.width.to_double())
          map["height"] = Number(state.window_rect.height.to_double())
          (200, success_object(map))
        }
        None =>
          (
            404,
            error_response(InvalidSessionId, "Session not found: " + session_id),
          )
      }

    // Unknown/Unimplemented
    Unknown(path~) =>
      (404, error_response(UnknownCommand, "Unknown command: " + path))
    _ =>
      (
        501,
        error_response(UnsupportedOperation, "Command not yet implemented"),
      )
  }
}

///|
/// Handle status request
fn SessionManager::handle_status(self : SessionManager) -> WebDriverResponse {
  let _ = self // suppress unused warning
  let map : Map[String, WebDriverValue] = {}
  map["ready"] = Bool(true)
  map["message"] = String("Crater WebDriver is ready")
  success_object(map)
}
