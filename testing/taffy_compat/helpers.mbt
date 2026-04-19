// Shared helpers for taffy compatibility tests

///|
/// Default dispatch for taffy tests
pub fn default_dispatch() -> @node.DispatchFn {
  @node.DispatchFn(fn(node, ctx, dispatch) {
    match node.style.display {
      // Taffy defaults to Flex layout when display is not explicit.
      // Treat Block as Flex for compat tests to match taffy fixtures.
      @types.Flex | @types.InlineFlex | @types.Block =>
        @node.compute_flex_layout_with_dispatch(node, ctx, dispatch)
      @types.Grid | @types.InlineGrid =>
        @node.compute_grid_layout_in_context(node, ctx, dispatch)
      _ => @node.compute_block_layout_with_dispatch(node, ctx, dispatch)
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
