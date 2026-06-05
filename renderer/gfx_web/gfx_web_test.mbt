///|
test "webgpu driver forwards a flushed command stream to the hooks" {
  let sink = install_capture_hooks()
  let driver = webgpu_driver(8, 8)
  @gfx.GraphicsDriver::initialize(driver)
  let dst = @gfx.GraphicsDriver::new_image(driver, 8, 8)
  let shader = @gfx.GraphicsDriver::new_shader(driver, "s")
  let command = @gfx.new_draw_triangles_command(
    dst,
    shader,
    [@gfx.new_dst_region(0, 0, 8, 8, 6)],
    0,
    0,
    0,
    @gfx.BlendMode::Alpha,
    [
      -1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 0.0,
      1.0,
    ],
    [0, 1, 2, 2, 3, 0],
    [],
    [255, 0, 0, 255],
  )
  let queue = @gfx.new_simple_command_queue()
  queue.enqueue_draw_triangles(command)
  @gfx.flush_commands(driver, queue, false)
  inspect(sink.initialized, content="true")
  inspect(sink.begin_count, content="1")
  inspect(sink.end_count, content="1")
  inspect(sink.draw_count(), content="1")
  reset_hooks()
}

///|
test "paint tree dispatches through the webgpu backend hooks" {
  let sink = install_capture_hooks()
  let root = @paint_model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    16.0,
    16.0,
    {
      ..@paint_model.PaintProperties::default(),
      background_color: @types.Color::rgb(255, 255, 255),
    },
    [
      @paint_model.PaintNode::new(
        "box",
        "div",
        2.0,
        2.0,
        8.0,
        8.0,
        {
          ..@paint_model.PaintProperties::default(),
          background_color: @types.Color::rgb(255, 0, 0),
        },
        [],
      ),
    ],
  )
  let driver = webgpu_driver(16, 16)
  // The assembler drives the gfx web driver unchanged; the host GPU layer
  // (or, here, the capture sink) receives the same command stream a real
  // backend would.
  @gfx_bridge.render_paint_tree(driver, root)
  // root background + red box = two fill commands
  inspect(sink.draw_count(), content="2")
  inspect(sink.begin_count, content="1")
  reset_hooks()
}
