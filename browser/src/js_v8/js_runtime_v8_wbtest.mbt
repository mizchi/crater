///|
test "V8: simple expression" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(0, dom, "return 1 + 2", @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(result.value, "3")
}

///|
test "V8: console.log capture" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0, dom, "console.log('hello'); return 42", @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "42")
  assert_eq(result.logs.length(), 1)
  assert_eq(result.logs[0], "hello")
}

///|
test "V8: error handling" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(0, dom, "throw new Error('oops')", @js.ImmediateFlush)
  assert_false(result.success)
  assert_true(result.value.contains("oops"))
}

///|
test "V8: undefined return" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(0, dom, "let x = 1;", @js.ImmediateFlush)
  assert_true(result.success)
  assert_eq(result.value, "undefined")
}

///|
test "V8: multiple executions share state" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let _ = rt.execute(0, dom, "globalThis.__counter = 1;", @js.ImmediateFlush)
  let result = rt.execute(
    0, dom, "return globalThis.__counter + 1", @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "2")
}

///|
test "V8: JsContext integration" {
  let rt = V8JsRuntime::new()
  let dom = @dom.DomTree::new()
  let ctx = @js.JsContext::new_with_runtime(dom, rt.as_js_runtime())
  let result = ctx.execute("return 'hello from v8'")
  assert_true(result.success)
  assert_eq(result.value, "hello from v8")
}

// ============================================================
// Mock DOM tests
// ============================================================

///|
test "V8+DOM: document.createElement" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const div = document.createElement('div'); return div.tagName",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "DIV")
}

///|
test "V8+DOM: setAttribute and getAttribute" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const el = document.createElement('span'); el.setAttribute('class', 'test'); return el.getAttribute('class')",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "test")
}

///|
test "V8+DOM: appendChild and getElementById" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const div = document.createElement('div'); div.id = 'myDiv'; document.body.appendChild(div); return document.getElementById('myDiv').tagName",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "DIV")
}

///|
test "V8+DOM: textContent" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "const p = document.createElement('p'); p.textContent = 'Hello'; document.body.appendChild(p); return document.body.textContent",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "Hello")
}

///|
test "V8+DOM: addEventListener and click" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "let clicked = false; const btn = document.createElement('button'); btn.addEventListener('click', () => { clicked = true; }); btn.click(); return clicked",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "true")
}

///|
test "V8+DOM: Promise ordering" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  // Use globalThis to capture async results since return is synchronous
  let result = rt.execute(
    0,
    dom,
    "globalThis.__order = []; globalThis.__order.push('sync'); Promise.resolve().then(() => globalThis.__order.push('promise')); globalThis.__order.push('end');",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  // Now read the final order after microtask checkpoint
  let check = rt.execute(
    0, dom, "return globalThis.__order.join(',')", @js.DeferredFlush,
  )
  assert_true(check.success)
  assert_eq(check.value, "sync,end,promise")
}

///|
test "V8+DOM: setTimeout ordering" {
  let rt = V8JsRuntime::new_with_mock_dom(minimal_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "globalThis.__order2 = []; globalThis.__order2.push('sync'); setTimeout(() => globalThis.__order2.push('timeout'), 0); Promise.resolve().then(() => globalThis.__order2.push('promise')); globalThis.__order2.push('end');",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  let check = rt.execute(
    0, dom, "return globalThis.__order2.join(',')", @js.DeferredFlush,
  )
  assert_true(check.success)
  // sync → end → promise (microtask) → timeout (task)
  assert_eq(check.value, "sync,end,promise,timeout")
}

// ============================================================
// Basic tests (no mock DOM)
// ============================================================

///|
test "V8: multiple console.log" {
  let rt = V8JsRuntime::new()
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0,
    dom,
    "console.log('a'); console.log('b'); console.warn('w'); return 'ok'",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.logs.length(), 3)
  assert_eq(result.logs[0], "a")
  assert_eq(result.logs[1], "b")
  assert_eq(result.logs[2], "[WARN] w")
}
