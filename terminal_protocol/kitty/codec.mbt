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
fn to_tui_colors(colors : Array[Color]) -> Array[@tui_kitty.Color] {
  colors.map(fn(color) { @tui_kitty.Color::rgb(color.r, color.g, color.b) })
}

///|
pub fn chunk_size() -> Int {
  @tui_kitty.chunk_size()
}

///|
pub fn encode_indexed_pixels_to_kitty(
  width : Int,
  height : Int,
  pixels : Array[Int],
  colors : Array[Color],
) -> String {
  @tui_kitty.encode_indexed_pixels_to_kitty(
    width,
    height,
    pixels,
    to_tui_colors(colors),
  )
}

///|
pub fn encode_indexed_pixels_to_kitty_cells(
  width : Int,
  height : Int,
  pixels : Array[Int],
  colors : Array[Color],
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  @tui_kitty.encode_indexed_pixels_to_kitty_cells(
    width,
    height,
    pixels,
    to_tui_colors(colors),
    display_cols,
    display_rows,
    image_id~,
    placement_id~,
  )
}

///|
pub fn encode_png_base64_to_kitty_image(
  b64_data : String,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  @tui_kitty.encode_png_base64_to_kitty_image(
    b64_data,
    display_cols,
    display_rows,
    image_id~,
    placement_id~,
  )
}

///|
pub fn encode_rgba_base64_to_kitty_image(
  b64_data : String,
  pixel_width : Int,
  pixel_height : Int,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  @tui_kitty.encode_rgba_base64_to_kitty_image(
    b64_data,
    pixel_width,
    pixel_height,
    display_cols,
    display_rows,
    image_id~,
    placement_id~,
  )
}

///|
pub fn encode_put_placement(
  image_id : Int,
  placement_id : Int,
  display_cols : Int,
  display_rows : Int,
) -> String {
  @tui_kitty.encode_put_placement(
    image_id, placement_id, display_cols, display_rows,
  )
}

///|
pub fn encode_delete_placement(image_id : Int, placement_id : Int) -> String {
  @tui_kitty.encode_delete_placement(image_id, placement_id)
}

///|
pub async fn[T : @io.Writer] write_indexed_pixels_to_kitty(
  writer : T,
  width : Int,
  height : Int,
  pixels : Array[Int],
  colors : Array[Color],
) -> Unit {
  @tui_kitty.write_indexed_pixels_to_kitty(
    writer,
    width,
    height,
    pixels,
    to_tui_colors(colors),
  )
}
