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
pub fn exact_display_dispatch() -> @node.DispatchFn {
  @node.DispatchFn(fn(node, ctx, dispatch) {
    match node.style.display {
      @types.Flex | @types.InlineFlex =>
        @node.compute_flex_layout_with_dispatch(node, ctx, dispatch)
      @types.Grid | @types.InlineGrid =>
        @node.compute_grid_layout_in_context(node, ctx, dispatch)
      _ => @node.compute_block_layout_with_dispatch(node, ctx, dispatch)
    }
  })
}

///|
/// Compute the root and descendants with their explicit display kind.
pub fn compute_root_layout(
  root : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  let dispatch = exact_display_dispatch()
  match root.style.display {
    @types.Flex | @types.InlineFlex =>
      @node.compute_flex_layout_with_dispatch(root, ctx, dispatch)
    @types.Grid | @types.InlineGrid =>
      @node.compute_grid_layout_in_context(root, ctx, dispatch)
    _ => @node.compute_block_layout_with_dispatch(root, ctx, dispatch)
  }
}

///|
pub fn compute_root_layout_size(
  root : @node.Node,
  width : Double,
  height : Double,
) -> @types.Layout {
  let ctx : @types.LayoutContext = {
    available_width: width,
    available_height: Some(height),
    sizing_mode: @types.MaxContent,
    viewport_width: width,
    viewport_height: height,
    stretch_width: false,
    stretch_height: false,
  }
  compute_root_layout(root, ctx)
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
