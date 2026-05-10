///|
/// Browser Shell - TUI browser application layer

///|
/// Enable or disable JavaScript execution
/// JavaScript is disabled by default for security reasons.
/// Use --enable-js flag to enable it.
pub fn Browser::set_enable_js(self : Browser, enable : Bool) -> Unit {
  self.enable_js = enable
}

///|
/// Enable or disable cookie jar.
/// Cookies are disabled by default for security.
pub fn Browser::set_enable_cookies(self : Browser, enable : Bool) -> Unit {
  self.cookie_jar = @http.CookieJar::new(enabled=enable)
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
/// Set HTML content directly (for testing or headless rendering).
pub fn Browser::set_html_content(self : Browser, html : String) -> Unit {
  self.source_html = html
  let has_declarative_shadow_dom = html_source_has_declarative_shadow_dom(html)
  match
    normalize_declarative_shadow_source_html_with_hint(
      html, has_declarative_shadow_dom,
    ) {
    Some(normalized) => {
      self.html_content = normalized.render_html
      self.dom_snapshot_html = normalized.snapshot_html
      self.parsed_doc = Some(normalized.parsed_doc)
      self.html_has_declarative_shadow_dom = false
    }
    None => {
      self.html_content = html
      self.dom_snapshot_html = html
      self.parsed_doc = Some(
        @html.assign_synthetic_ids(@html.parse_document(self.html_content)),
      )
      self.html_has_declarative_shadow_dom = has_declarative_shadow_dom
    }
  }
  self.refresh_links_from_render_source()
  self.focused_link = 0
  self.scroll_y = 0
  self.clear_element_scroll_states()
  self.clear_render_cache()
  self.content_height = 0
  self.a11y_tree = None
  self.focus_manager = None
  self.dom_tree = None
  self.script_executor = None
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
/// Whether hint mode is active
pub fn Browser::is_hint_mode(self : Browser) -> Bool {
  self.hint_mode
}

///|
/// Get maximum scroll position
fn Browser::max_scroll(self : Browser) -> Int {
  (self.content_height - self.viewport_height).max(0)
}

///|
/// Scroll down
pub fn Browser::scroll_down(self : Browser, amount : Int) -> Unit {
  self.scroll_y = (self.scroll_y + amount).min(self.max_scroll())
}

///|
/// Scroll up
pub fn Browser::scroll_up(self : Browser, amount : Int) -> Unit {
  self.scroll_y = (self.scroll_y - amount).max(0)
}

///|
/// Initialize scroll state for an element
/// Call this when a scrollable element is detected
fn Browser::init_element_scroll(
  self : Browser,
  element_id : String,
  scroll_width : Double,
  scroll_height : Double,
  client_width : Double,
  client_height : Double,
) -> Unit {
  let state = @dom.ScrollState::new(
    scroll_width, scroll_height, client_width, client_height,
  )
  self.element_scroll_states.set(element_id, state)
}

///|
/// Clear all element scroll states (call on page navigation)
fn Browser::clear_element_scroll_states(self : Browser) -> Unit {
  self.element_scroll_states.clear()
  self.focused_scrollable.val = None
}

///|
/// Initialize scroll states from detected scrollable elements
/// Called during render to set up scroll states for elements with overflow
fn Browser::init_scrollable_elements(
  self : Browser,
  elements : Array[@tui_paint_runtime.ScrollableElement],
) -> Unit {
  for elem in elements {
    // Only initialize if not already tracked (preserve scroll position)
    if !self.element_scroll_states.contains(elem.id) {
      self.init_element_scroll(
        elem.id,
        elem.scroll_width,
        elem.scroll_height,
        elem.client_width,
        elem.client_height,
      )
    }
  }
}

///|
/// Convert element scroll states to TUI format for rendering
fn Browser::get_element_scroll_positions(
  self : Browser,
) -> Map[String, @tui.ElementScrollPos] {
  let result : Map[String, @tui.ElementScrollPos] = {}
  self.element_scroll_states.each(fn(id, state) {
    result.set(id, {
      scroll_top: state.scroll_top,
      scroll_height: state.scroll_height,
      client_height: state.client_height,
    })
  })
  result
}

///|
fn Browser::is_bounds_visible(self : Browser, bounds : @aom.Bounds?) -> Bool {
  match bounds {
    Some(b) => {
      let view_left = 0.0
      let view_right = self.viewport_width.to_double()
      let view_top = self.scroll_y.to_double()
      let view_bottom = view_top + self.viewport_height.to_double()
      b.x + b.width > view_left &&
      b.x < view_right &&
      b.y + b.height > view_top &&
      b.y < view_bottom
    }
    None => false
  }
}

///|
fn Browser::is_focus_node_visible(
  self : Browser,
  node : @aom.AccessibilityNode,
) -> Bool {
  self.is_bounds_visible(node.bounds)
}

///|
/// Focus next visible focusable element (Tab)
pub fn Browser::next_link(self : Browser) -> Unit {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) => {
      let count = fm.focusable_count()
      if count == 0 {
        return
      }
      let previous_source_id = match fm.current() {
        Some(node) => node.source_id
        None => None
      }
      for attempt = 0; attempt < count; attempt = attempt + 1 {
        let _ = fm.focus_next()
        match fm.current() {
          Some(node) =>
            if self.is_focus_node_visible(node) {
              self.dispatch_focus_transition(previous_source_id, node.source_id)
              return
            }
          None => return
        }
      }
    }
    None =>
      // Fallback to legacy link navigation
      if self.links.length() > 0 {
        self.focused_link = (self.focused_link + 1) % self.links.length()
      }
  }
}

