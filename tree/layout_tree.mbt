///|
/// LayoutTree - Manages layout nodes with parent references and dirty propagation

///|
/// Layout tree with parent tracking for dirty propagation
pub struct LayoutTree {
  root : LayoutNode
  // Map from node uid to parent uid (root has no entry)
  parent_map : Map[Int, Int]
  // Map from uid to node for fast lookup
  node_map : Map[Int, LayoutNode]
  // Viewport size
  mut viewport_width : Double
  mut viewport_height : Double
}

///|
/// Build parent and node maps recursively
fn build_maps(
  node : LayoutNode,
  parent_uid : Int?,
  parent_map : Map[Int, Int],
  node_map : Map[Int, LayoutNode],
) -> Unit {
  node_map[node.uid] = node
  match parent_uid {
    Some(pid) => parent_map[node.uid] = pid
    None => ()
  }
  for child in node.children {
    build_maps(child, Some(node.uid), parent_map, node_map)
  }
}

///|
pub fn LayoutTree::new(
  root : LayoutNode,
  viewport_width : Double,
  viewport_height : Double,
) -> LayoutTree {
  let parent_map : Map[Int, Int] = {}
  let node_map : Map[Int, LayoutNode] = {}
  build_maps(root, None, parent_map, node_map)
  { root, parent_map, node_map, viewport_width, viewport_height }
}

///|
/// Create tree from immutable Node
pub fn LayoutTree::from_node(
  node : @node.Node,
  viewport_width : Double,
  viewport_height : Double,
) -> LayoutTree {
  let root = LayoutNode::from_node(node)
  LayoutTree::new(root, viewport_width, viewport_height)
}

///|
/// Find a node by uid
pub fn LayoutTree::find_node(self : LayoutTree, uid : Int) -> LayoutNode? {
  self.node_map.get(uid)
}

///|
/// Get parent of a node
pub fn LayoutTree::get_parent(self : LayoutTree, uid : Int) -> LayoutNode? {
  match self.parent_map.get(uid) {
    Some(parent_uid) => self.node_map.get(parent_uid)
    None => None
  }
}

///|
/// Propagate children_dirty flag up to root
/// CSS Containment: contain: layout stops propagation since internal layout
/// changes don't affect ancestors
fn LayoutTree::propagate_children_dirty(
  self : LayoutTree,
  from_uid : Int,
) -> Unit {
  let mut current_uid = from_uid
  let mut done = false
  while not(done) {
    match self.parent_map.get(current_uid) {
      Some(parent_uid) =>
        match self.node_map.get(parent_uid) {
          Some(parent) =>
            // CSS Containment optimization: contain: layout isolates internal layout
            // When a node has layout containment, its internal changes don't affect
            // the layout of its ancestors, so we can stop dirty propagation here
            if parent.style.contain.layout {
              // Still mark this parent as children_dirty, but don't propagate further
              parent.mark_children_dirty()
              done = true
            } else if parent.children_dirty {
              done = true
            } else {
              parent.mark_children_dirty()
              current_uid = parent_uid
            }
          None => done = true
        }
      None => done = true
    }
  }
}

///|
/// Mark a node as dirty and propagate to ancestors
pub fn LayoutTree::mark_node_dirty(self : LayoutTree, uid : Int) -> Unit {
  match self.node_map.get(uid) {
    Some(node) => {
      node.mark_dirty()
      self.propagate_children_dirty(uid)
    }
    None => ()
  }
}

///|
/// Update viewport size and mark dependent nodes dirty
pub fn LayoutTree::resize_viewport(
  self : LayoutTree,
  width : Double,
  height : Double,
) -> Unit {
  let width_changed = (self.viewport_width - width).abs() > 0.001
  let height_changed = (self.viewport_height - height).abs() > 0.001
  self.viewport_width = width
  self.viewport_height = height

  // Only mark nodes that depend on viewport dimensions
  if width_changed || height_changed {
    mark_viewport_dependents_dirty(self.root, width_changed, height_changed)
  }
}

///|
/// Recursively mark nodes dirty if they depend on viewport dimensions
fn mark_viewport_dependents_dirty(
  node : LayoutNode,
  width_changed : Bool,
  height_changed : Bool,
) -> Unit {
  let deps = node.dependencies

  // Check if this node needs to be marked dirty
  let needs_dirty = match deps {
    // Static nodes never need re-layout from viewport changes
    Static => false
    // Viewport-dependent nodes (vw/vh) - always dirty on viewport change
    Viewport => true
    // For root-level nodes, parent dimensions come from viewport
    // ParentWidth/ParentHeight/ParentBoth depend on parent, which at root = viewport
    ParentWidth => width_changed
    ParentHeight => height_changed
    ParentBoth => width_changed || height_changed
    // Intrinsic nodes may need re-layout if children change
    Intrinsic => false
  }
  if needs_dirty {
    node.mark_dirty()
  }

  // Always recurse to children - they may have viewport dependencies
  for child in node.children {
    mark_viewport_dependents_dirty(child, width_changed, height_changed)
  }
}

///|
/// Check if any layout is needed
pub fn LayoutTree::needs_layout(self : LayoutTree) -> Bool {
  self.root.needs_layout()
}

///|
/// Clear all dirty flags in tree (after full layout)
fn clear_all_dirty(node : LayoutNode) -> Unit {
  node.clear_dirty()
  for child in node.children {
    clear_all_dirty(child)
  }
}

///|
/// Compute layout using existing layout system (full recomputation)
pub fn LayoutTree::compute_full(self : LayoutTree) -> @node.Layout {
  // Reset intrinsic cache for full recomputation
  @dispatch.reset_intrinsic_cache()
  let node = self.root.to_node()
  let ctx : @node.LayoutContext = {
    available_width: self.viewport_width,
    available_height: Some(self.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: self.viewport_width,
    viewport_height: self.viewport_height,
  }
  let result = @node.dispatch_layout(node, ctx)
  clear_all_dirty(self.root)
  result
}

///|
/// Compute layout with incremental optimization
/// Uses per-node caching for better performance
pub fn LayoutTree::compute_incremental(self : LayoutTree) -> @node.Layout {
  let stats = CacheStats::new()
  compute_tree_incremental(self, stats)
}
