///|
test "block_basic" {
  let default_style = @style.Style::default()
  let child1_style = { ..default_style, height: @types.Length(10.0) }
  let child1 = @node.Node::leaf("child1", child1_style)
  let child2_style = { ..default_style, height: @types.Length(10.0) }
  let child2 = @node.Node::leaf("child2", child2_style)
  let root_style = { ..default_style, width: @types.Length(50.0) }
  let root = @node.Node::new("test-root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="50")
  inspect(layout.height, content="20")
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[0].height, content="10")
  inspect(layout.children[1].x, content="0")
  inspect(layout.children[1].y, content="10")
  inspect(layout.children[1].width, content="50")
  inspect(layout.children[1].height, content="10")
}

///|
test "block_border_fixed_size" {
  let default_style = @style.Style::default()
  let child1_style = { ..default_style, height: @types.Length(10.0) }
  let child1 = @node.Node::leaf("child1", child1_style)
  let child2_style = { ..default_style, height: @types.Length(10.0) }
  let child2 = @node.Node::leaf("child2", child2_style)
  let root_style = {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    border: {
      top: @types.Length(2.0),
      right: @types.Length(4.0),
      bottom: @types.Length(6.0),
      left: @types.Length(8.0),
    },
  }
  let root = @node.Node::new("test-root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="50")
  inspect(layout.height, content="50")
  inspect(layout.children[0].x, content="8")
  inspect(layout.children[0].y, content="2")
  inspect(layout.children[0].width, content="38")
  inspect(layout.children[0].height, content="10")
  inspect(layout.children[1].x, content="8")
  inspect(layout.children[1].y, content="12")
  inspect(layout.children[1].width, content="38")
  inspect(layout.children[1].height, content="10")
}

///|
test "block_margin_x_fixed_size_positive" {
  let default_style = @style.Style::default()
  let child1_style = {
    ..default_style,
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(10.0),
      right: @types.Length(5.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let child1 = @node.Node::leaf("child1", child1_style)
  let child2_style = { ..default_style, height: @types.Length(10.0) }
  let child2 = @node.Node::leaf("child2", child2_style)
  let root_style = { ..default_style, width: @types.Length(50.0) }
  let root = @node.Node::new("test-root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="50")
  inspect(layout.height, content="20")
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].width, content="35")
  inspect(layout.children[0].height, content="10")
  inspect(layout.children[1].x, content="0")
  inspect(layout.children[1].y, content="10")
  inspect(layout.children[1].width, content="50")
  inspect(layout.children[1].height, content="10")
}

///|
test "block_padding_fixed_size" {
  let default_style = @style.Style::default()
  let child1_style = { ..default_style, height: @types.Length(10.0) }
  let child1 = @node.Node::leaf("child1", child1_style)
  let child2_style = { ..default_style, height: @types.Length(10.0) }
  let child2 = @node.Node::leaf("child2", child2_style)
  let root_style = {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    padding: {
      top: @types.Length(2.0),
      right: @types.Length(4.0),
      bottom: @types.Length(6.0),
      left: @types.Length(8.0),
    },
  }
  let root = @node.Node::new("test-root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="50")
  inspect(layout.height, content="50")
  inspect(layout.children[0].x, content="8")
  inspect(layout.children[0].y, content="2")
  inspect(layout.children[0].width, content="38")
  inspect(layout.children[0].height, content="10")
  inspect(layout.children[1].x, content="8")
  inspect(layout.children[1].y, content="12")
  inspect(layout.children[1].width, content="38")
  inspect(layout.children[1].height, content="10")
}

///|
test "block_nested" {
  let default_style = @style.Style::default()
  let inner_style = { ..default_style, height: @types.Length(20.0) }
  let inner = @node.Node::leaf("inner", inner_style)
  let middle_style = {
    ..default_style,
    padding: {
      top: @types.Length(5.0),
      right: @types.Length(5.0),
      bottom: @types.Length(5.0),
      left: @types.Length(5.0),
    },
  }
  let middle = @node.Node::new("middle", middle_style, [inner])
  let root_style = {
    ..default_style,
    width: @types.Length(100.0),
    padding: {
      top: @types.Length(10.0),
      right: @types.Length(10.0),
      bottom: @types.Length(10.0),
      left: @types.Length(10.0),
    },
  }
  let root = @node.Node::new("root", root_style, [middle])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.width, content="100")
  inspect(layout.height, content="50")
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].y, content="10")
  inspect(layout.children[0].width, content="80")
  inspect(layout.children[0].height, content="30")
  inspect(layout.children[0].children[0].x, content="5")
  inspect(layout.children[0].children[0].y, content="5")
  inspect(layout.children[0].children[0].width, content="70")
  inspect(layout.children[0].children[0].height, content="20")
}