///|
/// Focus previous visible focusable element (Shift+Tab)
pub fn Browser::prev_link(self : Browser) -> Unit {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) => {
      let count = fm.focusable_count()
      if count == 0 {
        return
      }
      let previous_source_id = match fm.current() {
        Some(node) => node.source_id
        None => None
      }
      for attempt = 0; attempt < count; attempt = attempt + 1 {
        let _ = fm.focus_prev()
        match fm.current() {
          Some(node) =>
            if self.is_focus_node_visible(node) {
              self.dispatch_focus_transition(previous_source_id, node.source_id)
              return
            }
          None => return
        }
      }
    }
    None =>
      // Fallback to legacy link navigation
      if self.links.length() > 0 {
        self.focused_link = (self.focused_link - 1 + self.links.length()) %
          self.links.length()
      }
  }
}

///|
fn Browser::ensure_declarative_shadow_dom_normalized(self : Browser) -> Unit {
  match self.dom_tree {
    Some(_) => return
    None => ()
  }
  if !self.html_has_declarative_shadow_dom {
    return
  }
  match build_dom_tree_from_source_html(self.html_content) {
    Some(dom) => {
      self.dom_tree = Some(dom)
      let _ = self.sync_render_state_from_dom_tree()
    }
    None => ()
  }
}

///|
/// Build accessibility tree from current HTML content
fn Browser::build_accessibility_tree(self : Browser) -> Unit {
  self.ensure_declarative_shadow_dom_normalized()
  let previous_focus_source_id = match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) => node.source_id
        None => None
      }
    None => None
  }
  // Use cached parsed document if available
  let doc = match self.parsed_doc {
    Some(d) => d
    None => {
      if self.html_content.length() == 0 {
        self.a11y_tree = None
        self.focus_manager = None
        return
      }
      // Fallback: parse if not cached (shouldn't happen in normal flow)
      let d = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(d)
      d
    }
  }
  // Use the renderer's layout which applies CSS properly
  let ctx = @browser_contract.create_render_context(
    self.viewport_width,
    self.viewport_height,
    false,
  )
  // Render with CSS to get proper layout bounds
  // Use the document with synthetic IDs for consistent ID matching
  let (_, layout) = self.render_node_and_layout_from_document(doc, ctx, false)
  // Build accessibility tree with renderer's layout bounds
  let tree = @aom.build_accessibility_tree_with_node_layout(doc, layout)
  self.a11y_tree = Some(tree)
  // Create focus manager
  self.focus_manager = Some(@aom.FocusManager::new(tree))
  match (self.focus_manager, previous_focus_source_id) {
    (Some(fm), Some(source_id)) => {
      let _ = fm.focus_by_source_id(source_id)
    }
    _ => ()
  }
}

///|
/// Build lightweight accessibility tree (no CSS cascade, no layout)
/// Used for --json and --aom modes to reduce memory usage
fn Browser::build_accessibility_tree_lightweight(self : Browser) -> Unit {
  self.ensure_declarative_shadow_dom_normalized()
  // Use cached parsed document if available
  let doc = match self.parsed_doc {
    Some(d) => d
    None => {
      if self.html_content.length() == 0 {
        self.a11y_tree = None
        self.focus_manager = None
        return
      }
      // Parse with regular parser
      let d = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(d)
      d
    }
  }
  // Build lightweight accessibility tree (skips CSS cascade and layout)
  let tree = @aom.build_accessibility_tree_lightweight(doc)
  self.a11y_tree = Some(tree)
  // No focus manager needed for JSON/AOM output
  self.focus_manager = None
}

///|
/// Get the accessible name of the currently focused element
/// Used for :focus styling in TUI rendering
fn Browser::get_focused_element_name(self : Browser) -> String? {
  match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) => node.name
        None => None
      }
    None => None
  }
}

