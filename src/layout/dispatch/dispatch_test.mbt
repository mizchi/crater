///|
/// Tests for dispatch module including IFC integration

///|
test "dispatch_ifc_horizontal_layout" {
  // Set up the layout dispatcher
  setup()

  // Test that inline-block children in a block container are laid out horizontally using IFC
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
    width: @types.Dimension::Length(50.0),
    height: @types.Dimension::Length(30.0),
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let child2 = @node.Node::leaf("child2", inline_style)
  let root_style = { ..default_style, width: @types.Dimension::Length(400.0) }
  let root = @node.Node::new("root", root_style, [child1, child2])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
  }
  let layout = compute_layout(root, ctx)
  // Two inline-block children should be laid out horizontally
  inspect(layout.children.length(), content="2")
  // First child at x=0
  inspect(layout.children[0].x, content="0")
  // Second child at x=50 (after first child)
  inspect(layout.children[1].x, content="50")
  // Both on the same line (same y)
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[1].y, content="0")
  // Container height should be 30 (line height)
  inspect(layout.height, content="30")
}

///|
test "dispatch_ifc_line_wrap" {
  // Set up the layout dispatcher
  setup()

  // Test that inline-block children wrap when they exceed available width
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
    width: @types.Dimension::Length(60.0),
    height: @types.Dimension::Length(30.0),
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let child2 = @node.Node::leaf("child2", inline_style)
  let child3 = @node.Node::leaf("child3", inline_style)
  // Container width is 100, so only 1 child fits per line (60 > 100/2)
  // Actually 60+60 = 120 > 100, so second child wraps
  let root_style = { ..default_style, width: @types.Dimension::Length(100.0) }
  let root = @node.Node::new("root", root_style, [child1, child2, child3])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
  }
  let layout = compute_layout(root, ctx)
  // First child at (0, 0)
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
  // Second child at (0, 30) - wrapped to new line
  inspect(layout.children[1].x, content="0")
  inspect(layout.children[1].y, content="30")
  // Third child at (0, 60) - wrapped to third line
  inspect(layout.children[2].x, content="0")
  inspect(layout.children[2].y, content="60")
  // Container height should be 90 (3 lines)
  inspect(layout.height, content="90")
}

///|
test "dispatch_ifc_with_padding" {
  // Set up the layout dispatcher
  setup()

  // Test IFC with container padding
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
    width: @types.Dimension::Length(50.0),
    height: @types.Dimension::Length(30.0),
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let root_style = {
    ..default_style,
    width: @types.Dimension::Length(400.0),
    padding: {
      left: @types.Dimension::Length(10.0),
      right: @types.Dimension::Length(10.0),
      top: @types.Dimension::Length(20.0),
      bottom: @types.Dimension::Length(20.0),
    },
  }
  let root = @node.Node::new("root", root_style, [child1])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
  }
  let layout = compute_layout(root, ctx)
  // Child should be offset by padding
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].y, content="20")
  // Container height should include padding
  inspect(layout.height, content="70") // 20 + 30 + 20
}

///|
test "dispatch_inline_block_shrink_to_fit" {
  // Set up the layout dispatcher
  setup()

  // Test that inline-block elements shrink-to-fit their content
  let default_style = @style.Style::default()
  let leaf_style = {
    ..default_style,
    height: @types.Dimension::Length(20.0),
    width: @types.Dimension::Length(50.0),
  }
  let leaf = @node.Node::leaf("leaf", leaf_style)
  let inline_block_style = {
    ..default_style,
    display: @types.InlineBlock,
    padding: {
      left: @types.Dimension::Length(10.0),
      right: @types.Dimension::Length(10.0),
      top: @types.Dimension::Length(5.0),
      bottom: @types.Dimension::Length(5.0),
    },
  }
  let inline_block = @node.Node::new("inline-block", inline_block_style, [leaf])
  let root_style = { ..default_style, width: @types.Dimension::Length(400.0) }
  let root = @node.Node::new("root", root_style, [inline_block])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
  }
  let layout = compute_layout(root, ctx)

  // The inline-block should shrink to fit its content
  // Width should be: child width (50) + padding (10+10) = 70
  let inline_block_layout = layout.children[0]
  inspect(inline_block_layout.width, content="70")
  inspect(inline_block_layout.height, content="30") // 20 + 5 + 5
}
