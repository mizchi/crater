// Auto-generated from taffy test fixtures
// DO NOT EDIT - regenerate with: npm run gen-moonbit-tests
// Uses assert_approx from main gen_test.mbt

///|
test "taffy/leaf_overflow_scrollbars_affect_available_space_x_axis" {
  let root_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    width: @types.Length(45.0),
    height: @types.Length(45.0),
  }
  let root_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 210.0, max_width: 210.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root = @node.Node::with_measure("test-root", root_style, root_measure)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 45.0)
  assert_approx(layout.height, 45.0)
}

///|
test "taffy/leaf_overflow_scrollbars_affect_available_space_y_axis" {
  let root_style = {
    ..@style.Style::default(),
    overflow_y: @types.Overflow::Scroll,
    width: @types.Length(45.0),
    height: @types.Length(45.0),
  }
  let root_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 210.0, max_width: 210.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root = @node.Node::with_measure("test-root", root_style, root_measure)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 45.0)
  assert_approx(layout.height, 45.0)
}

///|
test "taffy/leaf_overflow_scrollbars_overridden_by_available_space" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(2.0),
    height: @types.Length(4.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @types.Flex,
    overflow_x: @types.Overflow::Scroll,
    overflow_y: @types.Overflow::Scroll,
    flex_grow: 1.0,
  }
  let root_child0 = @node.Node::leaf("node", root_child0_style)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)
  let layout = compute_layout(root, 800.0, 600.0)
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
test "taffy/leaf_overflow_scrollbars_overridden_by_max_size" {
  let root_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    overflow_y: @types.Overflow::Scroll,
    max_width: @types.Length(2.0),
    max_height: @types.Length(4.0),
  }
  let root = @node.Node::leaf("test-root", root_style)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 0.0)
  assert_approx(layout.height, 0.0)
}

///|
test "taffy/leaf_overflow_scrollbars_overridden_by_size" {
  let root_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    overflow_y: @types.Overflow::Scroll,
    width: @types.Length(2.0),
    height: @types.Length(4.0),
  }
  let root = @node.Node::leaf("test-root", root_style)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 2.0)
  assert_approx(layout.height, 4.0)
}

///|
test "taffy/leaf_overflow_scrollbars_take_up_space_both_axis" {
  let root_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
    overflow_y: @types.Overflow::Scroll,
  }
  let root_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root = @node.Node::with_measure("test-root", root_style, root_measure)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 10.0)
}

///|
test "taffy/leaf_overflow_scrollbars_take_up_space_x_axis" {
  let root_style = {
    ..@style.Style::default(),
    overflow_x: @types.Overflow::Scroll,
  }
  let root_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root = @node.Node::with_measure("test-root", root_style, root_measure)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 10.0)
}

///|
test "taffy/leaf_overflow_scrollbars_take_up_space_y_axis" {
  let root_style = {
    ..@style.Style::default(),
    overflow_y: @types.Overflow::Scroll,
  }
  let root_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root = @node.Node::with_measure("test-root", root_style, root_measure)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 20.0)
  assert_approx(layout.height, 10.0)
}

///|
test "taffy/leaf_padding_border_overrides_max_size" {
  let root_style = {
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
  let root = @node.Node::leaf("test-root", root_style)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 22.0)
  assert_approx(layout.height, 14.0)
}

///|
test "taffy/leaf_padding_border_overrides_min_size" {
  let root_style = {
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
  let root = @node.Node::leaf("test-root", root_style)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 22.0)
  assert_approx(layout.height, 14.0)
}

///|
test "taffy/leaf_padding_border_overrides_size" {
  let root_style = {
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
  let root = @node.Node::leaf("test-root", root_style)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 22.0)
  assert_approx(layout.height, 14.0)
}

///|
test "taffy/leaf_with_content_and_border" {
  let root_style = {
    ..@style.Style::default(),
    border: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
  }
  let root_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root = @node.Node::with_measure("test-root", root_style, root_measure)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 52.0)
  assert_approx(layout.height, 18.0)
}

///|
test "taffy/leaf_with_content_and_padding" {
  let root_style = {
    ..@style.Style::default(),
    padding: {
      left: @types.Length(8.0),
      right: @types.Length(4.0),
      top: @types.Length(2.0),
      bottom: @types.Length(6.0),
    },
  }
  let root_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root = @node.Node::with_measure("test-root", root_style, root_measure)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 52.0)
  assert_approx(layout.height, 18.0)
}

///|
test "taffy/leaf_with_content_and_padding_border" {
  let root_style = {
    ..@style.Style::default(),
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
  let root_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 40.0, max_width: 40.0, min_height: 10.0, max_height: 10.0 }
    },
  }
  let root = @node.Node::with_measure("test-root", root_style, root_measure)
  let layout = compute_layout(root, 800.0, 600.0)
  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 62.0)
  assert_approx(layout.height, 24.0)
}
