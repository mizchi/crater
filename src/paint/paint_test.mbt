///|
test "PaintNode clips_content with overflow hidden" {
  let node = PaintNode::new(
    "test",
    "div",
    0.0,
    0.0,
    100.0,
    100.0,
    PaintProperties::default(),
    [],
    overflow_x=@types.Hidden,
    overflow_y=@types.Hidden,
  )
  inspect(node.clips_content(), content="true")
}

///|
test "PaintNode clips_content with overflow visible" {
  let node = PaintNode::new(
    "test",
    "div",
    0.0,
    0.0,
    100.0,
    100.0,
    PaintProperties::default(),
    [],
    overflow_x=@types.Visible,
    overflow_y=@types.Visible,
  )
  inspect(node.clips_content(), content="false")
}

///|
test "PaintNode get_clip_rect returns rect when clipping" {
  let node = PaintNode::new(
    "test",
    "div",
    10.0,
    20.0,
    100.0,
    50.0,
    PaintProperties::default(),
    [],
    overflow_x=@types.Hidden,
    overflow_y=@types.Visible,
  )
  inspect(node.get_clip_rect(), content="Some((10, 20, 100, 50))")
}

///|
test "PaintNode get_clip_rect returns None when not clipping" {
  let node = PaintNode::new(
    "test",
    "div",
    10.0,
    20.0,
    100.0,
    50.0,
    PaintProperties::default(),
    [],
  )
  inspect(node.get_clip_rect(), content="None")
}

///|
test "PaintNode Show includes clips marker" {
  let node = PaintNode::new(
    "clipped",
    "div",
    0.0,
    0.0,
    1.0,
    1.0,
    PaintProperties::default(),
    [],
    overflow_x=@types.Hidden,
    overflow_y=@types.Hidden,
  )
  let s = node.to_string()
  inspect(s.contains("[clips]"), content="true")
}

///|
test "PaintNode with legacy clip rect" {
  let node = PaintNode::new(
    "test",
    "div",
    10.0,
    20.0,
    100.0,
    50.0,
    PaintProperties::default(),
    [],
    clip=@types.ClipRect::Rect(top=1.0, right=1.0, bottom=1.0, left=1.0),
  )
  inspect(node.clips_content(), content="true")
  inspect(node.has_legacy_clip(), content="true")
  // clip rect: x=10+1=11, y=20+1=21, w=1-1=0, h=1-1=0
  inspect(node.get_clip_rect(), content="Some((11, 21, 0, 0))")
}

///|
test "PaintNode legacy clip values" {
  let node = PaintNode::new(
    "test",
    "div",
    0.0,
    0.0,
    100.0,
    100.0,
    PaintProperties::default(),
    [],
    clip=@types.ClipRect::Rect(top=10.0, right=90.0, bottom=90.0, left=10.0),
  )
  // get_legacy_clip returns raw values
  inspect(node.get_legacy_clip(), content="Some((10, 90, 90, 10))")
  // get_clip_rect computes absolute coords: x=0+10=10, y=0+10=10, w=90-10=80, h=90-10=80
  inspect(node.get_clip_rect(), content="Some((10, 10, 80, 80))")
}

///|
/// Test from_node_and_layout_with_viewport culling behavior
test "viewport_culling_basic" {
  // Create a simple node tree manually
  let style = @style.Style::default()
  let child1 = @node.Node::new("child1", style, [])
  let child2 = @node.Node::new("child2", style, [])
  let child3 = @node.Node::new("child3", style, [])
  let root = @node.Node::new("root", style, [child1, child2, child3])

  // Create corresponding layouts
  // child1: y=0, height=100 (spans 0-100)
  // child2: y=100, height=100 (spans 100-200)
  // child3: y=200, height=100 (spans 200-300)
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
    height: 100.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    children: [],
    text: None,
  }
  let child2_layout : @types.Layout = {
    id: "child2",
    x: 0.0,
    y: 100.0,
    width: 100.0,
    height: 100.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    children: [],
    text: None,
  }
  let child3_layout : @types.Layout = {
    id: "child3",
    x: 0.0,
    y: 200.0,
    width: 100.0,
    height: 100.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    children: [],
    text: None,
  }
  let root_layout : @types.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 100.0,
    height: 300.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    children: [child1_layout, child2_layout, child3_layout],
    text: None,
  }

  // Test 1: Viewport 0-50 (should see root, child1)
  let paint1 = from_node_and_layout_with_viewport(
    root, root_layout, 0.0, 50.0, 0.0,
  )
  inspect(paint1 is Some(_), content="true")
  match paint1 {
    Some(p) =>
      // child1 (0-100) overlaps with viewport (0-50)
      // child2 (100-200) is below viewport
      // child3 (200-300) is below viewport
      inspect(p.children.length() >= 1, content="true")
    None => fail("viewport 0-50 should return Some")
  }

  // Test 2: Viewport 150-250 (should see root, child2, child3)
  let paint2 = from_node_and_layout_with_viewport(
    root, root_layout, 150.0, 250.0, 0.0,
  )
  inspect(paint2 is Some(_), content="true")
  match paint2 {
    Some(p) =>
      // child1 (0-100) is above viewport (100 < 150)
      // child2 (100-200) overlaps with viewport
      // child3 (200-300) overlaps with viewport
      inspect(p.children.length() >= 1, content="true")
    None => fail("viewport 150-250 should return Some")
  }

  // Test 3: Viewport 400-500 (way past content, should return None)
  let paint3 = from_node_and_layout_with_viewport(
    root, root_layout, 400.0, 500.0, 0.0,
  )
  // Root spans 0-300, viewport starts at 400, so root should be culled
  inspect(paint3 is None, content="true")
}

