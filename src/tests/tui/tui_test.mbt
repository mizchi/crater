///|
/// TUI API Subset Tests
/// These tests verify the stable API subset for TUI applications.
/// See docs/tui-api.md for documentation.

///|
/// Test basic flex vertical layout (Column)
test "tui/flex_vertical_stack" {
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column
  root_style.width = @types.Dimension::Length(80.0)
  root_style.height = @types.Dimension::Length(24.0)
  let header_style = @layout.Style::default()
  header_style.height = @types.Dimension::Length(3.0)
  let content_style = @layout.Style::default()
  content_style.flex_grow = 1.0
  let footer_style = @layout.Style::default()
  footer_style.height = @types.Dimension::Length(1.0)
  let root = @layout.Node::new("root", root_style, [
    @layout.Node::leaf("header", header_style),
    @layout.Node::leaf("content", content_style),
    @layout.Node::leaf("footer", footer_style),
  ])
  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))

  // Verify root dimensions
  inspect(layout.width, content="80")
  inspect(layout.height, content="24")

  // Verify header
  let header = layout.children[0]
  inspect(header.id, content="header")
  inspect(header.y, content="0")
  inspect(header.height, content="3")

  // Verify content (flexible, fills remaining space)
  let content = layout.children[1]
  inspect(content.id, content="content")
  inspect(content.y, content="3")
  inspect(content.height, content="20")

  // Verify footer
  let footer = layout.children[2]
  inspect(footer.id, content="footer")
  inspect(footer.y, content="23")
  inspect(footer.height, content="1")
}

///|
/// Test basic flex horizontal layout (Row)
test "tui/flex_horizontal_split" {
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Row
  root_style.width = @types.Dimension::Length(80.0)
  root_style.height = @types.Dimension::Length(24.0)
  let sidebar_style = @layout.Style::default()
  sidebar_style.width = @types.Dimension::Length(20.0)
  let main_style = @layout.Style::default()
  main_style.flex_grow = 1.0
  let root = @layout.Node::new("root", root_style, [
    @layout.Node::leaf("sidebar", sidebar_style),
    @layout.Node::leaf("main", main_style),
  ])
  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))

  // Verify sidebar
  let sidebar = layout.children[0]
  inspect(sidebar.x, content="0")
  inspect(sidebar.width, content="20")

  // Verify main content
  let main = layout.children[1]
  inspect(main.x, content="20")
  inspect(main.width, content="60")
}

///|
/// Test flex with gap
test "tui/flex_with_gap" {
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Row
  root_style.width = @types.Dimension::Length(80.0)
  root_style.column_gap = @types.Dimension::Length(2.0)
  let child_style = @layout.Style::default()
  child_style.width = @types.Dimension::Length(10.0)
  let root = @layout.Node::new("root", root_style, [
    @layout.Node::leaf("a", child_style),
    @layout.Node::leaf("b", child_style),
    @layout.Node::leaf("c", child_style),
  ])
  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))

  // Items should be spaced with 2-unit gaps
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[1].x, content="12") // 10 + 2
  inspect(layout.children[2].x, content="24") // 10 + 2 + 10 + 2
}

