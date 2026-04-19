///|
fn make_paint_node(id : String, background : @types.Color) -> PaintNode {
  let props = { ..PaintProperties::default(), background_color: background }
  PaintNode::new(id, "div", 0.0, 0.0, 16.0, 16.0, props, [])
}

///|
test "painter facade diffs paint trees" {
  let before = make_paint_node("card", @types.Color::rgb(255, 0, 0))
  let after = make_paint_node("card", @types.Color::rgb(0, 0, 255))
  let diff = diff_trees(before, after)

  inspect(diff.changes.length(), content="1")
  inspect(diff.changes[0].node_id, content="card")
  inspect(diff.changes[0].property, content="background_color")
}

///|
test "painter facade renders svg scene to sixel" {
  let scene = Scene::new(circle("dot", 8.0, 8.0, 4.0))
  let sixel = render_svg_to_sixel(scene, 16, 16)

  inspect(sixel.length() > 0, content="true")
}
