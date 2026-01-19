// Auto-generated from taffy test fixtures
// DO NOT EDIT - regenerate with: npm run gen-moonbit-tests

///|
test "taffy/absolute_correct_cross_child_size_with_percentage" {
  let root_style = {
    ..@style.Style::default(),
    position: @types.Position::Relative,
    width: @types.Length(300.0),
    height: @types.Length(110.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @types.Flex,
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(50.0),
      right: @types.Auto,
      top: @types.Length(40.0),
      bottom: @types.Auto,
    },
    flex_direction: @types.Column,
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
    display: @types.Flex,
    width: @types.Percent(1.0000),
    height: @types.Length(10.0),
  }
  let root_child0_child2_children : Array[@node.Node] = []
  let root_child0_child2_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  }
  let root_child0_child2_child0 = @node.Node::leaf(
    "node", root_child0_child2_child0_style,
  )
  root_child0_child2_children.push(root_child0_child2_child0)
  let root_child0_child2 = @node.Node::new(
    "node", root_child0_child2_style, root_child0_child2_children,
  )
  root_child0_children.push(root_child0_child2)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_absolute_aspect_ratio_aspect_ratio_overrides_height_of_full_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Percent(0.0500),
      right: @types.Percent(0.0500),
      top: @types.Percent(0.0500),
      bottom: @types.Percent(0.0500),
    },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_absolute_aspect_ratio_fill_height" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Percent(0.5000),
    inset: {
      left: @types.Percent(0.0500),
      right: @types.Auto,
      top: @types.Percent(0.0500),
      bottom: @types.Auto,
    },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 20.0)
  assert_approx(layout.children[0].y, 15.0)
  assert_approx(layout.children[0].width, 200.0)
  assert_approx(layout.children[0].height, 66.7)
}

///|
test "taffy/block_absolute_aspect_ratio_fill_height_from_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Percent(0.1000),
      right: @types.Percent(0.1000),
      top: @types.Percent(0.0500),
      bottom: @types.Auto,
    },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_absolute_aspect_ratio_fill_max_height" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    max_width: @types.Length(50.0),
    aspect_ratio: Some(3.0000),
  }
  let root_child0_measure = @types.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      {
        min_width: 40.0,
        max_width: 360.0,
        min_height: 120.0,
        max_height: 120.0,
      }
    },
  }
  let root_child0 = @node.Node::with_measure(
    "node", root_child0_style, root_child0_measure,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 16.7)
}

///|
test "taffy/block_absolute_aspect_ratio_fill_max_width" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    max_height: @types.Length(50.0),
    aspect_ratio: Some(0.5000),
  }
  let root_child0_measure = @types.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      {
        min_width: 40.0,
        max_width: 360.0,
        min_height: 720.0,
        max_height: 720.0,
      }
    },
  }
  let root_child0 = @node.Node::with_measure(
    "node", root_child0_style, root_child0_measure,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 25.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_aspect_ratio_fill_min_height" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    min_width: @types.Length(50.0),
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 16.7)
}

///|
test "taffy/block_absolute_aspect_ratio_fill_min_width" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    min_height: @types.Length(50.0),
    aspect_ratio: Some(0.5000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 25.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_aspect_ratio_fill_width" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    height: @types.Percent(0.2000),
    inset: {
      left: @types.Percent(0.0500),
      right: @types.Auto,
      top: @types.Percent(0.0500),
      bottom: @types.Auto,
    },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 400.0)
  assert_approx(layout.height, 300.0)
  assert_approx(layout.children[0].x, 20.0)
  assert_approx(layout.children[0].y, 15.0)
  assert_approx(layout.children[0].width, 180.0)
  assert_approx(layout.children[0].height, 60.0)
}

///|
test "taffy/block_absolute_aspect_ratio_fill_width_from_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Percent(0.3000),
      bottom: @types.Percent(0.5000),
    },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_absolute_aspect_ratio_height_overrides_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    height: @types.Percent(0.1000),
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Percent(0.3000),
      bottom: @types.Percent(0.5000),
    },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_absolute_aspect_ratio_width_overrides_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Percent(0.4000),
    inset: {
      left: @types.Percent(0.1000),
      right: @types.Percent(0.1000),
      top: @types.Percent(0.0500),
      bottom: @types.Auto,
    },
    aspect_ratio: Some(3.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_absolute_child_with_margin_x" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(37.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(9.0),
    height: @types.Length(9.0),
    margin: {
      left: @types.Length(7.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(9.0),
    height: @types.Length(9.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(7.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(9.0),
    height: @types.Length(9.0),
    margin: {
      left: @types.Length(10.0),
      right: @types.Length(5.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 37.0)
  assert_approx(layout.children[0].x, 7.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 9.0)
  assert_approx(layout.children[0].height, 9.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 9.0)
  assert_approx(layout.children[1].height, 9.0)
  assert_approx(layout.children[2].x, 10.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 9.0)
  assert_approx(layout.children[2].height, 9.0)
}

///|
test "taffy/block_absolute_child_with_margin_y" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(37.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(9.0),
    height: @types.Length(9.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(7.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(9.0),
    height: @types.Length(9.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(7.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(9.0),
    height: @types.Length(9.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 37.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 7.0)
  assert_approx(layout.children[0].width, 9.0)
  assert_approx(layout.children[0].height, 9.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 9.0)
  assert_approx(layout.children[1].height, 9.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 9.0)
  assert_approx(layout.children[2].height, 9.0)
}

///|
test "taffy/block_absolute_child_with_max_height" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    max_height: @types.Length(100.0),
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Auto,
      bottom: @types.Length(20.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(150.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 80.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 100.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 100.0)
  assert_approx(layout.children[0].children[0].height, 150.0)
}

///|
test "taffy/block_absolute_layout_child_order" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(110.0),
    height: @types.Length(100.0),
    justify_content: @types.Center,
    align_items: @types.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(40.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(60.0),
    height: @types.Length(40.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    width: @types.Length(60.0),
    height: @types.Length(40.0),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 110.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 60.0)
  assert_approx(layout.children[0].height, 40.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 40.0)
  assert_approx(layout.children[1].width, 60.0)
  assert_approx(layout.children[1].height, 40.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 60.0)
  assert_approx(layout.children[2].height, 40.0)
}

///|
test "taffy/block_absolute_layout_no_size" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
}

///|
test "taffy/block_absolute_layout_percentage_bottom_based_on_parent_height" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Percent(0.5000),
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Auto,
      bottom: @types.Percent(0.5000),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(10.0),
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Percent(0.1000),
      bottom: @types.Percent(0.1000),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 100.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 90.0)
  assert_approx(layout.children[1].width, 10.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 10.0)
  assert_approx(layout.children[2].height, 160.0)
}

///|
test "taffy/block_absolute_layout_percentage_height" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(10.0),
    height: @types.Percent(0.5000),
    inset: {
      left: @types.Length(10.0),
      right: @types.Auto,
      top: @types.Length(10.0),
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_layout_row_width_height_end_bottom" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
    inset: {
      left: @types.Auto,
      right: @types.Length(10.0),
      top: @types.Auto,
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 80.0)
  assert_approx(layout.children[0].y, 80.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 10.0)
}

///|
test "taffy/block_absolute_layout_start_top_end_bottom" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 80.0)
  assert_approx(layout.children[0].height, 80.0)
}

///|
test "taffy/block_absolute_layout_width_height_end_bottom" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
    inset: {
      left: @types.Auto,
      right: @types.Length(10.0),
      top: @types.Auto,
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 80.0)
  assert_approx(layout.children[0].y, 80.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 10.0)
}

///|
test "taffy/block_absolute_layout_width_height_start_top" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
    inset: {
      left: @types.Length(10.0),
      right: @types.Auto,
      top: @types.Length(10.0),
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 10.0)
}

///|
test "taffy/block_absolute_layout_width_height_start_top_end_bottom" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 10.0)
}

