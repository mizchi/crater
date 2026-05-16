///|
/// RGB Color (0-255 range)
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
  a : Int // Alpha (0-255, 255 = opaque)
}

///|
pub fn Color::rgb(r : Int, g : Int, b : Int) -> Color {
  Color::from_msvg(@msvg.Color::rgb(r, g, b))
}

///|
pub fn Color::rgba(r : Int, g : Int, b : Int, a : Int) -> Color {
  Color::from_msvg(@msvg.Color::rgba(r, g, b, a))
}

///|
pub fn Color::transparent() -> Color {
  Color::from_msvg(@msvg.Color::transparent())
}

///|
pub fn Color::black() -> Color {
  Color::from_msvg(@msvg.Color::black())
}

///|
pub fn Color::white() -> Color {
  Color::from_msvg(@msvg.Color::white())
}

///|
pub fn Color::is_transparent(self : Color) -> Bool {
  self.to_msvg().is_transparent()
}

///|
fn Color::from_msvg(color : @msvg.Color) -> Color {
  { r: color.r, g: color.g, b: color.b, a: color.a }
}

///|
fn Color::to_msvg(self : Color) -> @msvg.Color {
  @msvg.Color::{ r: self.r, g: self.g, b: self.b, a: self.a }
}

///|
fn Color::from_msvg_option(color : @msvg.Color?) -> Color? {
  match color {
    Some(c) => Some(Color::from_msvg(c))
    None => None
  }
}
