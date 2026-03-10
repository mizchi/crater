///|
/// Tests for Inline Formatting Context (IFC)

///|
/// Default dispatch for tests
fn default_dispatch() -> @node.DispatchFn {
  @node.DispatchFn(fn(node, ctx, dispatch) {
    compute_ifc_node(node, ctx, dispatch)
  })
}

///|
/// Helper to compute inline node with dispatch
fn compute_ifc_node(
  node : @node.Node,
  _ctx : @types.LayoutContext,
  _dispatch : @node.DispatchFn,
) -> @types.Layout {
  // Simple leaf layout
  let width = match node.style.width {
    @types.Length(w) => w
    _ => 0.0
  }
  let height = match node.style.height {
    @types.Length(h) => h
    _ => 0.0
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width,
    height,
    margin: @types.Rect::zero(),
    padding: @types.Rect::zero(),
    border: @types.Rect::zero(),
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: [],
    text: node.text,
  }
}

///|
test "ifc_horizontal_layout" {
  // Two inline-block elements should be laid out horizontally
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let child2 = @node.Node::leaf("child2", inline_style)
  let result = compute_ifc(
    [child1, child2],
    400.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )
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
test "ifc_negative_top_margin_atomic_inline_keeps_line_box_band" {
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineFlex,
    width: @types.Length(64.0),
    height: @types.Length(19.2),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-200.0),
      bottom: @types.Length(0.0),
    },
  }
  let child = @node.Node::leaf("child", inline_style)
  let result = compute_ifc(
    [child],
    400.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )
  guard result.layouts.length() == 1 else {
    fail("ifc should keep the atomic inline child")
  }
  guard (result.total_height - 19.2).abs() < 0.01 else {
    fail("negative top margin should not collapse the line box height")
  }
  guard result.layouts[0].y.abs() < 0.01 else {
    fail(
      "negative top margin should not move the atomic inline box above the line",
    )
  }
}