///|
test "taffy/block_absolute_layout_within_border" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    padding: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
    border: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    inset: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    inset: {
      left: @types.Auto,
      right: @types.Length(0.0),
      top: @types.Auto,
      bottom: @types.Length(0.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
    inset: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Auto,
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
    inset: {
      left: @types.Auto,
      right: @types.Length(0.0),
      top: @types.Auto,
      bottom: @types.Length(0.0),
    },
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_absolute_margin_auto_bottom_and_top_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Auto,
      bottom: @types.Auto,
    },
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(10.0),
      bottom: @types.Length(20.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 70.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_bottom_and_top_without_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_bottom_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Auto,
    },
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(10.0),
      bottom: @types.Length(20.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_bottom_without_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_left_and_right_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(20.0),
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 70.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_left_and_right_without_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_left_child_bigger_than_parent_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(52.0),
    height: @types.Length(52.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(72.0),
    height: @types.Length(72.0),
    margin: {
      left: @types.Auto,
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(20.0),
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 52.0)
  assert_approx(layout.height, 52.0)
  assert_approx(layout.children[0].x, -40.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 72.0)
  assert_approx(layout.children[0].height, 72.0)
}

///|
test "taffy/block_absolute_margin_auto_left_child_bigger_than_parent_without_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(52.0),
    height: @types.Length(52.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(72.0),
    height: @types.Length(72.0),
    margin: {
      left: @types.Auto,
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 52.0)
  assert_approx(layout.height, 52.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 72.0)
  assert_approx(layout.children[0].height, 72.0)
}

///|
test "taffy/block_absolute_margin_auto_left_fix_right_child_bigger_than_parent_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(52.0),
    height: @types.Length(52.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(72.0),
    height: @types.Length(72.0),
    margin: {
      left: @types.Auto,
      right: @types.Length(10.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(20.0),
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 52.0)
  assert_approx(layout.height, 52.0)
  assert_approx(layout.children[0].x, -50.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 72.0)
  assert_approx(layout.children[0].height, 72.0)
}

///|
test "taffy/block_absolute_margin_auto_left_fix_right_child_bigger_than_parent_without_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(52.0),
    height: @types.Length(52.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(72.0),
    height: @types.Length(72.0),
    margin: {
      left: @types.Auto,
      right: @types.Length(10.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 52.0)
  assert_approx(layout.height, 52.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 72.0)
  assert_approx(layout.children[0].height, 72.0)
}

///|
test "taffy/block_absolute_margin_auto_left_right_child_bigger_than_parent_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(52.0),
    height: @types.Length(52.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(72.0),
    height: @types.Length(72.0),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(20.0),
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 52.0)
  assert_approx(layout.height, 52.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 72.0)
  assert_approx(layout.children[0].height, 72.0)
}

///|
test "taffy/block_absolute_margin_auto_left_right_child_bigger_than_parent_without_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(52.0),
    height: @types.Length(52.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(72.0),
    height: @types.Length(72.0),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 52.0)
  assert_approx(layout.height, 52.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 72.0)
  assert_approx(layout.children[0].height, 72.0)
}

///|
test "taffy/block_absolute_margin_auto_left_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Auto,
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(20.0),
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 130.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_left_without_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Auto,
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_multiple_children_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
    flex_direction: @types.Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(100.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(20.0),
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    inset: {
      left: @types.Length(20.0),
      right: @types.Length(10.0),
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 20.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_multiple_children_without_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
    flex_direction: @types.Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(100.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_right_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(20.0),
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_right_without_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_top_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Auto,
      bottom: @types.Length(0.0),
    },
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(20.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 140.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_auto_top_without_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Auto,
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_absolute_margin_bottom_left_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(10.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
    inset: {
      left: @types.Length(20.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(20.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 30.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 10.0)
}

///|
test "taffy/block_absolute_margin_bottom_left_without_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(10.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 10.0)
  assert_approx(layout.children[0].height, 10.0)
}

///|
test "taffy/block_absolute_minmax_bottom_right_max" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    max_width: @types.Length(40.0),
    max_height: @types.Length(30.0),
    inset: {
      left: @types.Auto,
      right: @types.Length(10.0),
      top: @types.Auto,
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 50.0)
  assert_approx(layout.children[0].y, 60.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 30.0)
}

///|
test "taffy/block_absolute_minmax_bottom_right_min_max" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    min_width: @types.Length(50.0),
    min_height: @types.Length(60.0),
    max_width: @types.Length(40.0),
    max_height: @types.Length(30.0),
    inset: {
      left: @types.Auto,
      right: @types.Length(10.0),
      top: @types.Auto,
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 40.0)
  assert_approx(layout.children[0].y, 30.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 60.0)
}

///|
test "taffy/block_absolute_minmax_bottom_right_min_max_preferred" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    min_width: @types.Length(50.0),
    min_height: @types.Length(60.0),
    max_width: @types.Length(40.0),
    max_height: @types.Length(30.0),
    inset: {
      left: @types.Auto,
      right: @types.Length(10.0),
      top: @types.Auto,
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 40.0)
  assert_approx(layout.children[0].y, 30.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 60.0)
}

///|
test "taffy/block_absolute_minmax_top_left_bottom_right_max" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    max_width: @types.Length(40.0),
    max_height: @types.Length(30.0),
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 30.0)
}

///|
test "taffy/block_absolute_minmax_top_left_bottom_right_min_max" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    min_width: @types.Length(50.0),
    min_height: @types.Length(60.0),
    max_width: @types.Length(40.0),
    max_height: @types.Length(30.0),
    inset: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 60.0)
}

///|
test "taffy/block_absolute_no_styles" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 10.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 0.0)
}

///|
test "taffy/block_absolute_padding_border_overrides_max_size" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    max_width: @types.Length(12.0),
    max_height: @types.Length(12.0),
    padding: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
    border: {
      left: @types.Length(7.0),
      right: @types.Length(3.0),
      top: @types.Length(1.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 0.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 22.0)
  assert_approx(layout.children[0].height, 14.0)
}

///|
test "taffy/block_absolute_padding_border_overrides_size" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Length(12.0),
    height: @types.Length(12.0),
    padding: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
    border: {
      left: @types.Length(7.0),
      right: @types.Length(3.0),
      top: @types.Length(1.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 0.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 22.0)
  assert_approx(layout.children[0].height, 14.0)
}

