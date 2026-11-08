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
fn to_tui_colors(colors : Array[Color]) -> Array[@tui_kitty.Color] {
  colors.map(fn(color) { @tui_kitty.Color::rgb(color.r, color.g, color.b) })
}

///|
pub fn chunk_size() -> Int32 {
  @tui_kitty.chunk_size()
}

///|
pub fn encode_indexed_pixels_to_kitty(
  width : Int32,
  height : Int32,
  pixels : Array[Int32],
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
  width : Int32,
  height : Int32,
  pixels : Array[Int32],
  colors : Array[Color],
  display_cols : Int32,
  display_rows : Int32,
  image_id~ : Int32 = 0,
  placement_id~ : Int32 = 0,
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
  display_cols : Int32,
  display_rows : Int32,
  image_id~ : Int32 = 0,
  placement_id~ : Int32 = 0,
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
  pixel_width : Int32,
  pixel_height : Int32,
  display_cols : Int32,
  display_rows : Int32,
  image_id~ : Int32 = 0,
  placement_id~ : Int32 = 0,
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
  image_id : Int32,
  placement_id : Int32,
  display_cols : Int32,
  display_rows : Int32,
) -> String {
  @tui_kitty.encode_put_placement(
    image_id, placement_id, display_cols, display_rows,
  )
}

///|
pub fn encode_delete_placement(
  image_id : Int32,
  placement_id : Int32,
) -> String {
  @tui_kitty.encode_delete_placement(image_id, placement_id)
}

///|
pub async fn[T : @io.Writer] write_indexed_pixels_to_kitty(
  writer : T,
  width : Int32,
  height : Int32,
  pixels : Array[Int32],
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
