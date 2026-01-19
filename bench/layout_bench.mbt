// =============================================================================
// Layout Engine Benchmarks
// =============================================================================

///|
/// Compute layout for a node tree with given viewport
fn compute_layout(
  node : @node.Node,
  viewport : @types.Size[Double],
) -> @node.Layout {
  let ctx : @node.LayoutContext = {
    available_width: viewport.width,
    available_height: Some(viewport.height),
    sizing_mode: @node.MaxContent,
    viewport_width: viewport.width,
    viewport_height: viewport.height,
  }
  @dispatch.compute(node, ctx)
}

///|
/// Create a simple flat block layout with N children
fn create_flat_block(n : Int) -> @node.Node {
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < n; i = i + 1 {
    let child_style = { ..default_style, height: @types.Length(20.0) }
    children.push(@node.Node::leaf("child\{i}", child_style))
  }
  let root_style = { ..default_style, width: @types.Length(400.0) }
  @node.Node::new("root", root_style, children)
}

///|
/// Create a nested block layout with depth D and children per level
fn create_nested_block(depth : Int, children_per_level : Int) -> @node.Node {
  let default_style = @style.Style::default()
  fn build(d : Int) -> @node.Node {
    if d == 0 {
      let leaf_style = { ..default_style, height: @types.Length(10.0) }
      return @node.Node::leaf("leaf", leaf_style)
    }
    let children : Array[@node.Node] = []
    for i = 0; i < children_per_level; i = i + 1 {
      children.push(build(d - 1))
    }
    let style = {
      ..default_style,
      padding: {
        left: @types.Length(5.0),
        right: @types.Length(5.0),
        top: @types.Length(5.0),
        bottom: @types.Length(5.0),
      },
    }
    @node.Node::new("node_d\{d}", style, children)
  }

  let root_style = { ..default_style, width: @types.Length(800.0) }
  @node.Node::new("root", root_style, [build(depth)])
}

///|
/// Create a flex row layout with N children
fn create_flex_row(n : Int) -> @node.Node {
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < n; i = i + 1 {
    let child_style = {
      ..default_style,
      flex_grow: 1.0,
      height: @types.Length(50.0),
    }
    children.push(@node.Node::leaf("child\{i}", child_style))
  }
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(800.0),
    height: @types.Length(100.0),
  }
  @node.Node::new("root", root_style, children)
}

///|
/// Create a complex mixed layout (flex container with nested blocks)
fn create_complex_layout() -> @node.Node {
  let default_style = @style.Style::default()

  // Create sidebar with block children
  let sidebar_children : Array[@node.Node] = []
  for i = 0; i < 10; i = i + 1 {
    let item_style = {
      ..default_style,
      height: @types.Length(30.0),
      margin: {
        left: @types.Length(5.0),
        right: @types.Length(5.0),
        top: @types.Length(5.0),
        bottom: @types.Length(5.0),
      },
    }
    sidebar_children.push(@node.Node::leaf("sidebar_item\{i}", item_style))
  }
  let sidebar = @node.Node::new(
    "sidebar",
    { ..default_style, width: @types.Length(200.0) },
    sidebar_children,
  )

  // Create main content with nested structure
  let content_children : Array[@node.Node] = []
  for i = 0; i < 5; i = i + 1 {
    // Each section has a header and items
    let section_items : Array[@node.Node] = []
    let header_style = { ..default_style, height: @types.Length(40.0) }
    section_items.push(@node.Node::leaf("header\{i}", header_style))
    for j = 0; j < 3; j = j + 1 {
      let item_style = {
        ..default_style,
        height: @types.Length(25.0),
        margin: {
          left: @types.Length(10.0),
          right: @types.Length(10.0),
          top: @types.Length(0.0),
          bottom: @types.Length(10.0),
        },
      }
      section_items.push(@node.Node::leaf("item\{i}_\{j}", item_style))
    }
    let section_style = {
      ..default_style,
      padding: {
        left: @types.Length(10.0),
        right: @types.Length(10.0),
        top: @types.Length(10.0),
        bottom: @types.Length(10.0),
      },
    }
    content_children.push(
      @node.Node::new("section\{i}", section_style, section_items),
    )
  }
  let content = @node.Node::new(
    "content",
    { ..default_style, flex_grow: 1.0 },
    content_children,
  )

  // Root flex container
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(1200.0),
    height: @types.Length(800.0),
    padding: {
      left: @types.Length(20.0),
      right: @types.Length(20.0),
      top: @types.Length(20.0),
      bottom: @types.Length(20.0),
    },
  }
  @node.Node::new("root", root_style, [sidebar, content])
}

///|
/// Create a deeply nested flex layout
fn create_nested_flex(depth : Int) -> @node.Node {
  let default_style = @style.Style::default()
  fn build(d : Int, is_row : Bool) -> @node.Node {
    if d == 0 {
      let leaf_style = {
        ..default_style,
        width: @types.Length(20.0),
        height: @types.Length(20.0),
      }
      return @node.Node::leaf("leaf", leaf_style)
    }
    let children : Array[@node.Node] = []
    for i = 0; i < 3; i = i + 1 {
      children.push(build(d - 1, not(is_row)))
    }
    let style = {
      ..default_style,
      display: @style.Flex,
      flex_direction: if is_row {
        @style.Row
      } else {
        @style.Column
      },
    }
    @node.Node::new("flex_d\{d}", style, children)
  }

  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(600.0),
    height: @types.Length(400.0),
  }
  @node.Node::new("root", root_style, [build(depth, true)])
}

// =============================================================================
// Benchmarks
// =============================================================================

///|
test "bench_flat_block_10" (b : @bench.T) {
  let node = create_flat_block(10)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="flat_block_10", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_flat_block_100" (b : @bench.T) {
  let node = create_flat_block(100)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="flat_block_100", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_nested_block_depth5" (b : @bench.T) {
  let node = create_nested_block(5, 2)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="nested_block_d5", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
test "bench_flex_row_10" (b : @bench.T) {
  let node = create_flex_row(10)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="flex_row_10", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_flex_row_50" (b : @bench.T) {
  let node = create_flex_row(50)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="flex_row_50", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_complex_layout" (b : @bench.T) {
  let node = create_complex_layout()
  let viewport = @types.Size::new(1200.0, 800.0)
  b.bench(name="complex_layout", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_nested_flex_depth4" (b : @bench.T) {
  let node = create_nested_flex(4)
  let viewport = @types.Size::new(600.0, 400.0)
  b.bench(name="nested_flex_d4", fn() { b.keep(compute_layout(node, viewport)) })
}

// =============================================================================
// Intrinsic Sizing Benchmarks (for tracking performance during implementation)
// =============================================================================

///|
/// Create a layout that requires intrinsic sizing (auto width flex items)
fn create_intrinsic_sizing_test() -> @node.Node {
  let default_style = @style.Style::default()

  // Create items with explicit sizes (baseline for comparison)
  let explicit_children : Array[@node.Node] = []
  for i = 0; i < 5; i = i + 1 {
    let child_style = {
      ..default_style,
      width: @types.Length(100.0),
      height: @types.Length(50.0),
    }
    explicit_children.push(@node.Node::leaf("explicit\{i}", child_style))
  }
  let explicit_container = @node.Node::new(
    "explicit_container",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(600.0),
      height: @types.Length(100.0),
    },
    explicit_children,
  )

  // Root
  @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      width: @types.Length(800.0),
      height: @types.Length(600.0),
    },
    [explicit_container],
  )
}

