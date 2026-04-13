///|
fn make_flex_node() -> @layout.Node {
  let root_style = @style.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column
  root_style.height = @types.Length(10.0)
  root_style.width = @types.Length(20.0)
  root_style.row_gap = @types.Length(1.0)

  let child_style = @style.Style::default()
  child_style.flex_grow = 1.0

  @layout.Node::new("root", root_style, [
    @layout.Node::new("child", child_style, []),
  ])
}

///|
test "core subset package accepts tui-like flex tree" {
  let issues = validate_core_subset(make_flex_node())
  assert_eq(issues.length(), 0)
}

///|
test "core subset package rejects fixed positioning" {
  let style = @style.Style::default()
  style.position = @types.Fixed
  let node = @layout.Node::new("fixed", style, [])
  let result = compute_core_layout(node, @types.Size::new(10.0, 10.0))
  assert_true(result.layout is None)
  assert_true(result.issues.length() > 0)
}
