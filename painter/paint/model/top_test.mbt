///|
test "paint model re-exports paint node types" {
  let node = PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    120.0,
    50.0,
    PaintProperties::default(),
    [],
    text=Some("hello"),
  )

  let json = node.to_json_string()
  inspect(json.contains("\"id\":\"root\""), content="true")
  inspect(json.contains("\"text\":\"hello\""), content="true")
}

///|
test "paint properties carry text layout spacing" {
  let style = @style.Style::default()
  style.font_size = 12.0
  style.line_height = 18.0
  style.letter_spacing = 1.5
  style.word_spacing = 3.0
  let paint = PaintProperties::from_style(style)
  inspect(paint.font_size, content="12")
  inspect(paint.line_height, content="18")
  inspect(paint.letter_spacing, content="1.5")
  inspect(paint.word_spacing, content="3")
}
