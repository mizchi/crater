///|
test "Size::new and zero" {
  let size = Size::new(100.0, 200.0)
  inspect(size.width, content="100")
  inspect(size.height, content="200")
  let zero = Size::zero()
  inspect(zero.width, content="0")
  inspect(zero.height, content="0")
}

///|
test "Point::new and zero" {
  let point = Point::new(10.0, 20.0)
  inspect(point.x, content="10")
  inspect(point.y, content="20")
  let zero = Point::zero()
  inspect(zero.x, content="0")
  inspect(zero.y, content="0")
}

///|
test "Rect::new and sums" {
  let rect : Rect[Double] = Rect::new(10.0, 20.0, 5.0, 15.0)
  inspect(rect.horizontal_sum(), content="30")
  inspect(rect.vertical_sum(), content="20")
}

///|
test "Dimension::resolve" {
  let length : @crater.Dimension = @crater.Length(50.0)
  let percent : @crater.Dimension = @crater.Percent(0.5)
  let auto : @crater.Dimension = @crater.Auto
  inspect(length.resolve(100.0), content="Some(50)")
  inspect(percent.resolve(100.0), content="Some(50)")
  inspect(auto.resolve(100.0), content="None")
  inspect(auto.resolve_or(100.0, 25.0), content="25")
}

///|
test "BoundingRect operations" {
  let rect = BoundingRect::new(10.0, 20.0, 100.0, 50.0)
  inspect(rect.right(), content="110")
  inspect(rect.bottom(), content="70")
  inspect(rect.area(), content="5000")
}

///|
test "BoundingRect::union" {
  let a = BoundingRect::new(0.0, 0.0, 50.0, 50.0)
  let b = BoundingRect::new(25.0, 25.0, 50.0, 50.0)
  let u = a.union(b)
  inspect(u.x, content="0")
  inspect(u.y, content="0")
  inspect(u.width, content="75")
  inspect(u.height, content="75")
}

///|
test "Style::default" {
  let style = @crater.Style::default()
  inspect(style.display, content="Block")
  inspect(style.position, content="Relative")
  inspect(style.flex_grow, content="0")
}

///|
test "CLS: element shift calculation" {
  // Example from web.dev: element occupies 50% of viewport,
  // moves down by 25% of viewport height
  let viewport = Size::new(800.0, 600.0)

  // Before: element at top, 50% height
  let before = BoundingRect::new(0.0, 0.0, 800.0, 300.0)
  // After: element moved down by 25% (150px)
  let after = BoundingRect::new(0.0, 150.0, 800.0, 300.0)
  let shift = @crater.compute_element_shift(before, after, viewport)

  // Impact fraction: union covers 75% of viewport (0 to 450 = 450/600 height)
  // Union: x=0, y=0, width=800, height=450
  // Area = 800 * 450 = 360000
  // Viewport area = 800 * 600 = 480000
  // Impact = 360000 / 480000 = 0.75
  inspect(shift.impact_fraction, content="0.75")

  // Distance fraction: moved 150px / 800 (max viewport dim) = 0.1875
  inspect(shift.distance_fraction, content="0.1875")

  // Score: 0.75 * 0.1875 = 0.140625
  inspect(shift.score, content="0.140625")
}

///|
test "CLS: no movement = zero score" {
  let viewport = Size::new(1920.0, 1080.0)
  let rect = BoundingRect::new(100.0, 100.0, 200.0, 150.0)
  let shift = @crater.compute_element_shift(rect, rect, viewport)
  inspect(shift.distance_fraction, content="0")
  inspect(shift.score, content="0")
}

///|
test "CLS: total score for multiple elements" {
  let viewport = Size::new(1000.0, 1000.0)
  let before = [
    BoundingRect::new(0.0, 0.0, 500.0, 200.0),
    BoundingRect::new(0.0, 200.0, 500.0, 200.0),
  ]
  let after = [
    BoundingRect::new(0.0, 100.0, 500.0, 200.0), // moved down 100px
    BoundingRect::new(0.0, 300.0, 500.0, 200.0), // moved down 100px
  ]
  let total = @crater.compute_total_cls(before, after, viewport)
  // Both elements shifted, total should be sum of individual scores
  inspect(total > 0.0, content="true")
}

// =============================================================================
// Block Layout Tests (from taffy test_fixtures)
// =============================================================================

