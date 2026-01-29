///|
/// Demo: SVG rendering with Kitty Graphics Protocol (for Ghostty/Kitty/WezTerm)
test "kitty demo svg" {
  let scene = @sixel.create_svg_demo_scene()
  let kitty = render_svg_to_kitty(scene, 150, 120)
  println(kitty)
}

///|
/// Demo: Camera with pan and zoom (Kitty)
test "kitty demo camera" {
  // Create a large scene with multiple objects
  let rect1 = @svg.rect("r1", 0.0, 0.0, 50.0, 50.0)
  rect1.fill = @svg.SolidColor(@svg.Color::rgb(255, 100, 100))
  let rect2 = @svg.rect("r2", 100.0, 0.0, 50.0, 50.0)
  rect2.fill = @svg.SolidColor(@svg.Color::rgb(100, 255, 100))
  let rect3 = @svg.rect("r3", 0.0, 100.0, 50.0, 50.0)
  rect3.fill = @svg.SolidColor(@svg.Color::rgb(100, 100, 255))
  let rect4 = @svg.rect("r4", 100.0, 100.0, 50.0, 50.0)
  rect4.fill = @svg.SolidColor(@svg.Color::rgb(255, 255, 100))
  let circle1 = @svg.circle("c1", 75.0, 75.0, 30.0)
  circle1.fill = @svg.SolidColor(@svg.Color::rgb(255, 100, 255))
  let root = @svg.group("root", [rect1, rect2, rect3, rect4, circle1])
  let scene = @svg.Scene::new(root)
  // Create camera: viewport 120x120, positioned at center of scene, zoom 1.5x
  let camera = @svg.Camera::new(120, 120)
  camera.set_position(75.0, 75.0) // Center on the scene
  camera.set_zoom(1.5) // Zoom in 1.5x
  // Render with camera
  let kitty = render_svg_to_kitty_with_camera(scene, camera)
  println(kitty)
}
