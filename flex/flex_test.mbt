///|
test "flex_row_basic" {
  let default_style = @style.Style::default()

  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })

  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])

  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
  }
  let layout = compute(root, ctx)

  inspect(layout.width, content="200")
  inspect(layout.height, content="100")
  // Children should be side by side
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[1].x, content="50")
  inspect(layout.children[1].y, content="0")
  inspect(layout.children[1].width, content="50")
}

///|
test "flex_column_basic" {
  let default_style = @style.Style::default()

  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(40.0),
  })

  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Column,
    width: @types.Length(200.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])

  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
  }
  let layout = compute(root, ctx)

  inspect(layout.width, content="200")
  // Children should be stacked vertically
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].height, content="30")
  inspect(layout.children[1].x, content="0")
  inspect(layout.children[1].y, content="30")
  inspect(layout.children[1].height, content="40")
}

///|
test "flex_grow" {
  let default_style = @style.Style::default()

  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_grow: 1.0,
    height: @types.Length(30.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    flex_grow: 2.0,
    height: @types.Length(30.0),
  })

  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(300.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])

  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
  }
  let layout = compute(root, ctx)

  // Child1 gets 1/3 of space, child2 gets 2/3
  inspect(layout.children[0].width, content="100")
  inspect(layout.children[1].width, content="200")
  inspect(layout.children[1].x, content="100")
}

///|
test "flex_justify_center" {
  let default_style = @style.Style::default()

  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(100.0),
    height: @types.Length(30.0),
  })

  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    justify_content: @style.Center,
    width: @types.Length(300.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])

  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
  }
  let layout = compute(root, ctx)

  // Child should be centered: (300 - 100) / 2 = 100
  inspect(layout.children[0].x, content="100")
}

///|
test "flex_justify_space_between" {
  let default_style = @style.Style::default()

  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })

  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    justify_content: @style.SpaceBetween,
    width: @types.Length(300.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])

  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
  }
  let layout = compute(root, ctx)

  // Free space = 300 - 150 = 150, gap = 150 / 2 = 75
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[1].x, content="125")
  inspect(layout.children[2].x, content="250")
}

///|
test "flex_align_center" {
  let default_style = @style.Style::default()

  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })

  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    align_items: @style.Center,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])

  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
  }
  let layout = compute(root, ctx)

  // Child should be vertically centered: (100 - 30) / 2 = 35
  inspect(layout.children[0].y, content="35")
}

///|
test "flex_align_stretch" {
  let default_style = @style.Style::default()

  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(50.0),
    // No height specified, should stretch
  })

  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    align_items: @style.Stretch,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])

  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
  }
  let layout = compute(root, ctx)

  // Child should stretch to full height
  inspect(layout.children[0].height, content="100")
}

///|
test "flex_row_reverse" {
  let default_style = @style.Style::default()

  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })

  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.RowReverse,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])

  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
  }
  let layout = compute(root, ctx)

  // In row-reverse, child2 comes first (at x=0), child1 comes second
  inspect(layout.children[0].id, content="child2")
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[1].id, content="child1")
  inspect(layout.children[1].x, content="50")
}

///|
test "flex_with_padding" {
  let default_style = @style.Style::default()

  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })

  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
    padding: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(20.0),
      bottom: @types.Length(20.0),
    },
  }
  let root = @node.Node::new("root", root_style, [child])

  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
  }
  let layout = compute(root, ctx)

  // Child should be offset by padding
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].y, content="20")
}
