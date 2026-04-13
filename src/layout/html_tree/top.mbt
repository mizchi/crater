///|
/// Layout HTML tree bridge
/// Builds LayoutTree / LayoutNode values from HTML documents and elements.

///|
fn try_parse_double(s : String) -> Double? {
  Some(@string.parse_double(s)) catch {
    _ => None
  }
}

// =============================================================================
// HTML Element to LayoutNode Conversion
// =============================================================================

///|
/// Create a LayoutNode from an HTML element with computed styles.
pub fn layout_node_from_html_element(
  element : @html.Element,
  computed_styles : @css.CascadedValues,
) -> @tree.LayoutNode {
  let node_id = match element.id {
    Some(id) => id
    None => element.tag
  }
  let node = @tree.LayoutNode::create_with_id(node_id)

  let _ = @style_bridge.apply_css_values(node, computed_styles)

  let tag_lower = element.tag.to_lower()
  if tag_lower == "img" {
    setup_image_node(node, element)
  } else if tag_lower == "canvas" {
    setup_canvas_node(node, element)
  }

  for html_child in element.children {
    match html_child {
      @html.Element(child_elem) => {
        let child_node = layout_node_from_html_element(
          child_elem,
          @css.CascadedValues::new(),
        )
        let _ = node.add_child(child_node)
      }
      @html.Text(_) => ()
    }
  }
  node
}

///|
/// Setup an img node with intrinsic sizing.
fn setup_image_node(node : @tree.LayoutNode, element : @html.Element) -> Unit {
  let width : Double? = match element.attributes.get("width") {
    Some(v) => parse_html_dimension(v)
    None => None
  }
  let height : Double? = match element.attributes.get("height") {
    Some(v) => parse_html_dimension(v)
    None => None
  }
  match (width, height) {
    (Some(w), Some(h)) => {
      node.set_intrinsic_resolved(w, h)
      node.style.width = @types.Length(w)
      node.style.height = @types.Length(h)
    }
    (Some(w), None) => {
      node.set_intrinsic_pending(w, @tree.default_placeholder_height)
      node.style.width = @types.Length(w)
    }
    (None, Some(h)) => {
      node.set_intrinsic_pending(@tree.default_placeholder_width, h)
      node.style.height = @types.Length(h)
    }
    (None, None) =>
      node.set_intrinsic_pending(
        @tree.default_placeholder_width, @tree.default_placeholder_height,
      )
  }
}

///|
/// Setup a canvas node with intrinsic sizing.
fn setup_canvas_node(node : @tree.LayoutNode, element : @html.Element) -> Unit {
  let default_width = 300.0
  let default_height = 150.0

  let width : Double = match element.attributes.get("width") {
    Some(v) =>
      match parse_html_dimension(v) {
        Some(w) => w
        None => default_width
      }
    None => default_width
  }
  let height : Double = match element.attributes.get("height") {
    Some(v) =>
      match parse_html_dimension(v) {
        Some(h) => h
        None => default_height
      }
    None => default_height
  }

  node.set_intrinsic_resolved(width, height)

  match node.style.width {
    @types.Auto => node.style.width = @types.Length(width)
    _ => ()
  }
  match node.style.height {
    @types.Auto => node.style.height = @types.Length(height)
    _ => ()
  }
}

///|
fn parse_html_dimension(value : String) -> Double? {
  let num_str : String = if value.has_suffix("px") && value.length() > 2 {
    value.unsafe_substring(start=0, end=value.length() - 2)
  } else {
    value
  }
  try_parse_double(num_str)
}

// =============================================================================
// Convenience Functions for Tree Building
// =============================================================================

///|
/// Build a LayoutTree from an HTML document with stylesheets.
pub fn layout_tree_from_html_document(
  doc : @html.Document,
  viewport_width : Double,
  viewport_height : Double,
) -> @tree.LayoutTree {
  let root = layout_node_from_html_element(doc.root, @css.CascadedValues::new())
  @tree.LayoutTree::new(root, viewport_width, viewport_height)
}
