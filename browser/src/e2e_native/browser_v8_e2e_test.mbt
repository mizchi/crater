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
test "E2E: script creates element (DomTree verification)" {
  let browser = make_v8_browser(
    "<html><body><script>const el = document.createElement('p'); el.setAttribute('id', 'dynamic'); el.textContent = 'created'; document.body.appendChild(el);</script></body></html>",
  )
  let executed = browser.execute_scripts()
  assert_true(executed > 0)
  // Verify the dynamically created element is in DomTree
  match browser.get_dom_tree() {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#dynamic") {
        Ok(Some(node_id)) => {
          match dom.get_tag_name(node_id) {
            Ok(tag) => assert_eq(tag, "p")
            Err(_) => assert_true(false)
          }
          match dom.get_text_content(node_id) {
            Ok(t) => assert_eq(t, "created")
            Err(_) => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "E2E: createElement + appendChild round-trip" {
  let browser = make_v8_browser(
    "<html><body><div id=\"container\"></div><script>const container = document.getElementById('container'); const child = document.createElement('div'); child.textContent = 'Hello from Preact'; container.appendChild(child); return container.innerHTML;</script></body></html>",
  )
  let executed = browser.execute_scripts()
  assert_true(executed > 0)
  match browser.get_dom_tree() {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#container") {
        Ok(Some(container_id)) =>
          match dom.get_children(container_id) {
            Ok(children) => {
              assert_true(children.length() > 0)
              match dom.get_text_content(children[0]) {
                Ok(t) => assert_eq(t, "Hello from Preact")
                Err(_) => assert_true(false)
              }
            }
            Err(_) => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
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
test "E2E: Preact-style render pattern" {
  let browser = make_v8_browser(
    "<html><body><div id=\"app\"></div><script>\nconst container = document.getElementById('app');\n// Simulate Preact's h() + render(): create a component tree\nconst wrapper = document.createElement('div');\nwrapper.setAttribute('class', 'component');\nconst heading = document.createElement('h1');\nheading.textContent = 'Hello';\nconst paragraph = document.createElement('p');\nparagraph.textContent = 'World';\nwrapper.appendChild(heading);\nwrapper.appendChild(paragraph);\ncontainer.appendChild(wrapper);\n</script></body></html>",
  )
  let executed = browser.execute_scripts()
  assert_true(executed > 0)
  match browser.get_dom_tree() {
    Some(dom) => {
      let doc = dom.get_document()
      // Verify the component wrapper exists
      match dom.query_selector(doc, ".component") {
        Ok(Some(wrapper_id)) =>
          match dom.get_children(wrapper_id) {
            Ok(children) => {
              assert_eq(children.length(), 2)
              // Verify h1
              match dom.get_tag_name(children[0]) {
                Ok(tag) => assert_eq(tag, "h1")
                Err(_) => assert_true(false)
              }
              match dom.get_text_content(children[0]) {
                Ok(t) => assert_eq(t, "Hello")
                Err(_) => assert_true(false)
              }
              // Verify p
              match dom.get_tag_name(children[1]) {
                Ok(tag) => assert_eq(tag, "p")
                Err(_) => assert_true(false)
              }
              match dom.get_text_content(children[1]) {
                Ok(t) => assert_eq(t, "World")
                Err(_) => assert_true(false)
              }
            }
            Err(_) => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
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

///|
test "E2E: Preact h() + render() basic component" {
  // Load Preact into V8, then render a simple component
  let preact_js = preact_bundle_js()
  let html = "<html><body><div id=\"app\"></div><script>" +
    preact_js +
    "\nconst { h, render } = globalThis.preact;\nrender(h('div', { class: 'greeting' }, h('h1', null, 'Hello'), h('p', null, 'from Preact')), document.getElementById('app'));\n</script></body></html>"
  let browser = make_v8_browser(html)
  let executed = browser.execute_scripts()
  assert_true(executed > 0)
  match browser.get_dom_tree() {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, ".greeting") {
        Ok(Some(wrapper_id)) =>
          match dom.get_children(wrapper_id) {
            Ok(children) => {
              assert_true(children.length() >= 2)
              match dom.get_tag_name(children[0]) {
                Ok(tag) => assert_eq(tag.to_upper(), "H1")
                Err(_) => assert_true(false)
              }
              match dom.get_text_content(children[0]) {
                Ok(t) => assert_eq(t, "Hello")
                Err(_) => assert_true(false)
              }
              match dom.get_tag_name(children[1]) {
                Ok(tag) => assert_eq(tag.to_upper(), "P")
                Err(_) => assert_true(false)
              }
              match dom.get_text_content(children[1]) {
                Ok(t) => assert_eq(t, "from Preact")
                Err(_) => assert_true(false)
              }
            }
            Err(_) => assert_true(false)
          }
        _ => fail("Could not find .greeting element in DomTree")
      }
    }
    None => assert_true(false)
  }
}

///|
test "E2E: Preact useState counter" {
  let preact_js = preact_bundle_js()
  let html = "<html><body><div id=\"app\"></div><script>" +
    preact_js +
    "\nconst { h, render } = globalThis.preact;\nconst { useState } = globalThis.preactHooks;\nfunction Counter() {\n  const [count, setCount] = useState(42);\n  return h('div', { id: 'counter' }, h('span', null, String(count)));\n}\nrender(h(Counter), document.getElementById('app'));\n</script></body></html>"
  let browser = make_v8_browser(html)
  let executed = browser.execute_scripts()
  assert_true(executed > 0)
  match browser.get_dom_tree() {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#counter") {
        Ok(Some(counter_id)) =>
          match dom.get_text_content(counter_id) {
            Ok(t) => assert_eq(t, "42")
            Err(_) => assert_true(false)
          }
        _ => fail("Could not find #counter element in DomTree")
      }
    }
    None => assert_true(false)
  }
}

///|
test "E2E: Preact render → Browser DOM sync → DomTree verification" {
  let preact_js = preact_bundle_js()
  let browser = make_v8_browser(
    "<html><body><div id=\"app\"></div><script>" +
    preact_js +
    "\nconst { h, render } = globalThis.preact;\nrender(h('div', { id: 'result' }, h('h1', null, 'Rendered by Preact')), document.getElementById('app'));\n</script></body></html>",
  )
  let executed = browser.execute_scripts()
  assert_true(executed > 0)
  // Verify DomTree contains Preact's rendered output
  match browser.get_dom_tree() {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#result") {
        Ok(Some(result_id)) => {
          match dom.get_children(result_id) {
            Ok(children) => {
              assert_true(children.length() >= 1)
              match dom.get_tag_name(children[0]) {
                Ok(tag) => assert_eq(tag.to_upper(), "H1")
                Err(_) => fail("Could not get h1 tag")
              }
              match dom.get_text_content(children[0]) {
                Ok(t) => assert_eq(t, "Rendered by Preact")
                Err(_) => fail("Could not get h1 text")
              }
            }
            Err(_) => fail("Could not get result children")
          }
        }
        _ => fail("Could not find #result in DomTree")
      }
    }
    None => fail("No DomTree")
  }
}

///|
test "E2E: Preact click → setState → re-render" {
  // Use raw V8 + DomTree for click simulation (Browser.script_executor is private)
  let preact_js = preact_bundle_js()
  let v8 = @js_v8.V8JsRuntime::new_with_mock_dom(@js_v8.full_mock_dom_js())
  let dom = @dom.DomTree::new()
  let html_el = dom.create_element("html")
  let body = dom.create_element("body")
  let app = dom.create_element("div")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html_el)
  let _ = dom.append_child(html_el, body)
  let _ = dom.append_child(body, app)
  let _ = dom.set_attribute(app, "id", "app")
  let ctx = @js.JsContext::new_with_runtime(dom, v8.as_js_runtime())
  // Load Preact and render counter component
  let init_code = preact_js +
    "\nconst { h, render } = globalThis.preact;\nconst { useState } = globalThis.preactHooks;\nfunction Counter() {\n  const [count, setCount] = useState(0);\n  return h('div', { id: 'counter' },\n    h('span', { id: 'display' }, String(count)),\n    h('button', { id: 'btn', onclick: () => setCount(c => c + 1) }, '+'));\n}\nrender(h(Counter), document.getElementById('app'));"
  let result = ctx.execute(init_code)
  assert_true(result.success)
  // Check initial render: count = 0
  let check0 = ctx.execute("return document.getElementById('display').textContent;")
  assert_true(check0.success)
  assert_eq(check0.value, "0")
  // Click the button
  let click_result = ctx.execute(
    "document.getElementById('btn').click();",
  )
  assert_true(click_result.success)
  // Check after click: count = 1
  let check1 = ctx.execute("return document.getElementById('display').textContent;")
  assert_true(check1.success)
  assert_eq(check1.value, "1")
  // Click again
  let _ = ctx.execute("document.getElementById('btn').click();")
  let check2 = ctx.execute("return document.getElementById('display').textContent;")
  assert_true(check2.success)
  assert_eq(check2.value, "2")
}

///|
/// Helper: create a V8 context with Preact loaded
fn make_preact_ctx() -> (@js.JsContext, @dom.DomTree) {
  let v8 = @js_v8.V8JsRuntime::new_with_mock_dom(@js_v8.full_mock_dom_js())
  let dom = @dom.DomTree::new()
  let html_el = dom.create_element("html")
  let body = dom.create_element("body")
  let app = dom.create_element("div")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html_el)
  let _ = dom.append_child(html_el, body)
  let _ = dom.append_child(body, app)
  let _ = dom.set_attribute(app, "id", "app")
  let ctx = @js.JsContext::new_with_runtime(dom, v8.as_js_runtime())
  let _ = try { ctx.execute(preact_bundle_js()) } catch { _ => @js.JsResult::new("", [], false) }
  (ctx, dom)
}

///|
test "E2E: Preact useEffect fires on mount" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|const { useState, useEffect } = globalThis.preactHooks;
      #|globalThis.__effectLog = [];
      #|function App() {
      #|  const [count] = useState(0);
      #|  useEffect(() => {
      #|    globalThis.__effectLog.push('mount:' + count);
      #|    return () => { globalThis.__effectLog.push('cleanup:' + count); };
      #|  }, [count]);
      #|  return h('div', { id: 'app-inner' }, String(count));
      #|}
      #|render(h(App), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  let check = ctx.execute("return globalThis.__effectLog.join(',');")
  assert_true(check.success)
  assert_eq(check.value, "mount:0")
}

///|
test "E2E: Preact useEffect cleanup on re-render" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|const { useState, useEffect } = globalThis.preactHooks;
      #|globalThis.__effectLog2 = [];
      #|globalThis.__setCount2 = null;
      #|function App() {
      #|  const [count, setCount] = useState(0);
      #|  globalThis.__setCount2 = setCount;
      #|  useEffect(() => {
      #|    globalThis.__effectLog2.push('mount:' + count);
      #|    return () => { globalThis.__effectLog2.push('cleanup:' + count); };
      #|  }, [count]);
      #|  return h('div', { id: 'val' }, String(count));
      #|}
      #|render(h(App), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  // Trigger re-render
  let r2 = ctx.execute("globalThis.__setCount2(1);")
  assert_true(r2.success)
  let check = ctx.execute("return globalThis.__effectLog2.join(',');")
  assert_true(check.success)
  assert_eq(check.value, "mount:0,cleanup:0,mount:1")
}

///|
test "E2E: Preact list rendering with keys" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|const { useState } = globalThis.preactHooks;
      #|globalThis.__setItems = null;
      #|function App() {
      #|  const [items, setItems] = useState(['A', 'B', 'C']);
      #|  globalThis.__setItems = setItems;
      #|  return h('ul', { id: 'list' },
      #|    items.map(item => h('li', { key: item }, item))
      #|  );
      #|}
      #|render(h(App), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  let check = ctx.execute(
    "return Array.from(document.getElementById('list').children).map(li => li.textContent).join(',');",
  )
  assert_true(check.success)
  assert_eq(check.value, "A,B,C")
  // Remove middle item
  let r2 = ctx.execute("globalThis.__setItems(['A', 'C']);")
  assert_true(r2.success)
  let check2 = ctx.execute(
    "return Array.from(document.getElementById('list').children).map(li => li.textContent).join(',');",
  )
  assert_true(check2.success)
  assert_eq(check2.value, "A,C")
  // Add item at beginning
  let r3 = ctx.execute("globalThis.__setItems(['Z', 'A', 'C']);")
  assert_true(r3.success)
  let check3 = ctx.execute(
    "return Array.from(document.getElementById('list').children).map(li => li.textContent).join(',');",
  )
  assert_true(check3.success)
  assert_eq(check3.value, "Z,A,C")
}