///|
/// Test viewport culling with zero-height container (like body with height: 100%)
/// This was the root cause of addyosmani.com scrolling issue
test "viewport_culling_zero_height_container" {
  // Simulate: body has height=0 (CSS height: 100% resolves to 0)
  // but children have actual content that extends beyond
  let style = @style.Style::default()
  let child = @node.Node::new("child", style, [])
  let container = @node.Node::new("body", style, [child])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  // Child has actual height (e.g., 1000px of content)
  let child_layout : @types.Layout = {
    id: "child",
    x: 0.0,
    y: 0.0,
    width: 800.0,
    height: 1000.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    children: [],
    text: None,
  }
  // Container (body) has height=0 due to CSS height: 100%
  let container_layout : @types.Layout = {
    id: "body",
    x: 0.0,
    y: 0.0,
    width: 800.0,
    height: 0.0, // This is the key issue!
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    children: [child_layout],
    text: None,
  }

  // Scroll = 0: viewport 0-400 - should see content
  let paint0 = from_node_and_layout_with_viewport(
    container, container_layout, 0.0, 400.0, 0.0,
  )
  inspect(paint0 is Some(_), content="true")

  // Scroll = 200px: viewport 200-600 - should STILL see content
  // Before fix: body (y=0, height=0) bottom=0, viewport_top=200
  //   0 < 200 = true -> body culled, children lost!
  // After fix: effective_bottom = max(child.y + child.height) = 1000
  //   1000 < 200 = false -> body not culled
  let paint1 = from_node_and_layout_with_viewport(
    container, container_layout, 200.0, 600.0, 0.0,
  )
  inspect(paint1 is Some(_), content="true")

  // Scroll = 500px: viewport 500-900 - should STILL see content
  let paint2 = from_node_and_layout_with_viewport(
    container, container_layout, 500.0, 900.0, 0.0,
  )
  inspect(paint2 is Some(_), content="true")

  // Scroll = 1200px: viewport 1200-1600 - should NOT see content (past 1000)
  let paint3 = from_node_and_layout_with_viewport(
    container, container_layout, 1200.0, 1600.0, 0.0,
  )
  inspect(paint3 is None, content="true")
}

///|
/// Test viewport culling with scroll position simulation
test "viewport_culling_scroll_simulation" {
  // Simulate Browser scroll behavior
  // viewport_height = 100px (6.25 chars)
  // content_height = 300px
  // max_scroll = 300 - 100 = 200px

  let style = @style.Style::default()
  let root = @node.Node::new("root", style, [])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let root_layout : @types.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 100.0,
    height: 300.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    children: [],
    text: None,
  }
  let font_height = 16.0
  let viewport_height_chars = 6 // 96px
  let _ = 300.0 // content_height for reference

  // Scroll = 0 chars (0px): viewport 0-96
  let scroll0 = 0
  let vp_top0 = scroll0.to_double() * font_height
  let vp_bottom0 = (scroll0 + viewport_height_chars).to_double() * font_height
  let paint0 = from_node_and_layout_with_viewport(
    root, root_layout, vp_top0, vp_bottom0, 0.0,
  )
  inspect(paint0 is Some(_), content="true")

  // Scroll = 6 chars (96px): viewport 96-192
  let scroll1 = 6
  let vp_top1 = scroll1.to_double() * font_height
  let vp_bottom1 = (scroll1 + viewport_height_chars).to_double() * font_height
  let paint1 = from_node_and_layout_with_viewport(
    root, root_layout, vp_top1, vp_bottom1, 0.0,
  )
  inspect(paint1 is Some(_), content="true")

  // Scroll = 12 chars (192px): viewport 192-288 (still within 0-300)
  let scroll2 = 12
  let vp_top2 = scroll2.to_double() * font_height
  let vp_bottom2 = (scroll2 + viewport_height_chars).to_double() * font_height
  let paint2 = from_node_and_layout_with_viewport(
    root, root_layout, vp_top2, vp_bottom2, 0.0,
  )
  inspect(paint2 is Some(_), content="true")

  // Max scroll in pixels = 300 - 96 = 204px = 12.75 chars
  // Scroll = 13 chars (208px): viewport 208-304 (overlaps with 0-300)
  let scroll3 = 13
  let vp_top3 = scroll3.to_double() * font_height
  let vp_bottom3 = (scroll3 + viewport_height_chars).to_double() * font_height
  let paint3 = from_node_and_layout_with_viewport(
    root, root_layout, vp_top3, vp_bottom3, 0.0,
  )
  // Root ends at 300, viewport starts at 208, ends at 304
  // Root 0-300 overlaps with viewport 208-304 (overlap at 208-300)
  inspect(paint3 is Some(_), content="true")

  // Scroll = 20 chars (320px): viewport 320-416 (past content 0-300)
  let scroll4 = 20
  let vp_top4 = scroll4.to_double() * font_height
  let vp_bottom4 = (scroll4 + viewport_height_chars).to_double() * font_height
  let paint4 = from_node_and_layout_with_viewport(
    root, root_layout, vp_top4, vp_bottom4, 0.0,
  )
  // Root ends at 300, viewport starts at 320 -> no overlap
  inspect(paint4 is None, content="true")
}