///|
/// Create deeply nested layout (stress test for recursive intrinsic sizing)
fn create_deep_nested_intrinsic(depth : Int) -> @node.Node {
  let default_style = @style.Style::default()
  fn build(d : Int) -> @node.Node {
    if d == 0 {
      // Leaf with explicit size
      return @node.Node::leaf("leaf", {
        ..default_style,
        width: @types.Length(50.0),
        height: @types.Length(30.0),
      })
    }
    // Container with explicit size wrapping child
    let child = build(d - 1)
    @node.Node::new(
      "container_d\{d}",
      {
        ..default_style,
        display: @style.Flex,
        width: @types.Length(100.0 + d.to_double() * 20.0),
        height: @types.Length(60.0 + d.to_double() * 10.0),
      },
      [child],
    )
  }

  build(depth)
}

///|
test "bench_intrinsic_explicit_sizes" (b : @bench.T) {
  let node = create_intrinsic_sizing_test()
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="intrinsic_explicit", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
test "bench_deep_nested_d6" (b : @bench.T) {
  let node = create_deep_nested_intrinsic(6)
  let viewport = @types.Size::new(400.0, 300.0)
  b.bench(name="deep_nested_d6", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_deep_nested_d10" (b : @bench.T) {
  let node = create_deep_nested_intrinsic(10)
  let viewport = @types.Size::new(600.0, 400.0)
  b.bench(name="deep_nested_d10", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

// =============================================================================
// Grid Layout Benchmarks
// =============================================================================

///|
/// Create a simple 3x3 grid layout
fn create_grid_3x3() -> @node.Node {
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("cell\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @style.Grid,
    width: @types.Length(300.0),
    height: @types.Length(300.0),
    grid_template_columns: [
      @style.Length(100.0),
      @style.Length(100.0),
      @style.Length(100.0),
    ],
    grid_template_rows: [
      @style.Length(100.0),
      @style.Length(100.0),
      @style.Length(100.0),
    ],
  }
  @node.Node::new("grid", root_style, children)
}

///|
/// Create a larger 10x10 grid layout
fn create_grid_10x10() -> @node.Node {
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 100; i = i + 1 {
    children.push(@node.Node::leaf("cell\{i}", default_style))
  }
  let columns : Array[@style.TrackSizingFunction] = []
  let rows : Array[@style.TrackSizingFunction] = []
  for j = 0; j < 10; j = j + 1 {
    columns.push(@style.Length(50.0))
    rows.push(@style.Length(50.0))
  }
  let root_style = {
    ..default_style,
    display: @style.Grid,
    width: @types.Length(500.0),
    height: @types.Length(500.0),
    grid_template_columns: columns,
    grid_template_rows: rows,
  }
  @node.Node::new("grid", root_style, children)
}

///|
/// Create a grid with fr units
fn create_grid_fr() -> @node.Node {
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 12; i = i + 1 {
    children.push(@node.Node::leaf("cell\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @style.Grid,
    width: @types.Length(600.0),
    height: @types.Length(400.0),
    grid_template_columns: [@style.Fr(1.0), @style.Fr(2.0), @style.Fr(1.0)],
    grid_template_rows: [
      @style.Fr(1.0),
      @style.Fr(1.0),
      @style.Fr(1.0),
      @style.Fr(1.0),
    ],
  }
  @node.Node::new("grid", root_style, children)
}

///|
/// Create a grid with auto tracks
fn create_grid_auto() -> @node.Node {
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 20; i = i + 1 {
    let child_style = {
      ..default_style,
      width: @types.Length(50.0),
      height: @types.Length(30.0),
    }
    children.push(@node.Node::leaf("cell\{i}", child_style))
  }
  let root_style = {
    ..default_style,
    display: @style.Grid,
    width: @types.Length(500.0),
    grid_template_columns: [
      @style.Auto,
      @style.Auto,
      @style.Auto,
      @style.Auto,
      @style.Auto,
    ],
  }
  @node.Node::new("grid", root_style, children)
}

///|
test "bench_grid_3x3" (b : @bench.T) {
  let node = create_grid_3x3()
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="grid_3x3", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_grid_10x10" (b : @bench.T) {
  let node = create_grid_10x10()
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="grid_10x10", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_grid_fr" (b : @bench.T) {
  let node = create_grid_fr()
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="grid_fr", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_grid_auto" (b : @bench.T) {
  let node = create_grid_auto()
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="grid_auto", fn() { b.keep(compute_layout(node, viewport)) })
}

// =============================================================================
// Complex Case Benchmarks
// =============================================================================

///|
/// Create a flex layout with wrapping (many items that wrap to multiple lines)
fn create_flex_wrap_many() -> @node.Node {
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  // 50 items, each 100px wide, will wrap in a 600px container
  for i = 0; i < 50; i = i + 1 {
    let child_style = {
      ..default_style,
      width: @types.Length(100.0),
      height: @types.Length(50.0),
    }
    children.push(@node.Node::leaf("item\{i}", child_style))
  }
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    flex_wrap: @style.Wrap,
    width: @types.Length(600.0),
    height: @types.Length(600.0),
  }
  @node.Node::new("root", root_style, children)
}

///|
/// Create flex wrap with varying item sizes (more complex wrapping)
fn create_flex_wrap_varied() -> @node.Node {
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  let widths = [80.0, 120.0, 60.0, 150.0, 90.0, 100.0, 70.0, 130.0]
  for i = 0; i < 40; i = i + 1 {
    let child_style = {
      ..default_style,
      width: @types.Length(widths[i % 8]),
      height: @types.Length(40.0),
    }
    children.push(@node.Node::leaf("item\{i}", child_style))
  }
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    flex_wrap: @style.Wrap,
    width: @types.Length(500.0),
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
  }
  @node.Node::new("root", root_style, children)
}

///|
test "bench_flex_wrap_50" (b : @bench.T) {
  let node = create_flex_wrap_many()
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="flex_wrap_50", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_flex_wrap_varied" (b : @bench.T) {
  let node = create_flex_wrap_varied()
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="flex_wrap_varied", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

// =============================================================================
// Min/Max Constraints Benchmarks
// =============================================================================

///|
/// Create a layout with min/max constraints that are active
fn create_minmax_constraints() -> @node.Node {
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 20; i = i + 1 {
    // Items with flex_grow but constrained by min/max
    let child_style = {
      ..default_style,
      flex_grow: 1.0,
      min_width: @types.Length(50.0),
      max_width: @types.Length(150.0),
      height: @types.Length(40.0),
    }
    children.push(@node.Node::leaf("item\{i}", child_style))
  }
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    flex_wrap: @style.Wrap,
    width: @types.Length(800.0),
    height: @types.Length(400.0),
  }
  @node.Node::new("root", root_style, children)
}

///|
/// Create nested layout with percentage and min/max constraints
fn create_nested_percent_constraints() -> @node.Node {
  let default_style = @style.Style::default()

  // Create columns with percentage width and min-width constraints
  let columns : Array[@node.Node] = []
  for i = 0; i < 4; i = i + 1 {
    let column_children : Array[@node.Node] = []
    for j = 0; j < 5; j = j + 1 {
      let item_style = {
        ..default_style,
        height: @types.Percent(0.2),
        min_height: @types.Length(30.0),
      }
      column_children.push(@node.Node::leaf("item\{i}_\{j}", item_style))
    }
    let column_style = {
      ..default_style,
      width: @types.Percent(0.25),
      min_width: @types.Length(100.0),
      max_width: @types.Length(300.0),
    }
    columns.push(@node.Node::new("col\{i}", column_style, column_children))
  }
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(1000.0),
    height: @types.Length(500.0),
  }
  @node.Node::new("root", root_style, columns)
}

///|
test "bench_minmax_constraints" (b : @bench.T) {
  let node = create_minmax_constraints()
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="minmax_constraints", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
test "bench_nested_percent" (b : @bench.T) {
  let node = create_nested_percent_constraints()
  let viewport = @types.Size::new(1000.0, 500.0)
  b.bench(name="nested_percent", fn() { b.keep(compute_layout(node, viewport)) })
}

// =============================================================================
// Complex Alignment Benchmarks
// =============================================================================

///|
/// Create flex layout with space-between and center alignment
fn create_complex_alignment() -> @node.Node {
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 15; i = i + 1 {
    let child_style = {
      ..default_style,
      width: @types.Length(60.0 + (i % 3).to_double() * 20.0),
      height: @types.Length(40.0 + (i % 4).to_double() * 10.0),
    }
    children.push(@node.Node::leaf("item\{i}", child_style))
  }
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    flex_wrap: @style.Wrap,
    justify_content: @style.SpaceBetween,
    align_items: @style.Center,
    align_content: @style.SpaceAround,
    width: @types.Length(500.0),
    height: @types.Length(400.0),
    row_gap: @types.Length(15.0),
    column_gap: @types.Length(10.0),
  }
  @node.Node::new("root", root_style, children)
}

///|
test "bench_complex_alignment" (b : @bench.T) {
  let node = create_complex_alignment()
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="complex_alignment", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

// =============================================================================
// Mixed Nested Layout Benchmarks
// =============================================================================

///|
/// Create a mixed layout: flex container with grid children and block grandchildren
fn create_mixed_flex_grid() -> @node.Node {
  let default_style = @style.Style::default()

  // Create grid sections
  let grids : Array[@node.Node] = []
  for i = 0; i < 3; i = i + 1 {
    let grid_children : Array[@node.Node] = []
    for j = 0; j < 9; j = j + 1 {
      let cell_children : Array[@node.Node] = []
      for k = 0; k < 2; k = k + 1 {
        cell_children.push(
          @node.Node::leaf("block\{i}_\{j}_\{k}", {
            ..default_style,
            height: @types.Length(15.0),
          }),
        )
      }
      grid_children.push(
        @node.Node::new("cell\{i}_\{j}", default_style, cell_children),
      )
    }
    let grid_style = {
      ..default_style,
      display: @style.Grid,
      flex_grow: 1.0,
      grid_template_columns: [@style.Fr(1.0), @style.Fr(1.0), @style.Fr(1.0)],
      grid_template_rows: [@style.Fr(1.0), @style.Fr(1.0), @style.Fr(1.0)],
      row_gap: @types.Length(5.0),
      column_gap: @types.Length(5.0),
    }
    grids.push(@node.Node::new("grid\{i}", grid_style, grid_children))
  }
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_direction: @style.Row,
    width: @types.Length(900.0),
    height: @types.Length(400.0),
    column_gap: @types.Length(20.0),
  }
  @node.Node::new("root", root_style, grids)
}

///|
test "bench_mixed_flex_grid" (b : @bench.T) {
  let node = create_mixed_flex_grid()
  let viewport = @types.Size::new(900.0, 400.0)
  b.bench(name="mixed_flex_grid", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

// =============================================================================
// Realistic UI Layout Benchmarks
// =============================================================================

///|
/// Create a dashboard-like layout with sidebar, header, and main content grid
fn create_dashboard_layout() -> @node.Node {
  let default_style = @style.Style::default()

  // Sidebar with nav items
  let nav_items : Array[@node.Node] = []
  for i = 0; i < 12; i = i + 1 {
    nav_items.push(
      @node.Node::leaf("nav\{i}", {
        ..default_style,
        height: @types.Length(40.0),
        margin: {
          left: @types.Length(8.0),
          right: @types.Length(8.0),
          top: @types.Length(4.0),
          bottom: @types.Length(4.0),
        },
      }),
    )
  }
  let sidebar = @node.Node::new(
    "sidebar",
    {
      ..default_style,
      width: @types.Length(240.0),
      padding: {
        left: @types.Length(16.0),
        right: @types.Length(16.0),
        top: @types.Length(16.0),
        bottom: @types.Length(16.0),
      },
    },
    nav_items,
  )

  // Header
  let header_items : Array[@node.Node] = []
  for i = 0; i < 5; i = i + 1 {
    header_items.push(
      @node.Node::leaf("header_item\{i}", {
        ..default_style,
        width: @types.Length(100.0),
        height: @types.Length(36.0),
      }),
    )
  }
  let header = @node.Node::new(
    "header",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Row,
      justify_content: @style.SpaceBetween,
      align_items: @style.Center,
      height: @types.Length(60.0),
      padding: {
        left: @types.Length(24.0),
        right: @types.Length(24.0),
        top: @types.Length(12.0),
        bottom: @types.Length(12.0),
      },
    },
    header_items,
  )

  // Main content grid (cards)
  let cards : Array[@node.Node] = []
  for i = 0; i < 12; i = i + 1 {
    let card_content : Array[@node.Node] = []
    card_content.push(
      @node.Node::leaf("card_title\{i}", {
        ..default_style,
        height: @types.Length(24.0),
      }),
    )
    card_content.push(
      @node.Node::leaf("card_body\{i}", {
        ..default_style,
        height: @types.Length(80.0),
      }),
    )
    card_content.push(
      @node.Node::leaf("card_footer\{i}", {
        ..default_style,
        height: @types.Length(32.0),
      }),
    )
    cards.push(
      @node.Node::new(
        "card\{i}",
        {
          ..default_style,
          padding: {
            left: @types.Length(16.0),
            right: @types.Length(16.0),
            top: @types.Length(16.0),
            bottom: @types.Length(16.0),
          },
        },
        card_content,
      ),
    )
  }
  let main_grid = @node.Node::new(
    "main_grid",
    {
      ..default_style,
      display: @style.Grid,
      flex_grow: 1.0,
      grid_template_columns: [
        @style.Fr(1.0),
        @style.Fr(1.0),
        @style.Fr(1.0),
        @style.Fr(1.0),
      ],
      row_gap: @types.Length(16.0),
      column_gap: @types.Length(16.0),
      padding: {
        left: @types.Length(24.0),
        right: @types.Length(24.0),
        top: @types.Length(24.0),
        bottom: @types.Length(24.0),
      },
    },
    cards,
  )

  // Main area (header + grid)
  let main_area = @node.Node::new(
    "main_area",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      flex_grow: 1.0,
    },
    [header, main_grid],
  )

  // Root
  @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Row,
      width: @types.Length(1440.0),
      height: @types.Length(900.0),
    },
    [sidebar, main_area],
  )
}

