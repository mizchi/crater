// =============================================================================
// Paint Node Bridge Package - layout.Node + Layout to PaintNode conversion
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
pub fn from_node_and_layout(
  node : @layout.Node,
  layout : @types.Layout,
) -> @model.PaintNode {
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
    let mut child = from_node_and_layout(child_node, child_layout)
    child = { ..child, paint: inherit_text_paint(paint, child.paint) }
    let child_tag = extract_tag_from_id(child_node.id)
    if child_tag == "li" {
      match generate_list_marker(tag, layout_index) {
        Some(marker_text) => {
          let marker_paint = { ..child.paint, font_size: child.paint.font_size }
          let marker_node = @model.PaintNode::new(
            "#list-marker",
            "#text",
            -child.paint.font_size * 1.2,
            0.0,
            child.paint.font_size * 1.2,
            child.paint.font_size,
            marker_paint,
            [],
            text=Some(marker_text),
          )
          child = {
            ..child,
            children: {
              let new_children = child.children.copy()
              new_children.push(marker_node)
              new_children
            },
          }
        }
        None => ()
      }
    }
    children.push(child)
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
  )
}
