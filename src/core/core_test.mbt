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
test "resolve_flex_axis row horizontal ltr" {
  let axis = resolve_flex_axis(@types.Row, false, false)
  assert_eq(axis.direction_is_row, true)
  assert_eq(axis.is_row, true)
  assert_eq(axis.is_reverse, false)
}

///|
test "resolve_flex_axis row horizontal rtl reverses" {
  let axis = resolve_flex_axis(@types.Row, false, true)
  assert_eq(axis.direction_is_row, true)
  assert_eq(axis.is_row, true)
  assert_eq(axis.is_reverse, true)
}

///|
test "resolve_flex_axis row-reverse horizontal rtl cancels reverse" {
  let axis = resolve_flex_axis(@types.RowReverse, false, true)
  assert_eq(axis.direction_is_row, true)
  assert_eq(axis.is_row, true)
  assert_eq(axis.is_reverse, false)
}

///|
test "resolve_flex_axis row in vertical writing maps to column axis" {
  let axis = resolve_flex_axis(@types.Row, true, false)
  assert_eq(axis.direction_is_row, true)
  assert_eq(axis.is_row, false)
  assert_eq(axis.is_reverse, false)
}

///|
test "axis accessors map row main/cross to horizontal/vertical" {
  let rect = @types.Rect::new(1.0, 2.0, 3.0, 4.0)
  assert_eq(axis_main_start(true, rect), 1.0)
  assert_eq(axis_main_end(true, rect), 2.0)
  assert_eq(axis_cross_start(true, rect), 3.0)
  assert_eq(axis_cross_end(true, rect), 4.0)
  assert_eq(axis_main_sum(true, rect), 3.0)
  assert_eq(axis_cross_sum(true, rect), 7.0)
}

