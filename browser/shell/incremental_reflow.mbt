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
/// cached geometry. The dirty seed is the set of nodes whose own layout inputs
/// changed; `flow_dirty_uids` expands that seed for crater's absolute-geometry
/// cache so following in-flow siblings remain correct. The result is recorded as
/// the next reconcile baseline.
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
    Some(prev) => {
      let seeds = changed_seed_uids(node, prev)
      prev.reconcile_from(node, prev.flow_dirty_uids(seeds), vw, vh)
    }
    None => @layout.LayoutTree::from_node(node, vw, vh)
  }
  self.incremental_prev_tree = Some(tree)
  tree
}

///|
/// Directly changed layout-input uids, before flow-shift expansion.
fn changed_seed_uids(node : @node.Node, prev : @layout.LayoutTree) -> Array[Int] {
  let out : Array[Int] = []
  changed_seed_uids_into(node, prev, out)
  out
}

///|
fn changed_seed_uids_into(
  node : @node.Node,
  prev : @layout.LayoutTree,
  out : Array[Int],
) -> Unit {
  match prev.find_node(node.uid) {
    Some(old) =>
      if node_layout_input_changed(node, old) {
        out.push(node.uid)
      }
    None => ()
  }
  for child in node.children {
    changed_seed_uids_into(child, prev, out)
  }
}

///|
fn node_layout_input_changed(node : @node.Node, old : @layout.LayoutNode) -> Bool {
  !node.style.layout_eq(old.style) ||
  node.text != old.text ||
  node.src != old.src ||
  measure_presence_changed(node.measure, old.measure)
}

///|
fn measure_presence_changed(
  next : @layout_types.MeasureFunc?,
  old : @layout_types.MeasureFunc?,
) -> Bool {
  match (next, old) {
    (Some(_), Some(_)) => false
    (None, None) => false
    _ => true
  }
}
