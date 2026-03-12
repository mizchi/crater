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
async test "fixture focused textarea Enter inserts newline without submit" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <textarea id="field" style="display:block;width:160px;height:64px"></textarea>
    #|    <p id="status">before</p>
    #|  </form>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
    #|      document.getElementById('status').textContent = JSON.stringify(event.target.value);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let handled = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(handled, content="true")
  inspect(browser.get_current_url(), content="")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("\"\\n\""))
  assert_true(not(rendered.contains("done")))
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
async test "fixture Tab blur/focus dispatches change blur and focus repaint" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('change', function (event) {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'change:' + event.target.value : current + '|change:' + event.target.value;
    #|    });
    #|    document.getElementById('field').addEventListener('blur', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'blur' : current + '|blur';
    #|    });
    #|    document.getElementById('btn').addEventListener('focus', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'focus' : current + '|focus';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }
  browser.next_link()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("change:x|blur|focus"))
}

///|
async test "fixture Tab blur/focus does not dispatch change for untouched text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="seed" style="display:block;width:120px;height:32px" />
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('change', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'change' : current + '|change';
    #|    });
    #|    document.getElementById('field').addEventListener('blur', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'blur' : current + '|blur';
    #|    });
    #|    document.getElementById('btn').addEventListener('focus', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'focus' : current + '|focus';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  browser.next_link()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("blur|focus"))
  assert_true(not(rendered.contains("change")))
}

///|
async test "fixture click blur/focus dispatches change blur and focus repaint" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('change', function (event) {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'change:' + event.target.value : current + '|change:' + event.target.value;
    #|    });
    #|    document.getElementById('field').addEventListener('blur', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'blur' : current + '|blur';
    #|    });
    #|    document.getElementById('btn').addEventListener('focus', function () {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      status.textContent = current === 'before' ? 'focus' : current + '|focus';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }
  browser.build_accessibility_tree()
  let (col, row) = match browser.a11y_tree {
    Some(tree) =>
      match tree.find_by_source_id("btn") {
        Some(node) =>
          match node.bounds {
            Some(bounds) =>
              (
                @tui.px_to_col(bounds.x + bounds.width / 2.0),
                @tui.px_to_row(bounds.y + bounds.height / 2.0) + 1,
              )
            None => panic()
          }
        None => panic()
      }
    None => panic()
  }
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("change:x|blur|focus"))
}

///|
async test "fixture focused radio Space updates exclusive selection" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="a" name="group" type="radio" checked style="display:block;width:24px;height:24px" />
    #|  <input id="b" name="group" type="radio" style="display:block;width:24px;height:24px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('b').addEventListener('change', function () {
    #|      document.getElementById('status').textContent = String(document.getElementById('a').checked) + '|' + String(document.getElementById('b').checked);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  browser.next_link()
  let handled = browser.handle_focused_key(" ") catch { _ => false }
  inspect(handled, content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("false|true"))
}

///|
async test "fixture reset button restores initial control values" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form>
    #|    <input id="field" type="text" value="seed" style="display:block;width:120px;height:32px" />
    #|    <input id="check" type="checkbox" checked style="display:block;width:24px;height:24px" />
    #|    <button id="reset" type="reset" style="display:block;width:96px;height:32px">Reset</button>
    #|    <p id="status">before</p>
    #|  </form>
    #|  <script>
    #|    function render() {
    #|      const field = document.getElementById('field');
    #|      const check = document.getElementById('check');
    #|      document.getElementById('status').textContent = field.value + '|' + String(check.checked);
    #|    }
    #|    document.getElementById('field').addEventListener('input', render);
    #|    document.getElementById('check').addEventListener('change', render);
    #|    document.querySelector('form').addEventListener('reset', function () {
    #|      setTimeout(render, 0);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }
  browser.next_link()
  let _ = browser.handle_focused_key(" ") catch { _ => false }
  browser.build_accessibility_tree()
  let (col, row) = match browser.a11y_tree {
    Some(tree) =>
      match tree.find_by_source_id("reset") {
        Some(node) =>
          match node.bounds {
            Some(bounds) =>
              (
                @tui.px_to_col(bounds.x + bounds.width / 2.0),
                @tui.px_to_row(bounds.y + bounds.height / 2.0) + 1,
              )
            None => panic()
          }
        None => panic()
      }
    None => panic()
  }
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  for i = 0; i < 4; i = i + 1 {
    let _ = browser.tick_js()
  }
  let state = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); const check=document.getElementById('check'); return field.value + '|' + String(check.checked); })()",
  )
  inspect(state, content="Some(\"seed|true\")")
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
async test "fixture focused reset input Space restores initial values" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form>
    #|    <input id="field" type="text" value="seed" style="display:block;width:120px;height:32px" />
    #|    <input id="reset" type="reset" value="Reset" style="display:block;width:96px;height:32px" />
    #|    <p id="status">before</p>
    #|  </form>
    #|  <script>
    #|    function render() {
    #|      document.getElementById('status').textContent = document.getElementById('field').value;
    #|    }
    #|    document.getElementById('field').addEventListener('input', render);
    #|    document.querySelector('form').addEventListener('reset', function () {
    #|      setTimeout(render, 0);
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }
  browser.next_link()
  let handled = browser.handle_focused_key(" ") catch { _ => false }
  inspect(handled, content="true")
  for _ in 0..<4 {
    let _ = browser.tick_js()
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("seed"))
}

///|
async test "fixture focused submit input Space submits form" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%3Esubmitted-input%3C/p%3E" method="get">
    #|    <input id="submit" type="submit" value="Go" style="display:block;width:96px;height:32px" />
    #|  </form>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let handled = browser.handle_focused_key(" ") catch { _ => false }
  inspect(handled, content="true")
  assert_true(browser.html_content.contains("submitted-input"))
}

///|
async test "fixture focused input button Space dispatches click repaint" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="btn" type="button" value="Go" style="display:block;width:96px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('btn').addEventListener('click', function () {
    #|      document.getElementById('status').textContent = 'after';
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
  assert_true(rendered.contains("after"))
}

///|
async test "fixture select blur does not duplicate change repaint" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <select id="sel" style="display:block;width:120px;height:32px">
    #|    <option value="a">A</option>
    #|    <option value="b">B</option>
    #|  </select>
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('sel').addEventListener('change', function (event) {
    #|      const status = document.getElementById('status');
    #|      const current = status.textContent || '';
    #|      const next = 'change:' + event.target.value;
    #|      status.textContent = current === 'before' ? next : current + '|' + next;
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  load_fixture(browser, html)
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("ArrowDown") catch { _ => false }
  browser.next_link()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("change:b"))
  assert_true(not(rendered.contains("change:b|change:b")))
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