///|
test "block_percentage_width" {
  let default_style = @style.Style::default()
  let child_style = {
    ..default_style,
    width: @types.Percent(0.5),
    height: @types.Length(20.0),
  }
  let child = @node.Node::leaf("child", child_style)
  let root_style = {
    ..default_style,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[0].height, content="20")
}

///|
test "block_percentage_height" {
  let default_style = @style.Style::default()
  let child_style = {
    ..default_style,
    width: @types.Length(20.0),
    height: @types.Percent(0.5),
  }
  let child = @node.Node::leaf("child", child_style)
  let root_style = {
    ..default_style,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.children[0].width, content="20")
  inspect(layout.children[0].height, content="50")
}

///|
test "block_max_width" {
  let default_style = @style.Style::default()
  let child1_style = {
    ..default_style,
    max_width: @types.Length(100.0),
    height: @types.Length(50.0),
  }
  let child1 = @node.Node::leaf("child1", child1_style)
  let child2_style = {
    ..default_style,
    max_width: @types.Length(300.0),
    height: @types.Length(50.0),
  }
  let child2 = @node.Node::leaf("child2", child2_style)
  let root_style = {
    ..default_style,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.children[0].width, content="100")
  inspect(layout.children[1].width, content="200")
}

///|
test "block_min_width" {
  let default_style = @style.Style::default()
  let child_style = {
    ..default_style,
    width: @types.Length(50.0),
    min_width: @types.Length(100.0),
    height: @types.Length(30.0),
  }
  let child = @node.Node::leaf("child", child_style)
  let root_style = {
    ..default_style,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.children[0].width, content="100")
}

///|
test "block_max_height" {
  let default_style = @style.Style::default()
  let child_style = {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(150.0),
    max_height: @types.Length(80.0),
  }
  let child = @node.Node::leaf("child", child_style)
  let root_style = {
    ..default_style,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.children[0].height, content="80")
}

///|
test "block_min_height" {
  let default_style = @style.Style::default()
  let child_style = {
    ..default_style,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
    min_height: @types.Length(60.0),
  }
  let child = @node.Node::leaf("child", child_style)
  let root_style = {
    ..default_style,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.children[0].height, content="60")
}

///|
test "block_margin_collapse_siblings" {
  let default_style = @style.Style::default()
  let child1_style = {
    ..default_style,
    height: @types.Length(20.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(30.0),
    },
  }
  let child1 = @node.Node::leaf("child1", child1_style)
  let child2_style = {
    ..default_style,
    height: @types.Length(20.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(20.0),
      bottom: @types.Length(0.0),
    },
  }
  let child2 = @node.Node::leaf("child2", child2_style)
  let root_style = { ..default_style, width: @types.Length(100.0) }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.height, content="70")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].height, content="20")
  inspect(layout.children[1].y, content="50")
  inspect(layout.children[1].height, content="20")
}

///|
test "block_percentage_padding" {
  let default_style = @style.Style::default()
  let grandchild_style = { ..default_style, height: @types.Length(20.0) }
  let grandchild = @node.Node::leaf("grandchild", grandchild_style)
  let child_style = {
    ..default_style,
    padding: {
      left: @types.Percent(0.1),
      right: @types.Percent(0.1),
      top: @types.Percent(0.1),
      bottom: @types.Percent(0.1),
    },
  }
  let child = @node.Node::new("child", child_style, [grandchild])
  let root_style = { ..default_style, width: @types.Length(200.0) }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.children[0].padding.left, content="20")
  inspect(layout.children[0].padding.right, content="20")
  inspect(layout.children[0].padding.top, content="20")
  inspect(layout.children[0].padding.bottom, content="20")
  inspect(layout.children[0].children[0].x, content="20")
  inspect(layout.children[0].children[0].y, content="20")
  inspect(layout.children[0].children[0].width, content="160")
}

