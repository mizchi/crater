///|
/// Shadow-scoped `querySelector` / `querySelectorAll` (#286).
///
/// `query_selector` (`query.mbt`) scopes to a node's descendants using the plain
/// `mizchi/css` matcher, which cannot resolve the shadow-scoping pseudo-classes.
/// These entries query *inside a shadow root* and route matching through
/// `matches_shadow_scoped` (#285) so `:host(...)` and `:host-context(...)`
/// resolve against the live shadow relationships. (`::slotted()` targets light
/// nodes, which are not shadow-tree descendants, and is a styling pseudo-element
/// not matched by `querySelector` — see #286 — so it never selects here.)
///
/// Candidates are the shadow root's element descendants in document order;
/// nested shadow trees are not crossed (a shadow host inside the tree contributes
/// only its light children, never its own shadow root). The scope root itself is
/// never returned, matching `querySelectorAll` semantics.

///|
/// Shadow-scoped `querySelectorAll`: every shadow-tree element selected by
/// `selector`, in document order. `shadow_root` must be a shadow root node; its
/// host (resolved from the shadow root) anchors `:host` / `:host-context` /
/// `::slotted` resolution. An invalid selector yields `InvalidOperation`.
pub fn DomTree::shadow_query_selector_all(
  self : DomTree,
  shadow_root : NodeId,
  selector : String,
) -> Result[Array[NodeId], CoreError] {
  let root_node = match self.nodes.get(shadow_root.to_int()) {
    Some(node) => node
    None => return Err(NodeNotFound(node_id=shadow_root))
  }
  guard root_node.node_type == ShadowRoot else {
    return Err(
      InvalidOperation(message="node is not a shadow root: \{shadow_root}"),
    )
  }
  let host = match root_node.host_id {
    Some(id) => NodeId(id)
    None =>
      return Err(
        InvalidOperation(message="shadow root has no host: \{shadow_root}"),
      )
  }
  let list = match @selector.parse_selector_list_text(selector) {
    Some(list) => list
    None =>
      return Err(InvalidOperation(message="invalid selector: \{selector}"))
  }
  let results : Array[NodeId] = []
  self.shadow_query_collect(shadow_root, host, list, results)
  Ok(results)
}

///|
/// Shadow-scoped `querySelector`: the first shadow-tree element selected by
/// `selector` in document order, or `None`.
pub fn DomTree::shadow_query_selector(
  self : DomTree,
  shadow_root : NodeId,
  selector : String,
) -> Result[NodeId?, CoreError] {
  match self.shadow_query_selector_all(shadow_root, selector) {
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
/// Walk the element descendants of `node` in document order, testing each with
/// the shadow-aware matcher and recursing through light children only (nested
/// shadow roots are not entered).
fn DomTree::shadow_query_collect(
  self : DomTree,
  node : NodeId,
  host : NodeId,
  list : @selector.SelectorList,
  results : Array[NodeId],
) -> Unit {
  let n = match self.nodes.get(node.to_int()) {
    Some(n) => n
    None => return
  }
  for child_id in n.children {
    match self.nodes.get(child_id) {
      Some(child) if child.node_type == Element => {
        let child_node = NodeId(child_id)
        if self.matches_shadow_scoped_list(child_node, list, host) {
          results.push(child_node)
        }
        self.shadow_query_collect(child_node, host, list, results)
      }
      _ => ()
    }
  }
}
