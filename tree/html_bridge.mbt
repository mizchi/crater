///|
/// HTML+CSS Bridge API
/// Provides differential updates from HTML/CSS changes to LayoutTree

// =============================================================================
// Tree Update Operations
// =============================================================================

///|
/// Represents a change to the layout tree
pub(all) enum TreeChange {
  AddNode(String, Int, LayoutNode) // parent_id, index, node
  RemoveNode(String) // node_id
  MoveNode(String, String, Int) // node_id, new_parent_id, index
  UpdateStyle(String) // node_id
  ReplaceChildren(String, Array[LayoutNode]) // node_id, children
}

// =============================================================================
// Style Update from CSS
// =============================================================================

///|
/// Apply computed CSS values to a LayoutNode's style
/// Returns true if any changes were made
pub fn LayoutNode::apply_css_values(
  self : LayoutNode,
  values : @cascade.CascadedValues,
) -> Bool {
  let mut changed = false

  // Width
  match values.get_value("width") {
    Some(v) =>
      match parse_dimension(v) {
        Some(dim) =>
          if self.style.width != dim {
            self.style.width = dim
            changed = true
          }
        None => ()
      }
    None => ()
  }

  // Height
  match values.get_value("height") {
    Some(v) =>
      match parse_dimension(v) {
        Some(dim) =>
          if self.style.height != dim {
            self.style.height = dim
            changed = true
          }
        None => ()
      }
    None => ()
  }

  // Display
  match values.get_value("display") {
    Some(v) =>
      match parse_display(v) {
        Some(d) =>
          if self.style.display != d {
            self.style.display = d
            changed = true
          }
        None => ()
      }
    None => ()
  }

  // Flex direction
  match values.get_value("flex-direction") {
    Some(v) =>
      match parse_flex_direction(v) {
        Some(d) =>
          if self.style.flex_direction != d {
            self.style.flex_direction = d
            changed = true
          }
        None => ()
      }
    None => ()
  }

  // Flex wrap
  match values.get_value("flex-wrap") {
    Some(v) =>
      match parse_flex_wrap(v) {
        Some(w) =>
          if self.style.flex_wrap != w {
            self.style.flex_wrap = w
            changed = true
          }
        None => ()
      }
    None => ()
  }

  // Flex grow
  match values.get_value("flex-grow") {
    Some(v) =>
      match try_parse_double(v) {
        Some(n) =>
          if (self.style.flex_grow - n).abs() > 0.0001 {
            self.style.flex_grow = n
            changed = true
          }
        None => ()
      }
    None => ()
  }

  // Flex shrink
  match values.get_value("flex-shrink") {
    Some(v) =>
      match try_parse_double(v) {
        Some(n) =>
          if (self.style.flex_shrink - n).abs() > 0.0001 {
            self.style.flex_shrink = n
            changed = true
          }
        None => ()
      }
    None => ()
  }

  // Justify content
  match values.get_value("justify-content") {
    Some(v) =>
      match parse_alignment(v) {
        Some(a) =>
          if self.style.justify_content != a {
            self.style.justify_content = a
            changed = true
          }
        None => ()
      }
    None => ()
  }

  // Align items
  match values.get_value("align-items") {
    Some(v) =>
      match parse_alignment(v) {
        Some(a) =>
          if self.style.align_items != a {
            self.style.align_items = a
            changed = true
          }
        None => ()
      }
    None => ()
  }

  // Margin (simplified - full implementation would handle all sides)
  match values.get_value("margin") {
    Some(v) =>
      match parse_dimension(v) {
        Some(@types.Length(n)) => {
          let new_margin = @types.Rect::all(@types.Length(n))
          self.style.margin = new_margin
          changed = true
        }
        _ => ()
      }
    None => ()
  }

  // Padding
  match values.get_value("padding") {
    Some(v) =>
      match parse_dimension(v) {
        Some(@types.Length(n)) => {
          let new_padding = @types.Rect::all(@types.Length(n))
          self.style.padding = new_padding
          changed = true
        }
        _ => ()
      }
    None => ()
  }

  // Gap
  match values.get_value("gap") {
    Some(v) =>
      match parse_dimension(v) {
        Some(@types.Length(n)) => {
          self.style.row_gap = @types.Length(n)
          self.style.column_gap = @types.Length(n)
          changed = true
        }
        _ => ()
      }
    None => ()
  }
  if changed {
    self.mark_dirty()
  }
  changed
}

