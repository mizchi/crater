// =============================================================================
// Paint Viewport Bridge Package - Viewport-aware layout/style to PaintNode conversion
// =============================================================================

///|
fn inherit_text_paint(
  parent : @model.PaintProperties,
  child : @model.PaintProperties,
) -> @model.PaintProperties {
  {
    ..child,
    is_bold: child.is_bold || parent.is_bold,
    text_decoration_underline: child.text_decoration_underline ||
    parent.text_decoration_underline,
    text_decoration_line_through: child.text_decoration_line_through ||
    parent.text_decoration_line_through,
    text_decoration_overline: child.text_decoration_overline ||
    parent.text_decoration_overline,
  }
}

///|
fn extract_tag_from_id(id : String) -> String {
  if id == "#text" {
    return "#text"
  }
  let mut end_pos : Int? = None
  for i, c in id {
    if c == '#' || c == '.' {
      end_pos = Some(i)
      break
    }
  }
  match end_pos {
    Some(pos) => id.unsafe_substring(start=0, end=pos)
    None => id
  }
}

///|
fn is_ignorable_whitespace_text_node(node : @layout.Node) -> Bool {
  if node.id != "#text" {
    return false
  }
  match node.text {
    Some(text) => text.trim().length() == 0
    None => false
  }
}

///|
fn generate_list_marker(parent_tag : String, child_index : Int) -> String? {
  match parent_tag {
    "ul" => Some("\u{2022}")
    "ol" => Some((child_index + 1).to_string() + ".")
    _ => None
  }
}

///|
fn should_apply_text_overflow_ellipsis(
  style : @style.Style,
  layout : @types.Layout,
) -> Bool {
  style.text_overflow == @style.TextOverflow::Ellipsis &&
  style.white_space == @style.WhiteSpace::Nowrap &&
  layout.width > 0.0 &&
  (layout.overflow_x != @types.Visible || layout.overflow_y != @types.Visible)
}

///|
fn resolve_text_overflow_char_width(style : @style.Style) -> Double {
  let font_size = if style.font_size > 0.0 { style.font_size } else { 16.0 }
  if style.font_family.to_lower().contains("ahem") {
    font_size
  } else {
    font_size * 0.5
  }
}

///|
fn truncate_text_with_ellipsis(
  text : String,
  max_width : Double,
  char_width : Double,
) -> String {
  if char_width <= 0.0 {
    return text
  }
  let max_chars = (max_width / char_width).to_int()
  if max_chars <= 0 {
    return ""
  }
  if text.length().to_double() * char_width <= max_width {
    return text
  }
  if max_chars <= 3 {
    return "..."
  }
  let keep_chars = max_chars - 3
  let mut result = ""
  let mut count = 0
  for c in text {
    if count >= keep_chars {
      break
    }
    result = result + c.to_string()
    count += 1
  }
  result + "..."
}

///|
fn clamp_to_available_width(width : Double, available_width : Double) -> Double {
  if width > available_width {
    available_width
  } else {
    width
  }
}

///|
fn apply_text_overflow_ellipsis_to_subtree(
  paint_node : @model.PaintNode,
  source_node : @layout.Node,
  available_width : Double,
) -> @model.PaintNode {
  if source_node.id == "#text" {
    match paint_node.text {
      Some(text) => {
        let truncated = truncate_text_with_ellipsis(
          text,
          available_width,
          resolve_text_overflow_char_width(source_node.style),
        )
        return {
          ..paint_node,
          width: clamp_to_available_width(paint_node.width, available_width),
          text: Some(truncated),
        }
      }
      None => return paint_node
    }
  }
  if paint_node.children.length() == 1 && source_node.children.length() == 1 {
    let updated_child = apply_text_overflow_ellipsis_to_subtree(
      paint_node.children[0],
      source_node.children[0],
      available_width,
    )
    return {
      ..paint_node,
      width: clamp_to_available_width(paint_node.width, available_width),
      children: [updated_child],
    }
  }
  paint_node
}

///|
priv struct ExtentNode {
  relative_extent : Double
  children : Array[ExtentNode]
}

///|
fn precompute_extent_tree(layout : @types.Layout) -> ExtentNode {
  let children : Array[ExtentNode] = Array::new(
    capacity=layout.children.length(),
  )
  let mut max_extent = layout.height
  for child in layout.children {
    let child_node = precompute_extent_tree(child)
    let child_extent = child.y + child_node.relative_extent
    if child_extent > max_extent {
      max_extent = child_extent
    }
    children.push(child_node)
  }
  { relative_extent: max_extent, children }
}

