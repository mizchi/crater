// Shared helpers for taffy compatibility tests

///|
/// Default dispatch for taffy tests
pub fn default_dispatch() -> @node.DispatchFn {
  @node.DispatchFn(fn(node, ctx, dispatch) {
    match node.style.display {
      @types.Flex | @types.InlineFlex => @flex.compute(node, ctx, dispatch)
      @types.Grid | @types.InlineGrid => @grid.compute(node, ctx, dispatch)
      _ => @block.compute(node, ctx, dispatch)
    }
  })
}

///|
/// Helper for approximate floating point comparison (tolerance: 0.1)
pub fn assert_approx(actual : Double, expected : Double) -> Unit raise {
  let tolerance = 0.1
  let diff = if actual > expected {
    actual - expected
  } else {
    expected - actual
  }
  if diff > tolerance {
    raise Failure::Failure(
      "assert_approx failed: actual=\{actual}, expected=\{expected}, diff=\{diff}",
    )
  }
}
