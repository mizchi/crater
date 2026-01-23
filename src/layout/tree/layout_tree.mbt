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
  // Resource management for intrinsic-sized elements
  resources : ResourceRegistry
}

///|
/// Build parent and node maps recursively (without setting callbacks)
fn build_maps_internal(
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
    build_maps_internal(child, Some(node.uid), parent_map, node_map)
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
  build_maps_internal(root, None, parent_map, node_map)
  let tree : LayoutTree = {
    root,
    parent_map,
    node_map,
    viewport_width,
    viewport_height,
    resources: ResourceRegistry::new(),
  }
  // Set dirty callback on all nodes for proper parent propagation
  tree.setup_dirty_callbacks()
  tree
}

///|
/// Set up dirty callbacks on all nodes to propagate children_dirty to parents
fn LayoutTree::setup_dirty_callbacks(self : LayoutTree) -> Unit {
  self.node_map.each(fn(_uid, node) {
    node.on_dirty = Some(fn(uid) { self.propagate_children_dirty(uid) })
  })
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
/// Get the resource registry for external management
/// This allows decoupling resource management from LayoutTree
pub fn LayoutTree::get_resources(self : LayoutTree) -> ResourceRegistry {
  self.resources
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
pub fn LayoutTree::compute_full(self : LayoutTree) -> @types.Layout {
  // Reset intrinsic cache for full recomputation
  @dispatch.reset_intrinsic_cache()
  let node = self.root.to_node()
  let ctx : @types.LayoutContext = {
    available_width: self.viewport_width,
    available_height: Some(self.viewport_height),
    sizing_mode: @types.Definite,
    viewport_width: self.viewport_width,
    viewport_height: self.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }
  let result = @dispatch.compute_layout(node, ctx)
  clear_all_dirty(self.root)
  result
}

///|
/// Compute layout with incremental optimization
/// Uses per-node caching for better performance
pub fn LayoutTree::compute_incremental(self : LayoutTree) -> @types.Layout {
  let stats = CacheStats::new()
  compute_tree_incremental(self, stats)
}

// =============================================================================
// Resource Management API
// =============================================================================

///|
/// Register a pending resource for an intrinsic-sized element (e.g., image)
/// Returns a ResourceId that can be used to resolve the size later
pub fn LayoutTree::register_resource(
  self : LayoutTree,
  node_uid : Int,
  placeholder_width? : Double = 300.0,
  placeholder_height? : Double = 150.0,
) -> ResourceId {
  let rid = self.resources.next_resource_id()
  self.resources.add_node(rid, node_uid)
  self.resources.mark_pending(rid)

  // Set up the node with placeholder measure
  match self.node_map.get(node_uid) {
    Some(node) => {
      node.intrinsic_state = Some(
        Pending(placeholder_width~, placeholder_height~),
      )
      node.measure = Some(
        create_fixed_measure(placeholder_width, placeholder_height),
      )
      node.mark_dirty()
      self.propagate_children_dirty(node_uid)
    }
    None => ()
  }
  rid
}

///|
/// Attach an additional node to an existing resource (for shared resources like same src)
pub fn LayoutTree::attach_resource(
  self : LayoutTree,
  rid : ResourceId,
  node_uid : Int,
  placeholder_width? : Double = 300.0,
  placeholder_height? : Double = 150.0,
) -> Unit {
  self.resources.add_node(rid, node_uid)

  // Set up the node with placeholder measure
  match self.node_map.get(node_uid) {
    Some(node) => {
      node.intrinsic_state = Some(
        Pending(placeholder_width~, placeholder_height~),
      )
      node.measure = Some(
        create_fixed_measure(placeholder_width, placeholder_height),
      )
      node.mark_dirty()
      self.propagate_children_dirty(node_uid)
    }
    None => ()
  }
}

///|
/// Resolve a resource with its actual size
pub fn LayoutTree::resolve_resource(
  self : LayoutTree,
  rid : ResourceId,
  width : Double,
  height : Double,
) -> Unit {
  self.resources.mark_resolved(rid)
  let aspect = if height > 0.0 { Some(width / height) } else { None }
  for node_uid in self.resources.get_nodes(rid) {
    match self.node_map.get(node_uid) {
      Some(node) => {
        node.intrinsic_state = Some(Resolved(width~, height~))
        node.measure = Some(create_fixed_measure(width, height))
        // Only set aspect-ratio if not already specified by CSS
        match node.style.aspect_ratio {
          None => node.style.aspect_ratio = aspect
          Some(_) => () // CSS takes precedence
        }
        node.mark_dirty()
        self.propagate_children_dirty(node_uid)
      }
      None => ()
    }
  }
}

///|
/// Mark a resource as failed (e.g., image load error)
pub fn LayoutTree::fail_resource(self : LayoutTree, rid : ResourceId) -> Unit {
  self.resources.mark_resolved(rid)
  for node_uid in self.resources.get_nodes(rid) {
    match self.node_map.get(node_uid) {
      Some(node) => {
        node.intrinsic_state = Some(Error)
        node.measure = Some(
          create_fixed_measure(
            error_placeholder_width, error_placeholder_height,
          ),
        )
        node.mark_dirty()
        self.propagate_children_dirty(node_uid)
      }
      None => ()
    }
  }
}

///|
/// Check if a resource is still pending
pub fn LayoutTree::is_resource_pending(
  self : LayoutTree,
  rid : ResourceId,
) -> Bool {
  self.resources.is_pending(rid)
}

///|
/// Get all pending resources
pub fn LayoutTree::get_pending_resources(
  self : LayoutTree,
) -> Array[ResourceId] {
  self.resources.get_all_pending()
}

///|
/// Scan the tree for nodes with Pending intrinsic state and register them as resources
/// Returns a map from uid (as string) to ResourceId
/// This is useful after building a tree from HTML to register all pending images
pub fn LayoutTree::register_pending_images(
  self : LayoutTree,
) -> Map[String, ResourceId] {
  let uid_to_rid : Map[String, ResourceId] = {}
  self.node_map.each(fn(_uid, node) {
    match node.intrinsic_state {
      Some(Pending(_)) => {
        // This node needs a resource
        let key = node.uid.to_string()
        match uid_to_rid.get(key) {
          Some(_) => () // Already registered
          None => {
            // New resource - register it
            let rid = self.resources.next_resource_id()
            self.resources.add_node(rid, node.uid)
            self.resources.mark_pending(rid)
            uid_to_rid[key] = rid
          }
        }
      }
      _ => ()
    }
  })
  uid_to_rid
}

///|
/// Scan the tree for nodes with Pending intrinsic state and register them as resources
/// Uses provided src->uid mapping to share resources for same src
/// Returns a map from src to ResourceId
pub fn LayoutTree::register_pending_images_with_src(
  self : LayoutTree,
  uid_to_src : Map[Int, String],
) -> Map[String, ResourceId] {
  let src_to_rid : Map[String, ResourceId] = {}
  self.node_map.each(fn(uid, node) {
    match node.intrinsic_state {
      Some(Pending(_)) =>
        // Get src for this node
        match uid_to_src.get(uid) {
          Some(src) =>
            match src_to_rid.get(src) {
              Some(rid) =>
                // Already have a resource for this src, attach this node
                self.resources.add_node(rid, node.uid)
              None => {
                // New resource - register it
                let rid = self.resources.next_resource_id()
                self.resources.add_node(rid, node.uid)
                self.resources.mark_pending(rid)
                src_to_rid[src] = rid
              }
            }
          None => {
            // No src mapping, use uid as key
            let key = uid.to_string()
            let rid = self.resources.next_resource_id()
            self.resources.add_node(rid, node.uid)
            self.resources.mark_pending(rid)
            src_to_rid[key] = rid
          }
        }
      _ => ()
    }
  })
  src_to_rid
}

// =============================================================================
// Dirty Region Collection
// =============================================================================

///|
/// Collect bounding rects of all nodes that have new layouts
/// Returns absolute positions (relative to viewport origin)
/// Use this after calculate_layout() to get regions that need redrawing
pub fn LayoutTree::collect_dirty_rects(
  self : LayoutTree,
) -> Array[@types.BoundingRect] {
  let rects : Array[@types.BoundingRect] = []
  collect_dirty_rects_recursive(self.root, 0.0, 0.0, rects)
  rects
}

///|
/// Recursively collect dirty rects with absolute positioning
fn collect_dirty_rects_recursive(
  node : LayoutNode,
  offset_x : Double,
  offset_y : Double,
  rects : Array[@types.BoundingRect],
) -> Unit {
  let abs_x = offset_x + node.computed_x
  let abs_y = offset_y + node.computed_y
  if node.has_new_layout {
    rects.push(
      @types.BoundingRect::new(
        abs_x,
        abs_y,
        node.computed_width,
        node.computed_height,
      ),
    )
  }

  // Recurse to children
  for child in node.children {
    collect_dirty_rects_recursive(child, abs_x, abs_y, rects)
  }
}

///|
/// Collect dirty rects and merge overlapping ones into a single union rect
/// More efficient when many small regions change
pub fn LayoutTree::collect_dirty_union(
  self : LayoutTree,
) -> @types.BoundingRect? {
  let rects = self.collect_dirty_rects()
  if rects.length() == 0 {
    return None
  }
  let mut union = rects[0]
  for i = 1; i < rects.length(); i = i + 1 {
    union = union.union(rects[i])
  }
  Some(union)
}

///|
/// Mark all nodes' layouts as seen (clear has_new_layout flags)
/// Call this after processing dirty regions
pub fn LayoutTree::mark_all_layouts_seen(self : LayoutTree) -> Unit {
  mark_layouts_seen_recursive(self.root)
}

///|
fn mark_layouts_seen_recursive(node : LayoutNode) -> Unit {
  node.has_new_layout = false
  for child in node.children {
    mark_layouts_seen_recursive(child)
  }
}
