// Auto-generated from taffy test fixtures
// DO NOT EDIT - regenerate with: npm run gen-moonbit-tests
// Uses assert_approx from main gen_test.mbt

///|
test "taffy/gridflex_column_integration" {
  let root_style = {
    ..@style.Style::default(),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Fr(1.0), @style.Fr(1.0)],
    grid_template_rows: [@style.Fr(1.0), @style.Fr(1.0)],
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child0 = @node.Node::with_measure("node", root_child0_child0_style, root_child0_child0_measure)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child1 = @node.Node::with_measure("node", root_child0_child1_style, root_child0_child1_measure)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child2 = @node.Node::with_measure("node", root_child0_child2_style, root_child0_child2_measure)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child3 = @node.Node::with_measure("node", root_child0_child3_style, root_child0_child3_measure)
  root_child0_children.push(root_child0_child3)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[1].x, 20.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 20.0)
  assert_approx(layout.children[0].children[1].height, 10.0)
  assert_approx(layout.children[0].children[2].x, 0.0)
  assert_approx(layout.children[0].children[2].y, 10.0)
  assert_approx(layout.children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[2].height, 10.0)
  assert_approx(layout.children[0].children[3].x, 20.0)
  assert_approx(layout.children[0].children[3].y, 10.0)
  assert_approx(layout.children[0].children[3].width, 20.0)
  assert_approx(layout.children[0].children[3].height, 10.0)
}

///|
test "taffy/gridflex_kitchen_sink" {
  let root_style = {
    ..@style.Style::default(),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Fr(1.0), @style.Fr(1.0)],
    grid_template_rows: [@style.Fr(1.0), @style.Fr(1.0)],
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_children : Array[@node.Node] = []
  let root_child0_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
  }
  let root_child0_child0_child0 = @node.Node::leaf("node", root_child0_child0_child0_style)
  root_child0_child0_children.push(root_child0_child0_child0)
  let root_child0_child0_child1_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
  }
  let root_child0_child0_child1_children : Array[@node.Node] = []
  let root_child0_child0_child1_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Auto, @style.Percent(0.1000)],
    grid_template_rows: [@style.Percent(0.3000), @style.Percent(0.1000)],
  }
  let root_child0_child0_child1_child0_children : Array[@node.Node] = []
  let root_child0_child0_child1_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
  }
  let root_child0_child0_child1_child0_child0 = @node.Node::leaf("node", root_child0_child0_child1_child0_child0_style)
  root_child0_child0_child1_child0_children.push(root_child0_child0_child1_child0_child0)
  let root_child0_child0_child1_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_child1_child0_child1 = @node.Node::leaf("node", root_child0_child0_child1_child0_child1_style)
  root_child0_child0_child1_child0_children.push(root_child0_child0_child1_child0_child1)
  let root_child0_child0_child1_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_child1_child0_child2 = @node.Node::leaf("node", root_child0_child0_child1_child0_child2_style)
  root_child0_child0_child1_child0_children.push(root_child0_child0_child1_child0_child2)
  let root_child0_child0_child1_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_child1_child0_child3 = @node.Node::leaf("node", root_child0_child0_child1_child0_child3_style)
  root_child0_child0_child1_child0_children.push(root_child0_child0_child1_child0_child3)
  let root_child0_child0_child1_child0 = @node.Node::new("node", root_child0_child0_child1_child0_style, root_child0_child0_child1_child0_children)
  root_child0_child0_child1_children.push(root_child0_child0_child1_child0)
  let root_child0_child0_child1 = @node.Node::new("node", root_child0_child0_child1_style, root_child0_child0_child1_children)
  root_child0_child0_children.push(root_child0_child0_child1)
  let root_child0_child0 = @node.Node::new("node", root_child0_child0_style, root_child0_child0_children)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child1 = @node.Node::with_measure("node", root_child0_child1_style, root_child0_child1_measure)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child2 = @node.Node::with_measure("node", root_child0_child2_style, root_child0_child2_measure)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child3 = @node.Node::with_measure("node", root_child0_child3_style, root_child0_child3_measure)
  root_child0_children.push(root_child0_child3)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 140.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 140.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 70.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[1].x, 20.0)
  assert_approx(layout.children[0].children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[0].children[1].width, 50.0)
  assert_approx(layout.children[0].children[0].children[1].height, 10.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].height, 10.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[0].height, 3.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[1].x, 20.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[1].width, 2.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[1].height, 3.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[2].x, 0.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[2].y, 3.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[2].height, 1.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[3].x, 20.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[3].y, 3.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[3].width, 2.0)
  assert_approx(layout.children[0].children[0].children[1].children[0].children[3].height, 1.0)
  assert_approx(layout.children[0].children[1].x, 70.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 70.0)
  assert_approx(layout.children[0].children[1].height, 10.0)
  assert_approx(layout.children[0].children[2].x, 0.0)
  assert_approx(layout.children[0].children[2].y, 10.0)
  assert_approx(layout.children[0].children[2].width, 70.0)
  assert_approx(layout.children[0].children[2].height, 10.0)
  assert_approx(layout.children[0].children[3].x, 70.0)
  assert_approx(layout.children[0].children[3].y, 10.0)
  assert_approx(layout.children[0].children[3].width, 70.0)
  assert_approx(layout.children[0].children[3].height, 10.0)
}