///|
/// Test grid coordinate-based placement
test "tui/grid_coordinate_placement" {
  let grid_style = @layout.Style::default()
  grid_style.display = @types.Grid
  grid_style.width = @types.Dimension::Length(80.0)
  grid_style.height = @types.Dimension::Length(24.0)
  grid_style.grid_template_columns = [
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Fr(1.0),
  ]
  grid_style.grid_template_rows = [
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Fr(1.0),
  ]

  // Header: spans full width (1,1) -> (4,2)
  let header_style = @layout.Style::default()
  header_style.grid_column = {
    start: @types.GridPlacement::Line(1),
    end: @types.GridPlacement::Line(4),
  }
  header_style.grid_row = {
    start: @types.GridPlacement::Line(1),
    end: @types.GridPlacement::Line(2),
  }

  // Sidebar: left column (1,2) -> (2,4)
  let sidebar_style = @layout.Style::default()
  sidebar_style.grid_column = {
    start: @types.GridPlacement::Line(1),
    end: @types.GridPlacement::Line(2),
  }
  sidebar_style.grid_row = {
    start: @types.GridPlacement::Line(2),
    end: @types.GridPlacement::Line(4),
  }

  // Main: right columns (2,2) -> (4,4)
  let main_style = @layout.Style::default()
  main_style.grid_column = {
    start: @types.GridPlacement::Line(2),
    end: @types.GridPlacement::Line(4),
  }
  main_style.grid_row = {
    start: @types.GridPlacement::Line(2),
    end: @types.GridPlacement::Line(4),
  }
  let root = @layout.Node::new("root", grid_style, [
    @layout.Node::leaf("header", header_style),
    @layout.Node::leaf("sidebar", sidebar_style),
    @layout.Node::leaf("main", main_style),
  ])
  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))

  // Verify header spans full width
  let header = layout.children[0]
  inspect(header.width, content="80")

  // Verify sidebar is 1/3 width
  let sidebar = layout.children[1]
  // Grid column width: 80 / 3 ≈ 26.67
  assert_true(sidebar.width > 26.0 && sidebar.width < 27.0)

  // Verify main is 2/3 width
  let main = layout.children[2]
  // Grid column width: 80 * 2 / 3 ≈ 53.33
  assert_true(main.width > 53.0 && main.width < 54.0)
}

///|
/// Test grid with named areas
test "tui/grid_named_areas" {
  let grid_style = @layout.Style::default()
  grid_style.display = @types.Grid
  grid_style.width = @types.Dimension::Length(80.0)
  grid_style.height = @types.Dimension::Length(24.0)
  grid_style.grid_template_columns = [
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Fr(2.0),
  ]
  grid_style.grid_template_rows = [
    @types.TrackSizingFunction::Length(3.0),
    @types.TrackSizingFunction::Fr(1.0),
  ]
  grid_style.grid_template_areas = ["header header", "sidebar main"]
  let header_style = @layout.Style::default()
  header_style.grid_area = Some("header")
  let sidebar_style = @layout.Style::default()
  sidebar_style.grid_area = Some("sidebar")
  let main_style = @layout.Style::default()
  main_style.grid_area = Some("main")
  let root = @layout.Node::new("root", grid_style, [
    @layout.Node::leaf("header", header_style),
    @layout.Node::leaf("sidebar", sidebar_style),
    @layout.Node::leaf("main", main_style),
  ])
  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))

  // Verify header spans full width
  let header = layout.children[0]
  inspect(header.width, content="80")
  inspect(header.height, content="3")

  // Verify sidebar is 1/3 width (Fr(1) / (Fr(1) + Fr(2)))
  let sidebar = layout.children[1]
  // Width: 80 / 3 ≈ 26.67
  assert_true(sidebar.width > 26.0 && sidebar.width < 27.0)

  // Verify main is 2/3 width
  let main = layout.children[2]
  // Width: 80 * 2 / 3 ≈ 53.33
  assert_true(main.width > 53.0 && main.width < 54.0)
}

///|
/// Test measure function for text content
test "tui/measure_func" {
  let text = "Hello, World!"
  let text_width = text.length().to_double()
  let measure = @types.MeasureFunc::{
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      {
        min_width: 1.0,
        max_width: text_width,
        min_height: 1.0,
        max_height: 1.0,
      }
    },
  }
  let style = @layout.Style::default()
  let node = @layout.Node::with_measure("text", style, measure, text~)
  let layout = @crater.compute_layout(node, @types.Size::new(80.0, 24.0))

  // Width should be based on text measurement
  inspect(layout.width, content="13")
  inspect(layout.height, content="1")
  inspect(layout.text, content="Some(\"Hello, World!\")")
}

