///|
fn static_snapshot_viewport() -> @types.Size[Double] {
  @types.Size::new(1280.0, 900.0)
}

///|
fn static_snapshot_context() -> @renderer.RenderContext {
  {
    ..@renderer.RenderContext::default(),
    viewport_width: static_snapshot_viewport().width,
    viewport_height: static_snapshot_viewport().height,
  }
}

///|
fn static_snapshot_head(buf : StringBuilder) -> Unit {
  buf.write_string("<!DOCTYPE html><html><head><meta charset=\"utf-8\">")
  buf.write_string("<title>Static snapshot benchmark</title>")
  buf.write_string("<style>")
  buf.write_string(
    "html{font-family:Arial,sans-serif;font-size:16px;line-height:1.45;color:#1b1f24;background:#fff}",
  )
  buf.write_string("body{margin:0;background:#fff}")
  buf.write_string(
    ".page{display:grid;grid-template-columns:280px minmax(0,1fr)260px;gap:24px;max-width:1280px;margin:0 auto;padding:20px}",
  )
  buf.write_string(
    ".topbar{height:56px;border-bottom:1px solid #d9dee3;display:flex;align-items:center;padding:0 18px;background:#f8f9fb}",
  )
  buf.write_string(
    ".sidebar{display:flex;flex-direction:column;gap:4px;font-size:13px}",
  )
  buf.write_string(
    ".nav-link{display:flex;justify-content:space-between;gap:10px;color:#334155;text-decoration:none;padding:5px 8px;border-radius:4px}",
  )
  buf.write_string(".nav-link:hover{background:#eef2f7}")
  buf.write_string(
    "main{min-width:0;max-width:760px}.crumbs{font-size:12px;color:#64748b;margin-bottom:10px}",
  )
  buf.write_string(
    "h1{font-size:38px;line-height:1.1;margin:0 0 18px}h2{font-size:25px;margin:28px 0 12px}",
  )
  buf.write_string(
    "p{margin:0 0 14px}.note{border-left:4px solid #3b82f6;background:#eff6ff;padding:12px 14px;margin:16px 0}",
  )
  buf.write_string(
    "code{font-family:Menlo,monospace;background:#f1f5f9;border-radius:4px;padding:1px 4px}",
  )
  buf.write_string(
    ".cards{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin:18px 0}",
  )
  buf.write_string(
    ".card{border:1px solid #d9dee3;border-radius:6px;padding:12px;background:#fff}.related{font-size:13px}",
  )
  buf.write_string("</style></head>")
}

///|
fn static_snapshot_topbar(buf : StringBuilder) -> Unit {
  buf.write_string("<body><header class=\"topbar\">")
  buf.write_string("<strong>Developer Docs</strong>")
  buf.write_string(
    "<span style=\"margin-left:auto;color:#64748b\">reference snapshot</span>",
  )
  buf.write_string("</header><div class=\"page\">")
}

///|
fn static_snapshot_sidebar(buf : StringBuilder, count : Int) -> Unit {
  buf.write_string(
    "<nav class=\"sidebar\" aria-label=\"Reference navigation\">",
  )
  for i = 0; i < count; i = i + 1 {
    buf.write_string("<a class=\"nav-link\" href=\"/docs/static/")
    buf.write_string(i.to_string())
    buf.write_string("\"><span>Reference item ")
    buf.write_string(i.to_string())
    buf.write_string("</span><span>API</span></a>")
  }
  buf.write_string("</nav>")
}

///|
fn static_snapshot_article(buf : StringBuilder, sections : Int) -> Unit {
  buf.write_string("<main>")
  buf.write_string(
    "<div class=\"crumbs\">Docs / Web platform / Static snapshot</div>",
  )
  buf.write_string("<h1>Static document rendering benchmark</h1>")
  buf.write_string(
    "<p>This page models a no-script documentation snapshot with a large navigation tree and a content column that should fit inside the first viewport.</p>",
  )
  buf.write_string("<div class=\"note\">")
  buf.write_string(
    "The benchmark keeps the relevant body prefix and article content, mirroring the viewport-oriented static HTML path used by VRT.",
  )
  buf.write_string("</div>")
  for i = 0; i < sections; i = i + 1 {
    buf.write_string("<section><h2>Section ")
    buf.write_string(i.to_string())
    buf.write_string("</h2>")
    for p = 0; p < 4; p = p + 1 {
      buf.write_string("<p>")
      buf.write_string(
        "Rendering a captured document requires tokenization, tree construction, CSS cascade, layout, and paint data extraction. ",
      )
      buf.write_string(
        "The static path intentionally avoids unrelated deferred application markup while preserving the first viewport content. ",
      )
      buf.write_string("Example ")
      buf.write_string(i.to_string())
      buf.write_string(".")
      buf.write_string(p.to_string())
      buf.write_string(
        " uses <code>display:flex</code>, <code>min-width:0</code>, and inline text wrapping.</p>",
      )
    }
    buf.write_string("<div class=\"cards\">")
    for c = 0; c < 4; c = c + 1 {
      buf.write_string("<article class=\"card\"><strong>Card ")
      buf.write_string(c.to_string())
      buf.write_string(
        "</strong><p>Compact metadata for the article viewport.</p></article>",
      )
    }
    buf.write_string("</div></section>")
  }
  buf.write_string("</main>")
}

