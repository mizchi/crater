///|
test "Style::default" {
  let style = Style::default()
  inspect(style.display, content="Block")
  inspect(style.position, content="Static")
  inspect(style.flex_grow, content="0")
}

///|
test "Style::has_multicol_true_for_column_count_one" {
  let style = { ..Style::default(), column_count: Some(1) }
  assert_true(style.has_multicol())
}

///|
test "Style::has_multicol_false_for_auto_columns" {
  let style = Style::default()
  assert_false(style.has_multicol())
}

///|
test "BoxShadow::new constructs public box shadow values" {
  let shadow = BoxShadow::new(
    false,
    3.0,
    2.0,
    4.0,
    1.0,
    @types.Color::rgba(10, 20, 30, 0.5),
  )
  inspect(shadow.inset, content="false")
  inspect(shadow.offset_x, content="3")
  inspect(shadow.offset_y, content="2")
  inspect(shadow.blur_radius, content="4")
  inspect(shadow.spread_radius, content="1")
  inspect(shadow.color.r, content="10")
  inspect(shadow.color.g, content="20")
  inspect(shadow.color.b, content="30")
  inspect(shadow.color.a, content="0.5")
}