///|
/// Test Dimension variants
test "tui/dimension_variants" {
  // Length
  let len : @types.Dimension = @types.Dimension::Length(100.0)
  inspect(len.resolve(200.0), content="Some(100)")

  // Percent
  let pct : @types.Dimension = @types.Dimension::Percent(50.0)
  inspect(pct.resolve(200.0), content="Some(10000)")

  // Auto
  let auto : @types.Dimension = @types.Auto
  inspect(auto.resolve(200.0), content="None")

  // is_definite
  assert_true(len.is_definite())
  assert_true(pct.is_definite())
  assert_false(auto.is_definite())
}

///|
/// Test Size and Rect utilities
test "tui/size_rect_utilities" {
  // Size
  let size : @types.Size[Double] = @types.Size::new(80.0, 24.0)
  inspect(size.width, content="80")
  inspect(size.height, content="24")

  // Rect::zero
  let zero : @types.Rect[Double] = @types.Rect::zero()
  inspect(zero.left, content="0")
  inspect(zero.right, content="0")

  // Rect::all
  let all : @types.Rect[Double] = @types.Rect::all(5.0)
  inspect(all.left, content="5")
  inspect(all.top, content="5")
}

///|
/// Test margin and padding
test "tui/box_model" {
  let root_style = @layout.Style::default()
  root_style.display = @types.Block
  root_style.width = @types.Dimension::Length(80.0)
  root_style.height = @types.Dimension::Length(24.0)
  let child_style = @layout.Style::default()
  child_style.margin = {
    left: @types.Dimension::Length(2.0),
    right: @types.Dimension::Length(2.0),
    top: @types.Dimension::Length(1.0),
    bottom: @types.Dimension::Length(1.0),
  }
  child_style.padding = @types.Rect::all(@types.Dimension::Length(1.0))
  child_style.width = @types.Dimension::Length(40.0)
  child_style.height = @types.Dimension::Length(10.0)
  let root = @layout.Node::new("root", root_style, [
    @layout.Node::leaf("child", child_style),
  ])
  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))
  let child = layout.children[0]

  // Position should account for margin
  inspect(child.x, content="2")
  inspect(child.y, content="1")

  // Verify margin values
  inspect(child.margin.left, content="2")
  inspect(child.margin.top, content="1")

  // Verify padding values
  inspect(child.padding.left, content="1")
  inspect(child.padding.top, content="1")
}

///|
/// Test align-items center
test "tui/flex_align_center" {
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Row
  root_style.align_items = @types.Center
  root_style.width = @types.Dimension::Length(80.0)
  root_style.height = @types.Dimension::Length(24.0)
  let child_style = @layout.Style::default()
  child_style.width = @types.Dimension::Length(20.0)
  child_style.height = @types.Dimension::Length(10.0)
  let root = @layout.Node::new("root", root_style, [
    @layout.Node::leaf("child", child_style),
  ])
  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))
  let child = layout.children[0]

  // Child should be vertically centered: (24 - 10) / 2 = 7
  inspect(child.y, content="7")
}

///|
/// Test justify-content space-between
test "tui/flex_justify_space_between" {
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Row
  root_style.justify_content = @types.SpaceBetween
  root_style.width = @types.Dimension::Length(80.0)
  let child_style = @layout.Style::default()
  child_style.width = @types.Dimension::Length(10.0)
  let root = @layout.Node::new("root", root_style, [
    @layout.Node::leaf("a", child_style),
    @layout.Node::leaf("b", child_style),
    @layout.Node::leaf("c", child_style),
  ])
  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))

  // First item at start
  inspect(layout.children[0].x, content="0")

  // Last item at end
  inspect(layout.children[2].x, content="70") // 80 - 10

  // Middle item centered
  inspect(layout.children[1].x, content="35") // (80 - 10) / 2
}

