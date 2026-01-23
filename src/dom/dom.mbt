///|
/// Core DOM Primitives
///
/// These are the fundamental DOM operations that all higher layers use.
/// No serialization, direct function calls only.
///
/// Design principles:
/// 1. Each operation is atomic and stateless
/// 2. No implicit side effects
/// 3. Suitable for WASM export
/// 4. Can be batched by higher layers

///|
/// DOM Tree - the core document structure
/// This is the single source of truth for all DOM operations
pub struct DomTree {
  /// Next available node ID
  mut next_id : Int
  /// All nodes indexed by ID
  nodes : Map[Int, DomNode]
  /// Root document node ID
  mut root_id : Int
  /// Currently focused node (for input)
  mut focused_node : Int?
  /// Mutation queue for batching changes
  mutations : MutationQueue
}

///|
/// Internal DOM node representation
struct DomNode {
  node_type : NodeType
  tag_name : String
  mut text_content : String
  attributes : Map[String, String]
  mut parent_id : Int?
  children : Array[Int]
  /// For elements: computed style cache
  mut cached_rect : Rect?
}

///|
fn DomNode::new(
  node_type : NodeType,
  tag_name : String,
  text_content? : String = "",
) -> DomNode {
  {
    node_type,
    tag_name,
    text_content,
    attributes: {},
    parent_id: None,
    children: [],
    cached_rect: None,
  }
}

///|
/// Create a new empty DOM tree
pub fn DomTree::new() -> DomTree {
  let tree : DomTree = {
    next_id: 1,
    nodes: {},
    root_id: 0,
    focused_node: None,
    mutations: MutationQueue::new(),
  }
  tree.nodes[0] = DomNode::new(Document, "#document")
  tree.root_id = 0
  tree
}

// =============================================================================
// Node Creation
// =============================================================================

///|
/// Create an element node
pub fn DomTree::create_element(self : DomTree, tag_name : String) -> NodeId {
  self.allocate_node(DomNode::new(Element, tag_name))
}

///|
/// Create a text node
pub fn DomTree::create_text(self : DomTree, content : String) -> NodeId {
  self.allocate_node(DomNode::new(Text, "#text", text_content=content))
}

///|
/// Create a comment node
pub fn DomTree::create_comment(self : DomTree, content : String) -> NodeId {
  self.allocate_node(DomNode::new(Comment, "#comment", text_content=content))
}

///|
fn DomTree::allocate_node(self : DomTree, node : DomNode) -> NodeId {
  let id = self.next_id
  self.next_id += 1
  self.nodes[id] = node
  NodeId(id)
}

// =============================================================================
// Tree Manipulation
// =============================================================================

///|
/// Append child to parent
pub fn DomTree::append_child(
  self : DomTree,
  parent : NodeId,
  child : NodeId,
) -> Result[Unit, CoreError] {
  let parent_id = parent.to_int()
  let child_id = child.to_int()
  match (self.nodes.get(parent_id), self.nodes.get(child_id)) {
    (Some(p), Some(c)) => {
      // Remove from old parent if any
      match c.parent_id {
        Some(old_parent_id) =>
          match self.nodes.get(old_parent_id) {
            Some(old_parent) => {
              let idx = old_parent.children.search(child_id)
              match idx {
                Some(i) => {
                  let _ = old_parent.children.remove(i)
                  // Record removal from old parent
                  self.mutations.push(
                    MutationRecord::child_list(NodeId(old_parent_id), removed=[
                      child,
                    ]),
                  )
                }
                None => ()
              }
            }
            None => ()
          }
        None => ()
      }
      // Set new parent
      c.parent_id = Some(parent_id)
      // Add to new parent's children
      p.children.push(child_id)
      // Record mutation
      self.mutations.push(MutationRecord::child_list(parent, added=[child]))
      // Invalidate layout cache
      self.invalidate_layout(parent_id)
      Ok(())
    }
    (None, _) => Err(NodeNotFound(node_id=parent))
    (_, None) => Err(NodeNotFound(node_id=child))
  }
}

