///|
/// CDP-based WebDriver Handler
///
/// This handler uses CDP sessions instead of direct Browser access.
/// All WebDriver operations are routed through CDP domains.

// =============================================================================
// CDP Session Manager
// =============================================================================

///|
/// Manages CDP sessions for WebDriver
pub struct CdpSessionManager {
  sessions : Map[String, @cdp.CdpSession]
  mut next_id : Int
}

///|
/// Create a new CDP session manager
pub fn CdpSessionManager::new() -> CdpSessionManager {
  { sessions: {}, next_id: 1 }
}

///|
/// Generate a unique session ID
fn CdpSessionManager::generate_id(self : CdpSessionManager) -> String {
  let id = "session-" + self.next_id.to_string()
  self.next_id += 1
  id
}

///|
/// Create a new CDP session
pub fn CdpSessionManager::create_session(self : CdpSessionManager) -> String {
  let id = self.generate_id()
  let session = @cdp.CdpSession::new(id)
  self.sessions[id] = session
  id
}

///|
/// Get a session by ID
pub fn CdpSessionManager::get_session(
  self : CdpSessionManager,
  session_id : String,
) -> @cdp.CdpSession? {
  self.sessions.get(session_id)
}

///|
/// Check if a session exists
pub fn CdpSessionManager::has_session(
  self : CdpSessionManager,
  session_id : String,
) -> Bool {
  self.sessions.contains(session_id)
}

///|
/// Close a session
pub fn CdpSessionManager::close_session(
  self : CdpSessionManager,
  session_id : String,
) -> Bool {
  match self.sessions.get(session_id) {
    Some(_) => {
      self.sessions.remove(session_id)
      true
    }
    None => false
  }
}

///|
/// List all session IDs
pub fn CdpSessionManager::list_sessions(
  self : CdpSessionManager,
) -> Array[String] {
  let ids : Array[String] = []
  for id, _ in self.sessions {
    ids.push(id)
  }
  ids
}

// =============================================================================
// WebDriver Command Handlers (using CDP)
// =============================================================================

///|
/// Handle findElement via CDP
pub fn handle_find_element(
  session : @cdp.CdpSession,
  strategy : String,
  value : String,
) -> Result[Int, CdpHandlerError] {
  // Convert WebDriver locator strategy to CSS selector
  let selector : String = match strategy {
    "css selector" => value
    "id" => "#" + value
    "class name" => "." + value
    "tag name" => value
    "link text" => "a"
    "partial link text" => "a"
    _ => return Err(InvalidSelector(selector=strategy + ":" + value))
  }
  // Query for element
  match session.query_selector(selector) {
    Ok(Some(node_id)) =>
      // For link text strategies, verify the text matches
      if strategy == "link text" || strategy == "partial link text" {
        match verify_link_text(session, node_id, strategy, value) {
          Some(matched_id) => Ok(matched_id)
          None => Err(NoSuchElement(selector=value))
        }
      } else {
        Ok(node_id)
      }
    Ok(None) => Err(NoSuchElement(selector=value))
    Err(e) => Err(InternalCdpError(message=e.message))
  }
}

///|
/// Handle findElements via CDP
pub fn handle_find_elements(
  session : @cdp.CdpSession,
  strategy : String,
  value : String,
) -> Result[Array[Int], CdpHandlerError] {
  let selector : String = match strategy {
    "css selector" => value
    "id" => "#" + value
    "class name" => "." + value
    "tag name" => value
    "link text" => "a"
    "partial link text" => "a"
    _ => return Err(InvalidSelector(selector=strategy + ":" + value))
  }
  match session.query_selector_all(selector) {
    Ok(node_ids) =>
      if strategy == "link text" || strategy == "partial link text" {
        // Filter by text content
        let matched : Array[Int] = []
        for node_id in node_ids {
          match verify_link_text(session, node_id, strategy, value) {
            Some(id) => matched.push(id)
            None => ()
          }
        }
        Ok(matched)
      } else {
        Ok(node_ids)
      }
    Err(e) => Err(InternalCdpError(message=e.message))
  }
}

