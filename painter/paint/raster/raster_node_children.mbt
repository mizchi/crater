///|
/// Child clipping and recursive rendering for PaintNode rasterization.

///|
fn render_node_children_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  abs_x : Double,
  abs_y : Double,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
) -> Unit {
  let child_clip = if node.clips_content() {
    let node_clip : ClipRect = { x, y, w, h }
    match clip {
      None => Some(node_clip)
      Some(parent_clip) => clip_intersect(parent_clip, node_clip)
    }
  } else {
    clip
  }

  match (node.clips_content(), child_clip) {
    (true, None) => return
    _ => ()
  }

  if node.paint.opacity < 1.0 {
    for child in node.children {
      let child_with_opacity = {
        ..child,
        paint: {
          ..child.paint,
          opacity: child.paint.opacity * node.paint.opacity,
        },
      }
      render_paint_node_clipped(
        fb, palette, child_with_opacity, abs_x, abs_y, child_clip,
      )
    }
  } else {
    for child in node.children {
      render_paint_node_clipped(fb, palette, child, abs_x, abs_y, child_clip)
    }
  }
}
