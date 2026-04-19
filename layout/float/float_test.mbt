///|
test "vertical_rl_ltr_float_context_places_left_at_top_and_right_at_bottom" {
  let ctx = FloatContext::new_vertical(160.0, 0.0, 240.0, 0.0, true, true)
  let (left_x, left_y) = ctx.place_float(
    @types.Float::Left,
    80.0,
    56.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
  )
  let (right_x, right_y) = ctx.place_float(
    @types.Float::Right,
    48.0,
    40.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
  )
  inspect(left_x, content="80")
  inspect(left_y, content="0")
  inspect(right_x, content="112")
  inspect(right_y, content="200")
  inspect(ctx.get_clear_y(@types.Clear::Left, 0.0), content="80")
  inspect(ctx.get_clear_y(@types.Clear::Both, 0.0), content="80")
}

///|
test "vertical_rl_rtl_float_context_flips_line_left_to_bottom" {
  let ctx = FloatContext::new_vertical(160.0, 0.0, 240.0, 0.0, true, false)
  let (left_x, left_y) = ctx.place_float(
    @types.Float::Left,
    32.0,
    40.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
  )
  let (right_x, right_y) = ctx.place_float(
    @types.Float::Right,
    64.0,
    56.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
  )
  inspect(left_x, content="128")
  inspect(left_y, content="200")
  inspect(right_x, content="96")
  inspect(right_y, content="0")
  inspect(ctx.get_clear_y(@types.Clear::Right, 0.0), content="64")
}
