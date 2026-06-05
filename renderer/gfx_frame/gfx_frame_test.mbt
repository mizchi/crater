///|
fn test_frame(w : Int, h : Int) -> RenderFrame2D {
  RenderFrame2D::new(
    dst=@gfx.new_image_handle(1, w, h),
    shader=@gfx.new_shader_handle(2, "shader"),
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
test "append_rect_fill maps a pixel box to an NDC quad" {
  let frame = test_frame(100, 100)
  let commands = []
  append_rect_fill(
    commands,
    frame,
    RectFill2D::new(
      x=10.0,
      y=10.0,
      w=20.0,
      h=20.0,
      color=to_gfx_color(@types.Color::rgb(255, 0, 0)),
    ),
  )
  inspect(commands.length(), content="1")
  inspect(
    commands[0].vertex_data,
    content=(
      #|[-0.8, 0.8, 0, 0, -0.4, 0.8, 1, 0, -0.4, 0.4, 1, 1, -0.8, 0.4, 0, 1]
    ),
  )
}

///|
test "append_rect_outline emits four edge quads in one command" {
  let frame = test_frame(50, 50)
  let commands = []
  append_rect_outline(
    commands,
    frame,
    RectOutline2D::new(
      x=0.0,
      y=0.0,
      w=50.0,
      h=50.0,
      line_width=2.0,
      color=to_gfx_color(@types.Color::rgb(0, 0, 0)),
    ),
  )
  inspect(commands.length(), content="1")
  // 4 edges * 6 indices
  inspect(commands[0].indices.length(), content="24")
}

///|
test "with_clip intersects the clip rectangle and drives dst_region" {
  let frame = test_frame(100, 100)
  // default clip is the full frame
  inspect(
    frame.dst_region(),
    content=(
      #|{ x: 0, y: 0, width: 100, height: 100, index_count: 6 }
    ),
  )
  let clipped = frame.with_clip(10, 20, 40, 40)
  inspect(
    clipped.dst_region(),
    content=(
      #|{ x: 10, y: 20, width: 40, height: 40, index_count: 6 }
    ),
  )
  // intersecting again keeps the overlap only
  let inner = clipped.with_clip(30, 0, 40, 30)
  inspect(
    inner.dst_region(),
    content=(
      #|{ x: 30, y: 20, width: 20, height: 10, index_count: 6 }
    ),
  )
}
