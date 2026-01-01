// Auto-generated from taffy test fixtures
// DO NOT EDIT - regenerate with: npm run gen-moonbit-tests

///|
/// Helper for approximate floating point comparison (tolerance: 0.1)
fn assert_approx(actual : Double, expected : Double) -> Unit raise {
  let tolerance = 0.1
  let diff = if actual > expected { actual - expected } else { expected - actual }
  if diff > tolerance {
    raise Failure("assert_approx failed: actual=\{actual}, expected=\{expected}, diff=\{diff}")
  }
}

///|
test "taffy/absolute_correct_cross_child_size_with_percentage" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    position: @style.Position::Relative,
    width: @types.Length(300.0),
    height: @types.Length(110.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    position: @style.Position::Absolute,
    inset: { left: @types.Length(50.0), right: @types.Auto, top: @types.Length(40.0), bottom: @types.Auto },
    flex_direction: @style.Column,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(10.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
    width: @types.Percent(1.0000),
    height: @types.Length(10.0),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    width: @types.Percent(1.0000),
    height: @types.Length(10.0),
  }
  let root_child0_child2_children : Array[@node.Node] = []
  let root_child0_child2_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  }
  let root_child0_child2_child0 = @node.Node::leaf("node", root_child0_child2_child0_style)
  root_child0_child2_children.push(root_child0_child2_child0)
  let root_child0_child2 = @node.Node::new("node", root_child0_child2_style, root_child0_child2_children)
  root_child0_children.push(root_child0_child2)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 300.0)
  assert_approx(layout.height, 110.0)
  assert_approx(layout.children[0].x, 50.0)
  assert_approx(layout.children[0].y, 40.0)
  assert_approx(layout.children[0].width, 200.0)
  assert_approx(layout.children[0].height, 30.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 200.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[1].x, 0.0)
  assert_approx(layout.children[0].children[1].y, 10.0)
  assert_approx(layout.children[0].children[1].width, 200.0)
  assert_approx(layout.children[0].children[1].height, 10.0)
  assert_approx(layout.children[0].children[2].x, 0.0)
  assert_approx(layout.children[0].children[2].y, 20.0)
  assert_approx(layout.children[0].children[2].width, 200.0)
  assert_approx(layout.children[0].children[2].height, 10.0)
  assert_approx(layout.children[0].children[2].children[0].x, 0.0)
  assert_approx(layout.children[0].children[2].children[0].y, 0.0)
  assert_approx(layout.children[0].children[2].children[0].width, 10.0)
  assert_approx(layout.children[0].children[2].children[0].height, 10.0)
}

///|
test "taffy/chrome_issue_325928327" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Percent(1.0000),
    height: @types.Length(40.0),
    justify_items: @style.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Percent(1.0000),
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Percent(1.0000),
    aspect_ratio: Some(1.0000),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 40.0)
  assert_approx(layout.children[0].children[0].height, 40.0)
}

///|
test "taffy/grid_absolute_align_self_sized_all" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    align_self: @style.AlignSelf::Start,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    align_self: @style.AlignSelf::Start,
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    align_self: @style.AlignSelf::End,
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    align_self: @style.AlignSelf::End,
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    align_self: @style.AlignSelf::Center,
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    align_self: @style.AlignSelf::Center,
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    align_self: @style.AlignSelf::Stretch,
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    align_self: @style.AlignSelf::Stretch,
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 100.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 20.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 60.0)
  assert_approx(layout.children[3].width, 60.0)
  assert_approx(layout.children[3].height, 60.0)
  assert_approx(layout.children[4].x, 0.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 20.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 30.0)
  assert_approx(layout.children[5].width, 60.0)
  assert_approx(layout.children[5].height, 60.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 0.0)
  assert_approx(layout.children[6].width, 20.0)
  assert_approx(layout.children[6].height, 20.0)
  assert_approx(layout.children[7].x, 0.0)
  assert_approx(layout.children[7].y, 0.0)
  assert_approx(layout.children[7].width, 60.0)
  assert_approx(layout.children[7].height, 60.0)
}

///|
test "taffy/grid_absolute_column_end" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    grid_column: { start: @style.Auto, end: @style.Line(1) },
    inset: { left: @types.Length(4.0), right: @types.Length(3.0), top: @types.Length(1.0), bottom: @types.Length(2.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 4.0)
  assert_approx(layout.children[0].y, 1.0)
  assert_approx(layout.children[0].width, 33.0)
  assert_approx(layout.children[0].height, 157.0)
}

///|
test "taffy/grid_absolute_column_start" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    grid_column: { start: @style.Line(1), end: @style.Auto },
    inset: { left: @types.Length(4.0), right: @types.Length(3.0), top: @types.Length(1.0), bottom: @types.Length(2.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 44.0)
  assert_approx(layout.children[0].y, 1.0)
  assert_approx(layout.children[0].width, 133.0)
  assert_approx(layout.children[0].height, 157.0)
}

///|
test "taffy/grid_absolute_container_bottom_left" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Length(0.0), right: @types.Auto, top: @types.Auto, bottom: @types.Length(0.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 160.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 120.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 120.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_container_bottom_left_margin" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
    margin: { left: @types.Length(4.0), right: @types.Length(2.0), top: @types.Length(1.0), bottom: @types.Length(3.0) },
    inset: { left: @types.Length(0.0), right: @types.Auto, top: @types.Auto, bottom: @types.Length(0.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 4.0)
  assert_approx(layout.children[0].y, 147.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 120.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 120.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_container_left_overrides_right" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(10.0),
    inset: { left: @types.Length(5.0), right: @types.Length(2.0), top: @types.Auto, bottom: @types.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 5.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 120.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 120.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_container_left_right" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Length(5.0), right: @types.Length(2.0), top: @types.Auto, bottom: @types.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 5.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 173.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 120.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 120.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_container_left_right_margin" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    margin: { left: @types.Length(4.0), right: @types.Length(2.0), top: @types.Length(1.0), bottom: @types.Length(3.0) },
    inset: { left: @types.Length(5.0), right: @types.Length(2.0), top: @types.Auto, bottom: @types.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 9.0)
  assert_approx(layout.children[0].y, 1.0)
  assert_approx(layout.children[0].width, 167.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 120.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 120.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_container_negative_position" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Auto, right: @types.Length(-15.0), top: @types.Length(-5.0), bottom: @types.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Length(-35.0), right: @types.Auto, top: @types.Auto, bottom: @types.Length(-25.0) },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 195.0)
  assert_approx(layout.children[0].y, -5.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, -35.0)
  assert_approx(layout.children[1].y, 185.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 40.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 80.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 120.0)
  assert_approx(layout.children[4].y, 10.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 40.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 80.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 120.0)
  assert_approx(layout.children[7].y, 50.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 40.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_container_negative_position_margin" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    margin: { left: @types.Length(4.0), right: @types.Length(2.0), top: @types.Length(1.0), bottom: @types.Length(3.0) },
    inset: { left: @types.Auto, right: @types.Length(-15.0), top: @types.Length(-5.0), bottom: @types.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    margin: { left: @types.Length(4.0), right: @types.Length(2.0), top: @types.Length(1.0), bottom: @types.Length(3.0) },
    inset: { left: @types.Length(-35.0), right: @types.Auto, top: @types.Auto, bottom: @types.Length(-25.0) },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 193.0)
  assert_approx(layout.children[0].y, -4.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, -31.0)
  assert_approx(layout.children[1].y, 182.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 40.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 80.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 120.0)
  assert_approx(layout.children[4].y, 10.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 40.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 80.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 120.0)
  assert_approx(layout.children[7].y, 50.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 40.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_container_top_bottom" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Auto, right: @types.Auto, top: @types.Length(2.0), bottom: @types.Length(5.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 2.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 153.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 120.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 120.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_container_top_bottom_margin" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    margin: { left: @types.Length(4.0), right: @types.Length(2.0), top: @types.Length(1.0), bottom: @types.Length(3.0) },
    inset: { left: @types.Auto, right: @types.Auto, top: @types.Length(2.0), bottom: @types.Length(5.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 4.0)
  assert_approx(layout.children[0].y, 3.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 149.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 120.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 120.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_container_top_right" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Auto, right: @types.Length(0.0), top: @types.Length(0.0), bottom: @types.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 180.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 120.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 120.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_container_top_right_margin" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    margin: { left: @types.Length(4.0), right: @types.Length(2.0), top: @types.Length(1.0), bottom: @types.Length(3.0) },
    inset: { left: @types.Auto, right: @types.Length(0.0), top: @types.Length(0.0), bottom: @types.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 178.0)
  assert_approx(layout.children[0].y, 1.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 120.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 120.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_justify_self_sized_all" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    justify_self: @style.AlignSelf::Start,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    justify_self: @style.AlignSelf::Start,
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    justify_self: @style.AlignSelf::End,
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    justify_self: @style.AlignSelf::End,
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    justify_self: @style.AlignSelf::Center,
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    justify_self: @style.AlignSelf::Center,
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    justify_self: @style.AlignSelf::Stretch,
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    justify_self: @style.AlignSelf::Stretch,
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
  assert_approx(layout.children[2].x, 100.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 20.0)
  assert_approx(layout.children[3].x, 60.0)
  assert_approx(layout.children[3].y, 0.0)
  assert_approx(layout.children[3].width, 60.0)
  assert_approx(layout.children[3].height, 60.0)
  assert_approx(layout.children[4].x, 50.0)
  assert_approx(layout.children[4].y, 0.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 20.0)
  assert_approx(layout.children[5].x, 30.0)
  assert_approx(layout.children[5].y, 0.0)
  assert_approx(layout.children[5].width, 60.0)
  assert_approx(layout.children[5].height, 60.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 0.0)
  assert_approx(layout.children[6].width, 20.0)
  assert_approx(layout.children[6].height, 20.0)
  assert_approx(layout.children[7].x, 0.0)
  assert_approx(layout.children[7].y, 0.0)
  assert_approx(layout.children[7].width, 60.0)
  assert_approx(layout.children[7].height, 60.0)
}

///|
test "taffy/grid_absolute_layout_within_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    padding: { left: @types.Length(10.0), right: @types.Length(10.0), top: @types.Length(10.0), bottom: @types.Length(10.0) },
    border: { left: @types.Length(10.0), right: @types.Length(10.0), top: @types.Length(10.0), bottom: @types.Length(10.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    inset: { left: @types.Length(0.0), right: @types.Auto, top: @types.Length(0.0), bottom: @types.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    inset: { left: @types.Auto, right: @types.Length(0.0), top: @types.Auto, bottom: @types.Length(0.0) },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: { left: @types.Length(10.0), right: @types.Length(10.0), top: @types.Length(10.0), bottom: @types.Length(10.0) },
    inset: { left: @types.Length(0.0), right: @types.Auto, top: @types.Length(0.0), bottom: @types.Auto },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: { left: @types.Length(10.0), right: @types.Length(10.0), top: @types.Length(10.0), bottom: @types.Length(10.0) },
    inset: { left: @types.Auto, right: @types.Length(0.0), top: @types.Auto, bottom: @types.Length(0.0) },
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
  assert_approx(layout.children[2].x, 20.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 50.0)
  assert_approx(layout.children[3].x, 30.0)
  assert_approx(layout.children[3].y, 30.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 50.0)
}

///|
test "taffy/grid_absolute_layout_within_border_static" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    padding: { left: @types.Length(10.0), right: @types.Length(10.0), top: @types.Length(10.0), bottom: @types.Length(10.0) },
    border: { left: @types.Length(10.0), right: @types.Length(10.0), top: @types.Length(10.0), bottom: @types.Length(10.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    align_self: @style.AlignSelf::Start,
    justify_self: @style.AlignSelf::Start,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    align_self: @style.AlignSelf::End,
    justify_self: @style.AlignSelf::End,
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: { left: @types.Length(10.0), right: @types.Length(10.0), top: @types.Length(10.0), bottom: @types.Length(10.0) },
    align_self: @style.AlignSelf::Start,
    justify_self: @style.AlignSelf::Start,
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: { left: @types.Length(10.0), right: @types.Length(10.0), top: @types.Length(10.0), bottom: @types.Length(10.0) },
    align_self: @style.AlignSelf::End,
    justify_self: @style.AlignSelf::End,
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
  assert_approx(layout.children[2].x, 20.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 50.0)
  assert_approx(layout.children[3].x, 30.0)
  assert_approx(layout.children[3].y, 30.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 50.0)
}

///|
test "taffy/grid_absolute_resolved_insets" {
  let root_style = {
    ..@style.Style::default(),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    position: @style.Position::Relative,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(15.0), right: @types.Length(15.0), top: @types.Length(15.0), bottom: @types.Length(15.0) },
    border: { left: @types.Length(20.0), right: @types.Length(20.0), top: @types.Length(20.0), bottom: @types.Length(20.0) },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Auto, right: @types.Auto, top: @types.Auto, bottom: @types.Auto },
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Length(0.0), right: @types.Auto, top: @types.Length(0.0), bottom: @types.Auto },
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Percent(1.0000), right: @types.Auto, top: @types.Percent(1.0000), bottom: @types.Auto },
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Auto, right: @types.Percent(1.0000), top: @types.Auto, bottom: @types.Percent(1.0000) },
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Length(30.0), right: @types.Auto, top: @types.Length(30.0), bottom: @types.Auto },
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Percent(1.0000),
    height: @types.Percent(1.0000),
    inset: { left: @types.Length(0.0), right: @types.Auto, top: @types.Length(0.0), bottom: @types.Auto },
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    position: @style.Position::Relative,
    overflow_x: @style.Overflow::Scroll,
    overflow_y: @style.Overflow::Scroll,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(15.0), right: @types.Length(15.0), top: @types.Length(15.0), bottom: @types.Length(15.0) },
    border: { left: @types.Length(20.0), right: @types.Length(20.0), top: @types.Length(20.0), bottom: @types.Length(20.0) },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Auto, right: @types.Auto, top: @types.Auto, bottom: @types.Auto },
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1_child1_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Length(0.0), right: @types.Auto, top: @types.Length(0.0), bottom: @types.Auto },
  }
  let root_child1_child1 = @node.Node::leaf("node", root_child1_child1_style)
  root_child1_children.push(root_child1_child1)
  let root_child1_child2_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Percent(1.0000), right: @types.Auto, top: @types.Percent(1.0000), bottom: @types.Auto },
  }
  let root_child1_child2 = @node.Node::leaf("node", root_child1_child2_style)
  root_child1_children.push(root_child1_child2)
  let root_child1_child3_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Auto, right: @types.Percent(1.0000), top: @types.Auto, bottom: @types.Percent(1.0000) },
  }
  let root_child1_child3 = @node.Node::leaf("node", root_child1_child3_style)
  root_child1_children.push(root_child1_child3)
  let root_child1_child4_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Length(30.0), right: @types.Auto, top: @types.Length(30.0), bottom: @types.Auto },
  }
  let root_child1_child4 = @node.Node::leaf("node", root_child1_child4_style)
  root_child1_children.push(root_child1_child4)
  let root_child1_child5_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Percent(1.0000),
    height: @types.Percent(1.0000),
    inset: { left: @types.Length(0.0), right: @types.Auto, top: @types.Length(0.0), bottom: @types.Auto },
  }
  let root_child1_child5 = @node.Node::leaf("node", root_child1_child5_style)
  root_child1_children.push(root_child1_child5)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 200.0)
  assert_approx(layout.children[0].height, 200.0)
  assert_approx(layout.children[0].children[0].x, 20.0)
  assert_approx(layout.children[0].children[0].y, 20.0)
  assert_approx(layout.children[0].children[0].width, 0.0)
  assert_approx(layout.children[0].children[0].height, 0.0)
  assert_approx(layout.children[0].children[1].x, 20.0)
  assert_approx(layout.children[0].children[1].y, 20.0)
  assert_approx(layout.children[0].children[1].width, 0.0)
  assert_approx(layout.children[0].children[1].height, 0.0)
  assert_approx(layout.children[0].children[2].x, 180.0)
  assert_approx(layout.children[0].children[2].y, 180.0)
  assert_approx(layout.children[0].children[2].width, 0.0)
  assert_approx(layout.children[0].children[2].height, 0.0)
  assert_approx(layout.children[0].children[3].x, 20.0)
  assert_approx(layout.children[0].children[3].y, 20.0)
  assert_approx(layout.children[0].children[3].width, 0.0)
  assert_approx(layout.children[0].children[3].height, 0.0)
  assert_approx(layout.children[0].children[4].x, 50.0)
  assert_approx(layout.children[0].children[4].y, 50.0)
  assert_approx(layout.children[0].children[4].width, 0.0)
  assert_approx(layout.children[0].children[4].height, 0.0)
  assert_approx(layout.children[0].children[5].x, 20.0)
  assert_approx(layout.children[0].children[5].y, 20.0)
  assert_approx(layout.children[0].children[5].width, 160.0)
  assert_approx(layout.children[0].children[5].height, 160.0)
  assert_approx(layout.children[1].x, 200.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 200.0)
  assert_approx(layout.children[1].height, 200.0)
  assert_approx(layout.children[1].children[0].x, 20.0)
  assert_approx(layout.children[1].children[0].y, 20.0)
  assert_approx(layout.children[1].children[0].width, 0.0)
  assert_approx(layout.children[1].children[0].height, 0.0)
  assert_approx(layout.children[1].children[1].x, 20.0)
  assert_approx(layout.children[1].children[1].y, 20.0)
  assert_approx(layout.children[1].children[1].width, 0.0)
  assert_approx(layout.children[1].children[1].height, 0.0)
  assert_approx(layout.children[1].children[2].x, 180.0)
  assert_approx(layout.children[1].children[2].y, 180.0)
  assert_approx(layout.children[1].children[2].width, 0.0)
  assert_approx(layout.children[1].children[2].height, 0.0)
  assert_approx(layout.children[1].children[3].x, 20.0)
  assert_approx(layout.children[1].children[3].y, 20.0)
  assert_approx(layout.children[1].children[3].width, 0.0)
  assert_approx(layout.children[1].children[3].height, 0.0)
  assert_approx(layout.children[1].children[4].x, 50.0)
  assert_approx(layout.children[1].children[4].y, 50.0)
  assert_approx(layout.children[1].children[4].width, 0.0)
  assert_approx(layout.children[1].children[4].height, 0.0)
  assert_approx(layout.children[1].children[5].x, 20.0)
  assert_approx(layout.children[1].children[5].y, 20.0)
  assert_approx(layout.children[1].children[5].width, 160.0)
  assert_approx(layout.children[1].children[5].height, 160.0)
}

