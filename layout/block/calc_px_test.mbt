///|
/// Regression tests: a definite block width/height expressed with `calc()` (or
/// `min/max/clamp`) must include the absolute (px) term, not just the
/// percentage. Previously the `Calc(_, p)` / `MathFn` arms in the main block
/// resolution dropped px, so `width: calc(50% + 20px)` rendered as 50% only and
/// `width: 100px` (encoded as `Calc(100, 0)`) collapsed to 0.

///|
fn block_child_size(
  width : @types.Dimension,
  height : @types.Dimension,
) -> (Double, Double) {
  let default_style = @style.Style::default()
  let child_style = { ..default_style, width, height }
  let child = @node.Node::leaf("child", child_style)
  let root_style = {
    ..default_style,
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  }
  let root = @node.Node::new("root", root_style, [child])
  let ctx : @layout_types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(300.0),
    sizing_mode: @layout_types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = compute(root, ctx, default_dispatch())
  (layout.children[0].width, layout.children[0].height)
}

///|
test "block_calc_width_includes_px" {
  // width: calc(50% + 20px) against a 400px containing block -> 220.
  let (w, _) = block_child_size(@types.Calc(20.0, 0.5), @types.Length(10.0))
  inspect(w, content="220")
}

///|
test "block_calc_width_pure_px" {
  // width: 100px encoded as calc(100px + 0%) -> 100 (previously collapsed to 0).
  let (w, _) = block_child_size(@types.Calc(100.0, 0.0), @types.Length(10.0))
  inspect(w, content="100")
}

///|
test "block_calc_height_includes_px" {
  // height: calc(50% + 30px) against a 300px containing block -> 180.
  let (_, h) = block_child_size(@types.Length(50.0), @types.Calc(30.0, 0.5))
  inspect(h, content="180")
}

///|
test "block_mathfn_width_mixed_units" {
  // width: min(100px, 50%) against a 400px containing block -> min(100, 200) = 100.
  let (w, _) = block_child_size(
    @types.MathFn(@types.MathOp::Min, [(100.0, 0.0), (0.0, 0.5)]),
    @types.Length(10.0),
  )
  inspect(w, content="100")
}