///|
test "block_basic" {
  // From taffy/test_fixtures/block/block_basic.html
  // <div id="test-root" style="display: block; width: 50px;">
  //   <div style="height: 10px;"></div>
  //   <div style="height: 10px;"></div>
  // </div>

  let default_style = @crater.Style::default()

  // Build child 1: height: 10px
  let child1_style = { ..default_style, height: @crater.Length(10.0) }
  let child1 = @crater.Node::leaf("child1", child1_style)

  // Build child 2: height: 10px
  let child2_style = { ..default_style, height: @crater.Length(10.0) }
  let child2 = @crater.Node::leaf("child2", child2_style)

  // Build root: width: 50px, height: auto
  let root_style = { ..default_style, width: @crater.Length(50.0) }
  let root = @crater.Node::new("test-root", root_style, [child1, child2])

  // Compute layout
  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // Assert root dimensions
  inspect(layout.width, content="50")
  inspect(layout.height, content="20")

  // Assert child 1 position and size
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[0].height, content="10")

  // Assert child 2 position and size
  inspect(layout.children[1].x, content="0")
  inspect(layout.children[1].y, content="10")
  inspect(layout.children[1].width, content="50")
  inspect(layout.children[1].height, content="10")
}

///|
test "block_border_fixed_size" {
  // From taffy/test_fixtures/block/block_border_fixed_size.html
  // <div id="test-root" style="display: block; width: 50px; height: 50px; border-width: 2px 4px 6px 8px;">
  //   <div style="height: 10px;"></div>
  //   <div style="height: 10px;"></div>
  // </div>
  // border-width: top right bottom left = 2 4 6 8

  let default_style = @crater.Style::default()

  // Build child 1: height: 10px
  let child1_style = { ..default_style, height: @crater.Length(10.0) }
  let child1 = @crater.Node::leaf("child1", child1_style)

  // Build child 2: height: 10px
  let child2_style = { ..default_style, height: @crater.Length(10.0) }
  let child2 = @crater.Node::leaf("child2", child2_style)

  // Build root: width: 50px, height: 50px, border: 2 4 6 8
  let root_style = {
    ..default_style,
    width: @crater.Length(50.0),
    height: @crater.Length(50.0),
    border: {
      top: @crater.Length(2.0),
      right: @crater.Length(4.0),
      bottom: @crater.Length(6.0),
      left: @crater.Length(8.0),
    },
  }
  let root = @crater.Node::new("test-root", root_style, [child1, child2])

  // Compute layout
  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // Assert root dimensions (fixed size)
  inspect(layout.width, content="50")
  inspect(layout.height, content="50")

  // Children are positioned inside border
  // Child 1: x = left border (8), y = top border (2)
  // width = 50 - 8 (left) - 4 (right) = 38
  inspect(layout.children[0].x, content="8")
  inspect(layout.children[0].y, content="2")
  inspect(layout.children[0].width, content="38")
  inspect(layout.children[0].height, content="10")

  // Child 2: x = 8, y = 2 + 10 = 12
  inspect(layout.children[1].x, content="8")
  inspect(layout.children[1].y, content="12")
  inspect(layout.children[1].width, content="38")
  inspect(layout.children[1].height, content="10")
}

///|
test "block_margin_x_fixed_size_positive" {
  // From taffy/test_fixtures/block/block_margin_x_fixed_size_positive.html
  // <div id="test-root" style="display: block; width: 50px;">
  //   <div style="height: 10px; margin-left: 10px; margin-right: 5px;"></div>
  //   <div style="height: 10px;"></div>
  // </div>

  let default_style = @crater.Style::default()

  // Build child 1: height: 10px, margin-left: 10px, margin-right: 5px
  let child1_style = {
    ..default_style,
    height: @crater.Length(10.0),
    margin: {
      left: @crater.Length(10.0),
      right: @crater.Length(5.0),
      top: @crater.Length(0.0),
      bottom: @crater.Length(0.0),
    },
  }
  let child1 = @crater.Node::leaf("child1", child1_style)

  // Build child 2: height: 10px
  let child2_style = { ..default_style, height: @crater.Length(10.0) }
  let child2 = @crater.Node::leaf("child2", child2_style)

  // Build root: width: 50px
  let root_style = { ..default_style, width: @crater.Length(50.0) }
  let root = @crater.Node::new("test-root", root_style, [child1, child2])

  // Compute layout
  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // Assert root dimensions
  inspect(layout.width, content="50")
  inspect(layout.height, content="20")

  // Child 1: x = margin-left (10), width = 50 - 10 - 5 = 35
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].width, content="35")
  inspect(layout.children[0].height, content="10")

  // Child 2: x = 0, y = 10
  inspect(layout.children[1].x, content="0")
  inspect(layout.children[1].y, content="10")
  inspect(layout.children[1].width, content="50")
  inspect(layout.children[1].height, content="10")
}

