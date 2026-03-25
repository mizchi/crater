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
