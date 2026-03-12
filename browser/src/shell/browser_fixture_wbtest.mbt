///|
test "fixed article fixture renders heading and navigation in text mode" {
  let browser = Browser::new(1440, 960)
  load_fixture(browser, docs_article_fixture())
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("HTML"))
  assert_true(rendered.contains("Web APIs"))
  assert_true(rendered.contains("WebAssembly テキスト形式の理解"))
  assert_true(rendered.contains("セクション 0"))
}

///|
test "fixed article fixture exposes links and article role in aom output" {
  let browser = Browser::new(1440, 960)
  load_fixture(browser, docs_article_fixture())
  browser.links = extract_links(browser.html_content)
  browser.build_accessibility_tree()
  let aom = browser.render_output(Aom)
  inspect(browser.get_link_count(), content="22")
  assert_true(
    aom.contains(
      "- heading \"WebAssembly テキスト形式の理解\" [level=1]",
    ),
  )
  assert_true(aom.contains("WebAssembly テキスト形式の理解"))
}
