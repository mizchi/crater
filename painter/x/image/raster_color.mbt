///|
/// RGB Color (0-255 range)
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
}

///|
/// Predefined colors for visualization
pub fn Color::transparent() -> Color {
  { r: 0, g: 0, b: 0 }
}

///|
pub fn Color::blue() -> Color {
  { r: 66, g: 133, b: 244 }
}

///|
pub fn Color::green() -> Color {
  { r: 52, g: 168, b: 83 }
}

///|
pub fn Color::yellow() -> Color {
  { r: 251, g: 188, b: 4 }
}

///|
pub fn Color::red() -> Color {
  { r: 234, g: 67, b: 53 }
}

///|
pub fn Color::gray() -> Color {
  { r: 154, g: 160, b: 166 }
}

///|
pub fn Color::white() -> Color {
  { r: 255, g: 255, b: 255 }
}

///|
pub fn Color::black() -> Color {
  { r: 0, g: 0, b: 0 }
}

///|
/// Get color by depth level
pub fn get_depth_color(depth : Int) -> Color {
  let colors = [
    Color::blue(),
    Color::green(),
    Color::yellow(),
    Color::red(),
    Color::gray(),
  ]
  colors[depth % colors.length()]
}

///|
/// Blend color with alpha (0-255)
pub fn Color::blend(self : Color, bg : Color, alpha : Int) -> Color {
  let a = alpha.to_double() / 255.0
  let inv_a = 1.0 - a
  {
    r: (self.r.to_double() * a + bg.r.to_double() * inv_a).to_int(),
    g: (self.g.to_double() * a + bg.g.to_double() * inv_a).to_int(),
    b: (self.b.to_double() * a + bg.b.to_double() * inv_a).to_int(),
  }
}
