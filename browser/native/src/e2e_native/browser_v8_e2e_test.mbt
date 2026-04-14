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
        Ok(Some(result_id)) =>
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
        _ => fail("Could not find #result in DomTree")
      }
    }
    None => fail("No DomTree")
  }
}

///|
test "E2E: Preact style object → CSS string" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|render(h('div', {
      #|  id: 'styled',
      #|  style: { color: 'red', fontSize: '20px', backgroundColor: 'blue' }
      #|}, 'hello'), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  // Preact should convert style object to CSS string on the element
  let check = ctx.execute(
    "const el = document.getElementById('styled'); return el.style ? el.style.cssText || el.getAttribute('style') || '' : '';",
  )
  assert_true(check.success)
  // Should contain CSS properties
  assert_true(check.value.contains("color"))
  assert_true(check.value.contains("red"))
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
  let check0 = ctx.execute(
    "return document.getElementById('display').textContent;",
  )
  assert_true(check0.success)
  assert_eq(check0.value, "0")
  // Click the button
  let click_result = ctx.execute("document.getElementById('btn').click();")
  assert_true(click_result.success)
  // Check after click: count = 1
  let check1 = ctx.execute(
    "return document.getElementById('display').textContent;",
  )
  assert_true(check1.success)
  assert_eq(check1.value, "1")
  // Click again
  let _ = ctx.execute("document.getElementById('btn').click();")
  let check2 = ctx.execute(
    "return document.getElementById('display').textContent;",
  )
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
  let _ = ctx.execute(preact_bundle_js()) catch {
    _ => @js.JsResult::new("", [], false)
  }
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
  let check = ctx.execute(
    "return document.getElementById('mirror').textContent;",
  )
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
  let check2 = ctx.execute(
    "return document.getElementById('mirror').textContent;",
  )
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

///|
test "E2E: Real-world script: zenn.dev theme switcher" {
  let (ctx, _dom) = make_preact_ctx()
  // zenn.dev's theme switching script — no polyfills needed, mock DOM has all APIs
  let result = ctx.execute(
    (
      #|// Run the actual zenn.dev theme script
      #|function getSystemTheme() {
      #|  if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      #|    return 'dark-blue';
      #|  }
      #|  return 'light';
      #|}
      #|function applyTheme(theme) {
      #|  let actualTheme;
      #|  if (theme === 'system') {
      #|    actualTheme = getSystemTheme();
      #|  } else {
      #|    actualTheme = theme;
      #|  }
      #|  window.document.documentElement.dataset.theme = actualTheme;
      #|}
      #|const storedTheme = localStorage.getItem('theme');
      #|const theme = storedTheme || 'system';
      #|applyTheme(theme);
      #|return document.documentElement.dataset.theme;
    ),
  )
  assert_true(result.success)
  // System theme → matchMedia returns false → light theme
  assert_eq(result.value, "light")
}

///|
test "E2E: Next.js webpack bootstrap runs without error" {
  let (ctx, _dom) = make_preact_ctx()
  // No polyfills needed — mock DOM provides all browser APIs
  let setup = ctx.execute(
    (
      #|// webpack chunk array (Next.js specific, not a browser API)
      #|self.webpackChunk_N_E = self.webpackChunk_N_E || [];
      #|return 'setup ok';
    ),
  )
  assert_true(setup.success)
  // Next.js SSG/BUILD manifest
  let manifest = ctx.execute(
    (
      #|self.__SSG_MANIFEST=new Set;
      #|self.__SSG_MANIFEST_CB&&self.__SSG_MANIFEST_CB();
      #|return 'manifests ok';
    ),
  )
  assert_true(manifest.success)
  // Verify webpack chunk array is ready
  let check = ctx.execute(
    "return Array.isArray(self.webpackChunk_N_E) ? 'ready' : 'not ready';",
  )
  assert_eq(check.value, "ready")
}

///|
test "E2E: Dynamic vanilla JS app - createElement + addEventListener + re-render" {
  let html = "<html><body><div id=\"app\"></div><script>\nconst state = { todos: [{id:1,text:'Buy groceries',done:false},{id:2,text:'Walk the dog',done:true},{id:3,text:'Write code',done:false}], nextId:4 };\nfunction render() {\n  const app = document.getElementById('app');\n  while (app.firstChild) app.removeChild(app.firstChild);\n  const h1 = document.createElement('h1'); h1.textContent = 'Todo'; app.appendChild(h1);\n  const count = document.createElement('div'); count.id = 'count';\n  count.textContent = state.todos.filter(t=>!t.done).length + ' remaining';\n  app.appendChild(count);\n  const list = document.createElement('ul'); list.id = 'list';\n  state.todos.forEach(todo => {\n    const li = document.createElement('li');\n    li.setAttribute('class', todo.done ? 'done' : '');\n    li.textContent = todo.text;\n    const del = document.createElement('button'); del.textContent = 'x';\n    del.addEventListener('click', () => { state.todos = state.todos.filter(t=>t.id!==todo.id); render(); });\n    li.appendChild(del); list.appendChild(li);\n  });\n  app.appendChild(list);\n}\nrender();\n</script></body></html>"
  let browser = make_v8_browser(html)
  let executed = browser.execute_scripts()
  assert_true(executed > 0)
  match browser.get_dom_tree() {
    Some(dom) => {
      let doc = dom.get_document()
      match dom.query_selector(doc, "#list") {
        Ok(Some(list_id)) =>
          match dom.get_children(list_id) {
            Ok(children) => assert_eq(children.length(), 3)
            Err(_) => fail("Could not get list children")
          }
        _ => fail("Could not find #list")
      }
      match dom.query_selector(doc, "#count") {
        Ok(Some(count_id)) =>
          match dom.get_text_content(count_id) {
            Ok(t) => assert_eq(t, "2 remaining")
            Err(_) => fail("Could not get count text")
          }
        _ => fail("Could not find #count")
      }
    }
    None => fail("No DomTree")
  }
}

///|
test "E2E: SPA router simulation (history + DOM swap)" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|const { useState } = globalThis.preactHooks;
      #|
      #|const routes = {
      #|  '/': () => h('div', { id: 'page' }, h('h1', null, 'Home'), h('p', null, 'Welcome')),
      #|  '/about': () => h('div', { id: 'page' }, h('h1', null, 'About'), h('p', null, 'About us')),
      #|  '/contact': () => h('div', { id: 'page' }, h('h1', null, 'Contact'), h('p', null, 'Contact form')),
      #|};
      #|
      #|globalThis.__navigate = null;
      #|function App() {
      #|  const [path, setPath] = useState('/');
      #|  globalThis.__navigate = setPath;
      #|  const Page = routes[path] || routes['/'];
      #|  return h('div', { id: 'app-root' },
      #|    h('nav', { id: 'nav' },
      #|      h('a', { href: '#', onclick: (e) => { e.preventDefault && e.preventDefault(); setPath('/'); } }, 'Home'),
      #|      h('a', { href: '#', onclick: (e) => { e.preventDefault && e.preventDefault(); setPath('/about'); } }, 'About'),
      #|      h('a', { href: '#', onclick: (e) => { e.preventDefault && e.preventDefault(); setPath('/contact'); } }, 'Contact')
      #|    ),
      #|    h(Page)
      #|  );
      #|}
      #|render(h(App), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  // Home page
  let h1 = ctx.execute("return document.querySelector('h1').textContent;")
  assert_eq(h1.value, "Home")
  // Navigate to About
  let _ = ctx.execute("globalThis.__navigate('/about');")
  let h2 = ctx.execute("return document.querySelector('h1').textContent;")
  assert_eq(h2.value, "About")
  let p2 = ctx.execute("return document.querySelector('p').textContent;")
  assert_eq(p2.value, "About us")
  // Navigate to Contact
  let _ = ctx.execute("globalThis.__navigate('/contact');")
  let h3 = ctx.execute("return document.querySelector('h1').textContent;")
  assert_eq(h3.value, "Contact")
  // Back to Home
  let _ = ctx.execute("globalThis.__navigate('/');")
  let h4 = ctx.execute("return document.querySelector('h1').textContent;")
  assert_eq(h4.value, "Home")
}

///|
test "E2E: Complex nested component tree with dynamic updates" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|const { useState } = globalThis.preactHooks;
      #|
      #|function Badge({ count }) { return h('span', { class: 'badge' }, '(' + count + ')'); }
      #|function Tab({ label, count, active, onClick }) {
      #|  return h('button', { class: active ? 'tab active' : 'tab', onclick: onClick },
      #|    label, ' ', h(Badge, { count }));
      #|}
      #|function TabPanel({ children }) { return h('div', { class: 'panel', id: 'panel' }, children); }
      #|
      #|const tabData = {
      #|  inbox: ['Message 1', 'Message 2', 'Message 3'],
      #|  sent: ['Sent A'],
      #|  drafts: ['Draft X', 'Draft Y'],
      #|};
      #|
      #|function MailApp() {
      #|  const [tab, setTab] = useState('inbox');
      #|  globalThis.__setTab = setTab;
      #|  const items = tabData[tab] || [];
      #|  return h('div', { id: 'mail' },
      #|    h('div', { id: 'tabs' },
      #|      h(Tab, { label: 'Inbox', count: tabData.inbox.length, active: tab === 'inbox', onClick: () => setTab('inbox') }),
      #|      h(Tab, { label: 'Sent', count: tabData.sent.length, active: tab === 'sent', onClick: () => setTab('sent') }),
      #|      h(Tab, { label: 'Drafts', count: tabData.drafts.length, active: tab === 'drafts', onClick: () => setTab('drafts') })
      #|    ),
      #|    h(TabPanel, null, items.map((m, i) => h('div', { key: i, class: 'mail-item' }, m)))
      #|  );
      #|}
      #|render(h(MailApp), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  // Inbox: 3 messages
  let panel = ctx.execute(
    "return document.getElementById('panel').children.length;",
  )
  assert_eq(panel.value, "3")
  // Switch to Sent: 1 message
  let _ = ctx.execute("globalThis.__setTab('sent');")
  let sent = ctx.execute(
    "return document.getElementById('panel').children.length;",
  )
  assert_eq(sent.value, "1")
  let msg = ctx.execute(
    "return document.getElementById('panel').children[0].textContent;",
  )
  assert_eq(msg.value, "Sent A")
  // Switch to Drafts: 2 messages
  let _ = ctx.execute("globalThis.__setTab('drafts');")
  let drafts = ctx.execute(
    "return document.getElementById('panel').children.length;",
  )
  assert_eq(drafts.value, "2")
}

///|
test "E2E: Preact TODO app - full CRUD" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|const { useState } = globalThis.preactHooks;
      #|
      #|function TodoApp() {
      #|  const [todos, setTodos] = useState([
      #|    { id: 1, text: 'Learn Preact', done: false },
      #|    { id: 2, text: 'Build app', done: false }
      #|  ]);
      #|  const [nextId, setNextId] = useState(3);
      #|
      #|  globalThis.__addTodo = (text) => {
      #|    setTodos(prev => [...prev, { id: nextId, text, done: false }]);
      #|    setNextId(n => n + 1);
      #|  };
      #|  globalThis.__toggleTodo = (id) => {
      #|    setTodos(prev => prev.map(t => t.id === id ? { ...t, done: !t.done } : t));
      #|  };
      #|  globalThis.__deleteTodo = (id) => {
      #|    setTodos(prev => prev.filter(t => t.id !== id));
      #|  };
      #|
      #|  return h('div', { id: 'todo-app' },
      #|    h('h1', null, 'TODO (' + todos.filter(t => !t.done).length + ' remaining)'),
      #|    h('ul', { id: 'todo-list' },
      #|      todos.map(todo =>
      #|        h('li', { key: todo.id, class: todo.done ? 'done' : '' },
      #|          h('span', { class: 'text' }, todo.text),
      #|          h('button', { class: 'toggle', onclick: () => globalThis.__toggleTodo(todo.id) },
      #|            todo.done ? '✓' : '○'),
      #|          h('button', { class: 'delete', onclick: () => globalThis.__deleteTodo(todo.id) }, '×')
      #|        )
      #|      )
      #|    )
      #|  );
      #|}
      #|render(h(TodoApp), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  // Verify initial render: 2 todos
  let check_count = ctx.execute(
    "return document.getElementById('todo-list').children.length;",
  )
  assert_true(check_count.success)
  assert_eq(check_count.value, "2")
  // Verify header shows "2 remaining"
  let check_header = ctx.execute(
    "return document.querySelector('h1').textContent;",
  )
  assert_true(check_header.success)
  assert_eq(check_header.value, "TODO (2 remaining)")
  // Add a todo
  let r_add = ctx.execute("globalThis.__addTodo('Write tests');")
  assert_true(r_add.success)
  let check_add = ctx.execute(
    "return document.getElementById('todo-list').children.length;",
  )
  assert_true(check_add.success)
  assert_eq(check_add.value, "3")
  // Toggle first todo (mark as done)
  let r_toggle = ctx.execute("globalThis.__toggleTodo(1);")
  assert_true(r_toggle.success)
  let check_toggle = ctx.execute(
    "return document.querySelector('h1').textContent;",
  )
  assert_true(check_toggle.success)
  assert_eq(check_toggle.value, "TODO (2 remaining)")
  // Check the toggled item has 'done' class
  let check_class = ctx.execute(
    "return document.getElementById('todo-list').children[0].getAttribute('class');",
  )
  assert_true(check_class.success)
  assert_eq(check_class.value, "done")
  // Delete second todo
  let r_delete = ctx.execute("globalThis.__deleteTodo(2);")
  assert_true(r_delete.success)
  let check_delete = ctx.execute(
    "return document.getElementById('todo-list').children.length;",
  )
  assert_true(check_delete.success)
  assert_eq(check_delete.value, "2")
  // Verify remaining items text
  let check_texts = ctx.execute(
    "return Array.from(document.getElementById('todo-list').children).map(li => li.querySelector('.text').textContent).join(',');",
  )
  assert_true(check_texts.success)
  assert_eq(check_texts.value, "Learn Preact,Write tests")
}

