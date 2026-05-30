///|
/// Character cell and text style types for TUI buffers.

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
pub impl Eq for CharCell with fn equal(self, other) {
  self.char == other.char &&
  self.fg == other.fg &&
  self.bg == other.bg &&
  self.bold == other.bold &&
  self.underline == other.underline &&
  self.reverse == other.reverse
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
