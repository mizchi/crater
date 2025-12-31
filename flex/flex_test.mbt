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
    sizing_mode: @node.MaxContent,
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
    sizing_mode: @node.MaxContent,
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
    sizing_mode: @node.MaxContent,
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
    sizing_mode: @node.MaxContent,
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
    sizing_mode: @node.MaxContent,
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
    sizing_mode: @node.MaxContent,
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
    sizing_mode: @node.MaxContent,
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
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // In row-reverse, layout starts from the right (main-end)
  // DOM order is preserved: children[0] = child1, children[1] = child2
  // child1 is at x=150 (rightmost), child2 at x=100
  inspect(layout.children[0].id, content="child1")
  inspect(layout.children[0].x, content="150") // 200 - 50 = 150
  inspect(layout.children[1].id, content="child2")
  inspect(layout.children[1].x, content="100") // 150 - 50 = 100
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
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child should be offset by padding
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].y, content="20")
}

///|
/// From taffy: flex_shrink_to_zero
test "flex_shrink_to_zero" {
  let default_style = @style.Style::default()

  // Three children: 50px each, but container is only 75px wide
  // flex-shrink: 0, 1, 0 - only middle child should shrink
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    flex_shrink: 0.0,
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    flex_shrink: 1.0,
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    flex_shrink: 0.0,
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(75.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // child1 and child3 don't shrink (50px each)
  // child2 shrinks from 50px to 0px (75 - 50 - 50 = -25, but min is 0)
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[1].width, content="0")
  inspect(layout.children[2].width, content="50")
}

///|
/// From taffy: justify_content_row_space_around
test "flex_justify_space_around" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    justify_content: @style.SpaceAround,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Free space = 100 - 30 = 70
  // gap = 70 / 3 ≈ 23.33
  // Positions: gap/2, gap/2 + 10 + gap, gap/2 + 20 + 2*gap
  // = 11.67, 45, 78.33
  inspect(
    layout.children[0].x > 10.0 && layout.children[0].x < 13.0,
    content="true",
  )
  inspect(
    layout.children[1].x > 43.0 && layout.children[1].x < 47.0,
    content="true",
  )
  inspect(
    layout.children[2].x > 77.0 && layout.children[2].x < 80.0,
    content="true",
  )
}

///|
/// From taffy: justify_content_row_space_evenly
test "flex_justify_space_evenly" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    justify_content: @style.SpaceEvenly,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Free space = 100 - 30 = 70
  // gap = 70 / 4 = 17.5 (4 gaps for 3 items in space-evenly)
  // Positions: 17.5, 17.5 + 10 + 17.5 = 45, 45 + 10 + 17.5 = 72.5
  inspect(layout.children[0].x, content="17.5")
  inspect(layout.children[1].x, content="45")
  inspect(layout.children[2].x, content="72.5")
}

///|
/// From taffy: align_items_center
test "flex_align_items_center" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    align_items: @style.Center,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child should be vertically centered: (100 - 10) / 2 = 45
  inspect(layout.children[0].y, content="45")
  inspect(layout.children[0].height, content="10")
}

///|
test "flex_align_items_end" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    align_items: @style.End,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child should be at bottom: 100 - 10 = 90
  inspect(layout.children[0].y, content="90")
}

///|
test "flex_justify_end" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    justify_content: @style.End,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Children should be at end: free space = 60
  inspect(layout.children[0].x, content="60")
  inspect(layout.children[1].x, content="80")
}

///|
test "flex_column_reverse" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.ColumnReverse,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // In column-reverse, layout starts from the bottom (main-end)
  // DOM order is preserved: children[0] = child1, children[1] = child2
  // child1 is at y=80 (bottommost), child2 at y=50
  inspect(layout.children[0].id, content="child1")
  inspect(layout.children[0].y, content="80") // 100 - 20 = 80
  inspect(layout.children[1].id, content="child2")
  inspect(layout.children[1].y, content="50") // 80 - 30 = 50
}

///|
test "flex_nested" {
  let default_style = @style.Style::default()

  // Inner row with two children
  let inner_child1 = @node.Node::leaf("inner1", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(20.0),
  })
  let inner_child2 = @node.Node::leaf("inner2", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(20.0),
  })
  let inner_flex = @node.Node::new(
    "inner_flex",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Row,
      width: @types.Length(80.0),
      height: @types.Length(40.0),
    },
    [inner_child1, inner_child2],
  )
  let leaf = @node.Node::leaf("leaf", {
    ..default_style,
    width: @types.Length(80.0),
    height: @types.Length(30.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Column,
    width: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [inner_flex, leaf])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Root should be column layout
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].height, content="40")
  inspect(layout.children[1].y, content="40")
  inspect(layout.children[1].height, content="30")

  // Inner flex children should be in row
  inspect(layout.children[0].children[0].x, content="0")
  inspect(layout.children[0].children[1].x, content="30")
}

///|
test "flex_with_margin" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
    margin: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(5.0),
      bottom: @types.Length(5.0),
    },
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child should be positioned after its left margin
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].y, content="5")
}

///|
/// Test that explicit height prevents stretch
test "flex_stretch_respects_explicit_height" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(40.0), // Explicit height
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    align_items: @style.Stretch,
    width: @types.Length( // Default stretch
      200.0,
    ),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child should NOT stretch because it has explicit height
  inspect(layout.children[0].height, content="40")
}

