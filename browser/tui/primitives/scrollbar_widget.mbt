///|
/// Scrollbar widget rendering for TUI buffers.

///|
/// Draw a scrollbar
pub fn draw_scrollbar(
  buf : CharBuffer,
  x : Int32,
  y : Int32,
  height : Int32,
  scroll_pos : Int32,
  content_height : Int32,
  visible_height : Int32,
) -> Unit {
  for
    cell in @tui_buffer.plan_scrollbar(
      x, y, height, scroll_pos, content_height, visible_height, '│', '█',
    ) {
    let fg = if cell.thumb {
      @types.Color::rgb(200, 200, 200)
    } else {
      @types.Color::rgb(100, 100, 100)
    }
    buf.set_cell(cell.x, cell.y, {
      char: cell.char,
      fg,
      bg: @types.Color::transparent(),
      bold: false,
      underline: false,
      reverse: false,
    })
  }
}
