///|
test "paint diff wraps diff_trees" {
  let before = @model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    100.0,
    40.0,
    @model.PaintProperties::default(),
    [],
  )
  let after = @model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    100.0,
    40.0,
    { ..@model.PaintProperties::default(), opacity: 0.5 },
    [],
  )

  let diff = diff_trees(before, after)
  inspect(diff.changes.length(), content="1")
  inspect(diff.changes[0].property, content="opacity")
}