///|
test "taffy/block_absolute_resolved_insets" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Relative,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: {
      left: @types.Length(15.0),
      right: @types.Length(15.0),
      top: @types.Length(15.0),
      bottom: @types.Length(15.0),
    },
    border: {
      left: @types.Length(20.0),
      right: @types.Length(20.0),
      top: @types.Length(20.0),
      bottom: @types.Length(20.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Auto,
    },
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Percent(1.0000),
      right: @types.Auto,
      top: @types.Percent(1.0000),
      bottom: @types.Auto,
    },
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Auto,
      right: @types.Percent(1.0000),
      top: @types.Auto,
      bottom: @types.Percent(1.0000),
    },
  }
  let root_child0_child3 = @node.Node::leaf("node", root_child0_child3_style)
  root_child0_children.push(root_child0_child3)
  let root_child0_child4_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(30.0),
      right: @types.Auto,
      top: @types.Length(30.0),
      bottom: @types.Auto,
    },
  }
  let root_child0_child4 = @node.Node::leaf("node", root_child0_child4_style)
  root_child0_children.push(root_child0_child4)
  let root_child0_child5_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Percent(1.0000),
    height: @types.Percent(1.0000),
    inset: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Auto,
    },
  }
  let root_child0_child5 = @node.Node::leaf("node", root_child0_child5_style)
  root_child0_children.push(root_child0_child5)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Relative,
    overflow_x: @types.Overflow::Scroll,
    overflow_y: @types.Overflow::Scroll,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: {
      left: @types.Length(15.0),
      right: @types.Length(15.0),
      top: @types.Length(15.0),
      bottom: @types.Length(15.0),
    },
    border: {
      left: @types.Length(20.0),
      right: @types.Length(20.0),
      top: @types.Length(20.0),
      bottom: @types.Length(20.0),
    },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Auto,
    },
  }
  let root_child1_child1 = @node.Node::leaf("node", root_child1_child1_style)
  root_child1_children.push(root_child1_child1)
  let root_child1_child2_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Percent(1.0000),
      right: @types.Auto,
      top: @types.Percent(1.0000),
      bottom: @types.Auto,
    },
  }
  let root_child1_child2 = @node.Node::leaf("node", root_child1_child2_style)
  root_child1_children.push(root_child1_child2)
  let root_child1_child3_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Auto,
      right: @types.Percent(1.0000),
      top: @types.Auto,
      bottom: @types.Percent(1.0000),
    },
  }
  let root_child1_child3 = @node.Node::leaf("node", root_child1_child3_style)
  root_child1_children.push(root_child1_child3)
  let root_child1_child4_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(30.0),
      right: @types.Auto,
      top: @types.Length(30.0),
      bottom: @types.Auto,
    },
  }
  let root_child1_child4 = @node.Node::leaf("node", root_child1_child4_style)
  root_child1_children.push(root_child1_child4)
  let root_child1_child5_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    width: @types.Percent(1.0000),
    height: @types.Percent(1.0000),
    inset: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Auto,
    },
  }
  let root_child1_child5 = @node.Node::leaf("node", root_child1_child5_style)
  root_child1_children.push(root_child1_child5)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    position: @types.Position::Relative,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    padding: {
      left: @types.Length(15.0),
      right: @types.Length(15.0),
      top: @types.Length(15.0),
      bottom: @types.Length(15.0),
    },
    border: {
      left: @types.Length(20.0),
      right: @types.Length(20.0),
      top: @types.Length(20.0),
      bottom: @types.Length(20.0),
    },
  }
  let root_child2_children : Array[@node.Node] = []
  let root_child2_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child2_child0 = @node.Node::leaf("node", root_child2_child0_style)
  root_child2_children.push(root_child2_child0)
  let root_child2_child1_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child2_child1 = @node.Node::leaf("node", root_child2_child1_style)
  root_child2_children.push(root_child2_child1)
  let root_child2 = @node.Node::new(
    "node", root_child2_style, root_child2_children,
  )
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 600.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 200.0)
  assert_approx(layout.children[0].height, 200.0)
  assert_approx(layout.children[0].children[0].x, 35.0)
  assert_approx(layout.children[0].children[0].y, 35.0)
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
  assert_approx(layout.children[1].children[0].x, 35.0)
  assert_approx(layout.children[1].children[0].y, 35.0)
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
  assert_approx(layout.children[2].x, 400.0)
  assert_approx(layout.children[2].y, 0.0)
  assert_approx(layout.children[2].width, 200.0)
  assert_approx(layout.children[2].height, 200.0)
  assert_approx(layout.children[2].children[0].x, 35.0)
  assert_approx(layout.children[2].children[0].y, 35.0)
  assert_approx(layout.children[2].children[0].width, 50.0)
  assert_approx(layout.children[2].children[0].height, 10.0)
  assert_approx(layout.children[2].children[1].x, 35.0)
  assert_approx(layout.children[2].children[1].y, 45.0)
  assert_approx(layout.children[2].children[1].width, 0.0)
  assert_approx(layout.children[2].children[1].height, 0.0)
}

