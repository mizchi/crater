///|
/// HTML+CSS Bridge API
/// Compatibility wrapper around html_tree/style_bridge packages.

// =============================================================================
// Tree Update Operations
// =============================================================================

///|
/// Represents a change to the layout tree
pub(all) enum TreeChange {
  AddNode(String, Int, @tree.LayoutNode) // parent_id, index, node
  RemoveNode(String) // node_id
  MoveNode(String, String, Int) // node_id, new_parent_id, index
  UpdateStyle(String) // node_id
  ReplaceChildren(String, Array[@tree.LayoutNode]) // node_id, children
}

// =============================================================================
// Compatibility Wrappers
// =============================================================================

///|
pub fn apply_css_values(
  node : @tree.LayoutNode,
  values : @css.CascadedValues,
) -> Bool {
  @style_bridge.apply_css_values(node, values)
}

///|
pub fn update_node_style(
  tree : @tree.LayoutTree,
  node_id : String,
  values : @css.CascadedValues,
) -> Bool {
  @style_bridge.update_node_style(tree, node_id, values)
}

///|
pub fn batch_update_styles(
  tree : @tree.LayoutTree,
  updates : Array[(String, @css.CascadedValues)],
) -> Int {
  @style_bridge.batch_update_styles(tree, updates)
}

///|
pub fn add_node(
  tree : @tree.LayoutTree,
  parent_id : String,
  index : Int,
  node : @tree.LayoutNode,
) -> Bool {
  @style_bridge.add_node(tree, parent_id, index, node)
}

///|
pub fn remove_node(tree : @tree.LayoutTree, node_id : String) -> Bool {
  @style_bridge.remove_node(tree, node_id)
}

// =============================================================================
// Convenience Functions for Tree Building
// =============================================================================

///|
pub fn layout_node_from_html_element(
  element : @html.Element,
  computed_styles : @css.CascadedValues,
) -> @tree.LayoutNode {
  @html_tree.layout_node_from_html_element(element, computed_styles)
}

///|
pub fn layout_tree_from_html_document(
  doc : @html.Document,
  viewport_width : Double,
  viewport_height : Double,
) -> @tree.LayoutTree {
  @html_tree.layout_tree_from_html_document(
    doc, viewport_width, viewport_height,
  )
}
