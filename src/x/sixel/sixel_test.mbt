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
test "to_sixel_dynamic preserves deterministic mixed color rows" {
  let fb = @sixel.Framebuffer::new(2, 6)
  let palette = @sixel.DynamicPalette::new()
  palette.colors.push(@sixel.Color::blue())
  palette.colors.push(@sixel.Color::red())
  fb.fill_rect(0, 0, 1, 6, 1)
  fb.fill_rect(1, 0, 1, 6, 2)
  let result = @sixel.to_sixel_dynamic(fb, palette)
  assert_eq(
    result, "\u001bPq#0;2;100;100;100#1;2;25;52;95#2;2;91;26;20#1~?$#2?~$-\u001b\\",
  )
}

///|
test "to_sixel_dynamic compresses repeated columns with repeat introducer" {
  let fb = @sixel.Framebuffer::new(4, 6)
  let palette = @sixel.DynamicPalette::new()
  palette.colors.push(@sixel.Color::blue())
  fb.fill_rect(0, 0, 4, 6, 1)
  let result = @sixel.to_sixel_dynamic(fb, palette)
  assert_eq(result, "\u001bPq#0;2;100;100;100#1;2;25;52;95#1!4~$-\u001b\\")
}

///|
test "render_layout simple" {
  // Create a simple layout
  let layout : @types.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 100.0,
    height: 100.0,
    margin: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    padding: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    border: { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 },
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
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

///|
test "render_paint_node_to_framebuffer does not add debug border for block" {
  let style = @style.Style::default()
  style.background_color = @types.Color::rgb(220, 30, 30)
  let node = @paint.PaintNode::new(
    "div",
    "div",
    0.0,
    0.0,
    6.0,
    6.0,
    @paint.PaintProperties::from_style(style),
    [],
  )
  let fb = @sixel.Framebuffer::new(6, 6)
  let palette = @sixel.DynamicPalette::new()
  @sixel.render_paint_node_to_framebuffer(node, fb, palette)

  inspect(fb.get_pixel(0, 0), content="1")
  inspect(fb.get_pixel(1, 1), content="1")
  inspect(fb.get_pixel(5, 5), content="1")
}

///|
test "render_paint_node_to_framebuffer blends semi transparent background" {
  let style = @style.Style::default()
  style.background_color = @types.Color::rgba(255, 0, 0, 0.5)
  let node = @paint.PaintNode::new(
    "div",
    "div",
    0.0,
    0.0,
    4.0,
    4.0,
    @paint.PaintProperties::from_style(style),
    [],
  )
  let fb = @sixel.Framebuffer::new(4, 4)
  let palette = @sixel.DynamicPalette::new()
  @sixel.render_paint_node_to_framebuffer(node, fb, palette)

  let color = palette.colors[fb.get_pixel(0, 0)]
  inspect(color.r, content="255")
  inspect(color.g > 100, content="true")
  inspect(color.b > 100, content="true")
}