///|
test "ifc_line_wrapping" {
  // Three inline-block elements, third should wrap to new line
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
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
    default_dispatch(),
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
test "ifc_nowrap_keeps_inline_blocks_on_same_line" {
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
    width: @types.Length(60.0),
    height: @types.Length(30.0),
    white_space: @style.WhiteSpace::Nowrap,
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let child2 = @node.Node::leaf("child2", inline_style)
  let result = compute_ifc(
    [child1, child2],
    100.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )
  inspect(result.layouts.length(), content="2")
  inspect(result.layouts[0].x, content="0")
  inspect(result.layouts[0].y, content="0")
  inspect(result.layouts[1].x, content="60")
  inspect(result.layouts[1].y, content="0")
  inspect(result.total_height, content="30")
}

///|
test "ifc_rtl_nowrap_places_overflow_items_to_inline_start_side" {
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
    width: @types.Length(100.0),
    height: @types.Length(30.0),
    white_space: @style.WhiteSpace::Nowrap,
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let child2 = @node.Node::leaf("child2", inline_style)
  let result = compute_ifc(
    [child1, child2],
    100.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
    container_direction=@style.Direction::Rtl,
    container_white_space=@style.WhiteSpace::Nowrap,
  )
  inspect(result.layouts.length(), content="2")
  inspect(result.layouts[0].x, content="0")
  inspect(result.layouts[1].x, content="-100")
  inspect(result.layouts[0].y, content="0")
  inspect(result.layouts[1].y, content="0")
  inspect(result.total_height, content="30")
}

///|
test "ifc_vertical_writing_wraps_by_available_height" {
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
    width: @types.Length(50.0),
    height: @types.Length(100.0),
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let child2 = @node.Node::leaf("child2", inline_style)
  let result = compute_ifc(
    [child1, child2],
    100.0,
    Some(100.0),
    0.0,
    0.0,
    default_dispatch(),
    container_writing_mode=@style.WritingMode::VerticalRl,
  )
  inspect(result.layouts.length(), content="2")
  inspect(result.layouts[0].x, content="50")
  inspect(result.layouts[0].y, content="0")
  inspect(result.layouts[1].x, content="0")
  inspect(result.layouts[1].y, content="0")
  inspect(result.total_height, content="100")
}

///|
test "ifc_vertical_nowrap_keeps_items_in_single_column" {
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
    width: @types.Length(50.0),
    height: @types.Length(100.0),
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let child2 = @node.Node::leaf("child2", inline_style)
  let result = compute_ifc(
    [child1, child2],
    100.0,
    Some(100.0),
    0.0,
    0.0,
    default_dispatch(),
    container_writing_mode=@style.WritingMode::VerticalLr,
    container_white_space=@style.WhiteSpace::Nowrap,
  )
  inspect(result.layouts.length(), content="2")
  inspect(result.layouts[0].x, content="0")
  inspect(result.layouts[0].y, content="0")
  inspect(result.layouts[1].x, content="0")
  inspect(result.layouts[1].y, content="100")
  inspect(result.total_height, content="200")
}

///|
test "ifc_with_margins" {
  // Inline-block elements with margins
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
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
  let result = compute_ifc(
    [child1, child2],
    400.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )
  // First child at x=5 (margin-left)
  inspect(result.layouts[0].x, content="5")
  // Second child at x=55 (5 + 40 + 5 + 5)
  inspect(result.layouts[1].x, content="55")
}

///|
test "ifc_line_height_with_vertical_margins" {
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
    width: @types.Length(0.0),
    height: @types.Length(3.0),
    margin: {
      left: @types.Length(5.0),
      right: @types.Length(5.0),
      top: @types.Length(5.0),
      bottom: @types.Length(5.0),
    },
  }
  let child1 = @node.Node::leaf("child1", inline_style)
  let child2 = @node.Node::leaf("child2", inline_style)
  let result = compute_ifc(
    [child1, child2],
    0.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )
  inspect(result.layouts[0].x, content="5")
  inspect(result.layouts[0].y, content="5")
  inspect(result.layouts[1].y, content="18")
  inspect(result.total_height, content="26")
}

///|
test "ifc_replaced_only_line_includes_strut_descent" {
  let default_style = @style.Style::default()
  let replaced_style = {
    ..default_style,
    display: @types.Inline,
    font_size: 16.0,
    line_height: 19.2,
  }
  let replaced_measure : @types.MeasureFunc = {
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      {
        min_width: 300.0,
        max_width: 300.0,
        min_height: 150.0,
        max_height: 150.0,
      }
    },
  }
  let child1 = @node.Node::with_measure("img", replaced_style, replaced_measure)
  let child2 = @node.Node::with_measure(
    "video", replaced_style, replaced_measure,
  )
  let result = compute_ifc(
    [child1, child2],
    800.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )
  inspect(result.total_height, content="156.4")
}

///|
test "ifc_contain_size_replaced_auto_size_uses_border_box_only" {
  let default_style = @style.Style::default()
  let replaced_style = {
    ..default_style,
    display: @types.Inline,
    contain: { ..default_style.contain, size: true },
    border: {
      top: @types.Length(3.0),
      right: @types.Length(3.0),
      bottom: @types.Length(3.0),
      left: @types.Length(3.0),
    },
  }
  let replaced_measure : @types.MeasureFunc = {
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      {
        min_width: 300.0,
        max_width: 300.0,
        min_height: 150.0,
        max_height: 150.0,
      }
    },
  }
  let child = @node.Node::with_measure("img", replaced_style, replaced_measure)
  let result = compute_ifc(
    [child],
    800.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )
  inspect(result.layouts[0].width, content="6")
  inspect(result.layouts[0].height, content="6")
}

