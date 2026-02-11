///|
/// CDP Page Domain
///
/// Implements Chrome DevTools Protocol Page domain.
/// Handles page navigation, lifecycle, and content.

///|
/// Page Domain handler
pub struct PageDomain {
  tree : @dom.DomTree
  /// Current URL
  mut current_url : String
  /// Page title
  mut title : String
  /// Frame ID
  frame_id : String
  /// Loader ID (changes on each navigation)
  mut loader_id : Int
  /// Navigation history
  history : Array[CdpNavigationEntry]
  /// Current history index
  mut history_index : Int
}

///|
/// Create new Page domain
pub fn PageDomain::new(tree : @dom.DomTree) -> PageDomain {
  {
    tree,
    current_url: "about:blank",
    title: "",
    frame_id: "main-frame",
    loader_id: 1,
    history: [],
    history_index: -1,
  }
}

// =============================================================================
// Navigation
// =============================================================================

///|
/// Page.navigate - Navigates to URL
/// Note: Actual fetching is done externally, this just updates state
pub fn PageDomain::navigate(
  self : PageDomain,
  url : String,
) -> Result[CdpNavigateResult, CdpError] {
  // Update loader ID
  self.loader_id += 1
  let loader_id = "loader-" + self.loader_id.to_string()
  // Update current URL
  self.current_url = url
  // Add to history
  self.history_index += 1
  // Truncate forward history if any
  while self.history.length() > self.history_index {
    let _ = self.history.pop()
  }
  self.history.push({
    id: self.history_index,
    url,
    title: self.title,
    transition_type: "typed",
  })
  Ok({ frame_id: self.frame_id, loader_id, error_text: None })
}

///|
/// Page.reload - Reloads the current page
pub fn PageDomain::reload(self : PageDomain) -> Result[Unit, CdpError] {
  // Increment loader ID
  self.loader_id += 1
  Ok(())
}

///|
/// Page.goBack - Goes back in history
pub fn PageDomain::go_back(self : PageDomain) -> Result[Bool, CdpError] {
  if self.history_index > 0 {
    self.history_index -= 1
    let entry = self.history[self.history_index]
    self.current_url = entry.url
    self.title = entry.title
    self.loader_id += 1
    Ok(true)
  } else {
    Ok(false)
  }
}

///|
/// Page.goForward - Goes forward in history
pub fn PageDomain::go_forward(self : PageDomain) -> Result[Bool, CdpError] {
  if self.history_index < self.history.length() - 1 {
    self.history_index += 1
    let entry = self.history[self.history_index]
    self.current_url = entry.url
    self.title = entry.title
    self.loader_id += 1
    Ok(true)
  } else {
    Ok(false)
  }
}

///|
/// Page.getNavigationHistory - Returns navigation history
pub fn PageDomain::get_navigation_history(
  self : PageDomain,
) -> Result[CdpNavigationHistory, CdpError] {
  Ok({ current_index: self.history_index, entries: self.history })
}

// =============================================================================
// Frame Info
// =============================================================================

///|
/// Page.getFrameTree - Returns frame tree
pub fn PageDomain::get_frame_tree(
  self : PageDomain,
) -> Result[CdpFrameInfo, CdpError] {
  Ok({
    id: self.frame_id,
    parent_id: None,
    loader_id: "loader-" + self.loader_id.to_string(),
    name: "",
    url: self.current_url,
    security_origin: extract_origin(self.current_url),
    mime_type: "text/html",
  })
}

// =============================================================================
// Content
// =============================================================================

///|
/// Set page title (called when document is loaded)
pub fn PageDomain::set_title(self : PageDomain, title : String) -> Unit {
  self.title = title
  // Update history entry
  if self.history_index >= 0 && self.history_index < self.history.length() {
    self.history[self.history_index] = {
      ..self.history[self.history_index],
      title,
    }
  }
}

///|
/// Get current URL
pub fn PageDomain::get_url(self : PageDomain) -> String {
  self.current_url
}

///|
/// Get page title
pub fn PageDomain::get_title(self : PageDomain) -> String {
  self.title
}

// =============================================================================
// Types
// =============================================================================

///|
/// Navigate result
pub struct CdpNavigateResult {
  frame_id : String
  loader_id : String
  error_text : String?
} derive(Show)

///|
/// Navigation history
pub struct CdpNavigationHistory {
  current_index : Int
  entries : Array[CdpNavigationEntry]
} derive(Show)

// =============================================================================
// Helpers
// =============================================================================

///|
/// Extract origin from URL
fn extract_origin(url : String) -> String {
  // Simple origin extraction
  match url.find("://") {
    Some(i) => {
      let after_protocol = url[i + 3:].to_string() catch { _ => return url }
      match after_protocol.find("/") {
        Some(j) => url[:i + 3 + j].to_string() catch { _ => url }
        None => url
      }
    }
    None => url
  }
}
