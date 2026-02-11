///|
test "compute_justify basic distribution" {
  let (start, gap) = compute_justify(@types.SpaceBetween, 90.0, 4)
  assert_eq(start, 0.0)
  assert_eq(gap, 30.0)
}

///|
test "compute_justify negative free space packs to start for space alignments" {
  let (start, gap) = compute_justify(@types.SpaceAround, -10.0, 3)
  assert_eq(start, 0.0)
  assert_eq(gap, 0.0)
}

///|
test "compute_align_offset center" {
  let offset = compute_align_offset(@types.Center, 40.0)
  assert_eq(offset, 20.0)
}

///|
test "compute_align_self_offset auto follows parent alignment" {
  let offset = compute_align_self_offset(
    @types.AlignSelf::Auto,
    @types.End,
    30.0,
  )
  assert_eq(offset, 30.0)
}
