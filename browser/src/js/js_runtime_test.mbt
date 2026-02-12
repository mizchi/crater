///|
/// Tests for JavaScript Runtime

///|
test "JsContext::new creates context with DOM" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  // Verify we can get DOM back
  let _ = ctx.get_dom()
}

///|
test "JsContext logs management" {
  let dom = @dom.DomTree::new()
  let ctx = JsContext::new(dom)
  inspect(ctx.get_logs().length(), content="0")
  ctx.clear_logs()
  inspect(ctx.get_logs().length(), content="0")
}

///|
/// Mock runtime for trait abstraction tests
priv struct MockRuntime {
  init_calls : Ref[Int]
}

///|
impl JsRuntime for MockRuntime with init(self : MockRuntime) -> Unit {
  self.init_calls.val = self.init_calls.val + 1
}

///|
impl JsRuntime for MockRuntime with execute(
  self : MockRuntime,
  dom : @dom.DomTree,
  code : String,
) -> JsResult raise JsError {
  let _ = self
  let _ = dom
  JsResult::new("mock:" + code, ["mock-log"], true)
}

///|
/// Mock runtime that returns failure result
priv struct FailRuntime {
  init_calls : Ref[Int]
}

///|
impl JsRuntime for FailRuntime with init(self : FailRuntime) -> Unit {
  self.init_calls.val = self.init_calls.val + 1
}

///|
impl JsRuntime for FailRuntime with execute(
  self : FailRuntime,
  dom : @dom.DomTree,
  code : String,
) -> JsResult raise JsError {
  let _ = self
  let _ = dom
  let _ = code
  JsResult::new("boom", ["before-fail"], false)
}

test "JsContext::new_with_runtime uses runtime trait for execution" {
  let dom = @dom.DomTree::new()
  let init_calls = Ref::new(0)
  let runtime : MockRuntime = { init_calls, }
  let ctx = JsContext::new_with_runtime(dom, runtime as &JsRuntime)
  let result = ctx.execute("1 + 2")
  inspect(result.success, content="true")
  inspect(result.value, content="mock:1 + 2")
  inspect(ctx.get_logs().length(), content="1")
  inspect(ctx.get_logs()[0], content="mock-log")
  inspect(init_calls.val, content="1")
}

///|
test "JsContext::execute raises ExecutionError when runtime returns failure" {
  let dom = @dom.DomTree::new()
  let init_calls = Ref::new(0)
  let runtime : FailRuntime = { init_calls, }
  let ctx = JsContext::new_with_runtime(dom, runtime as &JsRuntime)
  let err_text = try {
    let _ = ctx.execute("throw new Error('x')")
    ""
  } catch {
    err => err.to_string()
  }
  assert_true(err_text.contains("ExecutionError"))
  inspect(ctx.get_logs().length(), content="1")
  inspect(ctx.get_logs()[0], content="before-fail")
  inspect(init_calls.val, content="1")
}

///|
test "JsContext::execute calls runtime.init on each execution" {
  let dom = @dom.DomTree::new()
  let init_calls = Ref::new(0)
  let runtime : MockRuntime = { init_calls, }
  let ctx = JsContext::new_with_runtime(dom, runtime as &JsRuntime)
  let _ = ctx.execute("first")
  let _ = ctx.execute("second")
  inspect(ctx.get_logs().length(), content="2")
  inspect(init_calls.val, content="2")
}