///|
test "taffy/gridflex_kitchen_sink_minimise" {
  let root_style = {
    ..@style.Style::default(),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Fr(1.0), @style.Fr(1.0)],
    grid_template_rows: [@style.Length(20.0)],
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1 = @node.Node::leaf("node", root_child0_child1_style)
  root_child0_children.push(root_child0_child1)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 100.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 100.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 50.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[0].children[1].x, 50.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 50.0)
  assert_approx(layout.children[0].children[1].height, 20.0)
}

///|
test "taffy/gridflex_kitchen_sink_minimise2" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Auto],
    grid_template_rows: [@style.Auto],
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let root_child0_child0 = @node.Node::leaf("node", root_child0_child0_style)
  root_child0_children.push(root_child0_child0)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
}

///|
test "taffy/gridflex_kitchen_sink_minimise3" {
  let root_style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Auto, @style.Percent(0.1000)],
    grid_template_rows: [@style.Percent(0.3000), @style.Percent(0.1000)],
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
    width: @types.Length(20.0),
    height: @types.Length(20.0),
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
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 50.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 20.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 20.0)
  assert_approx(layout.children[0].children[1].x, 20.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 2.0)
  assert_approx(layout.children[0].children[1].height, 6.0)
  assert_approx(layout.children[0].children[2].x, 0.0)
  assert_approx(layout.children[0].children[2].y, 6.0)
  assert_approx(layout.children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[2].height, 2.0)
  assert_approx(layout.children[0].children[3].x, 20.0)
  assert_approx(layout.children[0].children[3].y, 6.0)
  assert_approx(layout.children[0].children[3].width, 2.0)
  assert_approx(layout.children[0].children[3].height, 2.0)
}

///|
test "taffy/gridflex_row_integration" {
  let root_style = {
    ..@style.Style::default(),
  }
  let root_children : Array[@node.Node] = []
  let root_child0_style = {
    ..@style.Style::default(),
    display: @style.Grid,
    grid_template_columns: [@style.Fr(1.0), @style.Fr(1.0)],
    grid_template_rows: [@style.Fr(1.0), @style.Fr(1.0)],
  }
  let root_child0_children : Array[@node.Node] = []
  let root_child0_child0_style = {
    ..@style.Style::default(),
  }
  let root_child0_child0_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child0 = @node.Node::with_measure("node", root_child0_child0_style, root_child0_child0_measure)
  root_child0_children.push(root_child0_child0)
  let root_child0_child1_style = {
    ..@style.Style::default(),
  }
  let root_child0_child1_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child1 = @node.Node::with_measure("node", root_child0_child1_style, root_child0_child1_measure)
  root_child0_children.push(root_child0_child1)
  let root_child0_child2_style = {
    ..@style.Style::default(),
  }
  let root_child0_child2_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child2 = @node.Node::with_measure("node", root_child0_child2_style, root_child0_child2_measure)
  root_child0_children.push(root_child0_child2)
  let root_child0_child3_style = {
    ..@style.Style::default(),
  }
  let root_child0_child3_measure = @node.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @node.IntrinsicSize {
      { min_width: 20.0, max_width: 20.0, min_height: 10.0, max_height: 10.0 }
    }
  }
  let root_child0_child3 = @node.Node::with_measure("node", root_child0_child3_style, root_child0_child3_measure)
  root_child0_children.push(root_child0_child3)
  let root_child0 = @node.Node::new("node", root_child0_style, root_child0_children)
  root_children.push(root_child0)
  let root = @node.Node::new("test-root", root_style, root_children)

  let layout = compute_grid_layout(root, 800.0, 600.0)

  assert_approx(layout.x, 0.0)
  assert_approx(layout.y, 0.0)
  assert_approx(layout.width, 40.0)
  assert_approx(layout.height, 20.0)
  assert_approx(layout.children[0].x, 0.0)
  assert_approx(layout.children[0].y, 0.0)
  assert_approx(layout.children[0].width, 40.0)
  assert_approx(layout.children[0].height, 20.0)
  assert_approx(layout.children[0].children[0].x, 0.0)
  assert_approx(layout.children[0].children[0].y, 0.0)
  assert_approx(layout.children[0].children[0].width, 20.0)
  assert_approx(layout.children[0].children[0].height, 10.0)
  assert_approx(layout.children[0].children[1].x, 20.0)
  assert_approx(layout.children[0].children[1].y, 0.0)
  assert_approx(layout.children[0].children[1].width, 20.0)
  assert_approx(layout.children[0].children[1].height, 10.0)
  assert_approx(layout.children[0].children[2].x, 0.0)
  assert_approx(layout.children[0].children[2].y, 10.0)
  assert_approx(layout.children[0].children[2].width, 20.0)
  assert_approx(layout.children[0].children[2].height, 10.0)
  assert_approx(layout.children[0].children[3].x, 20.0)
  assert_approx(layout.children[0].children[3].y, 10.0)
  assert_approx(layout.children[0].children[3].width, 20.0)
  assert_approx(layout.children[0].children[3].height, 10.0)
}
