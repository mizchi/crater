///|
fn vrt_viewport() -> @types.Size[Double] {
  @types.Size::new(1280.0, 900.0)
}

///|
fn vrt_render_context(
  viewport : @types.Size[Double],
) -> @renderer.RenderContext {
  {
    ..@renderer.RenderContext::default(),
    viewport_width: viewport.width,
    viewport_height: viewport.height,
  }
}

///|
fn vrt_render_html_to_paint_tree(
  html : String,
  viewport : @types.Size[Double],
) -> @paint_model.PaintNode {
  let (node, layout) = @renderer.render_to_node_and_layout_with_external_css(
    html,
    vrt_render_context(viewport),
    [],
  )
  build_vrt_paint_tree(node, layout, viewport)
}

///|
fn vrt_render_html_to_paint_tree_json(
  html : String,
  viewport : @types.Size[Double],
) -> String {
  vrt_render_html_to_paint_tree(html, viewport).to_json_string()
}

///|
fn vrt_diff_rendered_paint_trees(
  baseline_html : String,
  current_html : String,
  viewport : @types.Size[Double],
) -> @paint_diff.PaintTreeDiff {
  let baseline = vrt_render_html_to_paint_tree(baseline_html, viewport)
  let current = vrt_render_html_to_paint_tree(current_html, viewport)
  @paint_diff.diff_trees(baseline, current)
}

///|
fn build_vrt_paint_tree(
  node : @tree.Node,
  layout : @types.Layout,
  viewport : @types.Size[Double],
) -> @paint_model.PaintNode {
  match
    @paint_render.from_node_and_layout_with_viewport_rect(
      node,
      layout,
      0.0,
      0.0,
      viewport.width,
      viewport.height,
      0.0,
      0.0,
    ) {
    Some(paint_tree) => paint_tree
    None => @paint_render.from_node_and_layout(node, layout)
  }
}

///|
fn vrt_component_fixture(
  padding_px : Int,
  bg : String,
  accent : String,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "<!DOCTYPE html><html><body style=\"margin:0;background:#f4f6fb;padding:24px\">",
  )
  buf.write_string(
    "<section style=\"width:420px;border:1px solid #d8dee8;border-radius:20px;background:",
  )
  buf.write_string(bg)
  buf.write_string(";padding:")
  buf.write_string(padding_px.to_string())
  buf.write_string("px\">")
  buf.write_string(
    "<p style=\"margin:0 0 10px;color:#5f6b7a;font-size:12px;text-transform:uppercase\">status</p>",
  )
  buf.write_string(
    "<h2 style=\"margin:0 0 12px;font-size:22px;font-weight:700\">Billing Ready</h2>",
  )
  buf.write_string(
    "<p style=\"margin:0 0 18px;font-size:14px;line-height:1.45;color:#17212b\">Invoice automation is active for the current workspace.</p>",
  )
  buf.write_string("<div style=\"display:flex;gap:8px;margin-bottom:18px\">")
  buf.write_string(
    "<span style=\"padding:4px 8px;border-radius:999px;background:#eef2f8\">Auto</span>",
  )
  buf.write_string(
    "<span style=\"padding:4px 8px;border-radius:999px;background:#eef2f8\">USD</span>",
  )
  buf.write_string("</div>")
  buf.write_string(
    "<button style=\"display:block;width:100%;padding:10px 12px;border:0;border-radius:10px;background:",
  )
  buf.write_string(accent)
  buf.write_string(";color:#ffffff\">Open</button>")
  buf.write_string("</section></body></html>")
  buf.to_string()
}

///|
test "bench_vrt_render_paint_tree_dashboard" (b : @bench.T) {
  let html = dashboard(16, 24)
  let viewport = vrt_viewport()
  b.bench(name="vrt_render_paint_tree_dashboard", fn() {
    b.keep(vrt_render_html_to_paint_tree(html, viewport))
  })
}

///|
test "bench_vrt_render_paint_tree_json_component" (b : @bench.T) {
  let html = vrt_component_fixture(20, "#ffffff", "#1463ff")
  let viewport = vrt_viewport()
  b.bench(name="vrt_render_paint_tree_json_component", fn() {
    b.keep(vrt_render_html_to_paint_tree_json(html, viewport))
  })
}

///|
test "bench_vrt_diff_rendered_paint_trees_component" (b : @bench.T) {
  let viewport = vrt_viewport()
  let baseline_html = vrt_component_fixture(20, "#ffffff", "#1463ff")
  let mutated_html = vrt_component_fixture(8, "#eef2f8", "#0f7b3b")
  b.bench(name="vrt_diff_rendered_paint_trees_component", fn() {
    b.keep(vrt_diff_rendered_paint_trees(baseline_html, mutated_html, viewport))
  })
}

///|
test "bench_vrt_phase_parse_dashboard" (b : @bench.T) {
  let html = dashboard(16, 24)
  b.bench(name="vrt_phase_parse_dashboard", fn() {
    b.keep(@html.parse_document(html))
  })
}

///|
test "bench_vrt_phase_node_layout_dashboard" (b : @bench.T) {
  let html = dashboard(16, 24)
  let viewport = vrt_viewport()
  let ctx = vrt_render_context(viewport)
  let doc = @html.parse_document(html)
  b.bench(name="vrt_phase_node_layout_dashboard", fn() {
    b.keep(@renderer.render_to_node_and_layout_with_document(doc, ctx, []))
  })
}

