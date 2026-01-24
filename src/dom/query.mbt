///|
/// Query Selector Implementation
///
/// Simple CSS selector support for querying DOM nodes.
/// Supports: tag names, #id, .class, [attr], [attr=value]

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
  let node = self.nodes.get(node_id)
  guard node is Some(node) else { return }
  // Check if this node matches
  if self.matches_selector(node, selector) {
    results.push(NodeId(node_id))
  }
  // Recurse into children
  for child_id in node.children {
    self.query_recursive(child_id, selector, results)
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
      match split_once(inner, '=') {
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
