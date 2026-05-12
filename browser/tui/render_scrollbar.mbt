///|
/// TUI element scrollbar rendering helpers.

///|
fn render_element_scrollbar(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  col : Int,
  row : Int,
  w : Int,
  h : Int,
) -> Unit {
  if !(node.is_scrollable() && h >= 3) {
    return
  }
  let scroll_pos = match ctx.element_scroll_positions.get(node.id) {
    Some(pos) => pos.scroll_top.to_int()
    None => 0
  }
  let content_height = px_to_row_height(node.scroll_height)
  let visible_height = h
  let scrollbar_col = col + w - 1
  let scrollbar_row = row.max(0)
  let scrollbar_height = (row + h).min(ctx.viewport_height) - scrollbar_row
  if scrollbar_height >= 3 && content_height > visible_height {
    draw_scrollbar(
      ctx.buffer,
      scrollbar_col,
      scrollbar_row,
      scrollbar_height,
      scroll_pos,
      content_height,
      visible_height,
    )
  }
}
