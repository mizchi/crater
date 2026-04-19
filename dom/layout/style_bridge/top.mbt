///|
/// Layout style bridge
/// Applies cascaded CSS values and structural tree mutations to LayoutTree.

// =============================================================================
// Style Update from CSS
// =============================================================================

///|
/// Apply computed CSS values to a LayoutNode's style.
/// Returns true if any changes were made.
pub fn apply_css_values(
  node : @tree.LayoutNode,
  values : @css.CascadedValues,
) -> Bool {
  let mut changed = false

  match values.get_value("width") {
    Some(v) =>
      match parse_dimension(v) {
        Some(dim) =>
          if node.style.width != dim {
            node.style.width = dim
            changed = true
          }
        None => ()
      }
    None => ()
  }

  match values.get_value("height") {
    Some(v) =>
      match parse_dimension(v) {
        Some(dim) =>
          if node.style.height != dim {
            node.style.height = dim
            changed = true
          }
        None => ()
      }
    None => ()
  }

  match values.get_value("display") {
    Some(v) =>
      match parse_display(v) {
        Some(d) =>
          if node.style.display != d {
            node.style.display = d
            changed = true
          }
        None => ()
      }
    None => ()
  }

  match values.get_value("flex-direction") {
    Some(v) =>
      match parse_flex_direction(v) {
        Some(d) =>
          if node.style.flex_direction != d {
            node.style.flex_direction = d
            changed = true
          }
        None => ()
      }
    None => ()
  }

  match values.get_value("flex-wrap") {
    Some(v) =>
      match parse_flex_wrap(v) {
        Some(w) =>
          if node.style.flex_wrap != w {
            node.style.flex_wrap = w
            changed = true
          }
        None => ()
      }
    None => ()
  }

  match values.get_value("flex-grow") {
    Some(v) =>
      match try_parse_double(v) {
        Some(n) =>
          if (node.style.flex_grow - n).abs() > 0.0001 {
            node.style.flex_grow = n
            changed = true
          }
        None => ()
      }
    None => ()
  }

  match values.get_value("flex-shrink") {
    Some(v) =>
      match try_parse_double(v) {
        Some(n) =>
          if (node.style.flex_shrink - n).abs() > 0.0001 {
            node.style.flex_shrink = n
            changed = true
          }
        None => ()
      }
    None => ()
  }

  match values.get_value("justify-content") {
    Some(v) =>
      match parse_alignment(v) {
        Some(a) =>
          if node.style.justify_content != a {
            node.style.justify_content = a
            changed = true
          }
        None => ()
      }
    None => ()
  }

  match values.get_value("align-items") {
    Some(v) =>
      match parse_alignment(v) {
        Some(a) =>
          if node.style.align_items != a {
            node.style.align_items = a
            changed = true
          }
        None => ()
      }
    None => ()
  }

  match values.get_value("margin") {
    Some(v) =>
      match parse_dimension(v) {
        Some(@types.Length(n)) => {
          let new_margin = @types.Rect::all(@types.Dimension::Length(n))
          node.style.margin = new_margin
          changed = true
        }
        _ => ()
      }
    None => ()
  }

  match values.get_value("padding") {
    Some(v) =>
      match parse_dimension(v) {
        Some(@types.Length(n)) => {
          let new_padding = @types.Rect::all(@types.Dimension::Length(n))
          node.style.padding = new_padding
          changed = true
        }
        _ => ()
      }
    None => ()
  }

  match values.get_value("gap") {
    Some(v) =>
      match parse_dimension(v) {
        Some(@types.Length(n)) => {
          node.style.row_gap = @types.Length(n)
          node.style.column_gap = @types.Length(n)
          changed = true
        }
        _ => ()
      }
    None => ()
  }

  if changed {
    node.mark_dirty()
  }
  changed
}

// =============================================================================
// CSS Value Parsers (simplified)
// =============================================================================

///|
fn try_parse_double(s : String) -> Double? {
  Some(@string.parse_double(s)) catch {
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
    let num_str = v.unsafe_substring(start=0, end=v.length() - 2)
    match try_parse_double(num_str) {
      Some(n) => return Some(@types.Length(n))
      None => ()
    }
  }
  if v.has_suffix("%") && v.length() > 1 {
    let num_str = v.unsafe_substring(start=0, end=v.length() - 1)
    match try_parse_double(num_str) {
      Some(n) => return Some(@types.Percent(n / 100.0))
      None => ()
    }
  }
  match try_parse_double(v) {
    Some(n) => Some(@types.Length(n))
    None => None
  }
}

