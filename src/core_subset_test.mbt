///|
fn make_flex_node() -> @node.Node {
  let root_style = @style.Style::default()
  root_style.display = @types.Flex
  root_style.flex_direction = @types.Column
  root_style.height = @types.Length(10.0)
  root_style.width = @types.Length(20.0)
  root_style.row_gap = @types.Length(1.0)

  let child_style = @style.Style::default()
  child_style.flex_grow = 1.0

  @node.Node::new("root", root_style, [
    @node.Node::new("child", child_style, []),
  ])
}

///|
fn make_grid_node() -> @node.Node {
  let root_style = @style.Style::default()
  root_style.display = @types.Grid
  root_style.width = @types.Length(80.0)
  root_style.height = @types.Length(24.0)
  root_style.grid_template_columns = [
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Fr(1.0),
  ]
  root_style.grid_template_rows = [
    @types.TrackSizingFunction::Fr(1.0),
    @types.TrackSizingFunction::Fr(1.0),
  ]
  root_style.grid_template_areas = ["header header", "main sidebar"]

  let header_style = @style.Style::default()
  header_style.grid_area = Some("header")

  let main_style = @style.Style::default()
  main_style.grid_area = Some("main")

  let side_style = @style.Style::default()
  side_style.grid_area = Some("sidebar")

  @node.Node::new("root", root_style, [
    @node.Node::new("header", header_style, []),
    @node.Node::new("main", main_style, []),
    @node.Node::new("sidebar", side_style, []),
  ])
}

///|
test "core subset accepts tui-like flex tree" {
  let node = make_flex_node()
  let issues = validate_core_subset(node)
  assert_eq(issues.length(), 0)
}

///|
test "core subset accepts tui-like grid tree" {
  let node = make_grid_node()
  let issues = validate_core_subset(node)
  assert_eq(issues.length(), 0)
}

///|
test "core subset rejects absolute positioning" {
  let style = @style.Style::default()
  style.position = @types.Absolute
  let node = @node.Node::new("abs", style, [])
  let issues = validate_core_subset(node)
  assert_eq(issues.length() > 0, true)
}

///|
test "core subset rejects unsupported grid track sizing" {
  let style = @style.Style::default()
  style.display = @types.Grid
  style.grid_template_columns = [@types.TrackSizingFunction::MinContent]
  style.grid_template_rows = [@types.TrackSizingFunction::Fr(1.0)]
  let node = @node.Node::new("grid", style, [])
  let issues = validate_core_subset(node)
  assert_eq(issues.length() > 0, true)
}

///|
test "core compute_core_layout skips compute when violations exist" {
  let style = @style.Style::default()
  style.position = @types.Fixed
  let node = @node.Node::new("fixed", style, [])
  let result = compute_core_layout(node, @types.Size::new(10.0, 10.0))
  assert_eq(result.layout is None, true)
  assert_eq(result.issues.length() > 0, true)
}
