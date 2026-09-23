///|
/// A/B harness for incremental (scoped) cascade — Phase 1. Measures the renderer
/// hot path the shell uses on a reflow (`build_render_root_node`): full cascade
/// vs. cascade-reuse (prior styles reused for unchanged subtrees). See
/// docs/incremental-cascade-design.md.

///|
/// A reuse-safe stylesheet (only class/tag/descendant selectors) with `rules`
/// class rules, inlined as a <style> block so the whole page is one document.
fn build_page(blocks : Int, rules : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><head><style>")
  buf.write_string("body{margin:0}.row .cell{margin:2px}")
  for i = 0; i < rules; i = i + 1 {
    buf.write_string(".c")
    buf.write_string(i.to_string())
    buf.write_string("{padding:")
    buf.write_string((i % 12).to_string())
    buf.write_string("px;border:1px solid #ddd;background:#eef;color:#123}")
  }
  buf.write_string("</style></head><body><main-shell>")
  for i = 0; i < blocks; i = i + 1 {
    let c = i % rules
    buf.write_string("<section class=\"box c")
    buf.write_string(c.to_string())
    buf.write_string("\"><div class=\"row c")
    buf.write_string(((c + 1) % rules).to_string())
    buf.write_string("\"><span class=\"cell\">Item ")
    buf.write_string(i.to_string())
    buf.write_string("</span></div><p class=\"body\">para</p></section>")
  }
  buf.write_string("</main-shell></body></html>")
  buf.to_string()
}

///|
fn main {
  let iters = 300
  let html = build_page(90, 60)
  let ctx = {
    ..@renderer.RenderContext::default(),
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let doc = @html.parse_document(html)
  let prepared = @renderer.prepare_render_document(doc, ctx, [])

  // Prime the prior-style maps from one reuse pass over the document.
  @renderer.cascade_reuse_begin(Map([]), Map([]))
  let _ = @renderer.build_render_root_node(doc, ctx, prepared)
  let (prior_styles, prior_sigs, _) = @renderer.cascade_reuse_end()

  // Sanity: how many elements a reuse pass reuses (an unchanged re-render).
  @renderer.cascade_reuse_begin(prior_styles, prior_sigs)
  let _ = @renderer.build_render_root_node(doc, ctx, prepared)
  let (_, _, reused) = @renderer.cascade_reuse_end()

  let mode = "reuse"
  let mut acc = 0
  for i = 0; i < iters; i = i + 1 {
    if mode == "reuse" {
      @renderer.cascade_reuse_begin(prior_styles, prior_sigs)
      let node = @renderer.build_render_root_node(doc, ctx, prepared)
      let _ = @renderer.cascade_reuse_end()
      acc = acc + node.children.length()
    } else {
      let node = @renderer.build_render_root_node(doc, ctx, prepared)
      acc = acc + node.children.length()
    }
  }
  println("mode=\{mode} iters=\{iters} reused_per_pass=\{reused} acc=\{acc}")
}
