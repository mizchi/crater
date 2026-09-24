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
  @gfx_frame.RenderFrame2D::new(
    dst=@gfx.new_image_handle(1, w, h),
    shader=@gfx.new_shader_handle(2, default_fill_shader_source()),
    screen_w=w,
    screen_h=h,
  )
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
  debug_inspect(
    commands.map(fn(c) { c.dst_regions[0].index_count }),
    content="[6, 6]",
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
test "replaced images are lowered when an image resolver is supplied" {
  let frame = test_frame(100, 100)
  let paint = @paint_model.PaintProperties::default()
  let img_node = @paint_model.PaintNode::new(
    "img",
    "img",
    0.0,
    0.0,
    32.0,
    32.0,
    paint,
    [],
    src=Some("logo.png"),
  )
  let resolve = fn(src : String) -> @gfx.ImageHandle? {
    if src == "logo.png" {
      Some(@gfx.new_image_handle(42, 32, 32))
    } else {
      None
    }
  }
  let commands = collect_paint_commands(frame, img_node, resolve_image=resolve)
  inspect(commands.length(), content="1")
  debug_inspect(commands[0].src_image_ids, content="[42]")
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

///|
test "node opacity dims the emitted fill and propagates to children" {
  let frame = test_frame(10, 10)
  let child = @paint_model.PaintNode::new(
    "child",
    "div",
    0.0,
    0.0,
    10.0,
    10.0,
    {
      ..@paint_model.PaintProperties::default(),
      background_color: @types.Color::rgb(0, 0, 0),
    },
    [],
  )
  let parent = @paint_model.PaintNode::new(
    "parent",
    "div",
    0.0,
    0.0,
    10.0,
    10.0,
    {
      ..@paint_model.PaintProperties::default(),
      background_color: @types.Color::rgb(0, 0, 0),
      opacity: 0.5,
    },
    [child],
  )
  let commands = collect_paint_commands(frame, parent)
  // parent + child fills, both dimmed by the parent's 0.5 group opacity
  inspect(commands.length(), content="2")
  debug_inspect(commands[0].uniform_dwords, content="[0, 0, 0, 127]")
  debug_inspect(commands[1].uniform_dwords, content="[0, 0, 0, 127]")
}

///|
test "box shadow is lowered as a fill before the background" {
  let frame = test_frame(16, 16)
  let shadow = @style.BoxShadow::new(
    false,
    3.0,
    3.0,
    0.0,
    0.0,
    @types.Color::rgb(170, 170, 170),
  )
  let node = @paint_model.PaintNode::new(
    "box",
    "div",
    0.0,
    0.0,
    6.0,
    6.0,
    {
      ..@paint_model.PaintProperties::default(),
      background_color: @types.Color::rgb(0, 0, 0),
      box_shadows: [shadow],
    },
    [],
  )
  let commands = collect_paint_commands(frame, node)
  // shadow fill, then background fill
  inspect(commands.length(), content="2")
  // shadow is grey and painted first
  debug_inspect(commands[0].uniform_dwords, content="[170, 170, 170, 255]")
  debug_inspect(commands[1].uniform_dwords, content="[0, 0, 0, 255]")
}

///|
test "border radius lowers the background as a rounded fill" {
  let frame = test_frame(8, 8)
  let node = @paint_model.PaintNode::new(
    "box",
    "div",
    0.0,
    0.0,
    8.0,
    8.0,
    {
      ..@paint_model.PaintProperties::default(),
      background_color: @types.Color::rgb(0, 0, 0),
      border_top_left_radius: 3.0,
      border_top_right_radius: 3.0,
      border_bottom_right_radius: 3.0,
      border_bottom_left_radius: 3.0,
    },
    [],
  )
  let commands = collect_paint_commands(frame, node)
  inspect(commands.length(), content="1")
  // rounded: shape uniforms appended after the colour
  debug_inspect(
    commands[0].uniform_dwords,
    content=(
      #|[0, 0, 0, 255, 3, 3, 3, 3, 3, 3, 3, 3, 0, 0, 8, 8]
    ),
  )
}
