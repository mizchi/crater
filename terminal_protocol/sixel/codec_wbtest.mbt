///|
test "build_sixel_palette_definition emits normalized rgb percentages" {
  let palette = [Color::rgb(255, 128, 0), Color::rgb(0, 64, 255)]
  inspect(
    build_sixel_palette_definition(palette),
    content="#0;2;100;50;0#1;2;0;25;100",
  )
}

///|
test "build_sixel_color_headers precomputes selectors" {
  inspect(
    build_sixel_color_headers(4),
    content=(
      #|["#0", "#1", "#2", "#3"]
    ),
  )
}

///|
test "encode_indexed_pixels_to_sixel compresses active color rows" {
  let pixels = Array::make(24, 1)
  let colors = [Color::rgb(255, 255, 255), Color::rgb(66, 133, 244)]
  let result = encode_indexed_pixels_to_sixel(4, 6, pixels, colors)
  inspect(
    result,
    content="\u001bPq#0;2;100;100;100#1;2;25;52;95#1!4~$-\u001b\\",
  )
}