///|
pub fn from_node_and_layout_with_viewport(
  node : @layout.Node,
  layout : @types.Layout,
  viewport_top : Double,
  viewport_bottom : Double,
  parent_y : Double,
) -> @model.PaintNode? {
  let extent_tree = precompute_extent_tree(layout)
  from_node_and_layout_with_viewport_inner(
    node, layout, extent_tree, viewport_top, viewport_bottom, parent_y,
  )
}

///|
fn from_node_and_layout_with_viewport_inner(
  node : @layout.Node,
  layout : @types.Layout,
  extent : ExtentNode,
  viewport_top : Double,
  viewport_bottom : Double,
  parent_y : Double,
) -> @model.PaintNode? {
  let abs_y = parent_y + layout.y
  let effective_bottom = abs_y + extent.relative_extent
  if effective_bottom < viewport_top || abs_y > viewport_bottom {
    return None
  }
  let mut paint = @model.PaintProperties::from_style(node.style)
  paint = {
    ..paint,
    border_top_width: layout.border.top,
    border_right_width: layout.border.right,
    border_bottom_width: layout.border.bottom,
    border_left_width: layout.border.left,
  }
  let tag = extract_tag_from_id(node.id)
  let children : Array[@model.PaintNode] = []

  let extent_count = extent.children.length()
  let mut node_index = 0
  let mut layout_index = 0
  while node_index < node.children.length() &&
        layout_index < layout.children.length() {
    if is_ignorable_whitespace_text_node(node.children[node_index]) {
      node_index += 1
      continue
    }
    let child_node = node.children[node_index]
    let child_layout = layout.children[layout_index]
    let child_extent = if layout_index < extent_count {
      extent.children[layout_index]
    } else {
      { relative_extent: child_layout.height, children: [] }
    }
    match
      from_node_and_layout_with_viewport_inner(
        child_node, child_layout, child_extent, viewport_top, viewport_bottom, abs_y,
      ) {
      Some(child) => {
        let mut current = {
          ..child,
          paint: inherit_text_paint(paint, child.paint),
        }
        let child_tag = extract_tag_from_id(child_node.id)
        if child_tag == "li" {
          match generate_list_marker(tag, layout_index) {
            Some(marker_text) => {
              let marker_paint = {
                ..current.paint,
                font_size: current.paint.font_size,
              }
              let marker_node = @model.PaintNode::new(
                "#list-marker",
                "#text",
                -current.paint.font_size * 1.2,
                0.0,
                current.paint.font_size * 1.2,
                current.paint.font_size,
                marker_paint,
                [],
                text=Some(marker_text),
              )
              current = {
                ..current,
                children: {
                  let new_children = current.children.copy()
                  new_children.push(marker_node)
                  new_children
                },
              }
            }
            None => ()
          }
        }
        if should_apply_text_overflow_ellipsis(node.style, layout) {
          current = apply_text_overflow_ellipsis_to_subtree(
            current,
            child_node,
            layout.width,
          )
        }
        children.push(current)
      }
      None => ()
    }
    node_index += 1
    layout_index += 1
  }
  if tag == "img" {
    if paint.background_color.is_transparent() {
      paint = { ..paint, background_color: @types.Color::rgb(240, 240, 240) }
    }
    match layout.text {
      Some(alt) =>
        if children.is_empty() && alt.length() > 0 {
          let alt_paint = {
            ..@model.PaintProperties::default(),
            color: @types.Color::rgb(128, 128, 128),
            font_size: paint.font_size,
          }
          children.push(
            @model.PaintNode::new(
              "#text",
              "#text",
              0.0,
              0.0,
              layout.width,
              layout.height,
              alt_paint,
              [],
              text=Some(alt),
            ),
          )
        }
      None => ()
    }
  }
  let transform = node.style.transform
  let translate_x = transform.compute_translate_x(layout.width)
  let translate_y = transform.compute_translate_y(layout.height)
  Some(
    @model.PaintNode::new(
      node.id,
      tag,
      layout.x + translate_x,
      layout.y + translate_y,
      layout.width,
      layout.height,
      paint,
      children,
      text=layout.text,
      src=node.src,
      overflow_x=layout.overflow_x,
      overflow_y=layout.overflow_y,
      clip=node.style.clip,
    ),
  )
}
