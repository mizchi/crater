///|
test "paint node bridge owns from_node_and_layout" {
  let style = @style.Style::default()
  let node = @layout.Node::new("root", style, [])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let layout : @layout_types.Layout = {
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

///|
test "paint node bridge does not apply translated layout twice" {
  let parent_style = @style.Style::default()
  let child_style = @style.Style::default()
  child_style.transform = {
    ..@style.Transform::none(),
    translate_x: @style.TranslateValue::Length(24.0),
    scale_x: 2.0,
    scale_y: 0.5,
  }
  let child_node = @layout.Node::new("span.thumb", child_style, [])
  let node = @layout.Node::new("div.track", parent_style, [child_node])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let child_layout : @layout_types.Layout = {
    id: "span.thumb",
    x: 26.0,
    y: 3.0,
    width: 36.0,
    height: 9.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 36.0,
    scroll_height: 9.0,
    children: [],
    text: None,
  }
  let layout : @layout_types.Layout = {
    id: "div.track",
    x: 0.0,
    y: 0.0,
    width: 48.0,
    height: 24.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 48.0,
    scroll_height: 24.0,
    children: [child_layout],
    text: None,
  }
  let paint_node = from_node_and_layout(node, layout)
  inspect(paint_node.children[0].x, content="26")
  inspect(paint_node.children[0].width, content="36")
  inspect(paint_node.children[0].height, content="9")
}
