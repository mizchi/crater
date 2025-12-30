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
  let sidebar = @node.Node::new("sidebar", {
    ..default_style,
    width: @types.Length(200.0),
  }, sidebar_children)

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
    content_children.push(@node.Node::new("section\{i}", section_style, section_items))
  }
  let content = @node.Node::new("content", {
    ..default_style,
    flex_grow: 1.0,
  }, content_children)

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
      flex_direction: if is_row { @style.Row } else { @style.Column },
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
  b.bench(name="nested_block_d5", fn() { b.keep(compute_layout(node, viewport)) })
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
