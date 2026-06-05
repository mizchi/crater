///|
// Render bitmap text to the software backend and snapshot it as ASCII so
// the glyph shapes are actually legible in the test.
fn render_text_ascii(
  text : String,
  width : Int,
  height : Int,
  x : Int,
  y : Int,
  scale : Int,
) -> String raise {
  let driver = @gfx_software.SoftwareDriver::new(width, height)
  @gfx.GraphicsDriver::initialize(driver)
  let dst = @gfx.GraphicsDriver::new_image(driver, width, height)
  let shader = @gfx.GraphicsDriver::new_shader(driver, "s")
  @gfx.GraphicsDriver::begin(
    driver,
    @gfx.new_render_pass_desc(@gfx.new_color(1.0, 1.0, 1.0, 1.0), true),
  )
  let frame = @gfx_frame.RenderFrame2D::new(
    dst~,
    shader~,
    screen_w=width,
    screen_h=height,
  )
  let commands = bitmap_text_commands(
    frame,
    text,
    x,
    y,
    scale,
    @gfx.new_color(0.0, 0.0, 0.0, 1.0),
  )
  for cmd in commands {
    @gfx.GraphicsDriver::draw_triangles(driver, cmd)
  }
  @gfx.GraphicsDriver::end(driver, false)
  let buf = StringBuilder::new()
  for py in 0..<height {
    for px in 0..<width {
      let (r, _g, _b, _a) = driver.pixel_at(px, py)
      buf.write_char(if r < 128 { '#' } else { ' ' })
    }
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
test "bitmap font renders legible text" {
  inspect(
    render_text_ascii("HI", 12, 7, 0, 0, 1),
    content=(
      #|#   #  ###  
      #|#   #   #   
      #|#   #   #   
      #|#####   #   
      #|#   #   #   
      #|#   #   #   
      #|#   #  ###  
      #|
    ),
  )
}

///|
test "bitmap font renders digits and advances glyphs" {
  inspect(
    render_text_ascii("012", 18, 7, 0, 0, 1),
    content=(
      #| ###    #    ###  
      #|#   #  ##   #   # 
      #|#  ##   #       # 
      #|# # #   #      #  
      #|##  #   #     #   
      #|#   #   #    #    
      #| ###   ###  ##### 
      #|
    ),
  )
}