///|
test "ifc_contain_size_replaced_uses_explicit_aspect_ratio_for_auto_height" {
  let default_style = @style.Style::default()
  let replaced_style = {
    ..default_style,
    display: @types.Inline,
    contain: { ..default_style.contain, size: true },
    width: @types.Length(100.0),
    height: @types.Auto,
    aspect_ratio: Some(1.0),
  }
  let replaced_measure : @types.MeasureFunc = {
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 60.0, max_width: 60.0, min_height: 60.0, max_height: 60.0 }
    },
  }
  let child = @node.Node::with_measure("img", replaced_style, replaced_measure)
  let result = compute_ifc(
    [child],
    800.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )
  inspect(result.layouts[0].width, content="100")
  inspect(result.layouts[0].height, content="100")
}

///|
test "ifc_contain_size_img_with_alt_keeps_taller_mixed_inline_line" {
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.Inline,
    font_size: 16.0,
    line_height: 19.2,
  }
  let contain_img_style = {
    ..inline_style,
    contain: { ..default_style.contain, size: true },
    padding: {
      top: @types.Length(50.0),
      right: @types.Length(50.0),
      bottom: @types.Length(50.0),
      left: @types.Length(50.0),
    },
  }
  let image_measure : @types.MeasureFunc = {
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      {
        min_width: 100.0,
        max_width: 100.0,
        min_height: 100.0,
        max_height: 100.0,
      }
    },
  }
  let space_measure : @types.MeasureFunc = {
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 8.0, max_width: 8.0, min_height: 19.2, max_height: 19.2 }
    },
  }
  let blue = @node.Node::with_measure(
    "img#blue-test",
    contain_img_style,
    image_measure,
    text="Image download support must be enabled",
  )
  let space = @node.Node::text("#text", inline_style, space_measure, " ")
  let orange = @node.Node::with_measure(
    "img#orange-reference",
    inline_style,
    image_measure,
    text="Image download support must be enabled",
  )
  let result = compute_ifc(
    [blue, space, orange],
    800.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )

  if result.total_height <= 150.0 {
    fail(
      "mixed inline line with contain:size image should not collapse to 150px",
    )
  }
  if result.layouts[2].y <= 40.0 {
    fail(
      "following inline image should be pushed down by contain:size baseline behavior",
    )
  }
}

///|
test "ifc_content_offset" {
  // IFC with content offset (padding/border of container)
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.InlineBlock,
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
    default_dispatch(),
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
    display: @types.InlineBlock,
    width: @types.Length(50.0),
    height: @types.Length(60.0),
  }
  let short_style = {
    ..default_style,
    display: @types.InlineBlock,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  }
  let tall = @node.Node::leaf("tall", tall_style)
  let short = @node.Node::leaf("short", short_style)
  let result = compute_ifc(
    [tall, short],
    400.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )
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
  inspect(is_inline_level(@types.Inline), content="true")
  inspect(is_inline_level(@types.InlineBlock), content="true")
  inspect(is_inline_level(@types.InlineFlex), content="true")
  inspect(is_inline_level(@types.InlineGrid), content="true")
  inspect(is_inline_level(@types.Block), content="false")
  inspect(is_inline_level(@types.Flex), content="false")
  inspect(is_inline_level(@types.Grid), content="false")
  inspect(is_inline_level(@types.Display::None), content="false")
}

///|
test "should_establish_ifc_all_inline" {
  let default_style = @style.Style::default()
  let inline_style = { ..default_style, display: @types.InlineBlock }
  let child1 = @node.Node::leaf("c1", inline_style)
  let child2 = @node.Node::leaf("c2", inline_style)
  // All inline-level children should establish IFC
  inspect(should_establish_ifc([child1, child2]), content="true")
}