///|
/// Get currently focused link URL
pub fn Browser::get_focused_link_url(self : Browser) -> String? {
  // Try to get URL from FocusManager first
  match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) =>
          match node.role {
            @aom.Link =>
              match node.source_id {
                Some(source_id) =>
                  match self.get_link_href_for_source_id(source_id) {
                    Some(href) => Some(resolve_url(self.current_url, href))
                    None =>
                      match node.name {
                        Some(name) => {
                          for link in self.links {
                            if link.text == name {
                              return Some(
                                resolve_url(self.current_url, link.href),
                              )
                            }
                          }
                          None
                        }
                        None => None
                      }
                  }
                None =>
                  match node.name {
                    Some(name) => {
                      for link in self.links {
                        if link.text == name {
                          return Some(resolve_url(self.current_url, link.href))
                        }
                      }
                      None
                    }
                    None => None
                  }
              }
            _ => None
          }
        None => None
      }
    None =>
      // Fallback to legacy
      if self.links.length() > 0 && self.focused_link < self.links.length() {
        Some(self.links[self.focused_link].href)
      } else {
        None
      }
  }
}

///|
fn Browser::get_focused_source_id(self : Browser) -> String? {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) => node.source_id
        None =>
          match self.a11y_tree {
            Some(tree) => {
              let mut link_index = 0
              for node in tree.find_focusable() {
                if node.role == @aom.Link {
                  if link_index == self.focused_link {
                    return node.source_id
                  }
                  link_index = link_index + 1
                }
              }
              None
            }
            None => None
          }
      }
    None =>
      match self.a11y_tree {
        Some(tree) => {
          let mut link_index = 0
          for node in tree.find_focusable() {
            if node.role == @aom.Link {
              if link_index == self.focused_link {
                return node.source_id
              }
              link_index = link_index + 1
            }
          }
          None
        }
        None => None
      }
  }
}

///|
fn Browser::get_link_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  for i = self.link_regions.length() - 1; i >= 0; i = i - 1 {
    let region = self.link_regions[i]
    if region.contains(col, row) {
      return Some(region.source_id)
    }
  }
  None
}

///|
fn Browser::get_extracted_link_href_for_source_id(
  self : Browser,
  source_id : String,
) -> String? {
  for link in self.links {
    if link.source_id == source_id {
      return Some(link.href)
    }
  }
  None
}

///|
fn Browser::get_a11y_link_href_for_source_id(
  self : Browser,
  source_id : String,
) -> String? {
  if self.a11y_tree is None {
    self.build_accessibility_tree()
  }
  match self.a11y_tree {
    Some(tree) =>
      match tree.find_by_source_id(source_id) {
        Some(node) => node.href
        None => None
      }
    None => None
  }
}

///|
fn Browser::get_link_href_for_source_id(
  self : Browser,
  source_id : String,
) -> String? {
  match self.get_href_for_source_id(source_id) {
    Some(href) => Some(href)
    None =>
      match self.get_a11y_link_href_for_source_id(source_id) {
        Some(href) => Some(href)
        None => self.get_extracted_link_href_for_source_id(source_id)
      }
  }
}

///|
fn Browser::get_link_href_for_region(
  self : Browser,
  region : @tui.LinkRegion,
) -> String? {
  match self.get_link_href_for_source_id(region.source_id) {
    Some(href) => Some(href)
    None => {
      for link in self.links {
        if region.text == link.text {
          return Some(link.href)
        }
      }
      None
    }
  }
}

///|
fn Browser::is_clickable_source_id(self : Browser, source_id : String) -> Bool {
  match self.get_href_for_source_id(source_id) {
    Some(href) if href.length() > 0 => true
    _ => {
      if !self.enable_js {
        return false
      }
      let escaped = escape_js_string(source_id)
      let source = "(function(){const target=document.getElementById('" +
        escaped +
        "');if(!target){return false;}if(target.hasAttribute&&(target.hasAttribute('onclick')||target.hasAttribute('data-crater-listeners-click'))){return true;}const tag=(target.tagName||'').toLowerCase();if(tag==='button'||tag==='input'||tag==='select'||tag==='textarea'||tag==='summary'){return true;}const role=target.getAttribute?target.getAttribute('role'):null;return role==='button'||role==='link';})()"
      match self.execute_inline_js(source) {
        Some("true") => true
        _ => false
      }
    }
  }
}

///|
fn Browser::get_paint_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  if self.hit_regions.is_empty() {
    return None
  }
  let mut i = self.hit_regions.length() - 1
  while i >= 0 {
    let region = self.hit_regions[i]
    if region.contains(col, row) &&
      self.is_clickable_source_id(region.source_id) {
      return Some(region.source_id)
    }
    i = i - 1
  }
  None
}

///|
fn Browser::get_any_paint_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  match @tui.find_hit_region_at(self.hit_regions, col, row) {
    Some(region) => Some(region.source_id)
    None => None
  }
}

///|
fn bounds_contains_click(
  bounds : @aom.Bounds,
  px_x : Double,
  px_y : Double,
) -> Bool {
  px_x >= bounds.x &&
  px_x < bounds.x + bounds.width &&
  px_y >= bounds.y &&
  px_y < bounds.y + bounds.height
}

