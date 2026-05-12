///|
/// ANSI Escape Sequences for terminal output
/// Supports 256-color mode

///|
/// Reset all attributes
pub fn ansi_reset() -> String {
  @tui_ansi.ansi_reset()
}

///|
/// Bold text
pub fn ansi_bold() -> String {
  @tui_ansi.ansi_bold()
}

///|
/// Underline text
pub fn ansi_underline() -> String {
  @tui_ansi.ansi_underline()
}

///|
/// Reverse video (swap foreground/background)
pub fn ansi_reverse() -> String {
  @tui_ansi.ansi_reverse()
}

///|
/// Set foreground color using 256-color palette
pub fn ansi_fg_256(color_idx : Int) -> String {
  @tui_ansi.ansi_fg_256(color_idx)
}

///|
/// Set background color using 256-color palette
pub fn ansi_bg_256(color_idx : Int) -> String {
  @tui_ansi.ansi_bg_256(color_idx)
}

///|
/// Move cursor to position (1-indexed, row/col)
pub fn ansi_move_to(row : Int, col : Int) -> String {
  @tui_ansi.ansi_move_to(row - 1, col - 1)
}

///|
/// Convert CharBuffer to ANSI-encoded string
pub fn buffer_to_ansi(buf : CharBuffer, max_cols? : Int = 0) -> String {
  let sb = StringBuilder::new()
  let style_state = AnsiStyleState::new()
  let mut current_row = -1
  for coord in @tui_buffer.plan_buffer_cells(buf.width, buf.height, max_cols) {
    let row = coord.row
    let col = coord.col
    if row != current_row {
      sb.write_string(ansi_move_to(row + 1, 1))
      current_row = row
    }
    let cell = buf.get_cell(col, row)
    // Skip wide char placeholder
    if cell.char == '\u0000' {
      continue
    }
    style_state.write_cell_style(sb, cell)
    sb.write_char(cell.char)
  }
  // Reset at end
  sb.write_string(ansi_reset())
  sb.to_string()
}

///|
/// Enable mouse tracking (SGR mode for better coordinates)
pub fn enable_mouse() -> String {
  @tui_ansi.enable_mouse_all()
}

///|
/// Disable mouse tracking
pub fn disable_mouse() -> String {
  @tui_ansi.disable_mouse_all()
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
