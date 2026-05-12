///|
/// Browser JS focused form control and keyboard interaction regression tests.

///|
async test "Browser handle_focused_key dispatches change event for focused text input on Enter" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    const field = document.getElementById('field');
    #|    field.addEventListener('change', function (event) {
    #|      document.getElementById('status').textContent = 'change:' + event.target.value;
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }

  let handled = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(handled, content="true")

  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  debug_inspect(status, content="Some(\"change:x\")")
}

///|
async test "Browser handle_focused_key replaces selected text in focused textarea" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <textarea id="field" style="display:block;width:160px;height:64px">abcd</textarea>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=1; field.selectionEnd=3; return 'ok'; })()",
  )

  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"axd|2|2\")",
  )
}

///|
async test "Browser activate_at moves caret in focused text input before typing" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let region = hit_region_of_source_id(browser, "field")

  let activated = browser.activate_at(region.col, region.row) catch {
    _ => false
  }
  inspect(activated, content="true")
  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"xabcd|1|1\")",
  )
}

///|
async test "Browser pointer drag selects text in focused input before typing" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let region = hit_region_of_source_id(browser, "field")

  inspect(browser.pointer_down_at(region.col + 1, region.row), content="true")
  inspect(browser.pointer_move_at(region.col + 3, region.row), content="true")
  let _ = browser.pointer_up_at(region.col + 3, region.row) catch { _ => false }
  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"axd|2|2\")",
  )
}

///|
async test "Browser activate_at moves caret in focused textarea before typing" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <textarea id="field" style="display:block;width:160px;height:64px">ab
    #|cd</textarea>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  let region = hit_region_of_source_id(browser, "field")

  let activated = browser.activate_at(region.col + 1, region.row + 1) catch {
    _ => false
  }
  inspect(activated, content="true")
  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"ab\\ncxd|5|5\")",
  )
}

///|
async test "Browser handle_focused_key deletes text after caret in focused textarea" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <textarea id="field" style="display:block;width:160px;height:64px">abc</textarea>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=1; field.selectionEnd=1; return 'ok'; })()",
  )

  let handled = browser.handle_focused_key("Delete") catch { _ => false }
  inspect(handled, content="true")
  debug_inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"ac|1|1\")",
  )
}

///|
async test "Browser handle_focused_key toggles focused checkbox with Space" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="check" type="checkbox" style="display:block;width:24px;height:24px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    const check = document.getElementById('check');
    #|    check.addEventListener('change', function (event) {
    #|      document.getElementById('status').textContent = event.target.checked ? 'checked' : 'unchecked';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
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
async test "Browser handle_focused_key toggles focused radio with Space" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="a" name="group" type="radio" checked style="display:block;width:24px;height:24px" />
    #|  <input id="b" name="group" type="radio" style="display:block;width:24px;height:24px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    const radio = document.getElementById('b');
    #|    radio.addEventListener('change', function (event) {
    #|      document.getElementById('status').textContent = event.target.checked ? 'radio-b' : 'radio-none';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  browser.next_link()

  let handled = browser.handle_focused_key(" ") catch { _ => false }
  inspect(handled, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("radio-b"))
}

///|
async test "Browser handle_focused_key activates focused button with Space" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('btn').addEventListener('click', function () {
    #|      document.getElementById('status').textContent = 'after';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
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
async test "Browser handle_focused_key changes focused select with ArrowDown" {
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
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()

  let handled = browser.handle_focused_key("ArrowDown") catch { _ => false }
  inspect(handled, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("b"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser focus transition dispatches change blur and focus" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <div id="log"></div>
    #|  <script>
    #|    const field = document.getElementById('field');
    #|    const btn = document.getElementById('btn');
    #|    field.addEventListener('change', function (event) {
    #|      const log = document.getElementById('log');
    #|      const current = log.textContent || '';
    #|      log.textContent = current ? current + '|change:' + event.target.value : 'change:' + event.target.value;
    #|    });
    #|    field.addEventListener('blur', function () {
    #|      const log = document.getElementById('log');
    #|      const current = log.textContent || '';
    #|      log.textContent = current ? current + '|blur' : 'blur';
    #|    });
    #|    field.addEventListener('focusout', function () {
    #|      const log = document.getElementById('log');
    #|      const current = log.textContent || '';
    #|      log.textContent = current ? current + '|focusout' : 'focusout';
    #|    });
    #|    btn.addEventListener('focus', function () {
    #|      const log = document.getElementById('log');
    #|      const current = log.textContent || '';
    #|      log.textContent = current ? current + '|focus' : 'focus';
    #|    });
    #|    btn.addEventListener('focusin', function () {
    #|      const log = document.getElementById('log');
    #|      const current = log.textContent || '';
    #|      log.textContent = current ? current + '|focusin' : 'focusin';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let _ = browser.handle_focused_key("x") catch { _ => false }
  let before_focus = browser.get_focused_source_id()
  assert_true(
    match before_focus {
      Some(_) => true
      None => false
    },
  )
  let persisted = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); const btn=document.getElementById('btn'); return [String(!!(field&&field.getAttribute('data-crater-listeners-change'))), String(!!(field&&field.getAttribute('data-crater-listeners-blur'))), String(!!(field&&field.getAttribute('data-crater-listeners-focusout'))), String(!!(btn&&btn.getAttribute('data-crater-listeners-focus'))), String(!!(btn&&btn.getAttribute('data-crater-listeners-focusin')))].join('|'); })()",
  )
  debug_inspect(persisted, content="Some(\"true|true|true|true|true\")")
  browser.next_link()
  let after_focus = browser.get_focused_source_id()
  assert_true(
    match after_focus {
      Some(_) => true
      None => false
    },
  )
  assert_true(after_focus != before_focus)

  let log = browser.execute_inline_js(
    "(function(){ return document.getElementById('log').textContent; })()",
  )
  debug_inspect(log, content="Some(\"change:x|blur|focusout|focus|focusin\")")
}