///|
/// Verify link text matches
fn verify_link_text(
  session : @cdp.CdpSession,
  node_id : Int,
  strategy : String,
  expected : String,
) -> Int? {
  let node = @dom.NodeId::from_int(node_id)
  match session.get_tree().get_text_content(node) {
    Ok(text) => {
      let trimmed = text.trim().to_string()
      let is_match = if strategy == "link text" {
        trimmed == expected
      } else {
        // partial link text
        trimmed.contains(expected)
      }
      if is_match {
        Some(node_id)
      } else {
        None
      }
    }
    Err(_) => None
  }
}

///|
/// Handle element click via CDP
pub fn handle_element_click(
  session : @cdp.CdpSession,
  element_id : Int,
) -> Result[Unit, CdpHandlerError] {
  match session.click_element(element_id) {
    Ok(_) => Ok(())
    Err(e) => Err(InternalCdpError(message=e.message))
  }
}

///|
/// Handle getElementText via CDP
pub fn handle_get_element_text(
  session : @cdp.CdpSession,
  element_id : Int,
) -> Result[String, CdpHandlerError] {
  let node = @dom.NodeId::from_int(element_id)
  match session.get_tree().get_text_content(node) {
    Ok(text) => Ok(text)
    Err(e) => Err(InternalCdpError(message=e.to_string()))
  }
}

///|
/// Handle getElementAttribute via CDP
pub fn handle_get_element_attribute(
  session : @cdp.CdpSession,
  element_id : Int,
  name : String,
) -> Result[String?, CdpHandlerError] {
  let node = @dom.NodeId::from_int(element_id)
  match session.get_tree().get_attribute(node, name) {
    Ok(value) => Ok(value)
    Err(e) => Err(InternalCdpError(message=e.to_string()))
  }
}

///|
/// Handle getElementTagName via CDP
pub fn handle_get_element_tag_name(
  session : @cdp.CdpSession,
  element_id : Int,
) -> Result[String, CdpHandlerError] {
  let node = @dom.NodeId::from_int(element_id)
  match session.get_tree().get_tag_name(node) {
    Ok(tag) => Ok(tag)
    Err(e) => Err(InternalCdpError(message=e.to_string()))
  }
}

///|
/// Handle navigation via CDP
pub fn handle_navigate(
  session : @cdp.CdpSession,
  url : String,
) -> Result[Unit, CdpHandlerError] {
  match session.navigate_to(url) {
    Ok(_) => Ok(())
    Err(e) => Err(NavigationFailed(url~, reason=e.message))
  }
}

///|
/// Handle getCurrentUrl via CDP
pub fn handle_get_current_url(session : @cdp.CdpSession) -> String {
  session.get_url()
}

///|
/// Handle getTitle via CDP
pub fn handle_get_title(session : @cdp.CdpSession) -> String {
  session.get_title()
}

// =============================================================================
// WebDriver Error Types
// =============================================================================

///|
/// CDP Handler errors
pub enum CdpHandlerError {
  NoSuchElement(selector~ : String)
  InvalidSelector(selector~ : String)
  NavigationFailed(url~ : String, reason~ : String)
  InternalCdpError(message~ : String)
} derive(Show)

///|
/// Convert CdpHandlerError to W3C error format
pub fn CdpHandlerError::to_w3c_error(
  self : CdpHandlerError,
) -> (String, String) {
  match self {
    NoSuchElement(selector~) =>
      ("no such element", "Unable to locate element: " + selector)
    InvalidSelector(selector~) =>
      ("invalid selector", "Invalid selector: " + selector)
    NavigationFailed(url~, reason~) =>
      ("unknown error", "Navigation to " + url + " failed: " + reason)
    InternalCdpError(message~) => ("unknown error", message)
  }
}
