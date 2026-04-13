///|
test "tui runtime paint prepares sorted viewport paint" {
  let style = @style.Style::default()
  let child1 = @node.Node::new("child1", style, [])
  let child2 = @node.Node::new("child2", style, [])
  let root = @node.Node::new("root", style, [child1, child2])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let child1_layout : @types.Layout = {
    id: "child1",
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
  let child2_layout : @types.Layout = {
    id: "child2",
    x: 0.0,
    y: 200.0,
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
    height: 250.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: [child1_layout, child2_layout],
    text: None,
  }

  let prepared = prepare_viewport_paint(root, root_layout, 0.0, 60.0, 0.0)
  inspect(prepared is Some(_), content="true")
  match prepared {
    Some(p) => {
      inspect(p.tree.children.length(), content="1")
      inspect(p.tree.children[0].id, content="child1")
      inspect(p.scrollable_elements.length(), content="0")
    }
    None => fail("viewport-culling should keep the visible child")
  }
}
