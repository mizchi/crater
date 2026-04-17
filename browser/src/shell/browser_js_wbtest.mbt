///|
/// Tests for Browser JS integration

///|
test "Browser getter API returns initial state" {
  let browser = Browser::new(800, 600)
  inspect(browser.get_current_url(), content="")
  inspect(browser.get_viewport_height(), content="600")
  inspect(browser.get_link_count(), content="0")
  inspect(browser.get_focused_link_index(), content="0")
  inspect(browser.is_hint_mode(), content="false")
}

///|
test "Browser render_output returns defaults when content is empty" {
  let browser = Browser::new(800, 600)
  inspect(browser.render_output(Text), content="")
  inspect(browser.render_output(Sixel), content="")
  inspect(browser.render_output(Kitty), content="")
  inspect(browser.render_output(Json), content="{}")
  inspect(browser.render_output(Aom), content="")
  inspect(
    browser.render_output(Arc90),
    content="No accessibility tree available.",
  )
  inspect(
    browser.render_output(ExtractMain),
    content="No accessibility tree available.",
  )
  inspect(
    browser.render_output(Grounding),
    content="No accessibility tree available.",
  )
}

///|
fn hit_region_of_source_id(
  browser : Browser,
  source_id : String,
) -> @tui.HitRegion {
  for region in browser.hit_regions {
    if region.source_id == source_id {
      return region
    }
  }
  panic()
}

///|
test "extract_scripts extracts inline script" {
  let html =
    #|<html>
    #|<head>
    #|<script>console.log('hello');</script>
    #|</head>
    #|<body></body>
    #|</html>
  let scripts = extract_scripts(html)
  inspect(scripts.length(), content="1")
  inspect(scripts[0].source, content="console.log('hello');")
  inspect(scripts[0].src, content="")
  inspect(scripts[0].is_async, content="false")
  inspect(scripts[0].is_defer, content="false")
}

///|
test "extract_scripts extracts external script" {
  let html =
    #|<html>
    #|<head>
    #|<script src="app.js"></script>
    #|</head>
    #|<body></body>
    #|</html>
  let scripts = extract_scripts(html)
  inspect(scripts.length(), content="1")
  inspect(scripts[0].source, content="")
  inspect(scripts[0].src, content="app.js")
}

///|
test "extract_scripts detects async and defer" {
  let html =
    #|<html>
    #|<script async src="a.js"></script>
    #|<script defer src="b.js"></script>
    #|</html>
  let scripts = extract_scripts(html)
  inspect(scripts.length(), content="2")
  inspect(scripts[0].is_async, content="true")
  inspect(scripts[0].is_defer, content="false")
  inspect(scripts[1].is_async, content="false")
  inspect(scripts[1].is_defer, content="true")
}

///|
test "extract_scripts handles multiple scripts" {
  let html =
    #|<html>
    #|<script>var a = 1;</script>
    #|<script>var b = 2;</script>
    #|</html>
  let scripts = extract_scripts(html)
  inspect(scripts.length(), content="2")
  inspect(scripts[0].source, content="var a = 1;")
  inspect(scripts[1].source, content="var b = 2;")
}

///|
test "Browser init_js_execution creates DOM tree" {
  let browser = Browser::new(800, 600)
  browser.init_js_execution()
  // DOM tree should be created
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      // Check body exists
      match dom.query_selector(doc, "body") {
        Ok(Some(_)) => () // Success
        _ => assert_true(false) // Body should exist
      }
    }
    None => assert_true(false) // DOM tree should exist
  }
  // Script executor should be created
  match browser.script_executor {
    Some(_) => ()
    None => assert_true(false)
  }
}

