///|
/// Character-based framebuffer for TUI rendering
/// Inspired by ratatui's Buffer implementation

///|
/// A single character cell in the terminal
pub(all) struct CharCell {
  char : Char // Display character
  fg : @types.Color // Foreground color
  bg : @types.Color // Background color
  bold : Bool
  underline : Bool
  reverse : Bool // Inverse video (swap fg/bg)
}

///|
/// Default cell (space with default colors)
pub fn CharCell::default() -> CharCell {
  {
    char: ' ',
    fg: @types.Color::white(),
    bg: @types.Color::transparent(),
    bold: false,
    underline: false,
    reverse: false,
  }
}

///|
/// Create a cell with just a character
pub fn CharCell::from_char(c : Char) -> CharCell {
  { ..CharCell::default(), char: c }
}

///|
/// Create a cell with character and foreground color
pub fn CharCell::styled(
  c : Char,
  fg : @types.Color,
  bg : @types.Color,
) -> CharCell {
  { ..CharCell::default(), char: c, fg, bg }
}

///|
pub impl Eq for CharCell with equal(self, other) {
  self.char == other.char &&
  self.fg == other.fg &&
  self.bg == other.bg &&
  self.bold == other.bold &&
  self.underline == other.underline &&
  self.reverse == other.reverse
}

///|
/// Character-based framebuffer
pub struct CharBuffer {
  width : Int // Width in character columns
  height : Int // Height in character rows
  cells : Array[CharCell]
}

///|
/// Create a new buffer filled with default cells
pub fn CharBuffer::new(width : Int, height : Int) -> CharBuffer {
  let size = width * height
  let cells : Array[CharCell] = Array::make(size, CharCell::default())
  { width, height, cells }
}

///|
/// Get cell at position (bounds checked)
pub fn CharBuffer::get_cell(self : CharBuffer, x : Int, y : Int) -> CharCell {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    self.cells[y * self.width + x]
  } else {
    CharCell::default()
  }
}

///|
/// Set cell at position (bounds checked)
pub fn CharBuffer::set_cell(
  self : CharBuffer,
  x : Int,
  y : Int,
  cell : CharCell,
) -> Unit {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    self.cells[y * self.width + x] = cell
  }
}

///|
/// Fill a rectangle with a cell
pub fn CharBuffer::fill_rect(
  self : CharBuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  cell : CharCell,
) -> Unit {
  match @tui_buffer.clip_rect(self.width, self.height, x, y, w, h) {
    Some(rect) =>
      for row = rect.y; row < rect.y + rect.h; row = row + 1 {
        for col = rect.x; col < rect.x + rect.w; col = col + 1 {
          self.set_cell(col, row, cell)
        }
      }
    None => ()
  }
}

///|
/// Fill a rectangle with just a background color (preserves char and fg)
pub fn CharBuffer::fill_bg(
  self : CharBuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  bg : @types.Color,
) -> Unit {
  match @tui_buffer.clip_rect(self.width, self.height, x, y, w, h) {
    Some(rect) =>
      for row = rect.y; row < rect.y + rect.h; row = row + 1 {
        for col = rect.x; col < rect.x + rect.w; col = col + 1 {
          let existing = self.get_cell(col, row)
          self.set_cell(col, row, { ..existing, bg, })
        }
      }
    None => ()
  }
}

///|
/// Get display width of a character (1 for narrow, 2 for wide)
pub fn char_display_width(c : Char) -> Int {
  @tui_buffer.char_display_width(c)
}

///|
/// Text style for writing text
pub(all) struct TextStyle {
  fg : @types.Color
  bg : @types.Color
  bold : Bool
  underline : Bool
}

///|
pub fn TextStyle::default() -> TextStyle {
  {
    fg: @types.Color::white(),
    bg: @types.Color::transparent(),
    bold: false,
    underline: false,
  }
}

///|
/// Get text content of a row (for testing)
pub fn CharBuffer::get_row_text(self : CharBuffer, row : Int) -> String {
  if row < 0 || row >= self.height {
    return ""
  }
  let buf = StringBuilder::new()
  for col = 0; col < self.width; col = col + 1 {
    let cell = self.get_cell(col, row)
    // Skip null placeholder (second half of wide character)
    if cell.char == '\u0000' {
      continue
    }
    if cell.char != ' ' {
      buf.write_char(cell.char)
    } else if buf.to_string().length() > 0 {
      // Only add spaces after we've started collecting text
      buf.write_char(' ')
    }
  }
  buf.to_string().trim().to_string()
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

///|
/// Clear the buffer (fill with default cells)
pub fn CharBuffer::clear(self : CharBuffer) -> Unit {
  let default_cell = CharCell::default()
  for i = 0; i < self.cells.length(); i = i + 1 {
    self.cells[i] = default_cell
  }
}