///|
test "taffy/block_align_baseline_child" {
  let root_style = {
    ..@style.Style::default(),
    display: @types.Flex,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @types.Baseline,
    flex_direction: @types.Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/block_align_baseline_child_margin" {
  let root_style = {
    ..@style.Style::default(),
    display: @types.Flex,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @types.Baseline,
    flex_direction: @types.Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(5.0),
      right: @types.Length(5.0),
      top: @types.Length(5.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(5.0),
      right: @types.Length(5.0),
      top: @types.Length(5.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 5.0)
  assert_approx(layout.children[0].y, 5.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 50.0)
  assert_approx(layout.children[1].y, 35.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 5.0)
  assert_approx(layout.children[1].children[0].y, 5.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/block_align_baseline_child_margin_percent" {
  let root_style = {
    ..@style.Style::default(),
    display: @types.Flex,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @types.Baseline,
    flex_direction: @types.Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Percent(0.0500),
      right: @types.Percent(0.0500),
      top: @types.Percent(0.0500),
      bottom: @types.Percent(0.0500),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Percent(0.0100),
      right: @types.Percent(0.0100),
      top: @types.Percent(0.0100),
      bottom: @types.Percent(0.0100),
    },
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 5.0)
  assert_approx(layout.children[0].y, 5.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 50.0)
  assert_approx(layout.children[1].y, 35.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.5)
  assert_approx(layout.children[1].children[0].y, 0.5)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/block_align_baseline_child_padding" {
  let root_style = {
    ..@style.Style::default(),
    display: @types.Flex,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    padding: {
      left: @types.Length(5.0),
      right: @types.Length(5.0),
      top: @types.Length(5.0),
      bottom: @types.Length(5.0),
    },
    align_items: @types.Baseline,
    flex_direction: @types.Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(20.0),
    padding: {
      left: @types.Length(5.0),
      right: @types.Length(5.0),
      top: @types.Length(5.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 5.0)
  assert_approx(layout.children[0].y, 5.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 45.0)
  assert_approx(layout.children[1].y, 35.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 5.0)
  assert_approx(layout.children[1].children[0].y, 5.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/block_align_baseline_child_top" {
  let root_style = {
    ..@style.Style::default(),
    display: @types.Flex,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @types.Baseline,
    flex_direction: @types.Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(10.0),
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 50.0)
  assert_approx(layout.children[1].y, 30.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/block_align_baseline_child_top2" {
  let root_style = {
    ..@style.Style::default(),
    display: @types.Flex,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @types.Baseline,
    flex_direction: @types.Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(20.0),
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(5.0),
      bottom: @types.Auto,
    },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 50.0)
  assert_approx(layout.children[1].y, 35.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
}

///|
test "taffy/block_align_baseline_double_nested_child" {
  let root_style = {
    ..@style.Style::default(),
    display: @types.Flex,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    align_items: @types.Baseline,
    flex_direction: @types.Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(20.0),
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
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(15.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
  assert_approx(layout.children[1].x, 50.0)
  assert_approx(layout.children[1].y, 30.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 20.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 15.0)
}

///|
test "taffy/block_aspect_ratio_fill_height" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(40.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_aspect_ratio_fill_max_height" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    max_width: @types.Length(40.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0_measure = @types.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      {
        min_width: 20.0,
        max_width: 220.0,
        min_height: 110.0,
        max_height: 110.0,
      }
    },
  }
  let root_child0 = @node.Node::with_measure(
    "node", root_child0_style, root_child0_measure,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 60.0)
}

///|
test "taffy/block_aspect_ratio_fill_max_width" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    max_height: @types.Length(20.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0_measure = @types.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 20.0, max_width: 80.0, min_height: 40.0, max_height: 40.0 }
    },
  }
  let root_child0 = @node.Node::with_measure(
    "node", root_child0_style, root_child0_measure,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_aspect_ratio_fill_min_height" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    min_width: @types.Length(40.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_aspect_ratio_fill_min_width" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    min_height: @types.Length(40.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_aspect_ratio_fill_width" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(40.0),
    aspect_ratio: Some(2.0000),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 80.0)
  assert_approx(layout.children[0].height, 40.0)
}

///|
test "taffy/block_basic" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_border_fixed_size" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    border: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 8.0)
  assert_approx(layout.children[0].y, 2.0)
  assert_approx(layout.children[0].width, 38.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 8.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 38.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_border_intrinsic_size" {
  let root_style = {
    ..@style.Style::default(),
    border: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 62.0)
  assert_approx(layout.height, 28.0)
  assert_approx(layout.children[0].x, 8.0)
  assert_approx(layout.children[0].y, 2.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 8.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_border_percentage_fixed_size" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = { ..@style.Style::default() }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
}

///|
test "taffy/block_border_percentage_intrinsic_size" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = { ..@style.Style::default() }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 0.0)
  assert_approx(layout.height, 10.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 0.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
}

///|
test "taffy/block_display_none" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @types.Display::None,
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_display_none_with_child" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @types.Display::None,
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(10.0),
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 0.0)
  assert_approx(layout.children[1].children[0].height, 0.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 10.0)
  assert_approx(layout.children[2].width, 100.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_display_none_with_inset" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    display: @types.Display::None,
    height: @types.Length(10.0),
    inset: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(10.0),
      bottom: @types.Auto,
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 0.0)
}

///|
test "taffy/block_display_none_with_margin" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @types.Display::None,
    width: @types.Length(20.0),
    height: @types.Length(20.0),
    margin: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 100.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_display_none_with_position_absolute" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @types.Display::None,
    position: @types.Position::Absolute,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 0.0)
}