///|
test "taffy/grid_absolute_row_end" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    grid_row: { start: @style.Auto, end: @style.Line(1) },
    inset: { left: @types.Length(4.0), right: @types.Length(3.0), top: @types.Length(1.0), bottom: @types.Length(2.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 4.0)
  assert_approx(layout.children[0].y, 1.0)
  assert_approx(layout.children[0].width, 173.0)
  assert_approx(layout.children[0].height, 7.0)
}

///|
test "taffy/grid_absolute_row_start" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    grid_row: { start: @style.Line(1), end: @style.Auto },
    inset: { left: @types.Length(4.0), right: @types.Length(3.0), top: @types.Length(1.0), bottom: @types.Length(2.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 4.0)
  assert_approx(layout.children[0].y, 11.0)
  assert_approx(layout.children[0].width, 173.0)
  assert_approx(layout.children[0].height, 147.0)
}

///|
test "taffy/grid_absolute_top_overrides_bottom" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    height: @types.Length(10.0),
    inset: { left: @types.Auto, right: @types.Auto, top: @types.Length(2.0), bottom: @types.Length(5.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 2.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 120.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 120.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_with_padding" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Auto, right: @types.Length(0.0), top: @types.Length(0.0), bottom: @types.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Length(10.0), right: @types.Auto, top: @types.Auto, bottom: @types.Length(10.0) },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 180.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, 10.0)
  assert_approx(layout.children[1].y, 150.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 40.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 80.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 120.0)
  assert_approx(layout.children[4].y, 10.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 40.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 80.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 120.0)
  assert_approx(layout.children[7].y, 50.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 40.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_absolute_with_padding_and_margin" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    margin: { left: @types.Length(4.0), right: @types.Length(2.0), top: @types.Length(1.0), bottom: @types.Length(3.0) },
    inset: { left: @types.Auto, right: @types.Length(0.0), top: @types.Length(0.0), bottom: @types.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    margin: { left: @types.Length(4.0), right: @types.Length(2.0), top: @types.Length(1.0), bottom: @types.Length(3.0) },
    inset: { left: @types.Length(10.0), right: @types.Auto, top: @types.Auto, bottom: @types.Length(10.0) },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 178.0)
  assert_approx(layout.children[0].y, 1.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, 14.0)
  assert_approx(layout.children[1].y, 147.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 40.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 80.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 120.0)
  assert_approx(layout.children[4].y, 10.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 40.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 80.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 120.0)
  assert_approx(layout.children[7].y, 50.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 40.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_center" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_content: @style.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 40.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 80.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 80.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 120.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 120.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 120.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_center_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.Center,
    align_content: @style.Center,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, 20.0)
  assert_approx(layout.children[0].children[0].y, -10.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 40.0)
  assert_approx(layout.children[0].children[1].x, 50.0)
  assert_approx(layout.children[0].children[1].y, -10.0)
  assert_approx(layout.children[0].children[1].width, 20.0)
  assert_approx(layout.children[0].children[1].height, 40.0)
  assert_approx(layout.children[0].children[2].x, 80.0)
  assert_approx(layout.children[0].children[2].y, -10.0)
  assert_approx(layout.children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[2].height, 40.0)
  assert_approx(layout.children[0].children[3].x, 20.0)
  assert_approx(layout.children[0].children[3].y, 40.0)
  assert_approx(layout.children[0].children[3].width, 20.0)
  assert_approx(layout.children[0].children[3].height, 40.0)
  assert_approx(layout.children[0].children[4].x, 50.0)
  assert_approx(layout.children[0].children[4].y, 40.0)
  assert_approx(layout.children[0].children[4].width, 20.0)
  assert_approx(layout.children[0].children[4].height, 40.0)
  assert_approx(layout.children[0].children[5].x, 80.0)
  assert_approx(layout.children[0].children[5].y, 40.0)
  assert_approx(layout.children[0].children[5].width, 20.0)
  assert_approx(layout.children[0].children[5].height, 40.0)
  assert_approx(layout.children[0].children[6].x, 20.0)
  assert_approx(layout.children[0].children[6].y, 90.0)
  assert_approx(layout.children[0].children[6].width, 20.0)
  assert_approx(layout.children[0].children[6].height, 40.0)
  assert_approx(layout.children[0].children[7].x, 50.0)
  assert_approx(layout.children[0].children[7].y, 90.0)
  assert_approx(layout.children[0].children[7].width, 20.0)
  assert_approx(layout.children[0].children[7].height, 40.0)
  assert_approx(layout.children[0].children[8].x, 80.0)
  assert_approx(layout.children[0].children[8].y, 90.0)
  assert_approx(layout.children[0].children[8].width, 20.0)
  assert_approx(layout.children[0].children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_end" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_content: @style.End,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 80.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 80.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 80.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 120.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 120.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 120.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 160.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 160.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 160.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_end_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.Center,
    align_content: @style.End,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, 20.0)
  assert_approx(layout.children[0].children[0].y, -20.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 40.0)
  assert_approx(layout.children[0].children[1].x, 50.0)
  assert_approx(layout.children[0].children[1].y, -20.0)
  assert_approx(layout.children[0].children[1].width, 20.0)
  assert_approx(layout.children[0].children[1].height, 40.0)
  assert_approx(layout.children[0].children[2].x, 80.0)
  assert_approx(layout.children[0].children[2].y, -20.0)
  assert_approx(layout.children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[2].height, 40.0)
  assert_approx(layout.children[0].children[3].x, 20.0)
  assert_approx(layout.children[0].children[3].y, 30.0)
  assert_approx(layout.children[0].children[3].width, 20.0)
  assert_approx(layout.children[0].children[3].height, 40.0)
  assert_approx(layout.children[0].children[4].x, 50.0)
  assert_approx(layout.children[0].children[4].y, 30.0)
  assert_approx(layout.children[0].children[4].width, 20.0)
  assert_approx(layout.children[0].children[4].height, 40.0)
  assert_approx(layout.children[0].children[5].x, 80.0)
  assert_approx(layout.children[0].children[5].y, 30.0)
  assert_approx(layout.children[0].children[5].width, 20.0)
  assert_approx(layout.children[0].children[5].height, 40.0)
  assert_approx(layout.children[0].children[6].x, 20.0)
  assert_approx(layout.children[0].children[6].y, 80.0)
  assert_approx(layout.children[0].children[6].width, 20.0)
  assert_approx(layout.children[0].children[6].height, 40.0)
  assert_approx(layout.children[0].children[7].x, 50.0)
  assert_approx(layout.children[0].children[7].y, 80.0)
  assert_approx(layout.children[0].children[7].width, 20.0)
  assert_approx(layout.children[0].children[7].height, 40.0)
  assert_approx(layout.children[0].children[8].x, 80.0)
  assert_approx(layout.children[0].children[8].y, 80.0)
  assert_approx(layout.children[0].children[8].width, 20.0)
  assert_approx(layout.children[0].children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_end_with_padding_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    border: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_content: @style.End,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 48.0)
  assert_approx(layout.children[0].y, 44.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 88.0)
  assert_approx(layout.children[1].y, 44.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 128.0)
  assert_approx(layout.children[2].y, 44.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 48.0)
  assert_approx(layout.children[3].y, 84.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 88.0)
  assert_approx(layout.children[4].y, 84.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 128.0)
  assert_approx(layout.children[5].y, 84.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 48.0)
  assert_approx(layout.children[6].y, 124.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 88.0)
  assert_approx(layout.children[7].y, 124.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 128.0)
  assert_approx(layout.children[8].y, 124.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_space_around" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_content: @style.SpaceAround,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 13.3)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 13.3)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 13.3)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 80.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 80.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 146.7)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 146.7)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 146.7)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_space_around_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.Center,
    align_content: @style.SpaceAround,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, 20.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 40.0)
  assert_approx(layout.children[0].children[1].x, 50.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 20.0)
  assert_approx(layout.children[0].children[1].height, 40.0)
  assert_approx(layout.children[0].children[2].x, 80.0)
  assert_approx(layout.children[0].children[2].y, 0.0)
  assert_approx(layout.children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[2].height, 40.0)
  assert_approx(layout.children[0].children[3].x, 20.0)
  assert_approx(layout.children[0].children[3].y, 50.0)
  assert_approx(layout.children[0].children[3].width, 20.0)
  assert_approx(layout.children[0].children[3].height, 40.0)
  assert_approx(layout.children[0].children[4].x, 50.0)
  assert_approx(layout.children[0].children[4].y, 50.0)
  assert_approx(layout.children[0].children[4].width, 20.0)
  assert_approx(layout.children[0].children[4].height, 40.0)
  assert_approx(layout.children[0].children[5].x, 80.0)
  assert_approx(layout.children[0].children[5].y, 50.0)
  assert_approx(layout.children[0].children[5].width, 20.0)
  assert_approx(layout.children[0].children[5].height, 40.0)
  assert_approx(layout.children[0].children[6].x, 20.0)
  assert_approx(layout.children[0].children[6].y, 100.0)
  assert_approx(layout.children[0].children[6].width, 20.0)
  assert_approx(layout.children[0].children[6].height, 40.0)
  assert_approx(layout.children[0].children[7].x, 50.0)
  assert_approx(layout.children[0].children[7].y, 100.0)
  assert_approx(layout.children[0].children[7].width, 20.0)
  assert_approx(layout.children[0].children[7].height, 40.0)
  assert_approx(layout.children[0].children[8].x, 80.0)
  assert_approx(layout.children[0].children[8].y, 100.0)
  assert_approx(layout.children[0].children[8].width, 20.0)
  assert_approx(layout.children[0].children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_space_around_with_padding_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    border: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_content: @style.SpaceAround,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 48.0)
  assert_approx(layout.children[0].y, 17.3)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 88.0)
  assert_approx(layout.children[1].y, 17.3)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 128.0)
  assert_approx(layout.children[2].y, 17.3)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 48.0)
  assert_approx(layout.children[3].y, 68.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 88.0)
  assert_approx(layout.children[4].y, 68.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 128.0)
  assert_approx(layout.children[5].y, 68.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 48.0)
  assert_approx(layout.children[6].y, 118.7)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 88.0)
  assert_approx(layout.children[7].y, 118.7)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 128.0)
  assert_approx(layout.children[8].y, 118.7)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_space_between" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_content: @style.SpaceBetween,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 80.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 80.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 160.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 160.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 160.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_space_between_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.Center,
    align_content: @style.SpaceBetween,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, 20.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 40.0)
  assert_approx(layout.children[0].children[1].x, 50.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 20.0)
  assert_approx(layout.children[0].children[1].height, 40.0)
  assert_approx(layout.children[0].children[2].x, 80.0)
  assert_approx(layout.children[0].children[2].y, 0.0)
  assert_approx(layout.children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[2].height, 40.0)
  assert_approx(layout.children[0].children[3].x, 20.0)
  assert_approx(layout.children[0].children[3].y, 50.0)
  assert_approx(layout.children[0].children[3].width, 20.0)
  assert_approx(layout.children[0].children[3].height, 40.0)
  assert_approx(layout.children[0].children[4].x, 50.0)
  assert_approx(layout.children[0].children[4].y, 50.0)
  assert_approx(layout.children[0].children[4].width, 20.0)
  assert_approx(layout.children[0].children[4].height, 40.0)
  assert_approx(layout.children[0].children[5].x, 80.0)
  assert_approx(layout.children[0].children[5].y, 50.0)
  assert_approx(layout.children[0].children[5].width, 20.0)
  assert_approx(layout.children[0].children[5].height, 40.0)
  assert_approx(layout.children[0].children[6].x, 20.0)
  assert_approx(layout.children[0].children[6].y, 100.0)
  assert_approx(layout.children[0].children[6].width, 20.0)
  assert_approx(layout.children[0].children[6].height, 40.0)
  assert_approx(layout.children[0].children[7].x, 50.0)
  assert_approx(layout.children[0].children[7].y, 100.0)
  assert_approx(layout.children[0].children[7].width, 20.0)
  assert_approx(layout.children[0].children[7].height, 40.0)
  assert_approx(layout.children[0].children[8].x, 80.0)
  assert_approx(layout.children[0].children[8].y, 100.0)
  assert_approx(layout.children[0].children[8].width, 20.0)
  assert_approx(layout.children[0].children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_space_between_with_padding_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    border: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_content: @style.SpaceBetween,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 48.0)
  assert_approx(layout.children[0].y, 12.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 88.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 128.0)
  assert_approx(layout.children[2].y, 12.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 48.0)
  assert_approx(layout.children[3].y, 68.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 88.0)
  assert_approx(layout.children[4].y, 68.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 128.0)
  assert_approx(layout.children[5].y, 68.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 48.0)
  assert_approx(layout.children[6].y, 124.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 88.0)
  assert_approx(layout.children[7].y, 124.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 128.0)
  assert_approx(layout.children[8].y, 124.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_space_evenly" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_content: @style.SpaceEvenly,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 20.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 80.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 80.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 140.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 140.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 140.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_space_evenly_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.Center,
    align_content: @style.SpaceBetween,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, 20.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 40.0)
  assert_approx(layout.children[0].children[1].x, 50.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 20.0)
  assert_approx(layout.children[0].children[1].height, 40.0)
  assert_approx(layout.children[0].children[2].x, 80.0)
  assert_approx(layout.children[0].children[2].y, 0.0)
  assert_approx(layout.children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[2].height, 40.0)
  assert_approx(layout.children[0].children[3].x, 20.0)
  assert_approx(layout.children[0].children[3].y, 50.0)
  assert_approx(layout.children[0].children[3].width, 20.0)
  assert_approx(layout.children[0].children[3].height, 40.0)
  assert_approx(layout.children[0].children[4].x, 50.0)
  assert_approx(layout.children[0].children[4].y, 50.0)
  assert_approx(layout.children[0].children[4].width, 20.0)
  assert_approx(layout.children[0].children[4].height, 40.0)
  assert_approx(layout.children[0].children[5].x, 80.0)
  assert_approx(layout.children[0].children[5].y, 50.0)
  assert_approx(layout.children[0].children[5].width, 20.0)
  assert_approx(layout.children[0].children[5].height, 40.0)
  assert_approx(layout.children[0].children[6].x, 20.0)
  assert_approx(layout.children[0].children[6].y, 100.0)
  assert_approx(layout.children[0].children[6].width, 20.0)
  assert_approx(layout.children[0].children[6].height, 40.0)
  assert_approx(layout.children[0].children[7].x, 50.0)
  assert_approx(layout.children[0].children[7].y, 100.0)
  assert_approx(layout.children[0].children[7].width, 20.0)
  assert_approx(layout.children[0].children[7].height, 40.0)
  assert_approx(layout.children[0].children[8].x, 80.0)
  assert_approx(layout.children[0].children[8].y, 100.0)
  assert_approx(layout.children[0].children[8].width, 20.0)
  assert_approx(layout.children[0].children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_space_evenly_with_padding_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    border: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_content: @style.SpaceEvenly,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 48.0)
  assert_approx(layout.children[0].y, 20.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 88.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 128.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 48.0)
  assert_approx(layout.children[3].y, 68.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 88.0)
  assert_approx(layout.children[4].y, 68.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 128.0)
  assert_approx(layout.children[5].y, 68.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 48.0)
  assert_approx(layout.children[6].y, 116.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 88.0)
  assert_approx(layout.children[7].y, 116.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 128.0)
  assert_approx(layout.children[8].y, 116.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_start" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_content: @style.Start,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_start_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.Center,
    align_content: @style.Start,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, 20.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 40.0)
  assert_approx(layout.children[0].children[1].x, 50.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 20.0)
  assert_approx(layout.children[0].children[1].height, 40.0)
  assert_approx(layout.children[0].children[2].x, 80.0)
  assert_approx(layout.children[0].children[2].y, 0.0)
  assert_approx(layout.children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[2].height, 40.0)
  assert_approx(layout.children[0].children[3].x, 20.0)
  assert_approx(layout.children[0].children[3].y, 50.0)
  assert_approx(layout.children[0].children[3].width, 20.0)
  assert_approx(layout.children[0].children[3].height, 40.0)
  assert_approx(layout.children[0].children[4].x, 50.0)
  assert_approx(layout.children[0].children[4].y, 50.0)
  assert_approx(layout.children[0].children[4].width, 20.0)
  assert_approx(layout.children[0].children[4].height, 40.0)
  assert_approx(layout.children[0].children[5].x, 80.0)
  assert_approx(layout.children[0].children[5].y, 50.0)
  assert_approx(layout.children[0].children[5].width, 20.0)
  assert_approx(layout.children[0].children[5].height, 40.0)
  assert_approx(layout.children[0].children[6].x, 20.0)
  assert_approx(layout.children[0].children[6].y, 100.0)
  assert_approx(layout.children[0].children[6].width, 20.0)
  assert_approx(layout.children[0].children[6].height, 40.0)
  assert_approx(layout.children[0].children[7].x, 50.0)
  assert_approx(layout.children[0].children[7].y, 100.0)
  assert_approx(layout.children[0].children[7].width, 20.0)
  assert_approx(layout.children[0].children[7].height, 40.0)
  assert_approx(layout.children[0].children[8].x, 80.0)
  assert_approx(layout.children[0].children[8].y, 100.0)
  assert_approx(layout.children[0].children[8].width, 20.0)
  assert_approx(layout.children[0].children[8].height, 40.0)
}