// =============================================================================
// CSS Value Parsers (simplified)
// =============================================================================

///|
fn try_parse_double(s : String) -> Double? {
  Some(@strconv.parse_double(s)) catch {
    _ => None
  }
}

///|
fn parse_dimension(value : String) -> @types.Dimension? {
  let v = value.trim().to_string()
  if v == "auto" {
    return Some(@types.Auto)
  }
  if v.has_suffix("px") && v.length() > 2 {
    let num_str = v[:v.length() - 2].to_string() catch { _ => "" }
    match try_parse_double(num_str) {
      Some(n) => return Some(@types.Length(n))
      None => ()
    }
  }
  if v.has_suffix("%") && v.length() > 1 {
    let num_str = v[:v.length() - 1].to_string() catch { _ => "" }
    match try_parse_double(num_str) {
      Some(n) => return Some(@types.Percent(n / 100.0))
      None => ()
    }
  }
  // Try parsing as plain number (treat as px)
  match try_parse_double(v) {
    Some(n) => Some(@types.Length(n))
    None => None
  }
}

///|
fn parse_display(value : String) -> @style.Display? {
  match value.trim().to_string() {
    "block" => Some(@style.Block)
    "flex" => Some(@style.Flex)
    "inline-flex" => Some(@style.InlineFlex)
    "grid" => Some(@style.Grid)
    "inline-grid" => Some(@style.InlineGrid)
    "none" => Some(@style.None)
    _ => None
  }
}

///|
fn parse_flex_direction(value : String) -> @style.FlexDirection? {
  match value.trim().to_string() {
    "row" => Some(@style.Row)
    "row-reverse" => Some(@style.RowReverse)
    "column" => Some(@style.Column)
    "column-reverse" => Some(@style.ColumnReverse)
    _ => None
  }
}

///|
fn parse_flex_wrap(value : String) -> @style.FlexWrap? {
  match value.trim().to_string() {
    "nowrap" => Some(@style.NoWrap)
    "wrap" => Some(@style.Wrap)
    "wrap-reverse" => Some(@style.WrapReverse)
    _ => None
  }
}

///|
fn parse_alignment(value : String) -> @style.Alignment? {
  match value.trim().to_string() {
    "flex-start" | "start" => Some(@style.FlexStart)
    "flex-end" | "end" => Some(@style.FlexEnd)
    "center" => Some(@style.Center)
    "space-between" => Some(@style.SpaceBetween)
    "space-around" => Some(@style.SpaceAround)
    "space-evenly" => Some(@style.SpaceEvenly)
    "stretch" => Some(@style.Stretch)
    "baseline" => Some(@style.Baseline)
    _ => None
  }
}

// =============================================================================
// LayoutTree HTML Bridge
// =============================================================================

///|
/// Update a specific node's style and propagate dirty flags
pub fn LayoutTree::update_node_style(
  self : LayoutTree,
  node_id : String,
  values : @cascade.CascadedValues,
) -> Bool {
  // Find node by id
  let mut found_uid : Int? = None
  self.node_map.each(fn(uid, node) {
    if node.id == node_id {
      found_uid = Some(uid)
    }
  })
  match found_uid {
    Some(uid) =>
      match self.node_map.get(uid) {
        Some(node) => {
          let changed = node.apply_css_values(values)
          if changed {
            self.mark_node_dirty(uid)
          }
          changed
        }
        None => false
      }
    None => false
  }
}

///|
/// Batch update multiple nodes' styles
pub fn LayoutTree::batch_update_styles(
  self : LayoutTree,
  updates : Array[(String, @cascade.CascadedValues)],
) -> Int {
  let mut count = 0
  for update in updates {
    let (node_id, values) = update
    if self.update_node_style(node_id, values) {
      count += 1
    }
  }
  count
}