///|
test "taffy/block_inset_fixed" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    inset: {
      left: @types.Length(2.0),
      right: @types.Auto,
      top: @types.Length(4.0),
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    inset: {
      left: @types.Auto,
      right: @types.Length(6.0),
      top: @types.Auto,
      bottom: @types.Length(8.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    inset: {
      left: @types.Length(2.0),
      right: @types.Length(6.0),
      top: @types.Length(4.0),
      bottom: @types.Length(8.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 2.0)
  assert_approx(layout.children[0].y, 4.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, -6.0)
  assert_approx(layout.children[1].y, 2.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[2].x, 2.0)
  assert_approx(layout.children[2].y, 24.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_inset_percentage" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    inset: {
      left: @types.Percent(0.0200),
      right: @types.Auto,
      top: @types.Percent(0.0400),
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    inset: {
      left: @types.Auto,
      right: @types.Percent(0.0600),
      top: @types.Auto,
      bottom: @types.Percent(0.0800),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    inset: {
      left: @types.Percent(0.0200),
      right: @types.Percent(0.0600),
      top: @types.Percent(0.0400),
      bottom: @types.Percent(0.0800),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 1.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, -3.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[2].x, 1.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_intrinsic_width" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_item_max_width" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(50.0),
    max_width: @types.Length(100.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(50.0),
    max_width: @types.Length(300.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 200.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_item_min_width_overrides_max_width" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(50.0),
    min_width: @types.Length(200.0),
    max_width: @types.Length(50.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 100.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 200.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_item_text_align_center" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(50.0),
    max_width: @types.Length(100.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(50.0),
    max_width: @types.Length(300.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 50.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 200.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_item_text_align_left" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(50.0),
    max_width: @types.Length(100.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(50.0),
    max_width: @types.Length(300.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 200.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_item_text_align_right" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(50.0),
    max_width: @types.Length(100.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(50.0),
    max_width: @types.Length(300.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 100.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 200.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_margin_auto_bottom" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_margin_auto_bottom_and_top" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Auto,
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_margin_auto_left" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Auto,
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 150.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_margin_auto_left_and_right" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 75.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_margin_auto_left_and_right_with_auto_width" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Auto,
    height: @types.Length(50.0),
    max_width: @types.Length(100.0),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 50.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
}

///|
test "taffy/block_margin_auto_left_child_bigger_than_parent" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(52.0),
    height: @types.Length(52.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(72.0),
    height: @types.Length(72.0),
    margin: {
      left: @types.Auto,
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 52.0)
  assert_approx(layout.height, 52.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 72.0)
  assert_approx(layout.children[0].height, 72.0)
}

///|
test "taffy/block_margin_auto_left_fix_right_child_bigger_than_parent" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(52.0),
    height: @types.Length(52.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(72.0),
    height: @types.Length(72.0),
    margin: {
      left: @types.Auto,
      right: @types.Length(10.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 52.0)
  assert_approx(layout.height, 52.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 72.0)
  assert_approx(layout.children[0].height, 72.0)
}

///|
test "taffy/block_margin_auto_left_right_child_bigger_than_parent" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(52.0),
    height: @types.Length(52.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(72.0),
    height: @types.Length(72.0),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 52.0)
  assert_approx(layout.height, 52.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 72.0)
  assert_approx(layout.children[0].height, 72.0)
}

///|
test "taffy/block_margin_auto_multiple_children" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
    flex_direction: @types.Row,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 100.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 50.0)
}

///|
test "taffy/block_margin_auto_right" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_margin_auto_top" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    align_items: @types.Center,
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Auto,
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 200.0)
  assert_approx(layout.height, 200.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 50.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 50.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 50.0)
}

///|
test "taffy/block_margin_x_fixed_auto_bottom" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Auto,
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_fixed_auto_left" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Auto,
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 30.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_fixed_auto_left_and_right" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Auto,
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 15.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_fixed_auto_right" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Auto,
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_fixed_auto_top" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Auto,
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_fixed_size_negative" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(-10.0),
      right: @types.Length(-5.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, -10.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 65.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_fixed_size_positive" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(10.0),
      right: @types.Length(5.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 35.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_intrinsic_size_negative" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(-10.0),
      right: @types.Length(-5.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 0.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, -10.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 15.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 0.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_intrinsic_size_positive" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(10.0),
      right: @types.Length(5.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 15.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 15.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_percentage_fixed_size_negative" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Percent(-0.2000),
      right: @types.Percent(-0.1000),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, -10.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 65.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_percentage_fixed_size_positive" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Percent(0.2000),
      right: @types.Percent(0.1000),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 10.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 35.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_percentage_intrinsic_size_other_negative" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Percent(-0.2000),
      right: @types.Percent(-0.1000),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, -20.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 130.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 100.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_percentage_intrinsic_size_other_positive" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Percent(0.2000),
      right: @types.Percent(0.1000),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 20.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 70.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 100.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_x_percentage_intrinsic_size_self_negative" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Percent(-0.2000),
      right: @types.Percent(-0.1000),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 10.0)
  assert_approx(layout.children[0].x, -20.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 10.0)
}

///|
test "taffy/block_margin_x_percentage_intrinsic_size_self_positive" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Percent(0.2000),
      right: @types.Percent(0.1000),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 10.0)
  assert_approx(layout.children[0].x, 20.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_complex" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-5.0),
      bottom: @types.Length(-5.0),
    },
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(7.0),
      bottom: @types.Length(3.0),
    },
  }
  let root_child1_child1 = @node.Node::leaf("node", root_child1_child1_style)
  root_child1_children.push(root_child1_child1)
  let root_child1_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-6.0),
      bottom: @types.Length(9.0),
    },
  }
  let root_child1_child2 = @node.Node::leaf("node", root_child1_child2_style)
  root_child1_children.push(root_child1_child2)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-5.0),
      bottom: @types.Length(-5.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, -10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, -10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, -5.0)
  assert_approx(layout.children[1].children[0].width, 0.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
  assert_approx(layout.children[1].children[1].x, 0.0)
  assert_approx(layout.children[1].children[1].y, 7.0)
  assert_approx(layout.children[1].children[1].width, 0.0)
  assert_approx(layout.children[1].children[1].height, 10.0)
  assert_approx(layout.children[1].children[2].x, 0.0)
  assert_approx(layout.children[1].children[2].y, -6.0)
  assert_approx(layout.children[1].children[2].width, 0.0)
  assert_approx(layout.children[1].children[2].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, -10.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, -10.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_blocked_by_aspect_ratio" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
    aspect_ratio: Some(2.0000),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 65.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 25.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 55.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_blocked_by_border_bottom" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
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
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_blocked_by_border_top" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
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
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_blocked_by_height" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(1.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
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
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 41.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 1.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 31.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_blocked_by_line_box" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child1_measure = @types.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root_child1 = @node.Node::with_measure(
    "node", root_child1_style, root_child1_measure,
  )
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 40.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_blocked_by_line_box_with_height_zero" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(0.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child1_measure = @types.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root_child1 = @node.Node::with_measure(
    "node", root_child1_style, root_child1_measure,
  )
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_margin_y_collapse_through_blocked_by_line_box_with_max_height_zero" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    max_height: @types.Length(0.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child1_measure = @types.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root_child1 = @node.Node::with_measure(
    "node", root_child1_style, root_child1_measure,
  )
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_margin_y_collapse_through_blocked_by_min_height" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    min_height: @types.Length(1.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
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
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 41.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 1.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 31.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_blocked_by_overflow_x_hidden" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Hidden,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
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
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_margin_y_collapse_through_blocked_by_overflow_x_scroll" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
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
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_margin_y_collapse_through_blocked_by_overflow_y_hidden" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    overflow_y: @types.Overflow::Hidden,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
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
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_margin_y_collapse_through_blocked_by_overflow_y_scroll" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    overflow_y: @types.Overflow::Scroll,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
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
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_margin_y_collapse_through_blocked_by_padding_bottom" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
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
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 41.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 1.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 31.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_blocked_by_padding_top" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
    padding: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(1.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 41.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 1.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 31.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_negative" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(-5.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-7.0),
      bottom: @types.Length(-3.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-2.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 13.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 3.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 3.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_positive" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
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
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_positive_and_negative" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(5.0),
      bottom: @types.Length(-4.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(7.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 17.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 5.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 7.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_collapse_through_with_absolute_child" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
  }
  let root_child1_child0_measure = @types.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root_child1_child0 = @node.Node::with_measure(
    "node", root_child1_child0_style, root_child1_child0_measure,
  )
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 0.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 20.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_blocked_by_border_top" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_blocked_by_overflow_x_hidden" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Hidden,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_blocked_by_overflow_x_scroll" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_blocked_by_overflow_y_hidden" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_y: @types.Overflow::Hidden,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_blocked_by_overflow_y_scroll" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_y: @types.Overflow::Scroll,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_blocked_by_padding_top" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
    padding: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(1.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 31.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 21.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 11.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_negative_equal" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, -10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_negative_parent_larger" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-5.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, -10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_negative_parent_smaller" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-5.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, -10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_not_blocked_by_border_bottom" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_not_blocked_by_padding_bottom" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
    padding: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(1.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 21.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 11.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_positive_and_negative" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
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
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(5.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child1_child0_children : Array[@node.Node] = []
  let root_child1_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1_child0_child0 = @node.Node::leaf(
    "node", root_child1_child0_child0_style,
  )
  root_child1_child0_children.push(root_child1_child0_child0)
  let root_child1_child0 = @node.Node::new(
    "node", root_child1_child0_style, root_child1_child0_children,
  )
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-5.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2_children : Array[@node.Node] = []
  let root_child2_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2_child0_children : Array[@node.Node] = []
  let root_child2_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child2_child0_child0 = @node.Node::leaf(
    "node", root_child2_child0_child0_style,
  )
  root_child2_child0_children.push(root_child2_child0_child0)
  let root_child2_child0 = @node.Node::new(
    "node", root_child2_child0_style, root_child2_child0_children,
  )
  root_child2_children.push(root_child2_child0)
  let root_child2 = @node.Node::new(
    "node", root_child2_style, root_child2_children,
  )
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 5.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
  assert_approx(layout.children[1].children[0].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].children[0].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
  assert_approx(layout.children[2].children[0].x, 0.0)
  assert_approx(layout.children[2].children[0].y, 0.0)
  assert_approx(layout.children[2].children[0].width, 50.0)
  assert_approx(layout.children[2].children[0].height, 10.0)
  assert_approx(layout.children[2].children[0].children[0].x, 0.0)
  assert_approx(layout.children[2].children[0].children[0].y, 0.0)
  assert_approx(layout.children[2].children[0].children[0].width, 50.0)
  assert_approx(layout.children[2].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_positive_equal" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_positive_parent_larger" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(5.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_child_collapse_positive_parent_smaller" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(5.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_first_granchild_collapse_positive_and_negative" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_child0_children : Array[@node.Node] = []
  let root_child0_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_child0_child0_children : Array[@node.Node] = []
  let root_child0_child0_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0_child0_child0_child0 = @node.Node::leaf(
    "node", root_child0_child0_child0_child0_style,
  )
  root_child0_child0_child0_children.push(root_child0_child0_child0_child0)
  let root_child0_child0_child0 = @node.Node::new(
    "node", root_child0_child0_child0_style, root_child0_child0_child0_children,
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
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(5.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child1_child0_children : Array[@node.Node] = []
  let root_child1_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-2.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child1_child0_child0_children : Array[@node.Node] = []
  let root_child1_child0_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1_child0_child0_child0 = @node.Node::leaf(
    "node", root_child1_child0_child0_child0_style,
  )
  root_child1_child0_child0_children.push(root_child1_child0_child0_child0)
  let root_child1_child0_child0 = @node.Node::new(
    "node", root_child1_child0_child0_style, root_child1_child0_child0_children,
  )
  root_child1_child0_children.push(root_child1_child0_child0)
  let root_child1_child0 = @node.Node::new(
    "node", root_child1_child0_style, root_child1_child0_children,
  )
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2_children : Array[@node.Node] = []
  let root_child2_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(5.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2_child0_children : Array[@node.Node] = []
  let root_child2_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(15.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child2_child0_child0_children : Array[@node.Node] = []
  let root_child2_child0_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child2_child0_child0_child0 = @node.Node::leaf(
    "node", root_child2_child0_child0_child0_style,
  )
  root_child2_child0_child0_children.push(root_child2_child0_child0_child0)
  let root_child2_child0_child0 = @node.Node::new(
    "node", root_child2_child0_child0_style, root_child2_child0_child0_children,
  )
  root_child2_child0_children.push(root_child2_child0_child0)
  let root_child2_child0 = @node.Node::new(
    "node", root_child2_child0_style, root_child2_child0_children,
  )
  root_child2_children.push(root_child2_child0)
  let root_child2 = @node.Node::new(
    "node", root_child2_style, root_child2_children,
  )
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].children[0].y, 0.0)
  assert_approx(
    layout.children[0].children[0].children[0].children[0].width,
    50.0,
  )
  assert_approx(
    layout.children[0].children[0].children[0].children[0].height,
    10.0,
  )
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 5.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
  assert_approx(layout.children[1].children[0].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].children[0].height, 10.0)
  assert_approx(layout.children[1].children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].children[0].children[0].y, 0.0)
  assert_approx(
    layout.children[1].children[0].children[0].children[0].width,
    50.0,
  )
  assert_approx(
    layout.children[1].children[0].children[0].children[0].height,
    10.0,
  )
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 20.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
  assert_approx(layout.children[2].children[0].x, 0.0)
  assert_approx(layout.children[2].children[0].y, 0.0)
  assert_approx(layout.children[2].children[0].width, 50.0)
  assert_approx(layout.children[2].children[0].height, 10.0)
  assert_approx(layout.children[2].children[0].children[0].x, 0.0)
  assert_approx(layout.children[2].children[0].children[0].y, 0.0)
  assert_approx(layout.children[2].children[0].children[0].width, 50.0)
  assert_approx(layout.children[2].children[0].children[0].height, 10.0)
  assert_approx(layout.children[2].children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[2].children[0].children[0].children[0].y, 0.0)
  assert_approx(
    layout.children[2].children[0].children[0].children[0].width,
    50.0,
  )
  assert_approx(
    layout.children[2].children[0].children[0].children[0].height,
    10.0,
  )
}

///|
test "taffy/block_margin_y_first_granchild_collapse_positive_equal" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_child0_children : Array[@node.Node] = []
  let root_child0_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_child0_child0_children : Array[@node.Node] = []
  let root_child0_child0_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0_child0_child0_child0 = @node.Node::leaf(
    "node", root_child0_child0_child0_child0_style,
  )
  root_child0_child0_child0_children.push(root_child0_child0_child0_child0)
  let root_child0_child0_child0 = @node.Node::new(
    "node", root_child0_child0_child0_style, root_child0_child0_child0_children,
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].children[0].y, 0.0)
  assert_approx(
    layout.children[0].children[0].children[0].children[0].width,
    50.0,
  )
  assert_approx(
    layout.children[0].children[0].children[0].children[0].height,
    10.0,
  )
}

///|
test "taffy/block_margin_y_last_child_collapse_blocked_by_border_bottom" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_blocked_by_overflow_x_hidden" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Hidden,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_blocked_by_overflow_x_scroll" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_blocked_by_overflow_y_hidden" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_y: @types.Overflow::Hidden,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_blocked_by_overflow_y_scroll" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_y: @types.Overflow::Scroll,
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_blocked_by_padding_bottom" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
    padding: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(1.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 31.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 21.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_negative_equal" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(-10.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_negative_parent_larger" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(-5.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_negative_parent_smaller" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(-5.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(-10.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_not_blocked_by_border_top" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_not_blocked_by_padding_top" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
    padding: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(1.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 21.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 11.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 1.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_positive_and_negative" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
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
  let root_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child1_child0_children : Array[@node.Node] = []
  let root_child1_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1_child0_child0 = @node.Node::leaf(
    "node", root_child1_child0_child0_style,
  )
  root_child1_child0_children.push(root_child1_child0_child0)
  let root_child1_child0 = @node.Node::new(
    "node", root_child1_child0_style, root_child1_child0_children,
  )
  root_child1_children.push(root_child1_child0)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(-5.0),
    },
  }
  let root_child2_children : Array[@node.Node] = []
  let root_child2_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child2_child0_children : Array[@node.Node] = []
  let root_child2_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child2_child0_child0 = @node.Node::leaf(
    "node", root_child2_child0_child0_style,
  )
  root_child2_child0_children.push(root_child2_child0_child0)
  let root_child2_child0 = @node.Node::new(
    "node", root_child2_child0_style, root_child2_child0_children,
  )
  root_child2_children.push(root_child2_child0)
  let root_child2 = @node.Node::new(
    "node", root_child2_style, root_child2_children,
  )
  root_children.push(root_child2)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
  assert_approx(layout.children[1].children[0].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].children[0].y, 0.0)
  assert_approx(layout.children[1].children[0].children[0].width, 50.0)
  assert_approx(layout.children[1].children[0].children[0].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 15.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
  assert_approx(layout.children[2].children[0].x, 0.0)
  assert_approx(layout.children[2].children[0].y, 0.0)
  assert_approx(layout.children[2].children[0].width, 50.0)
  assert_approx(layout.children[2].children[0].height, 10.0)
  assert_approx(layout.children[2].children[0].children[0].x, 0.0)
  assert_approx(layout.children[2].children[0].children[0].y, 0.0)
  assert_approx(layout.children[2].children[0].children[0].width, 50.0)
  assert_approx(layout.children[2].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_positive_equal" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_positive_parent_larger" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(5.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_child_collapse_positive_parent_smaller" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
}

///|
test "taffy/block_margin_y_last_granchild_collapse_positive_equal" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_child0_children : Array[@node.Node] = []
  let root_child0_child0_child0_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_child0_child0_children : Array[@node.Node] = []
  let root_child0_child0_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0_child0_child0_child0 = @node.Node::leaf(
    "node", root_child0_child0_child0_child0_style,
  )
  root_child0_child0_child0_children.push(root_child0_child0_child0_child0)
  let root_child0_child0_child0 = @node.Node::new(
    "node", root_child0_child0_child0_style, root_child0_child0_child0_children,
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
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].children[0].y, 0.0)
  assert_approx(
    layout.children[0].children[0].children[0].children[0].width,
    50.0,
  )
  assert_approx(
    layout.children[0].children[0].children[0].children[0].height,
    10.0,
  )
}

///|
test "taffy/block_margin_y_sibling_collapse_negative" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-5.0),
      bottom: @types.Length(-5.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, -10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, -10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, -10.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, -10.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 10.0)
}

///|
test "taffy/block_margin_y_sibling_collapse_negative_percentage" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(-0.1000),
      bottom: @types.Percent(-0.1000),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(-0.1000),
      bottom: @types.Percent(-0.1000),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(-0.0500),
      bottom: @types.Percent(-0.0500),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(-0.1000),
      bottom: @types.Percent(-0.1000),
    },
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 15.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, -5.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 5.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 10.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 10.0)
}

///|
test "taffy/block_margin_y_sibling_collapse_positive" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
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
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(5.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 90.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 30.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 50.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 70.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 10.0)
}

///|
test "taffy/block_margin_y_sibling_collapse_positive_and_negative" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-5.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(5.0),
      bottom: @types.Length(-5.0),
    },
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 90.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 35.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 40.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 10.0)
  assert_approx(layout.children[4].x, 0.0)
  assert_approx(layout.children[4].y, 50.0)
  assert_approx(layout.children[4].width, 50.0)
  assert_approx(layout.children[4].height, 10.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 55.0)
  assert_approx(layout.children[5].width, 50.0)
  assert_approx(layout.children[5].height, 10.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 70.0)
  assert_approx(layout.children[6].width, 50.0)
  assert_approx(layout.children[6].height, 10.0)
}

///|
test "taffy/block_margin_y_sibling_collapse_positive_and_negative_percentage" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(0.1000),
      bottom: @types.Percent(0.1000),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(-0.1000),
      bottom: @types.Percent(0.1000),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(-0.0500),
      bottom: @types.Percent(0.0500),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(-0.1000),
      bottom: @types.Percent(-0.1000),
    },
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root_child4_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(0.1000),
      bottom: @types.Percent(-0.1000),
    },
  }
  let root_child4 = @node.Node::leaf("node", root_child4_style)
  root_children.push(root_child4)
  let root_child5_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(0.0500),
      bottom: @types.Percent(-0.0500),
    },
  }
  let root_child5 = @node.Node::leaf("node", root_child5_style)
  root_children.push(root_child5)
  let root_child6_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(0.1000),
      bottom: @types.Percent(0.1000),
    },
  }
  let root_child6 = @node.Node::leaf("node", root_child6_style)
  root_children.push(root_child6)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 80.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 5.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 15.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 27.5)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 35.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 10.0)
  assert_approx(layout.children[4].x, 0.0)
  assert_approx(layout.children[4].y, 45.0)
  assert_approx(layout.children[4].width, 50.0)
  assert_approx(layout.children[4].height, 10.0)
  assert_approx(layout.children[5].x, 0.0)
  assert_approx(layout.children[5].y, 52.5)
  assert_approx(layout.children[5].width, 50.0)
  assert_approx(layout.children[5].height, 10.0)
  assert_approx(layout.children[6].x, 0.0)
  assert_approx(layout.children[6].y, 65.0)
  assert_approx(layout.children[6].width, 50.0)
  assert_approx(layout.children[6].height, 10.0)
}

