///|
test "fixed article fixture renders heading and navigation in text mode" {
  let browser = @shell.Browser::new(1440, 960)
  load_fixture(browser, docs_article_fixture())
  let rendered = browser.render_output(@shell.OutputMode::Text)
  assert_true(rendered.contains("HTML"))
  assert_true(rendered.contains("Web APIs"))
  assert_true(rendered.contains("WebAssembly テキスト形式の理解"))
  assert_true(rendered.contains("セクション 0"))
}

///|
test "fixed article fixture full text output includes below-the-fold sections" {
  let viewport_browser = @shell.Browser::new(1440, 240)
  load_fixture(viewport_browser, docs_article_fixture())
  let viewport = viewport_browser.render_output(@shell.OutputMode::Text)
  assert_true(viewport.contains("セクション 0"))
  assert_true(!viewport.contains("セクション 9"))

  let full_browser = @shell.Browser::new(1440, 240)
  load_fixture(full_browser, docs_article_fixture())
  let full = full_browser.render_text_full_page()
  assert_true(full.contains("セクション 0"))
  assert_true(full.contains("セクション 9"))
  assert_true(full.contains("セクション 13"))
}

///|
test "builtin github snapshot fixture loads and renders non-empty text output" {
  let browser = @shell.Browser::new(1440, 960)
  let html = builtin_github_snapshot_fixture()
  assert_true(html.contains("GitHub"))
  assert_true(!html.contains("<script"))
  load_fixture(browser, html)
  let rendered = browser.render_output(@shell.OutputMode::Text)
  assert_true(rendered.length() > 0)
}

///|
test "builtin github snapshot fixture renders kitty graphics output" {
  let browser = @shell.Browser::new(1440, 960)
  load_fixture(browser, builtin_github_snapshot_fixture())
  let rendered = browser.render_output(@shell.OutputMode::Kitty)
  assert_true(rendered.has_prefix("\u001b_Ga=T,f=24,q=2,s="))
  assert_true(rendered.length() > 64)
}

///|
test "fixed article fixture renders kitty graphics output" {
  let browser = @shell.Browser::new(1440, 960)
  load_fixture(browser, docs_article_fixture())
  let rendered = browser.render_output(@shell.OutputMode::Kitty)
  assert_true(rendered.has_prefix("\u001b_Ga=T,f=24,q=2,s="))
  assert_true(rendered.length() > 64)
}