///|
test "flex_min_width_constraint" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    flex_grow: 1.0,
    min_width: @types.Length(100.0),
    height: @types.Length(30.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(50.0), // Smaller than min_width
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child should be at least min_width
  inspect(layout.children[0].width, content="100")
}

///|
test "flex_max_width_constraint" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    flex_grow: 1.0,
    max_width: @types.Length(50.0),
    height: @types.Length(30.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child should be capped at max_width
  inspect(layout.children[0].width, content="50")
}

///|
/// From taffy: display_none - display:none child should be skipped in flex layout
test "flex_display_none" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", { ..default_style, flex_grow: 1.0 })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    display: @style.None,
    flex_grow: 1.0,
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child1 should expand to fill all space since child2 is display:none
  inspect(layout.children.length(), content="1")
  inspect(layout.children[0].width, content="100")
  inspect(layout.children[0].height, content="100")
}

///|
/// From taffy: flex_grow_within_constrained_min_column
/// Column flex with min-height and flex-grow child
test "flex_grow_within_constrained_min_column" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", { ..default_style, flex_grow: 1.0 })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    height: @types.Length(50.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Column,
    min_height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Container should be at least 100px (min-height)
  inspect(layout.height, content="100")
  // child1 should grow to fill remaining space (100 - 50 = 50)
  inspect(layout.children[0].height, content="50")
  inspect(layout.children[0].y, content="0")
  // child2 is fixed at 50px
  inspect(layout.children[1].height, content="50")
  inspect(layout.children[1].y, content="50")
}

///|
/// From taffy: percentage_flex_basis_main_max_width
/// Test percentage max-width with flex-grow
/// taffy redistributes excess space from capped items to uncapped items.
test "flex_percentage_max_width_with_grow" {
  let default_style = @style.Style::default()

  // Child with flex-grow: 1, max-width: 60%
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_grow: 1.0,
    max_width: @types.Percent(0.6),
  })
  // Child with flex-grow: 4, max-width: 20%
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    flex_grow: 4.0,
    max_width: @types.Percent(0.2),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(200.0),
    height: @types.Length(400.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(500.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // taffy expected: child1 gets 120 (max), child2 gets 40 (max)
  // Excess from child2 (160-40=120) redistributed to child1
  inspect(layout.children[0].width, content="120")
  inspect(layout.children[1].width, content="40")
  inspect(layout.children[1].x, content="120")
}

///|
/// From taffy: flex_grow_child
/// Basic flex-grow distribution test
test "flex_grow_child_distribution" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_grow: 0.0,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    flex_grow: 1.0,
    height: @types.Length(50.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // child1 has fixed width 50, child2 should grow to fill remaining 50
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[1].width, content="50")
  inspect(layout.children[1].x, content="50")
}

///|
/// From taffy: flex_shrink_child
/// Basic flex-shrink distribution test
test "flex_shrink_child_distribution" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_shrink: 0.0,
    width: @types.Length(80.0),
    height: @types.Length(50.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    flex_shrink: 1.0,
    width: @types.Length(80.0),
    height: @types.Length(50.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Total base = 160, available = 100, overflow = 60
  // child1 doesn't shrink (flex-shrink: 0), child2 shrinks by 60
  inspect(layout.children[0].width, content="80")
  inspect(layout.children[1].width, content="20")
}

///|
/// From taffy: align_items_flex_start
test "flex_align_items_start" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    align_items: @style.Start,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child should be at top (y = 0)
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].height, content="10")
}

///|
/// From taffy: padding_and_border_inside_flex_container
test "flex_container_with_border_and_padding" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    flex_grow: 1.0,
    height: @types.Length(20.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    padding: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(15.0),
      bottom: @types.Length(15.0),
    },
    border: {
      left: @types.Length(5.0),
      right: @types.Length(5.0),
      top: @types.Length(5.0),
      bottom: @types.Length(5.0),
    },
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Content width = 100 - 10 - 10 - 5 - 5 = 70
  inspect(layout.children[0].width, content="70")
  // Child x = border.left + padding.left = 5 + 10 = 15
  inspect(layout.children[0].x, content="15")
  // Child y = border.top + padding.top = 5 + 15 = 20
  inspect(layout.children[0].y, content="20")
}

///|
/// From taffy: flex_grow_within_constrained_max_width
/// Flex with max-width constraint on container
test "flex_grow_within_max_width" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_grow: 1.0,
    height: @types.Length(20.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    flex_grow: 1.0,
    height: @types.Length(20.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    max_width: @types.Length(100.0),
    // width is auto, but max-width constrains it
  }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 200.0, // More than max-width
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Container should be capped at 100 (max-width)
  inspect(layout.width, content="100")
  // Each child should get 50
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[1].width, content="50")
}

///|
/// From taffy: flex_shrink_by_outer_margin_with_max_size
test "flex_shrink_with_margin" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    flex_shrink: 1.0,
    width: @types.Length(100.0),
    height: @types.Length(20.0),
    margin: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(80.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child base = 100 + 20 margin = 120, available = 80
  // Overflow = 40, shrink only the width (not margin)
  // Final width = 100 - 40 = 60
  inspect(layout.children[0].width, content="60")
  inspect(layout.children[0].x, content="10") // margin.left
}