///|
test "taffy/block_margin_y_sibling_collapse_positive_percentage" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(0.1000),
      bottom: @types.Percent(0.1000),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(0.1000),
      bottom: @types.Percent(0.1000),
    },
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(0.0500),
      bottom: @types.Percent(0.0500),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(0.1000),
      bottom: @types.Percent(0.1000),
    },
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 65.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 5.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, 35.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, 50.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 10.0)
}

///|
test "taffy/block_margin_y_simple_negative" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, -10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, -10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_y_simple_negative_percentage_other" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(-0.1000),
      bottom: @types.Percent(-0.1000),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 10.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, -5.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_y_simple_negative_percentage_self" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(-0.1000),
      bottom: @types.Percent(-0.1000),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 10.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, -5.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 0.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_y_simple_positive" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 40.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 30.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_y_simple_positive_percentage_other" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(0.1000),
      bottom: @types.Percent(0.1000),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 5.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_y_simple_positive_percentage_self" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Percent(0.1000),
      bottom: @types.Percent(0.1000),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 5.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, 20.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_margin_y_total_collapse" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(10.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_child2 = @node.Node::leaf("node", root_child0_child2_style)
  root_child0_children.push(root_child0_child2)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 30.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[1].x, 0.0)
  assert_approx(layout.children[0].children[1].y, 20.0)
  assert_approx(layout.children[0].children[1].width, 50.0)
  assert_approx(layout.children[0].children[1].height, 0.0)
  assert_approx(layout.children[0].children[2].x, 0.0)
  assert_approx(layout.children[0].children[2].y, 20.0)
  assert_approx(layout.children[0].children[2].width, 50.0)
  assert_approx(layout.children[0].children[2].height, 10.0)
}