///|
fn find_smallest_a11y_hit_target(
  node : @aom.AccessibilityNode,
  px_x : Double,
  px_y : Double,
  current_best : HitTarget?,
) -> HitTarget? {
  let mut best = current_best
  match (node.source_id, node.bounds) {
    (Some(source_id), Some(bounds)) =>
      if bounds.width > 0.0 &&
        bounds.height > 0.0 &&
        bounds_contains_click(bounds, px_x, px_y) {
        let area = bounds.width * bounds.height
        match best {
          Some(existing) =>
            if area < existing.area {
              best = Some({ source_id, area })
            }
          None => best = Some({ source_id, area })
        }
      }
    _ => ()
  }
  for child in node.children {
    best = find_smallest_a11y_hit_target(child, px_x, px_y, best)
  }
  best
}

///|
fn Browser::get_a11y_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  if row <= 0 {
    return None
  }
  if self.a11y_tree is None {
    self.build_accessibility_tree()
  }
  let px_x = col.to_double() * 8.0 + 4.0
  let px_y = (row - 1 + self.scroll_y).to_double() * 16.0 + 8.0
  match self.a11y_tree {
    Some(tree) =>
      match find_smallest_a11y_hit_target(tree.root, px_x, px_y, None) {
        Some(target) => Some(target.source_id)
        None => None
      }
    None => None
  }
}

///|
fn Browser::get_source_id_at(self : Browser, col : Int, row : Int) -> String? {
  match self.get_link_source_id_at(col, row) {
    Some(source_id) => Some(source_id)
    None =>
      match self.get_paint_source_id_at(col, row) {
        Some(source_id) => Some(source_id)
        None => self.get_a11y_source_id_at(col, row)
      }
  }
}

///|
fn Browser::get_hover_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  match self.get_link_source_id_at(col, row) {
    Some(source_id) => Some(source_id)
    None =>
      match self.get_any_paint_source_id_at(col, row) {
        Some(source_id) => Some(source_id)
        None => self.get_a11y_source_id_at(col, row)
      }
  }
}

///|
fn Browser::focus_source_id(self : Browser, source_id : String) -> Unit {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) => {
      let previous_source_id = match fm.current() {
        Some(node) => node.source_id
        None => None
      }
      let _ = fm.focus_by_source_id(source_id)
      self.dispatch_focus_transition(previous_source_id, Some(source_id))
    }
    None => ()
  }
}

///|
fn Browser::get_href_for_source_id(
  self : Browser,
  source_id : String,
) -> String? {
  let escaped = escape_js_string(source_id)
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target||typeof target.getAttribute!=='function'){return '';}const href=target.getAttribute('href');return typeof href==='string'?href:'';})()"
  match self.execute_inline_js(source) {
    Some(href) if href.length() > 0 => Some(href)
    _ => None
  }
}

///|
/// Get number of visible focusable elements currently on screen
fn Browser::get_visible_focusable_count(self : Browser) -> Int {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) => {
      let mut count = 0
      for item in fm.get_tab_order() {
        if self.is_focus_node_visible(item.node) {
          count += 1
        }
      }
      count
    }
    None => self.link_regions.length()
  }
}

///|
/// Get current focus index among visible focusable elements (-1 if not visible)
fn Browser::get_visible_focus_index(self : Browser) -> Int {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) => {
          let focused_source_id = node.source_id
          let mut visible_index = 0
          for item in fm.get_tab_order() {
            if self.is_focus_node_visible(item.node) {
              if item.node.source_id == focused_source_id {
                return visible_index
              }
              visible_index += 1
            }
          }
          -1
        }
        None => -1
      }
    None => -1
  }
}

///|
/// Find link URL at screen coordinates (for mouse click)
/// Returns the resolved absolute URL if a link is found
pub fn Browser::get_link_at(self : Browser, col : Int, row : Int) -> String? {
  match self.get_link_source_id_at(col, row) {
    Some(source_id) =>
      match self.get_link_href_for_source_id(source_id) {
        Some(href) => Some(href)
        None =>
          match @tui.find_link_at(self.link_regions, col, row) {
            Some(link_text) => {
              for link in self.links {
                if link.text == link_text {
                  return Some(link.href)
                }
              }
              None
            }
            None => None
          }
      }
    None => None
  }
}

///|
fn cell_to_client_x(col : Int) -> Int {
  col * 8 + 4
}

///|
fn cell_to_client_y(row : Int) -> Int {
  let viewport_row = if row > 0 { row } else { 0 }
  viewport_row * 16 + 8
}

///|
fn Browser::get_client_coords_for_source_id(
  self : Browser,
  source_id : String,
) -> (Int, Int)? {
  if self.hit_regions.is_empty() {
    return None
  }
  let mut i = self.hit_regions.length() - 1
  while i >= 0 {
    let region = self.hit_regions[i]
    if region.source_id == source_id {
      let center_col = region.col + region.width / 2
      let center_row = region.row + region.height / 2
      return Some((cell_to_client_x(center_col), cell_to_client_y(center_row)))
    }
    i = i - 1
  }
  None
}