///|
test "bench_vrt_phase_paint_tree_dashboard" (b : @bench.T) {
  let html = dashboard(16, 24)
  let viewport = vrt_viewport()
  let ctx = vrt_render_context(viewport)
  let (node, layout) = @renderer.render_to_node_and_layout(html, ctx)
  b.bench(name="vrt_phase_paint_tree_dashboard", fn() {
    b.keep(build_vrt_paint_tree(node, layout, viewport))
  })
}

///|
test "bench_vrt_phase_paint_tree_json_component" (b : @bench.T) {
  let viewport = vrt_viewport()
  let ctx = vrt_render_context(viewport)
  let html = vrt_component_fixture(20, "#ffffff", "#1463ff")
  let (node, layout) = @renderer.render_to_node_and_layout(html, ctx)
  let paint_tree = build_vrt_paint_tree(node, layout, viewport)
  b.bench(name="vrt_phase_paint_tree_json_component", fn() {
    b.keep(paint_tree.to_json_string())
  })
}

///|
test "bench_vrt_phase_diff_component" (b : @bench.T) {
  let viewport = vrt_viewport()
  let baseline = vrt_render_html_to_paint_tree(
    vrt_component_fixture(20, "#ffffff", "#1463ff"),
    viewport,
  )
  let mutated = vrt_render_html_to_paint_tree(
    vrt_component_fixture(8, "#eef2f8", "#0f7b3b"),
    viewport,
  )
  b.bench(name="vrt_phase_diff_component", fn() {
    b.keep(@paint_diff.diff_trees(baseline, mutated))
  })
}

///|
fn capture_screenshot_fixture() -> String {
  dashboard(12, 16)
}

///|
fn capture_screenshot_viewport() -> @types.Size[Double] {
  @types.Size::new(960.0, 640.0)
}

///|
fn capture_screenshot_node_layout(
  html : String,
  viewport : @types.Size[Double],
) -> (@tree.Node, @types.Layout) {
  @renderer.render_to_node_and_layout_with_external_css(
    html,
    vrt_render_context(viewport),
    [],
  )
}

///|
fn capture_screenshot_paint_tree(
  html : String,
  viewport : @types.Size[Double],
) -> @paint_model.PaintNode {
  let (node, layout) = capture_screenshot_node_layout(html, viewport)
  build_vrt_paint_tree(node, layout, viewport)
}

///|
test "capture screenshot dashboard visual sanity is non-blank" {
  let viewport = capture_screenshot_viewport()
  let paint_tree = capture_screenshot_paint_tree(
    capture_screenshot_fixture(),
    viewport,
  )
  let (fb, palette) = @tui_paint_output.raster_to_framebuffer(
    paint_tree,
    viewport.width.to_int(),
    viewport.height.to_int(),
  )
  let stats = @tui_paint_output.framebuffer_visual_stats(fb, palette)
  assert_false(stats.is_blank)
  assert_true(stats.non_white_pixels > 0)
}

///|
test "bench_capture_screenshot_phase_paint_tree_dashboard" (b : @bench.T) {
  let html = capture_screenshot_fixture()
  let viewport = capture_screenshot_viewport()
  let (node, layout) = capture_screenshot_node_layout(html, viewport)
  b.bench(name="capture_screenshot_phase_paint_tree_dashboard", fn() {
    b.keep(build_vrt_paint_tree(node, layout, viewport))
  })
}

///|
test "bench_capture_screenshot_phase_raster_dashboard" (b : @bench.T) {
  let viewport = capture_screenshot_viewport()
  let paint_tree = capture_screenshot_paint_tree(
    capture_screenshot_fixture(),
    viewport,
  )
  b.bench(name="capture_screenshot_phase_raster_dashboard", fn() {
    b.keep(
      @tui_paint_output.raster_to_framebuffer(
        paint_tree,
        viewport.width.to_int(),
        viewport.height.to_int(),
      ),
    )
  })
}

///|
test "bench_capture_screenshot_phase_png_encode_dashboard" (b : @bench.T) {
  let viewport = capture_screenshot_viewport()
  let paint_tree = capture_screenshot_paint_tree(
    capture_screenshot_fixture(),
    viewport,
  )
  let (fb, palette) = @tui_paint_output.raster_to_framebuffer(
    paint_tree,
    viewport.width.to_int(),
    viewport.height.to_int(),
  )
  b.bench(name="capture_screenshot_phase_png_encode_dashboard", fn() {
    b.keep(@tui_paint_png.framebuffer_to_png_base64(fb, palette))
  })
}

///|
test "bench_capture_screenshot_phase_visual_sanity_dashboard" (b : @bench.T) {
  let viewport = capture_screenshot_viewport()
  let paint_tree = capture_screenshot_paint_tree(
    capture_screenshot_fixture(),
    viewport,
  )
  let (fb, palette) = @tui_paint_output.raster_to_framebuffer(
    paint_tree,
    viewport.width.to_int(),
    viewport.height.to_int(),
  )
  b.bench(name="capture_screenshot_phase_visual_sanity_dashboard", fn() {
    b.keep(@tui_paint_output.framebuffer_visual_stats(fb, palette))
  })
}
