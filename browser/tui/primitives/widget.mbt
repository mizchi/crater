///|
/// Widget utilities for TUI rendering
/// Box drawing characters and common widget patterns

///|
/// Box drawing style
pub(all) enum BoxStyle {
  Single // ┌─┐│└┘
  Double // ╔═╗║╚╝
  Rounded // ╭─╮│╰╯
  Ascii // +-+|+-+
}

///|
/// Get box drawing characters for a style
fn box_chars(style : BoxStyle) -> @tui_buffer.BoxChars {
  match style {
    Single => @tui_buffer.BoxChars::single()
    Double => @tui_buffer.BoxChars::double()
    Rounded => @tui_buffer.BoxChars::rounded()
    Ascii => @tui_buffer.BoxChars::ascii()
  }
}

///|
/// Draw a box outline
pub fn draw_box(
  buf : CharBuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  style : BoxStyle,
  fg : @types.Color,
  bg : @types.Color,
) -> Unit {
  let cell_style : CharCell = {
    char: ' ',
    fg,
    bg,
    bold: false,
    underline: false,
    reverse: false,
  }
  for cell in @tui_buffer.plan_box(x, y, w, h, box_chars(style)) {
    buf.set_cell(cell.x, cell.y, { ..cell_style, char: cell.char })
  }
}

///|
/// Draw a filled box (box outline with filled interior)
pub fn draw_filled_box(
  buf : CharBuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  style : BoxStyle,
  fg : @types.Color,
  bg : @types.Color,
) -> Unit {
  // Fill interior first
  let fill_cell : CharCell = {
    char: ' ',
    fg,
    bg,
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(x, y, w, h, fill_cell)
  // Draw box outline on top
  draw_box(buf, x, y, w, h, style, fg, bg)
}

///|
/// Draw a horizontal line
pub fn draw_hline(
  buf : CharBuffer,
  x : Int,
  y : Int,
  w : Int,
  style : BoxStyle,
  fg : @types.Color,
) -> Unit {
  let chars = box_chars(style)
  let cell : CharCell = {
    char: chars.horizontal,
    fg,
    bg: @types.Color::transparent(),
    bold: false,
    underline: false,
    reverse: false,
  }
  for planned in @tui_buffer.plan_hline(x, y, w, chars.horizontal) {
    buf.set_cell(planned.x, planned.y, cell)
  }
}

///|
/// Draw a vertical line
pub fn draw_vline(
  buf : CharBuffer,
  x : Int,
  y : Int,
  h : Int,
  style : BoxStyle,
  fg : @types.Color,
) -> Unit {
  let chars = box_chars(style)
  let cell : CharCell = {
    char: chars.vertical,
    fg,
    bg: @types.Color::transparent(),
    bold: false,
    underline: false,
    reverse: false,
  }
  for planned in @tui_buffer.plan_vline(x, y, h, chars.vertical) {
    buf.set_cell(planned.x, planned.y, cell)
  }
}

///|
/// Draw a scrollbar
pub fn draw_scrollbar(
  buf : CharBuffer,
  x : Int,
  y : Int,
  height : Int,
  scroll_pos : Int,
  content_height : Int,
  visible_height : Int,
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
