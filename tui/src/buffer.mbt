///|
/// Character-based framebuffer for TUI rendering

///|
/// Character-based framebuffer
pub struct CharBuffer {
  width : Int
  height : Int
  cells : Array[CharCell]
}

///|
pub fn CharBuffer::new(width : Int, height : Int) -> CharBuffer {
  let size = width * height
  let cells : Array[CharCell] = Array::make(size, CharCell::default())
  { width, height, cells }
}

///|
pub fn CharBuffer::get_cell(self : CharBuffer, x : Int, y : Int) -> CharCell {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    self.cells[y * self.width + x]
  } else {
    CharCell::default()
  }
}

///|
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
pub fn CharBuffer::fill_bg(
  self : CharBuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  bg : Color,
) -> Unit {
  for row = y; row < y + h; row = row + 1 {
    for col = x; col < x + w; col = col + 1 {
      if col >= 0 && col < self.width && row >= 0 && row < self.height {
        let existing = self.get_cell(col, row)
        self.set_cell(col, row, { ..existing, bg, })
      }
    }
  }
}

///|
fn is_wide_char(c : Char) -> Bool {
  let cp = c.to_int()
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  (cp >= 0x3040 && cp <= 0x309F) ||
  (cp >= 0x30A0 && cp <= 0x30FF) ||
  (cp >= 0xAC00 && cp <= 0xD7AF) ||
  (cp >= 0xFF00 && cp <= 0xFFEF) ||
  (cp >= 0x3000 && cp <= 0x303F)
}

///|
pub fn char_display_width(c : Char) -> Int {
  if is_wide_char(c) {
    2
  } else {
    1
  }
}

///|
/// Calculate display width of a string
pub fn string_display_width(s : String) -> Int {
  let mut width = 0
  for c in s {
    width = width + char_display_width(c)
  }
  width
}

///|
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
    if c == '\n' {
      break
    }
    if c.to_int() < 32 {
      continue
    }
    let width = char_display_width(c)
    if cur_x + width > end_x {
      break
    }
    let bg = if style.bg.is_transparent() {
      self.get_cell(cur_x, y).bg
    } else {
      style.bg
    }
    let cell : CharCell = {
      char: c,
      fg: style.fg,
      bg,
      bold: style.bold,
      underline: style.underline,
      reverse: false,
    }
    self.set_cell(cur_x, y, cell)
    if width == 2 && cur_x + 1 < end_x {
      let next_bg = if style.bg.is_transparent() {
        self.get_cell(cur_x + 1, y).bg
      } else {
        style.bg
      }
      let placeholder : CharCell = {
        char: '\u0000',
        fg: style.fg,
        bg: next_bg,
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
    if c == '\n' {
      cur_x = x
      cur_y = cur_y + 1
      continue
    }
    if c.to_int() < 32 {
      continue
    }
    let width = char_display_width(c)
    if cur_x + width > end_x {
      cur_x = x
      cur_y = cur_y + 1
      if cur_y >= end_y {
        break
      }
    }
    let bg = if style.bg.is_transparent() {
      self.get_cell(cur_x, cur_y).bg
    } else {
      style.bg
    }
    let cell : CharCell = {
      char: c,
      fg: style.fg,
      bg,
      bold: style.bold,
      underline: style.underline,
      reverse: false,
    }
    self.set_cell(cur_x, cur_y, cell)
    if width == 2 && cur_x + 1 < end_x {
      let next_bg = if style.bg.is_transparent() {
        self.get_cell(cur_x + 1, cur_y).bg
      } else {
        style.bg
      }
      let placeholder : CharCell = {
        char: '\u0000',
        fg: style.fg,
        bg: next_bg,
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
pub fn CharBuffer::clear(self : CharBuffer) -> Unit {
  let default_cell = CharCell::default()
  for i = 0; i < self.cells.length(); i = i + 1 {
    self.cells[i] = default_cell
  }
}

///|
/// Clone the buffer
pub fn CharBuffer::clone(self : CharBuffer) -> CharBuffer {
  let new_cells = Array::make(self.cells.length(), CharCell::default())
  for i = 0; i < self.cells.length(); i = i + 1 {
    new_cells[i] = self.cells[i]
  }
  { width: self.width, height: self.height, cells: new_cells }
}
