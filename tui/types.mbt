///|
/// TUI Color type (RGBA)
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
  a : Double
}

///|
pub fn Color::rgb(r : Int, g : Int, b : Int) -> Color {
  { r, g, b, a: 1.0 }
}

///|
pub fn Color::rgba(r : Int, g : Int, b : Int, a : Double) -> Color {
  { r, g, b, a }
}

///|
pub fn Color::white() -> Color {
  { r: 255, g: 255, b: 255, a: 1.0 }
}

///|
pub fn Color::black() -> Color {
  { r: 0, g: 0, b: 0, a: 1.0 }
}

///|
pub fn Color::transparent() -> Color {
  { r: 0, g: 0, b: 0, a: 0.0 }
}

///|
pub fn Color::red() -> Color {
  { r: 255, g: 0, b: 0, a: 1.0 }
}

///|
pub fn Color::green() -> Color {
  { r: 0, g: 255, b: 0, a: 1.0 }
}

///|
pub fn Color::blue() -> Color {
  { r: 0, g: 0, b: 255, a: 1.0 }
}

///|
pub fn Color::yellow() -> Color {
  { r: 255, g: 255, b: 0, a: 1.0 }
}

///|
pub fn Color::cyan() -> Color {
  { r: 0, g: 255, b: 255, a: 1.0 }
}

///|
pub fn Color::magenta() -> Color {
  { r: 255, g: 0, b: 255, a: 1.0 }
}

///|
pub fn Color::is_transparent(self : Color) -> Bool {
  self.a < 0.01
}

///|
pub impl Eq for Color with equal(self, other) {
  self.r == other.r &&
  self.g == other.g &&
  self.b == other.b &&
  self.a == other.a
}

///|
/// Convert from crater Color
pub fn Color::from_crater(c : @types.Color) -> Color {
  { r: c.r, g: c.g, b: c.b, a: c.a }
}

///|
/// A single character cell in the terminal
pub(all) struct CharCell {
  char : Char
  fg : Color
  bg : Color
  bold : Bool
  underline : Bool
  reverse : Bool
}

///|
pub fn CharCell::default() -> CharCell {
  {
    char: ' ',
    fg: Color::white(),
    bg: Color::transparent(),
    bold: false,
    underline: false,
    reverse: false,
  }
}

///|
pub fn CharCell::from_char(c : Char) -> CharCell {
  { ..CharCell::default(), char: c }
}

///|
pub fn CharCell::styled(c : Char, fg : Color, bg : Color) -> CharCell {
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
/// Text style for writing text
pub(all) struct TextStyle {
  fg : Color
  bg : Color
  bold : Bool
  underline : Bool
}

///|
pub fn TextStyle::default() -> TextStyle {
  {
    fg: Color::white(),
    bg: Color::transparent(),
    bold: false,
    underline: false,
  }
}

///|
/// Result of an input session
pub(all) enum InputResult {
  Confirmed(String)
  Cancelled
  TabNext(String) // Tab pressed - confirm and move to next
  TabPrev(String) // Shift+Tab pressed - confirm and move to previous
}
