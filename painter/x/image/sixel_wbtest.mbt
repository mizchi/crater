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

///|
test "resolve_glyph_text_wrap_width disables painter wrapping for single line text" {
  inspect(
    resolve_glyph_text_wrap_width(
      752, 38, 32.0, "http://info.cern.ch - home of the first website",
    ),
    content="0",
  )
}

///|
test "resolve_glyph_text_wrap_width disables painter wrapping for regular single line text" {
  inspect(
    resolve_glyph_text_wrap_width(480, 19, 16.0, "From here you can:"),
    content="0",
  )
}

///|
test "resolve_glyph_text_wrap_width keeps wrapping for long prose text" {
  inspect(
    resolve_glyph_text_wrap_width(
      448, 19, 16.0, "This domain is for use in documentation examples without needing permission. Avoid use in operations.",
    ),
    content="448",
  )
}

///|
test "resolve_glyph_text_wrap_width keeps wrapping for multi line text" {
  inspect(
    resolve_glyph_text_wrap_width(240, 40, 16.0, "short line"),
    content="240",
  )
}
