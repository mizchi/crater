///|
test "bench_browser_text_dashboard_fixed" (b : @bench.T) {
  let browser = @shell.Browser::new(1280, 900)
  let html = @fixtures.dashboard(15, 12)
  b.bench(name="browser_text_dashboard", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(@shell.OutputMode::Text))
  })
}

///|
test "bench_browser_text_article_fixed" (b : @bench.T) {
  let browser = @shell.Browser::new(1440, 960)
  let html = docs_article_fixture()
  b.bench(name="browser_text_article", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(@shell.OutputMode::Text))
  })
}

///|
test "bench_browser_sixel_scroll_fixed" (b : @bench.T) {
  let browser = @shell.Browser::new(1200, 800)
  let html = @fixtures.scrollable_list(500, 64)
  b.bench(name="browser_sixel_scroll_500", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(@shell.OutputMode::Sixel))
  })
}

///|
test "bench_browser_sixel_github_mizchi_snapshot" (b : @bench.T) {
  let browser = @shell.Browser::new(1440, 960)
  let html = builtin_github_snapshot_fixture()
  b.bench(name="browser_sixel_github_mizchi", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(@shell.OutputMode::Sixel))
  })
}

///|
test "bench_browser_kitty_github_mizchi_snapshot" (b : @bench.T) {
  let browser = @shell.Browser::new(1440, 960)
  let html = builtin_github_snapshot_fixture()
  b.bench(name="browser_kitty_github_mizchi", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(@shell.OutputMode::Kitty))
  })
}

///|
test "bench_browser_kitty_article_fixed" (b : @bench.T) {
  let browser = @shell.Browser::new(720, 480)
  let html = docs_article_fixture()
  b.bench(name="browser_kitty_article", fn() {
    load_fixture(browser, html)
    b.keep(browser.render_output(@shell.OutputMode::Kitty))
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
