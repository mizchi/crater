///|
/// DOM Serializer - Serializes DomTree to JavaScript objects
///
/// Converts MoonBit DomTree to a JS representation for mock DOM initialization.
/// This enables scripts to see the actual HTML content.

///|
/// Serialize DomTree to JavaScript object creation code
/// Returns JS code that reconstructs the DOM tree in the mock DOM
pub fn serialize_dom_for_mock(dom : @dom.DomTree) -> String {
  let buf = StringBuilder::new()
  buf.write_string("(function() {\n")
  buf.write_string("  const _nodeMap = new Map();\n")

  // Get document root
  let doc_id = dom.get_document()
  serialize_node_recursive(dom, doc_id, buf, 0)
  buf.write_string("  return _nodeMap;\n")
  buf.write_string("})()")
  buf.to_string()
}

///|
/// Serialize a node and its children recursively
fn serialize_node_recursive(
  dom : @dom.DomTree,
  node_id : @dom.NodeId,
  buf : StringBuilder,
  depth : Int,
) -> Unit {
  guard depth < 100 else { return } // Prevent infinite recursion
  let info = dom.get_node_info(node_id)
  guard info is Ok(info) else { return }
  let id = node_id.to_int()
  let indent = "  ".repeat(depth + 1)
  match info.node_type {
    @dom.Element => {
      // Create element
      let tag = escape_js_string(info.node_name)
      buf.write_string(indent)
      buf.write_string(
        "_nodeMap.set(\{id}, document.createElement('\{tag}'));\n",
      )

      // Set attributes
      let attrs = dom.get_attributes(node_id)
      match attrs {
        Ok(attrs) =>
          for pair in attrs {
            let (name, value) = pair
            let name_escaped = escape_js_string(name)
            let value_escaped = escape_js_string(value)
            buf.write_string(indent)
            buf.write_string(
              "_nodeMap.get(\{id}).setAttribute('\{name_escaped}', '\{value_escaped}');\n",
            )
          }
        Err(_) => ()
      }

      // Process children
      let children = dom.get_children(node_id)
      match children {
        Ok(children) =>
          for child_id in children {
            serialize_node_recursive(dom, child_id, buf, depth)
            let child_int = child_id.to_int()
            buf.write_string(indent)
            buf.write_string(
              "if (_nodeMap.has(\{child_int})) _nodeMap.get(\{id}).appendChild(_nodeMap.get(\{child_int}));\n",
            )
          }
        Err(_) => ()
      }

      match dom.get_shadow_root(node_id) {
        Ok(Some(shadow_root_id)) => {
          let shadow_int = shadow_root_id.to_int()
          let mode = dom
            .get_shadow_mode(shadow_root_id)
            .unwrap_or(None)
            .unwrap_or("open")
          let mode = escape_js_string(mode)
          buf.write_string(indent)
          buf.write_string(
            "_nodeMap.set(\{shadow_int}, _nodeMap.get(\{id}).attachShadow({ mode: '\{mode}' }));\n",
          )
          buf.write_string(indent)
          buf.write_string(
            "_nodeMap.get(\{shadow_int})._mockId = \{shadow_int};\n",
          )
          match dom.get_children(shadow_root_id) {
            Ok(shadow_children) =>
              for child_id in shadow_children {
                serialize_node_recursive(dom, child_id, buf, depth)
                let child_int = child_id.to_int()
                buf.write_string(indent)
                buf.write_string(
                  "if (_nodeMap.has(\{child_int})) _nodeMap.get(\{shadow_int}).appendChild(_nodeMap.get(\{child_int}));\n",
                )
              }
            Err(_) => ()
          }
        }
        _ => ()
      }
    }
    @dom.Text => {
      let text = dom.get_text_content(node_id)
      match text {
        Ok(text) => {
          let text_escaped = escape_js_string(text)
          buf.write_string(indent)
          buf.write_string(
            "_nodeMap.set(\{id}, document.createTextNode('\{text_escaped}'));\n",
          )
        }
        Err(_) => ()
      }
    }
    @dom.Comment => {
      let text = dom.get_text_content(node_id)
      match text {
        Ok(text) => {
          let text_escaped = escape_js_string(text)
          buf.write_string(indent)
          buf.write_string(
            "_nodeMap.set(\{id}, document.createComment('\{text_escaped}'));\n",
          )
        }
        Err(_) => ()
      }
    }
    @dom.Document
    | @dom.DocumentType
    | @dom.DocumentFragment
    | @dom.ShadowRoot =>
      // Skip document nodes in serialization (handled separately)
      // Process children for Document
      match info.node_type {
        @dom.Document => {
          let children = dom.get_children(node_id)
          match children {
            Ok(children) =>
              for child_id in children {
                serialize_node_recursive(dom, child_id, buf, depth)
              }
            Err(_) => ()
          }
        }
        _ => ()
      }
  }
}

