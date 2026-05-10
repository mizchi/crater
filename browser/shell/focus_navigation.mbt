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
