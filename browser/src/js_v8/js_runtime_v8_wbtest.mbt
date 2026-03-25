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
// Full mock DOM tests
// ============================================================

///|
test "V8+FullDOM: document.createElement with full mock" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0, dom,
    "const div = document.createElement('div'); div.setAttribute('id', 'test'); document.body.appendChild(div); return document.getElementById('test').tagName",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "DIV")
}

///|
test "V8+FullDOM: innerHTML and outerHTML" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0, dom,
    "const div = document.createElement('div'); div.textContent = 'hello'; return div.outerHTML",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_true(result.value.contains("hello"))
}

///|
test "V8+FullDOM: classList manipulation" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0, dom,
    "const el = document.createElement('div'); el.classList.add('a', 'b'); el.classList.remove('a'); return el.classList.contains('b') + ',' + el.classList.contains('a')",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "true,false")
}

///|
test "V8+FullDOM: querySelector and querySelectorAll" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0, dom,
    "const d1 = document.createElement('div'); d1.classList.add('item'); const d2 = document.createElement('div'); d2.classList.add('item'); document.body.appendChild(d1); document.body.appendChild(d2); return document.querySelectorAll('.item').length",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  assert_eq(result.value, "2")
}

///|
test "V8+FullDOM: Event dispatch" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  // Test basic addEventListener + dispatchEvent (not click bubbling which depends on full impl)
  let result = rt.execute(
    0, dom,
    "globalThis.__clicked = false; const btn = document.createElement('button'); btn.addEventListener('click', () => { globalThis.__clicked = true; }); btn.dispatchEvent(new Event('click'));",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  let check = rt.execute(
    0, dom, "return String(globalThis.__clicked)", @js.DeferredFlush,
  )
  assert_true(check.success)
  assert_eq(check.value, "true")
}

///|
test "V8+FullDOM: Promise.resolve chain" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  // V8 native Promises: test in single execute with globalThis capture
  let result = rt.execute(
    0, dom,
    "globalThis.__pResult2 = 'pending'; Promise.resolve('a').then(v => v + 'b').then(v => { globalThis.__pResult2 = v; });",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  // After ImmediateFlush, microtask checkpoint has run, so __pResult2 should be set
  // Read it back in a separate eval to confirm
  let check = rt.execute(
    0, dom, "return globalThis.__pResult2", @js.ImmediateFlush,
  )
  assert_true(check.success)
  assert_eq(check.value, "ab")
}

///|
test "V8+FullDOM: setTimeout with nested setTimeout" {
  let rt = V8JsRuntime::new_with_mock_dom(full_mock_dom_js())
  rt.init()
  let dom = @dom.DomTree::new()
  let result = rt.execute(
    0, dom,
    "globalThis.__timerOrder = []; setTimeout(() => { globalThis.__timerOrder.push('first'); setTimeout(() => globalThis.__timerOrder.push('nested'), 0); }, 0);",
    @js.ImmediateFlush,
  )
  assert_true(result.success)
  let check = rt.execute(
    0, dom, "return globalThis.__timerOrder.join(',')", @js.DeferredFlush,
  )
  assert_true(check.success)
  assert_eq(check.value, "first,nested")
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
