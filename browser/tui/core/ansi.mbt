///|
/// ANSI Escape Sequences for terminal output
/// Supports 256-color mode

///|
/// Reset all attributes
pub fn ansi_reset() -> String {
  "\u001b[0m"
}

///|
/// Bold text
pub fn ansi_bold() -> String {
  "\u001b[1m"
}

///|
/// Underline text
pub fn ansi_underline() -> String {
  "\u001b[4m"
}

///|
/// Reverse video (swap foreground/background)
pub fn ansi_reverse() -> String {
  "\u001b[7m"
}

///|
/// Set foreground color using 256-color palette
pub fn ansi_fg_256(color_idx : Int) -> String {
  "\u001b[38;5;" + color_idx.to_string() + "m"
}

///|
/// Set background color using 256-color palette
pub fn ansi_bg_256(color_idx : Int) -> String {
  "\u001b[48;5;" + color_idx.to_string() + "m"
}

///|
/// Move cursor to position (1-indexed, row/col)
pub fn ansi_move_to(row : Int, col : Int) -> String {
  "\u001b[" + row.to_string() + ";" + col.to_string() + "H"
}

///|
/// Convert RGB color to 256-color palette index
/// Uses the standard 256-color palette:
/// - 0-15: Standard colors (black, red, green, etc.)
/// - 16-231: 6x6x6 color cube (216 colors)
/// - 232-255: Grayscale (24 shades)
pub fn rgb_to_256(r : Int, g : Int, b : Int) -> Int {
  // Check for grayscale (r == g == b)
  if r == g && g == b {
    // Map to grayscale range (232-255)
    // 0-255 -> 0-23
    if r < 8 {
      16 // Use black from color cube
    } else if r > 248 {
      231 // Use white from color cube
    } else {
      // Map to 24 grayscale levels (232-255)
      232 + (r - 8) * 24 / 240
    }
  } else {
    // Map to 6x6x6 color cube (16-231)
    // Each component: 0-255 -> 0-5
    let r6 = r * 6 / 256
    let g6 = g * 6 / 256
    let b6 = b * 6 / 256
    16 + r6 * 36 + g6 * 6 + b6
  }
}

///|
/// Convert Color to 256-color palette index
pub fn color_to_256(color : @types.Color) -> Int {
  rgb_to_256(color.r, color.g, color.b)
}

///|
/// Set foreground color from Color type
pub fn ansi_fg_color(color : @types.Color) -> String {
  ansi_fg_256(color_to_256(color))
}

///|
/// Set background color from Color type
pub fn ansi_bg_color(color : @types.Color) -> String {
  ansi_bg_256(color_to_256(color))
}

///|
priv struct AnsiStyleState {
  mut fg : Int
  mut bg : Int
  mut bold : Bool
  mut underline : Bool
}

///|
fn AnsiStyleState::new() -> AnsiStyleState {
  { fg: -1, bg: -1, bold: false, underline: false }
}

///|
fn AnsiStyleState::reset(self : AnsiStyleState) -> Unit {
  self.fg = -1
  self.bg = -1
  self.bold = false
  self.underline = false
}

///|
fn AnsiStyleState::write_cell_style(
  self : AnsiStyleState,
  sb : StringBuilder,
  cell : CharCell,
) -> Unit {
  let fg_idx = if cell.fg.is_transparent() {
    7 // Default white
  } else {
    color_to_256(cell.fg)
  }
  let bg_idx = if cell.bg.is_transparent() {
    -1 // No background
  } else {
    color_to_256(cell.bg)
  }
  let need_reset = (self.bold && !cell.bold) ||
    (self.underline && !cell.underline)
  if need_reset {
    sb.write_string(ansi_reset())
    self.reset()
  }
  if cell.bold && !self.bold {
    sb.write_string(ansi_bold())
    self.bold = true
  }
  if cell.underline && !self.underline {
    sb.write_string(ansi_underline())
    self.underline = true
  }
  if fg_idx != self.fg {
    sb.write_string(ansi_fg_256(fg_idx))
    self.fg = fg_idx
  }
  if bg_idx >= 0 && bg_idx != self.bg {
    sb.write_string(ansi_bg_256(bg_idx))
    self.bg = bg_idx
  }
}

