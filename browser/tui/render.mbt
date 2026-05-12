///|
/// TUI Rendering - Convert PaintNode tree to CharBuffer
/// Implements pixel-to-character coordinate transformation

///|
/// Render a PaintNode to the CharBuffer
fn render_paint_node(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  parent_x : Double,
  parent_y : Double,
  inside_link : Bool,
  current_link_source_id? : String? = None,
  inside_pre? : Bool = false,
  clip_rect? : (Double, Double, Double, Double)? = None,
) -> Unit {
  // Skip invisible nodes
  if !node.paint.should_render() {
    return
  }
  // Calculate absolute position
  let abs_x = parent_x + node.x
  let abs_y = parent_y + node.y
  // Convert to character coordinates
  let col = px_to_col(abs_x)
  let row = px_to_row(abs_y) - ctx.scroll_y
  // Use ceiling for width and height to ensure text content fits
  let w = px_to_col_width(node.width)
  let h = px_to_row_height(node.height)
  let node_rect = (abs_x, abs_y, node.width, node.height)
  let effective_clip = combine_clip_rects(
    clip_rect,
    get_local_clip_rect(node, abs_x, abs_y),
  )
  let visible_rect = match effective_clip {
    Some(clip) => intersect_pixel_rects(node_rect, clip)
    None => Some(node_rect)
  }
  // Check if we're inside a pre/code element (no text wrapping)
  // Also disable wrapping inside table cells (th/td) - cells should clip, not wrap
  let is_pre = node.tag == "pre" || node.tag == "code"
  let is_table_cell = node.tag == "th" || node.tag == "td"
  let child_inside_pre = inside_pre || is_pre || is_table_cell
  let child_link_source_id = if node.tag == "a" &&
    node.paint.pointer_events != @style.PointerEvents::None {
    extract_source_id(node.id)
  } else {
    current_link_source_id
  }
  // Skip if completely outside viewport
  if row + h < 0 || row >= ctx.viewport_height {
    render_child_nodes(
      ctx, node, abs_x, abs_y, inside_link, child_link_source_id, child_inside_pre,
      effective_clip,
    )
    return
  }
  // Skip zero-sized nodes
  if w <= 0 || h <= 0 {
    render_child_nodes(
      ctx, node, abs_x, abs_y, inside_link, child_link_source_id, child_inside_pre,
      effective_clip,
    )
    return
  }
  collect_hit_region(ctx, node, abs_x, abs_y, visible_rect)
  // Draw background if not transparent
  if !node.paint.background_color.is_transparent() {
    // Clip to viewport
    let draw_row = row.max(0)
    let draw_h = (row + h).min(ctx.viewport_height) - draw_row
    if draw_h > 0 {
      // Use CSS-computed color directly (dark mode is handled by CSS cascade)
      ctx.buffer.fill_bg(col, draw_row, w, draw_h, node.paint.background_color)
    }
  }
  // Handle image placeholder (check BEFORE text to ensure background is drawn)
  if node.tag == "img" && w > 0 && h > 0 {
    render_image_node(ctx, node, col, row, w, h)
  } else {
    render_text_node(
      ctx, node, col, row, w, h, inside_link, child_link_source_id, child_inside_pre,
      visible_rect,
    )
  }
  render_child_nodes(
    ctx, node, abs_x, abs_y, inside_link, child_link_source_id, child_inside_pre,
    effective_clip,
  )
  render_element_scrollbar(ctx, node, col, row, w, h)
}