///|
/// Create a form layout with labels, inputs, and validation messages
fn create_form_layout() -> @node.Node {
  let default_style = @style.Style::default()
  let form_fields : Array[@node.Node] = []
  for i = 0; i < 10; i = i + 1 {
    let field_children : Array[@node.Node] = []
    // Label
    field_children.push(
      @node.Node::leaf("label\{i}", {
        ..default_style,
        height: @types.Length(20.0),
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(0.0),
          bottom: @types.Length(4.0),
        },
      }),
    )
    // Input row (input + button)
    let input_row_children : Array[@node.Node] = []
    input_row_children.push(
      @node.Node::leaf("input\{i}", {
        ..default_style,
        flex_grow: 1.0,
        height: @types.Length(36.0),
      }),
    )
    if i % 3 == 0 {
      input_row_children.push(
        @node.Node::leaf("btn\{i}", {
          ..default_style,
          width: @types.Length(80.0),
          height: @types.Length(36.0),
          margin: {
            left: @types.Length(8.0),
            right: @types.Length(0.0),
            top: @types.Length(0.0),
            bottom: @types.Length(0.0),
          },
        }),
      )
    }
    let input_row = @node.Node::new(
      "input_row\{i}",
      { ..default_style, display: @style.Flex, flex_direction: @style.Row },
      input_row_children,
    )
    field_children.push(input_row)
    // Validation message
    field_children.push(
      @node.Node::leaf("error\{i}", {
        ..default_style,
        height: @types.Length(16.0),
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(4.0),
          bottom: @types.Length(0.0),
        },
      }),
    )
    form_fields.push(
      @node.Node::new(
        "field\{i}",
        {
          ..default_style,
          margin: {
            left: @types.Length(0.0),
            right: @types.Length(0.0),
            top: @types.Length(0.0),
            bottom: @types.Length(16.0),
          },
        },
        field_children,
      ),
    )
  }
  @node.Node::new(
    "form",
    {
      ..default_style,
      width: @types.Length(400.0),
      padding: {
        left: @types.Length(24.0),
        right: @types.Length(24.0),
        top: @types.Length(24.0),
        bottom: @types.Length(24.0),
      },
    },
    form_fields,
  )
}

