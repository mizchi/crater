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
fn box_chars(style : BoxStyle) -> (Char, Char, Char, Char, Char, Char) {
  // Returns: (top_left, top_right, bottom_left, bottom_right, horizontal, vertical)
  match style {
    Single => ('┌', '┐', '└', '┘', '─', '│')
    Double => ('╔', '╗', '╚', '╝', '═', '║')
    Rounded => ('╭', '╮', '╰', '╯', '─', '│')
    Ascii => ('+', '+', '+', '+', '-', '|')
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
  if w < 2 || h < 2 {
    return
  }
  let (tl, tr, bl, br, horiz, vert) = box_chars(style)
  let cell_style : CharCell = {
    char: ' ',
    fg,
    bg,
    bold: false,
    underline: false,
    reverse: false,
  }
  // Top left corner
  buf.set_cell(x, y, { ..cell_style, char: tl })
  // Top right corner
  buf.set_cell(x + w - 1, y, { ..cell_style, char: tr })
  // Bottom left corner
  buf.set_cell(x, y + h - 1, { ..cell_style, char: bl })
  // Bottom right corner
  buf.set_cell(x + w - 1, y + h - 1, { ..cell_style, char: br })
  // Top edge
  for col = x + 1; col < x + w - 1; col = col + 1 {
    buf.set_cell(col, y, { ..cell_style, char: horiz })
  }
  // Bottom edge
  for col = x + 1; col < x + w - 1; col = col + 1 {
    buf.set_cell(col, y + h - 1, { ..cell_style, char: horiz })
  }
  // Left edge
  for row = y + 1; row < y + h - 1; row = row + 1 {
    buf.set_cell(x, row, { ..cell_style, char: vert })
  }
  // Right edge
  for row = y + 1; row < y + h - 1; row = row + 1 {
    buf.set_cell(x + w - 1, row, { ..cell_style, char: vert })
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
  let (_, _, _, _, horiz, _) = box_chars(style)
  let cell : CharCell = {
    char: horiz,
    fg,
    bg: @types.Color::transparent(),
    bold: false,
    underline: false,
    reverse: false,
  }
  for col = x; col < x + w; col = col + 1 {
    buf.set_cell(col, y, cell)
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
  let (_, _, _, _, _, vert) = box_chars(style)
  let cell : CharCell = {
    char: vert,
    fg,
    bg: @types.Color::transparent(),
    bold: false,
    underline: false,
    reverse: false,
  }
  for row = y; row < y + h; row = row + 1 {
    buf.set_cell(x, row, cell)
  }
}

///|
/// Draw a link (with optional focus highlight)
pub fn draw_link(
  buf : CharBuffer,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  focused : Bool,
) -> Int {
  let style : TextStyle = if focused {
    {
      fg: @types.Color::black(),
      bg: @types.Color::rgb(100, 149, 237), // Cornflower blue
      bold: true,
      underline: false,
    }
  } else {
    {
      fg: @types.Color::rgb(100, 149, 237), // Cornflower blue
      bg: @types.Color::transparent(),
      bold: false,
      underline: true,
    }
  }
  buf.write_text(x, y, text, style, max_width)
}

///|
/// Draw a heading (bold text)
pub fn draw_heading(
  buf : CharBuffer,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  level : Int,
) -> Int {
  let fg = match level {
    1 => @types.Color::rgb(255, 255, 255) // White for h1
    2 => @types.Color::rgb(200, 200, 200) // Light gray for h2
    _ => @types.Color::rgb(180, 180, 180) // Lighter gray for h3+
  }
  let style : TextStyle = { fg, bg: @types.Color::transparent(), bold: true, underline: false }
  buf.write_text(x, y, text, style, max_width)
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
  if content_height <= visible_height || height < 3 {
    return
  }
  let fg = @types.Color::rgb(100, 100, 100)
  // Draw track
  let track_char = '│'
  for row = y; row < y + height; row = row + 1 {
    buf.set_cell(
      x,
      row,
      {
        char: track_char,
        fg,
        bg: @types.Color::transparent(),
        bold: false,
        underline: false,
        reverse: false,
      },
    )
  }
  // Calculate thumb position and size
  let thumb_height = (visible_height * height / content_height).max(1)
  let thumb_pos = scroll_pos * (height - thumb_height) /
    (content_height - visible_height)
  // Draw thumb
  let thumb_char = '█'
  for row = y + thumb_pos; row < y + thumb_pos + thumb_height; row = row + 1 {
    if row < y + height {
      buf.set_cell(
        x,
        row,
        {
          char: thumb_char,
          fg: @types.Color::rgb(200, 200, 200),
          bg: @types.Color::transparent(),
          bold: false,
          underline: false,
          reverse: false,
        },
      )
    }
  }
}

///|
/// Draw a status bar at the bottom
pub fn draw_status_bar(
  buf : CharBuffer,
  y : Int,
  url : String,
  link_count : Int,
  focused_link : Int,
) -> Unit {
  let bg = @types.Color::rgb(50, 50, 50)
  let fg = @types.Color::rgb(200, 200, 200)
  // Fill the entire row with background
  let fill : CharCell = {
    char: ' ',
    fg,
    bg,
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(0, y, buf.width, 1, fill)
  // Build status text
  let status = " " +
    url +
    " | Links: " +
    (focused_link + 1).to_string() +
    "/" +
    link_count.to_string() +
    " | q:quit j/k:scroll Tab:link "
  let style : TextStyle = { fg, bg, bold: false, underline: false }
  let _ = buf.write_text(0, y, status, style, buf.width)

}
