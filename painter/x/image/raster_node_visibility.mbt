///|
/// Visibility and culling predicates for PaintNode rasterization.

///|
fn is_visually_hidden_paint_node(
  node : @paint_model.PaintNode,
  w : Int,
  h : Int,
) -> Bool {
  if node.clips_content() && w <= 1 && h <= 1 {
    true
  } else if w <= 1 && h <= 1 {
    true
  } else {
    w <= 1 && node.tag == "#text"
  }
}

///|
fn is_node_outside_framebuffer(
  fb : Framebuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Bool {
  x >= fb.width || y >= fb.height || x + w <= 0 || y + h <= 0
}

///|
fn is_node_outside_clip(
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
) -> Bool {
  match clip {
    Some(c) => x >= c.x + c.w || y >= c.y + c.h || x + w <= c.x || y + h <= c.y
    None => false
  }
}
