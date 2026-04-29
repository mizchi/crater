///|
/// Tests for Browser JS integration

///|
test "Browser getter API returns initial state" {
  let browser = Browser::new(800, 600)
  inspect(browser.get_current_url(), content="")
  inspect(browser.get_last_navigation_url(), content="None")
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
fn first_shared_hit_cell(a : @tui.HitRegion, b : @tui.HitRegion) -> (Int, Int) {
  let left = a.col.max(b.col)
  let top = a.row.max(b.row)
  let right = (a.col + a.width).min(b.col + b.width)
  let bottom = (a.row + a.height).min(b.row + b.height)
  if right <= left || bottom <= top {
    panic()
  }
  for row in top..<bottom {
    for col in left..<right {
      if a.contains(col, row) && b.contains(col, row) {
        return (col, row)
      }
    }
  }
  panic()
}

///|
fn link_region_of_source_id(
  browser : Browser,
  source_id : String,
) -> @tui.LinkRegion {
  for region in browser.link_regions {
    if region.source_id == source_id {
      return region
    }
  }
  panic()
}

///|
extern "js" fn js_install_fetch_mock(
  expected_url : String,
  response_body : String,
) -> Unit =
  #| (expectedUrl, responseBody) => {
  #|   const state = globalThis.__craterTestFetchMock || {
  #|     originalFetch: globalThis.fetch,
  #|     calls: [],
  #|     responses: Object.create(null),
  #|     installed: false,
  #|   };
  #|   globalThis.__craterTestFetchMock = state;
  #|   if (!state.installed) {
  #|     globalThis.fetch = async (url, init = {}) => {
  #|       const method = String(init.method || 'GET').toUpperCase();
  #|       const headers = Object.fromEntries(new Headers(init.headers || {}).entries());
  #|       const body =
  #|         typeof init.body === 'string'
  #|           ? init.body
  #|           : init.body == null
  #|             ? ''
  #|             : String(init.body);
  #|       const stringUrl = String(url);
  #|       state.calls.push({
  #|         url: stringUrl,
  #|         method,
  #|         headers,
  #|         body,
  #|       });
  #|       if (Object.prototype.hasOwnProperty.call(state.responses, stringUrl)) {
  #|         return new Response(state.responses[stringUrl], {
  #|           status: 200,
  #|           headers: { 'content-type': 'text/html' },
  #|         });
  #|       }
  #|       return state.originalFetch(url, init);
  #|     };
  #|     state.installed = true;
  #|   }
  #|   state.responses[String(expectedUrl)] = responseBody;
  #| }

///|
extern "js" fn js_take_last_fetch_mock_call_for_url(
  expected_url : String,
) -> String =
  #| (expectedUrl) => {
  #|   const state = globalThis.__craterTestFetchMock;
  #|   if (!state || !state.calls || state.calls.length === 0) {
  #|     return "null";
  #|   }
  #|   for (let i = state.calls.length - 1; i >= 0; i--) {
  #|     if (String(state.calls[i].url) === expectedUrl) {
  #|       return JSON.stringify(state.calls[i]);
  #|     }
  #|   }
  #|   return "null";
  #| }

///|
extern "js" fn js_restore_fetch_mock() -> Unit =
  #| () => {
  #|   return undefined;
  #| }

///|
fn extract_fetch_mock_header(
  call_json : String,
  header_name : String,
) -> String? {
  let parsed = @json.parse(call_json) catch { _ => return None }
  match parsed {
    Object(map) =>
      match map.get("headers") {
        Some(Object(headers)) =>
          match headers.get(header_name) {
            Some(String(value)) => Some(value)
            _ => None
          }
        _ => None
      }
    _ => None
  }
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
test "Browser execute_scripts propagates custom states into CSS cascade" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|<style>
    #|  x-panel { color: black; }
    #|  x-panel:state(open) { color: red; }
    #|</style>
    #|</head>
    #|<body>
    #|  <x-panel id="panel">hello</x-panel>
    #|  <script>
    #|    class XPanel extends HTMLElement {
    #|      constructor() {
    #|        super();
    #|        this.internals = this.attachInternals();
    #|        this.internals.states.add('open');
    #|      }
    #|    }
    #|    customElements.define('x-panel', XPanel);
    #|  </script>
    #|</body>
    #|</html>
  browser.set_html_content(html)
  browser.set_enable_js(true)
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  assert_true(
    browser.html_content.contains("data-crater-custom-states=\"open\""),
  )
  let styles = @css.discover_all_computed_styles(browser.html_content, ["color"])
  let panel_styles = styles.get("x-panel#panel").unwrap()
  assert_eq(panel_styles.get("color").unwrap(), "red")
}

///|
test "Browser execute_scripts preserves form-associated restore state across JS runtime reinit" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|  <form id="form">
    #|    <x-restore-aware id="control" name="token"></x-restore-aware>
    #|  </form>
    #|  <script>
    #|    globalThis.__restoreEvents = [];
    #|    class RestoreAwareControl extends HTMLElement {
    #|      static get formAssociated() { return true; }
    #|      constructor() {
    #|        super();
    #|        this.internals = this.attachInternals();
    #|      }
    #|      connectedCallback() {
    #|        if (!this.hasAttribute('data-seeded')) {
    #|          this.setAttribute('data-seeded', '1');
    #|          this.internals.setFormValue('draft-value', 'draft-state');
    #|        }
    #|      }
    #|      formStateRestoreCallback(state, mode) {
    #|        globalThis.__restoreEvents.push([state, mode, this.id]);
    #|      }
    #|    }
    #|    customElements.define('x-restore-aware', RestoreAwareControl);
    #|  </script>
    #|</body>
    #|</html>
  browser.set_html_content(html)
  browser.set_enable_js(true)
  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  assert_true(
    browser.source_html.contains("data-crater-form-state-value=\"draft-state\""),
  )
  assert_false(browser.html_content.contains("data-crater-form-state-value"))

  browser.dom_tree = None
  browser.script_executor = None

  let executed_after_reinit = browser.execute_scripts()
  inspect(executed_after_reinit, content="1")
  let restored = browser.execute_inline_js(
    "(function(){ return JSON.stringify([globalThis.__restoreEvents || [], new FormData(document.getElementById('form')).get('token')]); })()",
  )
  inspect(
    restored,
    content="Some(\"[[[\\\"draft-state\\\",\\\"restore\\\",\\\"control\\\"]],\\\"draft-value\\\"]\")",
  )
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
    (Some(top), Some(bottom)) => first_shared_hit_cell(top, bottom)
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
    (Some(top), Some(bottom)) => first_shared_hit_cell(top, bottom)
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
async test "Browser activate_at uses scaled transform visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 32px; background: #999; z-index: 1; transform: scaleX(2); }
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
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 10
  let row = bottom.row + 1
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at uses quarter-turn rotate visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 128px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 64px; top: 0; width: 32px; height: 64px; background: #999; z-index: 1; transform: rotate(90deg); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 6
  let row = bottom.row + 1
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at uses arbitrary-angle rotate visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 128px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: rotate(45deg); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let col = 3
  let row = 2
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at excludes arbitrary-angle rotate bbox corners" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 128px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: rotate(45deg); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 2
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at uses skew transform visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 128px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: skewX(45deg); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 2
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at excludes skew transform bbox corners" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 128px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: skewX(45deg); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at uses matrix transform visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 224px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: matrix(1, 0, -1, 1, 64, 0); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 18
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at excludes matrix transform bbox corners" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 224px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: matrix(1, 0, -1, 1, 64, 0); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 8
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at uses matrix3d transform visual bounds" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 224px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: matrix3d(1, 0, 0, 0, -1, 1, 0, 0, 0, 0, 1, 0, 64, 0, 0, 1); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 18
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at excludes matrix3d transform bbox corners" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 224px; height: 96px; background: #ccc; }
    #|    #top { position: absolute; left: 32px; top: 0; width: 64px; height: 64px; background: #999; z-index: 1; transform: matrix3d(1, 0, 0, 0, -1, 1, 0, 0, 0, 0, 1, 0, 64, 0, 0, 1); }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 112px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let col = bottom.col + 8
  let row = bottom.row
  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at uses cell center for sub-cell hit testing" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 1px; height: 48px; background: #999; z-index: 1; }
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
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
  }
  let (col, row) = match top_region {
    Some(region) => (region.col, region.row)
    None => panic()
  }

  inspect(browser.get_source_id_at(col, row), content="Some(\"bottom\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"bottom\")")
}