///|
fn Browser::get_hit_region_for_source_id(
  self : Browser,
  source_id : String,
) -> @tui.HitRegion? {
  if self.hit_regions.is_empty() {
    return None
  }
  let mut i = self.hit_regions.length() - 1
  while i >= 0 {
    let region = self.hit_regions[i]
    if region.source_id == source_id {
      return Some(region)
    }
    i = i - 1
  }
  None
}

///|
pub async fn Browser::handle_focused_key(
  self : Browser,
  key : String,
) -> Bool raise @http.HttpError {
  let source_id = self.get_focused_source_id()
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      match self.dispatch_focused_key_to_source_id(id, key) {
        Handled => true
        Activate => self.activate_focused_link()
        Submit =>
          match self.dispatch_submit_to_source_id(id) {
            Prevented => true
            Handled => true
            Navigate(request) => {
              let resolved_request = {
                ..request,
                url: resolve_url(self.current_url, request.url),
              }
              let _ = self.navigate_request(resolved_request)
              true
            }
            NotSubmittable => true
          }
        NotHandled => false
      }
    }
    None => false
  }
}

///|
pub async fn Browser::activate_focused_link(
  self : Browser,
) -> Bool raise @http.HttpError {
  let source_id = self.get_focused_source_id()
  let href = self.get_focused_link_url()
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      let (client_x, client_y) = match
        self.get_client_coords_for_source_id(id) {
        Some(coords) => coords
        None => (0, 0)
      }
      let dispatch = self.dispatch_click_to_source_id(id, client_x~, client_y~)
      if !dispatch.allow_default {
        return true
      }
      if self.dispatch_activation_default_to_source_id(id) {
        return true
      }
      match self.dispatch_submit_to_source_id(id, client_x~, client_y~) {
        Prevented => return true
        Handled => return true
        Navigate(request) => {
          let resolved_request = {
            ..request,
            url: resolve_url(self.current_url, request.url),
          }
          let _ = self.navigate_request(resolved_request)
          return true
        }
        NotSubmittable => ()
      }
      if href is None && dispatch.handled {
        return true
      }
    }
    None => ()
  }
  match href {
    Some(url) if url.length() > 0 => {
      let _ = self.navigate(url)
      true
    }
    _ => false
  }
}

///|
pub fn Browser::hover_at(self : Browser, col : Int, row : Int) -> Bool {
  let next_source_id = self.get_hover_source_id_at(col, row)
  let changed = self.dispatch_hover_transition(
    self.hovered_source_id,
    next_source_id,
    cell_to_client_x(col),
    cell_to_client_y(row),
  )
  self.hovered_source_id = next_source_id
  changed
}

///|
pub fn Browser::pointer_down_at(self : Browser, col : Int, row : Int) -> Bool {
  let source_id = self.get_hover_source_id_at(col, row)
  self.hovered_source_id = source_id
  self.dragging_source_id = None
  self.drag_over_source_id = None
  self.drop_allowed_source_id = None
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      if self.set_text_control_caret_from_cell(id, col, row) {
        self.text_selection_anchor_source_id = Some(id)
        self.text_selection_anchor_col = col
        self.text_selection_anchor_row = row
      } else {
        self.text_selection_anchor_source_id = None
      }
      self.pressed_source_id = Some(id)
      self.dispatch_pointer_mouse_event_to_source_id(
        id,
        "pointerdown",
        "mousedown",
        cell_to_client_x(col),
        cell_to_client_y(row),
      )
    }
    None => {
      self.pressed_source_id = None
      self.text_selection_anchor_source_id = None
      false
    }
  }
}