///|
/// Escape a string for JavaScript string literal
fn escape_js_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '\\' => buf.write_string("\\\\")
      '\'' => buf.write_string("\\'")
      '"' => buf.write_string("\\\"")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Create initialization code that populates mock DOM from DomTree
/// This builds the HTML structure (html, head, body) with actual content
pub fn create_dom_init_code(dom : @dom.DomTree) -> String {
  let buf = StringBuilder::new()

  // Find body element in DomTree
  let doc_id = dom.get_document()
  let body_content = find_and_serialize_body(dom, doc_id)
  buf.write_string("(function() {\n")
  buf.write_string("  // Populate body with DomTree content\n")
  buf.write_string(body_content)
  buf.write_string("})();\n")
  buf.to_string()
}

///|
/// Serialize DomTree to HTML string for renderer reparse
pub fn serialize_dom_to_html(dom : @dom.DomTree) -> String {
  let buf = StringBuilder::new()
  let doc_id = dom.get_document()
  match dom.get_children(doc_id) {
    Ok(children) =>
      for child in children {
        serialize_node_to_html_in_context(dom, child, buf, None)
      }
    Err(_) => ()
  }
  buf.to_string()
}

///|
fn serialize_node_to_html_in_context(
  dom : @dom.DomTree,
  node_id : @dom.NodeId,
  buf : StringBuilder,
  shadow_host : @dom.NodeId?,
) -> Unit {
  let info = dom.get_node_info(node_id)
  guard info is Ok(info) else { return }
  match info.node_type {
    @dom.Document =>
      for child in dom.get_composed_children(node_id, shadow_host~) {
        serialize_node_to_html_in_context(dom, child, buf, shadow_host)
      }
    @dom.DocumentType => {
      let name = info.node_name.to_lower()
      if name == "html" {
        buf.write_string("<!DOCTYPE html>")
      }
    }
    @dom.Text => buf.write_string(escape_html_text(info.node_value))
    @dom.Comment => {
      buf.write_string("<!--")
      buf.write_string(info.node_value)
      buf.write_string("-->")
    }
    @dom.DocumentFragment | @dom.ShadowRoot =>
      for child in dom.get_composed_children(node_id, shadow_host~) {
        serialize_node_to_html_in_context(dom, child, buf, shadow_host)
      }
    @dom.Element => {
      if shadow_host != None && dom.is_slot_element(node_id) {
        for child in dom.get_composed_children(node_id, shadow_host~) {
          serialize_node_to_html_in_context(dom, child, buf, shadow_host)
        }
        return
      }
      let tag = info.node_name
      buf.write_char('<')
      buf.write_string(tag)
      match dom.get_attributes(node_id) {
        Ok(attrs) =>
          for pair in attrs {
            let (name, value) = pair
            buf.write_char(' ')
            buf.write_string(name)
            buf.write_string("=\"")
            buf.write_string(escape_html_attr(value))
            buf.write_char('"')
          }
        Err(_) => ()
      }
      buf.write_char('>')
      if is_void_html_element(tag) {
        return
      }
      let child_shadow_host = match dom.get_shadow_root(node_id) {
        Ok(Some(_)) => Some(node_id)
        _ => shadow_host
      }
      for child in dom.get_composed_children(node_id, shadow_host~) {
        serialize_node_to_html_in_context(dom, child, buf, child_shadow_host)
      }
      buf.write_string("</")
      buf.write_string(tag)
      buf.write_char('>')
    }
  }
}

///|
fn is_void_html_element(tag : String) -> Bool {
  match tag.to_lower() {
    "area"
    | "base"
    | "br"
    | "col"
    | "embed"
    | "hr"
    | "img"
    | "input"
    | "link"
    | "meta"
    | "param"
    | "source"
    | "track"
    | "wbr" => true
    _ => false
  }
}

