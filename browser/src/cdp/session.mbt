///|
/// CDP Session
///
/// A CDP session combines all domains and provides
/// the unified interface for protocol operations.

///|
/// CDP Session - combines all domains
pub struct CdpSession {
  /// Shared DOM tree
  tree : @dom.DomTree
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
  let tree = @dom.DomTree::new()
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
pub fn CdpSession::get_tree(self : CdpSession) -> @dom.DomTree {
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
/// Load HTML content into the DOM tree
pub fn CdpSession::load_html(self : CdpSession, html : String) -> Unit {
  let doc = self.tree.get_document()
  // Clear existing children
  match self.tree.get_children(doc) {
    Ok(children) =>
      for child in children {
        let _ = self.tree.remove_child(doc, child)

      }
    Err(_) => ()
  }
  // Create html > body structure
  let html_elem = self.tree.create_element("html")
  let body = self.tree.create_element("body")
  let _ = self.tree.append_child(doc, html_elem)
  let _ = self.tree.append_child(html_elem, body)
  // Parse content into body
  parse_html_into(self.tree, body, html)
}

///|
/// Parse HTML content into a parent node
fn parse_html_into(
  tree : @dom.DomTree,
  parent : @dom.NodeId,
  html : String,
) -> Unit {
  let chars = html.to_array()
  let len = chars.length()
  let i = Ref::new(0)
  while i.val < len {
    if chars[i.val] == '<' {
      // Check for closing tag
      if i.val + 1 < len && chars[i.val + 1] == '/' {
        // Skip closing tag
        while i.val < len && chars[i.val] != '>' {
          i.val += 1
        }
        i.val += 1
        continue
      }
      // Parse opening tag
      i.val += 1
      let tag_start = i.val
      while i.val < len && chars[i.val] != ' ' && chars[i.val] != '>' {
        i.val += 1
      }
      let tag_name = make_substring(chars, tag_start, i.val)
      let elem = tree.create_element(tag_name)
      let _ = tree.append_child(parent, elem)
      // Parse attributes
      while i.val < len && chars[i.val] != '>' {
        // Skip whitespace
        while i.val < len && chars[i.val] == ' ' {
          i.val += 1
        }
        if i.val < len && chars[i.val] != '>' {
          // Parse attribute name
          let attr_start = i.val
          while i.val < len &&
                chars[i.val] != '=' &&
                chars[i.val] != ' ' &&
                chars[i.val] != '>' {
            i.val += 1
          }
          let attr_name = make_substring(chars, attr_start, i.val)
          if i.val < len && chars[i.val] == '=' {
            i.val += 1
            // Skip quote
            if i.val < len && chars[i.val] == '"' {
              i.val += 1
            }
            let val_start = i.val
            while i.val < len && chars[i.val] != '"' {
              i.val += 1
            }
            let attr_val = make_substring(chars, val_start, i.val)
            if i.val < len && chars[i.val] == '"' {
              i.val += 1
            }
            let _ = tree.set_attribute(elem, attr_name, attr_val)

          }
        }
      }
      if i.val < len && chars[i.val] == '>' {
        i.val += 1
      }
      // Parse children (recursively find content until closing tag)
      let content_start = i.val
      let depth = Ref::new(1)
      while i.val < len && depth.val > 0 {
        if chars[i.val] == '<' {
          if i.val + 1 < len && chars[i.val + 1] == '/' {
            depth.val -= 1
            if depth.val == 0 {
              break
            }
          } else if i.val + 1 < len && chars[i.val + 1] != '!' {
            depth.val += 1
          }
        }
        i.val += 1
      }
      let inner = make_substring(chars, content_start, i.val)
      if inner.length() > 0 {
        parse_html_into(tree, elem, inner)
      }
      // Skip closing tag
      while i.val < len && chars[i.val] != '>' {
        i.val += 1
      }
      i.val += 1
    } else {
      // Text content
      let text_start = i.val
      while i.val < len && chars[i.val] != '<' {
        i.val += 1
      }
      let text = make_substring(chars, text_start, i.val).trim().to_string()
      if text.length() > 0 {
        let text_node = tree.create_text(text)
        let _ = tree.append_child(parent, text_node)

      }
    }
  }
}

///|
fn make_substring(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
/// Focus element
pub fn CdpSession::focus_element(
  self : CdpSession,
  node_id : Int,
) -> Result[Unit, CdpError] {
  let node = @dom.NodeId::from_int(node_id)
  // Verify node exists
  match self.tree.get_node_info(node) {
    Ok(_) => {
      self.tree.set_focus(Some(node))
      Ok(())
    }
    Err(e) => Err(core_to_cdp_error(e))
  }
}