///|
/// From taffy: flex_grow_less_than_factor_one
/// CSS Flexbox spec says if sum(flex-grow) < 1, distribute only that fraction.
test "flex_grow_less_than_factor_one" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_grow: 0.2,
    flex_shrink: 0.0,
    width: @types.Length(40.0),
    height: @types.Length(100.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    flex_grow: 0.2,
    flex_shrink: 0.0,
    height: @types.Length(100.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    flex_grow: 0.4,
    flex_shrink: 0.0,
    height: @types.Length(100.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(500.0),
    height: @types.Length(200.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 600.0,
    available_height: Some(400.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // taffy expected: distribute only 80% of remaining space (460 * 0.8 = 368)
  // child1: 40 + 460 * 0.2 = 40 + 92 = 132
  // child2: 0 + 460 * 0.2 = 92
  // child3: 0 + 460 * 0.4 = 184
  // Total: 132 + 92 + 184 = 408 (92 remaining space unused)
  inspect(layout.children[0].width, content="132")
  inspect(layout.children[1].width, content="92")
  inspect(layout.children[2].width, content="184")
}

///|
/// From taffy: flex_basis_smaller_than_content
/// flex-basis should be used as initial size before grow/shrink
test "flex_basis_behavior" {
  let default_style = @style.Style::default()

  // Child with width: 50 but flex-grow: 1 should grow to fill space
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_grow: 1.0,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  // Child with fixed width: 50
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
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
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // child1: 50 base + 100 grow (200 - 100 = 100 remaining, all goes to child1)
  inspect(layout.children[0].width, content="150")
  inspect(layout.children[1].width, content="50")
}

///|
/// From taffy: flex_column_align_stretch
test "flex_column_align_stretch" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    height: @types.Length(50.0),
    // width: auto (should stretch)
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Column,
    align_items: @style.Stretch,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child should stretch to full width in column layout
  inspect(layout.children[0].width, content="200")
  inspect(layout.children[0].height, content="50")
}

///|
/// From taffy: justify_content_row_single_item_center
test "flex_single_item_center" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    justify_content: @style.Center,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Single child centered: (200 - 50) / 2 = 75
  inspect(layout.children[0].x, content="75")
}

///|
/// From taffy: flex_shrink_all_equally
test "flex_shrink_all_equally" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_shrink: 1.0,
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    flex_shrink: 1.0,
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    flex_shrink: 1.0,
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(150.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Total base = 300, available = 150, shrink = 150
  // Each shrinks by 50 equally
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[1].width, content="50")
  inspect(layout.children[2].width, content="50")
}

///|
/// Test nested flex with different directions
test "flex_nested_mixed_directions" {
  let default_style = @style.Style::default()

  // Inner column flex
  let inner_child1 = @node.Node::leaf("inner1", {
    ..default_style,
    flex_grow: 1.0,
    width: @types.Length(50.0),
  })
  let inner_child2 = @node.Node::leaf("inner2", {
    ..default_style,
    flex_grow: 1.0,
    width: @types.Length(50.0),
  })
  let inner_flex = @node.Node::new(
    "inner",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      height: @types.Length(100.0),
    },
    [inner_child1, inner_child2],
  )

  // Another fixed child
  let sibling = @node.Node::leaf("sibling", {
    ..default_style,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  })

  // Outer row flex
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [inner_flex, sibling])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Inner flex children should each get 50px height
  inspect(layout.children[0].children[0].height, content="50")
  inspect(layout.children[0].children[1].height, content="50")
  inspect(layout.children[0].children[1].y, content="50")
}

///|
/// From taffy: align_items_center
/// Child should be vertically centered in row layout
test "align_items_center" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    align_items: @style.Center,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  inspect(layout.children[0].width, content="10")
  inspect(layout.children[0].height, content="10")
  inspect(layout.children[0].x, content="0")
  // Child should be centered: (100 - 10) / 2 = 45
  inspect(layout.children[0].y, content="45")
}

///|
/// From taffy: align_items_flex_end
/// Child should be at flex end (bottom in row layout)
test "align_items_flex_end" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    align_items: @style.End,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.children[0].width, content="10")
  inspect(layout.children[0].height, content="10")
  inspect(layout.children[0].x, content="0")
  // Child should be at bottom: 100 - 10 = 90
  inspect(layout.children[0].y, content="90")
}