///|
test "taffy/grid_align_content_start_with_padding_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    border: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_content: @style.Start,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 48.0)
  assert_approx(layout.children[0].y, 12.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 88.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 128.0)
  assert_approx(layout.children[2].y, 12.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 48.0)
  assert_approx(layout.children[3].y, 52.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 88.0)
  assert_approx(layout.children[4].y, 52.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 128.0)
  assert_approx(layout.children[5].y, 52.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 48.0)
  assert_approx(layout.children[6].y, 92.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 88.0)
  assert_approx(layout.children[7].y, 92.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 128.0)
  assert_approx(layout.children[8].y, 92.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_align_items_baseline" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 65.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
}

///|
test "taffy/grid_align_items_baseline_child" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 65.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/grid_align_items_baseline_child_margin" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: { left: @types.Length(5.0), right: @types.Length(5.0), top: @types.Length(5.0), bottom: @types.Length(5.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
    margin: { left: @types.Length(5.0), right: @types.Length(5.0), top: @types.Length(5.0), bottom: @types.Length(5.0) },
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 5.0)
  assert_approx(layout.children[0].y, 5.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 70.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 5.0)
  assert_approx(layout.children[1].children[0].y, 5.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/grid_align_items_baseline_child_margin_percent" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: { left: @types.Percent(0.0500), right: @types.Percent(0.0500), top: @types.Percent(0.0500), bottom: @types.Percent(0.0500) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
    margin: { left: @types.Percent(0.0100), right: @types.Percent(0.0100), top: @types.Percent(0.0100), bottom: @types.Percent(0.0100) },
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 5.0)
  assert_approx(layout.children[0].y, 5.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 70.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.5)
  assert_approx(layout.children[1].children[0].y, 0.5)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/grid_align_items_baseline_child_multiline" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(60.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    grid_template_columns: [@style.Auto, @style.Auto],
    flex_wrap: @style.Wrap,
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(20.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(10.0),
  }
  let root_child1_child1 = @node.Node::leaf("node", root_child1_child1_style)
  root_child1_children.push(root_child1_child1)
  let root_child1_child2_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(20.0),
  }
  let root_child1_child2 = @node.Node::leaf("node", root_child1_child2_style)
  root_child1_children.push(root_child1_child2)
  let root_child1_child3_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(10.0),
  }
  let root_child1_child3 = @node.Node::leaf("node", root_child1_child3_style)
  root_child1_children.push(root_child1_child3)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 60.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 60.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 25.0)
  assert_approx(layout.children[1].children[0].height, 20.0)
  assert_approx(layout.children[1].children[1].x, 25.0)
  assert_approx(layout.children[1].children[1].y, 0.0)
  assert_approx(layout.children[1].children[1].width, 25.0)
  assert_approx(layout.children[1].children[1].height, 10.0)
  assert_approx(layout.children[1].children[2].x, 0.0)
  assert_approx(layout.children[1].children[2].y, 20.0)
  assert_approx(layout.children[1].children[2].width, 25.0)
  assert_approx(layout.children[1].children[2].height, 20.0)
  assert_approx(layout.children[1].children[3].x, 25.0)
  assert_approx(layout.children[1].children[3].y, 20.0)
  assert_approx(layout.children[1].children[3].width, 25.0)
  assert_approx(layout.children[1].children[3].height, 10.0)
}

///|
test "taffy/grid_align_items_baseline_child_multiline_no_override_on_secondline" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(60.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(25.0),
    grid_template_columns: [@style.Auto, @style.Auto],
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(20.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(10.0),
  }
  let root_child1_child1 = @node.Node::leaf("node", root_child1_child1_style)
  root_child1_children.push(root_child1_child1)
  let root_child1_child2_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(20.0),
  }
  let root_child1_child2 = @node.Node::leaf("node", root_child1_child2_style)
  root_child1_children.push(root_child1_child2)
  let root_child1_child3_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(10.0),
    align_self: @style.AlignSelf::Auto,
  }
  let root_child1_child3 = @node.Node::leaf("node", root_child1_child3_style)
  root_child1_children.push(root_child1_child3)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 60.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 67.5)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 25.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 25.0)
  assert_approx(layout.children[1].children[0].height, 20.0)
  assert_approx(layout.children[1].children[1].x, 25.0)
  assert_approx(layout.children[1].children[1].y, 0.0)
  assert_approx(layout.children[1].children[1].width, 25.0)
  assert_approx(layout.children[1].children[1].height, 10.0)
  assert_approx(layout.children[1].children[2].x, 0.0)
  assert_approx(layout.children[1].children[2].y, 20.0)
  assert_approx(layout.children[1].children[2].width, 25.0)
  assert_approx(layout.children[1].children[2].height, 20.0)
  assert_approx(layout.children[1].children[3].x, 25.0)
  assert_approx(layout.children[1].children[3].y, 20.0)
  assert_approx(layout.children[1].children[3].width, 25.0)
  assert_approx(layout.children[1].children[3].height, 10.0)
}

///|
test "taffy/grid_align_items_baseline_child_multiline_override" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(60.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(25.0),
    grid_template_columns: [@style.Auto, @style.Auto],
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(20.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(10.0),
    align_self: @style.AlignSelf::Auto,
  }
  let root_child1_child1 = @node.Node::leaf("node", root_child1_child1_style)
  root_child1_children.push(root_child1_child1)
  let root_child1_child2_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(20.0),
  }
  let root_child1_child2 = @node.Node::leaf("node", root_child1_child2_style)
  root_child1_children.push(root_child1_child2)
  let root_child1_child3_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(25.0),
    height: @types.Length(10.0),
    align_self: @style.AlignSelf::Auto,
  }
  let root_child1_child3 = @node.Node::leaf("node", root_child1_child3_style)
  root_child1_children.push(root_child1_child3)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 60.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 67.5)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 25.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 25.0)
  assert_approx(layout.children[1].children[0].height, 20.0)
  assert_approx(layout.children[1].children[1].x, 25.0)
  assert_approx(layout.children[1].children[1].y, 0.0)
  assert_approx(layout.children[1].children[1].width, 25.0)
  assert_approx(layout.children[1].children[1].height, 10.0)
  assert_approx(layout.children[1].children[2].x, 0.0)
  assert_approx(layout.children[1].children[2].y, 20.0)
  assert_approx(layout.children[1].children[2].width, 25.0)
  assert_approx(layout.children[1].children[2].height, 20.0)
  assert_approx(layout.children[1].children[3].x, 25.0)
  assert_approx(layout.children[1].children[3].y, 20.0)
  assert_approx(layout.children[1].children[3].width, 25.0)
  assert_approx(layout.children[1].children[3].height, 10.0)
}

///|
test "taffy/grid_align_items_baseline_child_padding" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    padding: { left: @types.Length(5.0), right: @types.Length(5.0), top: @types.Length(5.0), bottom: @types.Length(5.0) },
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
    padding: { left: @types.Length(5.0), right: @types.Length(5.0), top: @types.Length(5.0), bottom: @types.Length(5.0) },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 5.0)
  assert_approx(layout.children[0].y, 5.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 5.0)
  assert_approx(layout.children[1].y, 65.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 5.0)
  assert_approx(layout.children[1].children[0].y, 5.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/grid_align_items_baseline_child_top" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    inset: { left: @types.Auto, right: @types.Auto, top: @types.Length(10.0), bottom: @types.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 65.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/grid_align_items_baseline_child_top2" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
    inset: { left: @types.Auto, right: @types.Auto, top: @types.Length(5.0), bottom: @types.Auto },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 70.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/grid_align_items_baseline_complex" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child2_children : Array[@node.Node] = []
  let root_child2_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child2_child0 = @node.Node::leaf("node", root_child2_child0_style)
  root_child2_children.push(root_child2_child0)
  let root_child2 = @node.Node::new("node", root_child2_style, root_child2_children)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child6_children : Array[@node.Node] = []
  let root_child6_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child6_child0 = @node.Node::leaf("node", root_child6_child0_style)
  root_child6_children.push(root_child6_child0)
  let root_child6 = @node.Node::new("node", root_child6_style, root_child6_children)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child7_children : Array[@node.Node] = []
  let root_child7_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(5.0),
  }
  let root_child7_child0 = @node.Node::leaf("node", root_child7_child0_style)
  root_child7_children.push(root_child7_child0)
  let root_child7 = @node.Node::new("node", root_child7_style, root_child7_children)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 0.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 20.0)
  assert_approx(layout.children[2].children[0].x, 0.0)
  assert_approx(layout.children[2].children[0].y, 0.0)
  assert_approx(layout.children[2].children[0].width, 0.0)
  assert_approx(layout.children[2].children[0].height, 10.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 20.0)
  assert_approx(layout.children[3].height, 20.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 20.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 20.0)
  assert_approx(layout.children[5].height, 20.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 90.0)
  assert_approx(layout.children[6].width, 20.0)
  assert_approx(layout.children[6].height, 20.0)
  assert_approx(layout.children[6].children[0].x, 0.0)
  assert_approx(layout.children[6].children[0].y, 0.0)
  assert_approx(layout.children[6].children[0].width, 0.0)
  assert_approx(layout.children[6].children[0].height, 10.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 95.0)
  assert_approx(layout.children[7].width, 20.0)
  assert_approx(layout.children[7].height, 20.0)
  assert_approx(layout.children[7].children[0].x, 0.0)
  assert_approx(layout.children[7].children[0].y, 0.0)
  assert_approx(layout.children[7].children[0].width, 0.0)
  assert_approx(layout.children[7].children[0].height, 5.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 20.0)
  assert_approx(layout.children[8].height, 20.0)
}

///|
test "taffy/grid_align_items_baseline_double_nested_child" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(15.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 65.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 15.0)
}

///|
test "taffy/grid_align_items_baseline_multiline" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    grid_template_columns: [@style.Auto, @style.Auto],
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child2_children : Array[@node.Node] = []
  let root_child2_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child2_child0 = @node.Node::leaf("node", root_child2_child0_style)
  root_child2_children.push(root_child2_child0)
  let root_child2 = @node.Node::new("node", root_child2_style, root_child2_children)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 50.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 100.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 20.0)
  assert_approx(layout.children[2].children[0].x, 0.0)
  assert_approx(layout.children[2].children[0].y, 0.0)
  assert_approx(layout.children[2].children[0].width, 50.0)
  assert_approx(layout.children[2].children[0].height, 10.0)
  assert_approx(layout.children[3].x, 50.0)
  assert_approx(layout.children[3].y, 60.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 50.0)
}

///|
test "taffy/grid_align_items_baseline_multiline_column" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    grid_template_columns: [@style.Auto, @style.Auto],
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(30.0),
    height: @types.Length(50.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(40.0),
    height: @types.Length(70.0),
  }
  let root_child2_children : Array[@node.Node] = []
  let root_child2_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  }
  let root_child2_child0 = @node.Node::leaf("node", root_child2_child0_style)
  root_child2_children.push(root_child2_child0)
  let root_child2 = @node.Node::new("node", root_child2_style, root_child2_children)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 50.0)
  assert_approx(layout.children[1].y, 30.0)
  assert_approx(layout.children[1].width, 30.0)
  assert_approx(layout.children[1].height, 50.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 20.0)
  assert_approx(layout.children[1].children[0].height, 20.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 90.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 70.0)
  assert_approx(layout.children[2].children[0].x, 0.0)
  assert_approx(layout.children[2].children[0].y, 0.0)
  assert_approx(layout.children[2].children[0].width, 10.0)
  assert_approx(layout.children[2].children[0].height, 10.0)
  assert_approx(layout.children[3].x, 50.0)
  assert_approx(layout.children[3].y, 80.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 20.0)
}

///|
test "taffy/grid_align_items_baseline_multiline_row_and_column" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    grid_template_columns: [@style.Auto, @style.Auto],
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child2_children : Array[@node.Node] = []
  let root_child2_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child2_child0 = @node.Node::leaf("node", root_child2_child0_style)
  root_child2_children.push(root_child2_child0)
  let root_child2 = @node.Node::new("node", root_child2_style, root_child2_children)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 50.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 100.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 20.0)
  assert_approx(layout.children[2].children[0].x, 0.0)
  assert_approx(layout.children[2].children[0].y, 0.0)
  assert_approx(layout.children[2].children[0].width, 50.0)
  assert_approx(layout.children[2].children[0].height, 10.0)
  assert_approx(layout.children[3].x, 50.0)
  assert_approx(layout.children[3].y, 90.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 20.0)
}

///|
test "taffy/grid_align_items_baseline_nested_column" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @style.Baseline,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(60.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(80.0),
  }
  let root_child1_child0_children : Array[@node.Node] = []
  let root_child1_child0_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(30.0),
  }
  let root_child1_child0_child0 = @node.Node::leaf("node", root_child1_child0_child0_style)
  root_child1_child0_children.push(root_child1_child0_child0)
  let root_child1_child0_child1_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(40.0),
  }
  let root_child1_child0_child1 = @node.Node::leaf("node", root_child1_child0_child1_style)
  root_child1_child0_children.push(root_child1_child0_child1)
  let root_child1_child0 = @node.Node::new("node", root_child1_child0_style, root_child1_child0_children)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new("node", root_child1_style, root_child1_children)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 60.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 60.0)
  assert_approx(layout.children[1].width, 100.0)
  assert_approx(layout.children[1].height, 80.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 80.0)
  assert_approx(layout.children[1].children[0].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].children[0].height, 30.0)
  assert_approx(layout.children[1].children[0].children[1].x, 0.0)
  assert_approx(layout.children[1].children[0].children[1].y, 35.0)
  assert_approx(layout.children[1].children[0].children[1].width, 50.0)
  assert_approx(layout.children[1].children[0].children[1].height, 40.0)
}

///|
test "taffy/grid_align_items_sized_center" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_items: @style.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    grid_column: { start: @style.Line(3), end: @style.Auto },
    grid_row: { start: @style.Line(3), end: @style.Auto },
    grid_area: Some("3 / 3"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 70.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
}

///|
test "taffy/grid_align_items_sized_end" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_items: @style.End,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    grid_column: { start: @style.Line(3), end: @style.Auto },
    grid_row: { start: @style.Line(3), end: @style.Auto },
    grid_area: Some("3 / 3"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 20.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 60.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
}

///|
test "taffy/grid_align_items_sized_start" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_items: @style.Start,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    grid_column: { start: @style.Line(3), end: @style.Auto },
    grid_row: { start: @style.Line(3), end: @style.Auto },
    grid_area: Some("3 / 3"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 80.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
}

///|
test "taffy/grid_align_items_sized_stretch" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    align_items: @style.Stretch,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    grid_column: { start: @style.Line(3), end: @style.Auto },
    grid_row: { start: @style.Line(3), end: @style.Auto },
    grid_area: Some("3 / 3"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 80.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
}

///|
test "taffy/grid_align_self_sized_all" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    align_self: @style.AlignSelf::Start,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    align_self: @style.AlignSelf::Start,
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    align_self: @style.AlignSelf::End,
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    align_self: @style.AlignSelf::End,
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    align_self: @style.AlignSelf::Center,
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    align_self: @style.AlignSelf::Center,
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    align_self: @style.AlignSelf::Stretch,
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    align_self: @style.AlignSelf::Stretch,
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 20.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 20.0)
  assert_approx(layout.children[3].width, 60.0)
  assert_approx(layout.children[3].height, 60.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 20.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 30.0)
  assert_approx(layout.children[5].width, 60.0)
  assert_approx(layout.children[5].height, 60.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 20.0)
  assert_approx(layout.children[6].height, 20.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 60.0)
  assert_approx(layout.children[7].height, 60.0)
}

///|
test "taffy/grid_aspect_ratio_absolute_aspect_ratio_overrides_height_of_full_inset" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Percent(0.0500), right: @types.Percent(0.0500), top: @types.Percent(0.0500), bottom: @types.Percent(0.0500) },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 20.0)
  assert_approx(layout.children[0].y, 15.0)
  assert_approx(layout.children[0].width, 360.0)
  assert_approx(layout.children[0].height, 120.0)
}

///|
test "taffy/grid_aspect_ratio_absolute_fill_height_from_inset" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Percent(0.1000), right: @types.Percent(0.1000), top: @types.Percent(0.0500), bottom: @types.Auto },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 40.0)
  assert_approx(layout.children[0].y, 15.0)
  assert_approx(layout.children[0].width, 320.0)
  assert_approx(layout.children[0].height, 106.7)
}

///|
test "taffy/grid_aspect_ratio_absolute_fill_width_from_inset" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    inset: { left: @types.Auto, right: @types.Auto, top: @types.Percent(0.3000), bottom: @types.Percent(0.5000) },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 90.0)
  assert_approx(layout.children[0].width, 180.0)
  assert_approx(layout.children[0].height, 60.0)
}

///|
test "taffy/grid_aspect_ratio_absolute_height_overrides_inset" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    height: @types.Percent(0.1000),
    inset: { left: @types.Auto, right: @types.Auto, top: @types.Percent(0.3000), bottom: @types.Percent(0.5000) },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 90.0)
  assert_approx(layout.children[0].width, 90.0)
  assert_approx(layout.children[0].height, 30.0)
}

///|
test "taffy/grid_aspect_ratio_absolute_width_overrides_inset" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @style.Position::Absolute,
    width: @types.Percent(0.4000),
    inset: { left: @types.Percent(0.1000), right: @types.Percent(0.1000), top: @types.Percent(0.0500), bottom: @types.Auto },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 40.0)
  assert_approx(layout.children[0].y, 15.0)
  assert_approx(layout.children[0].width, 160.0)
  assert_approx(layout.children[0].height, 53.3)
}

///|
test "taffy/grid_aspect_ratio_child_fill_content_height" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    aspect_ratio: Some(0.5000),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 40.0, min_height: 80.0, max_height: 80.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(20.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 80.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 80.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 20.0)
}