///|
async test "Browser activate_at uses sub-pixel coverage for anti-aliased hit testing" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 6px; background: #999; z-index: 1; }
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
  for region in browser.hit_regions {
    if region.source_id == "top" {
      top_region = Some(region)
    }
  }
  let (col, row) = match top_region {
    Some(region) => (region.col, region.row)
    None => panic()
  }

  inspect(browser.get_source_id_at(col, row), content="Some(\"top\")")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  let status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(status, content="Some(\"top\")")
}

///|
async test "Browser activate_at samples non-rect clip-path cell coverage" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: polygon(0 0, 4px 0, 4px 64px, 0 64px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let top = hit_region_of_source_id(browser, "top")
  let outside_col = top.col + 1
  inspect(
    browser.get_source_id_at(outside_col, top.row),
    content="Some(\"bottom\")",
  )
  let outside_activated = browser.activate_at(outside_col, top.row) catch {
    _ => false
  }
  inspect(outside_activated, content="true")
  let outside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(outside_status, content="Some(\"bottom\")")

  inspect(browser.get_source_id_at(top.col, top.row), content="Some(\"top\")")
  let edge_activated = browser.activate_at(top.col, top.row) catch {
    _ => false
  }
  inspect(edge_activated, content="true")
  let edge_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(edge_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects border-radius hit shape" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 48px; background: #999; border-radius: 24px; z-index: 1; }
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
  let top = hit_region_of_source_id(browser, "top")
  inspect(
    browser.get_source_id_at(top.col, top.row),
    content="Some(\"bottom\")",
  )
  let corner_activated = browser.activate_at(top.col, top.row) catch {
    _ => false
  }
  inspect(corner_activated, content="true")
  let corner_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(corner_status, content="Some(\"bottom\")")

  let inside_col = top.col + 4
  inspect(
    browser.get_source_id_at(inside_col, top.row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, top.row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path inset hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #999; clip-path: inset(16px 0 0 16px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 3
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path rect hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #999; clip-path: rect(16px 128px 64px 16px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 3
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path xywh hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 160px; height: 64px; background: #999; clip-path: xywh(16px 16px 112px 48px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 3
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path circle hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: circle(24px at 32px 32px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 2
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path ellipse hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: ellipse(24px 16px at 32px 32px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 2
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path polygon hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: polygon(32px 0, 64px 64px, 0 64px); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 4
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects clip-path path hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: path("M 32 0 L 64 64 L 0 64 Z"); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  inspect(
    browser.get_source_id_at(bottom.col, bottom.row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(bottom.col, bottom.row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 4
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects quadratic clip-path path hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: path("M 0 64 Q 32 0 64 64 Z"); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let outside_col = bottom.col + 4
  let outside_row = bottom.row
  inspect(
    browser.get_source_id_at(outside_col, outside_row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(outside_col, outside_row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 4
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects smooth clip-path path hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: path("M 0 64 Q 16 0 32 64 T 64 64 Z"); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let outside_col = bottom.col + 4
  let outside_row = bottom.row
  inspect(
    browser.get_source_id_at(outside_col, outside_row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(outside_col, outside_row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 2
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
}

///|
async test "Browser activate_at respects arc clip-path path hit region" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<head>
    #|  <style>
    #|    body { margin: 0; position: relative; }
    #|    #bottom { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #ccc; }
    #|    #top { position: absolute; left: 0; top: 0; width: 64px; height: 64px; background: #999; clip-path: path("M 0 64 A 32 32 0 0 1 64 64 Z"); z-index: 1; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="bottom" onclick="document.getElementById('status').textContent='bottom';"></div>
    #|  <div id="top" onclick="document.getElementById('status').textContent='top';"></div>
    #|  <div style="height: 80px"></div>
    #|  <p id="status">before</p>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let bottom = hit_region_of_source_id(browser, "bottom")
  let outside_col = bottom.col + 4
  let outside_row = bottom.row
  inspect(
    browser.get_source_id_at(outside_col, outside_row),
    content="Some(\"bottom\")",
  )
  let clipped_activated = browser.activate_at(outside_col, outside_row) catch {
    _ => false
  }
  inspect(clipped_activated, content="true")
  let clipped_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(clipped_status, content="Some(\"bottom\")")

  let inside_col = bottom.col + 4
  let inside_row = bottom.row + 2
  inspect(
    browser.get_source_id_at(inside_col, inside_row),
    content="Some(\"top\")",
  )
  let inside_activated = browser.activate_at(inside_col, inside_row) catch {
    _ => false
  }
  inspect(inside_activated, content="true")
  let inside_status = browser.execute_inline_js(
    "(function(){ return document.getElementById('status').textContent; })()",
  )
  inspect(inside_status, content="Some(\"top\")")
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
test "Browser reinit restores clipboard addEventListener handlers" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|  <div id="target">Clipboard target</div>
    #|  <p id="status">before</p>
    #|  <script>
    #|    const target = document.getElementById('target');
    #|    target.addEventListener('copy', function (event) {
    #|      const data = event.clipboardData ? event.clipboardData.getData('text/plain') : 'none';
    #|      if (event.clipboardData) event.clipboardData.setData('text/plain', 'copied');
    #|      document.getElementById('status').textContent += 'copy:' + data + '|';
    #|    });
    #|    target.addEventListener('cut', function (event) {
    #|      const data = event.clipboardData ? event.clipboardData.getData('text/plain') : 'none';
    #|      document.getElementById('status').textContent += 'cut:' + data + '|';
    #|    });
    #|    target.addEventListener('paste', function (event) {
    #|      const data = event.clipboardData ? event.clipboardData.getData('text/plain') : 'none';
    #|      document.getElementById('status').textContent += 'paste:' + data;
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
  browser.dom_tree = None
  browser.script_executor = None

  let dispatch_clipboard_events =
    #|(function () {
    #|  const target = document.getElementById('target');
    #|  const status = document.getElementById('status');
    #|  status.textContent = '';
    #|  const clipboardData = new DataTransfer();
    #|  clipboardData.setData('text/plain', 'seed');
    #|  for (const type of ['copy', 'cut', 'paste']) {
    #|    target.dispatchEvent(new ClipboardEvent(type, {
    #|      bubbles: true,
    #|      cancelable: true,
    #|      clipboardData
    #|    }));
    #|  }
    #|  return status.textContent + ':' + clipboardData.getData('text/plain');
    #|})()
  let status = browser.execute_inline_js(dispatch_clipboard_events)
  inspect(status, content="Some(\"copy:seed|cut:copied|paste:copied:copied\")")
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
    (Some(top), Some(bottom)) => first_shared_hit_cell(top, bottom)
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
async test "Browser activate_at submit listener sees SubmitEvent.submitter" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%3Enavigated%3C/p%3E" method="get">
    #|    <button id="btn" name="go" value="Go" type="submit" style="display:block;width:96px;height:32px">Go</button>
    #|  </form>
    #|  <p id="status">before</p>
    #|  <script>
    #|    globalThis.__submitterSeen = 'none';
    #|    document.getElementById('form').addEventListener('submit', function (event) {
    #|      event.preventDefault();
    #|      globalThis.__submitterSeen = event.submitter ? event.submitter.id : 'null';
    #|      document.getElementById('status').textContent = globalThis.__submitterSeen;
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
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content="")

  let submitter_seen = browser.execute_inline_js("globalThis.__submitterSeen")
  inspect(submitter_seen, content="Some(\"btn\")")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("btn"))
}

///|
async test "Browser activate_at submitter formaction overrides form action" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22wrong%22%3Ewrong%3C/p%3E" method="get">
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formaction="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
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
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E?go=Go",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("right"))
  assert_true(!rendered.contains("wrong"))
}

///|
async test "Browser activate_at submitter formmethod post navigates with form body" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
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
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.http_method, content="POST")
      inspect(
        req.content_type,
        content="application/x-www-form-urlencoded;charset=UTF-8",
      )
      inspect(req.body, content="token=1&go=Go")
    }
    None => panic()
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser activate_at submitter formenctype text/plain serializes post body" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="post">
    #|    <input type="hidden" name="token" value="1" />
    #|    <textarea name="note">hello world</textarea>
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formenctype="text/plain"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
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
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.http_method, content="POST")
      inspect(req.content_type, content="text/plain;charset=UTF-8")
      inspect(req.body, content="token=1\r\nnote=hello world\r\ngo=Go")
    }
    None => panic()
  }
}

///|
async test "Browser activate_at submitter formenctype multipart serializes post body" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="post">
    #|    <input type="hidden" name="token" value="1" />
    #|    <textarea name="note">hello world</textarea>
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formenctype="multipart/form-data"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
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
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(
        req.content_type,
        content="multipart/form-data; boundary=----CraterFormBoundary",
      )
      assert_true(req.body.contains("--" + "----CraterFormBoundary" + "\r\n"))
      assert_true(
        req.body.contains(
          "Content-Disposition: form-data; name=\"token\"\r\n\r\n1\r\n",
        ),
      )
      assert_true(
        req.body.contains(
          "Content-Disposition: form-data; name=\"note\"\r\n\r\nhello world\r\n",
        ),
      )
      assert_true(
        req.body.contains(
          "Content-Disposition: form-data; name=\"go\"\r\n\r\nGo\r\n",
        ),
      )
      assert_true(req.body.contains("--" + "----CraterFormBoundary" + "--\r\n"))
    }
    None => panic()
  }
}

///|
async test "Browser activate_at submitter formtarget _blank avoids current navigation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <button
    #|      id="btn"
    #|      type="submit"
    #|      formtarget="_blank"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
    #|    <p id="status">before</p>
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
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content="")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("before"))
  assert_true(!rendered.contains("done"))
}

