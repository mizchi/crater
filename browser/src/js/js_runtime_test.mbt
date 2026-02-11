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
