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
test "framebuffer fill_rect clips to framebuffer bounds" {
  let fb = @image.Framebuffer::new(4, 3)
  fb.fill_rect(-1, -1, 3, 3, 7)
  inspect(fb.pixels[0], content="7")
  inspect(fb.pixels[1], content="7")
  inspect(fb.pixels[2], content="0")
  inspect(fb.pixels[4], content="7")
  inspect(fb.pixels[5], content="7")
  inspect(fb.pixels[6], content="0")
  inspect(fb.pixels[8], content="0")
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
  let child = @paint_model.PaintNode::new(
    "div",
    "div",
    0.0,
    0.0,
    6.0,
    6.0,
    @paint_model.PaintProperties::from_style(style),
    [],
  )
  let node = @paint_model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    12.0,
    12.0,
    @paint_model.PaintProperties::default(),
    [child],
  )
  let fb = @image.Framebuffer::new(6, 6)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)

  let corner = palette.colors[fb.get_pixel(0, 0)]
  let inner = palette.colors[fb.get_pixel(1, 1)]
  let edge = palette.colors[fb.get_pixel(5, 5)]
  inspect(corner.r, content="220")
  inspect(corner.g, content="30")
  inspect(corner.b, content="30")
  inspect(inner.r, content="220")
  inspect(inner.g, content="30")
  inspect(inner.b, content="30")
  inspect(edge.r, content="220")
  inspect(edge.g, content="30")
  inspect(edge.b, content="30")
}

///|
test "image provider draws raster img instead of alt text" {
  let style = @style.Style::default()
  style.color = @types.Color::rgb(0, 0, 0)
  @image.set_image_provider({
    resolve: fn(src) {
      if src == "logo.png" {
        Some(
          @image.ResolvedImage::Raster({
            width: 1,
            height: 1,
            rgba: [255, 0, 0, 255],
          }),
        )
      } else {
        None
      }
    },
  })
  let node = @paint_model.PaintNode::new(
    "img#logo",
    "img",
    0.0,
    0.0,
    4.0,
    4.0,
    @paint_model.PaintProperties::from_style(style),
    [],
    text=Some("Logo Alt"),
    src=Some("logo.png"),
  )
  let fb = @image.Framebuffer::new(4, 4)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)
  let color = palette.colors[fb.get_pixel(0, 0)]
  inspect(color.r, content="255")
  inspect(color.g, content="0")
  inspect(color.b, content="0")
  @image.clear_image_provider()
}

///|
test "render_paint_node_to_framebuffer blends semi transparent background" {
  let style = @style.Style::default()
  style.background_color = @types.Color::rgba(255, 0, 0, 0.5)
  let child = @paint_model.PaintNode::new(
    "div",
    "div",
    0.0,
    0.0,
    4.0,
    4.0,
    @paint_model.PaintProperties::from_style(style),
    [],
  )
  let node = @paint_model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    4.0,
    4.0,
    @paint_model.PaintProperties::default(),
    [child],
  )
  let fb = @image.Framebuffer::new(4, 4)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)

  let color = palette.colors[fb.get_pixel(0, 0)]
  inspect(color.r, content="255")
  inspect(
    color.g > 100,
    content=(
      #|true
    ),
  )
  inspect(
    color.b > 100,
    content=(
      #|true
    ),
  )
}

///|
test "render_paint_node_to_framebuffer blends semi transparent rounded background" {
  let style = @style.Style::default()
  style.background_color = @types.Color::rgba(0, 0, 0, 0.2)
  style.border_top_left_radius = 4.0
  style.border_top_right_radius = 4.0
  style.border_bottom_right_radius = 4.0
  style.border_bottom_left_radius = 4.0
  let child = @paint_model.PaintNode::new(
    "div",
    "div",
    0.0,
    0.0,
    12.0,
    12.0,
    @paint_model.PaintProperties::from_style(style),
    [],
  )
  let node = @paint_model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    12.0,
    12.0,
    @paint_model.PaintProperties::default(),
    [child],
  )
  let fb = @image.Framebuffer::new(12, 12)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)

  let color = palette.colors[fb.get_pixel(6, 6)]
  inspect(color.r, content="204")
  inspect(color.r > 180, content="true")
  inspect(color.g > 180, content="true")
  inspect(color.b > 180, content="true")
}