///|
test "taffy/grid_aspect_ratio_child_fill_content_width" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    aspect_ratio: Some(2.0000),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 40.0, min_height: 20.0, max_height: 20.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(20.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 20.0)
}

///|
test "taffy/grid_aspect_ratio_fill_child_height" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 25.0)
}

///|
test "taffy/grid_aspect_ratio_fill_child_max_height" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    max_width: @types.Length(40.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 240.0, max_width: 240.0, min_height: 120.0, max_height: 120.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 20.0)
}

///|
test "taffy/grid_aspect_ratio_fill_child_max_width" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    max_height: @types.Length(20.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 40.0, max_height: 40.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 20.0)
}

///|
test "taffy/grid_aspect_ratio_fill_child_min_height" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    min_width: @types.Length(50.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/grid_aspect_ratio_fill_child_width" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(50.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/grid_aspect_ratio_overridden_by_explicit_sizes" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/grid_aspect_ratio_overridden_by_explicit_sizes_flex" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/grid_auto_columns" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0)],
    grid_template_rows: [@style.Length(100.0)],
    grid_auto_columns: [@style.Length(10.0), @style.Length(20.0), @style.Length(30.0)],
    grid_auto_flow: @style.GridAutoFlow::Column,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(-3), end: @style.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 190.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 30.0)
  assert_approx(layout.children[0].height, 100.0)
  assert_approx(layout.children[1].x, 30.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 100.0)
  assert_approx(layout.children[2].x, 70.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 10.0)
  assert_approx(layout.children[2].height, 100.0)
  assert_approx(layout.children[3].x, 80.0)
  assert_approx(layout.children[3].y, 0.0)
  assert_approx(layout.children[3].width, 20.0)
  assert_approx(layout.children[3].height, 100.0)
  assert_approx(layout.children[4].x, 100.0)
  assert_approx(layout.children[4].y, 0.0)
  assert_approx(layout.children[4].width, 30.0)
  assert_approx(layout.children[4].height, 100.0)
  assert_approx(layout.children[5].x, 130.0)
  assert_approx(layout.children[5].y, 0.0)
  assert_approx(layout.children[5].width, 10.0)
  assert_approx(layout.children[5].height, 100.0)
  assert_approx(layout.children[6].x, 140.0)
  assert_approx(layout.children[6].y, 0.0)
  assert_approx(layout.children[6].width, 20.0)
  assert_approx(layout.children[6].height, 100.0)
  assert_approx(layout.children[7].x, 160.0)
  assert_approx(layout.children[7].y, 0.0)
  assert_approx(layout.children[7].width, 30.0)
  assert_approx(layout.children[7].height, 100.0)
}

///|
test "taffy/grid_auto_columns_fixed_width" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Auto, @style.Length(40.0), @style.Auto],
    grid_template_rows: [@style.Length(40.0), @style.Auto, @style.Length(40.0), @style.Auto],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root_child9_style = {
    ..@style.Style::default(),
  }
  let root_child9 = @node.Node::leaf("node", root_child9_style)
  root_children.push(root_child9)
  let root_child10_style = {
    ..@style.Style::default(),
  }
  let root_child10 = @node.Node::leaf("node", root_child10_style)
  root_children.push(root_child10)
  let root_child11_style = {
    ..@style.Style::default(),
  }
  let root_child11 = @node.Node::leaf("node", root_child11_style)
  root_children.push(root_child11)
  let root_child12_style = {
    ..@style.Style::default(),
  }
  let root_child12 = @node.Node::leaf("node", root_child12_style)
  root_children.push(root_child12)
  let root_child13_style = {
    ..@style.Style::default(),
  }
  let root_child13 = @node.Node::leaf("node", root_child13_style)
  root_children.push(root_child13)
  let root_child14_style = {
    ..@style.Style::default(),
  }
  let root_child14 = @node.Node::leaf("node", root_child14_style)
  root_children.push(root_child14)
  let root_child15_style = {
    ..@style.Style::default(),
  }
  let root_child15 = @node.Node::leaf("node", root_child15_style)
  root_children.push(root_child15)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 100.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 140.0)
  assert_approx(layout.children[3].y, 0.0)
  assert_approx(layout.children[3].width, 60.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 0.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 60.0)
  assert_approx(layout.children[5].x, 40.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 60.0)
  assert_approx(layout.children[5].height, 60.0)
  assert_approx(layout.children[6].x, 100.0)
  assert_approx(layout.children[6].y, 40.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 60.0)
  assert_approx(layout.children[7].x, 140.0)
  assert_approx(layout.children[7].y, 40.0)
  assert_approx(layout.children[7].width, 60.0)
  assert_approx(layout.children[7].height, 60.0)
  assert_approx(layout.children[8].x, 0.0)
  assert_approx(layout.children[8].y, 100.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
  assert_approx(layout.children[9].x, 40.0)
  assert_approx(layout.children[9].y, 100.0)
  assert_approx(layout.children[9].width, 60.0)
  assert_approx(layout.children[9].height, 40.0)
  assert_approx(layout.children[10].x, 100.0)
  assert_approx(layout.children[10].y, 100.0)
  assert_approx(layout.children[10].width, 40.0)
  assert_approx(layout.children[10].height, 40.0)
  assert_approx(layout.children[11].x, 140.0)
  assert_approx(layout.children[11].y, 100.0)
  assert_approx(layout.children[11].width, 60.0)
  assert_approx(layout.children[11].height, 40.0)
  assert_approx(layout.children[12].x, 0.0)
  assert_approx(layout.children[12].y, 140.0)
  assert_approx(layout.children[12].width, 40.0)
  assert_approx(layout.children[12].height, 60.0)
  assert_approx(layout.children[13].x, 40.0)
  assert_approx(layout.children[13].y, 140.0)
  assert_approx(layout.children[13].width, 60.0)
  assert_approx(layout.children[13].height, 60.0)
  assert_approx(layout.children[14].x, 100.0)
  assert_approx(layout.children[14].y, 140.0)
  assert_approx(layout.children[14].width, 40.0)
  assert_approx(layout.children[14].height, 60.0)
  assert_approx(layout.children[15].x, 140.0)
  assert_approx(layout.children[15].y, 140.0)
  assert_approx(layout.children[15].width, 60.0)
  assert_approx(layout.children[15].height, 60.0)
}

///|
test "taffy/grid_auto_fill_fixed_size" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Repeat(@style.AutoFill, [@style.SingleTrackSizing::Length(40.0)])],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_auto_fill_with_empty_auto_track" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Repeat(@style.AutoFill, [@style.SingleTrackSizing::Length(40.0)])],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.SpaceEvenly,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
}

///|
test "taffy/grid_auto_fit_definite_percentage" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(730.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Percent(1.0000),
    height: @types.Percent(1.0000),
    padding: { left: @types.Length(10.0), right: @types.Length(10.0), top: @types.Length(10.0), bottom: @types.Length(10.0) },
    grid_template_columns: [@style.Repeat(@style.AutoFill, [@style.SingleTrackSizing::MinMax(@style.MinTrackSizing::Length(150.0), @style.MaxTrackSizing::Fr(1.0))])],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 730.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 730.0)
  assert_approx(layout.children[0].height, 300.0)
  assert_approx(layout.children[0].children[0].x, 10.0)
  assert_approx(layout.children[0].children[0].y, 10.0)
  assert_approx(layout.children[0].children[0].width, 170.0)
  assert_approx(layout.children[0].children[0].height, 135.0)
  assert_approx(layout.children[0].children[1].x, 190.0)
  assert_approx(layout.children[0].children[1].y, 10.0)
  assert_approx(layout.children[0].children[1].width, 170.0)
  assert_approx(layout.children[0].children[1].height, 135.0)
  assert_approx(layout.children[0].children[2].x, 370.0)
  assert_approx(layout.children[0].children[2].y, 10.0)
  assert_approx(layout.children[0].children[2].width, 170.0)
  assert_approx(layout.children[0].children[2].height, 135.0)
  assert_approx(layout.children[0].children[3].x, 550.0)
  assert_approx(layout.children[0].children[3].y, 10.0)
  assert_approx(layout.children[0].children[3].width, 170.0)
  assert_approx(layout.children[0].children[3].height, 135.0)
  assert_approx(layout.children[0].children[4].x, 10.0)
  assert_approx(layout.children[0].children[4].y, 155.0)
  assert_approx(layout.children[0].children[4].width, 170.0)
  assert_approx(layout.children[0].children[4].height, 135.0)
  assert_approx(layout.children[0].children[5].x, 190.0)
  assert_approx(layout.children[0].children[5].y, 155.0)
  assert_approx(layout.children[0].children[5].width, 170.0)
  assert_approx(layout.children[0].children[5].height, 135.0)
  assert_approx(layout.children[0].children[6].x, 370.0)
  assert_approx(layout.children[0].children[6].y, 155.0)
  assert_approx(layout.children[0].children[6].width, 170.0)
  assert_approx(layout.children[0].children[6].height, 135.0)
  assert_approx(layout.children[0].children[7].x, 550.0)
  assert_approx(layout.children[0].children[7].y, 155.0)
  assert_approx(layout.children[0].children[7].width, 170.0)
  assert_approx(layout.children[0].children[7].height, 135.0)
}

///|
test "taffy/grid_auto_fit_with_empty_auto_track" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Repeat(@style.AutoFit, [@style.SingleTrackSizing::Length(40.0)])],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.SpaceEvenly,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 13.3)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 66.7)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
}

///|
test "taffy/grid_auto_rows" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(100.0)],
    grid_template_rows: [@style.Length(40.0)],
    grid_auto_rows: [@style.Length(10.0), @style.Length(20.0), @style.Length(30.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_row: { start: @style.Line(-4), end: @style.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 180.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 100.0)
  assert_approx(layout.children[1].height, 30.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 50.0)
  assert_approx(layout.children[2].width, 100.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 90.0)
  assert_approx(layout.children[3].width, 100.0)
  assert_approx(layout.children[3].height, 10.0)
  assert_approx(layout.children[4].x, 0.0)
  assert_approx(layout.children[4].y, 100.0)
  assert_approx(layout.children[4].width, 100.0)
  assert_approx(layout.children[4].height, 20.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 120.0)
  assert_approx(layout.children[5].width, 100.0)
  assert_approx(layout.children[5].height, 30.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 150.0)
  assert_approx(layout.children[6].width, 100.0)
  assert_approx(layout.children[6].height, 10.0)
  assert_approx(layout.children[7].x, 0.0)
  assert_approx(layout.children[7].y, 160.0)
  assert_approx(layout.children[7].width, 100.0)
  assert_approx(layout.children[7].height, 20.0)
}

///|
test "taffy/grid_auto_single_item" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.Auto, @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 100.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 140.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 100.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 140.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 100.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 140.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_auto_single_item_fixed_width" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Auto, @style.Auto],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    min_width: @types.Length(100.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 130.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 170.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 30.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 130.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 170.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 30.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 130.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 170.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 30.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_auto_single_item_fixed_width_with_definite_width" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Auto, @style.Auto],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 100.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 170.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 30.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 130.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 170.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 30.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 130.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 170.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 30.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_auto_takes_precedence_over_fr" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Auto, @style.Fr(1.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 200.0)
  assert_approx(layout.children[1].height, 40.0)
}

///|
test "taffy/grid_available_space_greater_than_max_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Auto, @style.Auto],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 160.0)
  assert_approx(layout.height, 10.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 80.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 80.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/grid_available_space_smaller_than_max_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Auto, @style.Auto],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 20.0)
}

///|
test "taffy/grid_available_space_smaller_than_min_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Auto, @style.Auto],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 20.0)
}

///|
test "taffy/grid_basic" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_basic_implicit_tracks" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(35.0),
    height: @types.Length(35.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 75.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 35.0)
  assert_approx(layout.children[1].height, 35.0)
}

///|
test "taffy/grid_basic_with_overflow" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root_child9_style = {
    ..@style.Style::default(),
  }
  let root_child9 = @node.Node::leaf("node", root_child9_style)
  root_children.push(root_child9)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
  assert_approx(layout.children[9].x, 0.0)
  assert_approx(layout.children[9].y, 120.0)
  assert_approx(layout.children[9].width, 40.0)
  assert_approx(layout.children[9].height, 0.0)
}

///|
test "taffy/grid_basic_with_padding" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 40.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 120.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 40.0)
  assert_approx(layout.children[3].y, 50.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 120.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 40.0)
  assert_approx(layout.children[6].y, 90.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 80.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 120.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_display_none_fixed_size" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    flex_grow: 1.0,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.None,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 100.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 0.0)
}

