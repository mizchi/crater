///|
test "paint viewport bridge owns viewport culling" {
  let style = @style.Style::default()
  let child1 = @layout.Node::new("child1", style, [])
  let child2 = @layout.Node::new("child2", style, [])
  let root = @layout.Node::new("root", style, [child1, child2])
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

  let paint = from_node_and_layout_with_viewport(
    root, root_layout, 0.0, 60.0, 0.0,
  )
  inspect(paint is Some(_), content="true")
  match paint {
    Some(node) => {
      inspect(node.children.length(), content="1")
      inspect(node.children[0].id, content="child1")
    }
    None => fail("viewport-culling should keep the visible child")
  }
}

///|
test "paint viewport bridge prunes horizontally outside viewport rect" {
  let style = @style.Style::default()
  let visible = @layout.Node::new("visible", style, [])
  let offscreen = @layout.Node::new("offscreen", style, [])
  let root = @layout.Node::new("root", style, [visible, offscreen])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let visible_layout : @types.Layout = {
    id: "visible",
    x: 0.0,
    y: 0.0,
    width: 50.0,
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
  let offscreen_layout : @types.Layout = {
    ..visible_layout,
    id: "offscreen",
    x: 200.0,
  }
  let root_layout : @types.Layout = {
    ..visible_layout,
    id: "root",
    width: 260.0,
    children: [visible_layout, offscreen_layout],
  }
  match
    from_node_and_layout_with_viewport_rect(
      root, root_layout, 0.0, 0.0, 100.0, 100.0, 0.0, 0.0,
    ) {
    Some(paint) => {
      inspect(paint.children.length(), content="1")
      inspect(paint.children[0].id, content="visible")
    }
    None => fail("root should stay visible")
  }
}

///|
test "paint viewport bridge prunes children outside overflow clip" {
  let style = @style.Style::default()
  let clip_style = @style.Style::default()
  clip_style.overflow_x = @types.Hidden
  clip_style.overflow_y = @types.Hidden
  let hidden_child = @layout.Node::new("hidden", style, [])
  let clipper = @layout.Node::new("clipper", clip_style, [hidden_child])
  let root = @layout.Node::new("root", style, [clipper])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let hidden_layout : @types.Layout = {
    id: "hidden",
    x: 0.0,
    y: 150.0,
    width: 40.0,
    height: 40.0,
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
  let clipper_layout : @types.Layout = {
    ..hidden_layout,
    id: "clipper",
    y: 0.0,
    width: 100.0,
    height: 100.0,
    overflow_x: @types.Hidden,
    overflow_y: @types.Hidden,
    children: [hidden_layout],
  }
  let root_layout : @types.Layout = {
    ..clipper_layout,
    id: "root",
    width: 200.0,
    height: 220.0,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    children: [clipper_layout],
  }
  match
    from_node_and_layout_with_viewport_rect(
      root, root_layout, 0.0, 0.0, 200.0, 220.0, 0.0, 0.0,
    ) {
    Some(paint) => {
      inspect(paint.children.length(), content="1")
      inspect(paint.children[0].children.length(), content="0")
    }
    None => fail("root should stay visible")
  }
}

///|
test "paint viewport bridge prunes fully covered earlier opaque siblings" {
  let red_style = @style.Style::default()
  red_style.background_color = @types.Color::rgb(255, 0, 0)
  let green_style = @style.Style::default()
  green_style.background_color = @types.Color::rgb(0, 255, 0)
  let red = @layout.Node::new("red", red_style, [])
  let green = @layout.Node::new("green", green_style, [])
  let root = @layout.Node::new("root", @style.Style::default(), [red, green])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let red_layout : @types.Layout = {
    id: "red",
    x: 0.0,
    y: 0.0,
    width: 100.0,
    height: 100.0,
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
  let green_layout : @types.Layout = { ..red_layout, id: "green" }
  let root_layout : @types.Layout = {
    ..red_layout,
    id: "root",
    children: [red_layout, green_layout],
  }
  match
    from_node_and_layout_with_viewport_rect(
      root, root_layout, 0.0, 0.0, 100.0, 100.0, 0.0, 0.0,
    ) {
    Some(paint) => {
      inspect(paint.children.length(), content="1")
      inspect(paint.children[0].id, content="green")
    }
    None => fail("root should stay visible")
  }
}