///|
test "render_paint_node_to_framebuffer clips solid rounded background corners" {
  let style = @style.Style::default()
  style.background_color = @types.Color::rgb(255, 0, 0)
  style.border_top_left_radius = 4.0
  style.border_top_right_radius = 4.0
  style.border_bottom_right_radius = 4.0
  style.border_bottom_left_radius = 4.0
  let child = @paint_model.PaintNode::new(
    "div",
    "div",
    0.0,
    0.0,
    12.0,
    12.0,
    @paint_model.PaintProperties::from_style(style),
    [],
  )
  let node = @paint_model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    12.0,
    12.0,
    @paint_model.PaintProperties::default(),
    [child],
  )
  let fb = @image.Framebuffer::new(12, 12)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)
  let corner = palette.colors[fb.get_pixel(0, 0)]
  let center = palette.colors[fb.get_pixel(6, 6)]
  inspect(corner.r, content="255")
  inspect(corner.g, content="255")
  inspect(corner.b, content="255")
  inspect(center.r, content="255")
  inspect(center.g, content="0")
  inspect(center.b, content="0")
}

///|
test "render_paint_node_to_framebuffer clips uniform rounded border corners" {
  let style = @style.Style::default()
  style.background_color = @types.Color::white()
  style.border_top_left_radius = 4.0
  style.border_top_right_radius = 4.0
  style.border_bottom_right_radius = 4.0
  style.border_bottom_left_radius = 4.0
  style.border_color = @types.Rect::all(@types.Color::rgb(0, 120, 212))
  let paint = {
    ..@paint_model.PaintProperties::from_style(style),
    border_top_width: 2.0,
    border_right_width: 2.0,
    border_bottom_width: 2.0,
    border_left_width: 2.0,
  }
  let child = @paint_model.PaintNode::new(
    "div",
    "div",
    0.0,
    0.0,
    12.0,
    12.0,
    paint,
    [],
  )
  let node = @paint_model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    12.0,
    12.0,
    @paint_model.PaintProperties::default(),
    [child],
  )
  let fb = @image.Framebuffer::new(12, 12)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)

  let corner = palette.colors[fb.get_pixel(0, 0)]
  let top_edge = palette.colors[fb.get_pixel(6, 0)]
  let left_edge = palette.colors[fb.get_pixel(0, 6)]
  let inner = palette.colors[fb.get_pixel(6, 6)]
  inspect(corner.r, content="255")
  inspect(corner.g, content="255")
  inspect(corner.b, content="255")
  inspect(top_edge.r, content="0")
  inspect(top_edge.g, content="120")
  inspect(top_edge.b, content="212")
  inspect(left_edge.r, content="0")
  inspect(left_edge.g, content="120")
  inspect(left_edge.b, content="212")
  inspect(inner.r, content="255")
  inspect(inner.g, content="255")
  inspect(inner.b, content="255")
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
test "render_paint_node_to_framebuffer blends glyph text opacity from parent" {
  @image.set_glyph_provider({
    get_glyph: fn(_codepoint, font_size, _is_bold) {
      let commands : Array[@svg.PathCommand] = [
        MoveTo(0.0, -font_size),
        LineTo(font_size, -font_size),
        LineTo(font_size, 0.0),
        LineTo(0.0, 0.0),
        ClosePath,
      ]
      (commands, font_size)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 1.0,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  })

  let parent_style = @style.Style::default()
  parent_style.opacity = 0.5
  let text_style = @style.Style::default()
  text_style.color = @types.Color::rgb(0, 0, 0)
  text_style.font_size = 10.0
  let text_node = @paint_model.PaintNode::new(
    "#text",
    "#text",
    0.0,
    0.0,
    12.0,
    12.0,
    @paint_model.PaintProperties::from_style(text_style),
    [],
    text=Some("A"),
  )
  let parent_node = @paint_model.PaintNode::new(
    "div",
    "div",
    0.0,
    0.0,
    12.0,
    12.0,
    @paint_model.PaintProperties::from_style(parent_style),
    [text_node],
  )
  let fb = @image.Framebuffer::new(12, 12)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(parent_node, fb, palette)
  let color = palette.colors[fb.get_pixel(5, 5)]
  inspect(color.r > 100 && color.r < 200, content="true")
  inspect(color.g > 100 && color.g < 200, content="true")
  inspect(color.b > 100 && color.b < 200, content="true")
  @image.clear_glyph_provider()
}

///|
test "render_paint_node_to_framebuffer applies parent opacity as a group" {
  let parent_style = @style.Style::default()
  parent_style.opacity = 0.5
  let red_style = @style.Style::default()
  red_style.background_color = @types.Color::rgb(255, 0, 0)
  let white_style = @style.Style::default()
  white_style.background_color = @types.Color::white()
  let red_node = @paint_model.PaintNode::new(
    "red",
    "div",
    0.0,
    0.0,
    12.0,
    12.0,
    @paint_model.PaintProperties::from_style(red_style),
    [],
  )
  let white_node = @paint_model.PaintNode::new(
    "white",
    "div",
    2.0,
    2.0,
    8.0,
    8.0,
    @paint_model.PaintProperties::from_style(white_style),
    [],
  )
  let parent_node = @paint_model.PaintNode::new(
    "group",
    "div",
    0.0,
    0.0,
    12.0,
    12.0,
    @paint_model.PaintProperties::from_style(parent_style),
    [red_node, white_node],
  )
  let fb = @image.Framebuffer::new(12, 12)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(parent_node, fb, palette)

  let edge = palette.colors[fb.get_pixel(0, 0)]
  let center = palette.colors[fb.get_pixel(5, 5)]
  inspect(edge.r, content="255")
  inspect(edge.g > 120 && edge.g < 140, content="true")
  inspect(edge.b > 120 && edge.b < 140, content="true")
  inspect(center.r, content="255")
  inspect(center.g, content="255")
  inspect(center.b, content="255")
}

///|
test "render_paint_node_to_framebuffer insets input text inside control" {
  @image.set_glyph_provider({
    get_glyph: fn(_codepoint, font_size, _is_bold) {
      let commands : Array[@svg.PathCommand] = [
        MoveTo(0.0, -font_size),
        LineTo(font_size, -font_size),
        LineTo(font_size, 0.0),
        LineTo(0.0, 0.0),
        ClosePath,
      ]
      (commands, font_size)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 1.0,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  })

  let style = @style.Style::default()
  style.color = @types.Color::rgb(0, 0, 0)
  style.font_size = 10.0
  let node = @paint_model.PaintNode::new(
    "input#email",
    "input",
    0.0,
    0.0,
    30.0,
    20.0,
    @paint_model.PaintProperties::from_style(style),
    [],
    text=Some("A"),
  )
  let fb = @image.Framebuffer::new(40, 24)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)

  inspect(fb.get_pixel(1, 5), content="0")
  inspect(fb.get_pixel(9, 8) > 0, content="true")
  @image.clear_glyph_provider()
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

///|
test "render_paint_node_to_framebuffer extends blurred box shadow beyond sharp bounds" {
  let style = @style.Style::default()
  style.background_color = @types.Color::rgb(255, 255, 255)
  style.box_shadows = [
    @style.BoxShadow::new(
      false,
      0.0,
      4.0,
      8.0,
      0.0,
      @types.Color::rgba(0, 0, 0, 0.5),
    ),
  ]
  let node = @paint_model.PaintNode::new(
    "box",
    "div",
    10.0,
    10.0,
    10.0,
    10.0,
    @paint_model.PaintProperties::from_style(style),
    [],
  )
  let fb = @image.Framebuffer::new(40, 40)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(node, fb, palette)

  let outside_blur = palette.colors[fb.get_pixel(15, 27)]
  let untouched = palette.colors[fb.get_pixel(1, 1)]

  inspect(outside_blur.r < untouched.r, content="true")
  inspect(outside_blur.g < untouched.g, content="true")
  inspect(outside_blur.b < untouched.b, content="true")
}
