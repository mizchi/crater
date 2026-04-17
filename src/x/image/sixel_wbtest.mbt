///|
test "build_sixel_palette_definition emits normalized rgb percentages" {
  let palette = [Color::white(), Color::blue(), { r: 10, g: 20, b: 30 }]
  inspect(
    build_sixel_palette_definition(palette),
    content=(
      #|#0;2;100;100;100#1;2;25;52;95#2;2;3;7;11
    ),
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