///|
async test "Browser handle_focused_key activates focused reset input with Space" {
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
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
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
  let state = browser.execute_inline_js(
    "(function(){ return document.getElementById('field').value; })()",
  )
  debug_inspect(state, content="Some(\"seed\")")
}

///|
async test "Browser handle_focused_key submits focused submit input form" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%3Esubmitted-input%3C/p%3E" method="get">
    #|    <input id="submit" type="submit" value="Go" style="display:block;width:96px;height:32px" />
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()
  let handled = browser.handle_focused_key(" ") catch { _ => false }
  inspect(handled, content="true")
  assert_true(browser.html_content.contains("submitted-input"))
}

///|
async test "Browser handle_focused_key activates focused input button with Space" {
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
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
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
async test "Browser activate_at dispatches change blur and focus when click moves focus" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <div id="log"></div>
    #|  <script>
    #|    document.getElementById('field').addEventListener('change', function (event) {
    #|      const log = document.getElementById('log');
    #|      const current = log.textContent || '';
    #|      log.textContent = current ? current + '|change:' + event.target.value : 'change:' + event.target.value;
    #|    });
    #|    document.getElementById('field').addEventListener('blur', function () {
    #|      const log = document.getElementById('log');
    #|      const current = log.textContent || '';
    #|      log.textContent = current ? current + '|blur' : 'blur';
    #|    });
    #|    document.getElementById('btn').addEventListener('focus', function () {
    #|      const log = document.getElementById('log');
    #|      const current = log.textContent || '';
    #|      log.textContent = current ? current + '|focus' : 'focus';
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
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
  let log = browser.execute_inline_js(
    "(function(){ return document.getElementById('log').textContent; })()",
  )
  debug_inspect(log, content="Some(\"change:x|blur|focus\")")
}

///|
async test "Browser focus transition does not duplicate select change on blur" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <select id="sel" style="display:block;width:120px;height:32px">
    #|    <option value="a">A</option>
    #|    <option value="b">B</option>
    #|  </select>
    #|  <button id="btn" style="display:block;width:96px;height:32px">Go</button>
    #|  <div id="log"></div>
    #|  <script>
    #|    document.getElementById('sel').addEventListener('change', function (event) {
    #|      const log = document.getElementById('log');
    #|      const current = log.textContent || '';
    #|      const next = 'change:' + event.target.value;
    #|      log.textContent = current ? current + '|' + next : next;
    #|    });
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.focus_source_id("sel")
  let _ = browser.handle_focused_key("ArrowDown") catch { _ => false }
  browser.focus_source_id("btn")
  let log = browser.execute_inline_js(
    "(function(){ return document.getElementById('log').textContent; })()",
  )
  debug_inspect(log, content="Some(\"change:b\")")
}

///|
async test "Browser handle_focused_key toggles details via focused summary" {
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
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()

  let handled = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(handled, content="true")
  let open = browser.execute_inline_js(
    "(function(){ return String(document.getElementById('det').hasAttribute('open')); })()",
  )
  debug_inspect(open, content="Some(\"true\")")
}

///|
async test "Browser handle_focused_key inserts newline for focused textarea on Enter" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%3Esubmitted%3C/p%3E" method="get">
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
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)
  browser.next_link()

  let handled = browser.handle_focused_key("Enter") catch { _ => false }
  inspect(handled, content="true")
  inspect(browser.get_current_url(), content="")
  let value = browser.execute_inline_js(
    "(function(){ return JSON.stringify(document.getElementById('field').value); })()",
  )
  debug_inspect(value, content="Some(\"\\\"\\\\n\\\"\")")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  debug_inspect(status, content="Some(\"\\\"\\\\n\\\"\")")
}

///|
async test "Browser activate_at resets form controls for reset button" {
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
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
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
  let _ = browser.tick_js()
  let state = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); const check=document.getElementById('check'); return field.value + '|' + String(check.checked); })()",
  )
  debug_inspect(state, content="Some(\"seed|true\")")
}
