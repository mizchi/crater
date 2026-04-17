///|
/// Create a document fragment node
pub fn DomTree::create_document_fragment(self : DomTree) -> NodeId {
  self.allocate_node(DomNode::new_document_fragment())
}

///|
/// Attach a new shadow root to a host element
pub fn DomTree::attach_shadow(
  self : DomTree,
  host : NodeId,
  mode : String,
) -> Result[NodeId, CoreError] {
  let shadow_root = self.create_document_fragment()
  match self.attach_existing_shadow_root(host, shadow_root, mode) {
    Ok(_) => Ok(shadow_root)
    Err(err) => {
      self.nodes.remove(shadow_root.to_int())
      Err(err)
    }
  }
}

///|
/// Mark an existing document fragment as the host's shadow root
pub fn DomTree::attach_existing_shadow_root(
  self : DomTree,
  host : NodeId,
  shadow_root : NodeId,
  mode : String,
) -> Result[Unit, CoreError] {
  let host_id = host.to_int()
  let shadow_id = shadow_root.to_int()
  match (self.nodes.get(host_id), self.nodes.get(shadow_id)) {
    (Some(host_node), Some(shadow_node)) => {
      if host_node.node_type != Element {
        return Err(
          InvalidOperation(message="Only element nodes can host shadow roots"),
        )
      }
      if host_node.shadow_root_id != None {
        return Err(InvalidOperation(message="Host already has a shadow root"))
      }
      if shadow_node.node_type != DocumentFragment &&
        shadow_node.node_type != ShadowRoot {
        return Err(
          InvalidOperation(
            message="Shadow root must be created from a document fragment",
          ),
        )
      }
      shadow_node.node_type = ShadowRoot
      shadow_node.tag_name = "#shadow-root"
      shadow_node.host_id = Some(host_id)
      shadow_node.shadow_mode = Some(mode)
      host_node.shadow_root_id = Some(shadow_id)
      self.mutations.push(MutationRecord::child_list(host, added=[shadow_root]))
      self.invalidate_layout(host_id)
      Ok(())
    }
    (None, _) => Err(NodeNotFound(node_id=host))
    (_, None) => Err(NodeNotFound(node_id=shadow_root))
  }
}

///|
/// Get shadow root for a host element
pub fn DomTree::get_shadow_root(
  self : DomTree,
  host : NodeId,
) -> Result[NodeId?, CoreError] {
  let id = host.to_int()
  match self.nodes.get(id) {
    Some(node) => Ok(node.shadow_root_id.map(NodeId::from_int))
    None => Err(NodeNotFound(node_id=host))
  }
}