///|
/// Insert child before reference node
pub fn DomTree::insert_before(
  self : DomTree,
  parent : NodeId,
  child : NodeId,
  reference : NodeId?,
) -> Result[Unit, CoreError] {
  let parent_id = parent.to_int()
  let child_id = child.to_int()
  match self.nodes.get(parent_id) {
    None => return Err(NodeNotFound(node_id=parent))
    Some(p) =>
      match self.nodes.get(child_id) {
        None => return Err(NodeNotFound(node_id=child))
        Some(c) => {
          // Remove from old parent
          match c.parent_id {
            Some(old_parent_id) =>
              match self.nodes.get(old_parent_id) {
                Some(old_parent) => {
                  let idx = old_parent.children.search(child_id)
                  match idx {
                    Some(i) => {
                      let _ = old_parent.children.remove(i)
                      // Record removal from old parent
                      self.mutations.push(
                        MutationRecord::child_list(NodeId(old_parent_id), removed=[
                          child,
                        ]),
                      )
                    }
                    None => ()
                  }
                }
                None => ()
              }
            None => ()
          }
          // Set new parent
          c.parent_id = Some(parent_id)
          // Insert at position
          match reference {
            Some(ref_node) => {
              let ref_id = ref_node.to_int()
              let idx = p.children.search(ref_id)
              match idx {
                Some(i) => p.children.insert(i, child_id)
                None => p.children.push(child_id) // Reference not found, append
              }
            }
            None => p.children.push(child_id) // No reference, append
          }
          // Record mutation
          self.mutations.push(MutationRecord::child_list(parent, added=[child]))
          self.invalidate_layout(parent_id)
          Ok(())
        }
      }
  }
}

///|
/// Remove child from parent
pub fn DomTree::remove_child(
  self : DomTree,
  parent : NodeId,
  child : NodeId,
) -> Result[Unit, CoreError] {
  let parent_id = parent.to_int()
  let child_id = child.to_int()
  match (self.nodes.get(parent_id), self.nodes.get(child_id)) {
    (Some(p), Some(c)) => {
      let idx = p.children.search(child_id)
      match idx {
        Some(i) => {
          let _ = p.children.remove(i)
          c.parent_id = None
          // Record mutation
          self.mutations.push(
            MutationRecord::child_list(parent, removed=[child]),
          )
          self.invalidate_layout(parent_id)
          Ok(())
        }
        None => Err(InvalidOperation(message="Child not found in parent"))
      }
    }
    (None, _) => Err(NodeNotFound(node_id=parent))
    (_, None) => Err(NodeNotFound(node_id=child))
  }
}

// =============================================================================
// Attribute Operations
// =============================================================================

