///|
test "tui plain paint keeps node conversion" {
  let style = @style.Style::default()
  let node = @node.Node::new("root", style, [])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let layout : @types.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 100.0,
    height: 40.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 100.0,
    scroll_height: 40.0,
    children: [],
    text: None,
  }
  let paint_node = from_node_and_layout(node, layout)
  inspect(paint_node.id, content="root")
  inspect(paint_node.width, content="100")
}
