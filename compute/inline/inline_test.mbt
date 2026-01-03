///|
/// Tests for Inline Formatting Context (IFC)

///|
test "ifc_horizontal_layout" {
  // Two inline-block elements should be laid out horizontally
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @style.InlineBlock,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let child2 = @node.Node::leaf("child2", inline_style)
  let result = compute_ifc([child1, child2], 400.0, Some(600.0), 0.0, 0.0)
  // Two children should be laid out
  inspect(result.layouts.length(), content="2")
  // First child at x=0
  inspect(result.layouts[0].x, content="0")
  // Second child at x=50 (after first child)
  inspect(result.layouts[1].x, content="50")
  // Both at y=0 (same line)
  inspect(result.layouts[0].y, content="0")
  inspect(result.layouts[1].y, content="0")
  // Total height should be 30
  inspect(result.total_height, content="30")
}

///|
test "ifc_line_wrapping" {
  // Three inline-block elements, third should wrap to new line
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @style.InlineBlock,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let child2 = @node.Node::leaf("child2", inline_style)
  let child3 = @node.Node::leaf("child3", inline_style)
  // Available width is 100, so only 2 children fit per line
  let result = compute_ifc(
    [child1, child2, child3],
    100.0,
    Some(600.0),
    0.0,
    0.0,
  )
  inspect(result.layouts.length(), content="3")
  // First child at (0, 0)
  inspect(result.layouts[0].x, content="0")
  inspect(result.layouts[0].y, content="0")
  // Second child at (50, 0)
  inspect(result.layouts[1].x, content="50")
  inspect(result.layouts[1].y, content="0")
  // Third child on new line at (0, 30)
  inspect(result.layouts[2].x, content="0")
  inspect(result.layouts[2].y, content="30")
  // Total height should be 60 (2 lines)
  inspect(result.total_height, content="60")
}

///|
test "ifc_with_margins" {
  // Inline-block elements with margins
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @style.InlineBlock,
    width: @types.Length(40.0),
    height: @types.Length(30.0),
    margin: {
      left: @types.Length(5.0),
      right: @types.Length(5.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let child2 = @node.Node::leaf("child2", inline_style)
  let result = compute_ifc([child1, child2], 400.0, Some(600.0), 0.0, 0.0)
  // First child at x=5 (margin-left)
  inspect(result.layouts[0].x, content="5")
  // Second child at x=55 (5 + 40 + 5 + 5)
  inspect(result.layouts[1].x, content="55")
}

///|
test "ifc_content_offset" {
  // IFC with content offset (padding/border of container)
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @style.InlineBlock,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  }
  let child = @node.Node::leaf("child", inline_style)
  let result = compute_ifc(
    [child],
    400.0,
    Some(600.0),
    10.0, // content_offset_x (padding + border left)
    20.0, // content_offset_y (padding + border top)
  )
  // Child should be offset by container padding/border
  inspect(result.layouts[0].x, content="10")
  inspect(result.layouts[0].y, content="20")
}

///|
test "ifc_mixed_heights" {
  // Inline elements with different heights should align to bottom of line
  let default_style = @style.Style::default()
  let tall_style = {
    ..default_style,
    display: @style.InlineBlock,
    width: @types.Length(50.0),
    height: @types.Length(60.0),
  }
  let short_style = {
    ..default_style,
    display: @style.InlineBlock,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  }
  let tall = @node.Node::leaf("tall", tall_style)
  let short = @node.Node::leaf("short", short_style)
  let result = compute_ifc([tall, short], 400.0, Some(600.0), 0.0, 0.0)
  // Tall element at y=0
  inspect(result.layouts[0].y, content="0")
  // Short element should be aligned to bottom (y=30, so bottom=60 matches tall)
  inspect(result.layouts[1].y, content="30")
  // Line height should be 60 (height of tallest element)
  inspect(result.total_height, content="60")
}

///|
test "is_inline_level" {
  // Test inline-level detection
  inspect(is_inline_level(@style.Inline), content="true")
  inspect(is_inline_level(@style.InlineBlock), content="true")
  inspect(is_inline_level(@style.InlineFlex), content="true")
  inspect(is_inline_level(@style.InlineGrid), content="true")
  inspect(is_inline_level(@style.Block), content="false")
  inspect(is_inline_level(@style.Flex), content="false")
  inspect(is_inline_level(@style.Grid), content="false")
  inspect(is_inline_level(@style.None), content="false")
}

///|
test "should_establish_ifc_all_inline" {
  let default_style = @style.Style::default()
  let inline_style = { ..default_style, display: @style.InlineBlock }
  let child1 = @node.Node::leaf("c1", inline_style)
  let child2 = @node.Node::leaf("c2", inline_style)
  // All inline-level children should establish IFC
  inspect(should_establish_ifc([child1, child2]), content="true")
}

///|
test "should_establish_ifc_mixed" {
  let default_style = @style.Style::default()
  let inline_style = { ..default_style, display: @style.InlineBlock }
  let block_style = { ..default_style, display: @style.Block }
  let inline_child = @node.Node::leaf("inline", inline_style)
  let block_child = @node.Node::leaf("block", block_style)
  // Mixed inline and block should NOT establish IFC
  inspect(should_establish_ifc([inline_child, block_child]), content="false")
}

///|
test "should_establish_ifc_empty" {
  // Empty children should not establish IFC
  let children : Array[@node.Node] = []
  inspect(should_establish_ifc(children), content="false")
}