///|
test "axis accessors map column main/cross to vertical/horizontal" {
  let rect = @types.Rect::new(1.0, 2.0, 3.0, 4.0)
  assert_eq(axis_main_start(false, rect), 3.0)
  assert_eq(axis_main_end(false, rect), 4.0)
  assert_eq(axis_cross_start(false, rect), 1.0)
  assert_eq(axis_cross_end(false, rect), 2.0)
  assert_eq(axis_main_sum(false, rect), 7.0)
  assert_eq(axis_cross_sum(false, rect), 3.0)
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
test "resolve_align_self maps auto to parent alignment" {
  let resolved = resolve_align_self(@types.AlignSelf::Auto, @types.FlexEnd)
  assert_eq(resolved, @types.FlexEnd)
}

///|
test "resolve_align_self maps center explicitly" {
  let resolved = resolve_align_self(@types.AlignSelf::Center, @types.Start)
  assert_eq(resolved, @types.Center)
}

///|
test "resolve_auto_margin_pair centers when both auto" {
  let (start, end) = resolve_auto_margin_pair(true, true, 3.0, 5.0, 20.0)
  assert_eq(start, 10.0)
  assert_eq(end, 10.0)
}

///|
test "resolve_auto_margin_pair left auto absorbs positive space" {
  let (start, end) = resolve_auto_margin_pair(true, false, 3.0, 5.0, 12.0)
  assert_eq(start, 12.0)
  assert_eq(end, 5.0)
}

///|
test "resolve_auto_margin_pair clamps negative remaining space" {
  let (start, end) = resolve_auto_margin_pair(false, true, 3.0, 5.0, -2.0)
  assert_eq(start, 3.0)
  assert_eq(end, 0.0)
}

///|
test "compute_grid_self_alignment_offset end aligns to free space" {
  let offset = compute_grid_self_alignment_offset(
    @types.End,
    120.0,
    70.0,
    false,
    false,
  )
  assert_eq(offset, 50.0)
}

///|
test "compute_grid_self_alignment_offset center aligns to half free space" {
  let offset = compute_grid_self_alignment_offset(
    @types.Center,
    120.0,
    70.0,
    false,
    false,
  )
  assert_eq(offset, 25.0)
}

///|
test "compute_grid_self_alignment_offset auto margins override alignment" {
  let offset = compute_grid_self_alignment_offset(
    @types.End,
    120.0,
    70.0,
    true,
    false,
  )
  assert_eq(offset, 0.0)
}

///|
test "compute_grid_absolute_self_position centers without insets" {
  let pos = compute_grid_absolute_self_position(
    @types.AlignSelf::Center,
    10.0,
    20.0,
    120.0,
    40.0,
    7.0,
    true,
    true,
  )
  assert_eq(pos, 60.0)
}

///|
test "compute_grid_absolute_self_position keeps base when inset exists" {
  let pos = compute_grid_absolute_self_position(
    @types.AlignSelf::End,
    33.0,
    20.0,
    120.0,
    40.0,
    7.0,
    false,
    true,
  )
  assert_eq(pos, 33.0)
}

///|
test "compute_inset_axis_position_with_auto_margin centers with both auto margins" {
  let pos = compute_inset_axis_position_with_auto_margin(
    Some(10.0),
    Some(10.0),
    0.0,
    0.0,
    true,
    true,
    20.0,
    0.0,
    100.0,
    0.0,
  )
  assert_eq(pos, 40.0)
}

///|
test "compute_inset_axis_position_with_auto_margin pushes to end for start auto" {
  let pos = compute_inset_axis_position_with_auto_margin(
    Some(10.0),
    Some(10.0),
    0.0,
    5.0,
    true,
    false,
    20.0,
    0.0,
    100.0,
    0.0,
  )
  assert_eq(pos, 65.0)
}

///|
test "compute_inset_axis_position_with_auto_margin uses fallback when no insets" {
  let pos = compute_inset_axis_position_with_auto_margin(
    None,
    None,
    3.0,
    0.0,
    false,
    false,
    20.0,
    5.0,
    100.0,
    7.0,
  )
  assert_eq(pos, 15.0)
}

///|
test "resolve_relative_inset_axis_offset uses start when definite" {
  let x = resolve_relative_inset_axis_offset(
    @types.Percent(0.25),
    @types.Length(20.0),
    Some(200.0),
  )
  assert_eq(x, 50.0)
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
test "resolve_relative_inset_axis_offset percent without context resolves zero" {
  let y = resolve_relative_inset_axis_offset(
    @types.Auto,
    @types.Percent(0.5),
    None,
  )
  assert_eq(y, 0.0)
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
test "apply_aspect_ratio_after_constraints keeps both constrained sizes" {
  let (w, h) = apply_aspect_ratio_after_constraints(
    80.0,
    30.0,
    Some(2.0),
    true,
    true,
  )
  assert_eq(w, 80.0)
  assert_eq(h, 30.0)
}

///|
fn make_track(
  position : Double,
  size : Double,
  stretchable : Bool,
) -> ContentTrack {
  { position, size, stretchable }
}

///|
test "align_content_tracks center shifts all tracks" {
  let tracks = [make_track(0.0, 40.0, false), make_track(50.0, 40.0, false)]
  let aligned = align_content_tracks(tracks, 120.0, @types.Center)
  assert_eq(aligned[0].position, 15.0)
  assert_eq(aligned[1].position, 65.0)
  assert_eq(aligned[0].size, 40.0)
  assert_eq(aligned[1].size, 40.0)
}

///|
test "align_content_tracks space-between skips zero-size tracks" {
  let tracks = [
    make_track(0.0, 20.0, false),
    make_track(30.0, 0.0, false),
    make_track(40.0, 20.0, false),
  ]
  let aligned = align_content_tracks(tracks, 100.0, @types.SpaceBetween)
  assert_eq(aligned[0].position, 0.0)
  assert_eq(aligned[1].position, 30.0)
  assert_eq(aligned[2].position, 80.0)
}

///|
test "align_content_tracks stretch grows only stretchable tracks" {
  let tracks = [
    make_track(0.0, 20.0, true),
    make_track(30.0, 20.0, false),
    make_track(60.0, 20.0, true),
  ]
  let aligned = align_content_tracks(tracks, 120.0, @types.Stretch)
  assert_eq(aligned[0].position, 0.0)
  assert_eq(aligned[0].size, 40.0)
  assert_eq(aligned[1].position, 50.0)
  assert_eq(aligned[1].size, 20.0)
  assert_eq(aligned[2].position, 80.0)
  assert_eq(aligned[2].size, 40.0)
}

///|
test "align_content_tracks keeps start packing for negative free space" {
  let tracks = [make_track(0.0, 30.0, false), make_track(35.0, 30.0, false)]
  let aligned = align_content_tracks(tracks, 50.0, @types.SpaceAround)
  assert_eq(aligned[0].position, 0.0)
  assert_eq(aligned[1].position, 35.0)
}