///|
/// From taffy: justify_content_row_space_between
/// Three children spread with space between
test "justify_content_space_between" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(10.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(10.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(10.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    justify_content: @style.SpaceBetween,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // space-between: first at start, last at end, middle centered
  // Remaining: 100 - 30 = 70, 2 gaps = 35 each
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[1].x, content="45")
  inspect(layout.children[2].x, content="90")
}

///|
/// From taffy: justify_content_row_space_around
/// Three children with equal space around each
test "justify_content_space_around" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(10.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(10.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(10.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    justify_content: @style.SpaceAround,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // space-around: each item has equal margin on both sides
  // Total: 100, content: 30, remaining: 70
  // 6 half-gaps, each = 70/6 ≈ 11.67
  // child1: 11.67 (half gap before)
  // child2: 11.67 + 10 + 11.67 + 11.67 = 45
  // child3: 45 + 10 + 11.67 + 11.67 = 78.33
  inspect(layout.children[0].x, content="11.666666666666666")
  inspect(layout.children[1].x, content="45")
  inspect(layout.children[2].x, content="78.33333333333333")
}

///|
/// From taffy: justify_content_row_center
/// Three children centered together
test "justify_content_center" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(10.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(10.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(10.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    justify_content: @style.Center,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // center: children grouped in center
  // Total content: 30, start offset: (100-30)/2 = 35
  inspect(layout.children[0].x, content="35")
  inspect(layout.children[1].x, content="45")
  inspect(layout.children[2].x, content="55")
}

///|
/// From taffy: flex_shrink_to_zero
/// Middle child shrinks to zero when it's the only shrinkable one
test "flex_shrink_middle_to_zero" {
  let default_style = @style.Style::default()

  // child0: no shrink
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    flex_shrink: 0.0,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  // child1: can shrink
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_shrink: 1.0,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  // child2: no shrink
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    flex_shrink: 0.0,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(75.0),
  }
  let root = @node.Node::new("root", root_style, [child0, child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Total: 150, container: 75, overflow: 75
  // Only child1 shrinks, so it goes to 50 - 75 = max(0, -25) = 0
  // But taffy expects child1 width = 0
  inspect(layout.width, content="75")
  inspect(layout.height, content="50")
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[1].width, content="0")
  inspect(layout.children[1].x, content="50")
  inspect(layout.children[2].width, content="50")
  inspect(layout.children[2].x, content="50")
}

///|
/// From taffy: align_self_center
/// align-self overrides align-items for a single child
test "align_self_center" {
  let default_style = @style.Style::default()
  let child = @node.Node::leaf("child", {
    ..default_style,
    align_self: @style.Center,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.children[0].width, content="10")
  inspect(layout.children[0].height, content="10")
  inspect(layout.children[0].x, content="0")
  // Center: (100 - 10) / 2 = 45
  inspect(layout.children[0].y, content="45")
}

///|
/// From taffy: flex_basis_flex_grow_column
/// flex-basis with flex-grow in column layout
test "flex_basis_flex_grow_column" {
  let default_style = @style.Style::default()

  // Child with flex-basis: 50 and flex-grow: 1
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_grow: 1.0,
    flex_basis: @types.Length(50.0),
  })
  // Child with flex-grow: 1 (no basis)
  let child2 = @node.Node::leaf("child2", { ..default_style, flex_grow: 1.0 })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Column,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // child1 base: 50, child2 base: 0
  // Remaining: 100 - 50 = 50, split equally
  // child1: 50 + 25 = 75
  // child2: 0 + 25 = 25
  inspect(layout.children[0].width, content="100")
  inspect(layout.children[0].height, content="75")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[1].width, content="100")
  inspect(layout.children[1].height, content="25")
  inspect(layout.children[1].y, content="75")
}

///|
/// From taffy: flex_wrap_align_stretch_fits_one_row
/// Flex wrap with stretch when all items fit on one row
test "flex_wrap_fits_one_row" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(50.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(50.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    flex_wrap: @style.Wrap,
    width: @types.Length(150.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Both children fit on one row
  inspect(layout.width, content="150")
  inspect(layout.height, content="100")
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[0].height, content="100")
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[1].width, content="50")
  inspect(layout.children[1].height, content="100")
  inspect(layout.children[1].x, content="50")
  inspect(layout.children[1].y, content="0")
}

///|
/// From taffy: nested_overflowing_child_in_constraint_parent
/// Child larger than parent should be constrained
test "nested_overflowing_child" {
  let default_style = @style.Style::default()
  let grandchild = @node.Node::leaf("grandchild", {
    ..default_style,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  })
  let child = @node.Node::new(
    "child",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [grandchild],
  )
  let root_style = {
    ..default_style,
    display: @style.Flex,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Parent constrains width but not height
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  inspect(layout.children[0].width, content="100")
  inspect(layout.children[0].height, content="100")
  // Grandchild width should be constrained to parent width
  inspect(layout.children[0].children[0].width, content="100")
  // Height can overflow (taffy: 200)
  inspect(layout.children[0].children[0].height, content="200")
}

///|
/// From taffy: gap_column_gap_flexible
/// Column gap with flex-grow children
test "gap_column_gap_flexible" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_grow: 1.0,
    flex_shrink: 1.0,
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    flex_grow: 1.0,
    flex_shrink: 1.0,
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    flex_grow: 1.0,
    flex_shrink: 1.0,
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    column_gap: @types.Length(10.0),
    width: @types.Length(80.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // 80px total, 2 gaps of 10px = 20px, remaining 60px / 3 = 20px each
  inspect(layout.width, content="80")
  inspect(layout.height, content="100")
  inspect(layout.children[0].width, content="20")
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[1].width, content="20")
  inspect(layout.children[1].x, content="30")
  inspect(layout.children[2].width, content="20")
  inspect(layout.children[2].x, content="60")
}

///|
/// From taffy: gap_column_gap_inflexible
/// Column gap with fixed width children
test "gap_column_gap_inflexible" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(20.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(20.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(20.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    column_gap: @types.Length(10.0),
    width: @types.Length(80.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // 3 children of 20px each + 2 gaps of 10px = 80px total
  inspect(layout.children[0].width, content="20")
  inspect(layout.children[0].height, content="100")
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[1].width, content="20")
  inspect(layout.children[1].x, content="30")
  inspect(layout.children[2].width, content="20")
  inspect(layout.children[2].x, content="60")
}

///|
/// From taffy: gap_row_gap_determines_parent_height
/// Row gap in column layout determines parent height
test "gap_row_gap_column" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    height: @types.Length(10.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    height: @types.Length(20.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    height: @types.Length(30.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Column,
    row_gap: @types.Length(10.0),
    width: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // 10 + 20 + 30 = 60px content + 2 gaps of 10px = 80px total height
  inspect(layout.width, content="100")
  inspect(layout.height, content="80")
  inspect(layout.children[0].height, content="10")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[1].height, content="20")
  inspect(layout.children[1].y, content="20")
  inspect(layout.children[2].height, content="30")
  inspect(layout.children[2].y, content="50")
}

///|
/// From taffy: wrap_row
/// Flex wrap in row direction
test "wrap_row" {
  let default_style = @style.Style::default()

  // 4 children: 31+32+33+34 = 130px total, but container is 100px
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(31.0),
    height: @types.Length(30.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(32.0),
    height: @types.Length(30.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(33.0),
    height: @types.Length(30.0),
  })
  let child4 = @node.Node::leaf("child4", {
    ..default_style,
    width: @types.Length(34.0),
    height: @types.Length(30.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    flex_wrap: @style.Wrap,
    width: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [
    child1, child2, child3, child4,
  ])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Row 1: child1 (31) + child2 (32) + child3 (33) = 96px (fits in 100px)
  // Row 2: child4 (34) wraps to second line
  // Total height: 30 + 30 = 60px
  inspect(layout.width, content="100")
  inspect(layout.height, content="60")
  // Row 1
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[1].x, content="31")
  inspect(layout.children[1].y, content="0")
  inspect(layout.children[2].x, content="63")
  inspect(layout.children[2].y, content="0")
  // Row 2
  inspect(layout.children[3].x, content="0")
  inspect(layout.children[3].y, content="30")
}

///|
/// From taffy: wrap_column
/// Flex wrap in column direction
test "wrap_column" {
  let default_style = @style.Style::default()

  // 4 children: 31+32+33+34 = 130px total height, container is 100px
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(31.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(32.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(33.0),
  })
  let child4 = @node.Node::leaf("child4", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(34.0),
  })
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Column,
    flex_wrap: @style.Wrap,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [
    child1, child2, child3, child4,
  ])
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Column 1: child1 (31) + child2 (32) + child3 (33) = 96px (fits in 100px)
  // Column 2: child4 (34) wraps to second column
  // taffy positions: child4 at x=50 (half of 100)
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  // Column 1
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[1].x, content="0")
  inspect(layout.children[1].y, content="31")
  inspect(layout.children[2].x, content="0")
  inspect(layout.children[2].y, content="63")
  // Column 2 (wrapped)
  inspect(layout.children[3].x, content="50")
  inspect(layout.children[3].y, content="0")
}

// =============================================================================
// Margin Auto Tests (ported from taffy)
// =============================================================================

///|
test "margin_auto_left_and_right" {
  // Container: 200x200, row
  // Child 0: 50x50 with margin-left: auto, margin-right: auto
  // Child 1: 50x50
  // Free space = 200 - 50 - 50 = 100, split between 2 auto margins = 50 each
  let default_style = @style.Style::default()
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  })
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(200.0),
      height: @types.Length(200.0),
    },
    [child0, child1],
  )
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="200")
  inspect(layout.height, content="200")
  // Child 0: x = 50 (auto left margin absorbs half of free space)
  inspect(layout.children[0].x, content="50")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[0].height, content="50")
  // Child 1: x = 50 (auto left) + 50 (child 0) + 50 (auto right) = 150
  inspect(layout.children[1].x, content="150")
  inspect(layout.children[1].y, content="0")
}