///|
test "taffy/grid_fit_content_percent_definite_argument" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(60.0),
    grid_template_columns: [@style.FitContentPercent(0.5000)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 30.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fit_content_percent_definite_max_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(60.0),
    grid_template_columns: [@style.FitContentPercent(0.5000)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fit_content_percent_definite_min_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(60.0),
    grid_template_columns: [@style.FitContentPercent(0.5000)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fit_content_percent_indefinite_argument" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.FitContentPercent(0.5000)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 30.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fit_content_percent_indefinite_max_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.FitContentPercent(0.5000)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fit_content_percent_indefinite_max_content_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.FitContentPercent(0.5000)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fit_content_percent_indefinite_min_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.FitContentPercent(0.5000)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fit_content_percent_indefinite_min_content_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.FitContentPercent(0.5000)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 30.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fit_content_points_argument" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.FitContentLength(30.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 30.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 30.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fit_content_points_max_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.FitContentLength(30.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fit_content_points_min_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.FitContentLength(30.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fit_content_points_min_content_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.FitContentLength(30.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 30.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 30.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_fr_fixed_size_no_content_proportions" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    grid_template_columns: [@style.Fr(1.0), @style.Fr(2.0), @style.Fr(3.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 33.3)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 33.3)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 66.7)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 100.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 100.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_fr_fixed_size_no_content_proportions_sub_1_sum" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    grid_template_columns: [@style.Fr(0.3), @style.Fr(0.2)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 30.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 30.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
}

///|
test "taffy/grid_fr_fixed_size_single_item" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Fr(1.0), @style.Fr(1.0)],
    grid_template_rows: [@style.Length(40.0), @style.Fr(1.0), @style.Fr(1.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 100.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 140.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 60.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 80.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 100.0)
  assert_approx(layout.children[4].height, 80.0)
  assert_approx(layout.children[5].x, 140.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 60.0)
  assert_approx(layout.children[5].height, 80.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 120.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 80.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 120.0)
  assert_approx(layout.children[7].width, 100.0)
  assert_approx(layout.children[7].height, 80.0)
  assert_approx(layout.children[8].x, 140.0)
  assert_approx(layout.children[8].y, 120.0)
  assert_approx(layout.children[8].width, 60.0)
  assert_approx(layout.children[8].height, 80.0)
}

///|
test "taffy/grid_fr_no_sized_items_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.Fr(1.0), @style.Fr(1.0)],
    grid_template_rows: [@style.Length(40.0), @style.Fr(1.0), @style.Fr(1.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 40.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 0.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 0.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 0.0)
  assert_approx(layout.children[4].height, 0.0)
  assert_approx(layout.children[5].x, 40.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 0.0)
  assert_approx(layout.children[5].height, 0.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 40.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 0.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 40.0)
  assert_approx(layout.children[7].width, 0.0)
  assert_approx(layout.children[7].height, 0.0)
  assert_approx(layout.children[8].x, 40.0)
  assert_approx(layout.children[8].y, 40.0)
  assert_approx(layout.children[8].width, 0.0)
  assert_approx(layout.children[8].height, 0.0)
}

///|
test "taffy/grid_fr_single_item_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Auto,
    height: @types.Auto,
    grid_template_columns: [@style.Length(40.0), @style.Fr(1.0), @style.Fr(1.0)],
    grid_template_rows: [@style.Length(40.0), @style.Fr(1.0), @style.Fr(1.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 100.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 140.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 100.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 0.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 100.0)
  assert_approx(layout.children[4].height, 0.0)
  assert_approx(layout.children[5].x, 140.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 100.0)
  assert_approx(layout.children[5].height, 0.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 40.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 0.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 40.0)
  assert_approx(layout.children[7].width, 100.0)
  assert_approx(layout.children[7].height, 0.0)
  assert_approx(layout.children[8].x, 140.0)
  assert_approx(layout.children[8].y, 40.0)
  assert_approx(layout.children[8].width, 100.0)
  assert_approx(layout.children[8].height, 0.0)
}

///|
test "taffy/grid_fr_span_2_proportion" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Fr(1.0), @style.Fr(2.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 60.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 20.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_fr_span_2_proportion_sub_1_sum" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Fr(0.2), @style.Fr(0.3)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 60.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 24.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 24.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 36.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_fr_span_2_proportion_with_non_spanned_track" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Fr(1.0), @style.Fr(2.0), @style.Fr(3.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 60.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 60.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 20.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 60.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 60.0)
  assert_approx(layout.children[4].height, 40.0)
}

///|
test "taffy/grid_fr_span_2_proportion_zero_sum" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Fr(0.0), @style.Fr(0.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 60.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 30.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 30.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 30.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_fr_span_2_proportion_zero_sum_with_non_spanned_track" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Fr(0.0), @style.Fr(0.0), @style.Fr(0.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 60.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 60.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 30.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 30.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 30.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 60.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 0.0)
  assert_approx(layout.children[4].height, 40.0)
}

///|
test "taffy/grid_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    row_gap: @types.Length(40.0),
    column_gap: @types.Length(40.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 160.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 80.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 80.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 160.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 160.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 80.0)
  assert_approx(layout.children[7].y, 160.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 160.0)
  assert_approx(layout.children[8].y, 160.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.None,
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    display: @style.None,
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
    display: @style.None,
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 40.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 80.0)
  assert_approx(layout.children[3].y, 0.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 0.0)
  assert_approx(layout.children[4].y, 0.0)
  assert_approx(layout.children[4].width, 0.0)
  assert_approx(layout.children[4].height, 0.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 0.0)
  assert_approx(layout.children[6].width, 0.0)
  assert_approx(layout.children[6].height, 0.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 40.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 40.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_center" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 40.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 120.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 40.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 120.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 40.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 80.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 120.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_center_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.Center,
    align_content: @style.Center,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, -10.0)
  assert_approx(layout.children[0].children[0].y, 20.0)
  assert_approx(layout.children[0].children[0].width, 40.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[0].children[1].x, 40.0)
  assert_approx(layout.children[0].children[1].y, 20.0)
  assert_approx(layout.children[0].children[1].width, 40.0)
  assert_approx(layout.children[0].children[1].height, 20.0)
  assert_approx(layout.children[0].children[2].x, 90.0)
  assert_approx(layout.children[0].children[2].y, 20.0)
  assert_approx(layout.children[0].children[2].width, 40.0)
  assert_approx(layout.children[0].children[2].height, 20.0)
  assert_approx(layout.children[0].children[3].x, -10.0)
  assert_approx(layout.children[0].children[3].y, 50.0)
  assert_approx(layout.children[0].children[3].width, 40.0)
  assert_approx(layout.children[0].children[3].height, 20.0)
  assert_approx(layout.children[0].children[4].x, 40.0)
  assert_approx(layout.children[0].children[4].y, 50.0)
  assert_approx(layout.children[0].children[4].width, 40.0)
  assert_approx(layout.children[0].children[4].height, 20.0)
  assert_approx(layout.children[0].children[5].x, 90.0)
  assert_approx(layout.children[0].children[5].y, 50.0)
  assert_approx(layout.children[0].children[5].width, 40.0)
  assert_approx(layout.children[0].children[5].height, 20.0)
  assert_approx(layout.children[0].children[6].x, -10.0)
  assert_approx(layout.children[0].children[6].y, 80.0)
  assert_approx(layout.children[0].children[6].width, 40.0)
  assert_approx(layout.children[0].children[6].height, 20.0)
  assert_approx(layout.children[0].children[7].x, 40.0)
  assert_approx(layout.children[0].children[7].y, 80.0)
  assert_approx(layout.children[0].children[7].width, 40.0)
  assert_approx(layout.children[0].children[7].height, 20.0)
  assert_approx(layout.children[0].children[8].x, 90.0)
  assert_approx(layout.children[0].children[8].y, 80.0)
  assert_approx(layout.children[0].children[8].width, 40.0)
  assert_approx(layout.children[0].children[8].height, 20.0)
}

///|
test "taffy/grid_justify_content_center_with_padding_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    border: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 52.0)
  assert_approx(layout.children[0].y, 12.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 92.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 132.0)
  assert_approx(layout.children[2].y, 12.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 52.0)
  assert_approx(layout.children[3].y, 52.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 92.0)
  assert_approx(layout.children[4].y, 52.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 132.0)
  assert_approx(layout.children[5].y, 52.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 52.0)
  assert_approx(layout.children[6].y, 92.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 92.0)
  assert_approx(layout.children[7].y, 92.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 132.0)
  assert_approx(layout.children[8].y, 92.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_end" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.End,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 80.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 120.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 160.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 80.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 120.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 160.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 80.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 120.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 160.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_end_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.End,
    align_content: @style.Center,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, -20.0)
  assert_approx(layout.children[0].children[0].y, 20.0)
  assert_approx(layout.children[0].children[0].width, 40.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[0].children[1].x, 30.0)
  assert_approx(layout.children[0].children[1].y, 20.0)
  assert_approx(layout.children[0].children[1].width, 40.0)
  assert_approx(layout.children[0].children[1].height, 20.0)
  assert_approx(layout.children[0].children[2].x, 80.0)
  assert_approx(layout.children[0].children[2].y, 20.0)
  assert_approx(layout.children[0].children[2].width, 40.0)
  assert_approx(layout.children[0].children[2].height, 20.0)
  assert_approx(layout.children[0].children[3].x, -20.0)
  assert_approx(layout.children[0].children[3].y, 50.0)
  assert_approx(layout.children[0].children[3].width, 40.0)
  assert_approx(layout.children[0].children[3].height, 20.0)
  assert_approx(layout.children[0].children[4].x, 30.0)
  assert_approx(layout.children[0].children[4].y, 50.0)
  assert_approx(layout.children[0].children[4].width, 40.0)
  assert_approx(layout.children[0].children[4].height, 20.0)
  assert_approx(layout.children[0].children[5].x, 80.0)
  assert_approx(layout.children[0].children[5].y, 50.0)
  assert_approx(layout.children[0].children[5].width, 40.0)
  assert_approx(layout.children[0].children[5].height, 20.0)
  assert_approx(layout.children[0].children[6].x, -20.0)
  assert_approx(layout.children[0].children[6].y, 80.0)
  assert_approx(layout.children[0].children[6].width, 40.0)
  assert_approx(layout.children[0].children[6].height, 20.0)
  assert_approx(layout.children[0].children[7].x, 30.0)
  assert_approx(layout.children[0].children[7].y, 80.0)
  assert_approx(layout.children[0].children[7].width, 40.0)
  assert_approx(layout.children[0].children[7].height, 20.0)
  assert_approx(layout.children[0].children[8].x, 80.0)
  assert_approx(layout.children[0].children[8].y, 80.0)
  assert_approx(layout.children[0].children[8].width, 40.0)
  assert_approx(layout.children[0].children[8].height, 20.0)
}

///|
test "taffy/grid_justify_content_end_with_padding_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    border: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.End,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 56.0)
  assert_approx(layout.children[0].y, 12.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 96.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 136.0)
  assert_approx(layout.children[2].y, 12.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 56.0)
  assert_approx(layout.children[3].y, 52.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 96.0)
  assert_approx(layout.children[4].y, 52.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 136.0)
  assert_approx(layout.children[5].y, 52.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 56.0)
  assert_approx(layout.children[6].y, 92.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 96.0)
  assert_approx(layout.children[7].y, 92.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 136.0)
  assert_approx(layout.children[8].y, 92.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_space_around" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.SpaceAround,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 13.3)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 146.7)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 13.3)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 146.7)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 13.3)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 80.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 146.7)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_space_around_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.SpaceAround,
    align_content: @style.Center,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 20.0)
  assert_approx(layout.children[0].children[0].width, 40.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[0].children[1].x, 50.0)
  assert_approx(layout.children[0].children[1].y, 20.0)
  assert_approx(layout.children[0].children[1].width, 40.0)
  assert_approx(layout.children[0].children[1].height, 20.0)
  assert_approx(layout.children[0].children[2].x, 100.0)
  assert_approx(layout.children[0].children[2].y, 20.0)
  assert_approx(layout.children[0].children[2].width, 40.0)
  assert_approx(layout.children[0].children[2].height, 20.0)
  assert_approx(layout.children[0].children[3].x, 0.0)
  assert_approx(layout.children[0].children[3].y, 50.0)
  assert_approx(layout.children[0].children[3].width, 40.0)
  assert_approx(layout.children[0].children[3].height, 20.0)
  assert_approx(layout.children[0].children[4].x, 50.0)
  assert_approx(layout.children[0].children[4].y, 50.0)
  assert_approx(layout.children[0].children[4].width, 40.0)
  assert_approx(layout.children[0].children[4].height, 20.0)
  assert_approx(layout.children[0].children[5].x, 100.0)
  assert_approx(layout.children[0].children[5].y, 50.0)
  assert_approx(layout.children[0].children[5].width, 40.0)
  assert_approx(layout.children[0].children[5].height, 20.0)
  assert_approx(layout.children[0].children[6].x, 0.0)
  assert_approx(layout.children[0].children[6].y, 80.0)
  assert_approx(layout.children[0].children[6].width, 40.0)
  assert_approx(layout.children[0].children[6].height, 20.0)
  assert_approx(layout.children[0].children[7].x, 50.0)
  assert_approx(layout.children[0].children[7].y, 80.0)
  assert_approx(layout.children[0].children[7].width, 40.0)
  assert_approx(layout.children[0].children[7].height, 20.0)
  assert_approx(layout.children[0].children[8].x, 100.0)
  assert_approx(layout.children[0].children[8].y, 80.0)
  assert_approx(layout.children[0].children[8].width, 40.0)
  assert_approx(layout.children[0].children[8].height, 20.0)
}

///|
test "taffy/grid_justify_content_space_around_with_padding_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    border: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.SpaceAround,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 49.3)
  assert_approx(layout.children[0].y, 12.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 92.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 134.7)
  assert_approx(layout.children[2].y, 12.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 49.3)
  assert_approx(layout.children[3].y, 52.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 92.0)
  assert_approx(layout.children[4].y, 52.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 134.7)
  assert_approx(layout.children[5].y, 52.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 49.3)
  assert_approx(layout.children[6].y, 92.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 92.0)
  assert_approx(layout.children[7].y, 92.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 134.7)
  assert_approx(layout.children[8].y, 92.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_space_between" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.SpaceBetween,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 160.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 160.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 80.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 160.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_space_between_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.SpaceBetween,
    align_content: @style.Center,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 20.0)
  assert_approx(layout.children[0].children[0].width, 40.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[0].children[1].x, 50.0)
  assert_approx(layout.children[0].children[1].y, 20.0)
  assert_approx(layout.children[0].children[1].width, 40.0)
  assert_approx(layout.children[0].children[1].height, 20.0)
  assert_approx(layout.children[0].children[2].x, 100.0)
  assert_approx(layout.children[0].children[2].y, 20.0)
  assert_approx(layout.children[0].children[2].width, 40.0)
  assert_approx(layout.children[0].children[2].height, 20.0)
  assert_approx(layout.children[0].children[3].x, 0.0)
  assert_approx(layout.children[0].children[3].y, 50.0)
  assert_approx(layout.children[0].children[3].width, 40.0)
  assert_approx(layout.children[0].children[3].height, 20.0)
  assert_approx(layout.children[0].children[4].x, 50.0)
  assert_approx(layout.children[0].children[4].y, 50.0)
  assert_approx(layout.children[0].children[4].width, 40.0)
  assert_approx(layout.children[0].children[4].height, 20.0)
  assert_approx(layout.children[0].children[5].x, 100.0)
  assert_approx(layout.children[0].children[5].y, 50.0)
  assert_approx(layout.children[0].children[5].width, 40.0)
  assert_approx(layout.children[0].children[5].height, 20.0)
  assert_approx(layout.children[0].children[6].x, 0.0)
  assert_approx(layout.children[0].children[6].y, 80.0)
  assert_approx(layout.children[0].children[6].width, 40.0)
  assert_approx(layout.children[0].children[6].height, 20.0)
  assert_approx(layout.children[0].children[7].x, 50.0)
  assert_approx(layout.children[0].children[7].y, 80.0)
  assert_approx(layout.children[0].children[7].width, 40.0)
  assert_approx(layout.children[0].children[7].height, 20.0)
  assert_approx(layout.children[0].children[8].x, 100.0)
  assert_approx(layout.children[0].children[8].y, 80.0)
  assert_approx(layout.children[0].children[8].width, 40.0)
  assert_approx(layout.children[0].children[8].height, 20.0)
}

///|
test "taffy/grid_justify_content_space_between_with_padding_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    border: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.SpaceBetween,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 48.0)
  assert_approx(layout.children[0].y, 12.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 92.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 136.0)
  assert_approx(layout.children[2].y, 12.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 48.0)
  assert_approx(layout.children[3].y, 52.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 92.0)
  assert_approx(layout.children[4].y, 52.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 136.0)
  assert_approx(layout.children[5].y, 52.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 48.0)
  assert_approx(layout.children[6].y, 92.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 92.0)
  assert_approx(layout.children[7].y, 92.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 136.0)
  assert_approx(layout.children[8].y, 92.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_space_evenly" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.SpaceEvenly,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 20.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 140.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 20.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 140.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 20.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 80.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 140.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_space_evenly_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.SpaceEvenly,
    align_content: @style.Center,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 20.0)
  assert_approx(layout.children[0].children[0].width, 40.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[0].children[1].x, 50.0)
  assert_approx(layout.children[0].children[1].y, 20.0)
  assert_approx(layout.children[0].children[1].width, 40.0)
  assert_approx(layout.children[0].children[1].height, 20.0)
  assert_approx(layout.children[0].children[2].x, 100.0)
  assert_approx(layout.children[0].children[2].y, 20.0)
  assert_approx(layout.children[0].children[2].width, 40.0)
  assert_approx(layout.children[0].children[2].height, 20.0)
  assert_approx(layout.children[0].children[3].x, 0.0)
  assert_approx(layout.children[0].children[3].y, 50.0)
  assert_approx(layout.children[0].children[3].width, 40.0)
  assert_approx(layout.children[0].children[3].height, 20.0)
  assert_approx(layout.children[0].children[4].x, 50.0)
  assert_approx(layout.children[0].children[4].y, 50.0)
  assert_approx(layout.children[0].children[4].width, 40.0)
  assert_approx(layout.children[0].children[4].height, 20.0)
  assert_approx(layout.children[0].children[5].x, 100.0)
  assert_approx(layout.children[0].children[5].y, 50.0)
  assert_approx(layout.children[0].children[5].width, 40.0)
  assert_approx(layout.children[0].children[5].height, 20.0)
  assert_approx(layout.children[0].children[6].x, 0.0)
  assert_approx(layout.children[0].children[6].y, 80.0)
  assert_approx(layout.children[0].children[6].width, 40.0)
  assert_approx(layout.children[0].children[6].height, 20.0)
  assert_approx(layout.children[0].children[7].x, 50.0)
  assert_approx(layout.children[0].children[7].y, 80.0)
  assert_approx(layout.children[0].children[7].width, 40.0)
  assert_approx(layout.children[0].children[7].height, 20.0)
  assert_approx(layout.children[0].children[8].x, 100.0)
  assert_approx(layout.children[0].children[8].y, 80.0)
  assert_approx(layout.children[0].children[8].width, 40.0)
  assert_approx(layout.children[0].children[8].height, 20.0)
}

///|
test "taffy/grid_justify_content_space_evenly_with_padding_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    border: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.SpaceEvenly,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 50.0)
  assert_approx(layout.children[0].y, 12.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 92.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 134.0)
  assert_approx(layout.children[2].y, 12.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 50.0)
  assert_approx(layout.children[3].y, 52.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 92.0)
  assert_approx(layout.children[4].y, 52.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 134.0)
  assert_approx(layout.children[5].y, 52.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 50.0)
  assert_approx(layout.children[6].y, 92.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 92.0)
  assert_approx(layout.children[7].y, 92.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 134.0)
  assert_approx(layout.children[8].y, 92.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_start" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.Start,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_content_start_negative_space_gap" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(240.0),
    height: @types.Length(240.0),
    border: { left: @types.Length(60.0), right: @types.Length(60.0), top: @types.Length(60.0), bottom: @types.Length(60.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
    justify_content: @style.Start,
    align_content: @style.Center,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0_child6_style = {
    ..@style.Style::default(),
  }
  let root_child0_child6 = @node.Node::leaf("node", root_child0_child6_style)
  root_child0_children.push(root_child0_child6)
  let root_child0_child7_style = {
    ..@style.Style::default(),
  }
  let root_child0_child7 = @node.Node::leaf("node", root_child0_child7_style)
  root_child0_children.push(root_child0_child7)
  let root_child0_child8_style = {
    ..@style.Style::default(),
  }
  let root_child0_child8 = @node.Node::leaf("node", root_child0_child8_style)
  root_child0_children.push(root_child0_child8)
  let root_child0 = @node.Node::new("test-root", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 240.0)
  assert_approx(layout.height, 240.0)
  assert_approx(layout.children[0].x, 60.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 120.0)
  assert_approx(layout.children[0].height, 120.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 20.0)
  assert_approx(layout.children[0].children[0].width, 40.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[0].children[1].x, 50.0)
  assert_approx(layout.children[0].children[1].y, 20.0)
  assert_approx(layout.children[0].children[1].width, 40.0)
  assert_approx(layout.children[0].children[1].height, 20.0)
  assert_approx(layout.children[0].children[2].x, 100.0)
  assert_approx(layout.children[0].children[2].y, 20.0)
  assert_approx(layout.children[0].children[2].width, 40.0)
  assert_approx(layout.children[0].children[2].height, 20.0)
  assert_approx(layout.children[0].children[3].x, 0.0)
  assert_approx(layout.children[0].children[3].y, 50.0)
  assert_approx(layout.children[0].children[3].width, 40.0)
  assert_approx(layout.children[0].children[3].height, 20.0)
  assert_approx(layout.children[0].children[4].x, 50.0)
  assert_approx(layout.children[0].children[4].y, 50.0)
  assert_approx(layout.children[0].children[4].width, 40.0)
  assert_approx(layout.children[0].children[4].height, 20.0)
  assert_approx(layout.children[0].children[5].x, 100.0)
  assert_approx(layout.children[0].children[5].y, 50.0)
  assert_approx(layout.children[0].children[5].width, 40.0)
  assert_approx(layout.children[0].children[5].height, 20.0)
  assert_approx(layout.children[0].children[6].x, 0.0)
  assert_approx(layout.children[0].children[6].y, 80.0)
  assert_approx(layout.children[0].children[6].width, 40.0)
  assert_approx(layout.children[0].children[6].height, 20.0)
  assert_approx(layout.children[0].children[7].x, 50.0)
  assert_approx(layout.children[0].children[7].y, 80.0)
  assert_approx(layout.children[0].children[7].width, 40.0)
  assert_approx(layout.children[0].children[7].height, 20.0)
  assert_approx(layout.children[0].children[8].x, 100.0)
  assert_approx(layout.children[0].children[8].y, 80.0)
  assert_approx(layout.children[0].children[8].width, 40.0)
  assert_approx(layout.children[0].children[8].height, 20.0)
}

///|
test "taffy/grid_justify_content_start_with_padding_border" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    border: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_content: @style.Start,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 48.0)
  assert_approx(layout.children[0].y, 12.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 88.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 128.0)
  assert_approx(layout.children[2].y, 12.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 48.0)
  assert_approx(layout.children[3].y, 52.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 88.0)
  assert_approx(layout.children[4].y, 52.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 128.0)
  assert_approx(layout.children[5].y, 52.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 48.0)
  assert_approx(layout.children[6].y, 92.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 88.0)
  assert_approx(layout.children[7].y, 92.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 128.0)
  assert_approx(layout.children[8].y, 92.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_justify_items_sized_center" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_items: @style.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    grid_column: { start: @style.Line(3), end: @style.Auto },
    grid_row: { start: @style.Line(3), end: @style.Auto },
    grid_area: Some("3 / 3"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 70.0)
  assert_approx(layout.children[1].y, 80.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
}

///|
test "taffy/grid_justify_items_sized_end" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_items: @style.End,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    grid_column: { start: @style.Line(3), end: @style.Auto },
    grid_row: { start: @style.Line(3), end: @style.Auto },
    grid_area: Some("3 / 3"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 20.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 60.0)
  assert_approx(layout.children[1].y, 80.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
}

///|
test "taffy/grid_justify_items_sized_start" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_items: @style.Start,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    grid_column: { start: @style.Line(3), end: @style.Auto },
    grid_row: { start: @style.Line(3), end: @style.Auto },
    grid_area: Some("3 / 3"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 80.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
}

///|
test "taffy/grid_justify_items_sized_stretch" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    justify_items: @style.Stretch,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    grid_column: { start: @style.Line(3), end: @style.Auto },
    grid_row: { start: @style.Line(3), end: @style.Auto },
    grid_area: Some("3 / 3"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 80.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
}

///|
test "taffy/grid_justify_self_sized_all" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    justify_self: @style.AlignSelf::Start,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    justify_self: @style.AlignSelf::Start,
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    justify_self: @style.AlignSelf::End,
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    justify_self: @style.AlignSelf::End,
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    justify_self: @style.AlignSelf::Center,
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    justify_self: @style.AlignSelf::Center,
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    justify_self: @style.AlignSelf::Stretch,
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(60.0),
    justify_self: @style.AlignSelf::Stretch,
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 60.0)
  assert_approx(layout.children[2].x, 100.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 20.0)
  assert_approx(layout.children[3].x, -20.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 60.0)
  assert_approx(layout.children[3].height, 60.0)
  assert_approx(layout.children[4].x, 50.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 20.0)
  assert_approx(layout.children[5].x, 70.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 60.0)
  assert_approx(layout.children[5].height, 60.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 20.0)
  assert_approx(layout.children[6].height, 20.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 60.0)
  assert_approx(layout.children[7].height, 60.0)
}

///|
test "taffy/grid_margins_auto_margins" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    margin: { left: @types.Auto, right: @types.Auto, top: @types.Length(0.0), bottom: @types.Length(0.0) },
    justify_self: @style.AlignSelf::Start,
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    height: @types.Length(20.0),
    margin: { left: @types.Length(0.0), right: @types.Length(0.0), top: @types.Auto, bottom: @types.Auto },
    align_self: @style.AlignSelf::Start,
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    margin: { left: @types.Auto, right: @types.Auto, top: @types.Auto, bottom: @types.Auto },
    align_self: @style.AlignSelf::Start,
    justify_self: @style.AlignSelf::Start,
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 40.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 130.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 40.0)
  assert_approx(layout.children[3].y, 50.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 60.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 20.0)
  assert_approx(layout.children[5].x, 120.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 50.0)
  assert_approx(layout.children[6].y, 100.0)
  assert_approx(layout.children[6].width, 20.0)
  assert_approx(layout.children[6].height, 20.0)
  assert_approx(layout.children[7].x, 80.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 120.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_margins_auto_margins_override_stretch" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
    margin: { left: @types.Auto, right: @types.Auto, top: @types.Auto, bottom: @types.Auto },
    align_self: @style.AlignSelf::Stretch,
    justify_self: @style.AlignSelf::Stretch,
  }
  let root_child6_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child6 = @node.Node::with_measure("node", root_child6_style, root_child6_measure)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 40.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 120.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 40.0)
  assert_approx(layout.children[3].y, 50.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 120.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 40.0)
  assert_approx(layout.children[6].y, 105.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 10.0)
  assert_approx(layout.children[7].x, 80.0)
  assert_approx(layout.children[7].y, 90.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 120.0)
  assert_approx(layout.children[8].y, 90.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_margins_fixed_center" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    margin: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    align_self: @style.AlignSelf::Center,
    justify_self: @style.AlignSelf::Center,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 52.0)
  assert_approx(layout.children[0].y, 18.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 120.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 40.0)
  assert_approx(layout.children[3].y, 50.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 120.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
}

