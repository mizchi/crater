///|
/// SVG Rendering Integration
/// Connects the SVG module to the framebuffer rendering pipeline

///|
/// Convert SVG Color to framebuffer Color
fn svg_color_to_image(c : @svg.Color) -> Color {
  { r: c.r, g: c.g, b: c.b }
}

///|
/// Render an SVG scene to a Framebuffer
pub fn render_svg_scene(
  scene : @svg.Scene,
  fb : Framebuffer,
  palette : DynamicPalette,
) -> Unit {
  // Create pixel setter that integrates with the palette
  let setter : @svg.PixelSetter = {
    set: fn(x, y, color) {
      if x >= 0 && x < fb.width && y >= 0 && y < fb.height {
        let image_color = svg_color_to_image(color)
        let idx = palette.get_or_add(image_color)
        fb.set_pixel(x, y, idx)
      }
    },
  }
  let ctx = @svg.RenderContext::new(setter, fb.width, fb.height)
  scene.render(ctx)
}

///|
/// Render an SVG scene with camera to a Framebuffer
pub fn render_svg_scene_with_camera(
  scene : @svg.Scene,
  fb : Framebuffer,
  palette : DynamicPalette,
  camera : @svg.Camera,
) -> Unit {
  let setter : @svg.PixelSetter = {
    set: fn(x, y, color) {
      if x >= 0 && x < fb.width && y >= 0 && y < fb.height {
        let image_color = svg_color_to_image(color)
        let idx = palette.get_or_add(image_color)
        fb.set_pixel(x, y, idx)
      }
    },
  }
  let ctx = @svg.RenderContext::for_camera(setter, camera)
  scene.render_with_camera(ctx, camera)
}

///|
/// Create a simple SVG demo scene
pub fn create_svg_demo_scene() -> @svg.Scene {
  // Create some shapes
  let rect1 = @svg.rect("rect1", 10.0, 10.0, 50.0, 30.0)
  rect1.fill = @svg.SolidColor(@svg.Color::rgb(255, 100, 100))
  rect1.stroke = {
    paint: @svg.SolidColor(@svg.Color::black()),
    width: 2.0,
    linecap: @svg.Butt,
    linejoin: @svg.Miter,
    miterlimit: 4.0,
    dasharray: None,
    dashoffset: 0.0,
  }
  let circle1 = @svg.circle("circle1", 100.0, 30.0, 20.0)
  circle1.fill = @svg.SolidColor(@svg.Color::rgb(100, 100, 255))
  circle1.stroke = {
    paint: @svg.SolidColor(@svg.Color::black()),
    width: 1.0,
    linecap: @svg.Butt,
    linejoin: @svg.Miter,
    miterlimit: 4.0,
    dasharray: None,
    dashoffset: 0.0,
  }
  let line1 = @svg.line("line1", 10.0, 60.0, 140.0, 60.0)
  line1.stroke = {
    paint: @svg.SolidColor(@svg.Color::rgb(0, 150, 0)),
    width: 3.0,
    linecap: @svg.Butt,
    linejoin: @svg.Miter,
    miterlimit: 4.0,
    dasharray: None,
    dashoffset: 0.0,
  }
  // Create a path (simple triangle)
  let path1 = @svg.path("path1", "M 70 70 L 100 100 L 40 100 Z")
  path1.fill = @svg.SolidColor(@svg.Color::rgb(255, 200, 0))
  path1.stroke = {
    paint: @svg.SolidColor(@svg.Color::black()),
    width: 1.0,
    linecap: @svg.Butt,
    linejoin: @svg.Miter,
    miterlimit: 4.0,
    dasharray: None,
    dashoffset: 0.0,
  }
  // Group them
  let root = @svg.group("root", [rect1, circle1, line1, path1])
  @svg.Scene::new(root)
}
