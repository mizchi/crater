///|
/// Core DOM Primitives
///
/// These are the fundamental DOM operations that all higher layers use.
/// No serialization, direct function calls only.
///
/// Design principles:
/// 1. Each operation is atomic and stateless
/// 2. No implicit side effects
/// 3. Suitable for WASM export
/// 4. Can be batched by higher layers

///|
/// DOM Tree - the core document structure
/// This is the single source of truth for all DOM operations
pub struct DomTree {
  /// Next available node ID
  mut next_id : Int
  /// All nodes indexed by ID
  nodes : Map[Int, DomNode]
  /// Root document node ID
  mut root_id : Int
  /// Currently focused node (for input)
  mut focused_node : Int?
}

///|
/// Internal DOM node representation
struct DomNode {
  node_type : NodeType
  tag_name : String
  mut text_content : String
  attributes : Map[String, String]
  mut parent_id : Int?
  children : Array[Int]
  /// For elements: computed style cache
  mut cached_rect : Rect?
}

///|
/// Create a new empty DOM tree
pub fn DomTree::new() -> DomTree {
  let tree : DomTree = { next_id: 1, nodes: {}, root_id: 0, focused_node: None }
  // Create root document node
  let doc_node : DomNode = {
    node_type: Document,
    tag_name: "#document",
    text_content: "",
    attributes: {},
    parent_id: None,
    children: [],
    cached_rect: None,
  }
  tree.nodes[0] = doc_node
  tree.root_id = 0
  tree
}

// =============================================================================
// Node Creation
// =============================================================================

///|
/// Create an element node
pub fn DomTree::create_element(self : DomTree, tag_name : String) -> NodeId {
  let id = self.next_id
  self.next_id += 1
  let node : DomNode = {
    node_type: Element,
    tag_name,
    text_content: "",
    attributes: {},
    parent_id: None,
    children: [],
    cached_rect: None,
  }
  self.nodes[id] = node
  NodeId(id)
}

///|
/// Create a text node
pub fn DomTree::create_text(self : DomTree, content : String) -> NodeId {
  let id = self.next_id
  self.next_id += 1
  let node : DomNode = {
    node_type: Text,
    tag_name: "#text",
    text_content: content,
    attributes: {},
    parent_id: None,
    children: [],
    cached_rect: None,
  }
  self.nodes[id] = node
  NodeId(id)
}

///|
/// Create a comment node
pub fn DomTree::create_comment(self : DomTree, content : String) -> NodeId {
  let id = self.next_id
  self.next_id += 1
  let node : DomNode = {
    node_type: Comment,
    tag_name: "#comment",
    text_content: content,
    attributes: {},
    parent_id: None,
    children: [],
    cached_rect: None,
  }
  self.nodes[id] = node
  NodeId(id)
}

// =============================================================================
// Tree Manipulation
// =============================================================================

///|
/// Append child to parent
pub fn DomTree::append_child(
  self : DomTree,
  parent : NodeId,
  child : NodeId,
) -> Result[Unit, CoreError] {
  let parent_id = parent.to_int()
  let child_id = child.to_int()
  match (self.nodes.get(parent_id), self.nodes.get(child_id)) {
    (Some(p), Some(c)) => {
      // Remove from old parent if any
      match c.parent_id {
        Some(old_parent_id) =>
          match self.nodes.get(old_parent_id) {
            Some(old_parent) => {
              let idx = old_parent.children.search(child_id)
              match idx {
                Some(i) => {
                  let _ = old_parent.children.remove(i)

                }
                None => ()
              }
            }
            None => ()
          }
        None => ()
      }
      // Set new parent
      c.parent_id = Some(parent_id)
      // Add to new parent's children
      p.children.push(child_id)
      // Invalidate layout cache
      self.invalidate_layout(parent_id)
      Ok(())
    }
    (None, _) => Err(NodeNotFound(node_id=parent))
    (_, None) => Err(NodeNotFound(node_id=child))
  }
}

