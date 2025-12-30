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
  }
  let layout = compute(root, ctx)

  // Free space = 100 - 30 = 70
  // gap = 70 / 3 ≈ 23.33
  // Positions: gap/2, gap/2 + 10 + gap, gap/2 + 20 + 2*gap
  // = 11.67, 45, 78.33
  inspect(layout.children[0].x > 10.0 && layout.children[0].x < 13.0, content="true")
  inspect(layout.children[1].x > 43.0 && layout.children[1].x < 47.0, content="true")
  inspect(layout.children[2].x > 77.0 && layout.children[2].x < 80.0, content="true")
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
  }
  let layout = compute(root, ctx)

  // In column-reverse, child2 comes first (at y=0), child1 comes second
  inspect(layout.children[0].id, content="child2")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[1].id, content="child1")
  inspect(layout.children[1].y, content="30")
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

  let inner_flex = @node.Node::new("inner_flex", {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(80.0),
    height: @types.Length(40.0),
  }, [inner_child1, inner_child2])

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
    align_items: @style.Stretch, // Default stretch
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])

  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
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
  }
  let layout = compute(root, ctx)

  // Child should be capped at max_width
  inspect(layout.children[0].width, content="50")
}

///|
/// From taffy: display_none - display:none child should be skipped in flex layout
test "flex_display_none" {
  let default_style = @style.Style::default()

  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_grow: 1.0,
  })
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

  let child1 = @node.Node::leaf("child1", {
    ..default_style,
    flex_grow: 1.0,
  })
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
/// Note: Full CSS Flexbox redistribution after max constraint is not yet implemented.
/// taffy redistributes excess space from capped items to uncapped items.
/// Current behavior: grow once, then apply max constraints without redistribution.
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
  }
  let layout = compute(root, ctx)

  // Current behavior (no redistribution):
  // child1 grows to 40 (200 * 1/5), then max=120 not reached -> 40
  // child2 grows to 160 (200 * 4/5), then max=40 caps it -> 40
  inspect(layout.children[0].width, content="40")
  inspect(layout.children[1].width, content="40")
  inspect(layout.children[1].x, content="40")
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
    available_width: 200.0,  // More than max-width
    available_height: Some(300.0),
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
  }
  let layout = compute(root, ctx)

  // Child base = 100 + 20 margin = 120, available = 80
  // Overflow = 40, shrink only the width (not margin)
  // Final width = 100 - 40 = 60
  inspect(layout.children[0].width, content="60")
  inspect(layout.children[0].x, content="10")  // margin.left
}

///|
/// From taffy: flex_grow_less_than_factor_one
/// Note: CSS Flexbox spec says if sum(flex-grow) < 1, distribute only that fraction.
/// Current implementation distributes all remaining space proportionally.
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
  }
  let layout = compute(root, ctx)

  // Current behavior: distributes all remaining space (460) proportionally
  // total_flex_grow = 0.8
  // child1: 40 + 460 * (0.2/0.8) = 40 + 115 = 155
  // child2: 0 + 460 * (0.2/0.8) = 115
  // child3: 0 + 460 * (0.4/0.8) = 230
  inspect(layout.children[0].width, content="155")
  inspect(layout.children[1].width, content="115")
  inspect(layout.children[2].width, content="230")
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

  let inner_flex = @node.Node::new("inner", {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Column,
    height: @types.Length(100.0),
  }, [inner_child1, inner_child2])

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
  }
  let layout = compute(root, ctx)

  // Inner flex children should each get 50px height
  inspect(layout.children[0].children[0].height, content="50")
  inspect(layout.children[0].children[1].height, content="50")
  inspect(layout.children[0].children[1].y, content="50")
}
