// Auto-generated from taffy test fixtures
// DO NOT EDIT - regenerate with: npm run gen-moonbit-tests
// Uses assert_approx from main gen_test.mbt

///|
test "taffy/blockflex_block_in_flex_column" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    width: @types.Length(200.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = { ..@style.Style::default() }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let layout = compute_grid_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 200.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 0.0)
}

///|
test "taffy/blockflex_block_in_flex_row" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    width: @types.Length(200.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = { ..@style.Style::default() }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let layout = compute_grid_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/blockflex_flex_in_block" {
  let root_style = { ..@style.Style::default(), width: @types.Length(200.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = { ..@style.Style::default(), display: @style.Flex }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let layout = compute_grid_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 70.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 200.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
}

///|
test "taffy/blockflex_margin_y_collapse_through_blocked_by_flex" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Auto,
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(10.0),
      bottom: @types.Auto,
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let layout = compute_grid_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 30.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/blockflex_margin_y_first_child_collapse_blocked_by_flex" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(10.0),
      bottom: @types.Auto,
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(10.0),
      bottom: @types.Auto,
    },
  }
  let root_child0_child0_children : Array[@node.Node] = []
  let root_child0_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0_child0_child0 = @node.Node::leaf(
    "node", root_child0_child0_child0_style,
  )
  root_child0_child0_children.push(root_child0_child0_child0)
  let root_child0_child0 = @node.Node::new(
    "node", root_child0_child0_style, root_child0_child0_children,
  )
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let layout = compute_grid_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 10.0)
  assert_approx(layout.children[0].children[0].width, 0.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 0.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/blockflex_margin_y_last_child_collapse_blocked_by_flex" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Auto,
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Auto,
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_child0_children : Array[@node.Node] = []
  let root_child0_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0_child0_child0 = @node.Node::leaf(
    "node", root_child0_child0_child0_style,
  )
  root_child0_child0_children.push(root_child0_child0_child0)
  let root_child0_child0 = @node.Node::new(
    "node", root_child0_child0_style, root_child0_child0_children,
  )
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let layout = compute_grid_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 0.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 0.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/blockflex_overflow_hidden" {
  let root_style = {
    ..@style.Style::default(),
    display: @style.Flex,
    width: @types.Length(20.0),
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
      { min_width: 40.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root_child0 = @node.Node::with_measure(
    "node", root_child0_style, root_child0_measure,
  )
  root_children.push(root_child0)
  let root_child1_style = { ..@style.Style::default() }
  let root_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 60.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root_child1 = @node.Node::with_measure(
    "node", root_child1_style, root_child1_measure,
  )
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let layout = compute_grid_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 40.0)
  assert_approx(layout.children[1].height, 50.0)
}
