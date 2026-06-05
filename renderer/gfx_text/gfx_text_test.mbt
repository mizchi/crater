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
fn glyph(
  x : Double,
  y : Double,
  w : Int,
  h : Int,
  offset_x : Int,
  offset_y : Int,
) -> @glyph.GlyphPlacement {
  let bitmap : @glyph.GlyphBitmap = {
    width: w,
    height: h,
    pixels: [],
    advance: w.to_double(),
    offset_x,
    offset_y,
    coverage: [],
    ss_factor: 1,
  }
  { bitmap, x, y, line_height: 16.0 }
}

///|
test "glyph_placements_to_commands emits one quad per inked glyph" {
  let frame = test_frame(100, 100)
  let color = @gfx.new_color(0.0, 0.0, 0.0, 1.0)
  let placements = [
    glyph(0.0, 0.0, 6, 8, 0, 0), // inked
    glyph(6.0, 0.0, 0, 0, 0, 0), // whitespace: zero ink box -> skipped
    glyph(10.0, 0.0, 6, 8, 1, 2), // inked, with bitmap offset
  ]
  let commands = glyph_placements_to_commands(frame, placements, color)
  inspect(commands.length(), content="2")
  // each glyph is a single quad
  inspect(commands.map(fn(c) { c.indices.length() }), content="[6, 6]")
  // the ink box position folds in the bitmap offset (10+1, 0+2)
  inspect(
    commands[1].vertex_data,
    content=(
      #|[-0.78, 0.96, 0, 0, -0.6599999999999999, 0.96, 1, 0, -0.6599999999999999, 0.8, 1, 1, -0.78, 0.8, 0, 1]
    ),
  )
}