///|
test "bench_dashboard_layout" (b : @bench.T) {
  let node = create_dashboard_layout()
  let viewport = @types.Size::new(1440.0, 900.0)
  b.bench(name="dashboard_layout", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
test "bench_form_layout" (b : @bench.T) {
  let node = create_form_layout()
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="form_layout", fn() { b.keep(compute_layout(node, viewport)) })
}

// =============================================================================
// Stress Test Benchmarks
// =============================================================================

///|
/// Deep nesting with mixed display types
fn create_deep_mixed_nesting(depth : Int) -> @node.Node {
  let default_style = @style.Style::default()
  fn build(d : Int) -> @node.Node {
    if d == 0 {
      return @node.Node::leaf("leaf", {
        ..default_style,
        width: @types.Length(30.0),
        height: @types.Length(20.0),
      })
    }
    let children : Array[@node.Node] = []
    for i = 0; i < 3; i = i + 1 {
      children.push(build(d - 1))
    }

    // Alternate between flex, grid, and block
    let display = match d % 3 {
      0 => @style.Flex
      1 => @style.Grid
      _ => @style.Block
    }
    if display == @style.Grid {
      return @node.Node::new(
        "node_d\{d}",
        {
          ..default_style,
          display,
          grid_template_columns: [
            @style.Fr(1.0),
            @style.Fr(1.0),
            @style.Fr(1.0),
          ],
        },
        children,
      )
    }
    @node.Node::new(
      "node_d\{d}",
      {
        ..default_style,
        display,
        flex_direction: if d % 2 == 0 {
          @style.Row
        } else {
          @style.Column
        },
      },
      children,
    )
  }

  @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(800.0),
      height: @types.Length(600.0),
    },
    [build(depth)],
  )
}

///|
test "bench_deep_mixed_d5" (b : @bench.T) {
  let node = create_deep_mixed_nesting(5)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="deep_mixed_d5", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_deep_mixed_d6" (b : @bench.T) {
  let node = create_deep_mixed_nesting(6)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="deep_mixed_d6", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
/// Deep nesting with Flex only (for comparison)
fn create_deep_flex_nesting(depth : Int) -> @node.Node {
  let default_style = @style.Style::default()
  fn build(d : Int) -> @node.Node {
    if d == 0 {
      return @node.Node::leaf("leaf", {
        ..default_style,
        width: @types.Length(30.0),
        height: @types.Length(20.0),
      })
    }
    let children : Array[@node.Node] = []
    for i = 0; i < 3; i = i + 1 {
      children.push(build(d - 1))
    }
    @node.Node::new(
      "node_d\{d}",
      {
        ..default_style,
        display: @style.Flex,
        flex_direction: if d % 2 == 0 {
          @style.Row
        } else {
          @style.Column
        },
      },
      children,
    )
  }

  @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(800.0),
      height: @types.Length(600.0),
    },
    [build(depth)],
  )
}

///|
test "bench_deep_flex_d5" (b : @bench.T) {
  let node = create_deep_flex_nesting(5)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="deep_flex_d5", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_deep_flex_d6" (b : @bench.T) {
  let node = create_deep_flex_nesting(6)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="deep_flex_d6", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
/// Deep nesting with fixed-size intermediate nodes (baseline for optimization)
fn create_deep_flex_fixed(depth : Int) -> @node.Node {
  let default_style = @style.Style::default()
  fn build(d : Int) -> @node.Node {
    if d == 0 {
      return @node.Node::leaf("leaf", {
        ..default_style,
        width: @types.Length(30.0),
        height: @types.Length(20.0),
      })
    }
    let children : Array[@node.Node] = []
    for i = 0; i < 3; i = i + 1 {
      children.push(build(d - 1))
    }
    @node.Node::new(
      "node_d\{d}",
      {
        ..default_style,
        display: @style.Flex,
        flex_direction: if d % 2 == 0 {
          @style.Row
        } else {
          @style.Column
        },
        width: @types.Length(
          // Fixed size to skip intrinsic calculation
          100.0 * d.to_double(),
        ),
        height: @types.Length(80.0 * d.to_double()),
      },
      children,
    )
  }

  @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Length(800.0),
      height: @types.Length(600.0),
    },
    [build(depth)],
  )
}

///|
test "bench_deep_flex_fixed_d6" (b : @bench.T) {
  let node = create_deep_flex_fixed(6)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="deep_flex_fixed_d6", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

// =============================================================================
// Grid Intrinsic Sizing Benchmarks
// =============================================================================

///|
/// Grid with auto-sized columns containing nested flex containers
fn create_grid_auto_nested_flex(depth : Int) -> @node.Node {
  let default_style = @style.Style::default()
  fn create_flex_tree(d : Int) -> @node.Node {
    if d == 0 {
      return @node.Node::leaf("leaf", {
        ..default_style,
        width: @types.Length(30.0),
        height: @types.Length(20.0),
      })
    }
    let children : Array[@node.Node] = []
    for i = 0; i < 2; i = i + 1 {
      children.push(create_flex_tree(d - 1))
    }
    @node.Node::new(
      "flex_d\{d}",
      {
        ..default_style,
        display: @style.Flex,
        flex_direction: if d % 2 == 0 {
          @style.Row
        } else {
          @style.Column
        },
      },
      children,
    )
  }

  // Create grid cells with nested flex trees
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(create_flex_tree(depth))
  }
  @node.Node::new(
    "grid_root",
    {
      ..default_style,
      display: @style.Grid,
      width: @types.Length(600.0),
      grid_template_columns: [@style.Auto, @style.Auto, @style.Auto],
      grid_template_rows: [@style.Auto, @style.Auto, @style.Auto],
    },
    children,
  )
}