///|
test "margin_auto_left" {
  // Container: 200x200, align-items: center
  // Child 0: 50x50 with margin-left: auto
  // Child 1: 50x50
  // Free space = 200 - 50 - 50 = 100, goes entirely to the one auto margin
  let default_style = @style.Style::default()
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Auto,
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  })
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(200.0),
      height: @types.Length(200.0),
      align_items: @style.Center,
    },
    [child0, child1],
  )
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="200")
  inspect(layout.height, content="200")
  // Child 0: x = 100 (auto left margin absorbs all free space)
  inspect(layout.children[0].x, content="100")
  inspect(layout.children[0].y, content="75") // centered
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[0].height, content="50")
  // Child 1: x = 100 + 50 = 150
  inspect(layout.children[1].x, content="150")
  inspect(layout.children[1].y, content="75") // centered
}

///|
test "margin_auto_top" {
  // Container: 200x200, align-items: center
  // Child 0: 50x50 with margin-top: auto (cross axis)
  // Child 1: 50x50
  // Cross axis auto margin pushes child 0 to the bottom
  let default_style = @style.Style::default()
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Auto,
      bottom: @types.Length(0.0),
    },
  })
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(200.0),
      height: @types.Length(200.0),
      align_items: @style.Center,
    },
    [child0, child1],
  )
  let ctx : @node.LayoutContext = {
    available_width: 200.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="200")
  inspect(layout.height, content="200")
  // Child 0: pushed to bottom by auto margin-top
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="150") // 200 - 50 = 150
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[0].height, content="50")
  // Child 1: centered (align-items: center)
  inspect(layout.children[1].x, content="50")
  inspect(layout.children[1].y, content="75") // (200 - 50) / 2 = 75
}

