///|
/// Incremental reflow across a rebuilt render node tree.
///
/// The dynamic-rendering path rebuilds the render node tree from the mutated DOM
/// on each change (full cascade — correct for every selector), which would
/// normally throw away all cached geometry. `reconcile_from` bridges a freshly
/// built `LayoutTree` to a prior one: it migrates each node's cached layout from
/// the previous tree by matching `uid` (the stable `dom_id`-derived identity —
/// see docs/incremental-reflow-design.md phase A), so unchanged subtrees stay
/// cache hits, while nodes that actually changed are dirtied and recomputed.
///
/// Two sources of dirtiness:
/// - `dirty_uids`: nodes whose computed style / content changed (the caller
///   determines these — e.g. by comparing computed styles after the cascade).
/// - structural changes: a node whose set of child `uid`s differs from the prior
///   tree (a child added / removed / reordered) is detected here and dirtied.
///
/// Correctness contract: if `dirty_uids` is a superset of the nodes whose layout
/// inputs changed, the layout computed from the returned tree equals a full
/// from-scratch recompute. (Unlisted changes would read stale cache — hence the
/// dynamic path pairs this with a conservative dirty set + fall-back to full.)
pub fn LayoutTree::reconcile_from(
  prev : LayoutTree,
  new_root : @node.Node,
  dirty_uids : Array[Int],
  viewport_width : Double,
  viewport_height : Double,
) -> LayoutTree {
  let next = LayoutTree::from_node(new_root, viewport_width, viewport_height)
  // Pass 1: every node from `from_node` starts dirty. For nodes that persisted
  // (same uid) migrate the cached geometry and clear the dirty flag so they can
  // be served from cache; record nodes whose child set changed (a structural
  // mutation). New nodes (no match) stay dirty and recompute.
  let structural : Array[Int] = []
  next.node_map.each(fn(uid, node) {
    match prev.node_map.get(uid) {
      Some(old) => {
        node.cached_layout = old.cached_layout
        node.clear_dirty()
        if !layout_child_uids_equal(node, old) {
          structural.push(uid)
        }
      }
      None => ()
    }
  })
  // Pass 2: re-dirty the changed nodes. mark_node_dirty propagates children_dirty
  // up the ancestor chain (so a clean ancestor of a changed node recomputes, and
  // a parent whose child set changed recomputes its new children).
  for uid in structural {
    next.mark_node_dirty(uid)
  }
  for uid in dirty_uids {
    next.mark_node_dirty(uid)
  }
  next
}

///|
/// Whether two layout nodes have the same ordered list of child `uid`s.
fn layout_child_uids_equal(a : LayoutNode, b : LayoutNode) -> Bool {
  if a.children.length() != b.children.length() {
    return false
  }
  for i = 0; i < a.children.length(); i = i + 1 {
    if a.children[i].uid != b.children[i].uid {
      return false
    }
  }
  true
}