///|
test "should_establish_ifc_mixed" {
  let default_style = @style.Style::default()
  let inline_style = { ..default_style, display: @types.InlineBlock }
  let block_style = { ..default_style, display: @types.Block }
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

///|
test "text_width_constrained_by_available_width" {
  // Text node with MeasureFunc should be constrained by available_width
  let default_style = @style.Style::default()
  let inline_style = { ..default_style, display: @types.Inline }

  // MeasureFunc that returns wide text (max_width=200) that wraps to 4 lines at width=50
  let measure : @types.MeasureFunc = {
    func: fn(
      available_width : Double,
      _available_height : Double,
    ) -> @types.IntrinsicSize {
      let max_width = 200.0 // Single line width
      let line_height = 16.0
      // Calculate wrapped height based on available_width
      let lines = if available_width >= max_width {
        1.0
      } else if available_width > 0.0 {
        (max_width / available_width).ceil()
      } else {
        1.0
      }
      {
        min_width: 40.0, // Longest word
        max_width,
        min_height: line_height,
        max_height: lines * line_height,
      }
    },
  }
  let text_node = @node.Node::with_measure("text", inline_style, measure)
  let result = compute_ifc(
    [text_node],
    100.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )

  // Width should be constrained to available_width (100), not max_width (200)
  inspect(result.layouts[0].width, content="100")
  // Height should be for 2 wrapped lines (200/100 = 2 lines * 16 = 32)
  inspect(result.layouts[0].height, content="32")
}

///|
test "text_width_unconstrained_when_smaller" {
  // Text node narrower than available_width should use its max_width
  let default_style = @style.Style::default()
  let inline_style = { ..default_style, display: @types.Inline }

  // MeasureFunc for short text (max_width=50)
  let measure : @types.MeasureFunc = {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @types.IntrinsicSize {
      { min_width: 20.0, max_width: 50.0, min_height: 16.0, max_height: 16.0 }
    }, // Single line
  }
  let text_node = @node.Node::with_measure("text", inline_style, measure)
  let result = compute_ifc(
    [text_node],
    400.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )

  // Width should be text's natural width (50), not available_width (400)
  inspect(result.layouts[0].width, content="50")
  // Height should be single line (16)
  inspect(result.layouts[0].height, content="16")
}

///|
test "text_min_content_width" {
  // Text node with width: min-content should use min_width
  let default_style = @style.Style::default()
  let inline_style = {
    ..default_style,
    display: @types.Inline,
    width: @types.MinContent,
  }
  let measure : @types.MeasureFunc = {
    func: fn(
      available_width : Double,
      _available_height : Double,
    ) -> @types.IntrinsicSize {
      let max_width = 200.0
      let min_width = 40.0 // Longest word
      let line_height = 16.0
      let lines = if available_width >= max_width {
        1.0
      } else if available_width > 0.0 {
        (max_width / available_width).ceil()
      } else {
        1.0
      }
      {
        min_width,
        max_width,
        min_height: line_height,
        max_height: lines * line_height,
      }
    },
  }
  let text_node = @node.Node::with_measure("text", inline_style, measure)
  let result = compute_ifc(
    [text_node],
    400.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )

  // Width should be min_width (40)
  inspect(result.layouts[0].width, content="40")
  // Height should be for 5 wrapped lines (200/40 = 5 lines * 16 = 80)
  inspect(result.layouts[0].height, content="80")
}

///|
test "inline_element_with_child_has_size" {
  // An inline element (like <a>) containing a child should have proper size
  // This tests the fix for 0x0 link size issue
  let default_style = @style.Style::default()
  let inline_style = { ..default_style, display: @types.Inline }

  // Create a text child with MeasureFunc (simulating text content)
  let child_measure : @types.MeasureFunc = {
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 80.0, max_width: 80.0, min_height: 16.0, max_height: 16.0 }
    },
  }
  let text_child = @node.Node::with_measure("text", inline_style, child_measure)

  // Create inline parent (like <a>) containing the text
  let link = @node.Node::new("a", inline_style, [text_child])
  let result = compute_ifc(
    [link],
    400.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )

  // Link should have width and height from its child, NOT 0x0
  inspect(result.layouts[0].width, content="80")
  inspect(result.layouts[0].height, content="16")
}

