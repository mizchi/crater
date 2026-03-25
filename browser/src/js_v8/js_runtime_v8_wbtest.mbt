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
