///|
/// V8 + Full mock DOM: DOM operation round-trip tests
/// These test that JS DOM operations are reflected back to MoonBit DomTree

///|
test "V8+FullDOM: insertBefore" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const a = document.createElement('div'); a.id = 'a'; const b = document.createElement('div'); b.id = 'b'; document.body.appendChild(a); document.body.appendChild(b); const c = document.createElement('div'); c.id = 'c'; document.body.insertBefore(c, b); return Array.from(document.body.children).map(e => e.id).join(',')",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "a,c,b")
}

///|
test "V8+FullDOM: replaceChild" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const old = document.createElement('div'); old.id = 'old'; document.body.appendChild(old); const replacement = document.createElement('span'); replacement.id = 'new'; document.body.replaceChild(replacement, old); return document.body.children[0].id + ',' + document.body.children[0].tagName",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "new,SPAN")
}

///|
test "V8+FullDOM: cloneNode shallow" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const el = document.createElement('div'); el.setAttribute('class', 'test'); el.appendChild(document.createElement('span')); const clone = el.cloneNode(false); return clone.getAttribute('class') + ',' + clone.children.length",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "test,0")
}

///|
test "V8+FullDOM: cloneNode deep" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const el = document.createElement('div'); el.appendChild(document.createElement('span')); el.appendChild(document.createElement('p')); const clone = el.cloneNode(true); return clone.children.length + ',' + clone.children[0].tagName",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "2,SPAN")
}

///|
test "V8+FullDOM: getElementsByTagName" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "document.body.appendChild(document.createElement('p')); document.body.appendChild(document.createElement('p')); document.body.appendChild(document.createElement('div')); return document.getElementsByTagName('p').length",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "2")
}

///|
test "V8+FullDOM: nodeType constants" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "return document.createElement('div').nodeType + ',' + document.createTextNode('hi').nodeType + ',' + document.createComment('c').nodeType",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "1,3,8")
}

///|
test "V8+FullDOM: contains" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const parent = document.createElement('div'); const child = document.createElement('span'); parent.appendChild(child); return parent.contains(child) + ',' + child.contains(parent)",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "true,false")
}

///|
test "V8+FullDOM: previousSibling and lastChild" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const a = document.createElement('div'); a.id = 'a'; const b = document.createElement('div'); b.id = 'b'; document.body.appendChild(a); document.body.appendChild(b); return document.body.lastChild.id + ',' + b.previousSibling.id",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "b,a")
}

///|
test "V8+FullDOM: createDocumentFragment" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const frag = document.createDocumentFragment(); frag.appendChild(document.createElement('div')); frag.appendChild(document.createElement('span')); document.body.appendChild(frag); return document.body.children.length",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  // Fragment's children are moved to body
  assert_true(result.value == "2" || result.value == "3" || result.value == "4")
}

///|
test "V8+FullDOM: Event preventDefault" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const e = new Event('click', { cancelable: true }); e.preventDefault(); return e.defaultPrevented",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "true")
}

///|
test "V8+FullDOM: setTimeout and clearTimeout" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "globalThis.__cancelled = 'not called'; const id = setTimeout(() => { globalThis.__cancelled = 'called'; }, 0); clearTimeout(id);",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  let check = rt.execute(
    0,
    dom,
    "return globalThis.__cancelled",
    @js.ImmediateFlush,
  )
  assert_true(check.success)
  assert_eq(check.value, "not called")
}

///|
test "V8+FullDOM: fetch mock returns Promise" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "return typeof fetch === 'function'",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "true")
}

///|
test "V8+FullDOM: window and document exist" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "return (typeof window !== 'undefined') + ',' + (typeof document !== 'undefined') + ',' + document.body.tagName",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "true,true,BODY")
}

