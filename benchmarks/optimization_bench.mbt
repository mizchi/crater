// =============================================================================
// Optimization Investigation Benchmarks
// =============================================================================
// Measure specific bottlenecks and optimization opportunities

///|
/// Create realistic stylesheets like a typical webpage
fn create_realistic_stylesheet() -> @css.Stylesheet {
  let css =
    #|body { margin: 0; font-family: sans-serif; }
    #|.container { max-width: 1200px; margin: 0 auto; padding: 0 16px; }
    #|.header { display: flex; align-items: center; height: 64px; border-bottom: 1px solid #eee; }
    #|.nav { display: flex; gap: 24px; }
    #|.nav-item { color: #333; text-decoration: none; }
    #|.nav-item:hover { color: #007bff; }
    #|.main { display: flex; gap: 24px; padding: 24px 0; }
    #|.sidebar { width: 280px; flex-shrink: 0; }
    #|.content { flex: 1; min-width: 0; }
    #|.card { background: white; border-radius: 8px; padding: 16px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    #|.card-title { font-size: 18px; font-weight: bold; margin-bottom: 8px; }
    #|.card-text { color: #666; line-height: 1.5; }
    #|.btn { display: inline-flex; align-items: center; padding: 8px 16px; border-radius: 4px; }
    #|.btn-primary { background: #007bff; color: white; }
    #|.btn-secondary { background: #6c757d; color: white; }
    #|.grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
    #|.flex-row { display: flex; flex-direction: row; }
    #|.flex-col { display: flex; flex-direction: column; }
    #|.text-center { text-align: center; }
    #|.text-muted { color: #6c757d; }
    #|.mt-2 { margin-top: 8px; }
    #|.mb-2 { margin-bottom: 8px; }
    #|.p-2 { padding: 8px; }
    #|.p-4 { padding: 16px; }
    #|.hidden { display: none; }
    #|.visible { visibility: visible; }
    #|#main-content { width: 100%; }
    #|#footer { background: #f8f9fa; padding: 24px 0; margin-top: 48px; }
  @css.parse_stylesheet(css)
}

///|
/// Create larger stylesheet (100 rules)
fn create_large_stylesheet() -> @css.Stylesheet {
  let mut css = ""
  // Add 100 class rules
  for i = 0; i < 100; i = i + 1 {
    css = css +
      ".class-" +
      i.to_string() +
      " { padding: " +
      (i % 20).to_string() +
      "px; margin: " +
      (i % 10).to_string() +
      "px; }\n"
  }
  @css.parse_stylesheet(css)
}

///|
fn make_selector_elem(
  tag : String,
  id : String?,
  classes : Array[String],
) -> @css.Element {
  let mut elem = @css.Element::new(tag)
  match id {
    Some(i) => elem = elem.set_id(i)
    None => ()
  }
  for cls in classes {
    elem = elem.add_class(cls)
  }
  elem
}

// =============================================================================
// Selector Matching Benchmarks
// =============================================================================

///|
/// Benchmark: Non-indexed matching with realistic stylesheet
test "bench_match_non_indexed_realistic" (b : @bench.T) {
  let stylesheet = create_realistic_stylesheet()
  let elem = make_selector_elem("div", None, ["card", "p-4"])
  b.bench(name="match_nonidx_real", fn() {
    b.keep(stylesheet.match_element(elem))
  })
}

///|
/// Benchmark: Indexed matching with realistic stylesheet
test "bench_match_indexed_realistic" (b : @bench.T) {
  let stylesheet = create_realistic_stylesheet()
  let indexed = @css.IndexedStylesheet::new(stylesheet)
  let elem = make_selector_elem("div", None, ["card", "p-4"])
  b.bench(name="match_idx_real", fn() { b.keep(indexed.match_element(elem)) })
}

///|
/// Benchmark: Non-indexed matching with large stylesheet (100 rules)
test "bench_match_non_indexed_large" (b : @bench.T) {
  let stylesheet = create_large_stylesheet()
  let elem = make_selector_elem("div", None, ["class-50", "class-25"])
  b.bench(name="match_nonidx_100", fn() {
    b.keep(stylesheet.match_element(elem))
  })
}

///|
/// Benchmark: Indexed matching with large stylesheet (100 rules)
test "bench_match_indexed_large" (b : @bench.T) {
  let stylesheet = create_large_stylesheet()
  let indexed = @css.IndexedStylesheet::new(stylesheet)
  let elem = make_selector_elem("div", None, ["class-50", "class-25"])
  b.bench(name="match_idx_100", fn() { b.keep(indexed.match_element(elem)) })
}

// =============================================================================
// Context Creation Overhead
// =============================================================================

///|
/// Benchmark: ComputeContext creation
test "bench_context_creation" (b : @bench.T) {
  b.bench(name="ctx_create", fn() { b.keep(@css.ComputeContext::new()) })
}

///|
/// Benchmark: MediaEnvironment creation
test "bench_media_env_creation" (b : @bench.T) {
  b.bench(name="media_env_create", fn() {
    b.keep(
      @css.MediaEnvironment::with_color_scheme(
        1200.0,
        800.0,
        @css.ColorScheme::Light,
      ),
    )
  })
}

