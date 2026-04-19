///|
test "compute_justify basic distribution" {
  let (start, gap) = compute_justify(@types.SpaceBetween, 90.0, 4)
  assert_eq(start, 0.0)
  assert_eq(gap, 30.0)
}

///|
test "compute_align_offset center" {
  let offset = compute_align_offset(@types.Center, 40.0)
  assert_eq(offset, 20.0)
}

///|
test "resolve_align_self maps auto to parent alignment" {
  let resolved = resolve_align_self(@types.AlignSelf::Auto, @types.FlexEnd)
  assert_eq(resolved, @types.FlexEnd)
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

///|
test "resolve_auto_margin_pair centers when both auto" {
  let (start, end) = resolve_auto_margin_pair(true, true, 3.0, 5.0, 20.0)
  assert_eq(start, 10.0)
  assert_eq(end, 10.0)
}

///|
test "clamp_value applies max then min (min wins on conflict)" {
  let clamped1 = clamp_value(120.0, 10.0, 100.0)
  assert_eq(clamped1, 100.0)
  let clamped2 = clamp_value(50.0, 80.0, 40.0)
  assert_eq(clamped2, 80.0)
}

///|
test "clamp_size_with_box_min enforces box minimum and max constraints" {
  let (w, h) = clamp_size_with_box_min(
    5.0, 3.0, 0.0, 100.0, 0.0, 100.0, 12.0, 8.0,
  )
  assert_eq(w, 12.0)
  assert_eq(h, 8.0)
}

///|
test "apply_aspect_ratio_after_constraints width driver" {
  let (w, h) = apply_aspect_ratio_after_constraints(
    80.0,
    10.0,
    Some(2.0),
    true,
    false,
  )
  assert_eq(w, 80.0)
  assert_eq(h, 40.0)
}

///|
test "resolve_relative_inset_axis_offset uses negative end when start auto" {
  let y = resolve_relative_inset_axis_offset(
    @types.Auto,
    @types.Length(12.0),
    Some(100.0),
  )
  assert_eq(y, -12.0)
}

///|
test "resolve_relative_inset_offsets resolves x/y with optional height context" {
  let (x, y) = resolve_relative_inset_offsets(
    {
      left: @types.Auto,
      right: @types.Percent(0.1),
      top: @types.Percent(0.25),
      bottom: @types.Auto,
    },
    300.0,
    Some(80.0),
  )
  assert_eq(x, -30.0)
  assert_eq(y, 20.0)
}
