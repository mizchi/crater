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
/// A deterministic geometry signature of the current render's layout boxes —
/// `id:x,y,w,h` per box in document order — for VRT-style comparison of the
/// dynamic reflow path. Forces a render so the layout tree reflects the current
/// DOM, then flattens the absolute box geometry. Two snapshots being equal means
/// the rendered layout is geometrically identical (the property a paint VRT
/// checks), so an incremental re-render can be diffed against a full rebuild.
pub fn Browser::layout_box_snapshot(self : Browser) -> String {
  let _ = self.render_text_full_page()
  match self.layout_tree {
    Some(tree) => {
      let layout = tree.compute_incremental()
      let buf = StringBuilder::new()
      for b in @vrt.collect_layout_boxes(layout) {
        buf.write_string(b.id)
        buf.write_string(":")
        buf.write_string(b.x.to_string())
        buf.write_string(",")
        buf.write_string(b.y.to_string())
        buf.write_string(",")
        buf.write_string(b.width.to_string())
        buf.write_string(",")
        buf.write_string(b.height.to_string())
        buf.write_string(";")
      }
      buf.to_string()
    }
    None => ""
  }
}

///|
/// Build the layout tree for a freshly built render node tree.
///
/// Off (default): a plain `LayoutTree::from_node` — unchanged behavior, no
/// stabilization, no overhead.
///
/// On: stabilize uids against the persistent registry (so a node maps to the
/// same uid across rebuilds), then reconcile against the prior tree, migrating
/// cached geometry. The dirty seed is the set of persisted uids whose layout
/// inputs actually changed — computed `@style.Style` (compared with
/// `Style::layout_eq`, which ignores paint-only fields), text, image `src`, or
/// measure presence — expanded by `flow_dirty_uids` for crater's
/// absolute-geometry flow shift. `reconcile_from` adds structural changes (add /
/// remove / move) on top. Everything else stays clean, so the layout engine's
/// per-uid + block-flow memoization reuses it. Node and layout trees are recorded
/// as the next reconcile baseline.
///
/// Correctness rests on the seed being a superset of the changed nodes. The
/// comparison is against the *computed* (post-cascade) style, so a mutation that
/// changes an un-mutated node's style via a selector combinator (`:has()`, `+`,
/// `~`, `:nth-child`) is still caught. A measure-func *value* change with no
/// src/style change (rare; closures aren't comparable) is the one residual.
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
  let tree = match (self.incremental_prev_tree, self.incremental_prev_node) {
    (Some(prev), Some(prev_node)) => {
      let prev_by_uid : Map[Int, @node.Node] = {}
      index_nodes_by_uid(prev_node, prev_by_uid)
      let seeds : Array[Int] = []
      collect_changed_seed_uids(node, prev_by_uid, seeds)
      prev.reconcile_from(node, prev.flow_dirty_uids(seeds), vw, vh)
    }
    // First dynamic render (or a reset baseline): nothing to reconcile against.
    _ => @layout.LayoutTree::from_node(node, vw, vh)
  }
  self.incremental_prev_tree = Some(tree)
  self.incremental_prev_node = Some(node)
  tree
}

///|
/// Index a render-node tree by uid (document order).
fn index_nodes_by_uid(node : @node.Node, out : Map[Int, @node.Node]) -> Unit {
  out[node.uid] = node
  for child in node.children {
    index_nodes_by_uid(child, out)
  }
}

///|
/// Whether two render nodes have the same layout inputs: computed style (via
/// `Style::layout_eq`, paint-only fields ignored), text, image src, and measure
/// presence. (Measure-func value equality isn't decidable — closures — so a
/// same-src/same-style intrinsic change is not detected here.)
fn node_layout_inputs_equal(a : @node.Node, b : @node.Node) -> Bool {
  a.style.layout_eq(b.style) &&
  a.text == b.text &&
  a.src == b.src &&
  (a.measure is Some(_)) == (b.measure is Some(_))
}

///|
/// Seed the dirty set with every persisted uid (present in `prev_by_uid`) whose
/// layout inputs changed. New uids are not seeded here — `reconcile_from` keeps
/// them dirty (no prior match) and structurally dirties their parent; removed
/// uids likewise dirty their parent structurally.
fn collect_changed_seed_uids(
  node : @node.Node,
  prev_by_uid : Map[Int, @node.Node],
  seeds : Array[Int],
) -> Unit {
  match prev_by_uid.get(node.uid) {
    Some(prev) =>
      if !node_layout_inputs_equal(node, prev) {
        seeds.push(node.uid)
      }
    None => ()
  }
  for child in node.children {
    collect_changed_seed_uids(child, prev_by_uid, seeds)
  }
}