// =============================================================================
// Aspect Ratio Tests (ported from taffy)
// =============================================================================

///|
test "aspect_ratio_flex_row_fill_width" {
  // Child has height=40, width=auto, aspect_ratio=2.0
  // Result: width = 40 * 2 = 80, height = 40
  let default_style = @style.Style::default()
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    height: @types.Length(40.0),
    aspect_ratio: Some(2.0),
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      align_items: @style.Start,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [child0],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  inspect(layout.children[0].width, content="80")
  inspect(layout.children[0].height, content="40")
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
}

///|
test "aspect_ratio_flex_row_fill_height" {
  // Child has width=40, height=auto, aspect_ratio=2.0
  // Result: width = 40, height = 40 / 2 = 20
  let default_style = @style.Style::default()
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    width: @types.Length(40.0),
    aspect_ratio: Some(2.0),
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      align_items: @style.Start,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [child0],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  inspect(layout.children[0].width, content="40")
  inspect(layout.children[0].height, content="20")
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
}

///|
test "aspect_ratio_flex_row_stretch_fill_height" {
  // Child has width=40, height=auto, aspect_ratio=2.0
  // With default align-items (stretch), stretch takes precedence over aspect_ratio
  // Result: width = 40, height = 100 (stretched to container)
  let default_style = @style.Style::default()
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    width: @types.Length(40.0),
    aspect_ratio: Some(2.0),
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(
        // default align_items is Stretch
        100.0,
      ),
      height: @types.Length(100.0),
    },
    [child0],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  inspect(layout.children[0].width, content="40")
  inspect(layout.children[0].height, content="100") // Stretched, not aspect_ratio
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
}

// =============================================================================
// Wrap Reverse Tests (ported from taffy)
// =============================================================================

///|
test "wrap_reverse_row" {
  // Container: 100px wide, flex-wrap: wrap-reverse
  // 4 children that wrap into 2 lines
  // With wrap-reverse, later lines go first (at y=0)
  let default_style = @style.Style::default()
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    width: @types.Length(31.0),
    height: @types.Length(30.0),
  })
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(32.0),
    height: @types.Length(30.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(33.0),
    height: @types.Length(30.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(34.0),
    height: @types.Length(30.0),
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      flex_wrap: @style.WrapReverse,
      width: @types.Length(100.0),
    },
    [child0, child1, child2, child3],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(200.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="100")
  inspect(layout.height, content="60") // 2 lines of 30px each
  // Line 1 (items 0,1,2): 31+32+33=96 fits in 100, at y=30 (wrap-reverse puts first line at end)
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="30")
  inspect(layout.children[1].x, content="31")
  inspect(layout.children[1].y, content="30")
  inspect(layout.children[2].x, content="63")
  inspect(layout.children[2].y, content="30")
  // Line 2 (item 3): wraps, at y=0 (wrap-reverse puts last line first)
  inspect(layout.children[3].x, content="0")
  inspect(layout.children[3].y, content="0")
}

///|
test "wrap_reverse_column" {
  // Container: 100x100, flex-direction: column, flex-wrap: wrap-reverse
  // 4 children that wrap into 2 columns
  let default_style = @style.Style::default()
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(31.0),
  })
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(32.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(33.0),
  })
  let child3 = @node.Node::leaf("child3", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(34.0),
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      flex_wrap: @style.WrapReverse,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [child0, child1, child2, child3],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  // Column 1 (items 0,1,2): 31+32+33=96 fits in 100, at x=70 (stretch gives 50px per column, item at end: 100-30=70)
  inspect(layout.children[0].x, content="70")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[1].x, content="70")
  inspect(layout.children[1].y, content="31")
  inspect(layout.children[2].x, content="70")
  inspect(layout.children[2].y, content="63")
  // Column 2 (item 3): wraps, at x=20 (second column 0-50, item at end: 50-30=20)
  inspect(layout.children[3].x, content="20")
  inspect(layout.children[3].y, content="0")
}

// =============================================================================
// Position Absolute Tests (ported from taffy)
// =============================================================================

///|
test "absolute_layout_width_height_start_top" {
  // Absolute positioned child with size 10x10, inset left=10, top=10
  // Parent is 100x100
  // Child should be at (10, 10) with size (10, 10)
  let default_style = @style.Style::default()
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    position: @style.Absolute,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
    inset: {
      left: @types.Length(10.0),
      right: @types.Auto,
      top: @types.Length(10.0),
      bottom: @types.Auto,
    },
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [child0],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  inspect(layout.children[0].width, content="10")
  inspect(layout.children[0].height, content="10")
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].y, content="10")
}

///|
test "absolute_layout_start_top_end_bottom" {
  // Absolute positioned child with inset left=10, right=10, top=10, bottom=10
  // Parent is 100x100
  // Child size is calculated from insets: 100 - 10 - 10 = 80
  let default_style = @style.Style::default()
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    position: @style.Absolute,
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [child0],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  inspect(layout.children[0].width, content="80")
  inspect(layout.children[0].height, content="80")
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].y, content="10")
}