///|
pub fn Browser::pointer_move_at(self : Browser, col : Int, row : Int) -> Bool {
  let client_x = cell_to_client_x(col)
  let client_y = cell_to_client_y(row)
  let mut changed = self.hover_at(col, row)
  match self.pressed_source_id {
    Some(pressed_id) => {
      match self.text_selection_anchor_source_id {
        Some(anchor_source_id) if anchor_source_id == pressed_id &&
          self.dragging_source_id is None =>
          if self.set_text_control_selection_from_cells(
              pressed_id,
              self.text_selection_anchor_col,
              self.text_selection_anchor_row,
              col,
              row,
            ) {
            changed = true
          }
        _ => ()
      }
      if self.dragging_source_id is None &&
        self.is_draggable_source_id(pressed_id) {
        if self.dispatch_drag_event_to_source_id(
            pressed_id,
            "dragstart",
            client_x,
            client_y,
            related_source_id=None,
          ) {
          self.dragging_source_id = Some(pressed_id)
          changed = true
        }
      }
      match self.dragging_source_id {
        Some(drag_id) => {
          let plan = @interaction_policy.drag_move_target_plan(
            drag_id,
            self.drag_over_source_id.unwrap_or(""),
            self.get_hover_source_id_at(col, row).unwrap_or(""),
          )
          let next_target = if plan.over_target != "" {
            Some(plan.over_target)
          } else {
            None
          }
          if self.dispatch_drag_event_to_source_id(
              drag_id,
              "drag",
              client_x,
              client_y,
              related_source_id=next_target,
            ) {
            changed = true
          }
          if self.drag_over_source_id != next_target {
            self.drop_allowed_source_id = None
            match self.drag_over_source_id {
              Some(previous_target) if plan.emit_dragleave =>
                if self.dispatch_drag_event_to_source_id(
                    previous_target,
                    "dragleave",
                    client_x,
                    client_y,
                    related_source_id=next_target,
                  ) {
                  changed = true
                }
              _ => ()
            }
            match next_target {
              Some(next_id) if plan.emit_dragenter =>
                if self.dispatch_drag_event_to_source_id(
                    next_id,
                    "dragenter",
                    client_x,
                    client_y,
                    related_source_id=self.drag_over_source_id,
                  ) {
                  changed = true
                }
              _ => ()
            }
            self.drag_over_source_id = next_target
          }
          match self.drag_over_source_id {
            Some(target_id) if plan.emit_dragover => {
              let (handled_drag_over, canceled_drag_over) = self.dispatch_drag_event_status_to_source_id(
                target_id,
                "dragover",
                client_x,
                client_y,
                related_source_id=Some(drag_id),
              )
              if handled_drag_over {
                changed = true
              }
              let accepted_target = @interaction_policy.drag_accept_target(
                drag_id, target_id, canceled_drag_over,
              )
              self.drop_allowed_source_id = if accepted_target != "" {
                Some(accepted_target)
              } else {
                None
              }
            }
            _ => ()
          }
        }
        None => ()
      }
      changed
    }
    None => changed
  }
}

///|
pub async fn Browser::pointer_up_at(
  self : Browser,
  col : Int,
  row : Int,
) -> Bool raise @http.HttpError {
  let client_x = cell_to_client_x(col)
  let client_y = cell_to_client_y(row)
  let up_source_id = self.get_hover_source_id_at(col, row)
  let pressed_source_id = self.pressed_source_id
  let dragging_source_id = self.dragging_source_id
  let drag_over_source_id = self.drag_over_source_id
  let drop_allowed_source_id = self.drop_allowed_source_id
  let mut handled = false
  match up_source_id {
    Some(id) =>
      if self.dispatch_pointer_mouse_event_to_source_id(
          id, "pointerup", "mouseup", client_x, client_y,
        ) {
        handled = true
      }
    None => ()
  }
  self.pressed_source_id = None
  self.text_selection_anchor_source_id = None
  self.dragging_source_id = None
  self.drag_over_source_id = None
  self.drop_allowed_source_id = None
  match dragging_source_id {
    Some(drag_id) => {
      let drop_target = @interaction_policy.drag_drop_target(
        drag_id,
        drag_over_source_id.unwrap_or(""),
        drop_allowed_source_id.unwrap_or(""),
      )
      match drag_over_source_id {
        Some(target_id) if drop_target == target_id &&
          self.is_current_drop_allowed() =>
          if self.dispatch_drag_event_to_source_id(
              target_id,
              "drop",
              client_x,
              client_y,
              related_source_id=Some(drag_id),
            ) {
            handled = true
          }
        _ => ()
      }
      if self.dispatch_drag_event_to_source_id(
          drag_id,
          "dragend",
          client_x,
          client_y,
          related_source_id=drag_over_source_id,
        ) {
        handled = true
      }
      return handled
    }
    None => ()
  }
  match (pressed_source_id, up_source_id) {
    (Some(down_id), Some(up_id)) if down_id == up_id => {
      let dispatch = self.dispatch_click_only_to_source_id(
        down_id, client_x, client_y,
      )
      if !dispatch.allow_default {
        return true
      }
      if self.dispatch_activation_default_to_source_id(down_id) {
        return true
      }
      match self.dispatch_submit_to_source_id(down_id, client_x~, client_y~) {
        Prevented => return true
        Handled => return true
        Navigate(request) => {
          let resolved_request = {
            ..request,
            url: resolve_url(self.current_url, request.url),
          }
          let _ = self.navigate_request(resolved_request)
          return true
        }
        NotSubmittable => ()
      }
      match self.get_href_for_source_id(down_id) {
        Some(url) if url.length() > 0 => {
          let _ = self.navigate(resolve_url(self.current_url, url))
          true
        }
        _ => handled || dispatch.handled
      }
    }
    _ => handled
  }
}