///|
test "Browser execute_scripts runs inline scripts" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|<script>
    #|  const div = document.createElement('div');
    #|  div.setAttribute('id', 'from-script');
    #|  document.body.appendChild(div);
    #|</script>
    #|</head>
    #|<body></body>
    #|</html>
  browser.html_content = html
  browser.set_enable_js(true)
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  // Verify DOM was modified
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#from-script") {
        Ok(Some(_)) => () // Element created by script exists
        _ => assert_true(false) // Element should exist
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser execute_scripts runs multiple scripts in order" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|<script>
    #|  const div1 = document.createElement('div');
    #|  div1.setAttribute('id', 'first');
    #|  document.body.appendChild(div1);
    #|</script>
    #|<script>
    #|  const div2 = document.createElement('div');
    #|  div2.setAttribute('id', 'second');
    #|  document.body.appendChild(div2);
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.set_enable_js(true)
  let executed = browser.execute_scripts()
  inspect(executed, content="2")
  // Verify both elements exist
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#first") {
        Ok(Some(_)) => ()
        _ => assert_true(false)
      }
      match dom.query_selector(doc, "#second") {
        Ok(Some(_)) => ()
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser execute_scripts modifies attributes" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|<script>
    #|  document.body.setAttribute('data-loaded', 'true');
    #|  document.body.setAttribute('class', 'initialized');
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.set_enable_js(true)
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  // Verify attributes were set
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "body") {
        Ok(Some(body)) => {
          match dom.get_attribute(body, "data-loaded") {
            Ok(Some(value)) => inspect(value, content="true")
            _ => assert_true(false)
          }
          match dom.get_attribute(body, "class") {
            Ok(Some(value)) => inspect(value, content="initialized")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser execute_scripts handles no scripts" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|<p>No scripts here</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.set_enable_js(true)
  let executed = browser.execute_scripts()
  inspect(executed, content="0")
}

///|
test "Browser execute_scripts skips external scripts" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|<script src="external.js"></script>
    #|</head>
    #|<body>
    #|<script>
    #|  document.body.setAttribute('data-inline', 'executed');
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.set_enable_js(true)
  let executed = browser.execute_scripts()
  // Only inline script should execute (external is skipped)
  inspect(executed, content="1")
  // Verify inline script ran
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "body") {
        Ok(Some(body)) =>
          match dom.get_attribute(body, "data-inline") {
            Ok(Some(value)) => inspect(value, content="executed")
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser execute_scripts uses getElementById within single script" {
  let browser = Browser::new(800, 600)
  // getElementById works within a single script execution
  // because the mock DOM tracks elements created in that execution
  let html =
    #|<html>
    #|<body>
    #|<script>
    #|  const div = document.createElement('div');
    #|  div.setAttribute('id', 'target');
    #|  document.body.appendChild(div);
    #|  // getElementById works in same script
    #|  const target = document.getElementById('target');
    #|  if (target) {
    #|    target.setAttribute('data-found', 'yes');
    #|  }
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.set_enable_js(true)
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  // Verify getElementById worked within the script
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#target") {
        Ok(Some(target)) =>
          match dom.get_attribute(target, "data-found") {
            Ok(Some(value)) => inspect(value, content="yes")
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser scheduler integration queues tasks correctly" {
  let browser = Browser::new(800, 600)
  // Verify scheduler starts empty
  let initial_tasks = browser.scheduler.poll_ready()
  inspect(initial_tasks.length(), content="0")
  // Set HTML content with script
  let html =
    #|<html>
    #|<script>console.log('test');</script>
    #|</html>
  browser.html_content = html
  browser.set_enable_js(true)
  // Execute scripts (this queues and processes tasks)
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  // After execution, scheduler should have processed the task
  let remaining = browser.scheduler.poll_ready()
  inspect(remaining.length(), content="0")
}

///|
test "extract_scripts handles mixed inline and external scripts" {
  let html =
    #|<html>
    #|<head>
    #|<script src="lib.js"></script>
    #|<script>var x = 1;</script>
    #|<script src="app.js" async></script>
    #|<script defer>var y = 2;</script>
    #|</head>
    #|</html>
  let scripts = extract_scripts(html)
  inspect(scripts.length(), content="4")
  // First: external lib.js
  inspect(scripts[0].src, content="lib.js")
  inspect(scripts[0].source, content="")
  inspect(scripts[0].is_async, content="false")
  // Second: inline
  inspect(scripts[1].src, content="")
  inspect(scripts[1].source, content="var x = 1;")
  // Third: external async
  inspect(scripts[2].src, content="app.js")
  inspect(scripts[2].is_async, content="true")
  // Fourth: inline defer
  inspect(scripts[3].source, content="var y = 2;")
  inspect(scripts[3].is_defer, content="true")
}

///|
test "resolve_url resolves script paths correctly" {
  // Absolute URL
  let abs = resolve_url("https://example.com/page", "https://cdn.com/lib.js")
  inspect(abs, content="https://cdn.com/lib.js")
  // Root-relative
  let root = resolve_url("https://example.com/dir/page", "/scripts/app.js")
  inspect(root, content="https://example.com/scripts/app.js")
  // Relative
  let rel = resolve_url("https://example.com/dir/page.html", "lib.js")
  inspect(rel, content="https://example.com/dir/lib.js")
  // Protocol-relative
  let proto = resolve_url("https://example.com/page", "//cdn.com/lib.js")
  inspect(proto, content="https://cdn.com/lib.js")
  // Data URL
  let data = resolve_url(
    "https://example.com/page", "data:text/html,%3Cp%3Eok%3C/p%3E",
  )
  inspect(data, content="data:text/html,%3Cp%3Eok%3C/p%3E")
}

///|
test "WPT-style: createElement and appendChild" {
  // This test mimics WPT DOM test patterns
  let browser = Browser::new(800, 600)
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<body>
    #|<script>
    #|  // Test 1: createElement
    #|  const div = document.createElement('div');
    #|  div.setAttribute('id', 'test-div');
    #|  div.setAttribute('data-test', 'passed');
    #|
    #|  // Test 2: appendChild
    #|  document.body.appendChild(div);
    #|
    #|  // Test 3: createElement with nested structure
    #|  const container = document.createElement('div');
    #|  container.setAttribute('id', 'container');
    #|  const child = document.createElement('span');
    #|  child.setAttribute('id', 'child');
    #|  child.setAttribute('class', 'test-class');
    #|  container.appendChild(child);
    #|  document.body.appendChild(container);
    #|
    #|  // Test 4: getElementById and modify
    #|  const found = document.getElementById('test-div');
    #|  if (found) {
    #|    found.setAttribute('data-found', 'true');
    #|  }
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.set_enable_js(true)
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  // Verify WPT-style assertions
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      // Assert: div was created and appended
      match dom.query_selector(doc, "#test-div") {
        Ok(Some(el)) => {
          match dom.get_attribute(el, "data-test") {
            Ok(Some(v)) => inspect(v, content="passed")
            _ => assert_true(false)
          }
          // Assert: getElementById worked
          match dom.get_attribute(el, "data-found") {
            Ok(Some(v)) => inspect(v, content="true")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
      // Assert: nested structure
      match dom.query_selector(doc, "#container") {
        Ok(Some(_)) => ()
        _ => assert_true(false)
      }
      match dom.query_selector(doc, "#child") {
        Ok(Some(child)) =>
          match dom.get_attribute(child, "class") {
            Ok(Some(v)) => inspect(v, content="test-class")
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "WPT-style: setAttribute and getAttribute" {
  let browser = Browser::new(800, 600)
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<body>
    #|<script>
    #|  const el = document.createElement('div');
    #|  el.setAttribute('id', 'attr-test');
    #|
    #|  // Set various attributes
    #|  el.setAttribute('data-string', 'hello');
    #|  el.setAttribute('data-number', '42');
    #|  el.setAttribute('data-empty', '');
    #|  el.setAttribute('class', 'foo bar');
    #|  el.setAttribute('title', 'Test Title');
    #|
    #|  // Override attribute
    #|  el.setAttribute('data-string', 'world');
    #|
    #|  document.body.appendChild(el);
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#attr-test") {
        Ok(Some(el)) => {
          // Verify overwritten attribute
          match dom.get_attribute(el, "data-string") {
            Ok(Some(v)) => inspect(v, content="world")
            _ => assert_true(false)
          }
          // Verify other attributes
          match dom.get_attribute(el, "data-number") {
            Ok(Some(v)) => inspect(v, content="42")
            _ => assert_true(false)
          }
          match dom.get_attribute(el, "class") {
            Ok(Some(v)) => inspect(v, content="foo bar")
            _ => assert_true(false)
          }
          match dom.get_attribute(el, "title") {
            Ok(Some(v)) => inspect(v, content="Test Title")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser DOM tree persists across script executions" {
  let browser = Browser::new(800, 600)
  // First execution creates element
  let html1 =
    #|<html>
    #|<script>
    #|  const div = document.createElement('div');
    #|  div.setAttribute('id', 'persistent');
    #|  div.setAttribute('data-initial', 'set');
    #|  document.body.appendChild(div);
    #|</script>
    #|</html>
  browser.html_content = html1
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  // Verify element was created in real DOM tree
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#persistent") {
        Ok(Some(el)) =>
          match dom.get_attribute(el, "data-initial") {
            Ok(Some(value)) => inspect(value, content="set")
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
  // Second execution - element still exists in real DOM
  // (Note: getElementById across executions requires DOM sync, not yet implemented)
  let html2 =
    #|<html>
    #|<script>
    #|  const newDiv = document.createElement('div');
    #|  newDiv.setAttribute('id', 'second');
    #|  document.body.appendChild(newDiv);
    #|</script>
    #|</html>
  browser.html_content = html2
  let _ = browser.execute_scripts()
  // Verify both elements exist in real DOM
  match browser.dom_tree {
    Some(dom) => {
      let doc = dom.get_document()
      // First element still exists
      match dom.query_selector(doc, "#persistent") {
        Ok(Some(_)) => ()
        _ => assert_true(false)
      }
      // Second element was added
      match dom.query_selector(doc, "#second") {
        Ok(Some(_)) => ()
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "Browser apply JS DOM changes to TUI render output" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|<p id="greet">before</p>
    #|<script>
    #|  const el = document.getElementById('greet');
    #|  if (el) {
    #|    el.textContent = 'after';
    #|  }
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
test "Browser syncs JS DOM mutations into html_content and link cache" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|<a id="target" href="/before">before</a>
    #|<script>
    #|  const el = document.getElementById('target');
    #|  if (el) {
    #|    el.setAttribute('href', '/after');
    #|    el.textContent = 'after';
    #|  }
    #|</script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()

  // HTML source used by renderer is synchronized from mutated DomTree
  assert_true(browser.html_content.contains("href=\"/after\""))
  assert_true(browser.html_content.contains(">after</a>"))
  assert_true(!browser.html_content.contains("href=\"/before\""))

  // Link cache should also be rebuilt from synchronized HTML
  inspect(browser.get_link_count(), content="1")
  inspect(browser.links[0].href, content="/after")
  inspect(browser.links[0].text, content="after")
}

///|
test "Browser tick_js applies queued JS tasks to render output" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|<p id="greet">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  browser.init_js_execution()
  let script =
    #|const el = document.getElementById('greet');
    #|if (el) el.textContent = 'after';
  let _ = @js.enqueue_script(browser.scheduler, script, true)

  inspect(browser.tick_js(), content="true")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_focused_link dispatches onclick and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|  <p id="status">before</p>
    #|  <a href="/next" onclick="document.getElementById('status').textContent='after'; event.preventDefault();">Go</a>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  browser.next_link()
  let activated = browser.activate_focused_link() catch { _ => false }
  inspect(activated, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at dispatches button onclick and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; }
    #|    button { display: block; width: 96px; height: 32px; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <button id="btn" onclick="document.getElementById('status').textContent='after';">Go</button>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
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
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at dispatches generic onclick element and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; }
    #|    div#target { display: block; width: 120px; height: 40px; background: #ddd; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="target" onclick="document.getElementById('status').textContent='after';">Tap</div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))
  browser.build_accessibility_tree()
  let (col, row) = match browser.a11y_tree {
    Some(tree) =>
      match tree.find_by_source_id("target") {
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
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at flushes requestAnimationFrame mutation and repaints" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; }
    #|    button { display: block; width: 96px; height: 32px; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <button id="btn" onclick="requestAnimationFrame(() => { document.getElementById('status').textContent='after'; });">Go</button>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))
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
  assert_true(rendered.contains("before"))
  inspect(browser.tick_js(), content="true")
  let after_tick = browser.render_output(Text)
  assert_true(after_tick.contains("after"))
  assert_true(!after_tick.contains("before"))
}

///|
async test "Browser activate_at prefers topmost overlapping painted element" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 80px; background: #ccc; }
    #|    #top { position: absolute; left: 20px; top: 10px; width: 160px; height: 80px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <p id="status" style="margin-top: 100px">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let mut top_region : @tui.HitRegion? = None
  let mut bottom_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
    if region.source_id == "bottom" {
      bottom_region = Some(region)
    }
  }
  let (col, row) = match (top_region, bottom_region) {
    (Some(top), Some(bottom)) => {
      let overlap_left = top.col.max(bottom.col)
      let overlap_top = top.row.max(bottom.row)
      let overlap_right = (top.col + top.width).min(bottom.col + bottom.width)
      let overlap_bottom = (top.row + top.height).min(
        bottom.row + bottom.height,
      )
      assert_true(overlap_right > overlap_left)
      assert_true(overlap_bottom > overlap_top)
      (overlap_left, overlap_top)
    }
    _ => panic()
  }

  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("top"))
  assert_true(!rendered.contains("bottom"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at ignores clipped overflow area" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; }
    #|    #clip { position: relative; width: 80px; height: 32px; overflow: hidden; background: #ddd; }
    #|    #target { position: absolute; left: 48px; top: 0; width: 96px; height: 32px; background: #999; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="clip">
    #|    <div id="target" onclick="document.getElementById('status').textContent='after';"></div>
    #|  </div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))
  let mut target_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "target" {
      target_region = Some(region)
    }
  }
  let region = match target_region {
    Some(region) => region
    None => panic()
  }
  let hidden_col = region.col + region.width + 1
  let hidden_row = region.row

  let hidden_activated = browser.activate_at(hidden_col, hidden_row) catch {
    _ => false
  }
  inspect(hidden_activated, content="false")

  let after_hidden = browser.render_output(Text)
  assert_true(after_hidden.contains("before"))
  assert_true(!after_hidden.contains("after"))

  let visible_activated = browser.activate_at(region.col, region.row) catch {
    _ => false
  }
  inspect(visible_activated, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at prefers underlying element outside clipped overlap" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 32px; background: #ccc; }
    #|    #clip { position: absolute; left: 0; top: 0; width: 80px; height: 32px; overflow: hidden; }
    #|    #top { position: absolute; left: 48px; top: 0; width: 96px; height: 32px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="clip">
    #|    <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  </div>
    #|  <div style="height: 48px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let mut top_region : @tui.HitRegion? = None
  let mut bottom_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
    if region.source_id == "bottom" {
      bottom_region = Some(region)
    }
  }
  let (col, row) = match (top_region, bottom_region) {
    (Some(top), Some(bottom)) => {
      let hidden_left = top.col + top.width
      let hidden_right = bottom.col + bottom.width
      assert_true(hidden_right > hidden_left)
      (hidden_left, bottom.row.max(top.row))
    }
    _ => panic()
  }

  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  inspect(activated, content="true")

  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at skips pointer_events_none overlay" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #999; pointer-events: none; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(browser.get_source_id_at(1, 1), content="Some(\"bottom\")")
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at respects inherited pointer_events_none" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #wrapper { pointer-events: none; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #child { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="wrapper">
    #|    <div id="child" onclick="document.getElementById('status').textContent='child';"></div>
    #|  </div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(browser.get_source_id_at(1, 1), content="Some(\"bottom\")")
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at allows child pointer_events_auto under inherited none" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #wrapper { pointer-events: none; position: absolute; left: 0; top: 0; }
    #|    #child { pointer-events: auto; position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="wrapper">
    #|    <div id="child" onclick="document.getElementById('status').textContent='child';"></div>
    #|  </div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(browser.get_source_id_at(1, 1), content="Some(\"child\")")
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"child\")")
}

///|
async test "Browser activate_at prefers transformed topmost element at visual position" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #999; z-index: 1; transform: translate(48px, 0); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 64px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let mut top_region : @tui.HitRegion? = None
  let mut bottom_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
    if region.source_id == "bottom" {
      bottom_region = Some(region)
    }
  }
  let (col, row) = match (top_region, bottom_region) {
    (Some(top), Some(bottom)) => {
      let overlap_left = top.col.max(bottom.col)
      let overlap_top = top.row.max(bottom.row)
      let overlap_right = (top.col + top.width).min(bottom.col + bottom.width)
      let overlap_bottom = (top.row + top.height).min(
        bottom.row + bottom.height,
      )
      assert_true(overlap_right > overlap_left)
      assert_true(overlap_bottom > overlap_top)
      (overlap_left, overlap_top)
    }
    _ => panic()
  }

  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at dispatches persisted addEventListener click handler" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <button id="btn">Go</button>
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
  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))

  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(activated, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at dispatches persisted generic addEventListener click handler" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="target" style="width:160px;height:48px;background:#999">Go</div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('target').addEventListener('click', function () {
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
  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))

  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(activated, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_at dispatches pointer and mouse events before click" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <button id="btn" style="position:absolute;left:80px;top:48px;display:block;width:96px;height:32px">Go</button>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const btn = document.getElementById('btn');
    #|    const status = document.getElementById('status');
    #|    const order = [];
    #|    for (const type of ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click']) {
    #|      btn.addEventListener(type, function (event) {
    #|        order.push(type + '@' + event.clientX + ',' + event.clientY);
    #|        status.textContent = order.join('|');
    #|      });
    #|    }
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
  let expected = "@" +
    (col * 8 + 4).to_string() +
    "," +
    (row * 16 + 8).to_string()
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")

  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(
    status,
    content="Some(\"pointerdown" +
      expected +
      "|mousedown" +
      expected +
      "|pointerup" +
      expected +
      "|mouseup" +
      expected +
      "|click" +
      expected +
      "\")",
  )
  let rendered = browser.render_output(Text)
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser hover_at dispatches pointer and mouse hover sequence" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="left" style="position:absolute;left:16px;top:16px;width:64px;height:32px;background:#ccc"></div>
    #|  <div id="right" style="position:absolute;left:112px;top:16px;width:64px;height:32px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    function bind(id) {
    #|      const el = document.getElementById(id);
    #|      for (const type of ['pointerover', 'mouseover', 'pointerenter', 'mouseenter', 'pointermove', 'mousemove', 'pointerout', 'mouseout', 'pointerleave', 'mouseleave']) {
    #|        el.addEventListener(type, function (event) {
    #|          events.push(id + ':' + type + ':' + (event.relatedTarget ? event.relatedTarget.id : 'none'));
    #|          status.textContent = events.join('|');
    #|        });
    #|      }
    #|    }
    #|    bind('left');
    #|    bind('right');
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
  let mut left_region : @tui.HitRegion? = None
  let mut right_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "left" {
      left_region = Some(region)
    }
    if region.source_id == "right" {
      right_region = Some(region)
    }
  }
  let (left_col, left_row, right_col, right_row) = match
    (left_region, right_region) {
    (Some(left), Some(right)) =>
      (
        left.col + left.width / 2,
        left.row + left.height / 2,
        right.col + right.width / 2,
        right.row + right.height / 2,
      )
    _ => panic()
  }
  inspect(browser.hover_at(left_col, left_row), content="true")
  inspect(browser.hover_at(right_col, right_row), content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"left:pointerover:none|left:mouseover:none|left:pointerenter:none|left:mouseenter:none|left:pointermove:none|left:mousemove:none|left:pointerout:right|left:mouseout:right|left:pointerleave:right|left:mouseleave:right|right:pointerover:left|right:mouseover:left|right:pointerenter:left|right:mouseenter:left|right:pointermove:left|right:mousemove:left\")",
  )
}

///|
async test "Browser pointer drag dispatches drag sequence between source and target" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    for (const type of ['dragstart', 'drag', 'dragend']) {
    #|      document.getElementById('source').addEventListener(type, function (event) {
    #|        events.push('source:' + type + '@' + event.clientX + ',' + event.clientY);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
    #|    for (const type of ['dragenter', 'dragover', 'drop']) {
    #|      document.getElementById('target').addEventListener(type, function (event) {
    #|        if (type === 'dragover') {
    #|          event.preventDefault();
    #|          event.dataTransfer.dropEffect = 'move';
    #|        }
    #|        events.push('target:' + type + '@' + event.clientX + ',' + event.clientY);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  let target_point = "@" +
    (target_col * 8 + 4).to_string() +
    "," +
    (target_row * 16 + 8).to_string()
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart" +
      target_point +
      "|source:drag" +
      target_point +
      "|target:dragenter" +
      target_point +
      "|target:dragover" +
      target_point +
      "|target:drop" +
      target_point +
      "|source:dragend" +
      target_point +
      "\")",
  )
}

///|
async test "Browser pointer drag preserves dataTransfer and switches drag targets" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="mid" style="position:absolute;left:120px;top:16px;width:72px;height:40px;background:#bbb"></div>
    #|  <div id="target" style="position:absolute;left:224px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    document.getElementById('source').addEventListener('dragstart', function (event) {
    #|      event.dataTransfer.setData('text/plain', 'payload');
    #|      event.dataTransfer.effectAllowed = 'copyMove';
    #|      events.push('source:dragstart:' + event.dataTransfer.getData('text/plain'));
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('drag', function (event) {
    #|      events.push('source:drag:' + event.dataTransfer.getData('text/plain'));
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('dragend', function (event) {
    #|      events.push('source:dragend:' + event.dataTransfer.getData('text/plain'));
    #|      status.textContent = events.join('|');
    #|    });
    #|    for (const [id, types] of [['mid', ['dragenter', 'dragover', 'dragleave']], ['target', ['dragenter', 'dragover', 'drop']]]) {
    #|      const el = document.getElementById(id);
    #|      for (const type of types) {
    #|        el.addEventListener(type, function (event) {
    #|          if (id === 'target' && type === 'dragover') {
    #|            event.preventDefault();
    #|            event.dataTransfer.dropEffect = 'move';
    #|          }
    #|          const rel = event.relatedTarget ? event.relatedTarget.id : 'none';
    #|          if (type === 'drop') {
    #|            events.push(id + ':' + type + ':' + rel + ':' + event.dataTransfer.effectAllowed + '/' + event.dataTransfer.dropEffect + ':' + event.dataTransfer.getData('text/plain'));
    #|          } else {
    #|            events.push(id + ':' + type + ':' + rel + ':' + event.dataTransfer.getData('text/plain'));
    #|          }
    #|          status.textContent = events.join('|');
    #|        });
    #|      }
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (mid_col, mid_row) = center_of_hit_source_id(browser, "mid")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(mid_col, mid_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart:payload|source:drag:payload|mid:dragenter:none:payload|mid:dragover:source:payload|source:drag:payload|mid:dragleave:target:payload|target:dragenter:mid:payload|target:dragover:source:payload|target:drop:source:copyMove/move:payload|source:dragend:payload\")",
  )
}

///|
async test "Browser pointer drag shares DataTransfer mutations through drop" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    document.getElementById('source').addEventListener('dragstart', function (event) {
    #|      event.dataTransfer.setData('text/plain', 'payload');
    #|      event.dataTransfer.setData('text/html', '<b>x</b>');
    #|      events.push('source:' + event.dataTransfer.types.join(','));
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('target').addEventListener('dragover', function (event) {
    #|      event.preventDefault();
    #|      event.dataTransfer.clearData('text/plain');
    #|      event.dataTransfer.dropEffect = 'copy';
    #|      events.push('target:dragover:' + event.dataTransfer.types.join(','));
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('target').addEventListener('drop', function (event) {
    #|      events.push(
    #|        'target:drop:' +
    #|        event.dataTransfer.types.join(',') +
    #|        ':' +
    #|        event.dataTransfer.getData('text/plain') +
    #|        ':' +
    #|        event.dataTransfer.getData('text/html')
    #|      );
    #|      status.textContent = events.join('|');
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:text/plain,text/html|target:dragover:text/html|target:drop:text/html::<b>x</b>\")",
  )
}

///|
async test "Browser pointer drag leaving targets dispatches dragleave without drop" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <div id="outside" style="position:absolute;left:320px;top:16px;width:96px;height:48px;background:#666"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    document.getElementById('source').addEventListener('dragstart', function (event) {
    #|      event.dataTransfer.setData('text/plain', 'payload');
    #|      events.push('source:dragstart');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('drag', function () {
    #|      events.push('source:drag');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('dragend', function () {
    #|      events.push('source:dragend');
    #|      status.textContent = events.join('|');
    #|    });
    #|    for (const type of ['dragenter', 'dragover', 'dragleave', 'drop']) {
    #|      document.getElementById('target').addEventListener(type, function () {
    #|        events.push('target:' + type);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  let (outside_col, outside_row) = center_of_hit_source_id(browser, "outside")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  inspect(browser.pointer_move_at(outside_col, outside_row), content="true")
  let released = browser.pointer_up_at(outside_col, outside_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart|source:drag|target:dragenter|target:dragover|source:drag|target:dragleave|source:dragend\")",
  )
}

///|
async test "Browser pointer drag does not drop without dragover preventDefault" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    for (const type of ['dragstart', 'drag', 'dragend']) {
    #|      document.getElementById('source').addEventListener(type, function () {
    #|        events.push('source:' + type);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
    #|    for (const type of ['dragenter', 'dragover', 'drop']) {
    #|      document.getElementById('target').addEventListener(type, function () {
    #|        events.push('target:' + type);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart|source:drag|target:dragenter|target:dragover|source:dragend\")",
  )
}

///|
async test "Browser pointer drag does not drop when effectAllowed is none" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    document.getElementById('source').addEventListener('dragstart', function (event) {
    #|      event.dataTransfer.effectAllowed = 'none';
    #|      events.push('source:dragstart');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('drag', function () {
    #|      events.push('source:drag');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('dragend', function (event) {
    #|      events.push('source:dragend:' + event.dataTransfer.effectAllowed + '/' + event.dataTransfer.dropEffect);
    #|      status.textContent = events.join('|');
    #|    });
    #|    for (const type of ['dragenter', 'dragover', 'drop']) {
    #|      document.getElementById('target').addEventListener(type, function (event) {
    #|        if (type === 'dragover') {
    #|          event.preventDefault();
    #|          event.dataTransfer.dropEffect = 'move';
    #|        }
    #|        events.push('target:' + type);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart|source:drag|target:dragenter|target:dragover|source:dragend:none/move\")",
  )
}

///|
async test "Browser pointer drag does not drop when dropEffect is incompatible with effectAllowed" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0;position:relative">
    #|  <div id="source" draggable="true" style="position:absolute;left:16px;top:16px;width:72px;height:40px;background:#ccc"></div>
    #|  <div id="target" style="position:absolute;left:144px;top:16px;width:96px;height:48px;background:#999"></div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const status = document.getElementById('status');
    #|    const events = [];
    #|    document.getElementById('source').addEventListener('dragstart', function (event) {
    #|      event.dataTransfer.effectAllowed = 'copy';
    #|      events.push('source:dragstart');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('drag', function () {
    #|      events.push('source:drag');
    #|      status.textContent = events.join('|');
    #|    });
    #|    document.getElementById('source').addEventListener('dragend', function (event) {
    #|      events.push('source:dragend:' + event.dataTransfer.effectAllowed + '/' + event.dataTransfer.dropEffect);
    #|      status.textContent = events.join('|');
    #|    });
    #|    for (const type of ['dragenter', 'dragover', 'drop']) {
    #|      document.getElementById('target').addEventListener(type, function (event) {
    #|        if (type === 'dragover') {
    #|          event.preventDefault();
    #|          event.dataTransfer.dropEffect = 'move';
    #|        }
    #|        events.push('target:' + type);
    #|        status.textContent = events.join('|');
    #|      });
    #|    }
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
  let (source_col, source_row) = center_of_hit_source_id(browser, "source")
  let (target_col, target_row) = center_of_hit_source_id(browser, "target")
  inspect(browser.pointer_down_at(source_col, source_row), content="true")
  inspect(browser.pointer_move_at(target_col, target_row), content="true")
  let released = browser.pointer_up_at(target_col, target_row) catch {
    _ => false
  }
  inspect(released, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"source:dragstart|source:drag|target:dragenter|target:dragover|source:dragend:copy/move\")",
  )
}

///|
async test "Browser activate_at prefers topmost persisted addEventListener element" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 24px; top: 8px; width: 160px; height: 64px; background: #999; z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top"></div>
    #|  <p id="status" style="margin-top: 96px">before</p>
    #|  <script>
    #|    document.getElementById('top').addEventListener('click', function () {
    #|      document.getElementById('status').textContent = 'top';
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
  let mut top_region : @tui.HitRegion? = None
  let mut bottom_region : @tui.HitRegion? = None
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
    if region.source_id == "bottom" {
      bottom_region = Some(region)
    }
  }
  let (col, row) = match (top_region, bottom_region) {
    (Some(top), Some(bottom)) => {
      let overlap_left = top.col.max(bottom.col)
      let overlap_top = top.row.max(bottom.row)
      let overlap_right = (top.col + top.width).min(bottom.col + bottom.width)
      let overlap_bottom = (top.row + top.height).min(
        bottom.row + bottom.height,
      )
      assert_true(overlap_right > overlap_left)
      assert_true(overlap_bottom > overlap_top)
      (overlap_left, overlap_top)
    }
    _ => panic()
  }

  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at submits GET form and navigates" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <button id="btn" type="submit" style="display:block;width:96px;height:32px">Go</button>
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

  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser activate_at submit preventDefault repaints without navigation" {
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
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let initial = browser.render_output(Text)
  assert_true(initial.contains("before"))

  let activated = browser.activate_at(1, 1) catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content="")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("after"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser activate_focused_link submits focused button form" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <button id="btn" type="submit" style="display:block;width:96px;height:32px">Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

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
async test "Browser activate_focused_link submits focused text input form" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input id="field" type="text" value="hello" style="display:block;width:120px;height:32px" />
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

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
async test "Browser handle_focused_key dispatches input event for focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('field').addEventListener('input', function (event) {
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

  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("x"))
  assert_true(!rendered.contains("before"))
}

///|
async test "Browser handle_focused_key dispatches beforeinput for focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
    #|  <script>
    #|    const field = document.getElementById('field');
    #|    field.addEventListener('beforeinput', function (event) {
    #|      document.getElementById('status').textContent = String(event.inputType || '') + ':' + String(event.data || '');
    #|      event.preventDefault();
    #|    });
    #|    field.addEventListener('input', function () {
    #|      const status = document.getElementById('status');
    #|      status.textContent = status.textContent + '|input';
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

  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('field').value; })()",
    ),
    content="Some(\"\")",
  )
  inspect(
    browser.execute_inline_js(
      "(function(){ return document.getElementById('status').textContent; })()",
    ),
    content="Some(\"insertText:x\")",
  )
}

///|
async test "Browser handle_focused_key inserts text at caret in focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="ab" style="display:block;width:120px;height:32px" />
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

  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"axb|2|2\")",
  )
}

///|
async test "Browser handle_focused_key deletes text before caret in focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abc" style="display:block;width:120px;height:32px" />
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
    "(function(){ const field=document.getElementById('field'); field.selectionStart=2; field.selectionEnd=2; return 'ok'; })()",
  )

  let handled = browser.handle_focused_key("Backspace") catch { _ => false }
  inspect(handled, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"ac|1|1\")",
  )
}

