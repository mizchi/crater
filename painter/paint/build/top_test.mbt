///|
test "paint build wraps traversal and scroll APIs" {
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
  let flattened = flatten_for_rendering(root)
  inspect(items.length(), content="1")
  inspect(items[0].id, content="child")
  inspect(flattened.length(), content="2")
}
