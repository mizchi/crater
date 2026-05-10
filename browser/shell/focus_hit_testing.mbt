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
