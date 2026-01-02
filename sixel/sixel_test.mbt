///|
/// Tests for Sixel renderer
test "framebuffer creation" {
  let fb = @sixel.Framebuffer::new(10, 10)
  inspect(fb.width, content="10")
  inspect(fb.height, content="10")
}

///|
test "framebuffer fill_rect" {
  let fb = @sixel.Framebuffer::new(10, 10)
  fb.fill_rect(2, 2, 5, 5, 1)
  // Check corners of the filled rect
  inspect(fb.pixels[2 * 10 + 2], content="1")
  inspect(fb.pixels[6 * 10 + 6], content="1")
  // Check outside is still 0
  inspect(fb.pixels[0], content="0")
}

///|
test "to_sixel basic output" {
  let fb = @sixel.Framebuffer::new(4, 6)
  fb.fill_rect(0, 0, 4, 6, 1) // Fill with color 1 (blue)
  let result = @sixel.to_sixel(fb)
  // Should start with ESC P q
  inspect(result.has_prefix("\u001bPq"), content="true")
  // Should end with ESC \
  inspect(result.has_suffix("\u001b\\"), content="true")
}

///|
test "render_layout simple" {
  // Create a simple layout
  let layout : @node.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 100.0,
    height: 100.0,
    margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    children: [],
    text: None,
  }
  let sixel = @sixel.render_layout(layout, 100, 100)
  // Just verify it produces valid sixel output
  inspect(sixel.has_prefix("\u001bPq"), content="true")
  inspect(sixel.has_suffix("\u001b\\"), content="true")
}

///|
test "color blend" {
  let white = @sixel.Color::white()
  let blue = @sixel.Color::blue()
  let blended = blue.blend(white, 128) // 50% blend
  // Should be roughly halfway between blue and white
  inspect(blended.r > 100, content="true")
  inspect(blended.g > 150, content="true")
  inspect(blended.b > 200, content="true")
}
