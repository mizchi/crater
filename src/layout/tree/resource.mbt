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
) -> @types.MeasureFunc {
  {
    func: fn(_available_width, _available_height) -> @types.IntrinsicSize {
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