///|
test "taffy/grid_margins_fixed_end" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    margin: { left: @types.Length(4.0), right: @types.Length(2.0), top: @types.Length(1.0), bottom: @types.Length(3.0) },
    align_self: @style.AlignSelf::End,
    justify_self: @style.AlignSelf::End,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 58.0)
  assert_approx(layout.children[0].y, 27.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 120.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 40.0)
  assert_approx(layout.children[3].y, 50.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 120.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
}

///|
test "taffy/grid_margins_fixed_start" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    margin: { left: @types.Length(4.0), right: @types.Length(2.0), top: @types.Length(1.0), bottom: @types.Length(3.0) },
    align_self: @style.AlignSelf::Start,
    justify_self: @style.AlignSelf::Start,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 44.0)
  assert_approx(layout.children[0].y, 11.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 120.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 40.0)
  assert_approx(layout.children[3].y, 50.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 120.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
}

///|
test "taffy/grid_margins_fixed_stretch" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(40.0), right: @types.Length(20.0), top: @types.Length(10.0), bottom: @types.Length(30.0) },
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    margin: { left: @types.Length(4.0), right: @types.Length(2.0), top: @types.Length(1.0), bottom: @types.Length(3.0) },
    align_self: @style.AlignSelf::Stretch,
    justify_self: @style.AlignSelf::Stretch,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 180.0)
  assert_approx(layout.height, 160.0)
  assert_approx(layout.children[0].x, 44.0)
  assert_approx(layout.children[0].y, 11.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 120.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 40.0)
  assert_approx(layout.children[3].y, 50.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 120.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
}

///|
test "taffy/grid_margins_percent_center" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    margin: { left: @types.Percent(0.2000), right: @types.Percent(0.1000), top: @types.Percent(0.0500), bottom: @types.Percent(0.1500) },
    align_self: @style.AlignSelf::Center,
    justify_self: @style.AlignSelf::Center,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 1.0)
  assert_approx(layout.children[0].y, 9.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 40.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 20.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 20.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 40.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 20.0)
  assert_approx(layout.children[5].height, 40.0)
}

///|
test "taffy/grid_margins_percent_end" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    margin: { left: @types.Percent(0.2000), right: @types.Percent(0.1000), top: @types.Percent(0.0500), bottom: @types.Percent(0.1500) },
    align_self: @style.AlignSelf::End,
    justify_self: @style.AlignSelf::End,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, -2.0)
  assert_approx(layout.children[0].y, 17.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 40.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 20.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 20.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 40.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 20.0)
  assert_approx(layout.children[5].height, 40.0)
}

///|
test "taffy/grid_margins_percent_start" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    margin: { left: @types.Percent(0.2000), right: @types.Percent(0.1000), top: @types.Percent(0.0500), bottom: @types.Percent(0.1500) },
    align_self: @style.AlignSelf::Start,
    justify_self: @style.AlignSelf::Start,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 4.0)
  assert_approx(layout.children[0].y, 1.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 40.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 20.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 20.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 40.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 20.0)
  assert_approx(layout.children[5].height, 40.0)
}

///|
test "taffy/grid_margins_percent_stretch" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(20.0), @style.Length(20.0), @style.Length(20.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    margin: { left: @types.Percent(0.2000), right: @types.Percent(0.1000), top: @types.Percent(0.0500), bottom: @types.Percent(0.1500) },
    align_self: @style.AlignSelf::Stretch,
    justify_self: @style.AlignSelf::Stretch,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 4.0)
  assert_approx(layout.children[0].y, 1.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 40.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 20.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 20.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 40.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 20.0)
  assert_approx(layout.children[5].height, 40.0)
}

///|
test "taffy/grid_max_content_maximum_single_item" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MinMax(@style.MinTrackSizing::Length(0.0), @style.MaxTrackSizing::MaxContent), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_max_content_single_item" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MaxContent, @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_max_content_single_item_margin_auto" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MaxContent, @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: { left: @types.Auto, right: @types.Auto, top: @types.Auto, bottom: @types.Auto },
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 15.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_max_content_single_item_margin_fixed" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MaxContent, @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: { left: @types.Length(20.0), right: @types.Length(10.0), top: @types.Length(5.0), bottom: @types.Length(15.0) },
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 150.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 60.0)
  assert_approx(layout.children[1].y, 5.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[2].x, 110.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 70.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 110.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 70.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 110.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_max_content_single_item_margin_percent" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MaxContent, @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: { left: @types.Percent(0.2000), right: @types.Percent(0.1000), top: @types.Percent(0.0500), bottom: @types.Percent(0.1500) },
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 48.0)
  assert_approx(layout.children[1].y, 2.0)
  assert_approx(layout.children[1].width, 28.0)
  assert_approx(layout.children[1].height, 32.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_max_content_single_item_span_2" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MaxContent, @style.MaxContent],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 40.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 20.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 60.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 40.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 20.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 60.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 20.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 0.0)
  assert_approx(layout.children[8].y, 120.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 0.0)
}

///|
test "taffy/grid_max_content_single_item_span_2_gap_fixed" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MaxContent, @style.MaxContent],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    column_gap: @types.Length(20.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 60.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 60.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 20.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 100.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 60.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 20.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 100.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 20.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 0.0)
  assert_approx(layout.children[8].y, 120.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 0.0)
}

///|
test "taffy/grid_max_content_single_item_span_2_gap_percent_definite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    grid_template_columns: [@style.Length(40.0), @style.MaxContent, @style.MaxContent],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    column_gap: @types.Percent(0.2000),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 60.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 60.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 20.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 100.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 60.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 20.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 100.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 20.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 0.0)
  assert_approx(layout.children[8].y, 120.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 0.0)
}

///|
test "taffy/grid_max_content_single_item_span_2_gap_percent_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MaxContent, @style.MaxContent],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    column_gap: @types.Percent(0.2000),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 60.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 60.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 20.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 100.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 60.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 20.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 100.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 20.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 0.0)
  assert_approx(layout.children[8].y, 120.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 0.0)
}

///|
test "taffy/grid_max_width_greater_than_max_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MaxContent],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    max_width: @types.Length(400.0),
    grid_template_columns: [@style.Auto, @style.Auto],
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child0 = @node.Node::with_measure("node", root_child0_child0_style, root_child0_child0_measure)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child1 = @node.Node::with_measure("node", root_child0_child1_style, root_child0_child1_measure)
  root_child0_children.push(root_child0_child1)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 160.0)
  assert_approx(layout.height, 10.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 160.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 80.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[1].x, 80.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 80.0)
  assert_approx(layout.children[0].children[1].height, 10.0)
}

///|
test "taffy/grid_max_width_less_than_max_content_with_min_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    max_width: @types.Length(80.0),
    grid_template_columns: [@style.Auto, @style.Auto],
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child0 = @node.Node::with_measure("node", root_child0_child0_style, root_child0_child0_measure)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child1 = @node.Node::with_measure("node", root_child0_child1_style, root_child0_child1_measure)
  root_child0_children.push(root_child0_child1)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 40.0)
  assert_approx(layout.children[0].children[1].x, 20.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 20.0)
  assert_approx(layout.children[0].children[1].height, 40.0)
}

///|
test "taffy/grid_max_width_smaller_than_max_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MaxContent],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    max_width: @types.Length(80.0),
    grid_template_columns: [@style.Auto, @style.Auto],
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child0 = @node.Node::with_measure("node", root_child0_child0_style, root_child0_child0_measure)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child1 = @node.Node::with_measure("node", root_child0_child1_style, root_child0_child1_measure)
  root_child0_children.push(root_child0_child1)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 80.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 40.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[0].children[1].x, 40.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 40.0)
  assert_approx(layout.children[0].children[1].height, 20.0)
}

///|
test "taffy/grid_max_width_smaller_than_min_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MaxContent],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    max_width: @types.Length(60.0),
    grid_template_columns: [@style.Auto, @style.Auto],
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child0 = @node.Node::with_measure("node", root_child0_child0_style, root_child0_child0_measure)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child1 = @node.Node::with_measure("node", root_child0_child1_style, root_child0_child1_measure)
  root_child0_children.push(root_child0_child1)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 60.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 40.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[0].children[1].x, 40.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 40.0)
  assert_approx(layout.children[0].children[1].height, 20.0)
}

///|
test "taffy/grid_min_content_flex_column" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    flex_direction: @style.Column,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child0 = @node.Node::with_measure("node", root_child0_child0_style, root_child0_child0_measure)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child1 = @node.Node::with_measure("node", root_child0_child1_style, root_child0_child1_measure)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child2 = @node.Node::with_measure("node", root_child0_child2_style, root_child0_child2_measure)
  root_child0_children.push(root_child0_child2)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[0].children[1].x, 0.0)
  assert_approx(layout.children[0].children[1].y, 20.0)
  assert_approx(layout.children[0].children[1].width, 20.0)
  assert_approx(layout.children[0].children[1].height, 20.0)
  assert_approx(layout.children[0].children[2].x, 0.0)
  assert_approx(layout.children[0].children[2].y, 40.0)
  assert_approx(layout.children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[2].height, 20.0)
}

///|
test "taffy/grid_min_content_flex_row" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    flex_direction: @style.Row,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child0 = @node.Node::with_measure("node", root_child0_child0_style, root_child0_child0_measure)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child1 = @node.Node::with_measure("node", root_child0_child1_style, root_child0_child1_measure)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child2 = @node.Node::with_measure("node", root_child0_child2_style, root_child0_child2_measure)
  root_child0_children.push(root_child0_child2)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 60.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 40.0)
  assert_approx(layout.children[0].children[1].x, 20.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 20.0)
  assert_approx(layout.children[0].children[1].height, 40.0)
  assert_approx(layout.children[0].children[2].x, 40.0)
  assert_approx(layout.children[0].children[2].y, 0.0)
  assert_approx(layout.children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[2].height, 40.0)
}

///|
test "taffy/grid_min_content_flex_single_item" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MinContent, @style.Fr(1.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    min_width: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child4_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child4 = @node.Node::with_measure("node", root_child4_style, root_child4_measure)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 10.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 50.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 30.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 40.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 10.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 50.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 30.0)
  assert_approx(layout.children[7].height, 40.0)
}

///|
test "taffy/grid_min_content_flex_single_item_margin_auto" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MinContent, @style.Fr(1.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    min_width: @types.Length(10.0),
    margin: { left: @types.Auto, right: @types.Auto, top: @types.Auto, bottom: @types.Auto },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    margin: { left: @types.Auto, right: @types.Auto, top: @types.Auto, bottom: @types.Auto },
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child4_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child4 = @node.Node::with_measure("node", root_child4_style, root_child4_measure)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 10.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 50.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 30.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 55.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 10.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 40.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 10.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 50.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 30.0)
  assert_approx(layout.children[7].height, 40.0)
}

///|
test "taffy/grid_min_content_flex_single_item_margin_fixed" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MinContent, @style.Fr(1.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    min_width: @types.Length(10.0),
    margin: { left: @types.Length(20.0), right: @types.Length(10.0), top: @types.Length(5.0), bottom: @types.Length(15.0) },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    margin: { left: @types.Length(20.0), right: @types.Length(10.0), top: @types.Length(5.0), bottom: @types.Length(15.0) },
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child4_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child4 = @node.Node::with_measure("node", root_child4_style, root_child4_measure)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 110.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 60.0)
  assert_approx(layout.children[1].y, 5.0)
  assert_approx(layout.children[1].width, 10.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 30.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 60.0)
  assert_approx(layout.children[4].y, 45.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 20.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 40.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 80.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 30.0)
  assert_approx(layout.children[7].height, 40.0)
}

///|
test "taffy/grid_min_content_flex_single_item_margin_percent" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MinContent, @style.Fr(1.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    min_width: @types.Length(10.0),
    margin: { left: @types.Percent(0.2000), right: @types.Percent(0.1000), top: @types.Percent(0.0500), bottom: @types.Percent(0.1500) },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    margin: { left: @types.Percent(0.2000), right: @types.Percent(0.1000), top: @types.Percent(0.0500), bottom: @types.Percent(0.1500) },
    grid_column: { start: @style.Span(2), end: @style.Auto },
  }
  let root_child4_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child4 = @node.Node::with_measure("node", root_child4_style, root_child4_measure)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 42.0)
  assert_approx(layout.children[1].y, 0.5)
  assert_approx(layout.children[1].width, 10.0)
  assert_approx(layout.children[1].height, 38.0)
  assert_approx(layout.children[2].x, 50.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 30.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 48.0)
  assert_approx(layout.children[4].y, 42.0)
  assert_approx(layout.children[4].width, 28.0)
  assert_approx(layout.children[4].height, 32.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 40.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 10.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 50.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 30.0)
  assert_approx(layout.children[7].height, 40.0)
}

