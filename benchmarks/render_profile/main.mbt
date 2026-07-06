///|
/// Build a stylesheet with `rules` class rules plus a handful of descendant /
/// tag rules, so the selector-matching side of the cascade has real work.
fn build_css(rules : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("body{margin:0;font-family:sans-serif}")
  buf.write_string("section{display:block;padding:8px}")
  buf.write_string(".row{display:flex;gap:8px}")
  buf.write_string(".row > .cell{flex:1;padding:4px}")
  buf.write_string("main-shell vrt-target .card p{line-height:1.5}")
  for i = 0; i < rules; i = i + 1 {
    buf.write_string(".c")
    buf.write_string(i.to_string())
    buf.write_string("{padding:")
    buf.write_string((i % 12).to_string())
    buf.write_string("px;margin:")
    buf.write_string((i % 7).to_string())
    buf.write_string("px;border:1px solid #ddd;background:#f")
    buf.write_string((i % 10).to_string())
    buf.write_string("f8ff;color:#1")
    buf.write_string((i % 10).to_string())
    buf.write_string("2}")
  }
  buf.to_string()
}

///|
/// Build a page of `blocks` cards, each a small nested subtree carrying a mix
/// of classes so many selectors partially match. Mirrors the shape of the
/// component_vrt "m" fixture (noise blocks around a component subtree).
fn build_html(blocks : Int, rules : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body><main-shell>")
  for i = 0; i < blocks; i = i + 1 {
    let c = i % rules
    buf.write_string("<section class=\"card c")
    buf.write_string(c.to_string())
    buf.write_string("\"><div class=\"row c")
    buf.write_string(((c + 1) % rules).to_string())
    buf.write_string("\"><span class=\"cell c")
    buf.write_string(((c + 2) % rules).to_string())
    buf.write_string("\">Item ")
    buf.write_string(i.to_string())
    buf.write_string("</span><span class=\"cell c")
    buf.write_string(((c + 3) % rules).to_string())
    buf.write_string("\">detail text for row that wraps</span></div>")
    buf.write_string("<p class=\"body c")
    buf.write_string(((c + 4) % rules).to_string())
    buf.write_string(
      "\">Synthetic paragraph content for layout work.</p></section>",
    )
  }
  buf.write_string("</main-shell></body></html>")
  buf.to_string()
}

///|
fn main {
  let rules = 60
  let blocks = 120
  let iters = 200
  let css = [build_css(rules)]
  let html = build_html(blocks, rules)
  let ctx = {
    ..@renderer.RenderContext::default(),
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  // Warm up (parse + first layout) outside the checksum so the profile is
  // dominated by steady-state renders.
  let mut acc = 0
  for i = 0; i < iters; i = i + 1 {
    let (node, layout) = @renderer.render_to_node_and_layout_with_external_css(
      html, ctx, css,
    )
    // Keep the results live so the optimizer can't drop the render.
    acc = acc + node.children.length() + layout.children.length()
  }
  println("rendered \{iters}x blocks=\{blocks} rules=\{rules} acc=\{acc}")
}
