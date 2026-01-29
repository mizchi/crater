///|
/// Demo: Sixel layout visualization
test "sixel demo layout" {
  // Create a sample layout tree (flex container with 3 children)
  let layout : @types.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 300.0,
    height: 200.0,
    margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    padding: { top: 10.0, right: 10.0, bottom: 10.0, left: 10.0 },
    border: { top: 2.0, right: 2.0, bottom: 2.0, left: 2.0 },
    overflow_x: Visible,
    overflow_y: Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: [
      // Header
      {
        id: "header",
        x: 12.0,
        y: 12.0,
        width: 276.0,
        height: 40.0,
        margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        overflow_x: Visible,
        overflow_y: Visible,
        scroll_width: 0.0,
        scroll_height: 0.0,
        children: [],
        text: None,
      },
      // Sidebar
      {
        id: "sidebar",
        x: 12.0,
        y: 62.0,
        width: 80.0,
        height: 126.0,
        margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        overflow_x: Visible,
        overflow_y: Visible,
        scroll_width: 0.0,
        scroll_height: 0.0,
        children: [],
        text: None,
      },
      // Main content
      {
        id: "main",
        x: 102.0,
        y: 62.0,
        width: 186.0,
        height: 126.0,
        margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        padding: { top: 5.0, right: 5.0, bottom: 5.0, left: 5.0 },
        border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
        overflow_x: Visible,
        overflow_y: Visible,
        scroll_width: 0.0,
        scroll_height: 0.0,
        children: [
          // Nested box
          {
            id: "box1",
            x: 5.0,
            y: 5.0,
            width: 80.0,
            height: 50.0,
            margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            overflow_x: Visible,
            overflow_y: Visible,
            scroll_width: 0.0,
            scroll_height: 0.0,
            children: [],
            text: None,
          },
          {
            id: "box2",
            x: 95.0,
            y: 5.0,
            width: 80.0,
            height: 50.0,
            margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
            overflow_x: Visible,
            overflow_y: Visible,
            scroll_width: 0.0,
            scroll_height: 0.0,
            children: [],
            text: None,
          },
        ],
        text: None,
      },
    ],
    text: None,
  }

  // Render to Sixel
  let _ = render_layout(layout, 300, 200)

}

///|
/// Demo: SVG rendering with Sixel
test "sixel demo svg" {
  // Create demo scene with rect, circle, line, and path
  let scene = create_svg_demo_scene()

  // Render to Sixel
  let sixel = render_svg_to_sixel(scene, 150, 120)

  // Output the sixel string (will show as image in sixel-compatible terminal)
  println(sixel)
}

///|
/// Demo: SVG path rendering
test "sixel demo svg path" {
  // Heart shape path
  let heart_path = "M 75,40 C 75,37 70,25 50,25 C 20,25 20,62.5 20,62.5 C 20,80 40,102 75,120 C 110,102 130,80 130,62.5 C 130,62.5 130,25 100,25 C 85,25 75,37 75,40 Z"
  let sixel = render_svg_path_to_sixel(
    heart_path,
    Some({ r: 255, g: 100, b: 100 }),
    Some({ r: 150, g: 50, b: 50 }),
    150,
    140,
  )
  println(sixel)
}

///|
/// Demo: Camera with pan and zoom
test "sixel demo camera" {
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
  let sixel = render_svg_to_sixel_with_camera(scene, camera)
  println(sixel)
}