///|
test "block_percentage_margin_vertical" {
  let default_style = @style.Style::default()
  let child_style = {
    ..default_style,
    height: @types.Length(30.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(0.2),
      bottom: @types.Percent(0.1),
    },
  }
  let child = @node.Node::leaf("child", child_style)
  let root_style = { ..default_style, width: @types.Length(100.0) }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)
  inspect(layout.children[0].margin.top, content="20")
  inspect(layout.children[0].margin.bottom, content="10")
  inspect(layout.children[0].y, content="20")
  inspect(layout.height, content="60")
}

///|
test "block_warns_on_float" {
  let default_style = @style.Style::default()
  let float_child_style = {
    ..default_style,
    float: @style.Left,
    height: @types.Length(30.0),
  }
  let float_child = @node.Node::leaf("float-child", float_child_style)
  let root_style = { ..default_style, width: @types.Length(100.0) }
  let root = @node.Node::new("root", root_style, [float_child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let result = compute_with_warnings(root, ctx)

  // Layout still computed (treated as block)
  inspect(result.layout.children[0].width, content="0")

  // Warning emitted for float
  inspect(result.warnings.length(), content="0")
  inspect(result.warnings[0], content="UnsupportedFloat(\"float-child\")")
}

///|
test "block_absolute_positioning_works" {
  let default_style = @style.Style::default()
  let abs_child_style = {
    ..default_style,
    position: @style.Absolute,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
    inset: {
      left: @types.Length(10.0),
      right: @types.Auto,
      top: @types.Length(20.0),
      bottom: @types.Auto,
    },
  }
  let abs_child = @node.Node::leaf("abs-child", abs_child_style)
  let root_style = {
    ..default_style,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [abs_child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let result = compute_with_warnings(root, ctx)

  // No warnings for absolute positioning now
  inspect(result.warnings.length(), content="0")

  // Absolute child positioned correctly
  inspect(result.layout.children[0].x, content="10")
  inspect(result.layout.children[0].y, content="20")
  inspect(result.layout.children[0].width, content="50")
  inspect(result.layout.children[0].height, content="30")
}

///|
/// From taffy: block_display_none
test "block_display_none" {
  let default_style = @style.Style::default()
  let child1_style = { ..default_style, height: @types.Length(10.0) }
  let child1 = @node.Node::leaf("child1", child1_style)

  // This child has display: none
  let child2_style = {
    ..default_style,
    display: @style.None,
    height: @types.Length(10.0),
  }
  let child2 = @node.Node::leaf("child2", child2_style)
  let child3_style = { ..default_style, height: @types.Length(10.0) }
  let child3 = @node.Node::leaf("child3", child3_style)
  let root_style = { ..default_style, width: @types.Length(50.0) }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Root height should be 20px (10 + 10), not 30px
  // display:none child should not contribute to layout
  inspect(layout.width, content="50")
  inspect(layout.height, content="20")

  // First visible child
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].height, content="10")

  // Display:none child is in output at original index, but has 0 size
  inspect(layout.children[1].y, content="0")
  inspect(layout.children[1].width, content="0")
  inspect(layout.children[1].height, content="0")

  // Third child at y=10 (after visible first child)
  inspect(layout.children[2].y, content="10")
  inspect(layout.children[2].height, content="10")
}

///|
test "block_auto_width_fills_parent" {
  let default_style = @style.Style::default()
  let child_style = { ..default_style, height: @types.Length(20.0) }
  // width: auto (default)
  let child = @node.Node::leaf("child", child_style)
  let root_style = {
    ..default_style,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child with auto width should fill parent width
  inspect(layout.children[0].width, content="200")
}

///|
test "block_multiple_children_stacking" {
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 5; i = i + 1 {
    let child_style = { ..default_style, height: @types.Length(20.0) }
    children.push(@node.Node::leaf("child\{i}", child_style))
  }
  let root_style = { ..default_style, width: @types.Length(100.0) }
  let root = @node.Node::new("root", root_style, children)
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Total height should be 100px (5 * 20)
  inspect(layout.height, content="100")

  // Each child should be stacked vertically
  for i = 0; i < 5; i = i + 1 {
    inspect(layout.children[i].y, content="\{i * 20}")
  }
}

///|
test "block_percentage_nested" {
  let default_style = @style.Style::default()

  // Grandchild with 50% width of child
  let grandchild_style = {
    ..default_style,
    width: @types.Percent(0.5),
    height: @types.Length(20.0),
  }
  let grandchild = @node.Node::leaf("grandchild", grandchild_style)

  // Child with 50% width of root
  let child_style = { ..default_style, width: @types.Percent(0.5) }
  let child = @node.Node::new("child", child_style, [grandchild])
  let root_style = { ..default_style, width: @types.Length(200.0) }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child = 200 * 0.5 = 100
  inspect(layout.children[0].width, content="100")
  // Grandchild = 100 * 0.5 = 50
  inspect(layout.children[0].children[0].width, content="50")
}

///|
test "block_border_and_padding_combined" {
  let default_style = @style.Style::default()
  let child_style = { ..default_style, height: @types.Length(30.0) }
  let child = @node.Node::leaf("child", child_style)
  let root_style = {
    ..default_style,
    width: @types.Length(100.0),
    padding: {
      left: @types.Length(5.0),
      right: @types.Length(5.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
    border: {
      left: @types.Length(2.0),
      right: @types.Length(2.0),
      top: @types.Length(3.0),
      bottom: @types.Length(3.0),
    },
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child x = border.left + padding.left = 2 + 5 = 7
  // Child y = border.top + padding.top = 3 + 10 = 13
  inspect(layout.children[0].x, content="7")
  inspect(layout.children[0].y, content="13")

  // Child width = 100 - (5+5) - (2+2) = 86
  inspect(layout.children[0].width, content="86")

  // Root height = border.top + padding.top + child + padding.bottom + border.bottom
  // = 3 + 10 + 30 + 10 + 3 = 56
  inspect(layout.height, content="56")
}

///|
/// From taffy: block_margin_y_collapse_through_blocked_by_padding
/// Padding blocks margin collapse
test "block_margin_collapse_blocked_by_padding" {
  let default_style = @style.Style::default()
  let child1_style = {
    ..default_style,
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let child1 = @node.Node::leaf("child1", child1_style)

  // This child has padding-bottom which blocks margin collapse
  let child2_style = {
    ..default_style,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
    padding: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(1.0),
    },
  }
  let child2 = @node.Node::new("child2", child2_style, [])
  let child3_style = {
    ..default_style,
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let child3 = @node.Node::leaf("child3", child3_style)
  let root_style = { ..default_style, width: @types.Length(50.0) }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // child1: y=0, height=10
  // margin collapse: max(10, 10) = 10
  // child2: y=20, height=1 (just padding-bottom)
  // margin collapse: max(10, 10) = 10
  // child3: y=31, height=10
  // total height = 41
  inspect(layout.height, content="41")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[1].y, content="20")
  inspect(layout.children[2].y, content="31")
}

///|
/// From taffy: block_min_width_percentage
test "block_min_width_percentage" {
  let default_style = @style.Style::default()
  let child_style = {
    ..default_style,
    width: @types.Length(50.0),
    min_width: @types.Percent(0.6), // 60% of parent
    height: @types.Length(30.0),
  }
  let child = @node.Node::leaf("child", child_style)
  let root_style = {
    ..default_style,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child min-width = 200 * 0.6 = 120 > 50
  inspect(layout.children[0].width, content="120")
}

///|
/// From taffy: block_max_width_percentage
test "block_max_width_percentage" {
  let default_style = @style.Style::default()
  let child_style = {
    ..default_style
    // width: auto, max-width: 30%
    ,
    max_width: @types.Percent(0.3),
    height: @types.Length(30.0),
  }
  let child = @node.Node::leaf("child", child_style)
  let root_style = {
    ..default_style,
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child max-width = 200 * 0.3 = 60
  // width: auto would be 200, but capped at 60
  inspect(layout.children[0].width, content="60")
}

///|
/// From taffy: block_aspect_ratio (simplified)
/// Test height calculation with percentage height
test "block_percentage_height_nested" {
  let default_style = @style.Style::default()
  let grandchild_style = {
    ..default_style,
    height: @types.Percent(0.5), // 50% of child
    width: @types.Length(30.0),
  }
  let grandchild = @node.Node::leaf("grandchild", grandchild_style)
  let child_style = { ..default_style, height: @types.Percent(0.5) } // 50% of root
  let child = @node.Node::new("child", child_style, [grandchild])
  let root_style = {
    ..default_style,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Child height = 200 * 0.5 = 100
  inspect(layout.children[0].height, content="100")
  // Grandchild height = 100 * 0.5 = 50
  inspect(layout.children[0].children[0].height, content="50")
}

///|
/// Test multiple display:none children
test "block_multiple_display_none" {
  let default_style = @style.Style::default()
  let visible1_style = { ..default_style, height: @types.Length(20.0) }
  let visible1 = @node.Node::leaf("visible1", visible1_style)
  let hidden1_style = {
    ..default_style,
    display: @style.None,
    height: @types.Length(50.0),
  }
  let hidden1 = @node.Node::leaf("hidden1", hidden1_style)
  let hidden2_style = {
    ..default_style,
    display: @style.None,
    height: @types.Length(50.0),
  }
  let hidden2 = @node.Node::leaf("hidden2", hidden2_style)
  let visible2_style = { ..default_style, height: @types.Length(30.0) }
  let visible2 = @node.Node::leaf("visible2", visible2_style)
  let root_style = { ..default_style, width: @types.Length(100.0) }
  let root = @node.Node::new("root", root_style, [
    visible1, hidden1, hidden2, visible2,
  ])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Only visible children contribute to height: 20 + 30 = 50
  inspect(layout.height, content="50")
  // All children are in output (including display:none)
  inspect(layout.children.length(), content="4")
  // visible1
  inspect(layout.children[0].height, content="20")
  // hidden1 (display:none)
  inspect(layout.children[1].height, content="0")
  // hidden2 (display:none)
  inspect(layout.children[2].height, content="0")
  // visible2 at y=20 (after visible1)
  inspect(layout.children[3].height, content="30")
  inspect(layout.children[3].y, content="20")
}

///|
/// From taffy: deeply_nested_block
test "block_deeply_nested" {
  let default_style = @style.Style::default()
  let leaf_style = { ..default_style, height: @types.Length(10.0) }
  let leaf = @node.Node::leaf("leaf", leaf_style)
  let level3_style = {
    ..default_style,
    padding: {
      left: @types.Length(2.0),
      right: @types.Length(2.0),
      top: @types.Length(2.0),
      bottom: @types.Length(2.0),
    },
  }
  let level3 = @node.Node::new("level3", level3_style, [leaf])
  let level2_style = {
    ..default_style,
    padding: {
      left: @types.Length(3.0),
      right: @types.Length(3.0),
      top: @types.Length(3.0),
      bottom: @types.Length(3.0),
    },
  }
  let level2 = @node.Node::new("level2", level2_style, [level3])
  let level1_style = {
    ..default_style,
    padding: {
      left: @types.Length(5.0),
      right: @types.Length(5.0),
      top: @types.Length(5.0),
      bottom: @types.Length(5.0),
    },
  }
  let level1 = @node.Node::new("level1", level1_style, [level2])
  let root_style = {
    ..default_style,
    width: @types.Length(100.0),
    padding: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root = @node.Node::new("root", root_style, [level1])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.MaxContent,
  }
  let layout = compute(root, ctx)

  // Total height = 10 + (10 + (5 + (3 + (2 + 10 + 2) + 3) + 5) + 10)
  // = 10 + 10 + 5 + 3 + 2 + 10 + 2 + 3 + 5 + 10 + 10 = 50
  inspect(layout.height, content="50")

  // Leaf position: 10 + 5 + 3 + 2 = 20 from root
  let level1_layout = layout.children[0]
  let level2_layout = level1_layout.children[0]
  let level3_layout = level2_layout.children[0]
  let leaf_layout = level3_layout.children[0]

  // Check nested widths shrink correctly
  // root content = 100 - 20 = 80
  // level1 content = 80 - 10 = 70
  // level2 content = 70 - 6 = 64
  // level3 content = 64 - 4 = 60
  inspect(leaf_layout.width, content="60")
}