///|
/// Set attribute on element
pub fn DomTree::set_attribute(
  self : DomTree,
  node : NodeId,
  name : String,
  value : String,
) -> Result[Unit, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => {
      let old_value = n.attributes.get(name)
      n.attributes[name] = value
      // Record mutation
      self.mutations.push(
        MutationRecord::attribute(node, name, old_value~, new_value=Some(value)),
      )
      self.invalidate_layout(id)
      Ok(())
    }
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get attribute from element
pub fn DomTree::get_attribute(
  self : DomTree,
  node : NodeId,
  name : String,
) -> Result[String?, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => Ok(n.attributes.get(name))
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Remove attribute from element
pub fn DomTree::remove_attribute(
  self : DomTree,
  node : NodeId,
  name : String,
) -> Result[Unit, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => {
      let old_value = n.attributes.get(name)
      n.attributes.remove(name)
      // Record mutation
      self.mutations.push(
        MutationRecord::attribute(node, name, old_value~, new_value=None),
      )
      self.invalidate_layout(id)
      Ok(())
    }
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get all attributes
pub fn DomTree::get_attributes(
  self : DomTree,
  node : NodeId,
) -> Result[Array[(String, String)], CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => {
      let attrs : Array[(String, String)] = []
      for name, value in n.attributes {
        attrs.push((name, value))
      }
      Ok(attrs)
    }
    None => Err(NodeNotFound(node_id=node))
  }
}

// =============================================================================
// Node Information
// =============================================================================

///|
/// Get node info
pub fn DomTree::get_node_info(
  self : DomTree,
  node : NodeId,
) -> Result[NodeInfo, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) =>
      Ok({
        node_id: node,
        node_type: n.node_type,
        node_name: n.tag_name,
        node_value: n.text_content,
        child_count: n.children.length(),
      })
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get tag name
pub fn DomTree::get_tag_name(
  self : DomTree,
  node : NodeId,
) -> Result[String, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => Ok(n.tag_name)
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get text content
pub fn DomTree::get_text_content(
  self : DomTree,
  node : NodeId,
) -> Result[String, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) =>
      match n.node_type {
        Text | Comment => Ok(n.text_content)
        _ => {
          // For elements, collect all descendant text
          let buf = StringBuilder::new()
          self.collect_text_content(id, buf)
          Ok(buf.to_string())
        }
      }
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Set text content
pub fn DomTree::set_text_content(
  self : DomTree,
  node : NodeId,
  content : String,
) -> Result[Unit, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => {
      match n.node_type {
        Text | Comment => {
          let old_value = n.text_content
          n.text_content = content
          // Record mutation
          self.mutations.push(
            MutationRecord::character_data(
              node,
              old_value=Some(old_value),
              new_value=Some(content),
            ),
          )
        }
        _ => {
          // For elements, remove all children and add text node
          // Record removal of existing children
          for child_id in n.children {
            self.mutations.push(
              MutationRecord::child_list(node, removed=[NodeId(child_id)]),
            )
          }
          n.children.clear()
          let text_node = self.create_text(content)
          let _ = self.append_child(node, text_node)

        }
      }
      self.invalidate_layout(id)
      Ok(())
    }
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Collect text content recursively
fn DomTree::collect_text_content(
  self : DomTree,
  node_id : Int,
  buf : StringBuilder,
) -> Unit {
  match self.nodes.get(node_id) {
    Some(n) =>
      match n.node_type {
        Text => buf.write_string(n.text_content)
        _ =>
          for child_id in n.children {
            self.collect_text_content(child_id, buf)
          }
      }
    None => ()
  }
}

// =============================================================================
// Tree Traversal
// =============================================================================

///|
/// Get document root
pub fn DomTree::get_document(self : DomTree) -> NodeId {
  NodeId(self.root_id)
}

///|
/// Get parent node
pub fn DomTree::get_parent(
  self : DomTree,
  node : NodeId,
) -> Result[NodeId?, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => Ok(n.parent_id.map(fn(x) { NodeId(x) }))
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get child nodes
pub fn DomTree::get_children(
  self : DomTree,
  node : NodeId,
) -> Result[Array[NodeId], CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => Ok(n.children.map(fn(x) { NodeId(x) }))
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get first child
pub fn DomTree::get_first_child(
  self : DomTree,
  node : NodeId,
) -> Result[NodeId?, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => Ok(n.children.get(0).map(NodeId::from_int))
    None => Err(NodeNotFound(node_id=node))
  }
}

///|
/// Get next sibling
pub fn DomTree::get_next_sibling(
  self : DomTree,
  node : NodeId,
) -> Result[NodeId?, CoreError] {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) =>
      match n.parent_id {
        Some(parent_id) =>
          match self.nodes.get(parent_id) {
            Some(parent) => {
              let idx = parent.children.search(id)
              match idx {
                Some(i) if i + 1 < parent.children.length() =>
                  Ok(Some(NodeId(parent.children[i + 1])))
                _ => Ok(None)
              }
            }
            None => Ok(None)
          }
        None => Ok(None)
      }
    None => Err(NodeNotFound(node_id=node))
  }
}

// =============================================================================
// Layout Cache
// =============================================================================

///|
/// Invalidate layout cache for node and ancestors
fn DomTree::invalidate_layout(self : DomTree, node_id : Int) -> Unit {
  match self.nodes.get(node_id) {
    Some(n) => {
      n.cached_rect = None
      match n.parent_id {
        Some(parent_id) => self.invalidate_layout(parent_id)
        None => ()
      }
    }
    None => ()
  }
}

///|
/// Set cached rect (called by layout engine)
pub fn DomTree::set_cached_rect(
  self : DomTree,
  node : NodeId,
  rect : Rect,
) -> Unit {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => n.cached_rect = Some(rect)
    None => ()
  }
}

///|
/// Get cached rect
pub fn DomTree::get_cached_rect(self : DomTree, node : NodeId) -> Rect? {
  let id = node.to_int()
  match self.nodes.get(id) {
    Some(n) => n.cached_rect
    None => None
  }
}

// =============================================================================
// Focus Management
// =============================================================================

///|
/// Set focused element
pub fn DomTree::set_focus(self : DomTree, node : NodeId?) -> Unit {
  self.focused_node = node.map(fn(x) { x.to_int() })
}

///|
/// Get focused element
pub fn DomTree::get_focus(self : DomTree) -> NodeId? {
  self.focused_node.map(fn(x) { NodeId(x) })
}

// =============================================================================
// Mutation Queue API
// =============================================================================

///|
/// Check if there are pending mutations
pub fn DomTree::has_pending_mutations(self : DomTree) -> Bool {
  not(self.mutations.is_empty())
}

///|
/// Get number of pending mutations
pub fn DomTree::pending_mutation_count(self : DomTree) -> Int {
  self.mutations.length()
}

///|
/// Flush pending mutations and return optimized records
/// Returns (records, result) where records is the optimized mutation list
/// and result contains statistics about the flush operation
pub fn DomTree::flush_mutations(
  self : DomTree,
) -> (Array[MutationRecord], FlushResult) {
  self.mutations.flush()
}

///|
/// Flush mutations with a custom handler for each record
/// Useful for applying mutations to other systems (e.g., LayoutTree)
pub fn[T] DomTree::flush_mutations_with(
  self : DomTree,
  handler : (MutationRecord) -> T,
) -> (Array[T], FlushResult) {
  self.mutations.flush_with(handler)
}

///|
/// Clear all pending mutations without processing
pub fn DomTree::clear_mutations(self : DomTree) -> Unit {
  self.mutations.clear()
}

///|
/// Get direct access to the mutation queue (for advanced use cases)
pub fn DomTree::get_mutation_queue(self : DomTree) -> MutationQueue {
  self.mutations
}
