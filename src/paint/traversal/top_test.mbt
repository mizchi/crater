///|
test "paint traversal owns stacking order normalization" {
  let paint = @model.PaintProperties::default()
  let back = @model.PaintNode::new(
    "back",
    "div",
    0.0,
    0.0,
    10.0,
    10.0,
    { ..paint, z_index: @style.ZIndex::Value(0) },
    [],
  )
  let front = @model.PaintNode::new(
    "front",
    "div",
    0.0,
    0.0,
    10.0,
    10.0,
    { ..paint, z_index: @style.ZIndex::Value(10) },
    [],
  )
  let sorted = sort_by_stacking_order([front, back])
  inspect(sorted[0].id, content="back")
  inspect(sorted[1].id, content="front")
}

///|
test "paint traversal skips hidden nodes when flattening" {
  let hidden = @model.PaintNode::new(
    "hidden",
    "div",
    0.0,
    0.0,
    10.0,
    10.0,
    {
      ..@model.PaintProperties::default(),
      visibility: @style.Visibility::Hidden,
    },
    [],
  )
  let visible = @model.PaintNode::new(
    "visible",
    "div",
    0.0,
    0.0,
    10.0,
    10.0,
    @model.PaintProperties::default(),
    [],
  )
  let root = @model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    10.0,
    10.0,
    @model.PaintProperties::default(),
    [hidden, visible],
  )
  let flattened = flatten_for_rendering(root)
  inspect(flattened.length(), content="2")
  inspect(flattened[0].id, content="root")
  inspect(flattened[1].id, content="visible")
}