///|
test "inline_element_with_padding_and_child" {
  // An inline element with padding containing a child
  let default_style = @style.Style::default()
  let inline_style = { ..default_style, display: @types.Inline }
  let inline_with_padding = {
    ..inline_style,
    padding: {
      left: @types.Length(5.0),
      right: @types.Length(5.0),
      top: @types.Length(2.0),
      bottom: @types.Length(2.0),
    },
  }

  // Create a text child with MeasureFunc
  let child_measure : @types.MeasureFunc = {
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 100.0, max_width: 100.0, min_height: 20.0, max_height: 20.0 }
    },
  }
  let text_child = @node.Node::with_measure("text", inline_style, child_measure)

  // Create inline parent with padding
  let link = @node.Node::new("a", inline_with_padding, [text_child])
  let result = compute_ifc(
    [link],
    400.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )

  // Link width = child width (100) + padding left (5) + padding right (5) = 110
  inspect(result.layouts[0].width, content="110")
  // Link height = child height (20) + padding top (2) + padding bottom (2) = 24
  inspect(result.layouts[0].height, content="24")
}

///|
test "br_after_wrapped_text_uses_last_visual_line_position" {
  let default_style = @style.Style::default()
  let text_style = {
    ..default_style,
    display: @types.Inline,
    font_size: 16.0,
    line_height: 19.2,
    white_space: @style.WhiteSpace::Normal,
  }
  let text = "Expected: A green box, overlapping red box, and a small, inset cyan box. The"
  // Intrinsic width 624px at 16px monospace-like metrics, wraps into two lines at 600px.
  let text_measure : @types.MeasureFunc = {
    func: fn(
      available_width : Double,
      _available_height : Double,
    ) -> @types.IntrinsicSize {
      let line_height = 19.2
      let max_width = 624.0
      let wrapped_height = if available_width >= max_width {
        line_height
      } else {
        line_height * 2.0
      }
      {
        min_width: 24.0,
        max_width,
        min_height: line_height,
        max_height: wrapped_height,
      }
    },
  }
  let text_node = @node.Node::text("#text", text_style, text_measure, text)

  let br_style = {
    ..default_style,
    display: @types.Inline,
    font_size: 16.0,
    line_height: 19.2,
  }
  let br_measure : @types.MeasureFunc = {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @types.IntrinsicSize {
      { min_width: 0.0, max_width: 0.0, min_height: 19.2, max_height: 19.2 }
    },
  }
  let br_node = @node.Node::with_measure("br", br_style, br_measure)

  let result = compute_ifc(
    [text_node, br_node],
    600.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )

  inspect(result.layouts.length(), content="2")
  inspect(result.layouts[1].x, content="24")
  inspect(result.layouts[1].y, content="19.2")
}

///|
test "br_after_vertical_align_top_tall_inline_block_stays_near_line_top" {
  let default_style = @style.Style::default()
  let button_style = {
    ..default_style,
    display: @types.InlineBlock,
    width: @types.Length(38.0),
    height: @types.Length(50.0),
    vertical_align: @style.VerticalAlign::Top,
    contain: { ..default_style.contain, size: true },
  }
  let button_node = @node.Node::leaf("button", button_style)

  let br_style = {
    ..default_style,
    display: @types.Inline,
    font_size: 14.0,
    line_height: 16.1,
  }
  let br_measure : @types.MeasureFunc = {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @types.IntrinsicSize {
      { min_width: 0.0, max_width: 0.0, min_height: 16.1, max_height: 16.1 }
    },
  }
  let br_node = @node.Node::with_measure("br", br_style, br_measure)

  let result = compute_ifc(
    [button_node, br_node],
    600.0,
    Some(600.0),
    0.0,
    0.0,
    default_dispatch(),
  )

  inspect(result.layouts.length(), content="2")
  inspect(result.layouts[0].y, content="0")
  if result.layouts[1].y >= 20.0 {
    fail(
      "br should stay near line top for vertical-align: top tall inline-block",
    )
  }
}
