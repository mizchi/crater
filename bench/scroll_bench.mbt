// =============================================================================
// Scroll / Incremental Paint Speed Benchmarks
// =============================================================================
// Measures viewport culling and incremental paint performance

///|
fn scroll_ctx() -> @renderer.RenderContext {
  {
    viewport_width: 1200.0,
    viewport_height: 800.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
}

// =============================================================================
// Viewport Culling Benchmarks
// =============================================================================
// Test how efficiently we can cull nodes outside the viewport

///|
test "bench_viewport_culling_500_top" (b : @bench.T) {
  let html = scrollable_list(500, 64)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  // Scroll position at top (0-800)
  b.bench(name="viewport_cull_top", fn() {
    b.keep(
      @paint.from_node_and_layout_with_viewport(node, layout, 0.0, 800.0, 0.0),
    )
  })
}

///|
test "bench_viewport_culling_500_middle" (b : @bench.T) {
  let html = scrollable_list(500, 64)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  // Scroll position at middle (~16000 pixels down)
  b.bench(name="viewport_cull_mid", fn() {
    b.keep(
      @paint.from_node_and_layout_with_viewport(
        node, layout, 16000.0, 16800.0, 0.0,
      ),
    )
  })
}

///|
test "bench_viewport_culling_500_bottom" (b : @bench.T) {
  let html = scrollable_list(500, 64)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  // Scroll position near bottom (~31200 pixels down)
  b.bench(name="viewport_cull_bot", fn() {
    b.keep(
      @paint.from_node_and_layout_with_viewport(
        node, layout, 31200.0, 32000.0, 0.0,
      ),
    )
  })
}

///|
test "bench_viewport_culling_1000_middle" (b : @bench.T) {
  let html = scrollable_list(1000, 64)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  // Middle of 1000 items
  b.bench(name="viewport_cull_1k", fn() {
    b.keep(
      @paint.from_node_and_layout_with_viewport(
        node, layout, 32000.0, 32800.0, 0.0,
      ),
    )
  })
}

// =============================================================================
// Paint Tree Construction Benchmarks
// =============================================================================

///|
test "bench_paint_tree_flat_100" (b : @bench.T) {
  let html = simple_flat(100)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  b.bench(name="paint_tree_flat", fn() {
    b.keep(@paint.from_node_and_layout(node, layout))
  })
}

///|
test "bench_paint_tree_dashboard" (b : @bench.T) {
  let html = dashboard(15, 12)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  b.bench(name="paint_tree_dash", fn() {
    b.keep(@paint.from_node_and_layout(node, layout))
  })
}

///|
test "bench_paint_tree_large_2k5" (b : @bench.T) {
  let html = large_website(15, 10, 8)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  b.bench(name="paint_tree_large", fn() {
    b.keep(@paint.from_node_and_layout(node, layout))
  })
}

// =============================================================================
// Flatten for Rendering Benchmarks
// =============================================================================

///|
test "bench_flatten_flat_100" (b : @bench.T) {
  let html = simple_flat(100)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  let paint_node = @paint.from_node_and_layout(node, layout)
  b.bench(name="flatten_flat_100", fn() {
    b.keep(@paint.flatten_for_rendering(paint_node))
  })
}

///|
test "bench_flatten_dashboard" (b : @bench.T) {
  let html = dashboard(15, 12)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  let paint_node = @paint.from_node_and_layout(node, layout)
  b.bench(name="flatten_dash", fn() {
    b.keep(@paint.flatten_for_rendering(paint_node))
  })
}

///|
test "bench_flatten_large_2k5" (b : @bench.T) {
  let html = large_website(15, 10, 8)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  let paint_node = @paint.from_node_and_layout(node, layout)
  b.bench(name="flatten_large", fn() {
    b.keep(@paint.flatten_for_rendering(paint_node))
  })
}

// =============================================================================
// Scroll Simulation Benchmarks
// =============================================================================
// Simulates a user scrolling down the page incrementally

///|
test "bench_scroll_simulation_10_steps" (b : @bench.T) {
  let html = scrollable_list(500, 64)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  let viewport_height = 800.0
  let total_height = 500.0 * 64.0 // 32000
  let step = (total_height - viewport_height) / 10.0
  b.bench(name="scroll_10_steps", fn() {
    // Simulate 10 scroll positions
    for i = 0; i < 10; i = i + 1 {
      let scroll_y = step * i.to_double()
      b.keep(
        @paint.from_node_and_layout_with_viewport(
          node,
          layout,
          scroll_y,
          scroll_y + viewport_height,
          0.0,
        ),
      )
    }
  })
}

///|
test "bench_scroll_simulation_100_steps" (b : @bench.T) {
  let html = scrollable_list(500, 64)
  let ctx = scroll_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(node, layout_ctx)
  let viewport_height = 800.0
  let total_height = 500.0 * 64.0 // 32000
  let step = (total_height - viewport_height) / 100.0
  b.bench(name="scroll_100_steps", fn() {
    // Simulate 100 scroll positions
    for i = 0; i < 100; i = i + 1 {
      let scroll_y = step * i.to_double()
      b.keep(
        @paint.from_node_and_layout_with_viewport(
          node,
          layout,
          scroll_y,
          scroll_y + viewport_height,
          0.0,
        ),
      )
    }
  })
}

// =============================================================================
// Incremental Layout Benchmarks (using tree module)
// =============================================================================

///|
test "bench_incremental_layout_unchanged" (b : @bench.T) {
  @dispatch.setup()
  let root = create_benchmark_tree(4, 4) // 341 nodes
  let tree = @tree.LayoutTree::new(root, 1200.0, 800.0)
  // First compute to populate cache
  let _ = tree.compute_incremental()
  // Benchmark unchanged recompute (should use cache)
  b.bench(name="incr_layout_cached", fn() { b.keep(tree.compute_incremental()) })
}

///|
test "bench_incremental_layout_single_dirty" (b : @bench.T) {
  @dispatch.setup()
  let root = create_benchmark_tree(4, 4) // 341 nodes
  let tree = @tree.LayoutTree::new(root, 1200.0, 800.0)
  // First compute to populate cache
  let _ = tree.compute_incremental()
  // Find a leaf to mark dirty
  let leaf = find_first_leaf(root)
  b.bench(name="incr_layout_dirty", fn() {
    tree.mark_node_dirty(leaf.uid)
    b.keep(tree.compute_incremental())
  })
}

///|
test "bench_incremental_layout_full" (b : @bench.T) {
  @dispatch.setup()
  let root = create_benchmark_tree(4, 4) // 341 nodes
  let tree = @tree.LayoutTree::new(root, 1200.0, 800.0)
  b.bench(name="incr_layout_full", fn() {
    tree.mark_node_dirty(root.uid)
    b.keep(tree.compute_incremental())
  })
}

// =============================================================================
// Helper Functions
// =============================================================================

///|
fn create_benchmark_tree(depth : Int, branching : Int) -> @tree.LayoutNode {
  create_benchmark_subtree("root", depth, branching, 0)
}

///|
fn create_benchmark_subtree(
  prefix : String,
  depth : Int,
  branching : Int,
  level : Int,
) -> @tree.LayoutNode {
  if depth == 0 {
    // Leaf node
    @tree.LayoutNode::leaf(prefix, @style.Style::{
      ..@style.Style::default(),
      width: @types.Length(50.0),
      height: @types.Length(30.0),
    })
  } else {
    // Container node
    let children : Array[@tree.LayoutNode] = []
    for i = 0; i < branching; i = i + 1 {
      let child_prefix = prefix + "_" + i.to_string()
      children.push(
        create_benchmark_subtree(child_prefix, depth - 1, branching, level + 1),
      )
    }
    @tree.LayoutNode::new(
      prefix,
      @style.Style::{
        ..@style.Style::default(),
        display: @style.Flex,
        flex_direction: if level % 2 == 0 {
          @style.Row
        } else {
          @style.Column
        },
        width: @types.Auto,
        height: @types.Auto,
        padding: @types.Rect::{
          top: @types.Length(5.0),
          right: @types.Length(5.0),
          bottom: @types.Length(5.0),
          left: @types.Length(5.0),
        },
      },
      children,
    )
  }
}

///|
fn find_first_leaf(node : @tree.LayoutNode) -> @tree.LayoutNode {
  if node.children.length() == 0 {
    return node
  }
  find_first_leaf(node.children[0])
}
