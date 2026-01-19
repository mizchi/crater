///|
/// DOM Bridge - Connects DomTree mutations to LayoutTree updates
///
/// This module provides the integration layer between the DOM and Layout systems,
/// enabling automatic layout updates when the DOM changes.

// =============================================================================
// Document: Unified DOM + Layout Container
// =============================================================================

///|
/// Document combines DomTree and LayoutTree with automatic synchronization
pub struct Document {
  /// The DOM tree (source of truth for structure)
  dom : @dom.DomTree
  /// The layout tree (computed layout)
  layout : LayoutTree
  /// Mapping from DOM NodeId to LayoutTree uid
  dom_to_layout : Map[Int, Int]
  /// Mapping from LayoutTree uid to DOM NodeId
  layout_to_dom : Map[Int, Int]
  /// Whether layout needs recomputation
  mut needs_layout : Bool
}

///|
/// Create a new Document with the given viewport dimensions
pub fn Document::new(
  viewport_width : Double,
  viewport_height : Double,
) -> Document {
  let dom = @dom.DomTree::new()
  // Create a minimal root LayoutNode
  let root_layout = LayoutNode::create_with_id("root")
  root_layout.style.width = @types.Percent(1.0)
  root_layout.style.height = @types.Percent(1.0)
  let layout = LayoutTree::new(root_layout, viewport_width, viewport_height)
  { dom, layout, dom_to_layout: {}, layout_to_dom: {}, needs_layout: false }
}

///|
/// Get the DomTree
pub fn Document::get_dom(self : Document) -> @dom.DomTree {
  self.dom
}

///|
/// Get the LayoutTree
pub fn Document::get_layout(self : Document) -> LayoutTree {
  self.layout
}

///|
/// Check if layout needs recomputation
pub fn Document::needs_layout(self : Document) -> Bool {
  self.needs_layout || self.layout.needs_layout()
}

///|
/// Process pending DOM mutations and apply them to the layout tree
/// Returns the number of mutations processed
pub fn Document::process_mutations(self : Document) -> Int {
  let (records, result) = self.dom.flush_mutations()
  if records.is_empty() {
    return 0
  }
  for record in records {
    self.apply_mutation(record)
  }
  if result.needs_layout {
    self.needs_layout = true
  }
  result.processed
}

///|
/// Compute layout if needed
pub fn Document::compute_layout(self : Document) -> @types.Layout {
  self.needs_layout = false
  if self.layout.needs_layout() {
    self.layout.compute_incremental()
  } else {
    self.layout.compute_full()
  }
}

///|
/// Force full layout recomputation
pub fn Document::compute_layout_full(self : Document) -> @types.Layout {
  self.needs_layout = false
  self.layout.compute_full()
}

///|
/// Resize viewport and trigger layout
pub fn Document::resize_viewport(
  self : Document,
  width : Double,
  height : Double,
) -> Unit {
  self.layout.resize_viewport(width, height)
  self.needs_layout = true
}

// =============================================================================
// Mutation Application
// =============================================================================

///|
/// Apply a single mutation record to the layout tree
fn Document::apply_mutation(
  self : Document,
  record : @dom.MutationRecord,
) -> Unit {
  match record.type_ {
    @dom.ChildList => self.apply_child_list_mutation(record)
    @dom.Attributes => self.apply_attributes_mutation(record)
    @dom.CharacterData => self.apply_character_data_mutation(record)
    @dom.StyleChange => self.apply_style_change_mutation(record)
  }
}

