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
    color_scheme: @css.ColorScheme::Light,
  }
}

///|
fn default_layout_ctx(ctx : @renderer.RenderContext) -> @types.LayoutContext {
  {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @types.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }
}

///|
fn large_2k5_node_build_bench_html() -> String {
  large_website(15, 10, 8)
}

///|
fn large_2k5_node_build_bench_doc() -> @html.Document {
  @html.parse_document(large_2k5_node_build_bench_html())
}

///|
fn large_2k5_node_build_bench_ctx() -> @renderer.RenderContext {
  default_ctx()
}

///|
fn large_2k5_node_build_bench_external_css() -> Array[String] {
  []
}

///|
fn large_website_simple_cards(
  sidebar_items : Int,
  sections : Int,
  cards_per_section : Int,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  buf.write_string("<div style=\"display:flex;min-height:100vh\">")
  buf.write_string(
    "<div style=\"width:240px;background:#1a1a2e;flex-shrink:0;padding:16px\">",
  )
  buf.write_string(
    "<div style=\"height:40px;background:#e94560;margin-bottom:24px;border-radius:4px\"></div>",
  )
  for i = 0; i < sidebar_items; i = i + 1 {
    buf.write_string(
      "<div style=\"height:36px;margin-bottom:8px;display:flex;align-items:center;padding:0 12px;border-radius:4px;background:",
    )
    buf.write_string(if i == 0 { "#e94560" } else { "#16213e" })
    buf.write_string("\">")
    buf.write_string(
      "<div style=\"width:16px;height:16px;background:#0f3460;margin-right:12px\"></div>",
    )
    buf.write_string("<div style=\"flex:1;height:12px;background:#eee\"></div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.write_string("<div style=\"flex:1;background:#f0f0f0\">")
  buf.write_string(
    "<div style=\"height:64px;background:#fff;border-bottom:1px solid #ddd;display:flex;align-items:center;padding:0 24px\">",
  )
  buf.write_string(
    "<div style=\"flex:1;height:36px;background:#ecf0f1;border-radius:4px\"></div>",
  )
  buf.write_string("</div>")
  buf.write_string("<div style=\"padding:24px\">")
  for _s = 0; _s < sections; _s = _s + 1 {
    buf.write_string("<div style=\"margin-bottom:32px\">")
    buf.write_string(
      "<div style=\"display:flex;justify-content:space-between;margin-bottom:16px\">",
    )
    buf.write_string(
      "<div style=\"width:200px;height:28px;background:#2c3e50;border-radius:4px\"></div>",
    )
    buf.write_string(
      "<div style=\"width:80px;height:28px;background:#3498db;border-radius:4px\"></div>",
    )
    buf.write_string("</div>")
    buf.write_string(
      "<div style=\"display:grid;grid-template-columns:repeat(4,1fr);gap:16px\">",
    )
    for _c = 0; _c < cards_per_section; _c = _c + 1 {
      buf.write_string(
        "<div style=\"height:238px;background:#fff;border-radius:8px\"></div>",
      )
    }
    buf.write_string("</div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.write_string("</div>")
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
fn large_website_card_bodies(
  sidebar_items : Int,
  sections : Int,
  cards_per_section : Int,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  buf.write_string("<div style=\"display:flex;min-height:100vh\">")
  buf.write_string(
    "<div style=\"width:240px;background:#1a1a2e;flex-shrink:0;padding:16px\">",
  )
  buf.write_string(
    "<div style=\"height:40px;background:#e94560;margin-bottom:24px;border-radius:4px\"></div>",
  )
  for i = 0; i < sidebar_items; i = i + 1 {
    buf.write_string(
      "<div style=\"height:36px;margin-bottom:8px;display:flex;align-items:center;padding:0 12px;border-radius:4px;background:",
    )
    buf.write_string(if i == 0 { "#e94560" } else { "#16213e" })
    buf.write_string("\">")
    buf.write_string(
      "<div style=\"width:16px;height:16px;background:#0f3460;margin-right:12px\"></div>",
    )
    buf.write_string("<div style=\"flex:1;height:12px;background:#eee\"></div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.write_string("<div style=\"flex:1;background:#f0f0f0\">")
  buf.write_string(
    "<div style=\"height:64px;background:#fff;border-bottom:1px solid #ddd;display:flex;align-items:center;padding:0 24px\">",
  )
  buf.write_string(
    "<div style=\"flex:1;height:36px;background:#ecf0f1;border-radius:4px\"></div>",
  )
  buf.write_string("</div>")
  buf.write_string("<div style=\"padding:24px\">")
  for _s = 0; _s < sections; _s = _s + 1 {
    buf.write_string("<div style=\"margin-bottom:32px\">")
    buf.write_string(
      "<div style=\"display:flex;justify-content:space-between;margin-bottom:16px\">",
    )
    buf.write_string(
      "<div style=\"width:200px;height:28px;background:#2c3e50;border-radius:4px\"></div>",
    )
    buf.write_string(
      "<div style=\"width:80px;height:28px;background:#3498db;border-radius:4px\"></div>",
    )
    buf.write_string("</div>")
    buf.write_string(
      "<div style=\"display:grid;grid-template-columns:repeat(4,1fr);gap:16px\">",
    )
    for _c = 0; _c < cards_per_section; _c = _c + 1 {
      buf.write_string("<div style=\"background:#fff;border-radius:8px\">")
      buf.write_string("<div style=\"padding:12px\">")
      buf.write_string(
        "<div style=\"height:16px;background:#2c3e50;margin-bottom:8px;width:80%\"></div>",
      )
      buf.write_string(
        "<div style=\"height:32px;background:#ecf0f1;margin-bottom:8px\"></div>",
      )
      buf.write_string(
        "<div style=\"display:flex;justify-content:space-between\">",
      )
      buf.write_string(
        "<div style=\"width:50px;height:14px;background:#e74c3c\"></div>",
      )
      buf.write_string(
        "<div style=\"width:30px;height:14px;background:#27ae60\"></div>",
      )
      buf.write_string("</div>")
      buf.write_string("</div>")
      buf.write_string("</div>")
    }
    buf.write_string("</div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.write_string("</div>")
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
fn large_website_card_text_bodies(
  sidebar_items : Int,
  sections : Int,
  cards_per_section : Int,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  buf.write_string("<div style=\"display:flex;min-height:100vh\">")
  buf.write_string(
    "<div style=\"width:240px;background:#1a1a2e;flex-shrink:0;padding:16px\">",
  )
  buf.write_string(
    "<div style=\"height:40px;background:#e94560;margin-bottom:24px;border-radius:4px\"></div>",
  )
  for i = 0; i < sidebar_items; i = i + 1 {
    buf.write_string(
      "<div style=\"height:36px;margin-bottom:8px;display:flex;align-items:center;padding:0 12px;border-radius:4px;background:",
    )
    buf.write_string(if i == 0 { "#e94560" } else { "#16213e" })
    buf.write_string("\">")
    buf.write_string(
      "<div style=\"width:16px;height:16px;background:#0f3460;margin-right:12px\"></div>",
    )
    buf.write_string("<div style=\"flex:1;height:12px;background:#eee\"></div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.write_string("<div style=\"flex:1;background:#f0f0f0\">")
  buf.write_string(
    "<div style=\"height:64px;background:#fff;border-bottom:1px solid #ddd;display:flex;align-items:center;padding:0 24px\">",
  )
  buf.write_string(
    "<div style=\"flex:1;height:36px;background:#ecf0f1;border-radius:4px\"></div>",
  )
  buf.write_string("</div>")
  buf.write_string("<div style=\"padding:24px\">")
  for _s = 0; _s < sections; _s = _s + 1 {
    buf.write_string("<div style=\"margin-bottom:32px\">")
    buf.write_string(
      "<div style=\"display:flex;justify-content:space-between;margin-bottom:16px\">",
    )
    buf.write_string(
      "<div style=\"width:200px;height:28px;background:#2c3e50;border-radius:4px\"></div>",
    )
    buf.write_string(
      "<div style=\"width:80px;height:28px;background:#3498db;border-radius:4px\"></div>",
    )
    buf.write_string("</div>")
    buf.write_string(
      "<div style=\"display:grid;grid-template-columns:repeat(4,1fr);gap:16px\">",
    )
    for _c = 0; _c < cards_per_section; _c = _c + 1 {
      buf.write_string("<div style=\"background:#fff;border-radius:8px\">")
      buf.write_string("<div style=\"padding:12px\">")
      buf.write_string(
        "<div style=\"height:16px;background:#2c3e50;margin-bottom:8px;width:80%\"></div>",
      )
      buf.write_string(
        "<div style=\"height:32px;background:#ecf0f1;margin-bottom:8px\"></div>",
      )
      buf.write_string("</div>")
      buf.write_string("</div>")
    }
    buf.write_string("</div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.write_string("</div>")
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
fn large_website_card_footer_bodies(
  sidebar_items : Int,
  sections : Int,
  cards_per_section : Int,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body style=\"margin:0\">")
  buf.write_string("<div style=\"display:flex;min-height:100vh\">")
  buf.write_string(
    "<div style=\"width:240px;background:#1a1a2e;flex-shrink:0;padding:16px\">",
  )
  buf.write_string(
    "<div style=\"height:40px;background:#e94560;margin-bottom:24px;border-radius:4px\"></div>",
  )
  for i = 0; i < sidebar_items; i = i + 1 {
    buf.write_string(
      "<div style=\"height:36px;margin-bottom:8px;display:flex;align-items:center;padding:0 12px;border-radius:4px;background:",
    )
    buf.write_string(if i == 0 { "#e94560" } else { "#16213e" })
    buf.write_string("\">")
    buf.write_string(
      "<div style=\"width:16px;height:16px;background:#0f3460;margin-right:12px\"></div>",
    )
    buf.write_string("<div style=\"flex:1;height:12px;background:#eee\"></div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.write_string("<div style=\"flex:1;background:#f0f0f0\">")
  buf.write_string(
    "<div style=\"height:64px;background:#fff;border-bottom:1px solid #ddd;display:flex;align-items:center;padding:0 24px\">",
  )
  buf.write_string(
    "<div style=\"flex:1;height:36px;background:#ecf0f1;border-radius:4px\"></div>",
  )
  buf.write_string("</div>")
  buf.write_string("<div style=\"padding:24px\">")
  for _s = 0; _s < sections; _s = _s + 1 {
    buf.write_string("<div style=\"margin-bottom:32px\">")
    buf.write_string(
      "<div style=\"display:flex;justify-content:space-between;margin-bottom:16px\">",
    )
    buf.write_string(
      "<div style=\"width:200px;height:28px;background:#2c3e50;border-radius:4px\"></div>",
    )
    buf.write_string(
      "<div style=\"width:80px;height:28px;background:#3498db;border-radius:4px\"></div>",
    )
    buf.write_string("</div>")
    buf.write_string(
      "<div style=\"display:grid;grid-template-columns:repeat(4,1fr);gap:16px\">",
    )
    for _c = 0; _c < cards_per_section; _c = _c + 1 {
      buf.write_string("<div style=\"background:#fff;border-radius:8px\">")
      buf.write_string("<div style=\"padding:12px\">")
      buf.write_string(
        "<div style=\"display:flex;justify-content:space-between\">",
      )
      buf.write_string(
        "<div style=\"width:50px;height:14px;background:#e74c3c\"></div>",
      )
      buf.write_string(
        "<div style=\"width:30px;height:14px;background:#27ae60\"></div>",
      )
      buf.write_string("</div>")
      buf.write_string("</div>")
      buf.write_string("</div>")
    }
    buf.write_string("</div>")
    buf.write_string("</div>")
  }
  buf.write_string("</div>")
  buf.write_string("</div>")
  buf.write_string("</div></body></html>")
  buf.to_string()
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
test "bench_render_to_node_large_2k5" (b : @bench.T) {
  let html = large_website(15, 10, 8)
  let ctx = default_ctx()
  b.bench(name="node_only_large_2k5", fn() {
    b.keep(@renderer.render_to_node(html, ctx))
  })
}

///|
test "bench_node_build_large_2k5" (b : @bench.T) {
  let doc = large_2k5_node_build_bench_doc()
  let ctx = large_2k5_node_build_bench_ctx()
  let external_css = large_2k5_node_build_bench_external_css()
  b.bench(name="node_build_large_2k5", fn() {
    b.keep(@renderer.render_to_node_with_document(doc, ctx, external_css))
  })
}

///|
test "bench_node_build_large_2k5_style_compute" (b : @bench.T) {
  let doc = large_2k5_node_build_bench_doc()
  let ctx = large_2k5_node_build_bench_ctx()
  let external_css = large_2k5_node_build_bench_external_css()
  b.bench(name="node_build_large_2k5_style_compute", fn() {
    b.keep(@renderer.prepare_render_document(doc, ctx, external_css))
  })
}

///|
test "bench_node_build_large_2k5_node_assembly" (b : @bench.T) {
  let doc = large_2k5_node_build_bench_doc()
  let ctx = large_2k5_node_build_bench_ctx()
  let external_css = large_2k5_node_build_bench_external_css()
  let prepared = @renderer.prepare_render_document(doc, ctx, external_css)
  b.bench(name="node_build_large_2k5_node_assembly", fn() {
    b.keep(@renderer.build_render_root_node(doc, ctx, prepared))
  })
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
  @tree.setup()
  b.bench(name="layout_only_flex_d5", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
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
  @tree.setup()
  b.bench(name="layout_only_grid", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
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
  @tree.setup()
  b.bench(name="layout_only_dash", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
  })
}

///|
test "bench_layout_only_large_2k5" (b : @bench.T) {
  let html = large_website(15, 10, 8)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx = default_layout_ctx(ctx)
  @tree.setup()
  b.bench(name="layout_only_large", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
  })
}

///|
test "bench_layout_only_large_shell" (b : @bench.T) {
  let html = large_website(15, 0, 0)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx = default_layout_ctx(ctx)
  @tree.setup()
  b.bench(name="layout_only_large_shell", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
  })
}

///|
test "bench_layout_only_large_headers" (b : @bench.T) {
  let html = large_website(15, 10, 0)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx = default_layout_ctx(ctx)
  @tree.setup()
  b.bench(name="layout_only_large_headers", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
  })
}

///|
test "bench_layout_only_large_simple_cards" (b : @bench.T) {
  let html = large_website_simple_cards(15, 10, 8)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx = default_layout_ctx(ctx)
  @tree.setup()
  b.bench(name="layout_only_large_simple_cards", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
  })
}

///|
test "bench_layout_only_large_card_body" (b : @bench.T) {
  let html = large_website_card_bodies(15, 10, 8)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx = default_layout_ctx(ctx)
  @tree.setup()
  b.bench(name="layout_only_large_card_body", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
  })
}

///|
test "bench_layout_only_large_card_text_body" (b : @bench.T) {
  let html = large_website_card_text_bodies(15, 10, 8)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx = default_layout_ctx(ctx)
  @tree.setup()
  b.bench(name="layout_only_large_card_text_body", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
  })
}

///|
test "bench_layout_only_large_card_footer_body" (b : @bench.T) {
  let html = large_website_card_footer_bodies(15, 10, 8)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx = default_layout_ctx(ctx)
  @tree.setup()
  b.bench(name="layout_only_large_card_footer_body", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
  })
}

///|
test "bench_layout_only_scrollable_500" (b : @bench.T) {
  let html = scrollable_list(500, 64)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx = default_layout_ctx(ctx)
  @tree.setup()
  b.bench(name="layout_only_scroll_500", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
  })
}

///|
test "bench_layout_only_scrollable_1000" (b : @bench.T) {
  let html = scrollable_list(1000, 64)
  let ctx = default_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx = default_layout_ctx(ctx)
  @tree.setup()
  b.bench(name="layout_only_scroll_1k", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
  })
}
