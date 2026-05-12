///|
/// Character-based framebuffer for TUI rendering
/// Inspired by ratatui's Buffer implementation

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
  buf.to_string().trim().to_owned()
}

///|
/// Clear the buffer (fill with default cells)
pub fn CharBuffer::clear(self : CharBuffer) -> Unit {
  let default_cell = CharCell::default()
  for i = 0; i < self.cells.length(); i = i + 1 {
    self.cells[i] = default_cell
  }
}
