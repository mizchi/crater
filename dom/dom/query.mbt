///|
/// Query Selector Implementation
///
/// CSS selector matching for DOM queries. Parsing and matching are delegated to
/// `mizchi/css/selector`: each candidate element in the queried subtree is
/// projected into a `@selector.Element` (with parent / previous-sibling /
/// sibling-index wiring) and tested with `@selector.matches_selector_list`.
/// This reuses the selector grammar and matcher — selector lists, combinators,
/// attribute operators and structural pseudo-classes — without duplicating it.
///
/// Scoping note: matching is restricted to the queried subtree (the root's
/// ancestors are not consulted) and the context node itself is never returned,
/// per `querySelectorAll` semantics.

///|
/// Query selector — returns the first matching node in document order.
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
/// Query selector all — returns every matching node in document order.
pub fn DomTree::query_selector_all(
  self : DomTree,
  root : NodeId,
  selector : String,
) -> Result[Array[NodeId], CoreError] {
  let root_id = root.to_int()
  guard self.nodes.get(root_id) is Some(_) else {
    return Err(NodeNotFound(node_id=root))
  }
  let list = match @selector.parse_selector_list_text(selector) {
    Some(list) => list
    None =>
      return Err(InvalidOperation(message="invalid selector: \{selector}"))
  }
  let results : Array[NodeId] = []
  let _ = self.query_match_node(root_id, None, 1, 1, None, true, list, results)
  Ok(results)
}

///|
/// Project the node at `node_id` into a `@selector.Element`, test it against
/// `list` (unless it is the scope root), then recurse into its element
/// children. Returns the built element so the caller can thread it as the
/// parent / previous-sibling of the next node. Non-element nodes are not tested
/// but still propagate scope to their element children.
fn DomTree::query_match_node(
  self : DomTree,
  node_id : Int,
  parent_sel : @selector.Element?,
  sibling_index : Int,
  sibling_count : Int,
  prev_sel : @selector.Element?,
  is_root : Bool,
  list : @selector.SelectorList,
  results : Array[NodeId],
) -> @selector.Element? {
  let node = self.nodes.get(node_id)
  guard node is Some(node) else { return None }
  let my_sel : @selector.Element? = if node.node_type == Element {
    let element = dom_node_to_selector_element(
      node, parent_sel, prev_sel, sibling_index, sibling_count,
    )
    if !is_root && @selector.matches_selector_list(element, list) {
      results.push(NodeId(node_id))
    }
    Some(element)
  } else {
    None
  }
  // Element children inherit this element as their parent; a non-element node
  // (document / shadow root) passes the inherited scope through unchanged.
  let child_parent = match my_sel {
    Some(_) => my_sel
    None => parent_sel
  }
  let element_children : Array[Int] = []
  for child_id in node.children {
    match self.nodes.get(child_id) {
      Some(child) if child.node_type == Element =>
        element_children.push(child_id)
      _ => ()
    }
  }
  let count = element_children.length()
  let mut prev : @selector.Element? = None
  for i, child_id in element_children {
    let child_sel = self.query_match_node(
      child_id,
      child_parent,
      i + 1,
      count,
      prev,
      false,
      list,
      results,
    )
    prev = child_sel
  }
  my_sel
}

///|
/// Build a `@selector.Element` view of a DOM node, wiring the parent and
/// previous-sibling links and the element-based sibling index/count that the
/// selector matcher uses for combinators and structural pseudo-classes.
/// Shared read-only empties for projected `@selector.Element` fields, so each
/// per-query node projection does not allocate fresh empty arrays. The selector
/// matcher only reads these fields; `children` is never populated by the query.
let empty_selector_strings : Array[String] = []

///|
let empty_selector_attrs : Array[@selector.Attribute] = []

///|
let empty_selector_children : Array[@selector.Element] = []

///|
fn dom_node_to_selector_element(
  node : DomNode,
  parent : @selector.Element?,
  prev_sibling : @selector.Element?,
  sibling_index : Int,
  sibling_count : Int,
) -> @selector.Element {
  // Reuse the parsed class list / attribute array across queries; both are
  // invalidated when the node's attributes change.
  let classes : Array[String] = match node.sel_classes {
    Some(cached) => cached
    None => {
      let computed = match node.attributes.get("class") {
        Some(value) => split_whitespace(value)
        None => empty_selector_strings
      }
      node.sel_classes = Some(computed)
      computed
    }
  }
  let attributes : Array[@selector.Attribute] = match node.sel_attrs {
    Some(cached) => cached
    None => {
      let computed : Array[@selector.Attribute] = if node.attributes.is_empty() {
        empty_selector_attrs
      } else {
        let attrs = []
        node.attributes.each(fn(name, value) {
          attrs.push(@selector.Attribute::{ name, value })
        })
        attrs
      }
      node.sel_attrs = Some(computed)
      computed
    }
  }
  // The projection is transient and read-only, so the node's custom_states can
  // be aliased (an empty set is shared) instead of copied.
  let custom_states = if node.custom_states.is_empty() {
    empty_selector_strings
  } else {
    node.custom_states
  }
  {
    tag_name: node.tag_name,
    id: node.attributes.get("id"),
    classes,
    attributes,
    custom_states,
    parent,
    prev_sibling,
    next_sibling: None,
    children: empty_selector_children,
    sibling_index,
    sibling_count,
  }
}

///|
fn is_whitespace_code(code : Int) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
/// Split a string on ASCII whitespace, dropping empty segments (used for the
/// `class` attribute's token list). Index-scans the input and slices each token
/// instead of materializing a char array (`to_array`) and a `StringBuilder` per
/// token, which dominated allocation in `querySelectorAll` node projection.
fn split_whitespace(s : String) -> Array[String] {
  let n = s.length()
  let tokens : Array[String] = []
  let mut i = 0
  while i < n {
    while i < n && is_whitespace_code(s[i].to_int()) {
      i = i + 1
    }
    let start = i
    while i < n && !is_whitespace_code(s[i].to_int()) {
      i = i + 1
    }
    if i > start {
      tokens.push(s[start:i].to_owned())
    }
  }
  tokens
}