///|
test "E2E: Preact controlled input" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|const { useState } = globalThis.preactHooks;
      #|globalThis.__inputSetValue = null;
      #|function App() {
      #|  const [value, setValue] = useState('hello');
      #|  globalThis.__inputSetValue = setValue;
      #|  return h('div', { id: 'form' },
      #|    h('input', { id: 'inp', type: 'text', value: value,
      #|      oninput: (e) => setValue(e.target.value) }),
      #|    h('span', { id: 'mirror' }, value)
      #|  );
      #|}
      #|render(h(App), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  // Check initial value
  let check = ctx.execute("return document.getElementById('mirror').textContent;")
  assert_true(check.success)
  assert_eq(check.value, "hello")
  // Check input value attribute
  let check_input = ctx.execute(
    "return document.getElementById('inp').getAttribute('value') || document.getElementById('inp').value || '';",
  )
  assert_true(check_input.success)
  assert_eq(check_input.value, "hello")
  // Simulate typing by calling setValue directly
  let r2 = ctx.execute("globalThis.__inputSetValue('world');")
  assert_true(r2.success)
  let check2 = ctx.execute("return document.getElementById('mirror').textContent;")
  assert_true(check2.success)
  assert_eq(check2.value, "world")
}

///|
test "E2E: Preact conditional rendering" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|const { useState } = globalThis.preactHooks;
      #|globalThis.__setShow = null;
      #|function App() {
      #|  const [show, setShow] = useState(true);
      #|  globalThis.__setShow = setShow;
      #|  return h('div', { id: 'container' },
      #|    show ? h('p', { id: 'content' }, 'visible') : null,
      #|    h('span', { id: 'always' }, 'always here')
      #|  );
      #|}
      #|render(h(App), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  // Initially visible
  let check = ctx.execute(
    "return document.getElementById('content') ? 'found' : 'not found';",
  )
  assert_true(check.success)
  assert_eq(check.value, "found")
  // Hide
  let r2 = ctx.execute("globalThis.__setShow(false);")
  assert_true(r2.success)
  let check2 = ctx.execute(
    "return document.getElementById('content') ? 'found' : 'not found';",
  )
  assert_true(check2.success)
  assert_eq(check2.value, "not found")
  // always-visible element should still be there
  let check3 = ctx.execute(
    "return document.getElementById('always').textContent;",
  )
  assert_true(check3.success)
  assert_eq(check3.value, "always here")
  // Show again
  let r3 = ctx.execute("globalThis.__setShow(true);")
  assert_true(r3.success)
  let check4 = ctx.execute(
    "return document.getElementById('content') ? document.getElementById('content').textContent : 'gone';",
  )
  assert_true(check4.success)
  assert_eq(check4.value, "visible")
}
