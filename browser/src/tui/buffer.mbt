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
  for row = y; row < y + h; row = row + 1 {
    for col = x; col < x + w; col = col + 1 {
      self.set_cell(col, row, cell)
    }
  }
}

///|
/// Fill a rectangle with just a background color
pub fn CharBuffer::fill_bg(
  self : CharBuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  bg : @types.Color,
) -> Unit {
  let cell = { ..CharCell::default(), bg }
  self.fill_rect(x, y, w, h, cell)
}

///|
/// Check if character is a wide (CJK) character
fn is_wide_char(c : Char) -> Bool {
  let cp = c.to_int()
  // CJK Unified Ideographs
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  // CJK Extension A
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  // Hiragana
  (cp >= 0x3040 && cp <= 0x309F) ||
  // Katakana
  (cp >= 0x30A0 && cp <= 0x30FF) ||
  // Hangul Syllables
  (cp >= 0xAC00 && cp <= 0xD7AF) ||
  // Fullwidth Forms
  (cp >= 0xFF00 && cp <= 0xFFEF) ||
  // CJK Symbols and Punctuation
  (cp >= 0x3000 && cp <= 0x303F)
}

///|
/// Get display width of a character (1 for narrow, 2 for wide)
pub fn char_display_width(c : Char) -> Int {
  if is_wide_char(c) { 2 } else { 1 }
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
/// Write text at position with style
/// Returns the number of columns written
pub fn CharBuffer::write_text(
  self : CharBuffer,
  x : Int,
  y : Int,
  text : String,
  style : TextStyle,
  max_width : Int,
) -> Int {
  let mut cur_x = x
  let end_x = x + max_width
  for c in text {
    // Handle newline
    if c == '\n' {
      break
    }
    // Skip control characters
    if c.to_int() < 32 {
      continue
    }
    let width = char_display_width(c)
    // Check if we have room
    if cur_x + width > end_x {
      break
    }
    // Write the character
    let cell : CharCell = {
      char: c,
      fg: style.fg,
      bg: style.bg,
      bold: style.bold,
      underline: style.underline,
      reverse: false,
    }
    self.set_cell(cur_x, y, cell)
    // For wide characters, fill next cell with a placeholder
    if width == 2 && cur_x + 1 < end_x {
      // Use a special marker for the second half of wide char
      let placeholder : CharCell = {
        char: '\u0000', // Null as placeholder for wide char continuation
        fg: style.fg,
        bg: style.bg,
        bold: style.bold,
        underline: style.underline,
        reverse: false,
      }
      self.set_cell(cur_x + 1, y, placeholder)
    }
    cur_x = cur_x + width
  }
  cur_x - x
}

///|
/// Write text with wrapping
/// Returns the number of lines used
pub fn CharBuffer::write_text_wrapped(
  self : CharBuffer,
  x : Int,
  y : Int,
  text : String,
  style : TextStyle,
  max_width : Int,
  max_height : Int,
) -> Int {
  let mut cur_x = x
  let mut cur_y = y
  let end_x = x + max_width
  let end_y = y + max_height
  for c in text {
    if cur_y >= end_y {
      break
    }
    // Handle newline
    if c == '\n' {
      cur_x = x
      cur_y = cur_y + 1
      continue
    }
    // Skip control characters
    if c.to_int() < 32 {
      continue
    }
    let width = char_display_width(c)
    // Check if we need to wrap
    if cur_x + width > end_x {
      cur_x = x
      cur_y = cur_y + 1
      if cur_y >= end_y {
        break
      }
    }
    // Write the character
    let cell : CharCell = {
      char: c,
      fg: style.fg,
      bg: style.bg,
      bold: style.bold,
      underline: style.underline,
      reverse: false,
    }
    self.set_cell(cur_x, cur_y, cell)
    if width == 2 && cur_x + 1 < end_x {
      let placeholder : CharCell = {
        char: '\u0000',
        fg: style.fg,
        bg: style.bg,
        bold: style.bold,
        underline: style.underline,
        reverse: false,
      }
      self.set_cell(cur_x + 1, cur_y, placeholder)
    }
    cur_x = cur_x + width
  }
  cur_y - y + 1
}

///|
/// Clear the buffer (fill with default cells)
pub fn CharBuffer::clear(self : CharBuffer) -> Unit {
  let default_cell = CharCell::default()
  for i = 0; i < self.cells.length(); i = i + 1 {
    self.cells[i] = default_cell
  }
}
