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
