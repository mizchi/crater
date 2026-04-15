///|
test "paint scroll owns scrollable traversal" {
  let child = @model.PaintNode::new(
    "child",
    "div",
    0.0,
    0.0,
    100.0,
    40.0,
    @model.PaintProperties::default(),
    [],
    overflow_x=@types.Overflow::Auto,
    overflow_y=@types.Overflow::Auto,
    scroll_width=200.0,
    scroll_height=120.0,
  )
  let root = @model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    100.0,
    40.0,
    @model.PaintProperties::default(),
    [child],
  )
  let items = collect_scrollable_elements(root)
  inspect(items.length(), content="1")
  inspect(items[0].id, content="child")
}

///|
test "paint scroll hit test returns deepest scrollable node" {
  let child = @model.PaintNode::new(
    "child",
    "div",
    10.0,
    10.0,
    80.0,
    30.0,
    @model.PaintProperties::default(),
    [],
    overflow_x=@types.Overflow::Auto,
    overflow_y=@types.Overflow::Auto,
    scroll_width=160.0,
    scroll_height=90.0,
  )
  let root = @model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    100.0,
    50.0,
    @model.PaintProperties::default(),
    [child],
    overflow_x=@types.Overflow::Auto,
    overflow_y=@types.Overflow::Auto,
    scroll_width=100.0,
    scroll_height=80.0,
  )
  let hit = find_scrollable_at(root, 20.0, 20.0, 0.0, 0.0)
  inspect(hit is Some(_), content="true")
  match hit {
    Some(result) => inspect(result.id, content="child")
    None => fail("expected deepest scrollable hit")
  }
}