///|
/// Test Layout struct fields
test "tui/layout_struct_fields" {
  let style = @layout.Style::default()
  style.width = @types.Dimension::Length(50.0)
  style.height = @types.Dimension::Length(20.0)
  style.overflow_x = @types.Hidden
  style.overflow_y = @types.Scroll
  let node = @layout.Node::leaf("test", style)
  let layout = @crater.compute_layout(node, @types.Size::new(80.0, 24.0))

  // Verify all expected fields exist
  inspect(layout.id, content="test")
  inspect(layout.x, content="0")
  inspect(layout.y, content="0")
  inspect(layout.width, content="50")
  inspect(layout.height, content="20")
  inspect(layout.overflow_x, content="Hidden")
  inspect(layout.overflow_y, content="Scroll")

  // margin, padding, border should be Rect[Double]
  let _ = layout.margin.left
  let _ = layout.padding.top
  let _ = layout.border.right

  // children should be Array[Layout]
  inspect(layout.children.length(), content="0")
}

///|
/// Test nested flex layout (typical TUI structure)
test "tui/nested_flex_layout" {
  // Root: vertical flex
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column
  root_style.width = @types.Dimension::Length(80.0)
  root_style.height = @types.Dimension::Length(24.0)

  // Header: fixed
  let header_style = @layout.Style::default()
  header_style.height = @types.Dimension::Length(1.0)

  // Body: horizontal flex, fills space
  let body_style = @layout.Style::default()
  body_style.display = @types.Flex
  body_style.flex_direction = @types.Row
  body_style.flex_grow = 1.0

  // Sidebar: fixed width
  let sidebar_style = @layout.Style::default()
  sidebar_style.width = @types.Dimension::Length(20.0)

  // Main: fills remaining
  let main_style = @layout.Style::default()
  main_style.flex_grow = 1.0

  // Footer: fixed
  let footer_style = @layout.Style::default()
  footer_style.height = @types.Dimension::Length(1.0)
  let body = @layout.Node::new("body", body_style, [
    @layout.Node::leaf("sidebar", sidebar_style),
    @layout.Node::leaf("main", main_style),
  ])
  let root = @layout.Node::new("root", root_style, [
    @layout.Node::leaf("header", header_style),
    body,
    @layout.Node::leaf("footer", footer_style),
  ])
  let layout = @crater.compute_layout(root, @types.Size::new(80.0, 24.0))

  // Header
  let header = layout.children[0]
  inspect(header.height, content="1")

  // Body
  let body_layout = layout.children[1]
  inspect(body_layout.y, content="1")
  inspect(body_layout.height, content="22") // 24 - 1 - 1

  // Sidebar
  let sidebar = body_layout.children[0]
  inspect(sidebar.width, content="20")

  // Main
  let main = body_layout.children[1]
  inspect(main.width, content="60")

  // Footer
  let footer = layout.children[2]
  inspect(footer.y, content="23")
  inspect(footer.height, content="1")
}

// =============================================================================
// LayoutTree (Incremental Layout) Tests
// =============================================================================

///|
/// Test LayoutTree basic creation and computation
test "tui/layout_tree_basic" {
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column
  root_style.width = @types.Dimension::Length(80.0)
  root_style.height = @types.Dimension::Length(24.0)
  let child_style = @layout.Style::default()
  child_style.flex_grow = 1.0
  let root = @layout.Node::new("root", root_style, [
    @layout.Node::leaf("header", child_style),
    @layout.Node::leaf("content", child_style),
  ])

  // Create LayoutTree from Node
  let tree = @layout.LayoutTree::from_node(root, 80.0, 24.0)

  // Compute layout
  let layout = tree.compute_incremental()

  // Verify layout results
  inspect(layout.width, content="80")
  inspect(layout.height, content="24")
  inspect(layout.children.length(), content="2")
}

