///|
// Render root selection and root layout adjustment helpers.

///|
/// Find the deepest body element in HTML tree
/// If there are nested body elements (invalid HTML), find the innermost one
fn find_body(elem : @html.Element) -> @html.Element? {
  if elem.tag == "body" {
    // Check if there's a nested body inside this one
    match find_body_in_children(elem) {
      Some(inner_body) => Some(inner_body)
      None => Some(elem)
    }
  } else {
    find_body_in_children(elem)
  }
}

///|
/// Helper to find body in children
fn find_body_in_children(elem : @html.Element) -> @html.Element? {
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) =>
        match find_body(child_elem) {
          Some(body) => return Some(body)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
/// Resolve zoom on the document root (html element).
/// We render from body in most paths, so root zoom needs to be propagated.
fn resolve_document_root_zoom(
  doc_root : @html.Element,
  ctx : RenderContext,
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  css_vars : Map[String, String],
) -> Double {
  if doc_root.tag.to_lower() != "html" {
    return 1.0
  }
  let root_selector = if indexed_stylesheets.length() == 0 {
    html_to_selector_element_minimal(doc_root, None)
  } else {
    html_to_selector_element(doc_root, None)
  }
  let root_style = compute_element_style_indexed(
    root_selector,
    doc_root.style,
    indexed_stylesheets,
    true,
    ctx,
    None,
    css_vars,
  )
  root_style.zoom
}

///|
/// We render from <body> in most paths. When <html> establishes multicol
/// formatting, mirror it onto body root unless body already establishes one.
fn propagate_document_root_multicol_to_body(
  body_style : @style.Style,
  doc_root_style : @style.Style,
) -> @style.Style {
  if body_style.has_multicol() || !doc_root_style.has_multicol() {
    return body_style
  }
  {
    ..body_style,
    column_count: doc_root_style.column_count,
    column_width: doc_root_style.column_width,
    column_gap: doc_root_style.column_gap,
    column_gap_is_normal: doc_root_style.column_gap_is_normal,
    column_fill: doc_root_style.column_fill,
  }
}

///|
fn should_layout_document_root(
  doc_root : @html.Element,
  doc_root_style : @style.Style,
) -> Bool {
  if doc_root.tag.to_lower() != "html" {
    return false
  }
  doc_root_style.position == @types.Absolute ||
  doc_root_style.position == @types.Fixed
}

///|
fn select_render_root(
  doc_root : @html.Element,
  doc_root_style : @style.Style,
) -> @html.Element {
  if should_layout_document_root(doc_root, doc_root_style) {
    return doc_root
  }
  match find_body(doc_root) {
    Some(body) => body
    None => doc_root
  }
}

///|
fn resolve_root_available_width(
  viewport_width : Double,
  root_margin : @types.Rect[Double],
  doc_root_style : @style.Style?,
) -> Double {
  let base = viewport_width - root_margin.left - root_margin.right
  let base = if base > 0.0 { base } else { 0.0 }
  match doc_root_style {
    None => base
    Some(style) => {
      let mut doc_width = match style.width {
        @types.Length(v) => v
        @types.Percent(p) => viewport_width * p
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => viewport_width
      }
      let min_width = match style.min_width {
        @types.Length(v) => v
        @types.Percent(p) => viewport_width * p
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 0.0
      }
      let max_width = match style.max_width {
        @types.Length(v) => v
        @types.Percent(p) => viewport_width * p
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 1.0e10
      }
      if doc_width > max_width {
        doc_width = max_width
      }
      if doc_width < min_width {
        doc_width = min_width
      }
      let constrained = doc_width - root_margin.left - root_margin.right
      let constrained = if constrained > 0.0 { constrained } else { 0.0 }
      if constrained < base {
        constrained
      } else {
        base
      }
    }
  }
}

///|
fn node_with_style(node : @node.Node, style : @style.Style) -> @node.Node {
  @node.Node::with_uid_and_measure(
    node.id,
    node.uid,
    style,
    node.children,
    node.measure,
    node.text,
  )
}

///|
/// Clamp body height only when author explicitly requests viewport-relative
/// percentage sizing.
fn should_clamp_body_to_viewport(root : @node.Node) -> Bool {
  if root.id != "body" {
    return false
  }
  let has_viewport_height_request = match root.style.height {
    @types.Percent(p) => p >= 1.0
    _ =>
      match root.style.min_height {
        @types.Percent(p) => p >= 1.0
        _ => false
      }
  }
  has_viewport_height_request
}

///|
fn adjust_root_height_for_viewport(
  layout : @types.Layout,
  root : @node.Node,
  render_root_tag : String,
  viewport_height : Double,
) -> @types.Layout {
  let content_extent = calculate_content_extent(layout)
  if should_clamp_body_to_viewport(root) {
    let min_viewport_height = if layout.height < viewport_height {
      viewport_height
    } else {
      layout.height
    }
    let final_height = if content_extent > min_viewport_height {
      content_extent
    } else {
      min_viewport_height
    }
    return { ..layout, height: final_height }
  }
  let keeps_empty_viewport_height = (
      render_root_tag == "body" || render_root_tag == "html"
    ) &&
    root.style.display != @types.Display::Contents &&
    root.style.position != @types.Absolute &&
    root.style.position != @types.Fixed &&
    layout.height <= 0.0 &&
    content_extent <= 0.0
  if keeps_empty_viewport_height {
    return { ..layout, height: viewport_height }
  }
  layout
}

///|
fn stretch_single_frameset_child_to_root(
  layout : @types.Layout,
) -> @types.Layout {
  if layout.children.length() != 1 {
    return layout
  }
  let child = layout.children[0]
  let is_frameset = child.id == "frameset" ||
    child.id.has_prefix("frameset#") ||
    child.id.has_prefix("frameset.")
  if !is_frameset || child.height > 0.0 {
    return layout
  }
  let adjusted_children : Array[@types.Layout] = []
  adjusted_children.push({
    ..child,
    width: if child.width > 0.0 {
      child.width
    } else {
      layout.width
    },
    height: layout.height,
  })
  { ..layout, children: adjusted_children }
}

///|
/// Create a recursive zero-sized layout for nodes that don't generate a box
/// (e.g. display:none on root/body).
fn create_zero_layout_from_node(node : @node.Node) -> @types.Layout {
  let children : Array[@types.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    children.push(create_zero_layout_from_node(node.children[i]))
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    margin: @types.Rect::zero(),
    padding: @types.Rect::zero(),
    border: @types.Rect::zero(),
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children,
    text: node.text,
  }
}