///|
test "taffy/grid_min_content_maximum_single_item" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MinMax(@style.MinTrackSizing::Length(0.0), @style.MaxTrackSizing::MinContent), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 60.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 60.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 20.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 60.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_min_content_single_item" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MinContent, @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 60.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 60.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 20.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 60.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_minmax_auto_fixed_10px" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::Auto, @style.MaxTrackSizing::Length(10.0))],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 10.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_auto_max_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::Auto, @style.MaxTrackSizing::MaxContent)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_auto_min_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::Auto, @style.MaxTrackSizing::MinContent)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_auto_percent_definite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::Auto, @style.MaxTrackSizing::Percent(0.2000))],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_auto_percent_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::Auto, @style.MaxTrackSizing::Percent(0.2000))],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 8.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_column_fixed_width_above_range" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(140.0),
    grid_template_columns: [@style.Length(40.0), @style.MinMax(@style.MinTrackSizing::Length(20.0), @style.MaxTrackSizing::Length(40.0)), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 140.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_minmax_column_fixed_width_below_range" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(90.0),
    grid_template_columns: [@style.Length(40.0), @style.MinMax(@style.MinTrackSizing::Length(20.0), @style.MaxTrackSizing::Length(40.0)), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 90.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 60.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 20.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 60.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 20.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 60.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_minmax_column_fixed_width_within_range" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(110.0),
    grid_template_columns: [@style.Length(40.0), @style.MinMax(@style.MinTrackSizing::Length(20.0), @style.MaxTrackSizing::Length(40.0)), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 110.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 30.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 70.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 30.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 70.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 30.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 70.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_minmax_column_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Length(40.0), @style.MinMax(@style.MinTrackSizing::Length(20.0), @style.MaxTrackSizing::Length(40.0)), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_minmax_column_with_auto_fixed" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(60.0),
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::Length(20.0), @style.MaxTrackSizing::Length(40.0)), @style.Auto],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
}

///|
test "taffy/grid_minmax_column_with_fr_fixed" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(60.0),
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::Length(20.0), @style.MaxTrackSizing::Length(40.0)), @style.Fr(1.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 60.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
}

///|
test "taffy/grid_minmax_max_content_1fr" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MaxContent, @style.MaxTrackSizing::Fr(1.0))],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_max_content_auto" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MaxContent, @style.MaxTrackSizing::Auto)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_max_content_fixed_10px" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MaxContent, @style.MaxTrackSizing::Length(10.0))],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_max_content_min_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MaxContent, @style.MaxTrackSizing::MinContent)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_max_content_percent_definite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MaxContent, @style.MaxTrackSizing::Percent(0.2000))],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_max_content_percent_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MaxContent, @style.MaxTrackSizing::Percent(0.2000))],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_min_content_1fr" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MinContent, @style.MaxTrackSizing::Fr(1.0))],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_min_content_auto" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MinContent, @style.MaxTrackSizing::Auto)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_min_content_fixed_10px" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MinContent, @style.MaxTrackSizing::Length(10.0))],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_min_content_max_content" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MinContent, @style.MaxTrackSizing::MaxContent)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_min_content_percent_definite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MinContent, @style.MaxTrackSizing::Percent(0.2000))],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_minmax_min_content_percent_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinMax(@style.MinTrackSizing::MinContent, @style.MaxTrackSizing::Percent(0.2000))],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/grid_out_of_order_items" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_auto_flow: @style.GridAutoFlow::Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    width: @types.Length(35.0),
    height: @types.Length(35.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
    width: @types.Length(10.0),
    height: @types.Length(10.0),
    grid_row: { start: @style.Line(1), end: @style.Auto },
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 80.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 80.0)
  assert_approx(layout.children[2].width, 35.0)
  assert_approx(layout.children[2].height, 35.0)
  assert_approx(layout.children[3].x, 40.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 80.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 0.0)
  assert_approx(layout.children[5].width, 20.0)
  assert_approx(layout.children[5].height, 20.0)
  assert_approx(layout.children[6].x, 40.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 0.0)
  assert_approx(layout.children[7].width, 10.0)
  assert_approx(layout.children[7].height, 10.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_overflow_inline_axis_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 100.0, max_width: 100.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/grid_overflow_inline_axis_scroll" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Scroll,
    overflow_y: @style.Overflow::Scroll,
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 100.0, max_width: 100.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/grid_overflow_inline_axis_visible" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 100.0, max_width: 100.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/grid_overflow_rows" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.MaxContent, @style.Length(10.0), @style.Percent(0.2000)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(4) },
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 160.0, max_width: 320.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 320.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 320.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 43.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 43.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 203.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 246.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 10.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 256.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 64.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 80.0)
  assert_approx(layout.children[5].width, 43.0)
  assert_approx(layout.children[5].height, 0.0)
}

///|
test "taffy/grid_overflow_scrollbars_overridden_by_available_space" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(2.0),
    height: @types.Length(4.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    overflow_x: @style.Overflow::Scroll,
    overflow_y: @style.Overflow::Scroll,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 2.0)
  assert_approx(layout.height, 4.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 2.0)
  assert_approx(layout.children[0].height, 4.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 2.0)
  assert_approx(layout.children[0].children[0].height, 4.0)
}

///|
test "taffy/grid_overflow_scrollbars_overridden_by_max_size" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    overflow_x: @style.Overflow::Scroll,
    overflow_y: @style.Overflow::Scroll,
    max_width: @types.Length(2.0),
    max_height: @types.Length(4.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 0.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
}

///|
test "taffy/grid_overflow_scrollbars_overridden_by_size" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    overflow_x: @style.Overflow::Scroll,
    overflow_y: @style.Overflow::Scroll,
    width: @types.Length(2.0),
    height: @types.Length(4.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 2.0)
  assert_approx(layout.height, 4.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 2.0)
  assert_approx(layout.children[0].height, 4.0)
}

///|
test "taffy/grid_overflow_scrollbars_take_up_space_both_axis" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    overflow_x: @style.Overflow::Scroll,
    overflow_y: @style.Overflow::Scroll,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/grid_overflow_scrollbars_take_up_space_x_axis" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    overflow_x: @style.Overflow::Scroll,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/grid_overflow_scrollbars_take_up_space_y_axis" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    overflow_y: @style.Overflow::Scroll,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/grid_padding_border_overrides_container_max_size" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    max_width: @types.Length(12.0),
    max_height: @types.Length(12.0),
    padding: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    border: { left: @types.Length(7.0), right: @types.Length(3.0), top: @types.Length(1.0), bottom: @types.Length(5.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 22.0)
  assert_approx(layout.height, 14.0)
  assert_approx(layout.children[0].x, 15.0)
  assert_approx(layout.children[0].y, 3.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
}

///|
test "taffy/grid_padding_border_overrides_container_size" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(12.0),
    height: @types.Length(12.0),
    padding: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    border: { left: @types.Length(7.0), right: @types.Length(3.0), top: @types.Length(1.0), bottom: @types.Length(5.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 22.0)
  assert_approx(layout.height, 14.0)
  assert_approx(layout.children[0].x, 15.0)
  assert_approx(layout.children[0].y, 3.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
}

///|
test "taffy/grid_padding_border_overrides_max_size" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    max_width: @types.Length(12.0),
    max_height: @types.Length(12.0),
    padding: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    border: { left: @types.Length(7.0), right: @types.Length(3.0), top: @types.Length(1.0), bottom: @types.Length(5.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 22.0)
  assert_approx(layout.height, 14.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 22.0)
  assert_approx(layout.children[0].height, 14.0)
}

///|
test "taffy/grid_padding_border_overrides_min_size" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    min_width: @types.Length(0.0),
    min_height: @types.Length(0.0),
    padding: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    border: { left: @types.Length(7.0), right: @types.Length(3.0), top: @types.Length(1.0), bottom: @types.Length(5.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 22.0)
  assert_approx(layout.height, 14.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 22.0)
  assert_approx(layout.children[0].height, 14.0)
}

///|
test "taffy/grid_padding_border_overrides_size" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(12.0),
    height: @types.Length(12.0),
    padding: { left: @types.Length(8.0), right: @types.Length(4.0), top: @types.Length(2.0), bottom: @types.Length(6.0) },
    border: { left: @types.Length(7.0), right: @types.Length(3.0), top: @types.Length(1.0), bottom: @types.Length(5.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 22.0)
  assert_approx(layout.height, 14.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 22.0)
  assert_approx(layout.children[0].height, 14.0)
}

///|
test "taffy/grid_percent_item_inside_stretch_item" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Percent(0.5000),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 100.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 100.0)
}

///|
test "taffy/grid_percent_items_nested_inside_stretch_alignment" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    padding: { left: @types.Length(0.0), right: @types.Length(0.0), top: @types.Percent(0.2000), bottom: @types.Length(0.0) },
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 200.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 200.0)
  assert_approx(layout.children[0].children[0].height, 40.0)
}

///|
test "taffy/grid_percent_items_nested_moderate" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    padding: { left: @types.Length(3.0), right: @types.Length(3.0), top: @types.Length(3.0), bottom: @types.Length(3.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Percent(0.5000),
    margin: { left: @types.Length(5.0), right: @types.Length(5.0), top: @types.Length(5.0), bottom: @types.Length(5.0) },
    padding: { left: @types.Percent(0.0300), right: @types.Percent(0.0300), top: @types.Percent(0.0300), bottom: @types.Percent(0.0300) },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Percent(0.4500),
    margin: { left: @types.Percent(0.0500), right: @types.Percent(0.0500), top: @types.Percent(0.0500), bottom: @types.Percent(0.0500) },
    padding: { left: @types.Length(3.0), right: @types.Length(3.0), top: @types.Length(3.0), bottom: @types.Length(3.0) },
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 42.2)
  assert_approx(layout.children[0].x, 8.0)
  assert_approx(layout.children[0].y, 8.0)
  assert_approx(layout.children[0].width, 97.0)
  assert_approx(layout.children[0].height, 26.2)
  assert_approx(layout.children[0].children[0].x, 10.1)
  assert_approx(layout.children[0].children[0].y, 10.1)
  assert_approx(layout.children[0].children[0].width, 38.4)
  assert_approx(layout.children[0].children[0].height, 6.0)
}

///|
test "taffy/grid_percent_items_nested_with_margin" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Percent(0.5000),
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Percent(0.4500),
    margin: { left: @types.Percent(0.0500), right: @types.Percent(0.0500), top: @types.Percent(0.0500), bottom: @types.Percent(0.0500) },
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 10.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 5.0)
  assert_approx(layout.children[0].children[0].y, 5.0)
  assert_approx(layout.children[0].children[0].width, 45.0)
  assert_approx(layout.children[0].children[0].height, 0.0)
}

///|
test "taffy/grid_percent_items_nested_with_padding_margin" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_rows: [@style.Fr(1.0), @style.Fr(4.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    min_width: @types.Percent(0.6000),
    margin: { left: @types.Length(5.0), right: @types.Length(5.0), top: @types.Length(5.0), bottom: @types.Length(5.0) },
    padding: { left: @types.Length(3.0), right: @types.Length(3.0), top: @types.Length(3.0), bottom: @types.Length(3.0) },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Percent(0.5000),
    margin: { left: @types.Length(5.0), right: @types.Length(5.0), top: @types.Length(5.0), bottom: @types.Length(5.0) },
    padding: { left: @types.Percent(0.0300), right: @types.Percent(0.0300), top: @types.Percent(0.0300), bottom: @types.Percent(0.0300) },
  }
  let root_child0_child0_children : Array[@node.Node] = []
  let root_child0_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Percent(0.4500),
    margin: { left: @types.Percent(0.0500), right: @types.Percent(0.0500), top: @types.Percent(0.0500), bottom: @types.Percent(0.0500) },
    padding: { left: @types.Length(3.0), right: @types.Length(3.0), top: @types.Length(3.0), bottom: @types.Length(3.0) },
  }
  let root_child0_child0_child0 = @node.Node::leaf("node", root_child0_child0_child0_style)
  root_child0_child0_children.push(root_child0_child0_child0)
  let root_child0_child0 = @node.Node::new("node", root_child0_child0_style, root_child0_child0_children)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 5.0)
  assert_approx(layout.children[0].y, 5.0)
  assert_approx(layout.children[0].width, 190.0)
  assert_approx(layout.children[0].height, 41.1)
  assert_approx(layout.children[0].children[0].x, 8.0)
  assert_approx(layout.children[0].children[0].y, 8.0)
  assert_approx(layout.children[0].children[0].width, 92.0)
  assert_approx(layout.children[0].children[0].height, 25.1)
  assert_approx(layout.children[0].children[0].children[0].x, 9.6)
  assert_approx(layout.children[0].children[0].children[0].y, 9.6)
  assert_approx(layout.children[0].children[0].children[0].width, 36.4)
  assert_approx(layout.children[0].children[0].children[0].height, 6.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 51.1)
  assert_approx(layout.children[1].width, 200.0)
  assert_approx(layout.children[1].height, 148.9)
}

///|
test "taffy/grid_percent_items_width_and_margin" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    padding: { left: @types.Length(3.0), right: @types.Length(3.0), top: @types.Length(3.0), bottom: @types.Length(3.0) },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Percent(0.4500),
    margin: { left: @types.Percent(0.0500), right: @types.Percent(0.0500), top: @types.Percent(0.0500), bottom: @types.Percent(0.0500) },
    padding: { left: @types.Length(3.0), right: @types.Length(3.0), top: @types.Length(3.0), bottom: @types.Length(3.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 31.4)
  assert_approx(layout.children[0].x, 12.7)
  assert_approx(layout.children[0].y, 12.7)
  assert_approx(layout.children[0].width, 87.3)
  assert_approx(layout.children[0].height, 6.0)
}

///|
test "taffy/grid_percent_items_width_and_padding" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Percent(0.5000),
    padding: { left: @types.Percent(0.0300), right: @types.Percent(0.0300), top: @types.Percent(0.0300), bottom: @types.Percent(0.0300) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 12.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 12.0)
}

///|
test "taffy/grid_percent_tracks_definite_overflow" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(60.0),
    grid_template_columns: [@style.Percent(0.4000), @style.Percent(0.4000), @style.Percent(0.4000)],
    grid_template_rows: [@style.Percent(0.5000), @style.Percent(0.8000)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 60.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 48.0)
  assert_approx(layout.children[0].height, 30.0)
  assert_approx(layout.children[1].x, 48.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 48.0)
  assert_approx(layout.children[1].height, 30.0)
  assert_approx(layout.children[2].x, 96.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 48.0)
  assert_approx(layout.children[2].height, 30.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 30.0)
  assert_approx(layout.children[3].width, 48.0)
  assert_approx(layout.children[3].height, 48.0)
  assert_approx(layout.children[4].x, 48.0)
  assert_approx(layout.children[4].y, 30.0)
  assert_approx(layout.children[4].width, 48.0)
  assert_approx(layout.children[4].height, 48.0)
  assert_approx(layout.children[5].x, 96.0)
  assert_approx(layout.children[5].y, 30.0)
  assert_approx(layout.children[5].width, 48.0)
  assert_approx(layout.children[5].height, 48.0)
}

///|
test "taffy/grid_percent_tracks_definite_underflow" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(60.0),
    grid_template_columns: [@style.Percent(0.1000), @style.Percent(0.2000), @style.Percent(0.3000)],
    grid_template_rows: [@style.Percent(0.3000), @style.Percent(0.6000)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 60.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 12.0)
  assert_approx(layout.children[0].height, 18.0)
  assert_approx(layout.children[1].x, 12.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 24.0)
  assert_approx(layout.children[1].height, 18.0)
  assert_approx(layout.children[2].x, 36.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 36.0)
  assert_approx(layout.children[2].height, 18.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 18.0)
  assert_approx(layout.children[3].width, 12.0)
  assert_approx(layout.children[3].height, 36.0)
  assert_approx(layout.children[4].x, 12.0)
  assert_approx(layout.children[4].y, 18.0)
  assert_approx(layout.children[4].width, 24.0)
  assert_approx(layout.children[4].height, 36.0)
  assert_approx(layout.children[5].x, 36.0)
  assert_approx(layout.children[5].y, 18.0)
  assert_approx(layout.children[5].width, 36.0)
  assert_approx(layout.children[5].height, 36.0)
}

///|
test "taffy/grid_percent_tracks_indefinite_only" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Percent(0.1000), @style.Percent(0.2000), @style.Percent(0.3000)],
    grid_template_rows: [@style.Percent(0.3000), @style.Percent(0.6000)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 0.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 0.0)
  assert_approx(layout.children[2].height, 0.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 0.0)
  assert_approx(layout.children[3].width, 0.0)
  assert_approx(layout.children[3].height, 0.0)
  assert_approx(layout.children[4].x, 0.0)
  assert_approx(layout.children[4].y, 0.0)
  assert_approx(layout.children[4].width, 0.0)
  assert_approx(layout.children[4].height, 0.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 0.0)
  assert_approx(layout.children[5].width, 0.0)
  assert_approx(layout.children[5].height, 0.0)
}

///|
test "taffy/grid_percent_tracks_indefinite_with_content_overflow" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Percent(0.4000), @style.Percent(0.4000), @style.Percent(0.4000)],
    grid_template_rows: [@style.Percent(0.5000), @style.Percent(0.8000)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 100.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 50.0)
  assert_approx(layout.children[2].x, 40.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 50.0)
  assert_approx(layout.children[3].x, 80.0)
  assert_approx(layout.children[3].y, 0.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 50.0)
  assert_approx(layout.children[4].x, 0.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 80.0)
  assert_approx(layout.children[5].x, 40.0)
  assert_approx(layout.children[5].y, 50.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 80.0)
  assert_approx(layout.children[6].x, 80.0)
  assert_approx(layout.children[6].y, 50.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 80.0)
}

