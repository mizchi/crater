///|
test "terminal facade renders svg scene to sixel" {
  let scene = Scene::new(@svg.circle("dot", 8.0, 8.0, 4.0))
  let sixel = render_svg_to_sixel(scene, 16, 16)

  inspect(sixel.length() > 0, content="true")
}