///|
/// Apply a ChildList mutation (add/remove children)
fn Document::apply_child_list_mutation(
  self : Document,
  record : @dom.MutationRecord,
) -> Unit {
  let parent_dom_id = record.target.to_int()
  // Handle added nodes
  for added in record.added_nodes {
    let child_dom_id = added.to_int()
    // Create a new LayoutNode for the added DOM node
    match self.create_layout_node_for_dom(child_dom_id) {
      Some(layout_node) =>
        // Find parent in layout tree
        match self.dom_to_layout.get(parent_dom_id) {
          Some(parent_uid) =>
            // Get parent's string id
            match self.layout.find_node(parent_uid) {
              Some(parent) => {
                // Add to parent's children
                parent.children.push(layout_node)
                // Register in maps
                self.dom_to_layout[child_dom_id] = layout_node.uid
                self.layout_to_dom[layout_node.uid] = child_dom_id
                // Update layout tree maps
                self.layout.node_map[layout_node.uid] = layout_node
                self.layout.parent_map[layout_node.uid] = parent_uid
                // Mark parent dirty
                self.layout.mark_node_dirty(parent_uid)
              }
              None => ()
            }
          None =>
            // Parent might be root (document node)
            if parent_dom_id == 0 {
              // Add to layout root
              self.layout.root.children.push(layout_node)
              self.dom_to_layout[child_dom_id] = layout_node.uid
              self.layout_to_dom[layout_node.uid] = child_dom_id
              self.layout.node_map[layout_node.uid] = layout_node
              self.layout.parent_map[layout_node.uid] = self.layout.root.uid
              self.layout.mark_node_dirty(self.layout.root.uid)
            }
        }
      None => ()
    }
  }
  // Handle removed nodes
  for removed in record.removed_nodes {
    let child_dom_id = removed.to_int()
    match self.dom_to_layout.get(child_dom_id) {
      Some(child_uid) =>
        // Remove from layout tree
        match self.layout.parent_map.get(child_uid) {
          Some(parent_uid) =>
            match self.layout.find_node(parent_uid) {
              Some(parent) => {
                // Find and remove child
                let mut idx = -1
                for i, child in parent.children {
                  if child.uid == child_uid {
                    idx = i
                    break
                  }
                }
                if idx >= 0 {
                  let _ = parent.children.remove(idx)
                  // Clean up maps
                  self.remove_from_maps(child_uid)
                  // Mark parent dirty
                  self.layout.mark_node_dirty(parent_uid)
                }
              }
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
}

///|
/// Apply an Attributes mutation
fn Document::apply_attributes_mutation(
  self : Document,
  record : @dom.MutationRecord,
) -> Unit {
  let dom_id = record.target.to_int()
  match self.dom_to_layout.get(dom_id) {
    Some(layout_uid) =>
      // Attribute changes might affect style
      match record.attribute_name {
        Some("style") | Some("class") =>
          // Would need to recompute CSS cascade
          // For now, just mark dirty
          self.layout.mark_node_dirty(layout_uid)
        _ => ()
      }
    None => ()
  }
}

///|
/// Apply a CharacterData mutation (text content change)
fn Document::apply_character_data_mutation(
  self : Document,
  record : @dom.MutationRecord,
) -> Unit {
  let dom_id = record.target.to_int()
  match self.dom_to_layout.get(dom_id) {
    Some(layout_uid) =>
      // Text content change affects intrinsic size
      self.layout.mark_node_dirty(layout_uid)
    None => ()
  }
}

///|
/// Apply a StyleChange mutation
fn Document::apply_style_change_mutation(
  self : Document,
  record : @dom.MutationRecord,
) -> Unit {
  let dom_id = record.target.to_int()
  match self.dom_to_layout.get(dom_id) {
    Some(layout_uid) =>
      // Style changed - mark dirty
      // In a full implementation, we would apply the specific property changes
      self.layout.mark_node_dirty(layout_uid)
    None => ()
  }
}

///|
/// Create a LayoutNode for a DOM node
fn Document::create_layout_node_for_dom(
  self : Document,
  dom_id : Int,
) -> LayoutNode? {
  let node_id = @dom.NodeId::from_int(dom_id)
  match self.dom.get_node_info(node_id) {
    Ok(info) => {
      let layout_id = dom_id.to_string()
      match info.node_type {
        @dom.Element => {
          let node = LayoutNode::create_with_id(layout_id)
          // Get tag name for element-specific styling
          match self.dom.get_tag_name(node_id) {
            Ok(tag) =>
              // Apply default styles based on tag
              apply_default_tag_styles(node, tag)
            Err(_) => ()
          }
          Some(node)
        }
        @dom.Text => {
          // Text nodes get a measure function for intrinsic sizing
          let node = LayoutNode::create_with_id(layout_id)
          // In a full implementation, would set up text measurement
          Some(node)
        }
        _ => None // Document, Comment nodes don't get layout nodes
      }
    }
    Err(_) => None
  }
}

///|
/// Remove a node and its descendants from the maps
fn Document::remove_from_maps(self : Document, uid : Int) -> Unit {
  match self.layout.node_map.get(uid) {
    Some(node) => {
      // Remove children first
      for child in node.children {
        self.remove_from_maps(child.uid)
      }
      // Remove from layout maps
      self.layout.node_map.remove(uid)
      self.layout.parent_map.remove(uid)
      // Remove from DOM<->Layout mapping
      match self.layout_to_dom.get(uid) {
        Some(dom_id) => {
          self.dom_to_layout.remove(dom_id)
          self.layout_to_dom.remove(uid)
        }
        None => ()
      }
    }
    None => ()
  }
}

///|
/// Apply default styles based on HTML tag
fn apply_default_tag_styles(node : LayoutNode, tag : String) -> Unit {
  match tag.to_lower() {
    "div"
    | "section"
    | "article"
    | "main"
    | "header"
    | "footer"
    | "nav"
    | "aside" => node.style.display = @types.Block
    "span" | "a" | "em" | "strong" | "b" | "i" =>
      node.style.display = @types.Block // Simplified
    "img" =>
      // Images have intrinsic sizing
      node.intrinsic_state = Some(
        Pending(placeholder_width=300.0, placeholder_height=150.0),
      )
    _ => ()
  }
}

// =============================================================================
// Convenience API for Document
// =============================================================================

///|
/// Create an element and add it to the document
pub fn Document::create_element(self : Document, tag : String) -> @dom.NodeId {
  self.dom.create_element(tag)
}

///|
/// Create a text node
pub fn Document::create_text(self : Document, content : String) -> @dom.NodeId {
  self.dom.create_text(content)
}

///|
/// Append a child to a parent
pub fn Document::append_child(
  self : Document,
  parent : @dom.NodeId,
  child : @dom.NodeId,
) -> Result[Unit, @dom.CoreError] {
  self.dom.append_child(parent, child)
}

///|
/// Set attribute on an element
pub fn Document::set_attribute(
  self : Document,
  node : @dom.NodeId,
  name : String,
  value : String,
) -> Result[Unit, @dom.CoreError] {
  self.dom.set_attribute(node, name, value)
}

///|
/// Set text content
pub fn Document::set_text_content(
  self : Document,
  node : @dom.NodeId,
  content : String,
) -> Result[Unit, @dom.CoreError] {
  self.dom.set_text_content(node, content)
}

///|
/// Get document root
pub fn Document::get_document_root(self : Document) -> @dom.NodeId {
  self.dom.get_document()
}

///|
/// Query selector
pub fn Document::query_selector(
  self : Document,
  selector : String,
) -> Result[@dom.NodeId?, @dom.CoreError] {
  self.dom.query_selector(self.dom.get_document(), selector)
}

///|
/// One-shot: Process mutations and compute layout
pub fn Document::update(self : Document) -> @types.Layout {
  let _ = self.process_mutations()
  self.compute_layout()
}