///|
/// Insert child before reference node
pub fn DomTree::insert_before(
  self : DomTree,
  parent : NodeId,
  child : NodeId,
  reference : NodeId?,
) -> Result[Unit, CoreError] {
  let parent_id = parent.to_int()
  let child_id = child.to_int()
  match self.nodes.get(parent_id) {
    None => return Err(NodeNotFound(node_id=parent))
    Some(p) =>
      match self.nodes.get(child_id) {
        None => return Err(NodeNotFound(node_id=child))
        Some(c) => {
          // Remove from old parent
          match c.parent_id {
            Some(old_parent_id) =>
              match self.nodes.get(old_parent_id) {
                Some(old_parent) => {
                  let idx = old_parent.children.search(child_id)
                  match idx {
                    Some(i) => {
                      let _ = old_parent.children.remove(i)

                    }
                    None => ()
                  }
                }
                None => ()
              }
            None => ()
          }
          // Set new parent
          c.parent_id = Some(parent_id)
          // Insert at position
          match reference {
            Some(ref_node) => {
              let ref_id = ref_node.to_int()
              let idx = p.children.search(ref_id)
              match idx {
                Some(i) => p.children.insert(i, child_id)
                None => p.children.push(child_id) // Reference not found, append
              }
            }
            None => p.children.push(child_id) // No reference, append
          }
          self.invalidate_layout(parent_id)
          Ok(())
        }
      }
  }
}

///|
/// Remove child from parent
pub fn DomTree::remove_child(
  self : DomTree,
  parent : NodeId,
  child : NodeId,
) -> Result[Unit, CoreError] {
  let parent_id = parent.to_int()
  let child_id = child.to_int()
  match (self.nodes.get(parent_id), self.nodes.get(child_id)) {
    (Some(p), Some(c)) => {
      let idx = p.children.search(child_id)
      match idx {
        Some(i) => {
          let _ = p.children.remove(i)
          c.parent_id = None
          self.invalidate_layout(parent_id)
          Ok(())
        }
        None => Err(InvalidOperation(message="Child not found in parent"))
      }
    }
    (None, _) => Err(NodeNotFound(node_id=parent))
    (_, None) => Err(NodeNotFound(node_id=child))
  }
}

// =============================================================================
// Attribute Operations
// =============================================================================

