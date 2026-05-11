///|
/// Framebuffer and paint tree rasterization for image outputs.
/// Terminal protocols are encoded by crater-painter-terminal packages.

///|
/// Render a PaintNode tree to framebuffer
fn render_paint_node(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  parent_x : Double,
  parent_y : Double,
) -> Unit {
  render_paint_node_clipped(fb, palette, node, parent_x, parent_y, None)
}

///|
/// Render a PaintNode tree to framebuffer with optional clip rect
fn render_paint_node_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  parent_x : Double,
  parent_y : Double,
  clip : ClipRect?,
) -> Unit {
  // Skip invisible nodes
  if !node.paint.should_render() {
    return
  }
  let abs_x = parent_x + node.x
  let abs_y = parent_y + node.y
  let x = abs_x.to_int()
  let y = abs_y.to_int()
  let w = node.width.to_int()
  let h = node.height.to_int()

  // Skip zero-sized nodes
  if w <= 0 || h <= 0 {
    for child in node.children {
      render_paint_node_clipped(fb, palette, child, abs_x, abs_y, clip)
    }
    return
  }

  if is_visually_hidden_paint_node(node, w, h) ||
    is_node_outside_framebuffer(fb, x, y, w, h) ||
    is_node_outside_clip(x, y, w, h, clip) {
    return
  }
  if node.paint.opacity < 1.0 && !node.children.is_empty() {
    render_group_opacity_clipped(fb, palette, node, parent_x, parent_y, clip)
    return
  }

  render_node_box_decorations(fb, palette, node, x, y, w, h, clip)
  render_node_content(fb, palette, node, x, y, w, h, clip)
  render_node_children_clipped(
    fb, palette, node, abs_x, abs_y, x, y, w, h, clip,
  )
}

///|
/// Render PaintNode tree to framebuffer with scroll offset
pub fn render_paint_node_to_framebuffer_scrolled(
  node : @paint_model.PaintNode,
  fb : Framebuffer,
  palette : DynamicPalette,
  scroll_y : Int,
) -> Unit {
  // Fill with white background
  fb.fill_rect(0, 0, fb.width, fb.height, 0)
  // Sort by stacking order (z-index) for correct rendering
  let sorted_node = @paint_traversal.sort_tree_by_stacking_order(node)
  fill_canvas_background(fb, palette, sorted_node)
  // Render the tree with scroll offset
  render_paint_node(fb, palette, sorted_node, 0.0, -scroll_y.to_double())
}

///|
/// Render PaintNode tree to framebuffer (for use by other renderers like Kitty)
pub fn render_paint_node_to_framebuffer(
  node : @paint_model.PaintNode,
  fb : Framebuffer,
  palette : DynamicPalette,
) -> Unit {
  // Sort by stacking order (z-index) for correct rendering
  let sorted_node = @paint_traversal.sort_tree_by_stacking_order(node)
  fill_canvas_background(fb, palette, sorted_node)
  // Render the tree
  render_paint_node(fb, palette, sorted_node, 0.0, 0.0)
}