///|
test "E2E: Preact parent-child component communication" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|const { useState } = globalThis.preactHooks;
      #|
      #|function Child({ value, onChange }) {
      #|  return h('button', { id: 'child-btn', onclick: () => onChange(value + 1) },
      #|    'Count: ' + value);
      #|}
      #|
      #|function Parent() {
      #|  const [count, setCount] = useState(0);
      #|  return h('div', { id: 'parent' },
      #|    h('span', { id: 'parent-display' }, 'Parent sees: ' + count),
      #|    h(Child, { value: count, onChange: setCount })
      #|  );
      #|}
      #|render(h(Parent), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  // Initial: count = 0
  let c0 = ctx.execute(
    "return document.getElementById('parent-display').textContent;",
  )
  assert_eq(c0.value, "Parent sees: 0")
  let b0 = ctx.execute(
    "return document.getElementById('child-btn').textContent;",
  )
  assert_eq(b0.value, "Count: 0")
  // Click child button → triggers onChange(1) → parent re-renders
  let _ = ctx.execute("document.getElementById('child-btn').click();")
  let c1 = ctx.execute(
    "return document.getElementById('parent-display').textContent;",
  )
  assert_eq(c1.value, "Parent sees: 1")
  let b1 = ctx.execute(
    "return document.getElementById('child-btn').textContent;",
  )
  assert_eq(b1.value, "Count: 1")
}

