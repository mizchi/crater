///|
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
}

///|
pub fn Color::rgb(r : Int, g : Int, b : Int) -> Color {
  { r, g, b }
}

///|
fn to_tui_colors(colors : Array[Color]) -> Array[@tui_sixel.Color] {
  colors.map(fn(color) { @tui_sixel.Color::rgb(color.r, color.g, color.b) })
}

///|
pub fn encode_indexed_pixels_to_sixel(
  width : Int,
  height : Int,
  pixels : Array[Int],
  colors : Array[Color],
  include_all_colors? : Bool = false,
  compress? : Bool = true,
) -> String {
  @tui_sixel.encode_indexed_pixels_to_sixel(
    width,
    height,
    pixels,
    to_tui_colors(colors),
    include_all_colors~,
    compress~,
  )
}