///|
/// Benchmark: Style::default() creation
test "bench_style_default_creation" (b : @bench.T) {
  b.bench(name="style_default", fn() { b.keep(@style.Style::default()) })
}

// =============================================================================
// Property Application Benchmarks
// =============================================================================

///|
/// Benchmark: Single property application
test "bench_apply_single_property" (b : @bench.T) {
  let style = @style.Style::default()
  let ctx = @css.ComputeContext::new()
  b.bench(name="apply_single", fn() {
    b.keep(@css.apply_property_direct(style, "padding", "16px", ctx))
  })
}

///|
/// Benchmark: Multiple properties with reused context
test "bench_apply_multiple_reused_ctx" (b : @bench.T) {
  let ctx = @css.ComputeContext::new()
  b.bench(name="apply_multi_reuse", fn() {
    let mut style = @style.Style::default()
    style = @css.apply_property_direct(style, "display", "flex", ctx)
    style = @css.apply_property_direct(style, "padding", "16px", ctx)
    style = @css.apply_property_direct(style, "margin", "8px", ctx)
    style = @css.apply_property_direct(style, "width", "100%", ctx)
    b.keep(style)
  })
}

///|
/// Benchmark: Multiple properties with new context each time
test "bench_apply_multiple_new_ctx" (b : @bench.T) {
  b.bench(name="apply_multi_new", fn() {
    let mut style = @style.Style::default()
    style = @css.apply_property_direct(
      style,
      "display",
      "flex",
      @css.ComputeContext::new(),
    )
    style = @css.apply_property_direct(
      style,
      "padding",
      "16px",
      @css.ComputeContext::new(),
    )
    style = @css.apply_property_direct(
      style,
      "margin",
      "8px",
      @css.ComputeContext::new(),
    )
    style = @css.apply_property_direct(
      style,
      "width",
      "100%",
      @css.ComputeContext::new(),
    )
    b.keep(style)
  })
}

///|
fn create_cascade_declarations(
  total : Int,
  property_kinds : Int,
) -> Array[@css.Declaration] {
  let declarations : Array[@css.Declaration] = []
  for i = 0; i < total; i = i + 1 {
    let property = "prop-" + (i % property_kinds).to_string()
    declarations.push({
      property,
      value: @css.PropertyValue::Value(i.to_string() + "px"),
      origin: @css.Origin::Author,
      importance: if i % 9 == 0 {
        @css.Importance::Important
      } else {
        @css.Importance::Normal
      },
      specificity: { a: 0, b: i % 5, c: i % 3 },
      source_order: i,
    })
  }
  declarations
}

///|
test "bench_cascade_declarations_200" (b : @bench.T) {
  let declarations = create_cascade_declarations(200, 20)
  b.bench(name="cascade_decl_200", fn() {
    b.keep(@css.cascade_declarations(declarations))
  })
}

///|
fn create_compute_cascaded_values() -> @css.CascadedValues {
  let declarations : Array[@css.Declaration] = [
    @css.Declaration::new("--main-color", "#333"),
    @css.Declaration::new("--gap-size", "12px"),
    @css.Declaration::new("--card-padding", "16px"),
    @css.Declaration::new("display", "flex"),
    @css.Declaration::new("font", "16px/20px sans-serif"),
    @css.Declaration::new("width", "100%"),
    @css.Declaration::new("min-width", "0"),
    @css.Declaration::new("height", "auto"),
    @css.Declaration::new("padding", "var(--card-padding)"),
    @css.Declaration::new("margin", "8px"),
    @css.Declaration::new("column-gap", "var(--gap-size)"),
    @css.Declaration::new("row-gap", "var(--gap-size)"),
    @css.Declaration::new("justify-content", "space-between"),
    @css.Declaration::new("align-items", "center"),
    @css.Declaration::new("background-color", "#fff"),
    @css.Declaration::new("color", "var(--main-color)"),
    @css.Declaration::new("writing-mode", "horizontal-tb"),
  ]
  @css.cascade_declarations(declarations)
}

///|
test "bench_compute_with_vars_mixed_props" (b : @bench.T) {
  let cascaded = create_compute_cascaded_values()
  let ctx = @css.ComputeContext::new()
  b.bench(name="compute_with_vars_mixed", fn() {
    b.keep(@css.compute_style_with_vars(cascaded, ctx))
  })
}

// =============================================================================
// Full Pipeline Comparison
// =============================================================================

///|
/// HTML for pipeline tests
fn pipeline_html() -> String {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|.container { display: flex; flex-direction: column; padding: 16px; }
    #|.header { height: 60px; background: #2c3e50; }
    #|.item { padding: 8px; margin: 4px; background: #f0f0f0; }
    #|</style>
    #|<div class="container">
    #|<div class="header">Header</div>
    #|<div class="item">Item 1</div>
    #|<div class="item">Item 2</div>
    #|<div class="item">Item 3</div>
    #|<div class="item">Item 4</div>
    #|<div class="item">Item 5</div>
    #|</div>
  html
}

///|
/// Benchmark: Current pipeline
test "bench_pipeline_current" (b : @bench.T) {
  let html = pipeline_html()
  let ctx = default_render_ctx()
  b.bench(name="pipeline_current", fn() { b.keep(@renderer.render(html, ctx)) })
}