///|
fn parse_display(value : String) -> @types.Display? {
  match value.trim().to_string() {
    "block" => Some(@types.Block)
    "flex" => Some(@types.Flex)
    "inline-flex" => Some(@types.InlineFlex)
    "grid" => Some(@types.Grid)
    "inline-grid" => Some(@types.InlineGrid)
    "none" => Some(@types.Display::None)
    _ => None
  }
}

///|
fn parse_flex_direction(value : String) -> @types.FlexDirection? {
  match value.trim().to_string() {
    "row" => Some(@types.Row)
    "row-reverse" => Some(@types.RowReverse)
    "column" => Some(@types.Column)
    "column-reverse" => Some(@types.ColumnReverse)
    _ => None
  }
}

///|
fn parse_flex_wrap(value : String) -> @types.FlexWrap? {
  match value.trim().to_string() {
    "nowrap" => Some(@types.NoWrap)
    "wrap" => Some(@types.Wrap)
    "wrap-reverse" => Some(@types.WrapReverse)
    _ => None
  }
}

///|
fn parse_alignment(value : String) -> @types.Alignment? {
  match value.trim().to_string() {
    "flex-start" | "start" => Some(@types.FlexStart)
    "flex-end" | "end" => Some(@types.FlexEnd)
    "center" => Some(@types.Center)
    "space-between" => Some(@types.SpaceBetween)
    "space-around" => Some(@types.SpaceAround)
    "space-evenly" => Some(@types.SpaceEvenly)
    "stretch" => Some(@types.Stretch)
    "baseline" => Some(@types.Baseline)
    _ => None
  }
}

// =============================================================================
// LayoutTree Mutation Helpers
// =============================================================================

///|
/// Update a specific node's style and propagate dirty flags.
pub fn update_node_style(
  tree : @tree.LayoutTree,
  node_id : String,
  values : @css.CascadedValues,
) -> Bool {
  match tree.find_node_by_id(node_id) {
    Some(node) => {
      let changed = apply_css_values(node, values)
      if changed {
        tree.mark_node_dirty(node.uid)
      }
      changed
    }
    None => false
  }
}

///|
/// Batch update multiple nodes' styles.
pub fn batch_update_styles(
  tree : @tree.LayoutTree,
  updates : Array[(String, @css.CascadedValues)],
) -> Int {
  let mut count = 0
  for update in updates {
    let (node_id, values) = update
    if update_node_style(tree, node_id, values) {
      count += 1
    }
  }
  count
}

///|
/// Add a new node to the tree.
pub fn add_node(
  tree : @tree.LayoutTree,
  parent_id : String,
  index : Int,
  node : @tree.LayoutNode,
) -> Bool {
  match tree.find_node_by_id(parent_id) {
    Some(parent) => {
      let idx = if index < 0 {
        0
      } else if index > parent.children.length() {
        parent.children.length()
      } else {
        index
      }
      parent.children.insert(idx, node)
      tree.node_map[node.uid] = node
      tree.parent_map[node.uid] = parent.uid
      add_subtree_to_maps(node, parent.uid, tree.parent_map, tree.node_map)
      parent.mark_dirty()
      tree.mark_node_dirty(parent.uid)
      true
    }
    None => false
  }
}

///|
fn add_subtree_to_maps(
  node : @tree.LayoutNode,
  parent_uid : Int,
  parent_map : Map[Int, Int],
  node_map : Map[Int, @tree.LayoutNode],
) -> Unit {
  node_map[node.uid] = node
  parent_map[node.uid] = parent_uid
  for child in node.children {
    add_subtree_to_maps(child, node.uid, parent_map, node_map)
  }
}

///|
/// Remove a node from the tree.
pub fn remove_node(tree : @tree.LayoutTree, node_id : String) -> Bool {
  match tree.find_node_by_id(node_id) {
    Some(node) =>
      match tree.parent_map.get(node.uid) {
        Some(parent_uid) =>
          match tree.node_map.get(parent_uid) {
            Some(parent) => {
              let mut idx = -1
              for i, child in parent.children {
                if child.uid == node.uid {
                  idx = i
                  break
                }
              }
              if idx >= 0 {
                let _ = parent.children.remove(idx)
                remove_subtree_from_maps(
                  node.uid,
                  tree.parent_map,
                  tree.node_map,
                )
                parent.mark_dirty()
                tree.mark_node_dirty(parent_uid)
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
  node_map : Map[Int, @tree.LayoutNode],
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
