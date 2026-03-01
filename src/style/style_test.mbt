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
