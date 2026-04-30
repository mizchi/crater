// =============================================================================
// Paint Output Benchmarks
// =============================================================================
// Measures the output side of rendering after node/layout have been prepared.

///|
fn set_square_glyph_provider_for_bench(advance_ratio : Double) -> Unit {
  @image.set_glyph_provider({
    get_glyph: fn(_codepoint, font_size, _is_bold) {
      let advance = font_size * advance_ratio
      let commands : Array[@svg.PathCommand] = [
        MoveTo(0.0, -font_size),
        LineTo(advance, -font_size),
        LineTo(advance, 0.0),
        LineTo(0.0, 0.0),
        ClosePath,
      ]
      (commands, advance)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    ascent_ratio: 1.0,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_ascent_for_family: None,
  })
}

///|
fn glyph_wrapped_text_paint_node() -> @paint_model.PaintNode {
  let root_style = @style.Style::default()
  root_style.background_color = @types.Color::white()
  let text_style = @style.Style::default()
  text_style.color = @types.Color::rgb(20, 24, 32)
  text_style.font_size = 14.0
  text_style.line_height = 18.0
  let text = "Invoice automation is active for the current workspace and this paragraph should wrap across several lines without recomputing the whole layout tree."
  let text_node = @paint_model.PaintNode::new(
    "#text",
    "#text",
    12.0,
    12.0,
    300.0,
    96.0,
    @paint_model.PaintProperties::from_style(text_style),
    [],
    text=Some(text),
  )
  @paint_model.PaintNode::new(
    "glyph-bench",
    "div",
    0.0,
    0.0,
    340.0,
    128.0,
    @paint_model.PaintProperties::from_style(root_style),
    [text_node],
  )
}

///|
fn scrollable_500_node_and_layout() -> (@tree.Node, @types.Layout) {
  let html = scrollable_list(500, 64)
  let ctx = default_ctx()
  @renderer.render_to_node_and_layout(html, ctx)
}

///|
fn scrollable_500_paint_node() -> @paint_model.PaintNode {
  let (node, layout) = scrollable_500_node_and_layout()
  @paint_render.from_node_and_layout(node, layout)
}

///|
test "bench_paint_bridge_scrollable_500" (b : @bench.T) {
  let (node, layout) = scrollable_500_node_and_layout()
  b.bench(name="paint_bridge_scroll_500", fn() {
    b.keep(@paint_render.from_node_and_layout(node, layout))
  })
}

///|
test "bench_framebuffer_output_scrollable_500_mid" (b : @bench.T) {
  let paint_node = scrollable_500_paint_node()
  b.bench(name="framebuffer_output_scroll_500_mid", fn() {
    let fb = @image.Framebuffer::new(640, 480)
    let palette = @image.DynamicPalette::new()
    @image.render_paint_node_to_framebuffer_scrolled(
      paint_node, fb, palette, 16000,
    )
    b.keep(fb)
  })
}

///|
test "bench_sixel_encode_scrollable_500_mid" (b : @bench.T) {
  let paint_node = scrollable_500_paint_node()
  let fb = @image.Framebuffer::new(640, 480)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer_scrolled(
    paint_node, fb, palette, 16000,
  )
  b.bench(name="sixel_encode_scroll_500_mid", fn() {
    b.keep(@image.to_sixel_dynamic(fb, palette))
  })
}

///|
test "bench_sixel_output_scrollable_500_top" (b : @bench.T) {
  let paint_node = scrollable_500_paint_node()
  b.bench(name="sixel_output_scroll_500_top", fn() {
    b.keep(@image.render_paint_node_to_sixel_scrolled(paint_node, 640, 480, 0))
  })
}

///|
test "bench_sixel_output_scrollable_500_mid" (b : @bench.T) {
  let paint_node = scrollable_500_paint_node()
  b.bench(name="sixel_output_scroll_500_mid", fn() {
    b.keep(
      @image.render_paint_node_to_sixel_scrolled(paint_node, 640, 480, 16000),
    )
  })
}

///|
test "bench_glyph_wrapped_text_framebuffer" (b : @bench.T) {
  set_square_glyph_provider_for_bench(0.55)
  let paint_node = glyph_wrapped_text_paint_node()
  b.bench(name="glyph_wrapped_text_fb", fn() {
    let fb = @image.Framebuffer::new(340, 128)
    let palette = @image.DynamicPalette::new()
    @image.render_paint_node_to_framebuffer(paint_node, fb, palette)
    b.keep(fb)
  })
  @image.clear_glyph_provider()
}
