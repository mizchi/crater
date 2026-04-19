///|
/// CDP Context (Browser Context)
///
/// Manages browser context state for CDP sessions.
/// Each context has its own target and session.

///|
/// CDP Context - equivalent to lightpanda's BrowserContext
pub struct CdpContext {
  /// Browser context ID
  id : String
  /// Target ID (page)
  mut target_id : String?
  /// Session ID (for attachToTarget)
  mut session_id : String?
  /// CDP Session containing DOM tree and domains
  session : CdpSession
  /// Current URL
  mut url : String
  /// Page title
  mut title : String
}

///|
/// Create new CDP context
pub fn CdpContext::new(id : String) -> CdpContext {
  let session = CdpSession::new(id)
  {
    id,
    target_id: None,
    session_id: None,
    session,
    url: "about:blank",
    title: "",
  }
}

///|
/// Get context ID
pub fn CdpContext::get_id(self : CdpContext) -> String {
  self.id
}

///|
/// Get target ID
pub fn CdpContext::get_target_id(self : CdpContext) -> String? {
  self.target_id
}

///|
/// Get session ID
pub fn CdpContext::get_session_id(self : CdpContext) -> String? {
  self.session_id
}

///|
/// Get underlying session
pub fn CdpContext::get_session(self : CdpContext) -> CdpSession {
  self.session
}

///|
/// Get current URL
pub fn CdpContext::get_url(self : CdpContext) -> String {
  self.url
}

///|
/// Get page title
pub fn CdpContext::get_title(self : CdpContext) -> String {
  self.title
}

///|
/// Set target ID
pub fn CdpContext::set_target_id(self : CdpContext, target_id : String) -> Unit {
  self.target_id = Some(target_id)
}

///|
/// Set session ID
pub fn CdpContext::set_session_id(
  self : CdpContext,
  session_id : String,
) -> Unit {
  self.session_id = Some(session_id)
}

///|
/// Clear target (close)
pub fn CdpContext::clear_target(self : CdpContext) -> Unit {
  self.target_id = None
  self.session_id = None
}

///|
/// Detach session
pub fn CdpContext::detach(self : CdpContext) -> Unit {
  self.session_id = None
}

///|
/// Check if target is attached
pub fn CdpContext::is_attached(self : CdpContext) -> Bool {
  match self.session_id {
    Some(_) => true
    None => false
  }
}

///|
/// Navigate to URL
pub fn CdpContext::navigate(
  self : CdpContext,
  url : String,
) -> Result[CdpNavigateResult, CdpError] {
  self.url = url
  self.session.navigate_to(url)
}

///|
/// Set page title
pub fn CdpContext::set_title(self : CdpContext, title : String) -> Unit {
  self.title = title
  self.session.set_title(title)
}