///|
/// Get host for a shadow root
pub fn DomTree::get_host(
  self : DomTree,
  node : NodeId,
) -> Result[NodeId?, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(dom_node) => Ok(dom_node.host_id.map(NodeId::from_int))
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get shadow mode for a shadow root
pub fn DomTree::get_shadow_mode(
  self : DomTree,
  node : NodeId,
) -> Result[String?, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(dom_node) => Ok(dom_node.shadow_mode)
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get root node for a node
pub fn DomTree::get_root_node(
  self : DomTree,
  node : NodeId,
  composed? : Bool = false,
) -> Result[NodeId, CoreError] {
  let id = node.to_int()
  guard self.nodes.contains(id) else { return Err(NodeNotFound(node_id=node)) }
  let root_id = self.get_root_node_internal(id)
  if !composed {
    return Ok(NodeId::from_int(root_id))
  }
  match self.nodes.get(root_id) {
    Some(root) =>
      match root.host_id {
        Some(host_id) =>
          self.get_root_node(NodeId::from_int(host_id), composed=true)
        None => Ok(NodeId::from_int(root_id))
      }
    None => Err(NodeNotFound(node_id=NodeId::from_int(root_id)))
  }
}

///|
fn DomTree::get_root_node_internal(self : DomTree, node_id : Int) -> Int {
  match self.nodes.get(node_id) {
    Some(node) =>
      match node.parent_id {
        Some(parent_id) => self.get_root_node_internal(parent_id)
        None => node_id
      }
    None => node_id
  }
}

///|
fn DomTree::get_invalidation_parent_id(self : DomTree, node_id : Int) -> Int? {
  match self.nodes.get(node_id) {
    Some(node) =>
      match node.parent_id {
        Some(parent_id) => Some(parent_id)
        None => node.host_id
      }
    None => None
  }
}

///|
pub fn DomTree::has_shadow_roots(self : DomTree) -> Bool {
  for _, node in self.nodes {
    if node.node_type == ShadowRoot || node.shadow_root_id != None {
      return true
    }
  }
  false
}

///|
/// Whether a node is a slot element
pub fn DomTree::is_slot_element(self : DomTree, node : NodeId) -> Bool {
  match self.get_node_info(node) {
    Ok(info) =>
      match info.node_type {
        Element => info.node_name.to_lower() == "slot"
        _ => false
      }
    Err(_) => false
  }
}

///|
/// Return the composed children for a node in the current tree scope.
///
/// - Shadow hosts expose their shadow root children instead of light DOM children.
/// - Slot elements inside a shadow tree expose assigned light DOM nodes, falling
///   back to their own children when no assignment exists.
pub fn DomTree::get_composed_children(
  self : DomTree,
  node : NodeId,
  shadow_host? : NodeId? = None,
) -> Array[NodeId] {
  match self.get_shadow_root(node) {
    Ok(Some(shadow_root)) =>
      match self.get_children(shadow_root) {
        Ok(children) => children
        Err(_) => []
      }
    _ =>
      if shadow_host != None && self.is_slot_element(node) {
        self.get_assigned_nodes_for_slot(node, shadow_host.unwrap())
      } else {
        match self.get_children(node) {
          Ok(children) => children
          Err(_) => []
        }
      }
  }
}

///|
fn DomTree::get_slot_name_for_light_node(
  self : DomTree,
  node : NodeId,
) -> String {
  match self.get_attribute(node, "slot") {
    Ok(Some(value)) => value
    _ => ""
  }
}

///|
fn DomTree::find_first_slot_for_name(
  self : DomTree,
  root : NodeId,
  slot_name : String,
) -> NodeId? {
  if self.is_slot_element(root) {
    let current_name = match self.get_attribute(root, "name") {
      Ok(Some(value)) => value
      _ => ""
    }
    if current_name == slot_name {
      return Some(root)
    }
  }
  match self.get_children(root) {
    Ok(children) =>
      for child in children {
        match self.find_first_slot_for_name(child, slot_name) {
          Some(found) => return Some(found)
          None => ()
        }
      }
    Err(_) => ()
  }
  None
}

///|
fn DomTree::get_assigned_slot_for_light_node(
  self : DomTree,
  shadow_host : NodeId,
  node : NodeId,
) -> NodeId? {
  match self.get_parent(node) {
    Ok(Some(parent)) if parent == shadow_host =>
      match self.get_shadow_root(shadow_host) {
        Ok(Some(shadow_root)) =>
          self.find_first_slot_for_name(
            shadow_root,
            self.get_slot_name_for_light_node(node),
          )
        _ => None
      }
    _ => None
  }
}

///|
fn DomTree::get_assigned_nodes_for_slot(
  self : DomTree,
  slot : NodeId,
  shadow_host : NodeId,
) -> Array[NodeId] {
  let assigned : Array[NodeId] = []
  match self.get_children(shadow_host) {
    Ok(children) =>
      for child in children {
        match self.get_assigned_slot_for_light_node(shadow_host, child) {
          Some(target_slot) if target_slot == slot => assigned.push(child)
          _ => ()
        }
      }
    Err(_) => ()
  }
  if !assigned.is_empty() {
    return assigned
  }
  match self.get_children(slot) {
    Ok(children) => children
    Err(_) => []
  }
}
