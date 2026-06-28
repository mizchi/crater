///|
/// Opt in to incremental reflow on the dynamic-rendering path. When enabled,
/// re-renders after a DOM mutation reconcile the layout tree against the prior
/// one (reusing cached geometry via stable uids) instead of a full from-scratch
/// rebuild. Default off — when off the render path is byte-for-byte the current
/// behavior. See docs/incremental-reflow-design.md.
pub fn Browser::set_incremental_reflow(self : Browser, enabled : Bool) -> Unit {
  self.enable_incremental_reflow = enabled
}

///|
/// Build the layout tree for a freshly built render node tree.
///
/// Off (default): a plain `LayoutTree::from_node` — unchanged behavior, no
/// stabilization, no overhead.
///
/// On: stabilize uids against the persistent registry (so a node maps to the
/// same uid across rebuilds), then reconcile against the prior tree, migrating
/// cached geometry. The dirty set is currently *every* uid — correct (equivalent
/// to a full recompute) and end-to-end wired. The layout engine now memoizes
/// in-flow block subtrees per uid (block-flow memoization, see
/// docs/incremental-reflow-design.md), so a *narrower* dirty set here would let
/// unchanged block subtrees be reused — narrowing it (paint-only via the mutation
/// queue, or a layout-relevant `@style.Style` diff) is the remaining optimization
/// to realize that win on this path. The result is recorded as the next
/// reconcile baseline.
fn Browser::build_dynamic_layout_tree(
  self : Browser,
  node : @node.Node,
  vw : Double,
  vh : Double,
) -> @layout.LayoutTree {
  if !self.enable_incremental_reflow {
    return @layout.LayoutTree::from_node(node, vw, vh)
  }
  @node.stabilize_uids(node, self.uid_registry)
  let tree = match self.incremental_prev_tree {
    Some(prev) => prev.reconcile_from(node, collect_node_uids(node), vw, vh)
    None => @layout.LayoutTree::from_node(node, vw, vh)
  }
  self.incremental_prev_tree = Some(tree)
  tree
}

///|
/// Every uid in the tree, in document order.
fn collect_node_uids(node : @node.Node) -> Array[Int] {
  let out : Array[Int] = []
  collect_node_uids_into(node, out)
  out
}

///|
fn collect_node_uids_into(node : @node.Node, out : Array[Int]) -> Unit {
  out.push(node.uid)
  for child in node.children {
    collect_node_uids_into(child, out)
  }
}