///|
test "bench_grid_auto_nested_d3" (b : @bench.T) {
  let node = create_grid_auto_nested_flex(3)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="grid_auto_nested_d3", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
test "bench_grid_auto_nested_d4" (b : @bench.T) {
  let node = create_grid_auto_nested_flex(4)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="grid_auto_nested_d4", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

// =============================================================================
// Large-Scale Website Benchmark (~5000 nodes)
// =============================================================================

///|
/// Create a realistic large-scale web page layout (~5000 nodes)
fn create_large_website_node(
  num_sidebar_items : Int,
  num_content_sections : Int,
  items_per_section : Int,
) -> @node.Node {
  let default_style = @style.Style::default()

  // Header
  let header_items : Array[@node.Node] = []
  for i = 0; i < 10; i = i + 1 {
    header_items.push(
      @node.Node::leaf("header_item\{i}", {
        ..default_style,
        width: @types.Length(80.0),
        height: @types.Length(40.0),
      }),
    )
  }
  let header = @node.Node::new(
    "header",
    {
      ..default_style,
      display: @style.Flex,
      width: @types.Percent(1.0),
      height: @types.Length(60.0),
    },
    header_items,
  )

  // Sidebar
  let sidebar_groups : Array[@node.Node] = []
  for g = 0; g < 5; g = g + 1 {
    let group_items : Array[@node.Node] = []
    for i = 0; i < num_sidebar_items / 5; i = i + 1 {
      let item = @node.Node::new(
        "sidebar_g\{g}_item\{i}",
        {
          ..default_style,
          display: @style.Flex,
          width: @types.Percent(1.0),
          height: @types.Length(36.0),
        },
        [
          @node.Node::leaf("icon_\{g}_\{i}", {
            ..default_style,
            width: @types.Length(20.0),
            height: @types.Length(20.0),
          }),
          @node.Node::leaf("label_\{g}_\{i}", {
            ..default_style,
            width: @types.Auto,
            height: @types.Length(20.0),
            flex_grow: 1.0,
          }),
        ],
      )
      group_items.push(item)
    }
    sidebar_groups.push(
      @node.Node::new(
        "sidebar_group\{g}",
        {
          ..default_style,
          display: @style.Flex,
          flex_direction: @style.Column,
          width: @types.Percent(1.0),
        },
        group_items,
      ),
    )
  }
  let sidebar = @node.Node::new(
    "sidebar",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      width: @types.Length(240.0),
    },
    sidebar_groups,
  )

  // Main content
  let sections : Array[@node.Node] = []
  for s = 0; s < num_content_sections; s = s + 1 {
    let section_header = @node.Node::new(
      "section_header\{s}",
      {
        ..default_style,
        display: @style.Flex,
        width: @types.Percent(1.0),
        height: @types.Length(48.0),
      },
      [
        @node.Node::leaf("section_title\{s}", {
          ..default_style,
          width: @types.Auto,
          height: @types.Length(24.0),
          flex_grow: 1.0,
        }),
        @node.Node::leaf("section_action\{s}", {
          ..default_style,
          width: @types.Length(100.0),
          height: @types.Length(32.0),
        }),
      ],
    )
    let cards : Array[@node.Node] = []
    for i = 0; i < items_per_section; i = i + 1 {
      let card = @node.Node::new(
        "card\{s}_\{i}",
        {
          ..default_style,
          display: @style.Flex,
          flex_direction: @style.Column,
          width: @types.Length(280.0),
        },
        [
          @node.Node::leaf("card_img\{s}_\{i}", {
            ..default_style,
            width: @types.Percent(1.0),
            height: @types.Length(160.0),
          }),
          @node.Node::new(
            "card_body\{s}_\{i}",
            {
              ..default_style,
              display: @style.Flex,
              flex_direction: @style.Column,
              width: @types.Percent(1.0),
            },
            [
              @node.Node::leaf("card_title\{s}_\{i}", {
                ..default_style,
                width: @types.Percent(1.0),
                height: @types.Length(24.0),
              }),
              @node.Node::leaf("card_desc\{s}_\{i}", {
                ..default_style,
                width: @types.Percent(1.0),
                height: @types.Length(48.0),
              }),
              @node.Node::new(
                "card_meta\{s}_\{i}",
                {
                  ..default_style,
                  display: @style.Flex,
                  width: @types.Percent(1.0),
                  height: @types.Length(20.0),
                },
                [
                  @node.Node::leaf("card_date\{s}_\{i}", {
                    ..default_style,
                    width: @types.Auto,
                    height: @types.Length(16.0),
                    flex_grow: 1.0,
                  }),
                  @node.Node::leaf("card_author\{s}_\{i}", {
                    ..default_style,
                    width: @types.Length(80.0),
                    height: @types.Length(16.0),
                  }),
                ],
              ),
            ],
          ),
          @node.Node::new(
            "card_actions\{s}_\{i}",
            {
              ..default_style,
              display: @style.Flex,
              width: @types.Percent(1.0),
              height: @types.Length(40.0),
            },
            [
              @node.Node::leaf("card_btn1\{s}_\{i}", {
                ..default_style,
                width: @types.Length(80.0),
                height: @types.Length(32.0),
              }),
              @node.Node::leaf("card_btn2\{s}_\{i}", {
                ..default_style,
                width: @types.Length(80.0),
                height: @types.Length(32.0),
              }),
            ],
          ),
        ],
      )
      cards.push(card)
    }
    let section_content = @node.Node::new(
      "section_content\{s}",
      {
        ..default_style,
        display: @style.Flex,
        flex_wrap: @style.Wrap,
        width: @types.Percent(1.0),
      },
      cards,
    )
    sections.push(
      @node.Node::new(
        "section\{s}",
        {
          ..default_style,
          display: @style.Flex,
          flex_direction: @style.Column,
          width: @types.Percent(1.0),
        },
        [section_header, section_content],
      ),
    )
  }
  let main_content = @node.Node::new(
    "main_content",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      flex_grow: 1.0,
    },
    sections,
  )

  // Body
  let body = @node.Node::new(
    "body",
    { ..default_style, display: @style.Flex, flex_grow: 1.0 },
    [sidebar, main_content],
  )

  // Footer
  let footer_items : Array[@node.Node] = []
  for i = 0; i < 20; i = i + 1 {
    footer_items.push(
      @node.Node::leaf("footer_link\{i}", {
        ..default_style,
        width: @types.Length(100.0),
        height: @types.Length(24.0),
      }),
    )
  }
  let footer = @node.Node::new(
    "footer",
    {
      ..default_style,
      display: @style.Flex,
      flex_wrap: @style.Wrap,
      width: @types.Percent(1.0),
    },
    footer_items,
  )

  // Root
  @node.Node::new(
    "root",
    {
      ..default_style,
      display: @style.Flex,
      flex_direction: @style.Column,
      width: @types.Length(1440.0),
      height: @types.Length(900.0),
    },
    [header, body, footer],
  )
}

