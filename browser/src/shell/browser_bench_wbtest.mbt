///|
fn load_fixture(browser : Browser, html : String) -> Unit {
  browser.html_content = html
  browser.parsed_doc = None
  browser.external_css = []
  browser.scroll_y = 0
  browser.content_height = 0
  browser.render_node = None
  browser.layout_tree = None
  browser.prev_buffer = None
  browser.last_render_key = ""
}

///|
extern "js" fn js_load_builtin_github_snapshot() -> String =
  #| () => {
  #|   const fs = require("node:fs");
  #|   const path = require("node:path");
  #|   const candidates = [
  #|     path.join(process.cwd(), "src", "benchmarks", "fixtures"),
  #|     path.join(process.cwd(), "..", "src", "benchmarks", "fixtures"),
  #|   ];
  #|   const dir = candidates.find((candidate) =>
  #|     fs.existsSync(path.join(candidate, "github_mizchi.html"))
  #|   );
  #|   if (!dir) {
  #|     throw new Error(
  #|       `github snapshot fixture directory not found: ${candidates.join(", ")}`,
  #|     );
  #|   }
  #|   const html = fs.readFileSync(path.join(dir, "github_mizchi.html"), "utf8");
  #|   const cssFiles = [
  #|     "github_primer.css",
  #|     "github_global.css",
  #|     "github_main.css",
  #|     "github_profile.css",
  #|   ];
  #|   const styles = cssFiles.map((name, index) => {
  #|     const css = fs.readFileSync(path.join(dir, name), "utf8");
  #|     return `<style data-real-world-style="${index + 1}">\n${css}\n</style>`;
  #|   }).join("\n");
  #|   const withoutScripts = String(html)
  #|     .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "")
  #|     .replace(/<script\b[^>]*\/\s*>/gi, "");
  #|   const withoutLinks = withoutScripts
  #|     .replace(/<link\b[^>]*rel=(['"])[^'"]*stylesheet[^'"]*\1[^>]*>/gi, "")
  #|     .replace(/<link\b[^>]*rel=(['"])[^'"]*(dns-prefetch|preconnect|prefetch|preload)[^'"]*\1[^>]*>/gi, "");
  #|   return withoutLinks.replace(
  #|     /<\/head>/i,
  #|     `<base href="https://github.com/mizchi">\n${styles}\n</head>`,
  #|   );
  #| }

///|
fn builtin_github_snapshot_fixture() -> String {
  js_load_builtin_github_snapshot()
}

///|
fn make_render_ctx(width : Int, height : Int) -> @renderer.RenderContext {
  {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
}

///|
fn github_snapshot_render_ctx() -> @renderer.RenderContext {
  make_render_ctx(1440, 960)
}

///|
fn kitty_article_render_ctx() -> @renderer.RenderContext {
  make_render_ctx(720, 480)
}

///|
fn docs_article_fixture() -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "<!DOCTYPE html><html><body style=\"margin:0;background:#202532;color:#f6f7fb\">",
  )
  buf.write_string(
    "<header style=\"padding:24px 40px;border-bottom:1px solid #39404f\">",
  )
  buf.write_string(
    "<nav style=\"display:flex;gap:24px\"><a href=\"#html\">HTML</a><a href=\"#css\">CSS</a><a href=\"#js\">JavaScript</a><a href=\"#api\">Web APIs</a></nav>",
  )
  buf.write_string("</header>")
  buf.write_string(
    "<main style=\"display:grid;grid-template-columns:240px 1fr;gap:32px;padding:32px 40px\">",
  )
  buf.write_string("<aside style=\"padding-top:16px\">")
  for i = 0; i < 18; i = i + 1 {
    buf.write_string("<div style=\"margin-bottom:12px\"><a href=\"#sec")
    buf.write_string(i.to_string())
    buf.write_string("\">節 ")
    buf.write_string(i.to_string())
    buf.write_string("</a></div>")
  }
  buf.write_string("</aside>")
  buf.write_string("<article style=\"max-width:860px\">")
  buf.write_string(
    "<h1 style=\"font-size:42px;margin:0 0 16px\">WebAssembly テキスト形式の理解</h1>",
  )
  buf.write_string(
    "<p style=\"margin:0 0 20px\">バイナリーとテキスト形式の両方で WebAssembly のモジュールを表現できます。</p>",
  )
  for i = 0; i < 14; i = i + 1 {
    buf.write_string("<section id=\"sec")
    buf.write_string(i.to_string())
    buf.write_string("\" style=\"margin-bottom:28px\">")
    buf.write_string(
      "<h2 style=\"font-size:28px;margin:0 0 12px\">セクション ",
    )
    buf.write_string(i.to_string())
    buf.write_string("</h2>")
    buf.write_string(
      "<p style=\"margin:0 0 12px\">S 式はツリー構造を表現するための構文で、括弧とラベルの並びから構成されます。</p>",
    )
    buf.write_string(
      "<pre style=\"padding:16px;background:#171b25;border-radius:8px;overflow:auto\">(module (func (export \\\"run\\\") nop))</pre>",
    )
    buf.write_string("</section>")
  }
  buf.write_string("</article></main></body></html>")
  buf.to_string()
}