///|
test "E2E: Preact useEffect async data loading pattern" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|const { useState, useEffect } = globalThis.preactHooks;
      #|
      #|// Simulate async data fetch
      #|globalThis.__mockFetch = (url) => {
      #|  return Promise.resolve({ json: () => Promise.resolve({ items: ['alpha', 'beta', 'gamma'] }) });
      #|};
      #|
      #|function DataList() {
      #|  const [items, setItems] = useState([]);
      #|  const [loading, setLoading] = useState(true);
      #|
      #|  useEffect(() => {
      #|    globalThis.__mockFetch('/api/items')
      #|      .then(r => r.json())
      #|      .then(data => { setItems(data.items); setLoading(false); });
      #|  }, []);
      #|
      #|  if (loading) return h('div', { id: 'status' }, 'Loading...');
      #|  return h('ul', { id: 'data-list' },
      #|    items.map((item, i) => h('li', { key: i }, item))
      #|  );
      #|}
      #|render(h(DataList), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  // useEffect runs after render, Promise needs extra microtask flush
  for i = 0; i < 10; i = i + 1 {
    ignore(
      ctx.execute(
        "typeof _flushMicrotasks === 'function' ? _flushMicrotasks() : null; return 'ok';",
      ),
    )
  }
  let check = ctx.execute(
    "return document.getElementById('data-list') ? Array.from(document.getElementById('data-list').children).map(li => li.textContent).join(',') : document.getElementById('status') ? document.getElementById('status').textContent : 'unknown';",
  )
  assert_true(check.success)
  assert_eq(check.value, "alpha,beta,gamma")
}

