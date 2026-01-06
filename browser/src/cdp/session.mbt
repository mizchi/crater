///|
/// CDP Session
///
/// A CDP session combines all domains and provides
/// the unified interface for protocol operations.

///|
/// CDP Session - combines all domains
pub struct CdpSession {
  /// Shared DOM tree
  tree : @core.DomTree
  /// DOM domain
  dom : DomDomain
  /// Input domain
  input : InputDomain
  /// Page domain
  page : PageDomain
  /// Session ID
  session_id : String
  /// Target ID (for DevTools protocol)
  target_id : String
}

///|
/// Create new CDP session
pub fn CdpSession::new(session_id : String) -> CdpSession {
  let tree = @core.DomTree::new()
  {
    tree,
    dom: DomDomain::new(tree),
    input: InputDomain::new(tree),
    page: PageDomain::new(tree),
    session_id,
    target_id: "page-" + session_id,
  }
}

///|
/// Get DOM domain
pub fn CdpSession::get_dom(self : CdpSession) -> DomDomain {
  self.dom
}

///|
/// Get Input domain
pub fn CdpSession::get_input(self : CdpSession) -> InputDomain {
  self.input
}

///|
/// Get Page domain
pub fn CdpSession::get_page(self : CdpSession) -> PageDomain {
  self.page
}

///|
/// Get underlying DOM tree for direct manipulation
pub fn CdpSession::get_tree(self : CdpSession) -> @core.DomTree {
  self.tree
}

///|
/// Get session ID
pub fn CdpSession::get_session_id(self : CdpSession) -> String {
  self.session_id
}

///|
/// Get target ID
pub fn CdpSession::get_target_id(self : CdpSession) -> String {
  self.target_id
}

// =============================================================================
// High-level convenience methods
// =============================================================================

///|
/// Navigate to URL (combines Page.navigate with state update)
pub fn CdpSession::navigate_to(
  self : CdpSession,
  url : String,
) -> Result[CdpNavigateResult, CdpError] {
  self.page.navigate(url)
}

///|
/// Get current URL
pub fn CdpSession::get_url(self : CdpSession) -> String {
  self.page.get_url()
}

///|
/// Get page title
pub fn CdpSession::get_title(self : CdpSession) -> String {
  self.page.get_title()
}

///|
/// Set page title
pub fn CdpSession::set_title(self : CdpSession, title : String) -> Unit {
  self.page.set_title(title)
}

///|
/// Find element by selector
pub fn CdpSession::query_selector(
  self : CdpSession,
  selector : String,
) -> Result[Int?, CdpError] {
  let doc = self.tree.get_document()
  self.dom.query_selector(doc.to_int(), selector)
}

///|
/// Find all elements by selector
pub fn CdpSession::query_selector_all(
  self : CdpSession,
  selector : String,
) -> Result[Array[Int], CdpError] {
  let doc = self.tree.get_document()
  self.dom.query_selector_all(doc.to_int(), selector)
}

///|
/// Click element by node ID
pub fn CdpSession::click_element(
  self : CdpSession,
  node_id : Int,
) -> Result[Unit, CdpError] {
  // Get element's box model
  match self.dom.get_box_model(node_id) {
    Ok(box_model) => {
      // Calculate center of element
      let center_x = (box_model.content[0] + box_model.content[2]) / 2.0
      let center_y = (box_model.content[1] + box_model.content[5]) / 2.0
      // Dispatch mouse events
      let _ = self.input.dispatch_mouse_event(
        "mousePressed", center_x, center_y, "left", 1,
      )
      self.input.dispatch_mouse_event(
        "mouseReleased", center_x, center_y, "left", 1,
      )
    }
    Err(e) => Err(e)
  }
}

///|
/// Type text into focused element
pub fn CdpSession::type_text(
  self : CdpSession,
  text : String,
) -> Result[Unit, CdpError] {
  self.input.insert_text(text)
}

///|
/// Focus element
pub fn CdpSession::focus_element(
  self : CdpSession,
  node_id : Int,
) -> Result[Unit, CdpError] {
  let node = @core.NodeId::from_int(node_id)
  // Verify node exists
  match self.tree.get_node_info(node) {
    Ok(_) => {
      self.tree.set_focus(Some(node))
      Ok(())
    }
    Err(e) => Err(core_to_cdp_error(e))
  }
}
