///|
/// Layout HTML tree bridge
/// Builds LayoutTree / LayoutNode values from HTML documents and elements.

///|
fn try_parse_double(s : String) -> Double? {
  Some(@string.parse_double(s)) catch {
    _ => None
  }
}

///|
fn layout_node_id_for_element(element : @html.Element) -> String {
  let tag = element.tag.to_lower()
  match element.id {
    Some(id) => "\{tag}#\{id}"
    None => tag
  }
}

///|
fn parse_inline_declarations(
  inline_css : String,
) -> Array[@css.Declaration] {
  let declarations : Array[@css.Declaration] = []
  let pairs = inline_css.split(";")
  for pair in pairs {
    let pair_str = pair.to_string().trim().to_string()
    if pair_str.is_empty() {
      continue
    }
    let mut colon_pos = -1
    for i in 0..<pair_str.length() {
      if pair_str[i].to_int().unsafe_to_char() == ':' {
        colon_pos = i
        break
      }
    }
    if colon_pos <= 0 {
      continue
    }
    let property = pair_str.unsafe_substring(start=0, end=colon_pos).trim()
    let raw_value = pair_str
      .unsafe_substring(start=colon_pos + 1, end=pair_str.length())
      .trim()
      .to_string()
    if property.is_empty() || raw_value.is_empty() {
      continue
    }
    let (value, importance) = if raw_value.has_suffix("!important") {
      (
        raw_value[:raw_value.length() - "!important".length()]
        .to_string()
        .trim()
        .to_string(),
        @css.Importance::Important,
      )
    } else {
      (raw_value, @css.Importance::Normal)
    }
    declarations.push(
      @css.Declaration::from_inline(property.to_string(), value, importance),
    )
  }
  declarations
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
  let node_id = layout_node_id_for_element(element)
  let node = @tree.LayoutNode::create_with_id(node_id)

  match element.style {
    Some(inline_style) => {
      let declarations = parse_inline_declarations(inline_style)
      if declarations.length() > 0 {
        let inline_values = @css.cascade_declarations(declarations)
        let _ = @style_bridge.apply_css_values(node, inline_values)
      }
    }
    None => ()
  }

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
