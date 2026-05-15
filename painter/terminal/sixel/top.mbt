///|
pub using @raster {type Color, type DynamicPalette, type Framebuffer}

///|
priv struct Palette {
  colors : Array[Color]
}

///|
fn Palette::new() -> Palette {
  {
    colors: [
      Color::white(),
      Color::blue(),
      Color::green(),
      Color::yellow(),
      Color::red(),
      Color::gray(),
      Color::black(),
    ],
  }
}

///|
fn Palette::extended() -> Palette {
  {
    colors: [
      Color::white(),
      { r: 220, g: 235, b: 250 },
      { r: 185, g: 215, b: 240 },
      { r: 150, g: 195, b: 230 },
      { r: 115, g: 175, b: 220 },
      { r: 80, g: 155, b: 210 },
      { r: 45, g: 135, b: 200 },
      { r: 34, g: 139, b: 34 },
      { r: 0, g: 100, b: 0 },
      Color::black(),
    ],
  }
}

///|
fn to_sixel_protocol_colors(
  colors : Array[Color],
) -> Array[@sixel_protocol.Color] {
  colors.map(fn(color) { @sixel_protocol.Color::rgb(color.r, color.g, color.b) })
}

///|
fn encode_framebuffer_to_sixel(
  fb : Framebuffer,
  colors : Array[Color],
  include_all_colors? : Bool = false,
  compress? : Bool = true,
) -> String {
  @sixel_protocol.encode_indexed_pixels_to_sixel(
    fb.width,
    fb.height,
    fb.pixels,
    to_sixel_protocol_colors(colors),
    include_all_colors~,
    compress~,
  )
}

///|
pub fn to_sixel(fb : Framebuffer) -> String {
  let palette = Palette::new()
  encode_framebuffer_to_sixel(
    fb,
    palette.colors,
    include_all_colors=true,
    compress=false,
  )
}

///|
pub fn to_sixel_extended(fb : Framebuffer) -> String {
  let palette = Palette::extended()
  encode_framebuffer_to_sixel(
    fb,
    palette.colors,
    include_all_colors=true,
    compress=false,
  )
}

///|
pub fn to_sixel_dynamic(fb : Framebuffer, palette : DynamicPalette) -> String {
  encode_framebuffer_to_sixel(fb, palette.colors)
}

///|
pub fn render_layout(
  layout : @types.Layout,
  width : Int,
  height : Int,
) -> String {
  render_layout_with_options(layout, width, height, false)
}

///|
pub fn render_layout_with_options(
  layout : @types.Layout,
  width : Int,
  height : Int,
  show_box_model : Bool,
) -> String {
  let fb = Framebuffer::new(width, height)
  fb.fill_rect(0, 0, width, height, 0)
  if show_box_model {
    render_node_with_box_model(fb, layout, 0.0, 0.0, 0, true)
    to_sixel(fb)
  } else {
    render_node_simple(fb, layout, 0.0, 0.0, 0)
    to_sixel_extended(fb)
  }
}

///|
fn is_text_node(id : String) -> Bool {
  id == "#text"
}

///|
fn render_node_simple(
  fb : Framebuffer,
  layout : @types.Layout,
  parent_x : Double,
  parent_y : Double,
  depth : Int,
) -> Unit {
  let abs_x = parent_x + layout.x
  let abs_y = parent_y + layout.y
  let x = abs_x.to_int()
  let y = abs_y.to_int()
  let w = layout.width.to_int()
  let h = layout.height.to_int()
  if w == 0 || h == 0 {
    for child in layout.children {
      render_node_simple(fb, child, abs_x, abs_y, depth + 1)
    }
    return
  }
  if is_text_node(layout.id) {
    fb.fill_rect(x, y, w, h, 0)
    match layout.text {
      Some(text_content) => {
        let _ = fb.draw_text(x, y, text_content, w, 7, 1)
        fb.stroke_rect(x, y, w, h, 8)
      }
      None => {
        fb.fill_rect_hatched(x, y, w, h, 0, 7, 3)
        fb.stroke_rect(x, y, w, h, 8)
      }
    }
  } else {
    let color_idx = if depth < 6 { depth + 1 } else { 6 }
    fb.fill_rect(x, y, w, h, color_idx)
    fb.stroke_rect(x, y, w, h, 9)
  }
  for child in layout.children {
    render_node_simple(fb, child, abs_x, abs_y, depth + 1)
  }
}