///|
test "block_padding_fixed_size" {
  // From taffy/test_fixtures/block/block_padding_fixed_size.html
  // <div id="test-root" style="display: block; width: 50px; height: 50px; padding: 2px 4px 6px 8px;">
  //   <div style="height: 10px;"></div>
  //   <div style="height: 10px;"></div>
  // </div>
  // padding: top right bottom left = 2 4 6 8

  let default_style = @crater.Style::default()

  // Build child 1: height: 10px
  let child1_style = { ..default_style, height: @crater.Length(10.0) }
  let child1 = @crater.Node::leaf("child1", child1_style)

  // Build child 2: height: 10px
  let child2_style = { ..default_style, height: @crater.Length(10.0) }
  let child2 = @crater.Node::leaf("child2", child2_style)

  // Build root: width: 50px, height: 50px, padding: 2 4 6 8
  let root_style = {
    ..default_style,
    width: @crater.Length(50.0),
    height: @crater.Length(50.0),
    padding: {
      top: @crater.Length(2.0),
      right: @crater.Length(4.0),
      bottom: @crater.Length(6.0),
      left: @crater.Length(8.0),
    },
  }
  let root = @crater.Node::new("test-root", root_style, [child1, child2])

  // Compute layout
  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // Assert root dimensions (fixed size)
  inspect(layout.width, content="50")
  inspect(layout.height, content="50")

  // Children are positioned inside padding
  // Child 1: x = left padding (8), y = top padding (2)
  // width = 50 - 8 (left) - 4 (right) = 38
  inspect(layout.children[0].x, content="8")
  inspect(layout.children[0].y, content="2")
  inspect(layout.children[0].width, content="38")
  inspect(layout.children[0].height, content="10")

  // Child 2: x = 8, y = 2 + 10 = 12
  inspect(layout.children[1].x, content="8")
  inspect(layout.children[1].y, content="12")
  inspect(layout.children[1].width, content="38")
  inspect(layout.children[1].height, content="10")
}

///|
test "block_nested" {
  // Test nested block layout:
  // <div style="width: 100px; padding: 10px;">
  //   <div style="padding: 5px;">
  //     <div style="height: 20px;"></div>
  //   </div>
  // </div>

  let default_style = @crater.Style::default()

  // Innermost: height: 20px
  let inner_style = { ..default_style, height: @crater.Length(20.0) }
  let inner = @crater.Node::leaf("inner", inner_style)

  // Middle: padding: 5px
  let middle_style = {
    ..default_style,
    padding: {
      top: @crater.Length(5.0),
      right: @crater.Length(5.0),
      bottom: @crater.Length(5.0),
      left: @crater.Length(5.0),
    },
  }
  let middle = @crater.Node::new("middle", middle_style, [inner])

  // Root: width: 100px, padding: 10px
  let root_style = {
    ..default_style,
    width: @crater.Length(100.0),
    padding: {
      top: @crater.Length(10.0),
      right: @crater.Length(10.0),
      bottom: @crater.Length(10.0),
      left: @crater.Length(10.0),
    },
  }
  let root = @crater.Node::new("root", root_style, [middle])

  // Compute layout
  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // Root: width = 100, height = 10 + 5 + 20 + 5 + 10 = 50
  inspect(layout.width, content="100")
  inspect(layout.height, content="50")

  // Middle: x = 10 (root padding), y = 10
  // width = 100 - 10 - 10 = 80
  // height = 5 + 20 + 5 = 30
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].y, content="10")
  inspect(layout.children[0].width, content="80")
  inspect(layout.children[0].height, content="30")

  // Inner: x = 5 (middle padding), y = 5
  // width = 80 - 5 - 5 = 70, height = 20
  inspect(layout.children[0].children[0].x, content="5")
  inspect(layout.children[0].children[0].y, content="5")
  inspect(layout.children[0].children[0].width, content="70")
  inspect(layout.children[0].children[0].height, content="20")
}