///|
test "bench_browser_text_dashboard_fixed" (b : @bench.T) {
  let browser = Browser::new(1280, 900)
  let html = @benchmarks.dashboard(15, 12)
  b.bench(name="browser_text_dashboard", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(Text))
  })
}

///|
test "bench_browser_text_article_fixed" (b : @bench.T) {
  let browser = Browser::new(1440, 960)
  let html = docs_article_fixture()
  b.bench(name="browser_text_article", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(Text))
  })
}

///|
test "bench_browser_sixel_scroll_fixed" (b : @bench.T) {
  let browser = Browser::new(1200, 800)
  let html = @benchmarks.scrollable_list(500, 64)
  b.bench(name="browser_sixel_scroll_500", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(Sixel))
  })
}

///|
test "bench_browser_sixel_github_mizchi_snapshot" (b : @bench.T) {
  let browser = Browser::new(1440, 960)
  let html = builtin_github_snapshot_fixture()
  b.bench(name="browser_sixel_github_mizchi", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(Sixel))
  })
}

///|
test "bench_browser_kitty_github_mizchi_snapshot" (b : @bench.T) {
  let browser = Browser::new(1440, 960)
  let html = builtin_github_snapshot_fixture()
  b.bench(name="browser_kitty_github_mizchi", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(Kitty))
  })
}

///|
test "bench_browser_kitty_article_fixed" (b : @bench.T) {
  let browser = Browser::new(720, 480)
  let html = docs_article_fixture()
  b.bench(name="browser_kitty_article", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(Kitty))
  })
}

///|
test "bench_browser_sixel_github_mizchi_node" (b : @bench.T) {
  let html = builtin_github_snapshot_fixture()
  let ctx = github_snapshot_render_ctx()
  b.bench(name="browser_sixel_github_mizchi_node", fn() {
    b.keep(@renderer.render_to_node_with_external_css(html, ctx, []))
  })
}

///|
test "bench_browser_sixel_github_mizchi_layout" (b : @bench.T) {
  let html = builtin_github_snapshot_fixture()
  let ctx = github_snapshot_render_ctx()
  b.bench(name="browser_sixel_github_mizchi_layout", fn() {
    b.keep(@renderer.render_with_external_css(html, ctx, []))
  })
}

///|
test "bench_browser_sixel_github_mizchi_node_and_layout_shared" (b : @bench.T) {
  let html = builtin_github_snapshot_fixture()
  let ctx = github_snapshot_render_ctx()
  b.bench(name="browser_sixel_github_mizchi_shared_node_layout", fn() {
    b.keep(@renderer.render_to_node_and_layout_with_external_css(html, ctx, []))
  })
}

///|
test "bench_browser_sixel_github_mizchi_paint_tree" (b : @bench.T) {
  let html = builtin_github_snapshot_fixture()
  let ctx = github_snapshot_render_ctx()
  let node = @renderer.render_to_node_with_external_css(html, ctx, [])
  let layout = @renderer.render_with_external_css(html, ctx, [])
  b.bench(name="browser_sixel_github_mizchi_paint_tree", fn() {
    b.keep(@tui_paint_plain.from_node_and_layout(node, layout))
  })
}

///|
test "bench_browser_sixel_github_mizchi_sixel_encode" (b : @bench.T) {
  let html = builtin_github_snapshot_fixture()
  let ctx = github_snapshot_render_ctx()
  let node = @renderer.render_to_node_with_external_css(html, ctx, [])
  let layout = @renderer.render_with_external_css(html, ctx, [])
  let paint_node = @tui_paint_plain.from_node_and_layout(node, layout)
  b.bench(name="browser_sixel_github_mizchi_sixel_encode", fn() {
    b.keep(@image.render_paint_node_to_sixel_scrolled(paint_node, 1440, 960, 0))
  })
}

///|
test "bench_browser_kitty_github_mizchi_kitty_encode" (b : @bench.T) {
  let html = builtin_github_snapshot_fixture()
  let ctx = github_snapshot_render_ctx()
  let node = @renderer.render_to_node_with_external_css(html, ctx, [])
  let layout = @renderer.render_with_external_css(html, ctx, [])
  let paint_node = @tui_paint_plain.from_node_and_layout(node, layout)
  b.bench(name="browser_kitty_github_mizchi_kitty_encode", fn() {
    b.keep(@kitty.render_paint_node_to_kitty_scrolled(paint_node, 1440, 960, 0))
  })
}

///|
test "bench_browser_kitty_article_kitty_encode" (b : @bench.T) {
  let html = docs_article_fixture()
  let ctx = kitty_article_render_ctx()
  let node = @renderer.render_to_node_with_external_css(html, ctx, [])
  let layout = @renderer.render_with_external_css(html, ctx, [])
  let paint_node = @tui_paint_plain.from_node_and_layout(node, layout)
  b.bench(name="browser_kitty_article_kitty_encode", fn() {
    b.keep(@kitty.render_paint_node_to_kitty_scrolled(paint_node, 720, 480, 0))
  })
}