///|
test "absolute_does_not_affect_flex_layout" {
  // Absolute positioned child should not affect siblings' layout
  let default_style = @style.Style::default()
  let abs_child = @node.Node::leaf("abs", {
    ..default_style,
    position: @style.Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    inset: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Auto,
    },
  })
  let flex_child = @node.Node::leaf("flex", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(30.0),
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [abs_child, flex_child],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Flex child should be at (0, 0) as if abs child doesn't exist
  // Note: children array order may vary - abs children are added after flex children
  // Check by id or by checking the sizes
  let mut flex_x = 0.0
  let mut abs_x = 0.0
  for child in layout.children {
    if child.width == 30.0 {
      flex_x = child.x
    }
    if child.width == 50.0 {
      abs_x = child.x
    }
  }
  // Flex child should start at x=0 (abs child doesn't push it)
  inspect(flex_x, content="0")
  // Abs child at x=0 (inset left=0)
  inspect(abs_x, content="0")
}

///|
/// Test nested flex containers with explicit sizes
/// Multiple levels of nesting with explicit dimensions
test "nested_flex_explicit_sizes" {
  let default_style = @style.Style::default()

  // Innermost child: 30x30
  let inner = @node.Node::leaf("inner", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(30.0),
  })

  // Middle container: column flex, 60x60
  let middle = @node.Node::new(
    "middle",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      width: @types.Length(60.0),
      height: @types.Length(60.0),
    },
    [inner],
  )

  // Outer container: row flex, 100x100
  let outer = @node.Node::new(
    "outer",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [middle],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(outer, ctx)

  // Outer: 100x100
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  // Middle: 60x60 (explicit sizes, not stretched)
  inspect(layout.children[0].width, content="60")
  inspect(layout.children[0].height, content="60")
  // Inner: 30x30 (explicit sizes, not stretched)
  inspect(layout.children[0].children[0].width, content="30")
  inspect(layout.children[0].children[0].height, content="30")
}

///|
/// Test deeply nested flex with padding and margins
test "nested_flex_with_padding_margin" {
  let default_style = @style.Style::default()

  // Leaf node: 40x40
  let leaf = @node.Node::leaf("leaf", {
    ..default_style,
    width: @types.Length(40.0),
    height: @types.Length(40.0),
  })

  // Parent with padding: 80x80
  let parent = @node.Node::new(
    "parent",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(80.0),
      height: @types.Length(80.0),
      padding: {
        left: @types.Length(10.0),
        right: @types.Length(10.0),
        top: @types.Length(5.0),
        bottom: @types.Length(5.0),
      },
    },
    [leaf],
  )

  // Root: 100x100
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
      padding: {
        left: @types.Length(5.0),
        right: @types.Length(5.0),
        top: @types.Length(5.0),
        bottom: @types.Length(5.0),
      },
    },
    [parent],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Root: 100x100
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  // Parent: 80x80 (explicit sizes, not stretched)
  inspect(layout.children[0].width, content="80")
  inspect(layout.children[0].height, content="80")
  inspect(layout.children[0].x, content="5")
  inspect(layout.children[0].y, content="5")
  // Leaf: positioned with parent's padding, explicit height preserved
  inspect(layout.children[0].children[0].width, content="40")
  inspect(layout.children[0].children[0].height, content="40") // explicit, not stretched
  inspect(layout.children[0].children[0].x, content="10") // parent padding left
  inspect(layout.children[0].children[0].y, content="5") // parent padding top
}

///|
/// Test nested row in column
test "nested_row_in_column" {
  let default_style = @style.Style::default()
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(30.0),
  })
  let child2 = @node.Node::leaf("child2", {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(30.0),
  })

  // Row container
  let row = @node.Node::new(
    "row",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Row,
      width: @types.Length(80.0),
      height: @types.Length(40.0),
    },
    [child1, child2],
  )

  // Column root
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [row],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Root: 100x100
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  // Row: 80x40 (explicit sizes, not stretched)
  inspect(layout.children[0].width, content="80")
  inspect(layout.children[0].height, content="40")
  // Children in row: side by side, explicit height preserved
  inspect(layout.children[0].children[0].x, content="0")
  inspect(layout.children[0].children[0].y, content="0")
  inspect(layout.children[0].children[0].width, content="30")
  inspect(layout.children[0].children[0].height, content="30") // explicit, not stretched
  inspect(layout.children[0].children[1].x, content="30")
  inspect(layout.children[0].children[1].y, content="0")
}

///|
/// Test nested overflowing child with unconstrained parent (ported from taffy)
/// Child is larger than grandparent, middle node has no explicit size
test "nested_overflowing_child_unconstrained" {
  let default_style = @style.Style::default()

  // node00: 200x200 (larger than containers)
  let node00 = @node.Node::leaf("node00", {
    ..default_style,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  })

  // node0: no explicit size, wraps node00
  let node0 = @node.Node::new(
    "node0",
    { ..default_style, display: @style.Flex },
    [node00],
  )

  // root: 100x100
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [node0],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Root stays 100x100
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  // node0 expands to fit child width (200), but height is constrained to 100
  // Note: This requires intrinsic sizing which is not fully implemented
  inspect(layout.children[0].width, content="200")
  inspect(layout.children[0].height, content="100")
  // node00 keeps its 200x200 size
  inspect(layout.children[0].children[0].width, content="200")
  inspect(layout.children[0].children[0].height, content="200")
}

