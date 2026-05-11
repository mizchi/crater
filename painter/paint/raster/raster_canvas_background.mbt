///|
/// Canvas background propagation helpers for raster entrypoints.

///|
fn resolve_canvas_background_color(
  node : @paint_model.PaintNode,
) -> @types.Color {
  let mut canvas_bg = node.paint.background_color
  if canvas_bg.is_transparent() {
    for child in node.children {
      if child.tag == "body" && !child.paint.background_color.is_transparent() {
        canvas_bg = child.paint.background_color
        break
      }
    }
  }
  canvas_bg
}

///|
fn fill_canvas_background(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
) -> Unit {
  let canvas_bg = resolve_canvas_background_color(node)
  if !canvas_bg.is_transparent() {
    let bg_raster = { r: canvas_bg.r, g: canvas_bg.g, b: canvas_bg.b }
    let bg_idx = palette.get_or_add(bg_raster)
    fb.fill_rect(0, 0, fb.width, fb.height, bg_idx)
  }
}