///|
pub async fn Browser::activate_at(
  self : Browser,
  col : Int,
  row : Int,
) -> Bool raise @http.HttpError {
  let source_id = self.get_source_id_at(col, row)
  let href = match self.get_link_at(col, row) {
    Some(url) => Some(resolve_url(self.current_url, url))
    None =>
      match source_id {
        Some(id) => self.get_href_for_source_id(id)
        None => None
      }
  }
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      let _ = self.set_text_control_caret_from_cell(id, col, row)
      let dispatch = self.dispatch_click_to_source_id(
        id,
        client_x=cell_to_client_x(col),
        client_y=cell_to_client_y(row),
      )
      if !dispatch.allow_default {
        return true
      }
      if self.dispatch_activation_default_to_source_id(id) {
        return true
      }
      match
        self.dispatch_submit_to_source_id(
          id,
          client_x=cell_to_client_x(col),
          client_y=cell_to_client_y(row),
        ) {
        Prevented => return true
        Handled => return true
        Navigate(request) => {
          let resolved_request = {
            ..request,
            url: resolve_url(self.current_url, request.url),
          }
          let _ = self.navigate_request(resolved_request)
          return true
        }
        NotSubmittable => ()
      }
      match href {
        Some(url) if url.length() > 0 => {
          let _ = self.navigate(url)
          true
        }
        _ => dispatch.handled
      }
    }
    None =>
      match href {
        Some(url) if url.length() > 0 => {
          let _ = self.navigate(url)
          true
        }
        _ => false
      }
  }
}

///|
pub async fn Browser::activate_link_at(
  self : Browser,
  col : Int,
  row : Int,
) -> Bool raise @http.HttpError {
  self.activate_at(col, row)
}

///|
/// Debug: print layout tree
pub fn Browser::debug_layout(self : Browser) -> Unit {
  if self.html_content.length() == 0 {
    println("No content loaded")
    return
  }
  let ctx = @browser_contract.create_render_context(
    self.viewport_width,
    self.viewport_height,
    false,
  )
  let layout = match self.parsed_doc {
    Some(doc) => self.render_node_and_layout_from_document(doc, ctx, false).1
    None =>
      @renderer.render_with_external_css(
        self.html_content,
        ctx,
        self.external_css,
      )
  }
  println("=== Layout Tree ===")
  @renderer.print_layout_tree_with_options(layout, 0, true)
  println("===================")
  println("Total content height: " + layout.height.to_string())
}

///|
/// Render accessibility tree as JSON (for AI scraping)
fn Browser::render_json(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) => tree.to_aria_json()
    None => "{}"
  }
}

///|
/// Render accessibility tree as YAML (Playwright-compatible)
fn Browser::render_aom(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) => tree.to_aria_snapshot()
    None => ""
  }
}

///|
/// Run Arc90 content extraction and return result
fn Browser::render_arc90(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) =>
      @browser_contract.render_arc90_summary(
        tree,
        self.viewport_width,
        self.viewport_height,
      )
    None => "No accessibility tree available."
  }
}

///|
/// Extract main content text using Arc90 algorithm
fn Browser::render_extract_main(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) =>
      @browser_contract.extract_main_text(
        tree,
        self.viewport_width,
        self.viewport_height,
      )
    None => "No accessibility tree available."
  }
}

///|
/// Run visual grounding demo and return results
fn Browser::render_grounding(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) =>
      @browser_contract.render_grounding_demo(
        tree,
        self.viewport_width,
        self.viewport_height,
      )
    None => "No accessibility tree available."
  }
}

///|
/// Get character at index from string (returns '\0' if out of bounds)
fn char_at(s : String, i : Int) -> Char {
  if i < 0 || i >= s.length() {
    '\u0000'
  } else {
    s[i].to_int().unsafe_to_char()
  }
}