///|
test "taffy/grid_percent_tracks_indefinite_with_content_underflow" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Percent(0.1000), @style.Percent(0.2000), @style.Percent(0.3000)],
    grid_template_rows: [@style.Percent(0.3000), @style.Percent(0.6000)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 100.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 10.0)
  assert_approx(layout.children[1].height, 30.0)
  assert_approx(layout.children[2].x, 10.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 30.0)
  assert_approx(layout.children[3].x, 30.0)
  assert_approx(layout.children[3].y, 0.0)
  assert_approx(layout.children[3].width, 30.0)
  assert_approx(layout.children[3].height, 30.0)
  assert_approx(layout.children[4].x, 0.0)
  assert_approx(layout.children[4].y, 30.0)
  assert_approx(layout.children[4].width, 10.0)
  assert_approx(layout.children[4].height, 60.0)
  assert_approx(layout.children[5].x, 10.0)
  assert_approx(layout.children[5].y, 30.0)
  assert_approx(layout.children[5].width, 20.0)
  assert_approx(layout.children[5].height, 60.0)
  assert_approx(layout.children[6].x, 30.0)
  assert_approx(layout.children[6].y, 30.0)
  assert_approx(layout.children[6].width, 30.0)
  assert_approx(layout.children[6].height, 60.0)
}

///|
test "taffy/grid_placement_auto_negative" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(-5), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / -5"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_row: { start: @style.Line(2), end: @style.Auto },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 20.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_placement_definite_in_secondary_axis_with_fully_definite_negative" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_row: { start: @style.Line(2), end: @style.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(-4), end: @style.Auto },
    grid_row: { start: @style.Line(2), end: @style.Auto },
    grid_area: Some("2 / -4"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_row: { start: @style.Line(1), end: @style.Auto },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 40.0)
  assert_approx(layout.children[0].y, 40.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_placement_definite_primary" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [@style.Percent(0.3300), @style.Percent(0.7400)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 66.0)
  assert_approx(layout.children[0].height, 66.7)
  assert_approx(layout.children[1].x, 66.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 148.0)
  assert_approx(layout.children[1].height, 66.7)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 66.7)
  assert_approx(layout.children[2].width, 66.0)
  assert_approx(layout.children[2].height, 66.7)
  assert_approx(layout.children[3].x, 66.0)
  assert_approx(layout.children[3].y, 66.7)
  assert_approx(layout.children[3].width, 148.0)
  assert_approx(layout.children[3].height, 66.7)
  assert_approx(layout.children[4].x, 0.0)
  assert_approx(layout.children[4].y, 133.3)
  assert_approx(layout.children[4].width, 66.0)
  assert_approx(layout.children[4].height, 66.7)
}

///|
test "taffy/grid_relative_all_sides" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(40.0),
    inset: { left: @types.Length(10.0), right: @types.Length(10.0), top: @types.Length(10.0), bottom: @types.Length(10.0) },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 100.0)
}

///|
test "taffy/grid_relayout_vertical_text" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 10.0, max_width: 10.0, min_height: 140.0, max_height: 140.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 60.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 20.0)
}

///|
test "taffy/grid_repeat_integer" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Repeat(@style.Count(3), [@style.SingleTrackSizing::Length(40.0)])],
    grid_template_rows: [@style.Repeat(@style.Count(3), [@style.SingleTrackSizing::Length(40.0)])],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_repeat_mixed" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Repeat(@style.Count(1), [@style.SingleTrackSizing::Length(40.0)]), @style.Repeat(@style.AutoFill, [@style.SingleTrackSizing::Length(40.0)])],
    grid_template_rows: [@style.Length(40.0), @style.Repeat(@style.Count(1), [@style.SingleTrackSizing::Length(40.0)]), @style.Repeat(@style.AutoFill, [@style.SingleTrackSizing::Length(40.0)])],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 40.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 40.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 80.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 40.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 80.0)
  assert_approx(layout.children[6].width, 40.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 40.0)
  assert_approx(layout.children[7].y, 80.0)
  assert_approx(layout.children[7].width, 40.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 80.0)
  assert_approx(layout.children[8].y, 80.0)
  assert_approx(layout.children[8].width, 40.0)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_size_child_fixed_tracks" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    align_self: @style.AlignSelf::Start,
    justify_self: @style.AlignSelf::Start,
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    align_self: @style.AlignSelf::Start,
    justify_self: @style.AlignSelf::Start,
  }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 30.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child1 = @node.Node::with_measure("node", root_child1_style, root_child1_measure)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    align_self: @style.AlignSelf::Start,
    justify_self: @style.AlignSelf::Start,
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    align_self: @style.AlignSelf::Start,
    justify_self: @style.AlignSelf::Start,
  }
  let root_child3_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child3 = @node.Node::with_measure("node", root_child3_style, root_child3_measure)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    max_width: @types.Length(30.0),
    align_self: @style.AlignSelf::Start,
    justify_self: @style.AlignSelf::Start,
  }
  let root_child4_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child4 = @node.Node::with_measure("node", root_child4_style, root_child4_measure)
  root_children.push(root_child4)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 120.0)
  assert_approx(layout.height, 120.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[2].x, 80.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 20.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 20.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 40.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 30.0)
  assert_approx(layout.children[4].height, 40.0)
}

///|
test "taffy/grid_span_13_most_non_flex_with_minmax_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.MaxContent, @style.FitContentLength(20.0), @style.Auto, @style.Length(10.0), @style.Percent(0.2000), @style.MinMax(@style.MinTrackSizing::Length(2.0), @style.MaxTrackSizing::Auto), @style.MinMax(@style.MinTrackSizing::Length(2.0), @style.MaxTrackSizing::Length(4.0)), @style.MinMax(@style.MinTrackSizing::Length(2.0), @style.MaxTrackSizing::MinContent), @style.MinMax(@style.MinTrackSizing::Length(2.0), @style.MaxTrackSizing::MaxContent), @style.MinMax(@style.MinTrackSizing::MinContent, @style.MaxTrackSizing::MaxContent), @style.MinMax(@style.MinTrackSizing::MinContent, @style.MaxTrackSizing::Auto), @style.MinMax(@style.MinTrackSizing::MaxContent, @style.MaxTrackSizing::Auto)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(13) },
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 160.0, max_width: 320.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root_child9_style = {
    ..@style.Style::default(),
  }
  let root_child9 = @node.Node::leaf("node", root_child9_style)
  root_children.push(root_child9)
  let root_child10_style = {
    ..@style.Style::default(),
  }
  let root_child10 = @node.Node::leaf("node", root_child10_style)
  root_children.push(root_child10)
  let root_child11_style = {
    ..@style.Style::default(),
  }
  let root_child11 = @node.Node::leaf("node", root_child11_style)
  root_children.push(root_child11)
  let root_child12_style = {
    ..@style.Style::default(),
  }
  let root_child12 = @node.Node::leaf("node", root_child12_style)
  root_children.push(root_child12)
  let root_child13_style = {
    ..@style.Style::default(),
  }
  let root_child13 = @node.Node::leaf("node", root_child13_style)
  root_children.push(root_child13)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 322.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 322.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 11.1)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 11.1)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 91.1)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 102.2)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 11.1)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 113.3)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 11.1)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 124.3)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 10.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 134.3)
  assert_approx(layout.children[6].y, 40.0)
  assert_approx(layout.children[6].width, 64.4)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 198.7)
  assert_approx(layout.children[7].y, 40.0)
  assert_approx(layout.children[7].width, 2.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 200.7)
  assert_approx(layout.children[8].y, 40.0)
  assert_approx(layout.children[8].width, 4.0)
  assert_approx(layout.children[8].height, 40.0)
  assert_approx(layout.children[9].x, 204.7)
  assert_approx(layout.children[9].y, 40.0)
  assert_approx(layout.children[9].width, 2.0)
  assert_approx(layout.children[9].height, 40.0)
  assert_approx(layout.children[10].x, 206.7)
  assert_approx(layout.children[10].y, 40.0)
  assert_approx(layout.children[10].width, 2.0)
  assert_approx(layout.children[10].height, 40.0)
  assert_approx(layout.children[11].x, 208.7)
  assert_approx(layout.children[11].y, 40.0)
  assert_approx(layout.children[11].width, 11.1)
  assert_approx(layout.children[11].height, 40.0)
  assert_approx(layout.children[12].x, 219.8)
  assert_approx(layout.children[12].y, 40.0)
  assert_approx(layout.children[12].width, 11.1)
  assert_approx(layout.children[12].height, 40.0)
  assert_approx(layout.children[13].x, 230.9)
  assert_approx(layout.children[13].y, 40.0)
  assert_approx(layout.children[13].width, 91.1)
  assert_approx(layout.children[13].height, 40.0)
}

///|
test "taffy/grid_span_13_most_non_flex_with_minmax_indefinite_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.MaxContent, @style.FitContentLength(20.0), @style.Auto, @style.Length(10.0), @style.Percent(0.2000), @style.MinMax(@style.MinTrackSizing::Length(2.0), @style.MaxTrackSizing::Auto), @style.MinMax(@style.MinTrackSizing::Length(2.0), @style.MaxTrackSizing::Length(4.0)), @style.MinMax(@style.MinTrackSizing::Length(2.0), @style.MaxTrackSizing::MinContent), @style.MinMax(@style.MinTrackSizing::Length(2.0), @style.MaxTrackSizing::MaxContent), @style.MinMax(@style.MinTrackSizing::MinContent, @style.MaxTrackSizing::MaxContent), @style.MinMax(@style.MinTrackSizing::MinContent, @style.MaxTrackSizing::Auto), @style.MinMax(@style.MinTrackSizing::MaxContent, @style.MaxTrackSizing::Auto)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
    grid_column: { start: @style.Line(1), end: @style.Span(13) },
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 160.0, max_width: 320.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root_child9_style = {
    ..@style.Style::default(),
  }
  let root_child9 = @node.Node::leaf("node", root_child9_style)
  root_children.push(root_child9)
  let root_child10_style = {
    ..@style.Style::default(),
  }
  let root_child10 = @node.Node::leaf("node", root_child10_style)
  root_children.push(root_child10)
  let root_child11_style = {
    ..@style.Style::default(),
  }
  let root_child11 = @node.Node::leaf("node", root_child11_style)
  root_children.push(root_child11)
  let root_child12_style = {
    ..@style.Style::default(),
  }
  let root_child12 = @node.Node::leaf("node", root_child12_style)
  root_children.push(root_child12)
  let root_child13_style = {
    ..@style.Style::default(),
  }
  let root_child13 = @node.Node::leaf("node", root_child13_style)
  root_children.push(root_child13)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 322.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 322.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 15.5)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 15.5)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 95.5)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 111.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 0.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 111.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 0.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 111.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 10.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 121.0)
  assert_approx(layout.children[6].y, 40.0)
  assert_approx(layout.children[6].width, 64.4)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 185.4)
  assert_approx(layout.children[7].y, 40.0)
  assert_approx(layout.children[7].width, 2.0)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 187.4)
  assert_approx(layout.children[8].y, 40.0)
  assert_approx(layout.children[8].width, 4.0)
  assert_approx(layout.children[8].height, 40.0)
  assert_approx(layout.children[9].x, 191.4)
  assert_approx(layout.children[9].y, 40.0)
  assert_approx(layout.children[9].width, 2.0)
  assert_approx(layout.children[9].height, 40.0)
  assert_approx(layout.children[10].x, 193.4)
  assert_approx(layout.children[10].y, 40.0)
  assert_approx(layout.children[10].width, 2.0)
  assert_approx(layout.children[10].height, 40.0)
  assert_approx(layout.children[11].x, 195.4)
  assert_approx(layout.children[11].y, 40.0)
  assert_approx(layout.children[11].width, 15.5)
  assert_approx(layout.children[11].height, 40.0)
  assert_approx(layout.children[12].x, 210.9)
  assert_approx(layout.children[12].y, 40.0)
  assert_approx(layout.children[12].width, 15.5)
  assert_approx(layout.children[12].height, 40.0)
  assert_approx(layout.children[13].x, 226.5)
  assert_approx(layout.children[13].y, 40.0)
  assert_approx(layout.children[13].width, 95.5)
  assert_approx(layout.children[13].height, 40.0)
}

///|
test "taffy/grid_span_2_max_content_auto_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MaxContent, @style.Auto],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 60.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 60.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 80.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_max_content_auto_indefinite_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MaxContent, @style.Auto],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 0.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 40.0)
}

///|
test "taffy/grid_span_2_max_content_fit_content_10px_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MaxContent, @style.FitContentLength(10.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 60.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 60.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 80.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_max_content_fit_content_10px_indefinite_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MaxContent, @style.FitContentLength(10.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 80.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 80.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_max_content_fit_content_80px_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MaxContent, @style.FitContentLength(80.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 60.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 60.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 80.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_max_content_fit_content_80px_indefinite_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MaxContent, @style.FitContentLength(80.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 80.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 80.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 80.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_max_content_max_content_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MaxContent, @style.MaxContent],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 80.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_min_content_auto_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.Auto],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 80.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/grid_span_2_min_content_auto_indefinite_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.Auto],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 80.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/grid_span_2_min_content_fit_content_10px_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.FitContentLength(10.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_min_content_fit_content_10px_indefinite_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.FitContentLength(10.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 10.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_min_content_fit_content_30px_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.FitContentLength(30.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 30.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_min_content_fit_content_30px_indefinite_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.FitContentLength(30.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 70.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 30.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 70.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_min_content_fit_content_80px_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.FitContentLength(80.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 80.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_min_content_fit_content_80px_indefinite_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.FitContentLength(80.0)],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 40.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 80.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_min_content_max_content_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.MaxContent],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 80.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 80.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_2_min_content_min_content_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.MinContent],
    grid_template_rows: [@style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(2), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Auto },
    grid_area: Some("1 / 1 / auto / span 2"),
  }
  let root_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 80.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child2 = @node.Node::with_measure("node", root_child2_style, root_child2_measure)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 20.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 40.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_span_6_all_non_flex_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.MaxContent, @style.FitContentLength(20.0), @style.Auto, @style.Length(10.0), @style.Percent(0.2000)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(6) },
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 80.0, max_width: 160.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 160.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 160.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 9.5)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 9.5)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 89.5)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 99.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 9.5)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 108.5)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 9.5)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 118.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 10.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 128.0)
  assert_approx(layout.children[6].y, 40.0)
  assert_approx(layout.children[6].width, 32.0)
  assert_approx(layout.children[6].height, 40.0)
}

///|
test "taffy/grid_span_6_all_non_flex_indefinite_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.MaxContent, @style.FitContentLength(20.0), @style.Auto, @style.Length(10.0), @style.Percent(0.2000)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @style.Overflow::Hidden,
    overflow_y: @style.Overflow::Hidden,
    grid_column: { start: @style.Line(1), end: @style.Span(6) },
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 80.0, max_width: 160.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 160.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 160.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 19.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 19.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 99.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 118.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 0.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 118.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 0.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 118.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 10.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 128.0)
  assert_approx(layout.children[6].y, 40.0)
  assert_approx(layout.children[6].width, 32.0)
  assert_approx(layout.children[6].height, 40.0)
}

///|
test "taffy/grid_span_8_all_track_types_indefinite" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.MinContent, @style.MaxContent, @style.FitContentLength(20.0), @style.Auto, @style.Length(10.0), @style.Percent(0.2000), @style.Fr(1.0), @style.Fr(2.0)],
    grid_template_rows: [@style.Length(40.0), @style.Length(40.0)],
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    grid_column: { start: @style.Line(1), end: @style.Span(8) },
  }
  let root_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 80.0, max_width: 160.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0 = @node.Node::with_measure("node", root_child0_style, root_child0_measure)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root_child7_style = {
    ..@style.Style::default(),
  }
  let root_child7 = @node.Node::leaf("node", root_child7_style)
  root_children.push(root_child7)
  let root_child8_style = {
    ..@style.Style::default(),
  }
  let root_child8 = @node.Node::leaf("node", root_child8_style)
  root_children.push(root_child8)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 160.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 160.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 0.0)
  assert_approx(layout.children[2].height, 40.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 0.0)
  assert_approx(layout.children[3].height, 40.0)
  assert_approx(layout.children[4].x, 0.0)
  assert_approx(layout.children[4].y, 40.0)
  assert_approx(layout.children[4].width, 0.0)
  assert_approx(layout.children[4].height, 40.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 40.0)
  assert_approx(layout.children[5].width, 10.0)
  assert_approx(layout.children[5].height, 40.0)
  assert_approx(layout.children[6].x, 10.0)
  assert_approx(layout.children[6].y, 40.0)
  assert_approx(layout.children[6].width, 32.0)
  assert_approx(layout.children[6].height, 40.0)
  assert_approx(layout.children[7].x, 42.0)
  assert_approx(layout.children[7].y, 40.0)
  assert_approx(layout.children[7].width, 39.3)
  assert_approx(layout.children[7].height, 40.0)
  assert_approx(layout.children[8].x, 81.3)
  assert_approx(layout.children[8].y, 40.0)
  assert_approx(layout.children[8].width, 78.7)
  assert_approx(layout.children[8].height, 40.0)
}

///|
test "taffy/grid_taffy_issue_624" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    width: @types.Length(320.0),
    height: @types.Length(640.0),
    grid_template_columns: [@style.Auto, @style.Auto, @style.Fr(1.0)],
    grid_template_rows: [@style.Auto, @style.Auto, @style.Auto, @style.Fr(1.0)],
    justify_content: @style.Start,
    justify_items: @style.Start,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
    grid_column: { start: @style.Line(1), end: @style.Auto },
    grid_row: { start: @style.Line(1), end: @style.Span(2) },
    grid_area: Some("1 / 1 / span 2"),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(40.0),
    height: @types.Length(30.0),
    grid_column: { start: @style.Line(2), end: @style.Span(2) },
    grid_row: { start: @style.Line(1), end: @style.Span(2) },
    grid_area: Some("1 / 2 / span 2 / span 2"),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    width: @types.Length(120.0),
    height: @types.Length(20.0),
    grid_column: { start: @style.Line(1), end: @style.Span(2) },
    grid_row: { start: @style.Line(3), end: @style.Span(1) },
    grid_area: Some("3 / 1 / span 1 / span 2"),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 320.0)
  assert_approx(layout.height, 640.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 100.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 30.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 50.0)
  assert_approx(layout.children[2].width, 120.0)
  assert_approx(layout.children[2].height, 20.0)
}