///|
async test "Browser handle_focused_key replaces selected text in focused text input" {
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
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=1; field.selectionEnd=3; return 'ok'; })()",
  )

  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"axd|2|2\")",
  )
}

///|
async test "Browser handle_focused_key deletes text after caret in focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abc" style="display:block;width:120px;height:32px" />
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
  inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"ac|1|1\")",
  )
}

///|
async test "Browser handle_focused_key moves caret with Home and End" {
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
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.selectionStart=2; field.selectionEnd=2; return 'ok'; })()",
  )

  let moved_home = browser.handle_focused_key("Home") catch { _ => false }
  inspect(moved_home, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"0|0\")",
  )
  let moved_end = browser.handle_focused_key("End") catch { _ => false }
  inspect(moved_end, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"4|4\")",
  )
}

///|
async test "Browser handle_focused_key replaces all text after select()" {
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
  browser.next_link()
  let _ = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); field.select(); return 'ok'; })()",
  )

  let handled = browser.handle_focused_key("x") catch { _ => false }
  inspect(handled, content="true")
  inspect(
    browser.execute_inline_js(
      "(function(){ const field=document.getElementById('field'); return field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); })()",
    ),
    content="Some(\"x|1|1\")",
  )
}

///|
async test "Browser execute_inline_js setRangeText updates focused text input" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <input id="field" type="text" value="abcd" style="display:block;width:120px;height:32px" />
    #|  <p id="status">before</p>
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

  let result = browser.execute_inline_js(
    "(function(){ const field=document.getElementById('field'); const status=document.getElementById('status'); field.setRangeText('xy',1,3,'select'); status.textContent = field.value + '|' + String(field.selectionStart) + '|' + String(field.selectionEnd); return status.textContent; })()",
  )
  inspect(result, content="Some(\"axyd|1|3\")")
  let _ = browser.sync_render_state_from_dom_tree()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("axyd|1|3"))
}