///|
test "taffy/block_margin_y_total_collapse_complex" {
  let root_style = { ..@style.Style::default(), width: @types.Length(50.0) }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child1_children : Array[@node.Node] = []
  let root_child1_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-5.0),
      bottom: @types.Length(-5.0),
    },
  }
  let root_child1_child0 = @node.Node::leaf("node", root_child1_child0_style)
  root_child1_children.push(root_child1_child0)
  let root_child1_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(7.0),
      bottom: @types.Length(3.0),
    },
  }
  let root_child1_child1 = @node.Node::leaf("node", root_child1_child1_style)
  root_child1_children.push(root_child1_child1)
  let root_child1_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-6.0),
      bottom: @types.Length(9.0),
    },
  }
  let root_child1_child2 = @node.Node::leaf("node", root_child1_child2_style)
  root_child1_children.push(root_child1_child2)
  let root_child1 = @node.Node::new(
    "node", root_child1_style, root_child1_children,
  )
  root_children.push(root_child1)
  let root_child2_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-5.0),
      bottom: @types.Length(-5.0),
    },
  }
  let root_child2 = @node.Node::leaf("node", root_child2_style)
  root_children.push(root_child2)
  let root_child3_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
    margin: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(-10.0),
      bottom: @types.Length(-10.0),
    },
  }
  let root_child3 = @node.Node::leaf("node", root_child3_style)
  root_children.push(root_child3)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 0.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, -10.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 0.0)
  assert_approx(layout.children[1].y, -10.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
  assert_approx(layout.children[1].children[0].x, 0.0)
  assert_approx(layout.children[1].children[0].y, -5.0)
  assert_approx(layout.children[1].children[0].width, 0.0)
  assert_approx(layout.children[1].children[0].height, 10.0)
  assert_approx(layout.children[1].children[1].x, 0.0)
  assert_approx(layout.children[1].children[1].y, 7.0)
  assert_approx(layout.children[1].children[1].width, 0.0)
  assert_approx(layout.children[1].children[1].height, 10.0)
  assert_approx(layout.children[1].children[2].x, 0.0)
  assert_approx(layout.children[1].children[2].y, -6.0)
  assert_approx(layout.children[1].children[2].width, 0.0)
  assert_approx(layout.children[1].children[2].height, 10.0)
  assert_approx(layout.children[2].x, 0.0)
  assert_approx(layout.children[2].y, -10.0)
  assert_approx(layout.children[2].width, 50.0)
  assert_approx(layout.children[2].height, 10.0)
  assert_approx(layout.children[3].x, 0.0)
  assert_approx(layout.children[3].y, -10.0)
  assert_approx(layout.children[3].width, 50.0)
  assert_approx(layout.children[3].height, 10.0)
}