///|
test "block_margin_percentage" {
  // margin-left: 20%, margin-right: 10% on a 50px parent
  // margin-left = 50 * 0.2 = 10px, margin-right = 50 * 0.1 = 5px

  let default_style = @crater.Style::default()

  let child1_style = {
    ..default_style,
    height: @crater.Length(10.0),
    margin: {
      left: @crater.Percent(0.2),
      right: @crater.Percent(0.1),
      top: @crater.Length(0.0),
      bottom: @crater.Length(0.0),
    },
  }
  let child1 = @crater.Node::leaf("child1", child1_style)

  let child2_style = { ..default_style, height: @crater.Length(10.0) }
  let child2 = @crater.Node::leaf("child2", child2_style)

  let root_style = { ..default_style, width: @crater.Length(50.0) }
  let root = @crater.Node::new("root", root_style, [child1, child2])

  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  inspect(layout.width, content="50")
  inspect(layout.height, content="20")

  // child1: x = 10 (20% of 50), width = 50 - 10 - 5 = 35
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].width, content="35")

  // child2: x = 0, width = 50
  inspect(layout.children[1].x, content="0")
  inspect(layout.children[1].width, content="50")
}

///|
test "block_percentage_width" {
  // Child with width: 50% of parent

  let default_style = @crater.Style::default()

  let child_style = {
    ..default_style,
    width: @crater.Percent(0.5),
    height: @crater.Length(20.0),
  }
  let child = @crater.Node::leaf("child", child_style)

  let root_style = {
    ..default_style,
    width: @crater.Length(100.0),
    height: @crater.Length(100.0),
  }
  let root = @crater.Node::new("root", root_style, [child])

  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // Child width = 100 * 0.5 = 50
  inspect(layout.children[0].width, content="50")
  inspect(layout.children[0].height, content="20")
}

///|
test "block_percentage_height" {
  // Child with height: 50% of parent

  let default_style = @crater.Style::default()

  let child_style = {
    ..default_style,
    width: @crater.Length(20.0),
    height: @crater.Percent(0.5),
  }
  let child = @crater.Node::leaf("child", child_style)

  let root_style = {
    ..default_style,
    width: @crater.Length(100.0),
    height: @crater.Length(100.0),
  }
  let root = @crater.Node::new("root", root_style, [child])

  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // Child height = 100 * 0.5 = 50
  inspect(layout.children[0].width, content="20")
  inspect(layout.children[0].height, content="50")
}

///|
test "block_max_width" {
  // From taffy: block_item_max_width.html
  // Child 1: max-width: 100px (limits auto width)
  // Child 2: max-width: 300px (larger than parent, no effect)

  let default_style = @crater.Style::default()

  let child1_style = {
    ..default_style,
    max_width: @crater.Length(100.0),
    height: @crater.Length(50.0),
  }
  let child1 = @crater.Node::leaf("child1", child1_style)

  let child2_style = {
    ..default_style,
    max_width: @crater.Length(300.0),
    height: @crater.Length(50.0),
  }
  let child2 = @crater.Node::leaf("child2", child2_style)

  let root_style = {
    ..default_style,
    width: @crater.Length(200.0),
    height: @crater.Length(200.0),
  }
  let root = @crater.Node::new("root", root_style, [child1, child2])

  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // Child 1: width limited to 100 by max-width
  inspect(layout.children[0].width, content="100")

  // Child 2: width is 200 (parent width), max-width 300 has no effect
  inspect(layout.children[1].width, content="200")
}

///|
test "block_min_width" {
  // min-width ensures element is at least a certain width

  let default_style = @crater.Style::default()

  let child_style = {
    ..default_style,
    width: @crater.Length(50.0),
    min_width: @crater.Length(100.0),
    height: @crater.Length(30.0),
  }
  let child = @crater.Node::leaf("child", child_style)

  let root_style = {
    ..default_style,
    width: @crater.Length(200.0),
    height: @crater.Length(100.0),
  }
  let root = @crater.Node::new("root", root_style, [child])

  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // min-width: 100 overrides width: 50
  inspect(layout.children[0].width, content="100")
}

///|
test "block_max_height" {
  // max-height limits element height

  let default_style = @crater.Style::default()

  let child_style = {
    ..default_style,
    width: @crater.Length(50.0),
    height: @crater.Length(150.0),
    max_height: @crater.Length(80.0),
  }
  let child = @crater.Node::leaf("child", child_style)

  let root_style = {
    ..default_style,
    width: @crater.Length(200.0),
    height: @crater.Length(200.0),
  }
  let root = @crater.Node::new("root", root_style, [child])

  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // max-height: 80 limits height: 150
  inspect(layout.children[0].height, content="80")
}

///|
test "block_min_height" {
  // min-height ensures element is at least a certain height

  let default_style = @crater.Style::default()

  let child_style = {
    ..default_style,
    width: @crater.Length(50.0),
    height: @crater.Length(20.0),
    min_height: @crater.Length(60.0),
  }
  let child = @crater.Node::leaf("child", child_style)

  let root_style = {
    ..default_style,
    width: @crater.Length(200.0),
    height: @crater.Length(200.0),
  }
  let root = @crater.Node::new("root", root_style, [child])

  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // min-height: 60 overrides height: 20
  inspect(layout.children[0].height, content="60")
}