///|
fn escape_html_text(s : String) -> String {
  let out = StringBuilder::new()
  for c in s {
    match c {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn escape_html_attr(s : String) -> String {
  let out = StringBuilder::new()
  for c in s {
    match c {
      '&' => out.write_string("&amp;")
      '"' => out.write_string("&quot;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
/// Find body element and serialize its children
fn find_and_serialize_body(dom : @dom.DomTree, start : @dom.NodeId) -> String {
  let buf = StringBuilder::new()
  let _ = find_body_recursive(dom, start, buf)
  buf.to_string()
}

///|
/// Recursively find body and serialize its content
fn find_body_recursive(
  dom : @dom.DomTree,
  node_id : @dom.NodeId,
  buf : StringBuilder,
) -> Bool {
  let info = dom.get_node_info(node_id)
  guard info is Ok(info) else { return false }
  match info.node_type {
    @dom.Element => {
      if info.node_name.to_lower() == "body" {
        // Found body, serialize its children
        serialize_body_children(dom, node_id, buf)
        return true
      }
      // Continue searching in children
      let children = dom.get_children(node_id)
      match children {
        Ok(children) =>
          for child_id in children {
            if find_body_recursive(dom, child_id, buf) {
              return true
            }
          }
        Err(_) => ()
      }
    }
    @dom.Document => {
      let children = dom.get_children(node_id)
      match children {
        Ok(children) =>
          for child_id in children {
            if find_body_recursive(dom, child_id, buf) {
              return true
            }
          }
        Err(_) => ()
      }
    }
    _ => ()
  }
  false
}

///|
/// Serialize body children as DOM creation code
fn serialize_body_children(
  dom : @dom.DomTree,
  body_id : @dom.NodeId,
  buf : StringBuilder,
) -> Unit {
  let children = dom.get_children(body_id)
  guard children is Ok(children) else { return }
  for child_id in children {
    serialize_element_to_append(dom, child_id, buf, "bodyEl")
  }
}

///|
/// Serialize an element as code that creates and appends it
/// Sets _mockId to match DomTree node ID for proper synchronization
fn serialize_element_to_append(
  dom : @dom.DomTree,
  node_id : @dom.NodeId,
  buf : StringBuilder,
  parent_var : String,
) -> Unit {
  let info = dom.get_node_info(node_id)
  guard info is Ok(info) else { return }
  let id = node_id.to_int()
  match info.node_type {
    @dom.Element => {
      let tag = escape_js_string(info.node_name)
      buf.write_string("  const el_\{id} = document.createElement('\{tag}');\n")
      // Sync _mockId with DomTree node ID for proper change tracking
      buf.write_string("  el_\{id}._mockId = \{id};\n")

      // Set attributes
      let attrs = dom.get_attributes(node_id)
      match attrs {
        Ok(attrs) =>
          for pair in attrs {
            let (name, value) = pair
            let name_escaped = escape_js_string(name)
            let value_escaped = escape_js_string(value)
            buf.write_string(
              "  el_\{id}.setAttribute('\{name_escaped}', '\{value_escaped}');\n",
            )
          }
        Err(_) => ()
      }

      // Process children
      let children = dom.get_children(node_id)
      match children {
        Ok(children) =>
          for child_id in children {
            serialize_element_to_append(dom, child_id, buf, "el_\{id}")
          }
        Err(_) => ()
      }

      match dom.get_shadow_root(node_id) {
        Ok(Some(shadow_root_id)) => {
          let shadow_int = shadow_root_id.to_int()
          let mode = dom
            .get_shadow_mode(shadow_root_id)
            .unwrap_or(None)
            .unwrap_or("open")
          let mode = escape_js_string(mode)
          buf.write_string(
            "  const shadow_\{shadow_int} = el_\{id}.attachShadow({ mode: '\{mode}' });\n",
          )
          buf.write_string("  shadow_\{shadow_int}._mockId = \{shadow_int};\n")
          match dom.get_children(shadow_root_id) {
            Ok(shadow_children) =>
              for child_id in shadow_children {
                serialize_element_to_append(
                  dom,
                  child_id,
                  buf,
                  "shadow_\{shadow_int}",
                )
              }
            Err(_) => ()
          }
        }
        _ => ()
      }

      // Append to parent
      buf.write_string("  \{parent_var}.appendChild(el_\{id});\n")
    }
    @dom.Text => {
      let text = dom.get_text_content(node_id)
      match text {
        Ok(text) => {
          let text_escaped = escape_js_string(text)
          buf.write_string(
            "  const txt_\{id} = document.createTextNode('\{text_escaped}');\n",
          )
          // Sync _mockId with DomTree node ID
          buf.write_string("  txt_\{id}._mockId = \{id};\n")
          buf.write_string("  \{parent_var}.appendChild(txt_\{id});\n")
        }
        Err(_) => ()
      }
    }
    @dom.Comment => {
      let text = dom.get_text_content(node_id)
      match text {
        Ok(text) => {
          let text_escaped = escape_js_string(text)
          buf.write_string(
            "  const cmt_\{id} = document.createComment('\{text_escaped}');\n",
          )
          // Sync _mockId with DomTree node ID
          buf.write_string("  cmt_\{id}._mockId = \{id};\n")
          buf.write_string("  \{parent_var}.appendChild(cmt_\{id});\n")
        }
        Err(_) => ()
      }
    }
    @dom.DocumentFragment
    | @dom.ShadowRoot
    | @dom.Document
    | @dom.DocumentType => ()
  }
}