///|
fn static_snapshot_related(buf : StringBuilder, count : Int) -> Unit {
  buf.write_string("<aside class=\"related\" aria-label=\"Related pages\">")
  for i = 0; i < count; i = i + 1 {
    buf.write_string("<section class=\"card\"><strong>Related ")
    buf.write_string(i.to_string())
    buf.write_string(
      "</strong><p>Additional static content outside the viewport article.</p></section>",
    )
  }
  buf.write_string("</aside>")
}

///|
fn static_snapshot_html(
  nav_items : Int,
  sections : Int,
  related_items : Int,
) -> String {
  let buf = StringBuilder::new()
  static_snapshot_head(buf)
  static_snapshot_topbar(buf)
  static_snapshot_sidebar(buf, nav_items)
  static_snapshot_article(buf, sections)
  static_snapshot_related(buf, related_items)
  buf.write_string("</div></body></html>")
  buf.to_string()
}

///|
fn static_snapshot_full_reference_html() -> String {
  static_snapshot_html(320, 14, 120)
}

///|
fn static_snapshot_trimmed_viewport_html() -> String {
  static_snapshot_html(8, 4, 0)
}

///|
extern "js" fn js_load_real_world_snapshot_html(name : String) -> String =
  #| (name) => {
  #|   const fs = require("node:fs");
  #|   const path = require("node:path");
  #|   const candidates = [
  #|     path.join(process.cwd(), "real-world", name, "index.html"),
  #|     path.join(process.cwd(), "..", "real-world", name, "index.html"),
  #|   ];
  #|   const resolved = candidates.find((candidate) => fs.existsSync(candidate));
  #|   if (!resolved) {
  #|     throw new Error(
  #|       `real-world snapshot not found: ${name}; searched ${candidates.join(", ")}`,
  #|     );
  #|   }
  #|   return fs.readFileSync(resolved, "utf8");
  #| }

///|
extern "js" fn js_trim_static_html_for_viewport(
  html : String,
  body_budget : Int,
  main_budget : Int,
) -> String =
  #| (html, bodyBudget, mainBudget) => {
  #|   const bodyMatch = /<body\b[^>]*>/i.exec(html);
  #|   if (!bodyMatch) return html;
  #|   const bodyStart = bodyMatch.index;
  #|   const keepUntil = Math.min(html.length, bodyStart + Math.max(1000, bodyBudget));
  #|   if (keepUntil === html.length) return html;
  #|   const mainIndex = html.toLowerCase().indexOf("<main", keepUntil);
  #|   if (mainIndex >= 0) {
  #|     const mainEnd = Math.min(html.length, mainIndex + Math.max(1000, mainBudget));
  #|     return `${html.slice(0, keepUntil)}
  #| <!-- crater-vrt-skipped-static-html -->
  #| ${html.slice(mainIndex, mainEnd)}
  #| <!-- crater-vrt-truncated-static-html -->
  #| </body></html>`;
  #|   }
  #|   return html;
  #| }

///|
fn static_snapshot_mdn_full_html() -> String {
  js_load_real_world_snapshot_html("mdn-wasm-text")
}

///|
fn static_snapshot_mdn_trimmed_html() -> String {
  js_trim_static_html_for_viewport(static_snapshot_mdn_full_html(), 1000, 4000)
}

///|
test "bench_static_snapshot_parse_full_reference" (b : @bench.T) {
  let html = static_snapshot_full_reference_html()
  b.bench(name="static_snapshot_parse_full_reference", fn() {
    b.keep(@html.parse_document(html))
  })
}

