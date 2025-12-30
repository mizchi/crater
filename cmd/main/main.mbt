///|
fn main {
  // Create a simple layout example
  let default_style = @style.Style::default()

  let child1_style = { ..default_style, height: @types.Length(30.0) }
  let child1 = @node.Node::leaf("child1", child1_style)

  let child2_style = { ..default_style, height: @types.Length(50.0) }
  let child2 = @node.Node::leaf("child2", child2_style)

  let root_style = {
    ..default_style,
    width: @types.Length(200.0),
    padding: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root = @node.Node::new("root", root_style, [child1, child2])

  // Compute layout
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
  }
  let layout = @block.compute(root, ctx)

  // Generate SVG
  let svg = @vis.to_svg(layout, 400.0, 300.0)
  println(svg)
}
