///|
/// Tests for CSS math functions (min/max/clamp) resolved as `Dimension::MathFn`.
///
/// `resolve_inset` / `resolve_length_dimension` resolve a dimension against a
/// base that mixes px and percentage components (`px + pct * base`). For a
/// `MathFn`, each term is resolved to a length first and the min/max/clamp op
/// is applied over the resolved lengths. The mixed-unit cases below are the
/// ones that distinguish this from collapsing the px and percentage components
/// independently — e.g. `min(100px, 50%)` against a 400px base is
/// `min(100, 200) = 100`, not `min(100, 0) + min(0, 0.5) * 400 = 0`.

///|
test "mathfn_min_mixed_units" {
  // min(100px, 50%) against a 400 base -> min(100, 200) = 100.
  inspect(
    resolve_length_dimension(
      @types.MathFn(@types.MathOp::Min, [(100.0, 0.0), (0.0, 0.5)]),
      400.0,
    ),
    content="100",
  )
}

///|
test "mathfn_max_mixed_units" {
  // max(100px, 50%) against a 400 base -> max(100, 200) = 200.
  inspect(
    resolve_length_dimension(
      @types.MathFn(@types.MathOp::Max, [(100.0, 0.0), (0.0, 0.5)]),
      400.0,
    ),
    content="200",
  )
}

///|
test "mathfn_clamp_mixed_units" {
  // clamp(50px, 25%, 300px) against a 400 base -> clamp(50, 100, 300) = 100.
  inspect(
    resolve_length_dimension(
      @types.MathFn(@types.MathOp::Clamp, [
        (50.0, 0.0),
        (0.0, 0.25),
        (300.0, 0.0),
      ]),
      400.0,
    ),
    content="100",
  )
}

///|
test "mathfn_term_with_both_units" {
  // min(50% + 20px, 200px) against a 400 base -> min(220, 200) = 200.
  inspect(
    resolve_length_dimension(
      @types.MathFn(@types.MathOp::Min, [(20.0, 0.5), (200.0, 0.0)]),
      400.0,
    ),
    content="200",
  )
}

///|
test "mathfn_inset_returns_resolved_length" {
  // resolve_inset wraps the same resolution in Some(..).
  debug_inspect(
    resolve_inset(
      @types.MathFn(@types.MathOp::Min, [(20.0, 0.5), (200.0, 0.0)]),
      400.0,
    ),
    content="Some(200)",
  )
}