///|
async test "Browser sync_render_state_from_dom_tree renders shadow root composed content" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host"><span>light</span></div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<p>shadow-text</p>';
    #|  return host.shadowRoot.firstChild.textContent;
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"shadow-text\")")

  let _ = browser.sync_render_state_from_dom_tree()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("shadow-text"))
  assert_false(rendered.contains("light"))
}

///|
async test "Browser sync_render_state_from_dom_tree renders distributed slot content" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <span id="plain">plain-text</span>
    #|    <em id="named" slot="label">named-text</em>
    #|  </div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<section><slot></slot><slot name="label"></slot><span>fallback</span></section>';
    #|  return shadow.textContent.replace(/\s+/g, ' ').trim();
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"fallback\")")

  let _ = browser.sync_render_state_from_dom_tree()
  assert_true(browser.html_content.contains("plain-text"))
  assert_true(browser.html_content.contains("named-text"))
  assert_true(browser.html_content.contains("fallback"))
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("plain-text"))
  assert_true(rendered.contains("named-text"))
}

///|
async test "Browser sync_render_state_from_dom_tree updates slot reassignment" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <span id="item">slot-source</span>
    #|  </div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<section><slot name="label"></slot><slot></slot></section>';
    #|  const slots = shadow.querySelectorAll('slot');
    #|  document.getElementById('item').slot = 'label';
    #|  return [
    #|    slots[0].assignedNodes().length,
    #|    slots[1].assignedNodes().length
    #|  ].join('|');
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"1|0\")")

  let _ = browser.sync_render_state_from_dom_tree()
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("slot-source"))
}

