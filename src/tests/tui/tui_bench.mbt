// =============================================================================
// TUI API Benchmarks
// =============================================================================
// Benchmarks using only the stable TUI API subset from @layout package.
// See docs/tui-api.md for the API specification.

// =============================================================================
// Basic Flex Layout Benchmarks
// =============================================================================

///|
/// Create a simple vertical flex layout with N children
fn create_vertical_flex(n : Int) -> @layout.Node {
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column
  root_style.width = @types.Length(80.0)
  root_style.height = @types.Length(24.0)
  let children : Array[@layout.Node] = []
  for i = 0; i < n; i = i + 1 {
    let child_style = @layout.Style::default()
    child_style.height = @types.Length(1.0)
    children.push(@layout.Node::leaf("child\{i}", child_style))
  }
  @layout.Node::new("root", root_style, children)
}

///|
/// Create a horizontal flex layout with N children
fn create_horizontal_flex(n : Int) -> @layout.Node {
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Row
  root_style.width = @types.Length(80.0)
  root_style.height = @types.Length(24.0)
  let children : Array[@layout.Node] = []
  for i = 0; i < n; i = i + 1 {
    let child_style = @layout.Style::default()
    child_style.width = @types.Length(10.0)
    children.push(@layout.Node::leaf("child\{i}", child_style))
  }
  @layout.Node::new("root", root_style, children)
}