///|
async test "Browser activate_at submitter formtarget _top navigates current page" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formtarget="_top"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
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
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?go=Go",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser activate_at invalid required form stays on page" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input id="field" name="name" required />
    #|    <button
    #|      id="btn"
    #|      type="submit"
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
    #|    <p id="status">before</p>
    #|    <script>
    #|      document.getElementById('field').addEventListener('invalid', () => {
    #|        document.getElementById('status').textContent = 'invalid';
    #|      });
    #|    </script>
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
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content="")
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("invalid"))
  assert_true(!rendered.contains("done"))
}

///|
async test "Browser activate_at submitter formnovalidate bypasses required validation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input id="field" name="name" required />
    #|    <button
    #|      id="btn"
    #|      type="submit"
    #|      formnovalidate
    #|      style="display:block;width:96px;height:32px"
    #|    >Go</button>
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
  let (col, row) = center_of_hit_source_id(browser, "btn")
  let activated = browser.activate_at(col, row) catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?name=",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser activate_at image submit appends coordinate pairs" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <input
    #|      id="img"
    #|      type="image"
    #|      name="pic"
    #|      value="ignored"
    #|      style="display:block;width:96px;height:32px"
    #|    />
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  let region = hit_region_of_source_id(browser, "img")
  let client_x = region.col * 8 + 4
  let client_y = region.row * 16 + 8

  let activated = browser.activate_at(region.col, region.row) catch {
    _ => false
  }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1&pic.x=" +
      client_x.to_string() +
      "&pic.y=" +
      client_y.to_string(),
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
test "Browser execute_inline_js form.submit bypasses submit listener and navigates data url" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('form').addEventListener('submit', function () {
    #|      document.getElementById('status').textContent = 'submitted';
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
  let result = browser.execute_inline_js(
    "(function(){ document.getElementById('form').submit(); return 'ok'; })()",
  )
  inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
  assert_true(!rendered.contains("submitted"))
}

///|
test "Browser execute_inline_js form.requestSubmit uses submitter overrides for data url" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22wrong%22%3Ewrong%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formaction="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  )
  inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E?token=1&go=Go",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("right"))
  assert_true(!rendered.contains("wrong"))
}