///|
/// Convert CharBuffer to ANSI-encoded string
pub fn buffer_to_ansi(buf : CharBuffer, max_cols? : Int = 0) -> String {
  let sb = StringBuilder::new()
  let style_state = AnsiStyleState::new()
  let cols = if max_cols > 0 && max_cols < buf.width {
    max_cols
  } else {
    buf.width
  }
  for row = 0; row < buf.height; row = row + 1 {
    // Move to start of row (1-indexed)
    sb.write_string(ansi_move_to(row + 1, 1))
    for col = 0; col < cols; col = col + 1 {
      let cell = buf.get_cell(col, row)
      // Skip wide char placeholder
      if cell.char == '\u0000' {
        continue
      }
      style_state.write_cell_style(sb, cell)
      sb.write_char(cell.char)
    }
  }
  // Reset at end
  sb.write_string(ansi_reset())
  sb.to_string()
}

///|
/// Optimized ANSI output with diff (only output changed cells)
pub fn buffer_diff_to_ansi(
  current : CharBuffer,
  prev : CharBuffer,
  max_cols? : Int = 0,
) -> String {
  let sb = StringBuilder::new()
  let mut last_row = -1
  let mut last_col = -1
  let style_state = AnsiStyleState::new()
  let cols = if max_cols > 0 && max_cols < current.width {
    max_cols
  } else {
    current.width
  }
  for row = 0; row < current.height; row = row + 1 {
    for col = 0; col < cols; col = col + 1 {
      let cell = current.get_cell(col, row)
      let prev_cell = prev.get_cell(col, row)
      // Skip if unchanged
      if cell == prev_cell {
        continue
      }
      // Skip wide char placeholder
      if cell.char == '\u0000' {
        continue
      }
      // Move cursor if not consecutive
      if row != last_row || col != last_col + 1 {
        sb.write_string(ansi_move_to(row + 1, col + 1))
      }
      style_state.write_cell_style(sb, cell)
      sb.write_char(cell.char)
      last_row = row
      last_col = col
    }
  }
  sb.write_string(ansi_reset())
  sb.to_string()
}

///|
/// Dirty rectangle for partial diff updates
pub(all) struct DirtyRect {
  col : Int
  row : Int
  width : Int
  height : Int
}

///|
/// Optimized ANSI output with diff limited to dirty rectangles
pub fn buffer_diff_to_ansi_rects(
  current : CharBuffer,
  prev : CharBuffer,
  rects : Array[DirtyRect],
  max_cols? : Int = 0,
) -> String {
  if rects.length() == 0 {
    return ""
  }
  let sb = StringBuilder::new()
  let mut last_row = -1
  let mut last_col = -1
  let style_state = AnsiStyleState::new()
  let clip_width = if max_cols > 0 && max_cols < current.width {
    max_cols
  } else {
    current.width
  }
  let visited : Array[Bool] = Array::make(current.width * current.height, false)
  for rect in rects {
    let mut x0 = rect.col
    let mut y0 = rect.row
    let mut x1 = rect.col + rect.width
    let mut y1 = rect.row + rect.height
    // Clip to terminal width
    if x1 > clip_width {
      x1 = clip_width
    }
    if x1 <= 0 || y1 <= 0 || x0 >= clip_width || y0 >= current.height {
      continue
    }
    if x0 < 0 {
      x0 = 0
    }
    if y0 < 0 {
      y0 = 0
    }
    if x1 > current.width {
      x1 = current.width
    }
    if y1 > current.height {
      y1 = current.height
    }
    for row = y0; row < y1; row = row + 1 {
      for col = x0; col < x1; col = col + 1 {
        let idx = row * current.width + col
        if visited[idx] {
          continue
        }
        visited[idx] = true
        let cell = current.get_cell(col, row)
        let prev_cell = prev.get_cell(col, row)
        if cell == prev_cell {
          continue
        }
        if cell.char == '\u0000' {
          continue
        }
        if row != last_row || col != last_col + 1 {
          sb.write_string(ansi_move_to(row + 1, col + 1))
        }
        style_state.write_cell_style(sb, cell)
        sb.write_char(cell.char)
        last_row = row
        last_col = col
      }
    }
  }
  sb.write_string(ansi_reset())
  sb.to_string()
}