///|
test "bench_tui_vertical_flex_10" (b : @bench.T) {
  let node = create_vertical_flex(10)
  let viewport = @layout.size(80.0, 24.0)
  b.bench(name="tui_vertical_flex_10", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

///|
test "bench_tui_vertical_flex_50" (b : @bench.T) {
  let node = create_vertical_flex(50)
  let viewport = @layout.size(80.0, 24.0)
  b.bench(name="tui_vertical_flex_50", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

///|
test "bench_tui_horizontal_flex_10" (b : @bench.T) {
  let node = create_horizontal_flex(10)
  let viewport = @layout.size(80.0, 24.0)
  b.bench(name="tui_horizontal_flex_10", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

// =============================================================================
// Nested Flex Layout Benchmarks (Typical TUI Structure)
// =============================================================================

///|
/// Create a typical TUI layout: header + sidebar/main + footer
fn create_tui_app_layout() -> @layout.Node {
  // Root: vertical flex
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column
  root_style.width = @types.Length(80.0)
  root_style.height = @types.Length(24.0)

  // Header
  let header_style = @layout.Style::default()
  header_style.height = @types.Length(1.0)

  // Body: horizontal flex
  let body_style = @layout.Style::default()
  body_style.display = @types.Flex
  body_style.flex_direction = @types.Row
  body_style.flex_grow = 1.0

  // Sidebar
  let sidebar_style = @layout.Style::default()
  sidebar_style.width = @types.Length(20.0)

  // Main
  let main_style = @layout.Style::default()
  main_style.flex_grow = 1.0

  // Footer
  let footer_style = @layout.Style::default()
  footer_style.height = @types.Length(1.0)
  let body = @layout.Node::new("body", body_style, [
    @layout.Node::leaf("sidebar", sidebar_style),
    @layout.Node::leaf("main", main_style),
  ])
  @layout.Node::new("root", root_style, [
    @layout.Node::leaf("header", header_style),
    body,
    @layout.Node::leaf("footer", footer_style),
  ])
}

///|
/// Create a deeply nested TUI layout
fn create_nested_tui_layout(depth : Int) -> @layout.Node {
  fn build(d : Int, is_row : Bool) -> @layout.Node {
    if d == 0 {
      let leaf_style = @layout.Style::default()
      leaf_style.width = @types.Length(10.0)
      leaf_style.height = @types.Length(5.0)
      return @layout.Node::leaf("leaf", leaf_style)
    }
    let style = @layout.Style::default()
    style.display = @types.Flex
    style.flex_direction = if is_row { @types.Row } else { @types.Column }
    let children : Array[@layout.Node] = []
    for i = 0; i < 3; i = i + 1 {
      children.push(build(d - 1, not(is_row)))
    }
    @layout.Node::new("node_d\{d}", style, children)
  }

  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.width = @types.Length(80.0)
  root_style.height = @types.Length(24.0)
  @layout.Node::new("root", root_style, [build(depth, true)])
}

///|
test "bench_tui_app_layout" (b : @bench.T) {
  let node = create_tui_app_layout()
  let viewport = @layout.size(80.0, 24.0)
  b.bench(name="tui_app_layout", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

///|
test "bench_tui_nested_depth3" (b : @bench.T) {
  let node = create_nested_tui_layout(3)
  let viewport = @layout.size(80.0, 24.0)
  b.bench(name="tui_nested_d3", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

///|
test "bench_tui_nested_depth5" (b : @bench.T) {
  let node = create_nested_tui_layout(5)
  let viewport = @layout.size(80.0, 24.0)
  b.bench(name="tui_nested_d5", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

// =============================================================================
// Grid Layout Benchmarks
// =============================================================================

///|
/// Create a TUI grid layout (3x3)
fn create_tui_grid_3x3() -> @layout.Node {
  let grid_style = @layout.Style::default()
  grid_style.display = @types.Grid
  grid_style.width = @types.Length(80.0)
  grid_style.height = @types.Length(24.0)
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
  let children : Array[@layout.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@layout.Node::leaf("cell\{i}", @layout.Style::default()))
  }
  @layout.Node::new("grid", grid_style, children)
}

///|
/// Create a TUI grid with named areas
fn create_tui_grid_named_areas() -> @layout.Node {
  let grid_style = @layout.Style::default()
  grid_style.display = @types.Grid
  grid_style.width = @types.Length(80.0)
  grid_style.height = @types.Length(24.0)
  grid_style.grid_template_columns = [
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Fr(2.0),
  ]
  grid_style.grid_template_rows = [
    @types.TrackSizingFunction::Length(3.0),
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Length(1.0),
  ]
  grid_style.grid_template_areas = [
    "header header", "sidebar main", "footer footer",
  ]
  let header_style = @layout.Style::default()
  header_style.grid_area = Some("header")
  let sidebar_style = @layout.Style::default()
  sidebar_style.grid_area = Some("sidebar")
  let main_style = @layout.Style::default()
  main_style.grid_area = Some("main")
  let footer_style = @layout.Style::default()
  footer_style.grid_area = Some("footer")
  @layout.Node::new("grid", grid_style, [
    @layout.Node::leaf("header", header_style),
    @layout.Node::leaf("sidebar", sidebar_style),
    @layout.Node::leaf("main", main_style),
    @layout.Node::leaf("footer", footer_style),
  ])
}

///|
test "bench_tui_grid_3x3" (b : @bench.T) {
  let node = create_tui_grid_3x3()
  let viewport = @layout.size(80.0, 24.0)
  b.bench(name="tui_grid_3x3", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

///|
test "bench_tui_grid_named_areas" (b : @bench.T) {
  let node = create_tui_grid_named_areas()
  let viewport = @layout.size(80.0, 24.0)
  b.bench(name="tui_grid_named", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

// =============================================================================
// MeasureFunc Benchmarks (Text Content)
// =============================================================================

///|
/// Create a text node with measure function
fn create_text_node(text : String) -> @layout.Node {
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
  @layout.Node::with_measure("text", @layout.Style::default(), measure, text~)
}

///|
/// Create a layout with many text nodes
fn create_text_list(n : Int) -> @layout.Node {
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column
  root_style.width = @types.Length(80.0)
  let children : Array[@layout.Node] = []
  for i = 0; i < n; i = i + 1 {
    children.push(create_text_node("Line \{i}: Some text content here"))
  }
  @layout.Node::new("root", root_style, children)
}

///|
test "bench_tui_text_list_10" (b : @bench.T) {
  let node = create_text_list(10)
  let viewport = @layout.size(80.0, 24.0)
  b.bench(name="tui_text_list_10", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

///|
test "bench_tui_text_list_50" (b : @bench.T) {
  let node = create_text_list(50)
  let viewport = @layout.size(80.0, 24.0)
  b.bench(name="tui_text_list_50", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

// =============================================================================
// LayoutTree (Incremental) Benchmarks
// =============================================================================

///|
/// Create a LayoutNode tree for incremental benchmarks
fn create_layout_node_tree(n_items : Int) -> @layout.LayoutNode {
  let root = @layout.layout_node_create("root")
    .set_display(@types.Flex)
    .set_flex_direction(@types.Column)
    .set_width(80.0)
    .set_height(24.0)
  let header = @layout.layout_node_create("header").set_height(1.0)
  let content = @layout.layout_node_create("content")
    .set_display(@types.Flex)
    .set_flex_direction(@types.Column)
    .set_flex_grow(1.0)
  for i = 0; i < n_items; i = i + 1 {
    let item = @layout.layout_node_create("item\{i}").set_height(1.0)
    let _ = content.add_child(item)

  }
  let footer = @layout.layout_node_create("footer").set_height(1.0)
  root.add_child(header).add_child(content).add_child(footer)
}

///|
test "bench_tui_incremental_full_20" (b : @bench.T) {
  let root = create_layout_node_tree(20)
  let tree = @layout.layout_tree(root, 80.0, 24.0)
  b.bench(name="tui_incr_full_20", fn() {
    tree.mark_node_dirty(tree.root.uid)
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_tui_incremental_cached_20" (b : @bench.T) {
  let root = create_layout_node_tree(20)
  let tree = @layout.layout_tree(root, 80.0, 24.0)
  // Initial full compute
  let _ = tree.compute_incremental()
  b.bench(name="tui_incr_cached_20", fn() {
    // No dirty nodes - pure cache hit
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_tui_incremental_single_dirty_20" (b : @bench.T) {
  let root = create_layout_node_tree(20)
  let tree = @layout.layout_tree(root, 80.0, 24.0)
  let _ = tree.compute_incremental()
  // Find a middle item
  let target = tree.find_node_by_id("item10")
  b.bench(name="tui_incr_single_20", fn() {
    match target {
      Some(node) => tree.mark_node_dirty(node.uid)
      None => ()
    }
    b.keep(tree.compute_incremental())
  })
}

// =============================================================================
// Realistic TUI Application Benchmarks
// =============================================================================

///|
/// Create a file browser TUI layout
fn create_file_browser_layout(n_files : Int) -> @layout.Node {
  // Root: vertical flex
  let root_style = @layout.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column
  root_style.width = @types.Length(120.0)
  root_style.height = @types.Length(40.0)

  // Header (title bar)
  let header_style = @layout.Style::default()
  header_style.height = @types.Length(1.0)

  // Body: horizontal flex
  let body_style = @layout.Style::default()
  body_style.display = @types.Flex
  body_style.flex_direction = @types.Row
  body_style.flex_grow = 1.0

  // Tree view (left panel)
  let tree_style = @layout.Style::default()
  tree_style.display = @types.Flex
  tree_style.flex_direction = @types.Column
  tree_style.width = @types.Length(30.0)
  let tree_items : Array[@layout.Node] = []
  for i = 0; i < 10; i = i + 1 {
    let item_style = @layout.Style::default()
    item_style.height = @types.Length(1.0)
    tree_items.push(@layout.Node::leaf("tree_item\{i}", item_style))
  }
  let tree = @layout.Node::new("tree", tree_style, tree_items)

  // File list (center panel)
  let list_style = @layout.Style::default()
  list_style.display = @types.Flex
  list_style.flex_direction = @types.Column
  list_style.flex_grow = 1.0
  let list_items : Array[@layout.Node] = []
  for i = 0; i < n_files; i = i + 1 {
    let item_style = @layout.Style::default()
    item_style.height = @types.Length(1.0)
    list_items.push(@layout.Node::leaf("file\{i}", item_style))
  }
  let list = @layout.Node::new("list", list_style, list_items)

  // Preview (right panel)
  let preview_style = @layout.Style::default()
  preview_style.width = @types.Length(40.0)
  let preview = @layout.Node::leaf("preview", preview_style)
  let body = @layout.Node::new("body", body_style, [tree, list, preview])

  // Status bar
  let status_style = @layout.Style::default()
  status_style.height = @types.Length(1.0)
  @layout.Node::new("root", root_style, [
    @layout.Node::leaf("header", header_style),
    body,
    @layout.Node::leaf("status", status_style),
  ])
}

///|
/// Create a dashboard TUI layout
fn create_dashboard_layout() -> @layout.Node {
  let grid_style = @layout.Style::default()
  grid_style.display = @types.Grid
  grid_style.width = @types.Length(120.0)
  grid_style.height = @types.Length(40.0)
  grid_style.grid_template_columns = [
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Fr(1.0),
  ]
  grid_style.grid_template_rows = [
    @types.TrackSizingFunction::Length(3.0),
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Fr(1.0),
  ]
  grid_style.grid_template_areas = [
    "header header header", "stats1 stats2 stats3", "chart chart logs",
  ]
  let header_style = @layout.Style::default()
  header_style.grid_area = Some("header")
  let stats1_style = @layout.Style::default()
  stats1_style.grid_area = Some("stats1")
  let stats2_style = @layout.Style::default()
  stats2_style.grid_area = Some("stats2")
  let stats3_style = @layout.Style::default()
  stats3_style.grid_area = Some("stats3")
  let chart_style = @layout.Style::default()
  chart_style.grid_area = Some("chart")
  let logs_style = @layout.Style::default()
  logs_style.grid_area = Some("logs")
  @layout.Node::new("dashboard", grid_style, [
    @layout.Node::leaf("header", header_style),
    @layout.Node::leaf("stats1", stats1_style),
    @layout.Node::leaf("stats2", stats2_style),
    @layout.Node::leaf("stats3", stats3_style),
    @layout.Node::leaf("chart", chart_style),
    @layout.Node::leaf("logs", logs_style),
  ])
}

///|
test "bench_tui_file_browser_50" (b : @bench.T) {
  let node = create_file_browser_layout(50)
  let viewport = @layout.size(120.0, 40.0)
  b.bench(name="tui_file_browser_50", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

///|
test "bench_tui_file_browser_200" (b : @bench.T) {
  let node = create_file_browser_layout(200)
  let viewport = @layout.size(120.0, 40.0)
  b.bench(name="tui_file_browser_200", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

///|
test "bench_tui_dashboard" (b : @bench.T) {
  let node = create_dashboard_layout()
  let viewport = @layout.size(120.0, 40.0)
  b.bench(name="tui_dashboard", fn() {
    b.keep(@crater.compute_layout(node, viewport))
  })
}

// =============================================================================
// Large Scale TUI Benchmarks
// =============================================================================

///|
/// Create a large scrollable list TUI
fn create_large_list(n : Int) -> @layout.LayoutNode {
  let root = @layout.layout_node_create("root")
    .set_display(@types.Flex)
    .set_flex_direction(@types.Column)
    .set_width(80.0)
    .set_height(24.0)
  let header = @layout.layout_node_create("header").set_height(1.0)
  let content = @layout.layout_node_create("content")
    .set_display(@types.Flex)
    .set_flex_direction(@types.Column)
    .set_flex_grow(1.0)

  // Create list items
  for i = 0; i < n; i = i + 1 {
    let item = @layout.layout_node_create("item\{i}")
      .set_display(@types.Flex)
      .set_flex_direction(@types.Row)
      .set_height(1.0)
    let icon = @layout.layout_node_create("icon\{i}").set_width(3.0)
    let text = @layout.layout_node_create("text\{i}").set_flex_grow(1.0)
    let _ = item.add_child(icon).add_child(text)
    let _ = content.add_child(item)

  }
  let footer = @layout.layout_node_create("footer").set_height(1.0)
  root.add_child(header).add_child(content).add_child(footer)
}

///|
test "bench_tui_large_list_100_full" (b : @bench.T) {
  let root = create_large_list(100)
  let tree = @layout.layout_tree(root, 80.0, 24.0)
  b.bench(name="tui_list_100_full", fn() {
    tree.mark_node_dirty(tree.root.uid)
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_tui_large_list_100_cached" (b : @bench.T) {
  let root = create_large_list(100)
  let tree = @layout.layout_tree(root, 80.0, 24.0)
  let _ = tree.compute_incremental()
  b.bench(name="tui_list_100_cached", fn() {
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_tui_large_list_500_full" (b : @bench.T) {
  let root = create_large_list(500)
  let tree = @layout.layout_tree(root, 80.0, 24.0)
  b.bench(name="tui_list_500_full", fn() {
    tree.mark_node_dirty(tree.root.uid)
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_tui_large_list_500_single_dirty" (b : @bench.T) {
  let root = create_large_list(500)
  let tree = @layout.layout_tree(root, 80.0, 24.0)
  let _ = tree.compute_incremental()
  let target = tree.find_node_by_id("item250")
  b.bench(name="tui_list_500_single", fn() {
    match target {
      Some(node) => tree.mark_node_dirty(node.uid)
      None => ()
    }
    b.keep(tree.compute_incremental())
  })
}

// =============================================================================
// Viewport Resize Benchmarks
// =============================================================================

///|
test "bench_tui_resize_percent" (b : @bench.T) {
  let root = @layout.layout_node_create("root")
    .set_display(@types.Flex)
    .set_flex_direction(@types.Row)
    .set_width_percent(1.0)
    .set_height_percent(1.0)
  let left = @layout.layout_node_create("left").set_width_percent(0.25)
  let right = @layout.layout_node_create("right").set_flex_grow(1.0)
  let root_with_children = root.add_child(left).add_child(right)
  let tree = @layout.layout_tree(root_with_children, 80.0, 24.0)
  let _ = tree.compute_incremental()
  let mut width = 80.0
  b.bench(name="tui_resize_percent", fn() {
    width = if width == 80.0 { 120.0 } else { 80.0 }
    tree.resize_viewport(width, 24.0)
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_tui_resize_fixed" (b : @bench.T) {
  let root = @layout.layout_node_create("root")
    .set_display(@types.Flex)
    .set_flex_direction(@types.Row)
    .set_width(80.0)
    .set_height(24.0)
  let left = @layout.layout_node_create("left").set_width(20.0)
  let right = @layout.layout_node_create("right").set_flex_grow(1.0)
  let root_with_children = root.add_child(left).add_child(right)
  let tree = @layout.layout_tree(root_with_children, 80.0, 24.0)
  let _ = tree.compute_incremental()
  let mut width = 80.0
  b.bench(name="tui_resize_fixed", fn() {
    width = if width == 80.0 { 120.0 } else { 80.0 }
    tree.resize_viewport(width, 24.0)
    b.keep(tree.compute_incremental())
  })
}