///|
test "Browser execute_inline_js form.requestSubmit preserves post body metadata" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      formenctype="text/plain"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  )
  inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.http_method, content="POST")
      inspect(req.content_type, content="text/plain;charset=UTF-8")
      inspect(req.body, content="token=1\r\ngo=Go")
    }
    None => panic()
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
test "Browser execute_inline_js keeps unsupported sync submit navigation pending" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="https://example.com/after" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let result = browser.execute_inline_js(
    "(function(){ document.getElementById('form').submit(); return 'ok'; })()",
  )
  inspect(result, content="Some(\"ok\")")
  inspect(browser.get_current_url(), content="")
  inspect(
    browser.execute_inline_js(
      "String((globalThis.__craterPendingFormSubmissions || []).length)",
    ),
    content="Some(\"1\")",
  )
}

///|
test "Browser execute_inline_js requestSubmit queues one submitter-aware external request" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="https://api.test/submit" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      formenctype="text/plain"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  )
  inspect(result, content="Some(\"ok\")")
  inspect(browser.get_current_url(), content="")
  inspect(
    browser.execute_inline_js(
      "String((globalThis.__craterPendingFormSubmissions || []).length)",
    ),
    content="Some(\"1\")",
  )
  let pending = browser.execute_inline_js(
    "(function(){ const queue = globalThis.__craterPendingFormSubmissions || []; return queue.length > 0 ? String(queue[0]) : ''; })()",
  )
  match pending {
    Some(request) => {
      assert_true(request.contains("\"url\":\"https://api.test/submit\""))
      assert_true(request.contains("\"http_method\":\"POST\""))
      assert_true(request.contains("token=1"))
      assert_true(request.contains("go=Go"))
    }
    None => panic()
  }
}