///|
test "taffy/block_overflow_scrollbars_overridden_by_available_space" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(2.0),
    height: @types.Length(4.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    overflow_y: @types.Overflow::Scroll,
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 2.0)
  assert_approx(layout.height, 4.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 2.0)
  assert_approx(layout.children[0].height, 0.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 2.0)
  assert_approx(layout.children[0].children[0].height, 0.0)
}

///|
test "taffy/block_overflow_scrollbars_overridden_by_max_size" {
  let root_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    overflow_y: @types.Overflow::Scroll,
    max_width: @types.Length(2.0),
    max_height: @types.Length(4.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_overflow_scrollbars_overridden_by_size" {
  let root_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    overflow_y: @types.Overflow::Scroll,
    width: @types.Length(2.0),
    height: @types.Length(4.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_overflow_scrollbars_take_up_space_both_axis" {
  let root_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    overflow_y: @types.Overflow::Scroll,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_overflow_scrollbars_take_up_space_cross_axis" {
  let root_style = {
    ..@style.Style::default(),
    overflow_y: @types.Overflow::Scroll,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_overflow_scrollbars_take_up_space_main_axis" {
  let root_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    position: @types.Position::Absolute,
    inset: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
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
test "taffy/block_padding_border_fixed_size" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    padding: {
      left: @types.Length(7.0),
      right: @types.Length(3.0),
      top: @types.Length(1.0),
      bottom: @types.Length(5.0),
    },
    border: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 15.0)
  assert_approx(layout.children[0].y, 3.0)
  assert_approx(layout.children[0].width, 28.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 15.0)
  assert_approx(layout.children[1].y, 13.0)
  assert_approx(layout.children[1].width, 28.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_padding_border_intrinsic_size" {
  let root_style = {
    ..@style.Style::default(),
    padding: {
      left: @types.Length(7.0),
      right: @types.Length(3.0),
      top: @types.Length(1.0),
      bottom: @types.Length(5.0),
    },
    border: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 72.0)
  assert_approx(layout.height, 34.0)
  assert_approx(layout.children[0].x, 15.0)
  assert_approx(layout.children[0].y, 3.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 15.0)
  assert_approx(layout.children[1].y, 13.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_padding_border_overrides_max_size" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    max_width: @types.Length(12.0),
    max_height: @types.Length(12.0),
    padding: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
    border: {
      left: @types.Length(7.0),
      right: @types.Length(3.0),
      top: @types.Length(1.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = { ..@style.Style::default() }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 22.0)
  assert_approx(layout.height, 14.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 22.0)
  assert_approx(layout.children[0].height, 14.0)
  assert_approx(layout.children[0].children[0].x, 15.0)
  assert_approx(layout.children[0].children[0].y, 3.0)
  assert_approx(layout.children[0].children[0].width, 0.0)
  assert_approx(layout.children[0].children[0].height, 0.0)
}

///|
test "taffy/block_padding_border_overrides_min_size" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    min_width: @types.Length(0.0),
    min_height: @types.Length(0.0),
    padding: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
    border: {
      left: @types.Length(7.0),
      right: @types.Length(3.0),
      top: @types.Length(1.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = { ..@style.Style::default() }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 22.0)
  assert_approx(layout.height, 14.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 22.0)
  assert_approx(layout.children[0].height, 14.0)
  assert_approx(layout.children[0].children[0].x, 15.0)
  assert_approx(layout.children[0].children[0].y, 3.0)
  assert_approx(layout.children[0].children[0].width, 0.0)
  assert_approx(layout.children[0].children[0].height, 0.0)
}

///|
test "taffy/block_padding_border_overrides_size" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(12.0),
    height: @types.Length(12.0),
    padding: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
    border: {
      left: @types.Length(7.0),
      right: @types.Length(3.0),
      top: @types.Length(1.0),
      bottom: @types.Length(5.0),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = { ..@style.Style::default() }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 22.0)
  assert_approx(layout.height, 14.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 22.0)
  assert_approx(layout.children[0].height, 14.0)
  assert_approx(layout.children[0].children[0].x, 15.0)
  assert_approx(layout.children[0].children[0].y, 3.0)
  assert_approx(layout.children[0].children[0].width, 0.0)
  assert_approx(layout.children[0].children[0].height, 0.0)
}

///|
test "taffy/block_padding_border_percentage_fixed_size" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    padding: {
      left: @types.Percent(0.0400),
      right: @types.Percent(0.0200),
      top: @types.Percent(0.0100),
      bottom: @types.Percent(0.0300),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 12.0)
  assert_approx(layout.children[0].children[0].x, 2.0)
  assert_approx(layout.children[0].children[0].y, 0.5)
  assert_approx(layout.children[0].children[0].width, 47.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
}

///|
test "taffy/block_padding_border_percentage_intrinsic_size" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    padding: {
      left: @types.Percent(0.0400),
      right: @types.Percent(0.0200),
      top: @types.Percent(0.0100),
      bottom: @types.Percent(0.0300),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 0.0)
  assert_approx(layout.height, 10.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 0.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
}

///|
test "taffy/block_padding_fixed_size" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    padding: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 8.0)
  assert_approx(layout.children[0].y, 2.0)
  assert_approx(layout.children[0].width, 38.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 8.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 38.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_padding_intrinsic_size" {
  let root_style = {
    ..@style.Style::default(),
    padding: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root_child1_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child1 = @node.Node::leaf("node", root_child1_style)
  root_children.push(root_child1)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 62.0)
  assert_approx(layout.height, 28.0)
  assert_approx(layout.children[0].x, 8.0)
  assert_approx(layout.children[0].y, 2.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[1].x, 8.0)
  assert_approx(layout.children[1].y, 12.0)
  assert_approx(layout.children[1].width, 50.0)
  assert_approx(layout.children[1].height, 10.0)
}

///|
test "taffy/block_padding_percentage_fixed_size" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    padding: {
      left: @types.Percent(0.0400),
      right: @types.Percent(0.0200),
      top: @types.Percent(0.0100),
      bottom: @types.Percent(0.0300),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 50.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 50.0)
  assert_approx(layout.children[0].height, 12.0)
  assert_approx(layout.children[0].children[0].x, 2.0)
  assert_approx(layout.children[0].children[0].y, 0.5)
  assert_approx(layout.children[0].children[0].width, 47.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
}

///|
test "taffy/block_padding_percentage_intrinsic_size" {
  let root_style = { ..@style.Style::default() }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    padding: {
      left: @types.Percent(0.0400),
      right: @types.Percent(0.0200),
      top: @types.Percent(0.0100),
      bottom: @types.Percent(0.0300),
    },
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    height: @types.Length(10.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new(
    "node", root_child0_style, root_child0_children,
  )
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @block.compute(root, ctx)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 0.0)
  assert_approx(layout.height, 10.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 0.0)
  assert_approx(layout.children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 0.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
}
