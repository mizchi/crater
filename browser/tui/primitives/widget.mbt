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
  let style : TextStyle = {
    fg,
    bg: @types.Color::transparent(),
    bold: true,
    underline: false,
  }
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

///|
/// Draw a status bar at the top
/// Shows focused link URL when a link is focused, otherwise shows current page URL
pub fn draw_status_bar(
  buf : CharBuffer,
  y : Int,
  url : String,
  link_count : Int,
  focused_link : Int,
  focused_link_url? : String? = None,
  selection_mode? : Bool = false,
  dark_mode? : Bool = false,
) -> Unit {
  // Status bar colors - slightly different for dark mode
  let (bg, fg) = if dark_mode {
    (@types.Color::rgb(40, 40, 50), @types.Color::rgb(180, 180, 180))
  } else {
    (@types.Color::rgb(50, 50, 50), @types.Color::rgb(200, 200, 200))
  }
  let highlight_fg = @types.Color::rgb(100, 200, 255) // Cyan for link URL
  let selection_fg = @types.Color::rgb(255, 200, 100) // Orange for selection mode
  let dark_mode_fg = @types.Color::rgb(150, 200, 150) // Green for dark mode indicator
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
  let style : TextStyle = { fg, bg, bold: false, underline: false }
  let selection_style : TextStyle = {
    fg: selection_fg,
    bg,
    bold: true,
    underline: false,
  }
  let dark_mode_style : TextStyle = {
    fg: dark_mode_fg,
    bg,
    bold: false,
    underline: false,
  }
  let mut col = 0
  // Show dark mode indicator if active
  if dark_mode {
    let mode_text = "[DARK] "
    col = buf.write_text(col, y, mode_text, dark_mode_style, buf.width)
  }
  // Show selection mode indicator if active
  if selection_mode {
    let mode_text = "[SELECT v:exit] "
    col = buf.write_text(col, y, mode_text, selection_style, buf.width - col)
  }
  // Determine display URL: show focused link URL if available
  let (display_url, is_link_url) = match focused_link_url {
    Some(link_url) => (link_url, true)
    None => (url, false)
  }
  let link_url_style : TextStyle = {
    fg: highlight_fg,
    bg,
    bold: false,
    underline: false,
  }
  // Write URL part (possibly highlighted if it's a link URL)
  let url_style = if is_link_url { link_url_style } else { style }
  let url_text = " " + display_url
  col = buf.write_text(col, y, url_text, url_style, buf.width - col)
  // Write the rest of the status (skip if selection mode to save space)
  if !selection_mode {
    let rest = " | Links: " +
      (focused_link + 1).to_string() +
      "/" +
      link_count.to_string() +
      " | d:dark v:select "
    let _ = buf.write_text(col, y, rest, style, buf.width - col)
  }
}
