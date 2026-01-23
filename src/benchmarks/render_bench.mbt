// =============================================================================
// Rendering Speed Benchmarks
// =============================================================================
// Measures full rendering pipeline: parse -> style -> layout

///|
fn default_ctx() -> @renderer.RenderContext {
  {
    viewport_width: 1200.0,
    viewport_height: 800.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
}

// =============================================================================
// Simple Pattern Render Benchmarks
// =============================================================================

///|
test "bench_render_flat_100" (b : @bench.T) {
  let html = simple_flat(100)
  let ctx = default_ctx()
  b.bench(name="render_flat_100", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_flat_500" (b : @bench.T) {
  let html = simple_flat(500)
  let ctx = default_ctx()
  b.bench(name="render_flat_500", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_flat_1000" (b : @bench.T) {
  let html = simple_flat(1000)
  let ctx = default_ctx()
  b.bench(name="render_flat_1000", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_nested_20" (b : @bench.T) {
  let html = nested_depth(20)
  let ctx = default_ctx()
  b.bench(name="render_nest_20", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_nested_50" (b : @bench.T) {
  let html = nested_depth(50)
  let ctx = default_ctx()
  b.bench(name="render_nest_50", fn() { b.keep(@renderer.render(html, ctx)) })
}

// =============================================================================
// Flexbox Render Benchmarks
// =============================================================================

///|
test "bench_render_flex_row_50" (b : @bench.T) {
  let html = flex_row(50)
  let ctx = default_ctx()
  b.bench(name="render_flex_row_50", fn() {
    b.keep(@renderer.render(html, ctx))
  })
}

///|
test "bench_render_flex_column_100" (b : @bench.T) {
  let html = flex_column(100)
  let ctx = default_ctx()
  b.bench(name="render_flex_col_100", fn() {
    b.keep(@renderer.render(html, ctx))
  })
}

///|
test "bench_render_flex_wrap_100" (b : @bench.T) {
  let html = flex_wrap(100, 150)
  let ctx = default_ctx()
  b.bench(name="render_flex_wrap", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_flex_nested_d4" (b : @bench.T) {
  let html = flex_nested(4, 3)
  let ctx = default_ctx()
  b.bench(name="render_flex_d4", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_flex_nested_d5" (b : @bench.T) {
  let html = flex_nested(5, 3)
  let ctx = default_ctx()
  b.bench(name="render_flex_d5", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_flex_nested_d6" (b : @bench.T) {
  let html = flex_nested(6, 3)
  let ctx = default_ctx()
  b.bench(name="render_flex_d6", fn() { b.keep(@renderer.render(html, ctx)) })
}

// =============================================================================
// Grid Render Benchmarks
// =============================================================================

///|
test "bench_render_grid_5x5" (b : @bench.T) {
  let html = grid_simple(5, 5)
  let ctx = default_ctx()
  b.bench(name="render_grid_5x5", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_grid_10x10" (b : @bench.T) {
  let html = grid_simple(10, 10)
  let ctx = default_ctx()
  b.bench(name="render_grid_10x10", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_grid_20x5" (b : @bench.T) {
  let html = grid_simple(20, 5)
  let ctx = default_ctx()
  b.bench(name="render_grid_20x5", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_grid_explicit" (b : @bench.T) {
  let html = grid_explicit(10, 6, 50)
  let ctx = default_ctx()
  b.bench(name="render_grid_exp", fn() { b.keep(@renderer.render(html, ctx)) })
}

// =============================================================================
// Complex Pattern Render Benchmarks
// =============================================================================

///|
test "bench_render_card_grid_12" (b : @bench.T) {
  let html = card_grid(12)
  let ctx = default_ctx()
  b.bench(name="render_cards_12", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_card_grid_24" (b : @bench.T) {
  let html = card_grid(24)
  let ctx = default_ctx()
  b.bench(name="render_cards_24", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_card_grid_48" (b : @bench.T) {
  let html = card_grid(48)
  let ctx = default_ctx()
  b.bench(name="render_cards_48", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_dashboard_small" (b : @bench.T) {
  let html = dashboard(10, 6)
  let ctx = default_ctx()
  b.bench(name="render_dash_small", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_dashboard_medium" (b : @bench.T) {
  let html = dashboard(15, 12)
  let ctx = default_ctx()
  b.bench(name="render_dash_med", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_chat_50" (b : @bench.T) {
  let html = chat_messages(50)
  let ctx = default_ctx()
  b.bench(name="render_chat_50", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_chat_100" (b : @bench.T) {
  let html = chat_messages(100)
  let ctx = default_ctx()
  b.bench(name="render_chat_100", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_table_30x6" (b : @bench.T) {
  let html = table_layout(30, 6)
  let ctx = default_ctx()
  b.bench(name="render_table_30x6", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_table_50x8" (b : @bench.T) {
  let html = table_layout(50, 8)
  let ctx = default_ctx()
  b.bench(name="render_table_50x8", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_form_10" (b : @bench.T) {
  let html = form_fields(10)
  let ctx = default_ctx()
  b.bench(name="render_form_10", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_form_20" (b : @bench.T) {
  let html = form_fields(20)
  let ctx = default_ctx()
  b.bench(name="render_form_20", fn() { b.keep(@renderer.render(html, ctx)) })
}

// =============================================================================
// Large Scale Render Benchmarks
// =============================================================================

///|
test "bench_render_large_1k" (b : @bench.T) {
  let html = large_website(10, 5, 4)
  let ctx = default_ctx()
  b.bench(name="render_large_1k", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_large_2k5" (b : @bench.T) {
  let html = large_website(15, 10, 8)
  let ctx = default_ctx()
  b.bench(name="render_large_2k5", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_large_5k" (b : @bench.T) {
  let html = large_website(20, 20, 10)
  let ctx = default_ctx()
  b.bench(name="render_large_5k", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_scrollable_200" (b : @bench.T) {
  let html = scrollable_list(200, 64)
  let ctx = default_ctx()
  b.bench(name="render_scroll_200", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_scrollable_500" (b : @bench.T) {
  let html = scrollable_list(500, 64)
  let ctx = default_ctx()
  b.bench(name="render_scroll_500", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_scrollable_1000" (b : @bench.T) {
  let html = scrollable_list(1000, 64)
  let ctx = default_ctx()
  b.bench(name="render_scroll_1k", fn() { b.keep(@renderer.render(html, ctx)) })
}

// =============================================================================
// Layout-Only Benchmarks (using render_to_node + dispatch)
// =============================================================================

///|
test "bench_layout_only_flex_d5" (b : @bench.T) {
  let html = flex_nested(5, 3)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @types.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @types.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  b.bench(name="layout_only_flex_d5", fn() {
    b.keep(@dispatch.compute_layout(node, layout_ctx))
  })
}

///|
test "bench_layout_only_grid_10x10" (b : @bench.T) {
  let html = grid_simple(10, 10)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @types.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @types.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  b.bench(name="layout_only_grid", fn() {
    b.keep(@dispatch.compute_layout(node, layout_ctx))
  })
}

///|
test "bench_layout_only_dashboard" (b : @bench.T) {
  let html = dashboard(15, 12)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @types.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @types.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  b.bench(name="layout_only_dash", fn() {
    b.keep(@dispatch.compute_layout(node, layout_ctx))
  })
}

///|
test "bench_layout_only_large_2k5" (b : @bench.T) {
  let html = large_website(15, 10, 8)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @types.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @types.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  b.bench(name="layout_only_large", fn() {
    b.keep(@dispatch.compute_layout(node, layout_ctx))
  })
}
