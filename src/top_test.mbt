///|
test "compute_layout preserves display_contents root children" {
  let default_style = @style.Style::default()
  let child1_style = {
    ..default_style,
    width: @types.Length(30.0),
    height: @types.Length(10.0),
  }
  let child2_style = {
    ..default_style,
    width: @types.Length(40.0),
    height: @types.Length(20.0),
  }
  let child1 = @layout.Node::leaf("child1", child1_style)
  let child2 = @layout.Node::leaf("child2", child2_style)
  let root_style = @style.Style::default()
  root_style.display = @types.Contents
  let root = @layout.Node::new("root", root_style, [child1, child2])

  let layout = compute_layout(root, @types.Size::new(300.0, 200.0))

  inspect(layout.width, content="0")
  inspect(layout.height, content="0")
  inspect(layout.children.length(), content="2")
  inspect(layout.children[0].id, content="child1")
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[0].width, content="30")
  inspect(layout.children[0].height, content="10")
  inspect(layout.children[1].id, content="child2")
  inspect(layout.children[1].y, content="10")
  inspect(layout.children[1].width, content="40")
  inspect(layout.children[1].height, content="20")
}
