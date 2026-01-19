// =============================================================================
// CSS Compute Optimization Benchmarks
// =============================================================================
// Compare current vs optimized CSS computation

///|
fn default_render_ctx() -> @renderer.RenderContext {
  {
    viewport_width: 1200.0,
    viewport_height: 800.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
}

///|
/// Create a test stylesheet with various selectors
fn create_real_stylesheet() -> @cascade.Stylesheet {
  // Parse a realistic CSS string
  let css =
    #|.container { display: flex; flex-direction: column; padding: 16px; }
    #|.header { height: 60px; background: #2c3e50; }
    #|.sidebar { width: 240px; flex-shrink: 0; }
    #|.content { flex: 1; padding: 24px; }
    #|.card { background: white; border-radius: 8px; padding: 16px; margin: 8px; }
    #|.title { font-size: 18px; font-weight: bold; margin-bottom: 8px; }
    #|.text { color: #666; line-height: 1.5; }
    #|.button { padding: 8px 16px; background: #3498db; border-radius: 4px; }
    #|.button:hover { background: #2980b9; }
    #|.grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
    #|.flex-row { display: flex; flex-direction: row; gap: 8px; }
    #|.flex-col { display: flex; flex-direction: column; gap: 8px; }
    #|.w-full { width: 100%; }
    #|.h-auto { height: auto; }
    #|.m-0 { margin: 0; }
    #|.p-0 { padding: 0; }
    #|.hidden { display: none; }
    #|.visible { visibility: visible; }
    #|#main { width: 100%; min-height: 100vh; }
    #|#footer { height: 80px; background: #34495e; }
  @parser.parse_stylesheet(css)
}

///|
/// Create a selector element for testing
fn create_selector_element(
  tag : String,
  id : String?,
  classes : Array[String],
) -> @selector.Element {
  let mut elem = @selector.Element::new(tag)
  match id {
    Some(i) => elem = elem.set_id(i)
    None => ()
  }
  for cls in classes {
    elem = elem.add_class(cls)
  }
  elem
}

///|
test "bench_cascade_single_element" (b : @bench.T) {
  let stylesheet = create_real_stylesheet()
  let stylesheets = [stylesheet]
  let elem = create_selector_element("div", None, ["container", "flex-col"])
  let media_env = @media.MediaEnvironment::with_color_scheme(
    1200.0,
    800.0,
    @media.ColorScheme::Light,
  )
  b.bench(name="cascade_single", fn() {
    b.keep(
      @cascade.cascade_element_with_media(
        elem,
        stylesheets,
        [],
        Some(media_env),
      ),
    )
  })
}

///|
test "bench_compute_from_cascaded" (b : @bench.T) {
  let stylesheet = create_real_stylesheet()
  let stylesheets = [stylesheet]
  let elem = create_selector_element("div", None, ["container", "flex-col"])
  let media_env = @media.MediaEnvironment::with_color_scheme(
    1200.0,
    800.0,
    @media.ColorScheme::Light,
  )
  let cascaded = @cascade.cascade_element_with_media(
    elem,
    stylesheets,
    [],
    Some(media_env),
  )
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1200.0,
    viewport_height: 800.0,
    custom_properties: {},
  }
  b.bench(name="compute_cascaded", fn() {
    b.keep(@computed.compute(cascaded, ctx))
  })
}

///|
test "bench_compute_inline_raw" (b : @bench.T) {
  let css = "display: flex; flex-direction: column; padding: 16px"
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width: 1200.0,
    viewport_height: 800.0,
    custom_properties: {},
  }
  b.bench(name="compute_inline", fn() {
    b.keep(@computed.compute_inline_raw(css, ctx))
  })
}

