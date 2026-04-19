// =============================================================================
// Paint Layout Tree Bridge Package - Layout to PaintNode conversion
// =============================================================================

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
pub fn from_layout(layout : @types.Layout) -> @model.PaintNode {
  let default_style = @style.Style::default()
  let paint = @model.PaintProperties::from_style(default_style)
  let children : Array[@model.PaintNode] = []
  for child in layout.children {
    children.push(from_layout(child))
  }
  let tag = extract_tag_from_id(layout.id)
  @model.PaintNode::new(
    layout.id,
    tag,
    layout.x,
    layout.y,
    layout.width,
    layout.height,
    paint,
    children,
    text=layout.text,
    overflow_x=layout.overflow_x,
    overflow_y=layout.overflow_y,
  )
}