///|
async test "Browser execute_inline_js_async form.submit bypasses submit listener and navigates" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|  <p id="status">before</p>
    #|  <script>
    #|    document.getElementById('form').addEventListener('submit', function () {
    #|      document.getElementById('status').textContent = 'submitted';
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
  let result = browser.execute_inline_js_async(
    "(function(){ document.getElementById('form').submit(); return 'ok'; })()",
  ) catch {
    _ => None
  }
  inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
  assert_true(!rendered.contains("submitted"))
}

///|
async test "Browser execute_inline_js_async form.requestSubmit uses submitter overrides" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22wrong%22%3Ewrong%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formaction="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  match
    browser.execute_inline_js(
      "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); return globalThis.__craterBuildFormNavigationRequest(form, button, 0, 0); })()",
    ) {
    Some(request) => assert_true(request.contains("go=Go"))
    None => panic()
  }
  let result = browser.execute_inline_js_async(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  ) catch {
    _ => None
  }
  inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22right%22%3Eright%3C/p%3E?token=1&go=Go",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("right"))
  assert_true(!rendered.contains("wrong"))
}

///|
async test "Browser execute_inline_js_async form.requestSubmit preserves post body metadata" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      formenctype="text/plain"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js_async(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  ) catch {
    _ => None
  }
  inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.http_method, content="POST")
      inspect(req.content_type, content="text/plain;charset=UTF-8")
      inspect(req.body, content="token=1\r\ngo=Go")
    }
    None => panic()
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
async test "Browser execute_inline_js_async requestSubmit posts body to external fetch" {
  js_restore_fetch_mock()
  js_install_fetch_mock(
    "https://api.test/request-submit-text", "<html><body><p id=\"posted\">posted</p></body></html>",
  )
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="https://api.test/request-submit-text" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      formenctype="text/plain"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.current_url = "https://example.test/form"
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js_async(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  ) catch {
    err => {
      js_restore_fetch_mock()
      raise err
    }
  }
  inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="https://api.test/request-submit-text",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.url, content="https://api.test/request-submit-text")
      inspect(req.http_method, content="POST")
      inspect(req.content_type, content="text/plain;charset=UTF-8")
      inspect(req.body, content="token=1\r\ngo=Go")
    }
    None => {
      js_restore_fetch_mock()
      panic()
    }
  }
  let call_json = js_take_last_fetch_mock_call_for_url(
    "https://api.test/request-submit-text",
  )
  let parsed = @json.parse(call_json) catch {
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  match parsed {
    Object(map) => {
      match map.get("url") {
        Some(String(url)) =>
          inspect(url, content="https://api.test/request-submit-text")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("method") {
        Some(String(http_method)) => inspect(http_method, content="POST")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("body") {
        Some(String(body)) => inspect(body, content="token=1\r\ngo=Go")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      inspect(
        extract_fetch_mock_header(call_json, "content-type"),
        content="Some(\"text/plain;charset=UTF-8\")",
      )
      inspect(
        extract_fetch_mock_header(call_json, "origin"),
        content="Some(\"https://example.test\")",
      )
    }
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("posted"))
  js_restore_fetch_mock()
}

///|
async test "Browser load_url_request preserves external post body with CRLF" {
  js_restore_fetch_mock()
  js_install_fetch_mock(
    "https://api.test/direct-post-text", "<html><body><p id=\"posted\">posted</p></body></html>",
  )
  let browser = Browser::new(800, 600)
  browser.current_url = "https://example.test/form"
  let _ = browser.load_url_request({
    url: "https://api.test/direct-post-text",
    http_method: "POST",
    content_type: "text/plain;charset=UTF-8",
    body: "token=1\r\ngo=Go",
  }) catch {
    err => {
      js_restore_fetch_mock()
      raise err
    }
  }
  let call_json = js_take_last_fetch_mock_call_for_url(
    "https://api.test/direct-post-text",
  )
  let parsed = @json.parse(call_json) catch {
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  match parsed {
    Object(map) =>
      match map.get("body") {
        Some(String(body)) => inspect(body, content="token=1\r\ngo=Go")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  js_restore_fetch_mock()
}

///|
async test "Browser execute_inline_js_async requestSubmit posts multipart body to external fetch" {
  js_restore_fetch_mock()
  js_install_fetch_mock(
    "https://api.test/request-submit-multipart", "<html><body><p id=\"uploaded\">uploaded</p></body></html>",
  )
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="https://api.test/request-submit-multipart" method="post">
    #|    <input type="hidden" name="token" value="1" />
    #|    <textarea name="note">hello world</textarea>
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formenctype="multipart/form-data"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.current_url = "https://example.test/form"
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js_async(
    "(function(){ const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button); return 'ok'; })()",
  ) catch {
    err => {
      js_restore_fetch_mock()
      raise err
    }
  }
  inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="https://api.test/request-submit-multipart",
  )
  let call_json = js_take_last_fetch_mock_call_for_url(
    "https://api.test/request-submit-multipart",
  )
  let parsed = @json.parse(call_json) catch {
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  match parsed {
    Object(map) => {
      match map.get("url") {
        Some(String(url)) =>
          inspect(url, content="https://api.test/request-submit-multipart")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("method") {
        Some(String(http_method)) => inspect(http_method, content="POST")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("body") {
        Some(String(body)) => {
          assert_true(body.contains("--" + "----CraterFormBoundary" + "\r\n"))
          assert_true(
            body.contains(
              "Content-Disposition: form-data; name=\"token\"\r\n\r\n1\r\n",
            ),
          )
          assert_true(
            body.contains(
              "Content-Disposition: form-data; name=\"note\"\r\n\r\nhello world\r\n",
            ),
          )
          assert_true(
            body.contains(
              "Content-Disposition: form-data; name=\"go\"\r\n\r\nGo\r\n",
            ),
          )
          assert_true(body.contains("--" + "----CraterFormBoundary" + "--\r\n"))
        }
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      inspect(
        extract_fetch_mock_header(call_json, "content-type"),
        content="Some(\"multipart/form-data; boundary=----CraterFormBoundary\")",
      )
      inspect(
        extract_fetch_mock_header(call_json, "origin"),
        content="Some(\"https://example.test\")",
      )
    }
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("uploaded"))
  js_restore_fetch_mock()
}

///|
async test "Browser execute_inline_js_async form.submit omits submitter field in external post body" {
  js_restore_fetch_mock()
  js_install_fetch_mock(
    "https://api.test/form-submit-post", "<html><body><p id=\"posted\">posted</p></body></html>",
  )
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="https://api.test/form-submit-post" method="post">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button id="btn" name="go" value="Go" type="submit">Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.current_url = "https://example.test/form"
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.execute_scripts()
  let result = browser.execute_inline_js_async(
    "(function(){ document.getElementById('form').submit(); return 'ok'; })()",
  ) catch {
    err => {
      js_restore_fetch_mock()
      raise err
    }
  }
  inspect(result, content="Some(\"ok\")")
  inspect(
    browser.get_current_url(),
    content="https://api.test/form-submit-post",
  )
  let call_json = js_take_last_fetch_mock_call_for_url(
    "https://api.test/form-submit-post",
  )
  let parsed = @json.parse(call_json) catch {
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  match parsed {
    Object(map) => {
      match map.get("url") {
        Some(String(url)) =>
          inspect(url, content="https://api.test/form-submit-post")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("method") {
        Some(String(http_method)) => inspect(http_method, content="POST")
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      match map.get("body") {
        Some(String(body)) => {
          inspect(body, content="token=1")
          assert_true(!body.contains("go=Go"))
        }
        _ => {
          js_restore_fetch_mock()
          panic()
        }
      }
      inspect(
        extract_fetch_mock_header(call_json, "content-type"),
        content="Some(\"application/x-www-form-urlencoded;charset=UTF-8\")",
      )
      inspect(
        extract_fetch_mock_header(call_json, "origin"),
        content="Some(\"https://example.test\")",
      )
    }
    _ => {
      js_restore_fetch_mock()
      panic()
    }
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("posted"))
  js_restore_fetch_mock()
}

///|
async test "Browser execute_scripts_async drains script-triggered form submission navigation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|  <script>
    #|    document.getElementById('form').submit();
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let executed = browser.execute_scripts_async() catch { _ => 0 }
  inspect(executed, content="1")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
test "Browser execute_scripts drains script-triggered data-url form submission navigation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|  <script>
    #|    document.getElementById('form').submit();
    #|  </script>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let executed = browser.execute_scripts()
  inspect(executed, content="1")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
test "Browser tick_js drains queued data-url form submission navigation" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  browser.init_js_execution()
  let _ = @js.enqueue_script(
    browser.scheduler,
    "document.getElementById('form').submit();",
    true,
  )

  inspect(browser.tick_js(), content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?token=1",
  )
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
}

///|
test "Browser tick_js drains queued post form submission metadata" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form id="form" action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input type="hidden" name="token" value="1" />
    #|    <button
    #|      id="btn"
    #|      name="go"
    #|      value="Go"
    #|      type="submit"
    #|      formmethod="post"
    #|      formenctype="text/plain"
    #|    >Go</button>
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  browser.init_js_execution()
  let _ = @js.enqueue_script(
    browser.scheduler,
    "const form = document.getElementById('form'); const button = document.getElementById('btn'); form.requestSubmit(button);",
    true,
  )

  inspect(browser.tick_js(), content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E",
  )
  match browser.last_navigation_request {
    Some(req) => {
      inspect(req.http_method, content="POST")
      inspect(req.content_type, content="text/plain;charset=UTF-8")
      inspect(req.body, content="token=1\r\ngo=Go")
    }
    None => panic()
  }
  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("done"))
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
async test "Browser activate_focused_link image submit appends centered coordinates" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <form action="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E" method="get">
    #|    <input
    #|      id="img"
    #|      type="image"
    #|      name="pic"
    #|      style="display:block;width:96px;height:32px"
    #|    />
    #|  </form>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)

  let _ = browser.render_output(Text)
  browser.focus_source_id("img")
  let (client_x, client_y) = match
    browser.get_client_coords_for_source_id("img") {
    Some(coords) => coords
    None => panic()
  }

  let activated = browser.activate_focused_link() catch { _ => false }
  inspect(activated, content="true")
  inspect(
    browser.get_current_url(),
    content="data:text/html,%3Cp%20id%3D%22after%22%3Edone%3C/p%3E?pic.x=" +
      client_x.to_string() +
      "&pic.y=" +
      client_y.to_string(),
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
async test "Browser sync_render_state_from_dom_tree keeps serializable shadow snapshot separate from render html" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host"><span id="light">light</span></div>
    #|</body>
    #|</html>
  browser.html_content = html
  browser.dom_snapshot_html = html
  browser.parsed_doc = Some(
    @html.assign_synthetic_ids(@html.parse_document(html)),
  )
  browser.set_enable_js(true)
  let _ = browser.execute_scripts()
  let _ = browser.render_output(Text)

  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({
    #|    mode: 'closed',
    #|    delegatesFocus: true,
    #|    clonable: true,
    #|    serializable: true
    #|  });
    #|  shadow.innerHTML = '<button id="shadow-btn">shadow-action</button>';
    #|  return host.shadowRoot === null ? 'closed' : 'open';
    #|})()
  let result = browser.execute_inline_js(code)
  inspect(result, content="Some(\"closed\")")

  let _ = browser.sync_render_state_from_dom_tree()
  assert_true(browser.html_content.contains("shadow-action"))
  assert_false(browser.html_content.contains("shadowrootmode"))
  assert_false(browser.html_content.contains("id=\"light\""))
  assert_true(
    browser.dom_snapshot_html.contains(
      "<template shadowrootmode=\"closed\" shadowrootdelegatesfocus shadowrootclonable shadowrootserializable><button id=\"shadow-btn\">shadow-action</button></template><span id=\"light\">light</span>",
    ),
  )
}

///|
test "Browser render_output normalizes declarative shadow DOM from initial HTML" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <template shadowrootmode="closed" shadowrootdelegatesfocus shadowrootclonable shadowrootserializable>
    #|      <p id="shadow-text">shadow-text</p>
    #|    </template>
    #|    <span id="light-text">light-text</span>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("shadow-text"))
  assert_false(rendered.contains("light-text"))
  assert_true(browser.html_content.contains("shadow-text"))
  assert_false(browser.html_content.contains("light-text"))
  assert_false(browser.html_content.contains("shadowrootmode"))
  assert_true(browser.dom_snapshot_html.contains("shadowrootmode=\"closed\""))
  assert_true(browser.dom_snapshot_html.contains("shadowrootdelegatesfocus"))
  assert_true(browser.dom_snapshot_html.contains("shadowrootclonable"))
  assert_true(browser.dom_snapshot_html.contains("shadowrootserializable"))
  assert_true(browser.dom_snapshot_html.contains("id=\"shadow-text\""))
  assert_true(browser.dom_snapshot_html.contains("id=\"light-text\""))
}

///|
test "Browser set_html_content eagerly normalizes declarative shadow DOM source" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <template shadowrootmode="closed" shadowrootserializable>
    #|      <p id="shadow-text">shadow-text</p>
    #|    </template>
    #|    <span id="light-text">light-text</span>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  assert_true(browser.html_content.contains("shadow-text"))
  assert_false(browser.html_content.contains("light-text"))
  assert_false(browser.html_content.contains("shadowrootmode"))
  assert_true(browser.dom_snapshot_html.contains("shadowrootmode=\"closed\""))
  assert_true(browser.dom_snapshot_html.contains("id=\"light-text\""))
  inspect(browser.parsed_doc is Some(_), content="true")
}

///|
test "Browser set_html_content rebuilds link cache from normalized shadow content" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a href="/shadow">shadow link</a>
    #|    </template>
    #|    <a href="/light">light link</a>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  inspect(browser.get_link_count(), content="1")
  inspect(browser.get_focused_link_index(), content="0")
  inspect(browser.get_focused_link_url(), content="Some(\"/shadow\")")
}

///|
test "Browser render_output exposes only shadow link regions and hints from initial HTML" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a href="data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E">shadow link</a>
    #|    </template>
    #|    <a href="data:text/html,%3Cp%20id%3D%22after%22%3Elight-done%3C/p%3E">light link</a>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("shadow link"))
  assert_false(rendered.contains("light link"))
  inspect(browser.link_regions.length(), content="1")
  inspect(browser.link_regions[0].text, content="shadow link")
  inspect(
    browser.get_link_at(
      browser.link_regions[0].col,
      browser.link_regions[0].row,
    ),
    content="Some(\"data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E\")",
  )

  browser.enter_hint_mode()
  inspect(browser.is_hint_mode(), content="true")
  inspect(browser.hints.length(), content="1")
  inspect(browser.hints[0].text, content="shadow link")
  inspect(
    browser.process_hint_char(browser.hints[0].label),
    content="Some(\"data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E\")",
  )
  inspect(browser.is_hint_mode(), content="false")
}

///|
test "Browser build_accessibility_tree normalizes declarative shadow DOM from initial HTML" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <button id="shadow-btn">shadow action</button>
    #|    </template>
    #|    <button id="light-btn">light action</button>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)
  browser.build_accessibility_tree()

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
test "Browser init_js_execution preserves declarative shadow DOM from source HTML" {
  let browser = Browser::new(800, 600)
  let html =
    #|<html>
    #|<body>
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <button id="shadow-btn">shadow action</button>
    #|    </template>
    #|    <button id="light-btn">light action</button>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)
  browser.set_enable_js(true)
  browser.init_js_execution()

  let host_has_open_shadow = browser.execute_inline_js(
    "(() => { const host = document.getElementById('host'); return host && host.shadowRoot ? 'yes' : 'no'; })()",
  )
  let shadow_visible = browser.execute_inline_js(
    "(() => { const host = document.getElementById('host'); return host && host.shadowRoot && host.shadowRoot.querySelector('#shadow-btn') ? 'yes' : 'no'; })()",
  )
  let light_visible = browser.execute_inline_js(
    "document.querySelector('#light-btn') !== null ? 'yes' : 'no'",
  )

  inspect(host_has_open_shadow, content="Some(\"yes\")")
  inspect(shadow_visible, content="Some(\"yes\")")
  inspect(light_visible, content="Some(\"yes\")")
}

///|
async test "Browser activate_at navigates shadow link from initial HTML" {
  let browser = Browser::new(800, 600)
  let target_url = "data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E"
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a href="data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E" style="display:block;width:120px;height:24px">shadow link</a>
    #|    </template>
    #|    <a href="data:text/html,%3Cp%20id%3D%22after%22%3Elight-done%3C/p%3E">light link</a>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let _ = browser.render_output(Text)
  inspect(browser.link_regions.length(), content="1")
  let region = browser.link_regions[0]
  let activated = browser.activate_at(region.col, region.row) catch {
    _ => false
  }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content=target_url)

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("shadow-done"))
}

///|
test "Browser shadow link hints resolve duplicate visible link text by source id" {
  let browser = Browser::new(800, 600)
  browser.current_url = "https://example.com/base/page.html"
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <a id="outer-link" href="/outer">shared link</a>
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a id="shadow-link" href="/shadow">shared link</a>
    #|    </template>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let _ = browser.render_output(Text)
  inspect(browser.link_regions.length(), content="2")
  let shadow_region = link_region_of_source_id(browser, "shadow-link")
  inspect(
    browser.get_link_at(shadow_region.col, shadow_region.row),
    content="Some(\"/shadow\")",
  )

  browser.enter_hint_mode()
  inspect(browser.hints.length(), content="2")
  let mut shadow_hint_href = ""
  for hint in browser.hints {
    if hint.col == shadow_region.col && hint.row == shadow_region.row {
      shadow_hint_href = hint.href
    }
  }
  inspect(shadow_hint_href, content="https://example.com/shadow")
}

///|
test "Browser render_output in no_color mode preserves duplicate link URLs" {
  let browser = Browser::new(800, 600)
  browser.current_url = "https://example.com/base/page.html"
  browser.set_no_color(true)
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <a id="outer-link" href="/outer">shared link</a>
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a id="shadow-link" href="/shadow">shared link</a>
    #|    </template>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let rendered = browser.render_output(Text)
  inspect(rendered.contains("https://example.com/outer"), content="true")
  inspect(rendered.contains("https://example.com/shadow"), content="true")
}

///|
async test "Browser activate_focused_link keeps shadow href for duplicate visible link text" {
  let browser = Browser::new(800, 600)
  let outer_url = "data:text/html,%3Cp%20id%3D%22after%22%3Eouter-done%3C/p%3E"
  let shadow_url = "data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E"
  let html =
    #|<html>
    #|<body style="margin:0">
    #|  <a id="outer-link" href="data:text/html,%3Cp%20id%3D%22after%22%3Eouter-done%3C/p%3E">shared link</a>
    #|  <div id="host">
    #|    <template shadowrootmode="open">
    #|      <a id="shadow-link" href="data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E">shared link</a>
    #|    </template>
    #|  </div>
    #|</body>
    #|</html>
  browser.set_html_content(html)

  let _ = browser.render_output(Text)
  browser.next_link()
  browser.next_link()

  inspect(
    browser.get_focused_link_url(),
    content="Some(\"data:text/html,%3Cp%20id%3D%22after%22%3Eshadow-done%3C/p%3E\")",
  )
  let activated = browser.activate_focused_link() catch { _ => false }
  inspect(activated, content="true")
  inspect(browser.get_current_url(), content=shadow_url)
  inspect(browser.get_current_url() == outer_url, content="false")

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("shadow-done"))
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
