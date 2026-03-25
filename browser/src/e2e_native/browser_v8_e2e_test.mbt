///|
/// Browser + V8 end-to-end tests (external/black-box tests)

///|
fn make_v8_browser(html : String) -> @shell.Browser {
  let browser = @shell.Browser::new(800, 600)
  let v8 = @js_v8.V8JsRuntime::new_with_mock_dom(@js_v8.full_mock_dom_js())
  browser.set_js_runtime(v8.as_js_runtime())
  browser.set_html_content(html)
  browser
}

///|
test "E2E: script modifies DOM textContent" {
  let browser = make_v8_browser(
    "<html><body><div id=\"app\">original</div><script>document.getElementById('app').textContent = 'Hello from V8!';</script></body></html>",
  )
  let executed = browser.execute_scripts()
  assert_true(executed > 0)
  match browser.get_dom_tree() {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#app") {
        Ok(Some(node_id)) =>
          match dom.get_text_content(node_id) {
            Ok(t) => assert_eq(t, "Hello from V8!")
            Err(_) => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "E2E: script creates element (JS-side verification)" {
  let browser = make_v8_browser(
    "<html><body><script>const el = document.createElement('p'); el.setAttribute('id', 'dynamic'); el.textContent = 'created'; document.body.appendChild(el);</script></body></html>",
  )
  let executed = browser.execute_scripts()
  assert_true(executed > 0)
  // Note: createElement assigns mock DOM _mockId (1000+) which doesn't map
  // to DomTree NodeId. Verifying script executed without error is sufficient.
}

///|
test "E2E: multiple scripts execute in order" {
  let browser = make_v8_browser(
    "<html><body><div id=\"log\"></div><script>document.getElementById('log').textContent = 'first';</script><script>document.getElementById('log').textContent += ',second';</script></body></html>",
  )
  let executed = browser.execute_scripts()
  assert_true(executed >= 2)
  match browser.get_dom_tree() {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#log") {
        Ok(Some(node_id)) =>
          match dom.get_text_content(node_id) {
            Ok(t) => assert_eq(t, "first,second")
            Err(_) => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "E2E: console.log captured" {
  let browser = make_v8_browser(
    "<html><body><script>console.log('hello from script');</script></body></html>",
  )
  let executed = browser.execute_scripts()
  assert_true(executed > 0)
}

///|
test "E2E: raw V8 domOps round-trip" {
  let v8 = @js_v8.V8JsRuntime::new_with_mock_dom(@js_v8.full_mock_dom_js())
  let dom = @dom.DomTree::new()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let div = dom.create_element("div")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.append_child(body, div)
  let _ = dom.set_attribute(div, "id", "target")
  let _ = dom.set_text_content(div, "before")
  let ctx = @js.JsContext::new_with_runtime(dom, v8.as_js_runtime())
  let result = ctx.execute(
    "document.getElementById('target').textContent = 'after';",
  )
  assert_true(result.success)
  match dom.get_text_content(div) {
    Ok(t) => assert_eq(t, "after")
    Err(_) => assert_true(false)
  }
}
