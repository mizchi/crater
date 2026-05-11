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
  color_from_msvg(@msvg.Color::rgb(r, g, b))
}

///|
pub fn Color::rgba(r : Int, g : Int, b : Int, a : Int) -> Color {
  color_from_msvg(@msvg.Color::rgba(r, g, b, a))
}

///|
pub fn Color::transparent() -> Color {
  color_from_msvg(@msvg.Color::transparent())
}

///|
pub fn Color::black() -> Color {
  color_from_msvg(@msvg.Color::black())
}

///|
pub fn Color::white() -> Color {
  color_from_msvg(@msvg.Color::white())
}

///|
pub fn Color::is_transparent(self : Color) -> Bool {
  color_to_msvg(self).is_transparent()
}
