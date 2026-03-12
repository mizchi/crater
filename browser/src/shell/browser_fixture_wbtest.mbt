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

///|
test "builtin github snapshot fixture loads and renders non-empty text output" {
  let browser = Browser::new(1440, 960)
  let html = builtin_github_snapshot_fixture()
  assert_true(html.contains("GitHub"))
  assert_true(not(html.contains("<script")))
  load_fixture(browser, html)
  let rendered = browser.render_output(Text)
  assert_true(rendered.length() > 0)
}

///|
test "builtin github snapshot fixture renders kitty graphics output" {
  let browser = Browser::new(1440, 960)
  let html = builtin_github_snapshot_fixture()
  load_fixture(browser, html)
  let rendered = browser.render_output(Kitty)
  assert_true(rendered.has_prefix("\u001b_Ga=T,f=24,s="))
  assert_true(rendered.length() > 64)
}

///|
test "fixed article fixture renders kitty graphics output" {
  let browser = Browser::new(1440, 960)
  load_fixture(browser, docs_article_fixture())
  let rendered = browser.render_output(Kitty)
  assert_true(rendered.has_prefix("\u001b_Ga=T,f=24,s="))
  assert_true(rendered.length() > 64)
}

///|
async test "builtin github snapshot fixture can stream kitty output to writer" {
  let browser = Browser::new(1440, 960)
  load_fixture(browser, builtin_github_snapshot_fixture())
  let expected = browser.render_output(Kitty)
  let (reader, writer) = @pipe.pipe()
  defer reader.close()
  browser.write_output(Kitty, writer)
  writer.close()
  let streamed = reader.read_all().text()
  assert_eq(streamed, expected)
}

///|
async test "fixture form submit navigates on focused button activation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <button id="btn" type="submit" style="display:block;width:96px;height:32px">Go</button>
    #|  </form>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let activated = browser.activate_focused_link() catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "fixture submit preventDefault repaints without navigation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%3Enavigated%3C/p%3E" method="get">
    #|    <button id="btn" type="submit" style="display:block;width:96px;height:32px">Go</button>
    #|  </form>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('form').addEventListener('submit', function (event) {
    #|      event.preventDefault();
    #|      document.getElementById('status').textContent = 'after';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))
  browser.next_link()
  let activated = browser.activate_focused_link() catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content="")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(not(rendered.contains("before")))
}

///|
async test "fixture focused text input Enter submits form" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  </form>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }
  let handled = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(handled, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "fixture focused checkbox Space toggles and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="check" type="checkbox" style="display:block;width:24px;height:24px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('check').addEventListener('change', function (event) {
    #|      document.getElementById('status').textContent = event.target.checked ? 'checked' : 'unchecked';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let handled = browser.handle_focused_key(" ") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("checked"))
}

///|
async test "fixture focused select ArrowDown changes selection and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <select id="sel" style="display:block;width:120px;height:32px">
    #|    <option value="a">A</option>
    #|    <option value="b">B</option>
    #|  </select>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('sel').addEventListener('change', function (event) {
    #|      document.getElementById('status').textContent = event.target.value;
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let handled = browser.handle_focused_key("ArrowDown") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("b"))
  assert_true(not(rendered.contains("before")))
}

///|
async test "fixture focused summary Enter toggles details and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <details id="det">
    #|    <summary id="sum" style="display:block;width:120px;height:32px">More</summary>
    #|    <p>Body</p>
    #|  </details>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let before = browser.render_output(Text)
  assert_true(not(before.contains("Body")))
  browser.next_link()
  let handled = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("Body"))
}
