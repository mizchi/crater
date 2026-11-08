///|
pub(all) struct Color {
  r : Int32
  g : Int32
  b : Int32
}

///|
pub fn Color::rgb(r : Int32, g : Int32, b : Int32) -> Color {
  { r, g, b, }
}

///|
fn to_tui_colors(colors : Array[Color]) -> Array[@tui_sixel.Color] {
  colors.map(fn(color) { @tui_sixel.Color::rgb(color.r, color.g, color.b) })
}

///|
pub fn encode_indexed_pixels_to_sixel(
  width : Int32,
  height : Int32,
  pixels : Array[Int32],
  colors : Array[Color],
  include_all_colors~ : Bool = false,
  compress~ : Bool = true,
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