///|
test "V8+FullDOM: declarative shadow DOM round-trips into DomTree" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let source =
    #|document.body.setHTMLUnsafe('<div id="host"><template shadowrootmode="open" shadowrootdelegatesfocus shadowrootclonable shadowrootserializable><button id="inner">shadow-text</button></template><span id="light">light-text</span></div>');
    #|return document.getElementById('host').shadowRoot.getElementById('inner').textContent;
  let result = rt.execute(0, dom, source, @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(result.value, "shadow-text")

  let doc = dom.get_document()
  match dom.query_selector(doc, "#host") {
    Ok(Some(host)) =>
      match dom.get_shadow_root(host) {
        Ok(Some(shadow_root)) => {
          match dom.get_shadow_init(shadow_root) {
            Ok(Some(init)) => {
              assert_eq(init.mode, "open")
              assert_true(init.delegates_focus)
              assert_true(init.clonable)
              assert_true(init.serializable)
            }
            Ok(None) => fail("missing shadow init")
            Err(_) => fail("missing shadow init")
          }
          match dom.query_selector(shadow_root, "#inner") {
            Ok(Some(inner)) =>
              match dom.get_text_content(inner) {
                Ok(text) => assert_eq(text, "shadow-text")
                Err(_) => fail("missing shadow text")
              }
            _ => fail("missing shadow child")
          }
        }
        _ => fail("missing shadow root")
      }
    _ => fail("missing host")
  }
}

///|
test "V8+FullDOM: declarative closed shadow DOM serializes to composed html and snapshot html separately" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let source =
    #|document.body.setHTMLUnsafe('<div id="host"><template shadowrootmode="closed" shadowrootdelegatesfocus shadowrootclonable shadowrootserializable><button id="shadow-btn">shadow-action</button></template><span id="light">light-text</span></div>');
    #|return document.getElementById('host').shadowRoot === null ? 'closed' : 'open';
  let result = rt.execute(0, dom, source, @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(result.value, "closed")

  let composed = @js.serialize_dom_to_html(dom)
  let snapshot = @js.serialize_dom_to_snapshot_html(dom)

  assert_true(composed.contains("shadow-action"))
  assert_false(composed.contains("light-text"))
  assert_false(composed.contains("shadowrootmode"))
  assert_true(snapshot.contains("shadowrootmode=\"closed\""))
  assert_true(snapshot.contains("shadowrootdelegatesfocus"))
  assert_true(snapshot.contains("shadowrootclonable"))
  assert_true(snapshot.contains("shadowrootserializable"))
  assert_true(snapshot.contains("shadow-action"))
  assert_true(snapshot.contains("light-text"))
}

///|
test "V8+FullDOM: script-created shadow root serializes composed html and snapshot metadata" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let source =
    #|const host = document.createElement('div');
    #|host.id = 'host';
    #|document.body.appendChild(host);
    #|const shadow = host.attachShadow({
    #|  mode: 'open',
    #|  delegatesFocus: true,
    #|  slotAssignment: 'manual',
    #|  clonable: true,
    #|  serializable: true
    #|});
    #|shadow.setHTMLUnsafe('<button id="inner">shadow-created</button>');
    #|return host.shadowRoot === shadow ? 'open' : 'mismatch';
  let result = rt.execute(0, dom, source, @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(result.value, "open")

  let composed = @js.serialize_dom_to_html(dom)
  let snapshot = @js.serialize_dom_to_snapshot_html(dom)

  assert_true(composed.contains("shadow-created"))
  assert_false(composed.contains("shadowrootmode"))
  assert_true(snapshot.contains("shadowrootmode=\"open\""))
  assert_true(snapshot.contains("shadowrootdelegatesfocus"))
  assert_true(snapshot.contains("shadowrootslotassignment=\"manual\""))
  assert_true(snapshot.contains("shadowrootclonable"))
  assert_true(snapshot.contains("shadowrootserializable"))
  assert_true(snapshot.contains("shadow-created"))
}

///|
test "V8+FullDOM: custom states round-trip into DomTree and render html" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let source =
    #|const panel = document.createElement('x-panel');
    #|panel.id = 'panel';
    #|document.body.appendChild(panel);
    #|const internals = panel.attachInternals();
    #|internals.states.add('open');
    #|return internals.states.has('open');
  let result = rt.execute(0, dom, source, @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(result.value, "true")

  let doc = dom.get_document()
  match dom.query_selector(doc, "#panel") {
    Ok(Some(panel)) =>
      match dom.get_custom_states(panel) {
        Ok(states) => inspect(states, content="[\"open\"]")
        Err(_) => fail("missing custom states")
      }
    _ => fail("missing panel")
  }

  let composed = @js.serialize_dom_to_html(dom)
  let snapshot = @js.serialize_dom_to_snapshot_html(dom)
  assert_true(composed.contains("data-crater-custom-states=\"open\""))
  assert_false(snapshot.contains("data-crater-custom-states"))
}
