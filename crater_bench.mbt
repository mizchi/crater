// =============================================================================
// Layout Engine Benchmarks
// =============================================================================

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
  b.bench(name="nested_percent", fn() {
    b.keep(compute_layout(node, viewport))
  })
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
      grid_children.push(@node.Node::new("cell\{i}_\{j}", default_style, cell_children))
    }
    let grid_style = {
      ..default_style,
      display: @style.Grid,
      flex_grow: 1.0,
      grid_template_columns: [
        @style.Fr(1.0),
        @style.Fr(1.0),
        @style.Fr(1.0),
      ],
      grid_template_rows: [
        @style.Fr(1.0),
        @style.Fr(1.0),
        @style.Fr(1.0),
      ],
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
      @node.Node::new("card\{i}", {
        ..default_style,
        padding: {
          left: @types.Length(16.0),
          right: @types.Length(16.0),
          top: @types.Length(16.0),
          bottom: @types.Length(16.0),
        },
      }, card_content),
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
      {
        ..default_style,
        display: @style.Flex,
        flex_direction: @style.Row,
      },
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
      @node.Node::new("field\{i}", {
        ..default_style,
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(0.0),
          bottom: @types.Length(16.0),
        },
      }, field_children),
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
          display: display,
          grid_template_columns: [@style.Fr(1.0), @style.Fr(1.0), @style.Fr(1.0)],
        },
        children,
      )
    }
    @node.Node::new(
      "node_d\{d}",
      {
        ..default_style,
        display: display,
        flex_direction: if d % 2 == 0 { @style.Row } else { @style.Column },
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
        flex_direction: if d % 2 == 0 { @style.Row } else { @style.Column },
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
        flex_direction: if d % 2 == 0 { @style.Row } else { @style.Column },
        // Fixed size to skip intrinsic calculation
        width: @types.Length(100.0 * d.to_double()),
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
  b.bench(name="deep_flex_fixed_d6", fn() { b.keep(compute_layout(node, viewport)) })
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
        flex_direction: if d % 2 == 0 { @style.Row } else { @style.Column },
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
  b.bench(name="grid_auto_nested_d3", fn() { b.keep(compute_layout(node, viewport)) })
}

///|
test "bench_grid_auto_nested_d4" (b : @bench.T) {
  let node = create_grid_auto_nested_flex(4)
  let viewport = @types.Size::new(800.0, 600.0)
  b.bench(name="grid_auto_nested_d4", fn() { b.keep(compute_layout(node, viewport)) })
}
