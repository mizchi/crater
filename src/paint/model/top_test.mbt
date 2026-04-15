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