///|
async test "Browser sync_render_state_from_dom_tree builds accessibility tree from shadow root composed content" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <button id="light-btn">light</button>
    #|  </div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<button id="shadow-btn">shadow action</button>';
    #|  return shadow.firstChild.id;
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"shadow-btn\")")

  let _ = browser.sync_render_state_from_dom_tree()
  match browser.a11y_tree {
    Some(tree) => {
      match tree.find_by_source_id("shadow-btn") {
        Some(_) => assert_true(true)
        None => assert_true(false)
      }
      match tree.find_by_source_id("light-btn") {
        Some(_) => assert_true(false)
        None => assert_true(true)
      }
    }
    None => panic()
  }
}

///|
async test "Browser sync_render_state_from_dom_tree builds accessibility tree from distributed slot content" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <button id="slotted-btn" slot="cta">slotted action</button>
    #|  </div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<section><slot name="cta"><button id="fallback-btn">fallback action</button></slot></section>';
    #|  return shadow.textContent.replace(/\s+/g, ' ').trim();
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"fallback action\")")

  let _ = browser.sync_render_state_from_dom_tree()
  match browser.a11y_tree {
    Some(tree) => {
      match tree.find_by_source_id("slotted-btn") {
        Some(_) => assert_true(true)
        None => assert_true(false)
      }
      match tree.find_by_source_id("fallback-btn") {
        Some(_) => assert_true(false)
        None => assert_true(true)
      }
    }
    None => panic()
  }
}

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
  inspect(status, content="Some(\"change:x\")")
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
  inspect(
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
  inspect(
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
  inspect(
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
  inspect(
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
  inspect(
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
  inspect(persisted, content="Some(\"true|true|true|true|true\")")
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
  inspect(log, content="Some(\"change:x|blur|focusout|focus|focusin\")")
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
  inspect(state, content="Some(\"seed\")")
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
  inspect(log, content="Some(\"change:x|blur|focus\")")
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
  inspect(log, content="Some(\"change:b\")")
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
  inspect(open, content="Some(\"true\")")
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
  inspect(value, content="Some(\"\\\"\\\\n\\\"\")")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"\\\"\\\\n\\\"\")")
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
  inspect(state, content="Some(\"seed|true\")")
}