///|
/// Extract links from HTML content (portable fallback version)
#cfg(not(target="js"))
fn extract_links_fallback(html : String) -> Array[Link] {
  let links : Array[Link] = []
  let len = html.length()
  let mut i = 0
  while i < len {
    // Look for <a
    if i + 2 < len &&
      char_at(html, i) == '<' &&
      (char_at(html, i + 1) == 'a' || char_at(html, i + 1) == 'A') &&
      (char_at(html, i + 2) == ' ' || char_at(html, i + 2) == '\t') {
      // Find href="
      let mut j = i + 2
      let mut href = ""
      let mut source_id = ""
      while j < len && char_at(html, j) != '>' {
        if j + 6 < len &&
          (char_at(html, j) == 'h' || char_at(html, j) == 'H') &&
          (char_at(html, j + 1) == 'r' || char_at(html, j + 1) == 'R') &&
          (char_at(html, j + 2) == 'e' || char_at(html, j + 2) == 'E') &&
          (char_at(html, j + 3) == 'f' || char_at(html, j + 3) == 'F') &&
          char_at(html, j + 4) == '=' {
          let quote = char_at(html, j + 5)
          if quote == '"' || quote == '\'' {
            let mut k = j + 6
            while k < len && char_at(html, k) != quote {
              k = k + 1
            }
            href = html.unsafe_substring(start=j + 6, end=k)
          }
        } else if j + 4 < len &&
          (char_at(html, j) == 'i' || char_at(html, j) == 'I') &&
          (char_at(html, j + 1) == 'd' || char_at(html, j + 1) == 'D') &&
          char_at(html, j + 2) == '=' {
          let quote = char_at(html, j + 3)
          if quote == '"' || quote == '\'' {
            let mut k = j + 4
            while k < len && char_at(html, k) != quote {
              k = k + 1
            }
            source_id = html.unsafe_substring(start=j + 4, end=k)
          }
        }
        j = j + 1
      }
      // Find link text (between > and </a>)
      if j < len && char_at(html, j) == '>' {
        let text_start = j + 1
        let mut text_end = text_start
        while text_end + 3 < len {
          if char_at(html, text_end) == '<' &&
            char_at(html, text_end + 1) == '/' &&
            (
              char_at(html, text_end + 2) == 'a' ||
              char_at(html, text_end + 2) == 'A'
            ) {
            break
          }
          text_end = text_end + 1
        }
        let text = html
          .unsafe_substring(start=text_start, end=text_end)
          .trim()
          .to_string()
        if href.length() > 0 {
          links.push({ href, text, source_id })
        }
        i = text_end
      }
    }
    i = i + 1
  }
  links
}

///|
#cfg(target="js")
extern "js" fn extract_links_js(html : String) -> Array[Link] =
  #| (html) => {
  #|   const links = [];
  #|   const anchorRe = /<a\b([^>]*)>([\s\S]*?)<\/a\s*>/gi;
  #|   const readAttr = (attrs, name) => {
  #|     const re = new RegExp(
  #|       "\\b" + name + "\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))",
  #|       "i",
  #|     );
  #|     const match = re.exec(attrs);
  #|     return match ? String(match[1] ?? match[2] ?? match[3] ?? "") : "";
  #|   };
  #|   let match;
  #|   while ((match = anchorRe.exec(html)) !== null) {
  #|     const attrs = String(match[1] ?? "");
  #|     const href = readAttr(attrs, "href");
  #|     if (!href) continue;
  #|     links.push({
  #|       href,
  #|       text: String(match[2] ?? "").trim(),
  #|       source_id: readAttr(attrs, "id"),
  #|     });
  #|   }
  #|   return links;
  #| }

///|
#cfg(target="js")
fn extract_links(html : String) -> Array[Link] {
  extract_links_js(html)
}

///|
#cfg(not(target="js"))
fn extract_links(html : String) -> Array[Link] {
  extract_links_fallback(html)
}

///|
/// Enter hint mode - generate hints for visible links only
pub fn Browser::enter_hint_mode(self : Browser) -> Unit {
  if self.link_regions.length() == 0 {
    return // No visible links to hint
  }
  self.hint_mode = true
  self.hint_input = ""
  // Generate hints from visible link regions only
  self.hints = []
  let mut label_idx = 0
  for region in self.link_regions {
    match self.get_link_href_for_region(region) {
      Some(link_href) => {
        let href = resolve_url(self.current_url, link_href)
        if href.length() == 0 {
          continue
        }
        self.hints.push({
          label: generate_single_label(label_idx),
          href,
          text: region.text,
          col: region.col,
          row: region.row,
        })
        label_idx = label_idx + 1
      }
      None => ()
    }
  }
}

///|
/// Generate a single hint label for index
fn generate_single_label(idx : Int) -> String {
  if idx < 26 {
    // a-z
    (97 + idx).unsafe_to_char().to_string()
  } else {
    // aa, ab, ac, ...
    let first = 97 + idx / 26
    let second = 97 + idx % 26
    first.unsafe_to_char().to_string() + second.unsafe_to_char().to_string()
  }
}

///|
/// Exit hint mode
pub fn Browser::exit_hint_mode(self : Browser) -> Unit {
  self.hint_mode = false
  self.hints = []
  self.hint_input = ""
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

///|
/// Process hint character input
/// Returns Some(url) if a hint is matched, None otherwise
pub fn Browser::process_hint_char(self : Browser, char : String) -> String? {
  self.hint_input = self.hint_input + char
  // Check for exact match
  for hint in self.hints {
    if hint.label == self.hint_input {
      let href = hint.href
      self.exit_hint_mode()
      return Some(href)
    }
  }
  // Check if any hints start with current input
  let mut has_prefix_match = false
  for hint in self.hints {
    if hint.label.has_prefix(self.hint_input) {
      has_prefix_match = true
      break
    }
  }
  // If no prefix matches, exit hint mode
  if !has_prefix_match {
    self.exit_hint_mode()
  }
  None
}
