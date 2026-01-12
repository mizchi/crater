///|
/// CDP Testing Utilities
///
/// Test helpers for CDP domain tests.
/// Pattern inspired by lightpanda-browser testing.zig

///|
/// Test context for CDP operations
pub struct TestContext {
  session : CdpSession
}

///|
/// Create a new test context
pub fn TestContext::new() -> TestContext {
  { session: CdpSession::new("test-session") }
}

///|
/// Create test context with HTML content
pub fn TestContext::with_html(html : String) -> TestContext {
  let ctx = TestContext::new()
  // Parse HTML and build DOM tree
  ctx.parse_html(html)
  ctx
}

///|
/// Parse simple HTML into DOM tree
/// Supports: <tag>, <tag attr="value">, text, nested elements
fn TestContext::parse_html(self : TestContext, html : String) -> Unit {
  let tree = self.session.get_tree()
  let doc = tree.get_document()
  // Create html > body structure
  let html_elem = tree.create_element("html")
  let body = tree.create_element("body")
  let _ = tree.append_child(doc, html_elem)
  let _ = tree.append_child(html_elem, body)
  // Parse content into body
  parse_html_content(tree, body, html)
}

///|
/// Simple HTML parser (for testing only)
fn parse_html_content(
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
      let tag_name = substring(chars, tag_start, i.val)
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
          let attr_name = substring(chars, attr_start, i.val)
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
            let attr_val = substring(chars, val_start, i.val)
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
      let inner = substring(chars, content_start, i.val)
      if inner.length() > 0 {
        parse_html_content(tree, elem, inner)
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
      let text = substring(chars, text_start, i.val).trim().to_string()
      if text.length() > 0 {
        let text_node = tree.create_text(text)
        let _ = tree.append_child(parent, text_node)

      }
    }
  }
}

///|
/// Extract substring from char array
fn substring(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
/// Get DOM domain from test context
pub fn TestContext::dom(self : TestContext) -> DomDomain {
  self.session.get_dom()
}

///|
/// Get Page domain from test context
pub fn TestContext::page(self : TestContext) -> PageDomain {
  self.session.get_page()
}

///|
/// Get Input domain from test context
pub fn TestContext::input(self : TestContext) -> InputDomain {
  self.session.get_input()
}

///|
/// Get the underlying DOM tree
pub fn TestContext::tree(self : TestContext) -> @dom.DomTree {
  self.session.get_tree()
}

///|
/// Get document root node ID
pub fn TestContext::doc_id(self : TestContext) -> Int {
  self.session.get_tree().get_document().to_int()
}