///|
test "bench_full_render_small_css" (b : @bench.T) {
  // Small HTML with stylesheet
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|.container { display: flex; padding: 16px; }
    #|.item { flex: 1; height: 50px; }
    #|</style>
    #|<div class="container">
    #|<div class="item"></div>
    #|<div class="item"></div>
    #|<div class="item"></div>
    #|</div>
  let ctx = default_render_ctx()
  b.bench(name="render_small_css", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_full_render_medium_css" (b : @bench.T) {
  // Medium HTML with more CSS rules
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|.container { display: flex; flex-direction: column; min-height: 100vh; }
    #|.header { height: 60px; background: #2c3e50; display: flex; align-items: center; padding: 0 24px; }
    #|.sidebar { width: 240px; background: #34495e; }
    #|.content { flex: 1; padding: 24px; }
    #|.card { background: white; border-radius: 8px; padding: 16px; margin-bottom: 16px; }
    #|.title { font-size: 18px; margin-bottom: 8px; }
    #|.grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
    #|</style>
    #|<div class="container">
    #|<div class="header"><div class="title">Header</div></div>
    #|<div style="display: flex; flex: 1;">
    #|<div class="sidebar"></div>
    #|<div class="content">
    #|<div class="grid">
    #|<div class="card"><div class="title">Card 1</div></div>
    #|<div class="card"><div class="title">Card 2</div></div>
    #|<div class="card"><div class="title">Card 3</div></div>
    #|<div class="card"><div class="title">Card 4</div></div>
    #|<div class="card"><div class="title">Card 5</div></div>
    #|<div class="card"><div class="title">Card 6</div></div>
    #|</div>
    #|</div>
    #|</div>
    #|</div>
  let ctx = default_render_ctx()
  b.bench(name="render_med_css", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_many_elements_few_rules" (b : @bench.T) {
  // Many elements, few CSS rules (worst case for non-indexed)
  let mut html = "<!DOCTYPE html><style>.item { height: 30px; }</style><body>"
  for i = 0; i < 100; i = i + 1 {
    html = html + "<div class=\"item\">" + i.to_string() + "</div>"
  }
  html = html + "</body>"
  let ctx = default_render_ctx()
  b.bench(name="render_many_few", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_few_elements_many_rules" (b : @bench.T) {
  // Few elements, many CSS rules
  let mut css = ""
  for i = 0; i < 50; i = i + 1 {
    css = css +
      ".class-" +
      i.to_string() +
      " { padding: " +
      i.to_string() +
      "px; }\n"
  }
  let html = "<!DOCTYPE html><style>" +
    css +
    "</style><body><div class=\"class-0 class-10 class-20\">Content</div></body>"
  let ctx = default_render_ctx()
  b.bench(name="render_few_many", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
/// Compare inline vs stylesheet styles - 100 elements
test "bench_render_inline_styles_100" (b : @bench.T) {
  // 100 elements with inline styles
  let mut html = "<!DOCTYPE html><body style=\"margin:0\">"
  for i = 0; i < 100; i = i + 1 {
    html = html +
      "<div style=\"height:20px;background:#" +
      (if i % 2 == 0 { "eee" } else { "ddd" }) +
      "\">" +
      i.to_string() +
      "</div>"
  }
  html = html + "</body>"
  let ctx = default_render_ctx()
  b.bench(name="render_inline_100", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_stylesheet_styles_100" (b : @bench.T) {
  // 100 elements with stylesheet (no inline styles)
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.item { height: 20px; }
    #|.even { background: #eee; }
    #|.odd { background: #ddd; }
    #|</style>
    #|<body>
  let mut body = ""
  for i = 0; i < 100; i = i + 1 {
    body = body +
      "<div class=\"item " +
      (if i % 2 == 0 { "even" } else { "odd" }) +
      "\">" +
      i.to_string() +
      "</div>"
  }
  let full_html = html + body + "</body>"
  let ctx = default_render_ctx()
  b.bench(name="render_css_100", fn() {
    b.keep(@renderer.render(full_html, ctx))
  })
}

///|
/// Compare inline vs stylesheet - 50 elements with more properties
test "bench_render_inline_complex_50" (b : @bench.T) {
  // 50 elements with complex inline styles
  let mut html = "<!DOCTYPE html><body>"
  for i = 0; i < 50; i = i + 1 {
    html = html +
      "<div style=\"display:flex;padding:8px;margin:4px;background:#f0f0f0;border:1px solid #ccc;border-radius:4px\">" +
      i.to_string() +
      "</div>"
  }
  html = html + "</body>"
  let ctx = default_render_ctx()
  b.bench(name="inline_complex_50", fn() { b.keep(@renderer.render(html, ctx)) })
}

///|
test "bench_render_stylesheet_complex_50" (b : @bench.T) {
  // 50 elements with stylesheet (equivalent styles)
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|.card { display: flex; padding: 8px; margin: 4px; background: #f0f0f0; border: 1px solid #ccc; border-radius: 4px; }
    #|</style>
    #|<body>
  let mut body = ""
  for i = 0; i < 50; i = i + 1 {
    body = body + "<div class=\"card\">" + i.to_string() + "</div>"
  }
  let full_html = html + body + "</body>"
  let ctx = default_render_ctx()
  b.bench(name="css_complex_50", fn() {
    b.keep(@renderer.render(full_html, ctx))
  })
}

// =============================================================================
// Pipeline Phase Benchmarks
// =============================================================================

///|
test "bench_phase_parse_only_100" (b : @bench.T) {
  // Phase 1: Parse HTML only
  let mut html = "<!DOCTYPE html><body>"
  for i = 0; i < 100; i = i + 1 {
    html = html +
      "<div style=\"height:20px;background:#eee\">" +
      i.to_string() +
      "</div>"
  }
  html = html + "</body>"
  b.bench(name="phase_parse_100", fn() { b.keep(@html.parse_document(html)) })
}

///|
test "bench_phase_render_to_node_100" (b : @bench.T) {
  // Phase 2: Parse + Style (render_to_node)
  let mut html = "<!DOCTYPE html><body>"
  for i = 0; i < 100; i = i + 1 {
    html = html +
      "<div style=\"height:20px;background:#eee\">" +
      i.to_string() +
      "</div>"
  }
  html = html + "</body>"
  let ctx = default_render_ctx()
  b.bench(name="phase_node_100", fn() {
    b.keep(@renderer.render_to_node(html, ctx))
  })
}

///|
test "bench_phase_layout_only_100" (b : @bench.T) {
  // Phase 3: Layout only (after render_to_node)
  let mut html = "<!DOCTYPE html><body>"
  for i = 0; i < 100; i = i + 1 {
    html = html +
      "<div style=\"height:20px;background:#eee\">" +
      i.to_string() +
      "</div>"
  }
  html = html + "</body>"
  let ctx = default_render_ctx()
  let node = @renderer.render_to_node(html, ctx)
  let layout_ctx : @node.LayoutContext = {
    available_width: ctx.viewport_width,
    available_height: Some(ctx.viewport_height),
    sizing_mode: @node.Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  @dispatch.setup()
  b.bench(name="phase_layout_100", fn() {
    b.keep(@dispatch.compute(node, layout_ctx))
  })
}

///|
test "bench_phase_full_render_100" (b : @bench.T) {
  // Full render (all phases combined)
  let mut html = "<!DOCTYPE html><body>"
  for i = 0; i < 100; i = i + 1 {
    html = html +
      "<div style=\"height:20px;background:#eee\">" +
      i.to_string() +
      "</div>"
  }
  html = html + "</body>"
  let ctx = default_render_ctx()
  b.bench(name="phase_full_100", fn() { b.keep(@renderer.render(html, ctx)) })
}