///|
/// Enable mouse tracking (SGR mode for better coordinates)
pub fn enable_mouse() -> String {
  "\u001b[?1003h\u001b[?1006h"
}

///|
/// Disable mouse tracking
pub fn disable_mouse() -> String {
  "\u001b[?1006l\u001b[?1003l"
}

///|
/// OSC 8 hyperlink start (URL)
/// Uses BEL (0x07) as String Terminator for broader terminal compatibility
pub fn ansi_hyperlink_start(url : String) -> String {
  "\u001b]8;;" + url + "\u0007"
}

///|
/// OSC 8 hyperlink end
/// Uses BEL (0x07) as String Terminator for broader terminal compatibility
pub fn ansi_hyperlink_end() -> String {
  "\u001b]8;;\u0007"
}

///|
/// Convert CharBuffer to plain text string (no ANSI color codes)
/// Used for --no-color mode
/// Preserves underline attribute for links
pub fn buffer_to_plain(buf : CharBuffer) -> String {
  let sb = StringBuilder::new()
  let style_state = PlainStyleState::new()
  for row = 0; row < buf.height; row = row + 1 {
    // Move to start of row (1-indexed)
    sb.write_string(ansi_move_to(row + 1, 1))
    for col = 0; col < buf.width; col = col + 1 {
      style_state.write_cell(sb, buf.get_cell(col, row))
    }
    style_state.reset_underline(sb)
  }
  sb.to_string()
}

///|
/// Link info for plain mode hyperlinks
pub(all) struct PlainLink {
  col : Int
  row : Int
  width : Int
  url : String
}

///|
priv struct PlainStyleState {
  mut underline : Bool
}

///|
fn PlainStyleState::new() -> PlainStyleState {
  { underline: false }
}

///|
fn PlainStyleState::reset_underline(
  self : PlainStyleState,
  sb : StringBuilder,
) -> Unit {
  if self.underline {
    sb.write_string(ansi_reset())
    self.underline = false
  }
}

///|
fn PlainStyleState::write_cell(
  self : PlainStyleState,
  sb : StringBuilder,
  cell : CharCell,
) -> Unit {
  // Skip wide char placeholder
  if cell.char == '\u0000' {
    return
  }
  // Handle underline toggle (for links)
  if cell.underline && !self.underline {
    sb.write_string(ansi_underline())
    self.underline = true
  } else if !cell.underline && self.underline {
    sb.write_string(ansi_reset())
    self.underline = false
  }
  // Write the character (no color codes)
  sb.write_char(cell.char)
}

///|
/// Convert CharBuffer to plain text with clickable hyperlinks
/// Uses OSC 8 escape sequences for terminal hyperlinks
/// Preserves underline attribute for links
pub fn buffer_to_plain_with_links(
  buf : CharBuffer,
  links : Array[PlainLink],
) -> String {
  // Build a map of link start positions for quick lookup
  let link_starts : Map[Int, PlainLink] = {}
  let link_ends : Map[Int, Bool] = {}
  for link in links {
    let start_key = link.row * buf.width + link.col
    link_starts.set(start_key, link)
    let end_key = link.row * buf.width + link.col + link.width
    link_ends.set(end_key, true)
  }
  let sb = StringBuilder::new()
  let style_state = PlainStyleState::new()
  let mut in_hyperlink = false
  for row = 0; row < buf.height; row = row + 1 {
    // Move to start of row (1-indexed)
    sb.write_string(ansi_move_to(row + 1, 1))
    for col = 0; col < buf.width; col = col + 1 {
      let cell = buf.get_cell(col, row)
      let pos_key = row * buf.width + col
      // Check for link end (before processing current cell)
      if link_ends.contains(pos_key) && in_hyperlink {
        sb.write_string(ansi_hyperlink_end())
        in_hyperlink = false
      }
      // Check for link start
      match link_starts.get(pos_key) {
        Some(link) => {
          sb.write_string(ansi_hyperlink_start(link.url))
          in_hyperlink = true
        }
        None => ()
      }
      style_state.write_cell(sb, cell)
    }
    // End hyperlink at end of row if still active
    if in_hyperlink {
      sb.write_string(ansi_hyperlink_end())
      in_hyperlink = false
    }
    style_state.reset_underline(sb)
  }
  sb.to_string()
}
