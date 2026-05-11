///|
/// Replaced image and text content rendering for PaintNode rasterization.

///|
fn render_node_content(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
) -> Unit {
  let drew_replaced_image = if node.tag == "img" && w > 0 && h > 0 {
    match node.src {
      Some(src) =>
        render_image_src_into_region(
          fb,
          palette,
          src,
          x,
          y,
          w,
          h,
          clip,
          node.paint.opacity,
        )
      None => false
    }
  } else {
    false
  }
  if !drew_replaced_image {
    render_node_text_content(fb, palette, node, x, y, w, h, clip)
    render_node_text_decorations(fb, palette, node, x, y, w, clip)
  }
}