///|
test "E2E: Preact className and DOM property access" {
  let (ctx, _dom) = make_preact_ctx()
  let result = ctx.execute(
    (
      #|const { h, render } = globalThis.preact;
      #|const { useState } = globalThis.preactHooks;
      #|globalThis.__setActive = null;
      #|function App() {
      #|  const [active, setActive] = useState(false);
      #|  globalThis.__setActive = setActive;
      #|  return h('div', {
      #|    id: 'target',
      #|    class: active ? 'active highlight' : 'inactive',
      #|    'data-state': active ? 'on' : 'off'
      #|  }, active ? 'ON' : 'OFF');
      #|}
      #|render(h(App), document.getElementById('app'));
    ),
  )
  assert_true(result.success)
  // Initial: inactive
  let c0 = ctx.execute(
    "return document.getElementById('target').getAttribute('class');",
  )
  assert_eq(c0.value, "inactive")
  let d0 = ctx.execute(
    "return document.getElementById('target').getAttribute('data-state');",
  )
  assert_eq(d0.value, "off")
  let t0 = ctx.execute("return document.getElementById('target').textContent;")
  assert_eq(t0.value, "OFF")
  // Toggle to active
  let _ = ctx.execute("globalThis.__setActive(true);")
  let c1 = ctx.execute(
    "return document.getElementById('target').getAttribute('class');",
  )
  assert_eq(c1.value, "active highlight")
  let d1 = ctx.execute(
    "return document.getElementById('target').getAttribute('data-state');",
  )
  assert_eq(d1.value, "on")
  let t1 = ctx.execute("return document.getElementById('target').textContent;")
  assert_eq(t1.value, "ON")
}