///|
/// Test min-height with nested fixed height (ported from taffy)
/// Min-height and margin interactions with nested children
test "min_height_with_nested_fixed_height" {
  let default_style = @style.Style::default()

  // node00: 40x40
  let node00 = @node.Node::leaf("node00", {
    ..default_style,
    width: @types.Length(40.0),
    height: @types.Length(40.0),
  })

  // node0: column, align-self:start, flex-shrink:0, min-height:28, margin:top=8,bottom=9
  let node0 = @node.Node::new(
    "node0",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      align_self: @style.AlignSelf::Start,
      flex_shrink: 0.0,
      min_height: @types.Length(28.0),
      margin: {
        left: @types.Length(0.0),
        right: @types.Length(0.0),
        top: @types.Length(8.0),
        bottom: @types.Length(9.0),
      },
    },
    [node00],
  )

  // root: width=320, height=auto, min-height=44, padding left/right=16
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(320.0),
      min_height: @types.Length(44.0),
      padding: {
        left: @types.Length(16.0),
        right: @types.Length(16.0),
        top: @types.Length(0.0),
        bottom: @types.Length(0.0),
      },
    },
    [node0],
  )
  let ctx : @node.LayoutContext = {
    available_width: 320.0,
    available_height: None,
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Root: 320 wide, height = 8 + 40 + 9 = 57 (margin + child height)
  inspect(layout.width, content="320")
  inspect(layout.height, content="57")
  // node0: 40x40 at (16, 8)
  inspect(layout.children[0].width, content="40")
  inspect(layout.children[0].height, content="40")
  inspect(layout.children[0].x, content="16")
  inspect(layout.children[0].y, content="8")
  // node00: 40x40 at (0, 0) relative to node0
  inspect(layout.children[0].children[0].width, content="40")
  inspect(layout.children[0].children[0].height, content="40")
  inspect(layout.children[0].children[0].x, content="0")
  inspect(layout.children[0].children[0].y, content="0")
}

///|
/// Test baseline alignment with nested child (ported from taffy)
/// For flex column container, baseline is the baseline of its first child
test "align_baseline_nested_child" {
  let default_style = @style.Style::default()

  // node0: 50x50 leaf
  let node0 = @node.Node::leaf("node0", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })

  // node10: 50x10 leaf (first child of node1)
  let node10 = @node.Node::leaf("node10", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  })

  // node1: 50x20 column flex (baseline = first child's baseline = 10)
  let node1 = @node.Node::new(
    "node1",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      width: @types.Length(50.0),
      height: @types.Length(20.0),
    },
    [node10],
  )

  // root: 100x100, align_items: baseline
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      align_items: @style.Baseline,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [node0, node1],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Root: 100x100
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  // node0: 50x50 at (0, 0)
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[0].height, content="50")
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
  // node1: 50x20 at (50, 40) - baseline (first child bottom at y+10) aligns with node0's baseline (50)
  // node1.y + 10 = 50, so node1.y = 40
  inspect(layout.children[1].width, content="50")
  inspect(layout.children[1].height, content="20")
  inspect(layout.children[1].x, content="50")
  inspect(layout.children[1].y, content="40")
}

///|
/// Test baseline alignment (ported from taffy align_baseline test)
/// Container: 100x100
/// Child 0: 50x50 at (0, 0)
/// Child 1: 50x20 at (50, 30) - baseline (bottom) aligns with child 0's baseline
test "align_baseline" {
  let default_style = @style.Style::default()
  let child0 = @node.Node::leaf("child0", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  })
  let root = @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      align_items: @style.Baseline,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [child0, child1],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  // Child 0: 50x50 at (0, 0)
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[0].height, content="50")
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
  // Child 1: 50x20 at (50, 30) - baseline aligns with child 0
  inspect(layout.children[1].width, content="50")
  inspect(layout.children[1].height, content="20")
  inspect(layout.children[1].x, content="50")
  inspect(layout.children[1].y, content="30")
}

///|
/// Debug test for intrinsic sizing
test "debug_intrinsic_cross_sizing" {
  let default_style = @style.Style::default()

  // Simple Column flex with explicit height child
  let child = @node.Node::leaf("child", {
    ..default_style,
    width: @types.Length(40.0),
    height: @types.Length(40.0),
  })

  // parent has align_self: Start, min_height: 28 (testing if min_height causes the issue)
  let parent = @node.Node::new(
    "parent",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      align_self: @style.AlignSelf::Start,
      min_height: @types.Length(28.0),
      // no margin
    },
    [child],
  )

  // Root is Row with height: Auto - should grow to fit children
  let root = @node.Node::new(
    "root",
    { ..default_style, display: @style.Flex, width: @types.Length(100.0) },
    // height: Auto (default)
    [parent],
  )
  let ctx : @node.LayoutContext = {
    available_width: 100.0,
    available_height: None,
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Root should have height 40 (from parent's intrinsic height, no margin)
  inspect(layout.height, content="40")
  // parent should have intrinsic height of 40 from child (not stretched)
  inspect(layout.children[0].height, content="40")
  // child should be 40x40
  inspect(layout.children[0].children[0].height, content="40")
}
