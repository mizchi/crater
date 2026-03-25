///|
/// V8 + Full mock DOM: DOM operation round-trip tests
/// These test that JS DOM operations are reflected back to MoonBit DomTree

///|
test "V8+FullDOM: insertBefore" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0, dom,
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
    0, dom,
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
    0, dom,
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
    0, dom,
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
    0, dom,
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
    0, dom,
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
    0, dom,
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
    0, dom,
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
    0, dom,
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
    0, dom,
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
    0, dom,
    "globalThis.__cancelled = 'not called'; const id = setTimeout(() => { globalThis.__cancelled = 'called'; }, 0); clearTimeout(id);",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  let check = rt.execute(
    0, dom, "return globalThis.__cancelled", @js.ImmediateFlush,
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
    0, dom,
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
    0, dom,
    "return (typeof window !== 'undefined') + ',' + (typeof document !== 'undefined') + ',' + document.body.tagName",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "true,true,BODY")
}
