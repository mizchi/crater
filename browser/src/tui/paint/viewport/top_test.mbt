///|
test "tui viewport paint keeps viewport conversion" {
  let style = @style.Style::default()
  let child = @node.Node::new("child", style, [])
  let root = @node.Node::new("root", style, [child])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let child_layout : @types.Layout = {
    id: "child",
    x: 0.0,
    y: 0.0,
    width: 100.0,
    height: 50.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: [],
    text: None,
  }
  let root_layout : @types.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 100.0,
    height: 50.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: [child_layout],
    text: None,
  }
  let paint_node = from_node_and_layout_with_viewport(
    root, root_layout, 0.0, 60.0, 0.0,
  )
  inspect(paint_node is Some(_), content="true")
}