///|
/// Add a new node to the tree
pub fn LayoutTree::add_node(
  self : LayoutTree,
  parent_id : String,
  index : Int,
  node : LayoutNode,
) -> Bool {
  // Find parent by id
  let mut parent_uid : Int? = None
  self.node_map.each(fn(uid, n) {
    if n.id == parent_id {
      parent_uid = Some(uid)
    }
  })
  match parent_uid {
    Some(puid) =>
      match self.node_map.get(puid) {
        Some(parent) => {
          // Insert child at index
          let idx = if index < 0 {
            0
          } else if index > parent.children.length() {
            parent.children.length()
          } else {
            index
          }
          parent.children.insert(idx, node)

          // Update maps
          self.node_map[node.uid] = node
          self.parent_map[node.uid] = puid

          // Add all descendants to maps
          add_subtree_to_maps(node, puid, self.parent_map, self.node_map)

          // Mark parent dirty
          parent.mark_dirty()
          self.mark_node_dirty(puid)
          true
        }
        None => false
      }
    None => false
  }
}

///|
fn add_subtree_to_maps(
  node : LayoutNode,
  parent_uid : Int,
  parent_map : Map[Int, Int],
  node_map : Map[Int, LayoutNode],
) -> Unit {
  node_map[node.uid] = node
  parent_map[node.uid] = parent_uid
  for child in node.children {
    add_subtree_to_maps(child, node.uid, parent_map, node_map)
  }
}

///|
/// Remove a node from the tree
pub fn LayoutTree::remove_node(self : LayoutTree, node_id : String) -> Bool {
  // Find node by id
  let mut found_uid : Int? = None
  self.node_map.each(fn(uid, node) {
    if node.id == node_id {
      found_uid = Some(uid)
    }
  })
  match found_uid {
    Some(uid) =>
      match self.parent_map.get(uid) {
        Some(parent_uid) =>
          match self.node_map.get(parent_uid) {
            Some(parent) => {
              // Find and remove child
              let mut idx = -1
              for i, child in parent.children {
                if child.uid == uid {
                  idx = i
                  break
                }
              }
              if idx >= 0 {
                let _ = parent.children.remove(idx)

                // Remove from maps
                remove_subtree_from_maps(uid, self.parent_map, self.node_map)

                // Mark parent dirty
                parent.mark_dirty()
                self.mark_node_dirty(parent_uid)
                true
              } else {
                false
              }
            }
            None => false
          }
        None => false
      }
    None => false
  }
}

///|
fn remove_subtree_from_maps(
  uid : Int,
  parent_map : Map[Int, Int],
  node_map : Map[Int, LayoutNode],
) -> Unit {
  match node_map.get(uid) {
    Some(node) => {
      for child in node.children {
        remove_subtree_from_maps(child.uid, parent_map, node_map)
      }
      node_map.remove(uid)
      parent_map.remove(uid)
    }
    None => ()
  }
}

// =============================================================================
// HTML Element to LayoutNode Conversion
// =============================================================================

///|
/// Create a LayoutNode from HTML Element with computed styles
pub fn LayoutNode::from_html_element(
  element : @html.Element,
  computed_styles : @cascade.CascadedValues,
) -> LayoutNode {
  // Create node with element id or generate from tag
  let node_id = match element.id {
    Some(id) => id
    None => element.tag
  }
  let node = LayoutNode::create_with_id(node_id)

  // Apply computed styles
  let _ = node.apply_css_values(computed_styles)

  // Recursively convert children
  for html_child in element.children {
    match html_child {
      @html.Element(child_elem) => {
        // For now, use empty styles for children (should be computed separately)
        let child_node = LayoutNode::from_html_element(
          child_elem,
          @cascade.CascadedValues::new(),
        )
        let _ = node.add_child(child_node)

      }
      @html.Text(_) =>
        // Text nodes could be handled with MeasureFunc
        ()
    }
  }
  node
}

// =============================================================================
// Convenience Functions for Tree Building
// =============================================================================

///|
/// Build a complete LayoutTree from HTML Document with stylesheets
pub fn LayoutTree::from_html_document(
  doc : @html.Document,
  viewport_width : Double,
  viewport_height : Double,
) -> LayoutTree {
  // For now, create tree without CSS cascade (simplified)
  let root = LayoutNode::from_html_element(
    doc.root,
    @cascade.CascadedValues::new(),
  )
  LayoutTree::new(root, viewport_width, viewport_height)
}

///|
/// Find node by string id
pub fn LayoutTree::find_node_by_id(
  self : LayoutTree,
  node_id : String,
) -> LayoutNode? {
  let mut result : LayoutNode? = None
  self.node_map.each(fn(_uid, node) {
    if node.id == node_id {
      result = Some(node)
    }
  })
  result
}
