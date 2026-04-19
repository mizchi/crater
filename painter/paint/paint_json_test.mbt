///|
test "PaintNode::to_json_string basic" {
  let node = PaintNode::new(
    "body",
    "body",
    0.0,
    0.0,
    800.0,
    600.0,
    PaintProperties::default(),
    [
      PaintNode::new(
        "div.box",
        "div",
        10.0,
        20.0,
        100.0,
        50.0,
        {
          ..PaintProperties::default(),
          background_color: @types.Color::rgb(238, 238, 238),
        },
        [],
        text=Some("Hello"),
      ),
    ],
  )
  let json = node.to_json_string()
  // Check that it contains expected fields
  assert_true(json.contains("\"id\":\"body\""))
  assert_true(json.contains("\"tag\":\"body\""))
  assert_true(json.contains("\"w\":800"))
  assert_true(json.contains("\"text\":\"Hello\""))
  assert_true(json.contains("\"bg\":[238,238,238,"))
}

///|
test "PaintNode::to_json_string includes decoration flags" {
  let node = PaintNode::new(
    "#text",
    "#text",
    0.0,
    0.0,
    80.0,
    20.0,
    {
      ..PaintProperties::default(),
      is_bold: true,
      font_family: "ahem",
      text_decoration_underline: true,
      text_decoration_line_through: true,
      text_decoration_overline: true,
    },
    [],
    text=Some("Hello"),
  )
  let json = node.to_json_string()
  assert_true(json.contains("\"b\":true"))
  assert_true(json.contains("\"ff\":\"ahem\""))
  assert_true(json.contains("\"u\":true"))
  assert_true(json.contains("\"lt\":true"))
  assert_true(json.contains("\"ov\":true"))
}
