///|
/// Text writing helpers for TUI character buffers.

///|
/// Get display width of a character (1 for narrow, 2 for wide)
pub fn char_display_width(c : Char) -> Int {
  @tui_buffer.char_display_width(c)
}

///|
fn CharBuffer::styled_cell_at(
  self : CharBuffer,
  x : Int,
  y : Int,
  c : Char,
  style : TextStyle,
) -> CharCell {
  let bg = if style.bg.is_transparent() {
    self.get_cell(x, y).bg
  } else {
    style.bg
  }
  {
    char: c,
    fg: style.fg,
    bg,
    bold: style.bold,
    underline: style.underline,
    reverse: false,
  }
}

///|
fn CharBuffer::apply_text_write_plan(
  self : CharBuffer,
  plan : @tui_buffer.TextWritePlan,
  style : TextStyle,
) -> Unit {
  for cell in plan.cells {
    self.set_cell(
      cell.x,
      cell.y,
      self.styled_cell_at(cell.x, cell.y, cell.char, style),
    )
  }
}

///|
/// Write text at position with style
/// Returns the number of columns written
/// Note: If style.bg is transparent, preserves existing cell background
pub fn CharBuffer::write_text(
  self : CharBuffer,
  x : Int,
  y : Int,
  text : String,
  style : TextStyle,
  max_width : Int,
) -> Int {
  let plan = @tui_buffer.plan_write_text(x, y, text, max_width)
  self.apply_text_write_plan(plan, style)
  plan.columns
}

///|
/// Write preformatted text (for white-space: pre)
/// Respects newlines but does NOT auto-wrap at word boundaries
/// Returns the number of lines used
/// Note: If style.bg is transparent, preserves existing cell background
pub fn CharBuffer::write_text_pre(
  self : CharBuffer,
  x : Int,
  y : Int,
  text : String,
  style : TextStyle,
  max_width : Int,
  max_height : Int,
) -> Int {
  let plan = @tui_buffer.plan_write_text_pre(x, y, text, max_width, max_height)
  self.apply_text_write_plan(plan, style)
  plan.lines
}

///|
/// Write text with wrapping
/// Returns the number of lines used
/// Note: If style.bg is transparent, preserves existing cell background
pub fn CharBuffer::write_text_wrapped(
  self : CharBuffer,
  x : Int,
  y : Int,
  text : String,
  style : TextStyle,
  max_width : Int,
  max_height : Int,
) -> Int {
  let plan = @tui_buffer.plan_write_text_wrapped(
    x, y, text, max_width, max_height,
  )
  self.apply_text_write_plan(plan, style)
  plan.lines
}