///|
fn render_node_with_box_model(
  fb : Framebuffer,
  layout : @types.Layout,
  parent_x : Double,
  parent_y : Double,
  depth : Int,
  show_box_model : Bool,
) -> Unit {
  let abs_x = parent_x + layout.x
  let abs_y = parent_y + layout.y
  let x = abs_x.to_int()
  let y = abs_y.to_int()
  let w = layout.width.to_int()
  let h = layout.height.to_int()
  if w == 0 || h == 0 {
    for child in layout.children {
      render_node_with_box_model(
        fb,
        child,
        abs_x,
        abs_y,
        depth + 1,
        show_box_model,
      )
    }
    return
  }
  if is_text_node(layout.id) {
    fb.fill_rect_hatched(x, y, w, h, 0, 5, 3)
    fb.stroke_rect(x, y, w, h, 6)
  } else if show_box_model {
    let margin_t = layout.margin.top.to_int()
    let margin_r = layout.margin.right.to_int()
    let margin_b = layout.margin.bottom.to_int()
    let margin_l = layout.margin.left.to_int()
    let padding_t = layout.padding.top.to_int()
    let padding_r = layout.padding.right.to_int()
    let padding_b = layout.padding.bottom.to_int()
    let padding_l = layout.padding.left.to_int()
    let border_t = layout.border.top.to_int()
    let border_r = layout.border.right.to_int()
    let border_b = layout.border.bottom.to_int()
    let border_l = layout.border.left.to_int()
    if margin_t > 0 {
      fb.fill_rect(
        x - margin_l,
        y - margin_t,
        w + margin_l + margin_r,
        margin_t,
        4,
      )
    }
    if margin_b > 0 {
      fb.fill_rect(x - margin_l, y + h, w + margin_l + margin_r, margin_b, 4)
    }
    if margin_l > 0 {
      fb.fill_rect(x - margin_l, y, margin_l, h, 4)
    }
    if margin_r > 0 {
      fb.fill_rect(x + w, y, margin_r, h, 4)
    }
    let content_x = x + border_l + padding_l
    let content_y = y + border_t + padding_t
    let content_w = w - border_l - border_r - padding_l - padding_r
    let content_h = h - border_t - border_b - padding_t - padding_b
    if padding_t > 0 {
      fb.fill_rect(
        x + border_l,
        y + border_t,
        w - border_l - border_r,
        padding_t,
        2,
      )
    }
    if padding_b > 0 {
      fb.fill_rect(
        x + border_l,
        y + h - border_b - padding_b,
        w - border_l - border_r,
        padding_b,
        2,
      )
    }
    if padding_l > 0 {
      fb.fill_rect(
        x + border_l,
        y + border_t + padding_t,
        padding_l,
        content_h,
        2,
      )
    }
    if padding_r > 0 {
      fb.fill_rect(
        x + w - border_r - padding_r,
        y + border_t + padding_t,
        padding_r,
        content_h,
        2,
      )
    }
    if content_w > 0 && content_h > 0 {
      fb.fill_rect(content_x, content_y, content_w, content_h, 1)
    }
    fb.stroke_rect(x, y, w, h, 6)
  } else {
    let color = depth % 5 + 1
    fb.fill_rect(x, y, w, h, color)
    fb.stroke_rect(x, y, w, h, 6)
  }
  for child in layout.children {
    render_node_with_box_model(
      fb,
      child,
      abs_x,
      abs_y,
      depth + 1,
      show_box_model,
    )
  }
}

///|
pub fn print_layout(layout : @types.Layout, width : Int, height : Int) -> Unit {
  let _ = render_layout(layout, width, height)
}

///|
pub fn render_paint_node_to_sixel(
  node : @paint_model.PaintNode,
  width : Int,
  height : Int,
) -> String {
  let fb = Framebuffer::new(width, height)
  let palette = DynamicPalette::new()
  fb.fill_rect(0, 0, width, height, 0)
  @raster.render_paint_node_to_framebuffer(node, fb, palette)
  to_sixel_dynamic(fb, palette)
}

///|
pub fn render_with_styles(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
) -> String {
  let paint_node = @paint_node.from_node_and_layout(node, layout)
  render_paint_node_to_sixel(paint_node, width, height)
}

///|
pub fn render_paint_node_to_sixel_scrolled(
  node : @paint_model.PaintNode,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> String {
  let fb = Framebuffer::new(width, height)
  let palette = DynamicPalette::new()
  @raster.render_paint_node_to_framebuffer_scrolled(node, fb, palette, scroll_y)
  to_sixel_dynamic(fb, palette)
}

///|
pub fn render_with_styles_scrolled(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> String {
  let paint_node = @paint_node.from_node_and_layout(node, layout)
  render_paint_node_to_sixel_scrolled(paint_node, width, height, scroll_y)
}

///|
pub fn render_svg_to_sixel(
  scene : @svg.Scene,
  width : Int,
  height : Int,
) -> String {
  let fb = Framebuffer::new(width, height)
  let palette = DynamicPalette::new()
  fb.fill_rect(0, 0, width, height, 0)
  @raster.render_svg_scene(scene, fb, palette)
  to_sixel_dynamic(fb, palette)
}

///|
pub fn render_svg_node_to_sixel(
  node : @svg.SVGNode,
  width : Int,
  height : Int,
) -> String {
  let scene = @svg.Scene::new(node)
  render_svg_to_sixel(scene, width, height)
}

///|
pub fn render_svg_path_to_sixel(
  path_data : String,
  fill_color : Color?,
  stroke_color : Color?,
  width : Int,
  height : Int,
) -> String {
  let commands = @svg.parse_path(path_data)
  let node = @svg.SVGNode::new(@svg.Path(commands~))
  match fill_color {
    Some(c) => node.fill = @svg.SolidColor(@svg.Color::rgb(c.r, c.g, c.b))
    None => node.fill = @svg.None
  }
  match stroke_color {
    Some(c) =>
      node.stroke = {
        paint: @svg.SolidColor(@svg.Color::rgb(c.r, c.g, c.b)),
        width: 1.0,
        linecap: @svg.Butt,
        linejoin: @svg.Miter,
        miterlimit: 4.0,
        dasharray: None,
        dashoffset: 0.0,
      }
    None => ()
  }
  render_svg_node_to_sixel(node, width, height)
}

///|
pub fn render_svg_to_sixel_with_camera(
  scene : @svg.Scene,
  camera : @svg.Camera,
) -> String {
  let fb = Framebuffer::new(camera.viewport_width, camera.viewport_height)
  let palette = DynamicPalette::new()
  fb.fill_rect(0, 0, camera.viewport_width, camera.viewport_height, 0)
  @raster.render_svg_scene_with_camera(scene, fb, palette, camera)
  to_sixel_dynamic(fb, palette)
}
