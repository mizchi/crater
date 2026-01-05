// =============================================================================
// Color Types
// =============================================================================
//
// RGBA color representation for computed CSS colors.
// All color values are resolved to this format by css/computed.

///|
/// RGBA color with 8-bit channels and alpha
pub(all) struct Color {
  r : Int // 0-255
  g : Int // 0-255
  b : Int // 0-255
  a : Double // 0.0-1.0
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
/// Transparent color (alpha = 0)
pub fn Color::transparent() -> Color {
  { r: 0, g: 0, b: 0, a: 0.0 }
}

///|
/// Black color
pub fn Color::black() -> Color {
  { r: 0, g: 0, b: 0, a: 1.0 }
}

///|
/// White color
pub fn Color::white() -> Color {
  { r: 255, g: 255, b: 255, a: 1.0 }
}

///|
pub fn Color::is_transparent(self : Color) -> Bool {
  self.a == 0.0
}

///|
pub fn Color::is_opaque(self : Color) -> Bool {
  self.a == 1.0
}

///|
/// Convert to CSS hex string (#rrggbb or #rrggbbaa)
pub fn Color::to_hex(self : Color) -> String {
  fn hex_char(n : Int) -> Char {
    if n < 10 {
      ('0'.to_int() + n).unsafe_to_char()
    } else {
      ('a'.to_int() + n - 10).unsafe_to_char()
    }
  }

  fn hex2(n : Int) -> String {
    let hi = n / 16 % 16
    let lo = n % 16
    let sb = StringBuilder::new()
    sb.write_char(hex_char(hi))
    sb.write_char(hex_char(lo))
    sb.to_string()
  }

  let rgb = "#" + hex2(self.r) + hex2(self.g) + hex2(self.b)
  if self.a < 1.0 {
    let alpha_byte = (self.a * 255.0).to_int()
    rgb + hex2(alpha_byte)
  } else {
    rgb
  }
}

///|
/// Convert to CSS rgba() string
pub fn Color::to_rgba_string(self : Color) -> String {
  if self.a == 1.0 {
    "rgb(\{self.r}, \{self.g}, \{self.b})"
  } else {
    "rgba(\{self.r}, \{self.g}, \{self.b}, \{self.a})"
  }
}

///|
pub impl Show for Color with output(self, logger) {
  logger.write_string(self.to_rgba_string())
}

///|
pub impl Eq for Color with equal(self, other) {
  self.r == other.r &&
  self.g == other.g &&
  self.b == other.b &&
  self.a == other.a
}