///|
/// Test LayoutTree with LayoutNode setters
test "tui/layout_tree_with_layout_node" {
  // Build tree using LayoutNode directly
  let root = @layout.LayoutNode::create_with_id("root")
    .set_display(@types.Flex)
    .set_flex_direction(@types.Column)
    .set_width(80.0)
    .set_height(24.0)
  let header = @layout.LayoutNode::create_with_id("header").set_height(3.0)
  let content = @layout.LayoutNode::create_with_id("content").set_flex_grow(1.0)
  let footer = @layout.LayoutNode::create_with_id("footer").set_height(1.0)
  let root_with_children = root
    .add_child(header)
    .add_child(content)
    .add_child(footer)
  let tree = @layout.LayoutTree::new(root_with_children, 80.0, 24.0)
  let layout = tree.compute_incremental()

  // Verify
  inspect(layout.children[0].height, content="3")
  inspect(layout.children[1].height, content="20") // 24 - 3 - 1
  inspect(layout.children[2].height, content="1")
}

///|
/// Test LayoutTree incremental update with dirty marking
test "tui/layout_tree_incremental_update" {
  let root = @layout.LayoutNode::create_with_id("root")
    .set_display(@types.Flex)
    .set_flex_direction(@types.Row)
    .set_width(80.0)
    .set_height(24.0)
  let left = @layout.LayoutNode::create_with_id("left").set_width(20.0)
  let right = @layout.LayoutNode::create_with_id("right").set_flex_grow(1.0)
  let root_with_children = root.add_child(left).add_child(right)
  let tree = @layout.LayoutTree::new(root_with_children, 80.0, 24.0)

  // Initial layout
  let layout1 = tree.compute_incremental()
  inspect(layout1.children[0].width, content="20")
  inspect(layout1.children[1].width, content="60")

  // Modify left panel width
  match tree.find_node_by_id("left") {
    Some(node) => {
      let _ = node.set_width(30.0)
      // This marks the node dirty
    }
    None => ()
  }

  // Recompute - should use incremental update
  let layout2 = tree.compute_incremental()
  inspect(layout2.children[0].width, content="30") // Updated from 20 to 30
  inspect(layout2.children[1].width, content="50") // Flex takes remaining space: 80 - 30 = 50
}

///|
/// Test LayoutTree viewport resize
/// Note: Percent values use 0.0-1.0 range (0.25 = 25%)
test "tui/layout_tree_resize_viewport" {
  let root = @layout.LayoutNode::create_with_id("root")
    .set_display(@types.Flex)
    .set_flex_direction(@types.Row)
    .set_width_percent(1.0) // 100%
    .set_height_percent(1.0) // 100%
  let left = @layout.LayoutNode::create_with_id("left").set_width_percent(0.25) // 25%
  let right = @layout.LayoutNode::create_with_id("right").set_flex_grow(1.0)
  let root_with_children = root.add_child(left).add_child(right)
  let tree = @layout.LayoutTree::new(root_with_children, 80.0, 24.0)

  // Initial layout at 80x24
  let layout1 = tree.compute_incremental()
  inspect(layout1.width, content="80") // 100% of 80
  inspect(layout1.children[0].width, content="20") // 25% of 80

  // Resize viewport to 120x30
  tree.resize_viewport(120.0, 30.0)

  // Recompute
  let layout2 = tree.compute_incremental()
  inspect(layout2.width, content="120") // 100% of 120
  inspect(layout2.children[0].width, content="30") // 25% of 120
}

///|
/// Test LayoutTree find_node_by_id
test "tui/layout_tree_find_node" {
  let root = @layout.LayoutNode::create_with_id("root")
    .set_display(@types.Flex)
    .set_flex_direction(@types.Column)
  let header = @layout.LayoutNode::create_with_id("header").set_height(3.0)
  let content = @layout.LayoutNode::create_with_id("content").set_flex_grow(1.0)
  let root_with_children = root.add_child(header).add_child(content)
  let tree = @layout.LayoutTree::new(root_with_children, 80.0, 24.0)

  // Find existing nodes
  assert_true(tree.find_node_by_id("root") is Some(_))
  assert_true(tree.find_node_by_id("header") is Some(_))
  assert_true(tree.find_node_by_id("content") is Some(_))

  // Non-existent node
  assert_true(tree.find_node_by_id("nonexistent") is None)
}

