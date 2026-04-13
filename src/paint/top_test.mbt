///|
test "paint package diff_trees reports paint property changes" {
  let before_paint = PaintProperties::default()
  let after_paint = { ..PaintProperties::default(), opacity: 0.5 }

  let before = PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    100.0,
    40.0,
    before_paint,
    [],
  )
  let after = PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    100.0,
    40.0,
    after_paint,
    [],
  )

  let diff = diff_trees(before, after)
  inspect(diff.changes.length(), content="1")
  inspect(diff.changes[0].property, content="opacity")
}

///|
test "paint package serializes paint nodes to json" {
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
