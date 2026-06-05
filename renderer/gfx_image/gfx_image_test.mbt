///|
fn test_frame(w : Int, h : Int) -> @gfx_frame.RenderFrame2D {
  @gfx_frame.RenderFrame2D::new(
    dst=@gfx.new_image_handle(1, w, h),
    shader=@gfx.new_shader_handle(2, "shader"),
    screen_w=w,
    screen_h=h,
  )
}

///|
test "append_image_quad emits a textured quad referencing the image id" {
  let frame = test_frame(100, 100)
  let image = @gfx.new_image_handle(7, 32, 32)
  let commands = []
  append_image_quad(
    commands,
    frame,
    ImageQuad2D::new(x=0.0, y=0.0, w=50.0, h=50.0, image~),
  )
  inspect(commands.length(), content="1")
  // textured: the source image id is referenced
  inspect(commands[0].src_image_ids, content="[7]")
  // uv spans the unit square
  inspect(
    commands[0].vertex_data,
    content="[-1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, -1, 0, 0, 1]",
  )
}

///|
test "append_image_quad skips zero-area boxes" {
  let frame = test_frame(100, 100)
  let image = @gfx.new_image_handle(7, 32, 32)
  let commands = []
  append_image_quad(
    commands,
    frame,
    ImageQuad2D::new(x=0.0, y=0.0, w=0.0, h=10.0, image~),
  )
  inspect(commands.length(), content="0")
}
