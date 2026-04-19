///|
test "compute_justify benchmark" (b : @bench.T) {
  b.bench(fn() { ignore(compute_justify(@types.SpaceAround, 300.0, 12)) })
}

///|
test "resolve_relative_inset_offsets benchmark" (b : @bench.T) {
  let inset : @types.Rect[@types.Dimension] = {
    left: @types.Dimension::Auto,
    right: @types.Percent(0.1),
    top: @types.Percent(0.25),
    bottom: @types.Dimension::Auto,
  }
  b.bench(fn() {
    ignore(resolve_relative_inset_offsets(inset, 300.0, Some(80.0)))
  })
}