///|
test "block_margin_collapse_siblings" {
  // Adjacent sibling margins should collapse
  // Child 1: margin-bottom: 30px
  // Child 2: margin-top: 20px
  // Result: gap of 30px (max), not 50px (sum)

  let default_style = @crater.Style::default()

  let child1_style = {
    ..default_style,
    height: @crater.Length(20.0),
    margin: {
      left: @crater.Length(0.0),
      right: @crater.Length(0.0),
      top: @crater.Length(0.0),
      bottom: @crater.Length(30.0),
    },
  }
  let child1 = @crater.Node::leaf("child1", child1_style)

  let child2_style = {
    ..default_style,
    height: @crater.Length(20.0),
    margin: {
      left: @crater.Length(0.0),
      right: @crater.Length(0.0),
      top: @crater.Length(20.0),
      bottom: @crater.Length(0.0),
    },
  }
  let child2 = @crater.Node::leaf("child2", child2_style)

  let root_style = { ..default_style, width: @crater.Length(100.0) }
  let root = @crater.Node::new("root", root_style, [child1, child2])

  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // Without collapsing: 20 + 30 + 20 + 20 = 90
  // With collapsing: 20 + 30 + 20 = 70 (margins collapse to 30)
  inspect(layout.height, content="70")

  // Child 1: y = 0, height = 20
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].height, content="20")

  // Child 2: y = 20 + 30 (collapsed margin) = 50
  inspect(layout.children[1].y, content="50")
  inspect(layout.children[1].height, content="20")
}

///|
test "block_percentage_padding" {
  // CSS: percentage padding is calculated relative to parent's WIDTH
  // Even for top/bottom padding!
  // Parent: width: 200px
  // Child: padding: 10% (all sides)
  // padding = 200 * 0.1 = 20px on all sides

  let default_style = @crater.Style::default()

  let grandchild_style = { ..default_style, height: @crater.Length(20.0) }
  let grandchild = @crater.Node::leaf("grandchild", grandchild_style)

  let child_style = {
    ..default_style,
    padding: {
      left: @crater.Percent(0.1),
      right: @crater.Percent(0.1),
      top: @crater.Percent(0.1),
      bottom: @crater.Percent(0.1),
    },
  }
  let child = @crater.Node::new("child", child_style, [grandchild])

  let root_style = { ..default_style, width: @crater.Length(200.0) }
  let root = @crater.Node::new("root", root_style, [child])

  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // Child padding resolved: all 20px (10% of 200)
  inspect(layout.children[0].padding.left, content="20")
  inspect(layout.children[0].padding.right, content="20")
  inspect(layout.children[0].padding.top, content="20")
  inspect(layout.children[0].padding.bottom, content="20")

  // Grandchild position: x = 20 (left padding), y = 20 (top padding)
  inspect(layout.children[0].children[0].x, content="20")
  inspect(layout.children[0].children[0].y, content="20")

  // Grandchild width = 200 - 20 - 20 = 160
  inspect(layout.children[0].children[0].width, content="160")
}

///|
test "block_percentage_margin_vertical" {
  // CSS: percentage margin (even top/bottom) is relative to parent's WIDTH
  // Parent: width: 100px
  // Child: margin-top: 20%, margin-bottom: 10%
  // margin-top = 100 * 0.2 = 20px
  // margin-bottom = 100 * 0.1 = 10px

  let default_style = @crater.Style::default()

  let child_style = {
    ..default_style,
    height: @crater.Length(30.0),
    margin: {
      left: @crater.Length(0.0),
      right: @crater.Length(0.0),
      top: @crater.Percent(0.2),
      bottom: @crater.Percent(0.1),
    },
  }
  let child = @crater.Node::leaf("child", child_style)

  let root_style = { ..default_style, width: @crater.Length(100.0) }
  let root = @crater.Node::new("root", root_style, [child])

  let viewport = @crater.Size::new(800.0, 600.0)
  let layout = @crater.compute_layout(root, viewport)

  // Child margin resolved
  inspect(layout.children[0].margin.top, content="20")
  inspect(layout.children[0].margin.bottom, content="10")

  // Child y = margin-top = 20
  inspect(layout.children[0].y, content="20")

  // Root height = margin-top + height + margin-bottom = 20 + 30 + 10 = 60
  inspect(layout.height, content="60")
}