///|
/// Test LayoutTree needs_layout check
test "tui/layout_tree_needs_layout" {
  let root = @layout.LayoutNode::create_with_id("root")
    .set_width(80.0)
    .set_height(24.0)
  let tree = @layout.LayoutTree::new(root, 80.0, 24.0)

  // Initially needs layout
  assert_true(tree.needs_layout())

  // After compute, should not need layout
  let _ = tree.compute_incremental()
  assert_false(tree.needs_layout())

  // After modification, should need layout again
  match tree.find_node_by_id("root") {
    Some(node) => {
      let _ = node.set_width(100.0)

    }
    None => ()
  }
  assert_true(tree.needs_layout())
}

///|
/// Test LayoutNode dirty tracking
test "tui/layout_node_dirty_tracking" {
  let node = @layout.LayoutNode::create_with_id("test").set_width(50.0)

  // Initially dirty (new node)
  assert_true(node.is_dirty())

  // Clear dirty flag
  node.clear_dirty()
  assert_false(node.is_dirty())

  // Modification marks dirty
  let _ = node.set_width(100.0)
  assert_true(node.is_dirty())
}

///|
/// Test LayoutNode conversion from Node
test "tui/layout_node_from_node" {
  let style = @layout.Style::default()
  style.display = @types.Flex
  style.width = @types.Dimension::Length(80.0)
  let node = @layout.Node::new("root", style, [
    @layout.Node::leaf("child", @layout.Style::default()),
  ])

  // Convert to LayoutNode
  let layout_node = @layout.LayoutNode::from_node(node)
  inspect(layout_node.id, content="root")
  inspect(layout_node.get_child_count(), content="1")

  // Can be used in LayoutTree
  let tree = @layout.LayoutTree::new(layout_node, 80.0, 24.0)
  let layout = tree.compute_incremental()
  inspect(layout.width, content="80")
}

///|
/// Test layout package convenience API
/// This demonstrates how to use the simplified API from mizchi/crater/layout
test "tui/layout_package_api" {
  // @layout for Style/Node, @types for enums
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column
  root_style.width = @types.Length(80.0)
  root_style.height = @types.Length(24.0)

  // Create nodes using layout package
  let header_style = @layout.Style::default()
  header_style.height = @types.Length(3.0)
  let content_style = @layout.Style::default()
  content_style.flex_grow = 1.0
  let root = @layout.Node::new("root", root_style, [
    @layout.Node::leaf("header", header_style),
    @layout.Node::leaf("content", content_style),
  ])

  // Compute layout using crater
  let result = @crater.compute_layout(root, @layout.size(80.0, 24.0))
  inspect(result.width, content="80")
  inspect(result.height, content="24")
  inspect(result.children[0].height, content="3")
  inspect(result.children[1].height, content="21")
}

///|
/// Test layout package LayoutTree API
test "tui/layout_package_tree_api" {
  // @layout for LayoutNode/LayoutTree, @types for enums
  let root = @layout.layout_node_create("root")
    .set_display(@types.Flex)
    .set_flex_direction(@types.Row)
    .set_width(100.0)
    .set_height(50.0)
  let left = @layout.layout_node_create("left").set_width(30.0)
  let right = @layout.layout_node_create("right").set_flex_grow(1.0)
  let root_with_children = root.add_child(left).add_child(right)

  // Create tree using layout package function
  let tree = @layout.layout_tree(root_with_children, 100.0, 50.0)
  let layout = tree.compute_incremental()
  inspect(layout.children[0].width, content="30")
  inspect(layout.children[1].width, content="70")

  // Modify and recompute
  match tree.find_node_by_id("left") {
    Some(node) => {
      let _ = node.set_width(40.0)

    }
    None => ()
  }
  let layout2 = tree.compute_incremental()
  inspect(layout2.children[0].width, content="40")
  inspect(layout2.children[1].width, content="60")
}