///|
test "bench_large_website_5000" (b : @bench.T) {
  // ~5000 nodes: 50 sidebar items, 20 sections, 20 cards each
  let node = create_large_website_node(50, 20, 20)
  let viewport = @types.Size::new(1440.0, 900.0)
  b.bench(name="large_website_5000", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
test "bench_large_website_2000" (b : @bench.T) {
  // ~2000 nodes: 30 sidebar items, 10 sections, 15 cards each
  let node = create_large_website_node(30, 10, 15)
  let viewport = @types.Size::new(1440.0, 900.0)
  b.bench(name="large_website_2000", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
test "bench_large_website_10000" (b : @bench.T) {
  // ~10000 nodes: 100 sidebar items, 40 sections, 20 cards each
  let node = create_large_website_node(100, 40, 20)
  let viewport = @types.Size::new(1440.0, 900.0)
  b.bench(name="large_website_10000", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

// =============================================================================
// Incremental Layout Benchmarks
// =============================================================================

///|
/// Create LayoutNode tree for incremental benchmarks
fn create_large_layout_tree(
  num_sidebar : Int,
  num_sections : Int,
  cards_per_section : Int,
) -> (@tree.LayoutTree, Array[@tree.LayoutNode]) {
  let all_cards : Array[@tree.LayoutNode] = []

  // Sidebar items
  let sidebar_items : Array[@tree.LayoutNode] = []
  for i = 0; i < num_sidebar; i = i + 1 {
    sidebar_items.push(
      @tree.LayoutNode::leaf("sidebar_" + i.to_string(), @style.Style::{
        ..@style.Style::default(),
        width: @types.Length(180.0),
        height: @types.Length(40.0),
      }),
    )
  }
  let sidebar = @tree.LayoutNode::new(
    "sidebar",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      flex_direction: @style.Column,
      width: @types.Length(200.0),
      height: @types.Auto,
    },
    sidebar_items,
  )

  // Sections with cards
  let sections : Array[@tree.LayoutNode] = []
  for s = 0; s < num_sections; s = s + 1 {
    let cards : Array[@tree.LayoutNode] = []
    for c = 0; c < cards_per_section; c = c + 1 {
      let card = @tree.LayoutNode::new(
        "card_" + s.to_string() + "_" + c.to_string(),
        @style.Style::{
          ..@style.Style::default(),
          display: @style.Flex,
          flex_direction: @style.Column,
          width: @types.Length(280.0),
          height: @types.Length(200.0),
        },
        [
          @tree.LayoutNode::leaf("title", @style.Style::{
            ..@style.Style::default(),
            width: @types.Percent(1.0),
            height: @types.Length(24.0),
          }),
          @tree.LayoutNode::leaf("body", @style.Style::{
            ..@style.Style::default(),
            width: @types.Percent(1.0),
            height: @types.Length(100.0),
          }),
          @tree.LayoutNode::leaf("footer", @style.Style::{
            ..@style.Style::default(),
            width: @types.Percent(1.0),
            height: @types.Length(32.0),
          }),
        ],
      )
      cards.push(card)
      all_cards.push(card)
    }
    let section = @tree.LayoutNode::new(
      "section_" + s.to_string(),
      @style.Style::{
        ..@style.Style::default(),
        display: @style.Flex,
        flex_wrap: @style.Wrap,
        width: @types.Percent(1.0),
        height: @types.Auto,
      },
      cards,
    )
    sections.push(section)
  }
  let main = @tree.LayoutNode::new(
    "main",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      flex_direction: @style.Column,
      width: @types.Auto,
      height: @types.Auto,
      flex_grow: 1.0,
    },
    sections,
  )
  let body = @tree.LayoutNode::new(
    "body",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Percent(1.0),
      height: @types.Auto,
      flex_grow: 1.0,
    },
    [sidebar, main],
  )
  let root = @tree.LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      flex_direction: @style.Column,
      width: @types.Length(1440.0),
      height: @types.Length(900.0),
    },
    [body],
  )
  let tree = @tree.LayoutTree::new(root, 1440.0, 900.0)
  (tree, all_cards)
}

///|
test "bench_incremental_5000_full" (b : @bench.T) {
  @dispatch.setup()
  let (tree, _) = create_large_layout_tree(50, 20, 20)
  b.bench(name="incremental_5000_full", fn() {
    // Mark root dirty to force full recompute
    tree.mark_node_dirty(tree.root.uid)
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_incremental_5000_single_dirty" (b : @bench.T) {
  @dispatch.setup()
  let (tree, cards) = create_large_layout_tree(50, 20, 20)
  // Initial full compute
  let _ = tree.compute_incremental()
  let target_card = cards[cards.length() / 2]
  b.bench(name="incremental_5000_single", fn() {
    // Mark single card dirty
    tree.mark_node_dirty(target_card.uid)
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_incremental_5000_cached" (b : @bench.T) {
  @dispatch.setup()
  let (tree, _) = create_large_layout_tree(50, 20, 20)
  // Initial full compute
  let _ = tree.compute_incremental()
  b.bench(name="incremental_5000_cached", fn() {
    // No dirty nodes - pure cache hit
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_incremental_10000_full" (b : @bench.T) {
  @dispatch.setup()
  let (tree, _) = create_large_layout_tree(100, 40, 20)
  b.bench(name="incremental_10000_full", fn() {
    tree.mark_node_dirty(tree.root.uid)
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_incremental_10000_single_dirty" (b : @bench.T) {
  @dispatch.setup()
  let (tree, cards) = create_large_layout_tree(100, 40, 20)
  let _ = tree.compute_incremental()
  let target_card = cards[cards.length() / 2]
  b.bench(name="incremental_10000_single", fn() {
    tree.mark_node_dirty(target_card.uid)
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_incremental_10000_cached" (b : @bench.T) {
  @dispatch.setup()
  let (tree, _) = create_large_layout_tree(100, 40, 20)
  let _ = tree.compute_incremental()
  b.bench(name="incremental_10000_cached", fn() {
    b.keep(tree.compute_incremental())
  })
}

// =============================================================================
// CSS Containment Benchmarks
// =============================================================================
// These benchmarks measure the potential performance gains from CSS contain property.
// contain: size - allows skipping child layout when computing parent size
// contain: layout - isolates subtree layout from affecting parent

///|
/// Create a layout with many "cards" that could benefit from contain: size
/// Each card has a fixed size and contains complex nested content
fn create_contained_cards(
  num_cards : Int,
  items_per_card : Int,
  use_containment : Bool,
) -> @node.Node {
  let default_style = @style.Style::default()
  let cards : Array[@node.Node] = []
  for i = 0; i < num_cards; i = i + 1 {
    // Each card has nested items
    let items : Array[@node.Node] = []
    for j = 0; j < items_per_card; j = j + 1 {
      let item_style = { ..default_style, height: @types.Length(20.0) }
      items.push(@node.Node::leaf("item_\{i}_\{j}", item_style))
    }
    // Card style with optional containment
    let card_style = if use_containment {
      {
        ..default_style,
        width: @types.Length(200.0),
        height: @types.Length(300.0),
        contain: @style.Contain::strict(),
      }
    } else {
      {
        ..default_style,
        width: @types.Length(200.0),
        height: @types.Length(300.0),
      }
    }
    cards.push(@node.Node::new("card_\{i}", card_style, items))
  }
  let root_style = {
    ..default_style,
    display: @style.Flex,
    flex_wrap: @style.Wrap,
    width: @types.Length(1200.0),
  }
  @node.Node::new("root", root_style, cards)
}

///|
/// Create deeply nested layout with containment at certain levels
fn create_nested_with_containment(
  depth : Int,
  children_per_level : Int,
  containment_at_depth : Int,
  use_containment : Bool,
) -> @node.Node {
  let default_style = @style.Style::default()
  fn build(d : Int) -> @node.Node {
    if d == 0 {
      let leaf_style = { ..default_style, height: @types.Length(10.0) }
      return @node.Node::leaf("leaf", leaf_style)
    }
    let children : Array[@node.Node] = []
    for i = 0; i < children_per_level; i = i + 1 {
      children.push(build(d - 1))
    }
    let style = if use_containment && d == containment_at_depth {
      {
        ..default_style,
        padding: {
          left: @types.Length(5.0),
          right: @types.Length(5.0),
          top: @types.Length(5.0),
          bottom: @types.Length(5.0),
        },
        contain: @style.Contain::content(),
      }
    } else {
      {
        ..default_style,
        padding: {
          left: @types.Length(5.0),
          right: @types.Length(5.0),
          top: @types.Length(5.0),
          bottom: @types.Length(5.0),
        },
      }
    }
    @node.Node::new("node_d\{d}", style, children)
  }

  let root_style = { ..default_style, width: @types.Length(800.0) }
  @node.Node::new("root", root_style, [build(depth)])
}

///|
/// Benchmark: Cards WITHOUT containment (baseline)
test "bench_contain_cards_100_no_contain" (b : @bench.T) {
  @dispatch.setup()
  let node = create_contained_cards(100, 20, false)
  let viewport = @types.Size::new(1200.0, 2000.0)
  b.bench(name="cards_100_no_contain", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
/// Benchmark: Cards WITH contain: strict (should be faster when optimized)
test "bench_contain_cards_100_with_contain" (b : @bench.T) {
  @dispatch.setup()
  let node = create_contained_cards(100, 20, true)
  let viewport = @types.Size::new(1200.0, 2000.0)
  b.bench(name="cards_100_with_contain", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
/// Benchmark: Nested layout WITHOUT containment (baseline)
test "bench_contain_nested_no_contain" (b : @bench.T) {
  @dispatch.setup()
  // depth=6, 3 children per level = ~1000 nodes
  let node = create_nested_with_containment(6, 3, 3, false)
  let viewport = @types.Size::new(800.0, 2000.0)
  b.bench(name="nested_no_contain", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
/// Benchmark: Nested layout WITH contain: content at middle level
test "bench_contain_nested_with_contain" (b : @bench.T) {
  @dispatch.setup()
  // depth=6, 3 children per level, containment at depth 3
  let node = create_nested_with_containment(6, 3, 3, true)
  let viewport = @types.Size::new(800.0, 2000.0)
  b.bench(name="nested_with_contain", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
/// Create a layout where parent depends on children's intrinsic size
/// Cards have width: auto, so intrinsic calculation traverses deeply
/// When contain: size + explicit size, we skip deep traversal
fn create_intrinsic_dependent_layout(
  num_cards : Int,
  items_per_card : Int,
  use_containment : Bool,
) -> @node.Node {
  let default_style = @style.Style::default()
  let cards : Array[@node.Node] = []
  for i = 0; i < num_cards; i = i + 1 {
    // Each card has nested items with complex content
    let items : Array[@node.Node] = []
    for j = 0; j < items_per_card; j = j + 1 {
      // Items with nested children to create intrinsic size calculation
      let nested : Array[@node.Node] = []
      for k = 0; k < 5; k = k + 1 {
        // Deeply nested structure
        let deep : Array[@node.Node] = []
        for l = 0; l < 3; l = l + 1 {
          let leaf_style = {
            ..default_style,
            width: @types.Length(50.0),
            height: @types.Length(10.0),
          }
          deep.push(@node.Node::leaf("leaf_\{i}_\{j}_\{k}_\{l}", leaf_style))
        }
        let nested_style = { ..default_style }
        nested.push(
          @node.Node::new("nested_\{i}_\{j}_\{k}", nested_style, deep),
        )
      }
      let item_style = { ..default_style }
      items.push(@node.Node::new("item_\{i}_\{j}", item_style, nested))
    }
    // Card: containment version has fixed size, non-containment has width: auto
    let card_style = if use_containment {
      {
        ..default_style,
        width: @types.Length(200.0),
        height: @types.Length(300.0),
        contain: @style.Contain::strict(),
      }
    } else {
      // width: auto forces intrinsic size calculation through nested children
      { ..default_style, height: @types.Length(300.0) }
    }
    cards.push(@node.Node::new("card_\{i}", card_style, items))
  }
  // Parent with AUTO width - depends on children's intrinsic sizes
  let root_style = { ..default_style, display: @style.Flex, width: @types.Auto }
  @node.Node::new("root", root_style, cards)
}

///|
/// Benchmark: Intrinsic-dependent layout WITHOUT containment
test "bench_intrinsic_no_contain" (b : @bench.T) {
  @dispatch.setup()
  let node = create_intrinsic_dependent_layout(50, 10, false)
  let viewport = @types.Size::new(2000.0, 2000.0)
  b.bench(name="intrinsic_no_contain", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
/// Benchmark: Intrinsic-dependent layout WITH containment (should be faster)
test "bench_intrinsic_with_contain" (b : @bench.T) {
  @dispatch.setup()
  let node = create_intrinsic_dependent_layout(50, 10, true)
  let viewport = @types.Size::new(2000.0, 2000.0)
  b.bench(name="intrinsic_with_contain", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
/// Create simple deep tree to measure pure intrinsic calculation
fn create_pure_intrinsic_tree(
  depth : Int,
  width : Int,
  use_contain : Bool,
) -> @node.Node {
  let default_style = @style.Style::default()
  fn build(d : Int) -> @node.Node {
    if d == 0 {
      return @node.Node::leaf("leaf", {
        ..default_style,
        width: @types.Length(50.0),
        height: @types.Length(20.0),
      })
    }
    let children : Array[@node.Node] = []
    for i = 0; i < width; i = i + 1 {
      children.push(build(d - 1))
    }
    // At depth 2, apply containment if enabled
    let style = if use_contain && d == 2 {
      {
        ..default_style,
        width: @types.Length(200.0),
        height: @types.Length(100.0),
        contain: @style.Contain::strict(),
      }
    } else {
      default_style
    }
    @node.Node::new("node_\{d}", style, children)
  }
  // Root with width: auto triggers intrinsic calculation
  let root = build(depth)
  @node.Node::new(
    "root",
    { ..default_style, display: @style.Flex, width: @types.Auto },
    [root],
  )
}

///|
test "bench_pure_intrinsic_no_contain" (b : @bench.T) {
  @dispatch.setup()
  // depth 5, width 4 = 1365 nodes
  let node = create_pure_intrinsic_tree(5, 4, false)
  let viewport = @types.Size::new(2000.0, 2000.0)
  b.bench(name="pure_intrinsic_no", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

///|
test "bench_pure_intrinsic_with_contain" (b : @bench.T) {
  @dispatch.setup()
  // Same tree but with contain: size at depth 2
  let node = create_pure_intrinsic_tree(5, 4, true)
  let viewport = @types.Size::new(2000.0, 2000.0)
  b.bench(name="pure_intrinsic_yes", fn() {
    b.keep(compute_layout(node, viewport))
  })
}

// =============================================================================
// Incremental Layout + CSS Containment Benchmarks
// =============================================================================
// These benchmarks test the dirty propagation optimization with contain: layout
// Key: when marking a deep node dirty, contain: layout stops propagation at boundary
// This means fewer ancestor nodes need recomputation

///|
/// Create a deep tree for incremental layout testing with containment
/// Structure: root -> sections (with/without containment) -> cards -> items
fn create_incremental_containment_tree(
  num_sections : Int,
  cards_per_section : Int,
  items_per_card : Int,
  use_containment : Bool,
) -> (@tree.LayoutTree, Array[@tree.LayoutNode]) {
  let deep_items : Array[@tree.LayoutNode] = []
  let sections : Array[@tree.LayoutNode] = []
  for s = 0; s < num_sections; s = s + 1 {
    let cards : Array[@tree.LayoutNode] = []
    for c = 0; c < cards_per_section; c = c + 1 {
      let items : Array[@tree.LayoutNode] = []
      for i = 0; i < items_per_card; i = i + 1 {
        let item = @tree.LayoutNode::leaf(
          "item_" + s.to_string() + "_" + c.to_string() + "_" + i.to_string(),
          @style.Style::{
            ..@style.Style::default(),
            width: @types.Percent(1.0),
            height: @types.Length(20.0),
          },
        )
        items.push(item)
        deep_items.push(item)
      }
      let card = @tree.LayoutNode::new(
        "card_" + s.to_string() + "_" + c.to_string(),
        @style.Style::{
          ..@style.Style::default(),
          display: @style.Flex,
          flex_direction: @style.Column,
          width: @types.Length(280.0),
          height: @types.Length(200.0),
        },
        items,
      )
      cards.push(card)
    }
    // Section: with containment or without
    let section_style = if use_containment {
      @style.Style::{
        ..@style.Style::default(),
        display: @style.Flex,
        flex_wrap: @style.Wrap,
        width: @types.Percent(1.0),
        contain: @style.Contain::content(), // layout + paint + style
      }
    } else {
      @style.Style::{
        ..@style.Style::default(),
        display: @style.Flex,
        flex_wrap: @style.Wrap,
        width: @types.Percent(1.0),
      }
    }
    let section = @tree.LayoutNode::new(
      "section_" + s.to_string(),
      section_style,
      cards,
    )
    sections.push(section)
  }
  let main = @tree.LayoutNode::new(
    "main",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      flex_direction: @style.Column,
      width: @types.Percent(1.0),
      flex_grow: 1.0,
    },
    sections,
  )
  let root = @tree.LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      flex_direction: @style.Column,
      width: @types.Length(1440.0),
      height: @types.Length(900.0),
    },
    [main],
  )
  let tree = @tree.LayoutTree::new(root, 1440.0, 900.0)
  (tree, deep_items)
}

///|
/// Benchmark: Incremental layout after marking deep item dirty - WITHOUT containment
/// Dirty flag propagates all the way to root, so more nodes need to be checked
test "bench_incremental_contain_dirty_no" (b : @bench.T) {
  @dispatch.setup()
  // 10 sections, 10 cards each, 5 items per card = 500 items
  let (tree, items) = create_incremental_containment_tree(10, 10, 5, false)
  // Initial full compute
  let _ = tree.compute_incremental()
  // Target item in middle section
  let target = items[items.length() / 2]
  b.bench(name="incr_contain_dirty_no", fn() {
    // Mark deep item dirty - propagates to root
    tree.mark_node_dirty(target.uid)
    b.keep(tree.compute_incremental())
  })
}

///|
/// Benchmark: Incremental layout after marking deep item dirty - WITH containment
/// Dirty flag stops at section boundary due to contain: layout
test "bench_incremental_contain_dirty_yes" (b : @bench.T) {
  @dispatch.setup()
  // Same structure but sections have contain: content (includes layout)
  let (tree, items) = create_incremental_containment_tree(10, 10, 5, true)
  // Initial full compute
  let _ = tree.compute_incremental()
  // Target item in middle section
  let target = items[items.length() / 2]
  b.bench(name="incr_contain_dirty_yes", fn() {
    // Mark deep item dirty - propagation stops at section boundary
    tree.mark_node_dirty(target.uid)
    b.keep(tree.compute_incremental())
  })
}

///|
/// Benchmark: Multiple deep items marked dirty - WITHOUT containment
/// All dirty flags propagate to root, causing wide re-layout
test "bench_incremental_contain_multi_no" (b : @bench.T) {
  @dispatch.setup()
  let (tree, items) = create_incremental_containment_tree(10, 10, 5, false)
  let _ = tree.compute_incremental()
  // Mark items in different sections dirty
  let targets = [
    items[50], // Section 1
    items[150], // Section 3
    items[250], // Section 5
    items[350], // Section 7
    items[450],
  ] // Section 9
  b.bench(name="incr_contain_multi_no", fn() {
    for t in targets {
      tree.mark_node_dirty(t.uid)
    }
    b.keep(tree.compute_incremental())
  })
}

///|
/// Benchmark: Multiple deep items marked dirty - WITH containment
/// Each dirty section is isolated, only affected sections need re-layout
test "bench_incremental_contain_multi_yes" (b : @bench.T) {
  @dispatch.setup()
  let (tree, items) = create_incremental_containment_tree(10, 10, 5, true)
  let _ = tree.compute_incremental()
  let targets = [items[50], items[150], items[250], items[350], items[450]]
  b.bench(name="incr_contain_multi_yes", fn() {
    for t in targets {
      tree.mark_node_dirty(t.uid)
    }
    b.keep(tree.compute_incremental())
  })
}

///|
/// Larger scale: 50 sections to see more dramatic difference
test "bench_incremental_contain_large_no" (b : @bench.T) {
  @dispatch.setup()
  // 50 sections, 5 cards each, 4 items per card = 1000 items
  let (tree, items) = create_incremental_containment_tree(50, 5, 4, false)
  let _ = tree.compute_incremental()
  let target = items[items.length() / 2]
  b.bench(name="incr_contain_large_no", fn() {
    tree.mark_node_dirty(target.uid)
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_incremental_contain_large_yes" (b : @bench.T) {
  @dispatch.setup()
  let (tree, items) = create_incremental_containment_tree(50, 5, 4, true)
  let _ = tree.compute_incremental()
  let target = items[items.length() / 2]
  b.bench(name="incr_contain_large_yes", fn() {
    tree.mark_node_dirty(target.uid)
    b.keep(tree.compute_incremental())
  })
}
