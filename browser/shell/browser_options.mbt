///|
/// Enable or disable JavaScript execution
/// JavaScript is disabled by default for security reasons.
/// Use --enable-js flag to enable it.
pub fn Browser::set_enable_js(self : Browser, enable : Bool) -> Unit {
  self.enable_js = enable
}

///|
/// Enable or disable cookie jar.
/// Swaps only the jar on the existing profile, preserving http_cache,
/// user_agent, and auth_state.
pub fn Browser::set_enable_cookies(self : Browser, enable : Bool) -> Unit {
  self.profile.cookie_jar = @http_cookie_jar.CookieJar::new(enabled=enable)
}

///|
pub fn Browser::set_image_cache_max_bytes(
  self : Browser,
  max_bytes : Int,
) -> Unit {
  self.image_cache.set_max_bytes(max_bytes)
}

///|
/// Configure request sandbox policy
pub fn Browser::set_request_sandbox(
  self : Browser,
  sandbox : @http.RequestSandbox,
) -> Unit {
  self.request_sandbox = sandbox
}

///|
/// Get current URL
pub fn Browser::get_dom_tree(self : Browser) -> @dom.DomTree? {
  self.dom_tree
}

///|
pub fn Browser::get_current_url(self : Browser) -> String {
  self.current_url
}

///|
pub fn Browser::get_last_navigation_url(self : Browser) -> String? {
  match self.last_navigation_request {
    Some(request) => Some(request.url)
    None => None
  }
}

///|
/// Get viewport height in pixels
pub fn Browser::get_viewport_height(self : Browser) -> Int {
  self.viewport_height
}

///|
/// Get number of extracted links
pub fn Browser::get_link_count(self : Browser) -> Int {
  self.links.length()
}

///|
/// Get currently focused link index
pub fn Browser::get_focused_link_index(self : Browser) -> Int {
  self.focused_link
}

///|
/// Toggle selection mode (for text copy with mouse)
/// Returns true if selection mode is now enabled, false if disabled
pub fn Browser::toggle_selection_mode(self : Browser) -> Bool {
  self.selection_mode = !self.selection_mode
  self.selection_mode
}

///|
/// Toggle dark mode
pub fn Browser::toggle_dark_mode(self : Browser) -> Unit {
  self.dark_mode = !self.dark_mode
}

///|
/// Set dark mode explicitly
pub fn Browser::set_dark_mode(self : Browser, enabled : Bool) -> Unit {
  self.dark_mode = enabled
}

///|
/// Set no-color mode (disable ANSI color codes)
pub fn Browser::set_no_color(self : Browser, enabled : Bool) -> Unit {
  self.no_color = enabled
}
