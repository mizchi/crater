///|
fn fill_node(
  id : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  color : @types.Color,
  children : Array[@paint_model.PaintNode],
) -> @paint_model.PaintNode {
  let paint = {
    ..@paint_model.PaintProperties::default(),
    background_color: color,
  }
  @paint_model.PaintNode::new(id, "div", x, y, w, h, paint, children)
}

///|
fn test_frame(w : Int, h : Int) -> RenderFrame2D {
  RenderFrame2D::new(
    dst=@gfx.new_image_handle(1, w, h),
    shader=@gfx.new_shader_handle(2, default_fill_shader_source()),
    screen_w=w,
    screen_h=h,
  )
}

///|
test "to_gfx_color normalizes 0..255 channels into 0..1" {
  inspect(
    to_gfx_color(@types.Color::rgb(255, 128, 0)),
    content=(
      #|{ r: 1, g: 0.5019607843137255, b: 0, a: 1 }
    ),
  )
}

///|
test "color_to_uniform_dwords packs 0..255 channels" {
  inspect(
    color_to_uniform_dwords(to_gfx_color(@types.Color::rgba(255, 128, 0, 1.0))),
    content="[255, 128, 0, 255]",
  )
}

///|
test "ndc_rect_fill_vertices maps the full viewport onto the NDC square" {
  let (vertices, indices) = ndc_rect_fill_vertices(
    0.0, 0.0, 100.0, 50.0, 100.0, 50.0,
  )
  // top-left -> (-1, 1), bottom-right -> (1, -1)
  inspect(
    vertices,
    content="[-1, 1, 0, 0, 1, 1, 1, 0, 1, -1, 1, 1, -1, -1, 0, 1]",
  )
  inspect(indices, content="[0, 1, 2, 2, 3, 0]")
}

///|
test "collect_paint_commands lowers background fills in paint order" {
  let frame = test_frame(100, 100)
  let tree = fill_node(
    "root",
    0.0,
    0.0,
    100.0,
    100.0,
    @types.Color::rgb(255, 255, 255),
    [
      fill_node(
        "opaque",
        10.0,
        10.0,
        20.0,
        20.0,
        @types.Color::rgb(255, 0, 0),
        [],
      ),
      fill_node(
        "transparent",
        0.0,
        0.0,
        5.0,
        5.0,
        @types.Color::transparent(),
        [],
      ),
      fill_node("zero-area", 0.0, 0.0, 0.0, 0.0, @types.Color::rgb(0, 0, 255), []),
    ],
  )
  let commands = collect_paint_commands(frame, tree)
  // root + opaque child only; transparent and zero-area nodes are skipped.
  inspect(commands.length(), content="2")
  // Every fill targets the full-frame dst region (geometry lives in NDC
  // vertex data).
  inspect(
    commands.map(fn(c) { c.dst_regions[0].index_count }),
    content="[6, 6]",
  )
  // The opaque child fill maps its pixel box to NDC vertex data.
  inspect(
    commands[1].vertex_data,
    content=(
      #|[-0.8, 0.8, 0, 0, -0.4, 0.8, 1, 0, -0.4, 0.4, 1, 1, -0.8, 0.4, 0, 1]
    ),
  )
}

///|
test "borders are lowered as per-side edge fills" {
  let frame = test_frame(50, 50)
  let paint = {
    ..@paint_model.PaintProperties::default(),
    border_top_width: 2.0,
    border_top_color: @types.Color::rgb(0, 0, 0),
    border_left_width: 3.0,
    border_left_color: @types.Color::rgb(0, 0, 0),
  }
  // right / bottom widths stay 0 -> skipped
  let node = @paint_model.PaintNode::new(
    "bordered",
    "div",
    0.0,
    0.0,
    50.0,
    50.0,
    paint,
    [],
  )
  let commands = []
  append_paint_node(commands, frame, node)
  // no background, two visible borders (top + left)
  inspect(commands.length(), content="2")
}

///|
test "render_paint_tree drives a null graphics backend end-to-end" {
  let tree = fill_node(
    "root",
    0.0,
    0.0,
    64.0,
    48.0,
    @types.Color::rgb(255, 255, 255),
    [fill_node("box", 4.0, 4.0, 8.0, 8.0, @types.Color::rgb(0, 128, 255), [])],
  )
  let driver = @gfx.create_null_graphics(64, 48)
  // Should initialize, allocate resources and flush one render pass
  // without raising.
  render_paint_tree(driver, tree)
}
