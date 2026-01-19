///|
/// Resource management for intrinsic-sized elements (images, etc.)
/// Allows external systems to resolve sizes asynchronously

///|
/// Opaque resource identifier for external reference
pub(all) struct ResourceId(Int) derive(Eq, Hash, Show)

///|
/// State of an intrinsic resource
pub(all) enum IntrinsicState {
  /// Size resolved successfully
  Resolved(width~ : Double, height~ : Double)
  /// Size pending (using placeholder)
  Pending(placeholder_width~ : Double, placeholder_height~ : Double)
  /// Load failed
  Error
}

///|
/// HTML default placeholder size (per specification)
pub let default_placeholder_width : Double = 300.0

///|
pub let default_placeholder_height : Double = 150.0

///|
/// Error placeholder size (broken image icon)
pub let error_placeholder_width : Double = 24.0

///|
pub let error_placeholder_height : Double = 24.0

///|
/// Create a fixed MeasureFunc for intrinsic sizing
pub fn create_fixed_measure(
  width : Double,
  height : Double,
) -> @node.MeasureFunc {
  {
    func: fn(_available_width, _available_height) -> @node.IntrinsicSize {
      {
        min_width: width,
        max_width: width,
        min_height: height,
        max_height: height,
      }
    },
  }
}

///|
/// Resource registry - tracks pending resources and their associated nodes
pub struct ResourceRegistry {
  /// Counter for generating unique resource IDs
  mut next_id : Int
  /// Map from resource ID to node UIDs
  resource_nodes : Map[Int, Array[Int]]
  /// Set of pending resource IDs
  pending : @hashset.HashSet[Int]
}

///|
pub fn ResourceRegistry::new() -> ResourceRegistry {
  { next_id: 0, resource_nodes: {}, pending: @hashset.new() }
}

///|
/// Generate a new unique resource ID
pub fn ResourceRegistry::next_resource_id(
  self : ResourceRegistry,
) -> ResourceId {
  let id = self.next_id
  self.next_id += 1
  ResourceId(id)
}

///|
/// Associate a node UID with a resource ID
pub fn ResourceRegistry::add_node(
  self : ResourceRegistry,
  rid : ResourceId,
  node_uid : Int,
) -> Unit {
  let ResourceId(id) = rid
  match self.resource_nodes.get(id) {
    Some(nodes) => nodes.push(node_uid)
    None => self.resource_nodes[id] = [node_uid]
  }
}

///|
/// Mark a resource as pending (not yet resolved)
pub fn ResourceRegistry::mark_pending(
  self : ResourceRegistry,
  rid : ResourceId,
) -> Unit {
  let ResourceId(id) = rid
  self.pending.add(id)
}

///|
/// Mark a resource as resolved (size known)
pub fn ResourceRegistry::mark_resolved(
  self : ResourceRegistry,
  rid : ResourceId,
) -> Unit {
  let ResourceId(id) = rid
  self.pending.remove(id)
}

///|
/// Check if a resource is still pending
pub fn ResourceRegistry::is_pending(
  self : ResourceRegistry,
  rid : ResourceId,
) -> Bool {
  let ResourceId(id) = rid
  self.pending.contains(id)
}

///|
/// Get all node UIDs associated with a resource
pub fn ResourceRegistry::get_nodes(
  self : ResourceRegistry,
  rid : ResourceId,
) -> Array[Int] {
  let ResourceId(id) = rid
  match self.resource_nodes.get(id) {
    Some(nodes) => nodes
    None => []
  }
}

///|
/// Get all pending resource IDs
pub fn ResourceRegistry::get_all_pending(
  self : ResourceRegistry,
) -> Array[ResourceId] {
  self.pending.iter().map(fn(id) { ResourceId(id) }).collect()
}

// =============================================================================
// Standalone Resource Management Functions
// These allow decoupled resource management without using LayoutTree methods
// =============================================================================

///|
/// Register a new resource and set up a node with placeholder sizing
/// Returns the ResourceId for later resolution
pub fn register_node_resource(
  registry : ResourceRegistry,
  node : LayoutNode,
  propagate_dirty : (Int) -> Unit,
  placeholder_width? : Double = default_placeholder_width,
  placeholder_height? : Double = default_placeholder_height,
) -> ResourceId {
  let rid = registry.next_resource_id()
  registry.add_node(rid, node.uid)
  registry.mark_pending(rid)
  node.intrinsic_state = Some(Pending(placeholder_width~, placeholder_height~))
  node.measure = Some(
    create_fixed_measure(placeholder_width, placeholder_height),
  )
  node.mark_dirty()
  propagate_dirty(node.uid)
  rid
}

///|
/// Resolve a resource with its actual size and update all associated nodes
pub fn resolve_node_resource(
  registry : ResourceRegistry,
  find_node : (Int) -> LayoutNode?,
  propagate_dirty : (Int) -> Unit,
  rid : ResourceId,
  width : Double,
  height : Double,
) -> Unit {
  registry.mark_resolved(rid)
  let aspect = if height > 0.0 { Some(width / height) } else { None }
  for node_uid in registry.get_nodes(rid) {
    match find_node(node_uid) {
      Some(node) => {
        node.intrinsic_state = Some(Resolved(width~, height~))
        node.measure = Some(create_fixed_measure(width, height))
        match node.style.aspect_ratio {
          None => node.style.aspect_ratio = aspect
          Some(_) => ()
        }
        node.mark_dirty()
        propagate_dirty(node_uid)
      }
      None => ()
    }
  }
}

///|
/// Mark a resource as failed and update all associated nodes with error placeholder
pub fn fail_node_resource(
  registry : ResourceRegistry,
  find_node : (Int) -> LayoutNode?,
  propagate_dirty : (Int) -> Unit,
  rid : ResourceId,
) -> Unit {
  registry.mark_resolved(rid)
  for node_uid in registry.get_nodes(rid) {
    match find_node(node_uid) {
      Some(node) => {
        node.intrinsic_state = Some(Error)
        node.measure = Some(
          create_fixed_measure(
            error_placeholder_width, error_placeholder_height,
          ),
        )
        node.mark_dirty()
        propagate_dirty(node_uid)
      }
      None => ()
    }
  }
}