///|
/// Set attribute on element
pub fn DomTree::set_attribute(
  self : DomTree,
  node : NodeId,
  name : String,
  value : String,
) -> Result[Unit, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => {
      n.attributes[name] = value
      self.invalidate_layout(id)
      Ok(())
    }
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get attribute from element
pub fn DomTree::get_attribute(
  self : DomTree,
  node : NodeId,
  name : String,
) -> Result[String?, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => Ok(n.attributes.get(name))
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Remove attribute from element
pub fn DomTree::remove_attribute(
  self : DomTree,
  node : NodeId,
  name : String,
) -> Result[Unit, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => {
      n.attributes.remove(name)
      self.invalidate_layout(id)
      Ok(())
    }
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get all attributes
pub fn DomTree::get_attributes(
  self : DomTree,
  node : NodeId,
) -> Result[Array[(String, String)], CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => {
      let attrs : Array[(String, String)] = []
      for name, value in n.attributes {
        attrs.push((name, value))
      }
      Ok(attrs)
    }
    None => Err(NodeNotFound(node_id=node))
  }
}

// =============================================================================
// Node Information
// =============================================================================

///|
/// Get node info
pub fn DomTree::get_node_info(
  self : DomTree,
  node : NodeId,
) -> Result[NodeInfo, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) =>
      Ok({
        node_id: node,
        node_type: n.node_type,
        node_name: n.tag_name,
        node_value: n.text_content,
        child_count: n.children.length(),
      })
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get tag name
pub fn DomTree::get_tag_name(
  self : DomTree,
  node : NodeId,
) -> Result[String, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => Ok(n.tag_name)
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get text content
pub fn DomTree::get_text_content(
  self : DomTree,
  node : NodeId,
) -> Result[String, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) =>
      match n.node_type {
        Text | Comment => Ok(n.text_content)
        _ => {
          // For elements, collect all descendant text
          let buf = StringBuilder::new()
          self.collect_text_content(id, buf)
          Ok(buf.to_string())
        }
      }
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Set text content
pub fn DomTree::set_text_content(
  self : DomTree,
  node : NodeId,
  content : String,
) -> Result[Unit, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => {
      match n.node_type {
        Text | Comment => n.text_content = content
        _ => {
          // For elements, remove all children and add text node
          n.children.clear()
          let text_node = self.create_text(content)
          let _ = self.append_child(node, text_node)

        }
      }
      self.invalidate_layout(id)
      Ok(())
    }
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Collect text content recursively
fn DomTree::collect_text_content(
  self : DomTree,
  node_id : Int,
  buf : StringBuilder,
) -> Unit {
  match self.nodes.get(node_id) {
    Some(n) =>
      match n.node_type {
        Text => buf.write_string(n.text_content)
        _ =>
          for child_id in n.children {
            self.collect_text_content(child_id, buf)
          }
      }
    None => ()
  }
}

// =============================================================================
// Tree Traversal
// =============================================================================

///|
/// Get document root
pub fn DomTree::get_document(self : DomTree) -> NodeId {
  NodeId(self.root_id)
}

///|
/// Get parent node
pub fn DomTree::get_parent(
  self : DomTree,
  node : NodeId,
) -> Result[NodeId?, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => Ok(n.parent_id.map(fn(x) { NodeId(x) }))
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get child nodes
pub fn DomTree::get_children(
  self : DomTree,
  node : NodeId,
) -> Result[Array[NodeId], CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => Ok(n.children.map(fn(x) { NodeId(x) }))
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get first child
pub fn DomTree::get_first_child(
  self : DomTree,
  node : NodeId,
) -> Result[NodeId?, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) =>
      if n.children.length() > 0 {
        Ok(Some(NodeId(n.children[0])))
      } else {
        Ok(None)
      }
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get next sibling
pub fn DomTree::get_next_sibling(
  self : DomTree,
  node : NodeId,
) -> Result[NodeId?, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) =>
      match n.parent_id {
        Some(parent_id) =>
          match self.nodes.get(parent_id) {
            Some(parent) => {
              let idx = parent.children.search(id)
              match idx {
                Some(i) if i + 1 < parent.children.length() =>
                  Ok(Some(NodeId(parent.children[i + 1])))
                _ => Ok(None)
              }
            }
            None => Ok(None)
          }
        None => Ok(None)
      }
    None => Err(NodeNotFound(node_id=node))
  }
}

// =============================================================================
// Query
// =============================================================================

///|
/// Query selector (simple CSS selector support)
/// Returns first matching node
pub fn DomTree::query_selector(
  self : DomTree,
  root : NodeId,
  selector : String,
) -> Result[NodeId?, CoreError] {
  match self.query_selector_all(root, selector) {
    Ok(results) =>
      if results.length() > 0 {
        Ok(Some(results[0]))
      } else {
        Ok(None)
      }
    Err(e) => Err(e)
  }
}

///|
/// Query selector all
/// Returns all matching nodes
pub fn DomTree::query_selector_all(
  self : DomTree,
  root : NodeId,
  selector : String,
) -> Result[Array[NodeId], CoreError] {
  let root_id = root.to_int()
  match self.nodes.get(root_id) {
    None => Err(NodeNotFound(node_id=root))
    Some(_) => {
      let results : Array[NodeId] = []
      self.query_recursive(root_id, selector, results)
      Ok(results)
    }
  }
}

///|
/// Recursive query helper
fn DomTree::query_recursive(
  self : DomTree,
  node_id : Int,
  selector : String,
  results : Array[NodeId],
) -> Unit {
  match self.nodes.get(node_id) {
    None => ()
    Some(node) => {
      // Check if this node matches
      if self.matches_selector(node, selector) {
        results.push(NodeId(node_id))
      }
      // Recurse into children
      for child_id in node.children {
        self.query_recursive(child_id, selector, results)
      }
    }
  }
}

///|
/// Check if node matches selector (simplified)
fn DomTree::matches_selector(
  self : DomTree,
  node : DomNode,
  selector : String,
) -> Bool {
  // Suppress unused warning
  let _ = self
  // Only match elements
  guard node.node_type == Element else { return false }
  // Simple selector matching
  if selector.has_prefix("#") {
    // ID selector
    let id = selector[1:].to_string() catch { _ => return false }
    node.attributes.get("id") == Some(id)
  } else if selector.has_prefix(".") {
    // Class selector
    let class_name = selector[1:].to_string() catch { _ => return false }
    match node.attributes.get("class") {
      Some(classes) => classes.contains(class_name)
      None => false
    }
  } else if selector.has_prefix("[") && selector.has_suffix("]") {
    // Attribute selector (simple: [attr] or [attr=value])
    let inner = selector[1:selector.length() - 1].to_string() catch {
      _ => return false
    }
    if inner.contains("=") {
      let parts = split_once(inner, '=')
      match parts {
        Some((attr, value)) => {
          let clean_value = value.trim().to_string()
          let clean_value = if clean_value.has_prefix("\"") &&
            clean_value.has_suffix("\"") {
            clean_value[1:clean_value.length() - 1].to_string() catch {
              _ => clean_value
            }
          } else {
            clean_value
          }
          node.attributes.get(attr.trim().to_string()) == Some(clean_value)
        }
        None => false
      }
    } else {
      node.attributes.contains(inner)
    }
  } else {
    // Tag name selector
    node.tag_name.to_lower() == selector.to_lower()
  }
}

///|
/// Split string on first occurrence of character
fn split_once(s : String, c : Char) -> (String, String)? {
  let chars = s.to_array()
  for i, ch in chars {
    if ch == c {
      let before = StringBuilder::new()
      let after = StringBuilder::new()
      for j = 0; j < i; j = j + 1 {
        before.write_char(chars[j])
      }
      for j = i + 1; j < chars.length(); j = j + 1 {
        after.write_char(chars[j])
      }
      return Some((before.to_string(), after.to_string()))
    }
  }
  None
}

// =============================================================================
// Layout Cache
// =============================================================================

///|
/// Invalidate layout cache for node and ancestors
fn DomTree::invalidate_layout(self : DomTree, node_id : Int) -> Unit {
  match self.nodes.get(node_id) {
    Some(n) => {
      n.cached_rect = None
      match n.parent_id {
        Some(parent_id) => self.invalidate_layout(parent_id)
        None => ()
      }
    }
    None => ()
  }
}

///|
/// Set cached rect (called by layout engine)
pub fn DomTree::set_cached_rect(
  self : DomTree,
  node : NodeId,
  rect : Rect,
) -> Unit {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => n.cached_rect = Some(rect)
    None => ()
  }
}

///|
/// Get cached rect
pub fn DomTree::get_cached_rect(self : DomTree, node : NodeId) -> Rect? {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => n.cached_rect
    None => None
  }
}

// =============================================================================
// Focus Management
// =============================================================================

///|
/// Set focused element
pub fn DomTree::set_focus(self : DomTree, node : NodeId?) -> Unit {
  self.focused_node = node.map(fn(x) { x.to_int() })
}

///|
/// Get focused element
pub fn DomTree::get_focus(self : DomTree) -> NodeId? {
  self.focused_node.map(fn(x) { NodeId(x) })
}