///|
/// Helper: create a V8 context with React loaded
fn make_react_ctx() -> (@js.JsContext, @dom.DomTree) {
  let v8 = @js_v8.V8JsRuntime::new_with_mock_dom(@js_v8.full_mock_dom_js())
  let dom = @dom.DomTree::new()
  let html_el = dom.create_element("html")
  let body = dom.create_element("body")
  let app = dom.create_element("div")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html_el)
  let _ = dom.append_child(html_el, body)
  let _ = dom.append_child(body, app)
  let _ = dom.set_attribute(app, "id", "root")
  let ctx = @js.JsContext::new_with_runtime(dom, v8.as_js_runtime())
  let r = ctx.execute(react_bundle_js()) catch {
    _ => @js.JsResult::new("", [], false)
  }
  if !r.success {
    println("[React init error] " + r.value)
  }
  (ctx, dom)
}

///|
test "E2E: React basic render" {
  let (ctx, _dom) = make_react_ctx()
  let result = ctx.execute(
    (
      #|const root = globalThis.ReactDOM.createRoot(document.getElementById('root'));
      #|root.render(globalThis.React.createElement('div', { id: 'hello' }, 'Hello from React'));
    ),
  )
  assert_true(result.success)
  // React batches updates, flush microtasks
  for i = 0; i < 20; i = i + 1 {
    ignore(
      ctx.execute(
        "typeof _flushMicrotasks === 'function' ? _flushMicrotasks() : null;",
      ),
    )
  }
  let check = ctx.execute(
    "return document.getElementById('hello') ? document.getElementById('hello').textContent : 'NOT FOUND';",
  )
  assert_true(check.success)
  assert_eq(check.value, "Hello from React")
}

///|
test "E2E: React useState counter" {
  let (ctx, _dom) = make_react_ctx()
  let result = ctx.execute(
    (
      #|const { createElement: h, useState } = globalThis.React;
      #|function Counter() {
      #|  const [count, setCount] = useState(0);
      #|  return h('div', { id: 'counter' },
      #|    h('span', { id: 'count' }, String(count)),
      #|    h('button', { id: 'inc', onClick: () => setCount(c => c + 1) }, '+')
      #|  );
      #|}
      #|const root = globalThis.ReactDOM.createRoot(document.getElementById('root'));
      #|root.render(h(Counter));
    ),
  )
  assert_true(result.success)
  for i = 0; i < 20; i = i + 1 {
    ignore(
      ctx.execute(
        "typeof _flushMicrotasks === 'function' ? _flushMicrotasks() : null;",
      ),
    )
  }
  // Check initial render
  let c0 = ctx.execute(
    "return document.getElementById('count') ? document.getElementById('count').textContent : 'NOT FOUND';",
  )
  assert_true(c0.success)
  assert_eq(c0.value, "0")
  // Click to increment
  let _ = ctx.execute("document.getElementById('inc').click();")
  for i = 0; i < 20; i = i + 1 {
    ignore(
      ctx.execute(
        "typeof _flushMicrotasks === 'function' ? _flushMicrotasks() : null;",
      ),
    )
  }
  let c1 = ctx.execute("return document.getElementById('count').textContent;")
  assert_true(c1.success)
  assert_eq(c1.value, "1")
}