///|
test "bench_static_snapshot_parse_trimmed_viewport" (b : @bench.T) {
  let html = static_snapshot_trimmed_viewport_html()
  b.bench(name="static_snapshot_parse_trimmed_viewport", fn() {
    b.keep(@html.parse_document(html))
  })
}

///|
test "bench_static_snapshot_node_layout_full_reference" (b : @bench.T) {
  let doc = @html.parse_document(static_snapshot_full_reference_html())
  let ctx = static_snapshot_context()
  b.bench(name="static_snapshot_node_layout_full_reference", fn() {
    b.keep(@renderer.render_to_node_and_layout_with_document(doc, ctx, []))
  })
}

///|
test "bench_static_snapshot_node_layout_trimmed_viewport" (b : @bench.T) {
  let doc = @html.parse_document(static_snapshot_trimmed_viewport_html())
  let ctx = static_snapshot_context()
  b.bench(name="static_snapshot_node_layout_trimmed_viewport", fn() {
    b.keep(@renderer.render_to_node_and_layout_with_document(doc, ctx, []))
  })
}

///|
test "bench_static_snapshot_render_trimmed_viewport" (b : @bench.T) {
  let html = static_snapshot_trimmed_viewport_html()
  let ctx = static_snapshot_context()
  b.bench(name="static_snapshot_render_trimmed_viewport", fn() {
    b.keep(@renderer.render_to_node_and_layout(html, ctx))
  })
}

///|
test "bench_static_snapshot_paint_tree_trimmed_viewport" (b : @bench.T) {
  let viewport = static_snapshot_viewport()
  let ctx = static_snapshot_context()
  let html = static_snapshot_trimmed_viewport_html()
  b.bench(name="static_snapshot_paint_tree_trimmed_viewport", fn() {
    let (node, layout) = @renderer.render_to_node_and_layout(html, ctx)
    b.keep(build_vrt_paint_tree(node, layout, viewport))
  })
}

///|
test "bench_static_snapshot_parse_mdn_full_snapshot" (b : @bench.T) {
  let html = static_snapshot_mdn_full_html()
  b.bench(name="static_snapshot_parse_mdn_full_snapshot", fn() {
    b.keep(@html.parse_document(html))
  })
}

///|
test "bench_static_snapshot_parse_mdn_trimmed_viewport" (b : @bench.T) {
  let html = static_snapshot_mdn_trimmed_html()
  b.bench(name="static_snapshot_parse_mdn_trimmed_viewport", fn() {
    b.keep(@html.parse_document(html))
  })
}

///|
test "bench_static_snapshot_render_mdn_trimmed_viewport" (b : @bench.T) {
  let html = static_snapshot_mdn_trimmed_html()
  let ctx = static_snapshot_context()
  b.bench(name="static_snapshot_render_mdn_trimmed_viewport", fn() {
    b.keep(@renderer.render_to_node_and_layout(html, ctx))
  })
}

///|
test "bench_static_snapshot_prepare_mdn_trimmed_viewport" (b : @bench.T) {
  let doc = @html.parse_document(static_snapshot_mdn_trimmed_html())
  let ctx = static_snapshot_context()
  b.bench(name="static_snapshot_prepare_mdn_trimmed_viewport", fn() {
    b.keep(@renderer.prepare_render_document(doc, ctx, []))
  })
}

///|
test "bench_static_snapshot_node_build_mdn_trimmed_viewport" (b : @bench.T) {
  let doc = @html.parse_document(static_snapshot_mdn_trimmed_html())
  let ctx = static_snapshot_context()
  let prepared = @renderer.prepare_render_document(doc, ctx, [])
  b.bench(name="static_snapshot_node_build_mdn_trimmed_viewport", fn() {
    b.keep(@renderer.build_render_root_node(doc, ctx, prepared))
  })
}

///|
test "bench_static_snapshot_layout_mdn_trimmed_viewport" (b : @bench.T) {
  let doc = @html.parse_document(static_snapshot_mdn_trimmed_html())
  let ctx = static_snapshot_context()
  let prepared = @renderer.prepare_render_document(doc, ctx, [])
  let node = @renderer.build_render_root_node(doc, ctx, prepared)
  let layout_ctx = default_layout_ctx(ctx)
  @tree.setup()
  b.bench(name="static_snapshot_layout_mdn_trimmed_viewport", fn() {
    b.keep(@tree.compute_layout_in_context(node, layout_ctx))
  })
}

///|
