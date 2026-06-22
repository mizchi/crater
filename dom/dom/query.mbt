///|
/// Query Selector Implementation
///
/// CSS selector support for querying DOM nodes. Handles a single compound
/// selector: a type / universal selector combined with `#id`, `.class`, and
/// `[attr]` / `[attr=value]` simple selectors. Combinators and pseudo-classes
/// are not handled yet (tracked in #286).

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
  if matches_selector(node, selector) {
    results.push(NodeId(node_id))
  }
  // Recurse into children
  for child_id in node.children {
    self.query_recursive(child_id, selector, results)
  }
}

///|
/// Check whether `node` matches a single compound selector.
///
/// Supports a type / universal selector combined with any number of `#id`,
/// `.class`, and `[attr]` / `[attr=value]` simple selectors, e.g.
/// `div.foo#bar[type=text]`. Combinators (descendant / child / sibling) and
/// pseudo-classes / pseudo-elements are not handled here yet — they need
/// traversal or shadow context (tracked in #286) — so a selector containing
/// them matches nothing rather than being mis-parsed.
fn matches_selector(node : DomNode, selector : String) -> Bool {
  // Only match elements
  guard node.node_type == Element else { return false }
  let sel = selector.trim().to_owned()
  guard sel.length() > 0 else { return false }
  if has_combinator(sel) || sel.contains(":") {
    return false
  }
  match parse_compound(sel) {
    Some(tokens) => {
      for token in tokens {
        if !matches_simple(node, token) {
          return false
        }
      }
      true
    }
    None => false
  }
}

///|
fn is_whitespace_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// Whether the selector contains a combinator (` `, `>`, `+`, `~`) outside an
/// attribute `[...]` block.
fn has_combinator(sel : String) -> Bool {
  let chars = sel.to_array()
  let mut depth = 0
  for ch in chars {
    if ch == '[' {
      depth = depth + 1
    } else if ch == ']' {
      if depth > 0 {
        depth = depth - 1
      }
    } else if depth == 0 && (ch == ' ' || ch == '>' || ch == '+' || ch == '~') {
      return true
    }
  }
  false
}

///|
/// Split a compound selector into its simple-selector tokens, each keeping its
/// leading marker (`#id`, `.class`, `[attr...]`) plus an optional leading type.
/// Returns None on malformed input (e.g. an unterminated `[`).
fn parse_compound(sel : String) -> Array[String]? {
  let chars = sel.to_array()
  let n = chars.length()
  let tokens : Array[String] = []
  let mut i = 0
  // Leading type / universal selector (up to the first marker).
  let type_buf = StringBuilder::new()
  while i < n && chars[i] != '#' && chars[i] != '.' && chars[i] != '[' {
    type_buf.write_char(chars[i])
    i = i + 1
  }
  let type_part = type_buf.to_string()
  if type_part.length() > 0 {
    tokens.push(type_part)
  }
  while i < n {
    let marker = chars[i]
    if marker == '#' || marker == '.' {
      let buf = StringBuilder::new()
      buf.write_char(marker)
      i = i + 1
      while i < n && chars[i] != '#' && chars[i] != '.' && chars[i] != '[' {
        buf.write_char(chars[i])
        i = i + 1
      }
      tokens.push(buf.to_string())
    } else if marker == '[' {
      let buf = StringBuilder::new()
      buf.write_char('[')
      i = i + 1
      while i < n && chars[i] != ']' {
        buf.write_char(chars[i])
        i = i + 1
      }
      if i >= n {
        return None
      }
      buf.write_char(']')
      i = i + 1
      tokens.push(buf.to_string())
    } else {
      return None
    }
  }
  if tokens.is_empty() {
    None
  } else {
    Some(tokens)
  }
}

///|
/// Match one simple-selector token (`*`, `#id`, `.class`, `[attr...]`, or a
/// bare type) against a node.
fn matches_simple(node : DomNode, token : String) -> Bool {
  if token == "*" {
    return true
  }
  if token.has_prefix("#") {
    let id = token.unsafe_substring(start=1, end=token.length())
    return node.attributes.get("id") == Some(id)
  }
  if token.has_prefix(".") {
    let class_name = token.unsafe_substring(start=1, end=token.length())
    return match node.attributes.get("class") {
      Some(classes) => class_list_contains(classes, class_name)
      None => false
    }
  }
  if token.has_prefix("[") && token.has_suffix("]") {
    let inner = token.unsafe_substring(start=1, end=token.length() - 1)
    return matches_attribute_expr(node, inner)
  }
  // Type selector (case-insensitive).
  node.tag_name.to_lower() == token.to_lower()
}

///|
/// Match an attribute selector body (`attr` or `attr=value`, optional quotes).
fn matches_attribute_expr(node : DomNode, inner : String) -> Bool {
  if inner.contains("=") {
    match split_once(inner, '=') {
      Some((attr, value)) => {
        let clean_value = value.trim().to_owned()
        let clean_value = if clean_value.has_prefix("\"") &&
          clean_value.has_suffix("\"") {
          clean_value.unsafe_substring(start=1, end=clean_value.length() - 1)
        } else {
          clean_value
        }
        node.attributes.get(attr.trim().to_owned()) == Some(clean_value)
      }
      None => false
    }
  } else {
    node.attributes.contains(inner.trim().to_owned())
  }
}

///|
/// Whitespace-separated class-list membership (so `.foo` does not match
/// `class="foobar"`).
fn class_list_contains(classes : String, name : String) -> Bool {
  guard name.length() > 0 else { return false }
  let chars = classes.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n {
    while i < n && is_whitespace_char(chars[i]) {
      i = i + 1
    }
    let buf = StringBuilder::new()
    while i < n && !is_whitespace_char(chars[i]) {
      buf.write_char(chars[i])
      i = i + 1
    }
    if buf.to_string() == name {
      return true
    }
  }
  false
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
