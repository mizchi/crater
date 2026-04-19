///|
/// Tests for Sixel renderer
fn render_text_probe(build : (@style.Style) -> Unit) -> @image.Framebuffer {
  let style = @style.Style::default()
  style.color = @types.Color::rgb(20, 20, 20)
  style.font_size = 12.0
  build(style)
  let node = @paint_model.PaintNode::new(
    "text",
    "#text",
    2.0,
    2.0,
    40.0,
    24.0,
    @paint_model.PaintProperties::from_style(style),
    [],
    text=Some("Hi"),
  )
  let fb = @image.Framebuffer::new(48, 32)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)
  fb
}

///|
test "framebuffer creation" {
  let fb = @image.Framebuffer::new(10, 10)
  inspect(fb.width, content="10")
  inspect(fb.height, content="10")
}

///|
test "framebuffer fill_rect" {
  let fb = @image.Framebuffer::new(10, 10)
  fb.fill_rect(2, 2, 5, 5, 1)
  // Check corners of the filled rect
  inspect(fb.pixels[2 * 10 + 2], content="1")
  inspect(fb.pixels[6 * 10 + 6], content="1")
  // Check outside is still 0
  inspect(fb.pixels[0], content="0")
}

///|
test "to_sixel basic output" {
  let fb = @image.Framebuffer::new(4, 6)
  fb.fill_rect(0, 0, 4, 6, 1) // Fill with color 1 (blue)
  let result = @image.to_sixel(fb)
  // Should start with ESC P q
  inspect(result.has_prefix("\u001bPq"), content="true")
  // Should end with ESC \
  inspect(result.has_suffix("\u001b\\"), content="true")
}

///|
test "to_sixel_dynamic preserves deterministic mixed color rows" {
  let fb = @image.Framebuffer::new(2, 6)
  let palette = @image.DynamicPalette::new()
  palette.colors.push(@image.Color::blue())
  palette.colors.push(@image.Color::red())
  fb.fill_rect(0, 0, 1, 6, 1)
  fb.fill_rect(1, 0, 1, 6, 2)
  let result = @image.to_sixel_dynamic(fb, palette)
  assert_eq(
    result, "\u001bPq#0;2;100;100;100#1;2;25;52;95#2;2;91;26;20#1~?$#2?~$-\u001b\\",
  )
}

///|
test "to_sixel_dynamic compresses repeated columns with repeat introducer" {
  let fb = @image.Framebuffer::new(4, 6)
  let palette = @image.DynamicPalette::new()
  palette.colors.push(@image.Color::blue())
  fb.fill_rect(0, 0, 4, 6, 1)
  let result = @image.to_sixel_dynamic(fb, palette)
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
  let sixel = @image.render_layout(layout, 100, 100)
  // Just verify it produces valid sixel output
  inspect(sixel.has_prefix("\u001bPq"), content="true")
  inspect(sixel.has_suffix("\u001b\\"), content="true")
}

///|
test "color blend" {
  let white = @image.Color::white()
  let blue = @image.Color::blue()
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
  let node = @paint_model.PaintNode::new(
    "div",
    "div",
    0.0,
    0.0,
    6.0,
    6.0,
    @paint_model.PaintProperties::from_style(style),
    [],
  )
  let fb = @image.Framebuffer::new(6, 6)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)

  inspect(fb.get_pixel(0, 0), content="1")
  inspect(fb.get_pixel(1, 1), content="1")
  inspect(fb.get_pixel(5, 5), content="1")
}

///|
test "render_paint_node_to_framebuffer blends semi transparent background" {
  let style = @style.Style::default()
  style.background_color = @types.Color::rgba(255, 0, 0, 0.5)
  let node = @paint_model.PaintNode::new(
    "div",
    "div",
    0.0,
    0.0,
    4.0,
    4.0,
    @paint_model.PaintProperties::from_style(style),
    [],
  )
  let fb = @image.Framebuffer::new(4, 4)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)

  let color = palette.colors[fb.get_pixel(0, 0)]
  inspect(color.r, content="255")
  inspect(
    color.g > 100,
    content=(
      #|false
    ),
  )
  inspect(
    color.b > 100,
    content=(
      #|false
    ),
  )
}

///|
test "canvas background propagates from body when html is transparent" {
  // Simulate <html> with transparent background containing <body> with #ececec
  let html_style = @style.Style::default()
  // html has transparent background (default)
  let body_style = @style.Style::default()
  body_style.background_color = @types.Color::rgb(236, 236, 236)
  let body_node = @paint_model.PaintNode::new(
    "body",
    "body",
    0.0,
    0.0,
    10.0,
    10.0,
    @paint_model.PaintProperties::from_style(body_style),
    [],
  )
  let html_node = @paint_model.PaintNode::new(
    "html",
    "html",
    0.0,
    0.0,
    10.0,
    10.0,
    @paint_model.PaintProperties::from_style(html_style),
    [body_node],
  )
  let fb = @image.Framebuffer::new(10, 10)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(html_node, fb, palette)
  // Corner pixel (outside body's rendered area doesn't matter, but
  // canvas fill should cover entire viewport)
  let color = palette.colors[fb.get_pixel(0, 0)]
  // Should be #ececec (236,236,236) from body background, not white
  inspect(color.r, content="236")
  inspect(color.g, content="236")
  inspect(color.b, content="236")
}

///|
test "render_paint_node_to_framebuffer draws underline beyond glyph bounds" {
  let baseline = render_text_probe(fn(_paint) {  })
  let underlined = render_text_probe(fn(paint) {
    paint.text_decoration_underline = true
  })
  inspect(baseline.get_pixel(35, 15), content="0")
  inspect(underlined.get_pixel(35, 15) > 0, content="true")
}

///|
test "render_paint_node_to_framebuffer draws overline and line_through beyond glyph bounds" {
  let baseline = render_text_probe(fn(_paint) {  })
  let decorated = render_text_probe(fn(paint) {
    paint.text_decoration_overline = true
    paint.text_decoration_line_through = true
  })
  inspect(baseline.get_pixel(35, 3), content="0")
  inspect(baseline.get_pixel(35, 9), content="0")
  inspect(decorated.get_pixel(35, 3) > 0, content="true")
  inspect(decorated.get_pixel(35, 9) > 0, content="true")
}

///|
test "render_paint_node_to_framebuffer draws box shadow outside element bounds" {
  let style = @style.Style::default()
  style.background_color = @types.Color::rgb(240, 240, 240)
  style.box_shadows = [
    @style.BoxShadow::new(
      false,
      3.0,
      2.0,
      0.0,
      0.0,
      @types.Color::rgba(0, 0, 0, 0.5),
    ),
  ]
  let node = @paint_model.PaintNode::new(
    "box",
    "div",
    4.0,
    4.0,
    6.0,
    6.0,
    @paint_model.PaintProperties::from_style(style),
    [],
  )
  let fb = @image.Framebuffer::new(20, 20)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)

  let outside_shadow = palette.colors[fb.get_pixel(10, 7)]
  let untouched = palette.colors[fb.get_pixel(1, 1)]

  inspect(outside_shadow.r < untouched.r, content="true")
  inspect(outside_shadow.g < untouched.g, content="true")
  inspect(outside_shadow.b < untouched.b, content="true")
}
