// =============================================================================
// gfx Rasterization Benchmarks
// =============================================================================
// Measures the gfx-backed renderer (gfx_bridge assembler -> gfx_software CPU
// rasterizer -> RGBA pixels). The `render_html_to_image` bench is end-to-end;
// the `rasterize` phase benches isolate the paint-tree -> pixels work on a
// pre-built paint tree, which is the part the gfx packages own.

///|
fn gfx_bench_viewport() -> @types.Size[Double] {
  @types.Size::new(800.0, 600.0)
}

///|
fn gfx_bench_paint_tree(html : String) -> @paint_model.PaintNode {
  vrt_render_html_to_paint_tree(html, gfx_bench_viewport())
}

///|
fn gfx_bench_rasterize(tree : @paint_model.PaintNode) -> @gfx_vrt.RenderedImage {
  let viewport = gfx_bench_viewport()
  @gfx_vrt.render_paint_tree_to_image(
    tree,
    viewport.width.to_int(),
    viewport.height.to_int(),
  )
}

///|
test "bench_gfx_render_html_to_image_dashboard" (b : @bench.T) {
  let html = dashboard(16, 24)
  let viewport = gfx_bench_viewport()
  b.bench(name="gfx_render_html_to_image_dashboard", fn() {
    b.keep(@gfx_vrt.render_html_to_image(html, viewport))
  })
}

///|
test "bench_gfx_phase_rasterize_dashboard" (b : @bench.T) {
  let tree = gfx_bench_paint_tree(dashboard(16, 24))
  b.bench(name="gfx_phase_rasterize_dashboard", fn() {
    b.keep(gfx_bench_rasterize(tree))
  })
}

///|
test "bench_gfx_phase_rasterize_grid" (b : @bench.T) {
  let tree = gfx_bench_paint_tree(grid_simple(10, 10))
  b.bench(name="gfx_phase_rasterize_grid", fn() {
    b.keep(gfx_bench_rasterize(tree))
  })
}

///|
test "bench_gfx_phase_rasterize_cards" (b : @bench.T) {
  // Many bordered / rounded card backgrounds: stresses the rounded-corner
  // coverage path in the rasterizer.
  let tree = gfx_bench_paint_tree(dashboard(24, 48))
  b.bench(name="gfx_phase_rasterize_cards", fn() {
    b.keep(gfx_bench_rasterize(tree))
  })
}
