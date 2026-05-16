///|
/// Bridge between the layout engine's `LayoutTree` / `LayoutNode` and
/// the AOM. Lives in the dom/layout bridge layer so that
/// `mizchi/crater-dom/aom` itself does not need a `mizchi/crater-layout`
/// dependency. Consumers that work with `@core.Layout` (renderer output,
/// pure data) can call `@aom.build_accessibility_tree_with_node_layout`
/// directly without touching this module.

///|
/// Extract bounds from a LayoutTree into a `(source_id -> Bounds)` map.
/// Uses each layout node's id as the AOM lookup key.
pub fn extract_bounds_from_layout(
  layout_tree : @layout.LayoutTree,
) -> Map[String, @aom.Bounds] {
  let bounds_map : Map[String, @aom.Bounds] = {}
  extract_bounds_recursive(layout_tree.root, bounds_map)
  bounds_map
}

///|
fn extract_bounds_recursive(
  node : @layout.LayoutNode,
  bounds_map : Map[String, @aom.Bounds],
) -> Unit {
  if !node.id.is_empty() {
    let bounds = @aom.Bounds::new(
      node.computed_x,
      node.computed_y,
      node.computed_width,
      node.computed_height,
    )
    bounds_map[node.id] = bounds
    let source_id = extract_element_id(node.id)
    if !source_id.is_empty() {
      bounds_map[source_id] = bounds
    }
  }
  for child in node.children {
    extract_bounds_recursive(child, bounds_map)
  }
}

///|
/// Extract the element id portion from a renderer-style node id of the
/// form `tag#id` / `tag.class` / `tag`. Returns the empty string when
/// no `#id` segment is present.
fn extract_element_id(node_id : String) -> String {
  match node_id.find("#") {
    Some(idx) => node_id.unsafe_substring(start=idx + 1, end=node_id.length())
    None => ""
  }
}

///|
/// Build AccessibilityTree from HTML and attach layout bounds from
/// `LayoutTree`. Equivalent to
/// `@aom.build_accessibility_tree_with_node_layout` but accepts the
/// layout engine's mutable tree directly.
pub fn build_accessibility_tree_with_layout(
  doc : @html.Document,
  layout_tree : @layout.LayoutTree,
) -> @aom.AccessibilityTree {
  let a11y_tree = @aom.build_accessibility_tree(doc)
  let bounds_map = extract_bounds_from_layout(layout_tree)
  @aom.attach_bounds(a11y_tree, bounds_map)
}
