///|
// A synthetic glyph provider returning a filled right-triangle outline for
// every codepoint. This drives crater's real glyph rasterizer
// (@glyph.layout_glyph_bitmaps -> rasterize), so coverage/anti-aliasing is
// produced by the same path real fonts use -- only the outline is
// substituted.
fn triangle_provider() -> @glyph.GlyphProvider {
  {
    get_glyph: fn(_codepoint, font_size, _is_bold) {
      let commands : Array[@svg.PathCommand] = [
        MoveTo(0.0, -font_size),
        LineTo(font_size, 0.0),
        LineTo(0.0, 0.0),
        ClosePath,
      ]
      (commands, font_size)
    },
    get_kern: fn(_l, _r, _fs, _b) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 1.0,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
}

///|
test "real glyph rasterization lowers to coverage fills" {
  let w = 10
  let h = 10
  let driver = @gfx_software.SoftwareDriver::new(w, h)
  @gfx.GraphicsDriver::initialize(driver)
  let dst = @gfx.GraphicsDriver::new_image(driver, w, h)
  let shader = @gfx.GraphicsDriver::new_shader(driver, "s")
  @gfx.GraphicsDriver::begin(
    driver,
    @gfx.new_render_pass_desc(@gfx.new_color(1.0, 1.0, 1.0, 1.0), true),
  )
  let frame = @gfx_frame.RenderFrame2D::new(
    dst~,
    shader~,
    screen_w=w,
    screen_h=h,
  )
  let commands = text_run_coverage_commands(
    frame,
    triangle_provider(),
    "A",
    0,
    0,
    8.0,
    @gfx.new_color(0.0, 0.0, 0.0, 1.0),
  )
  // a real glyph rasterizes to many coverage pixels, not a single box
  inspect(commands.length() > 4, content="true")
  for cmd in commands {
    @gfx.GraphicsDriver::draw_triangles(driver, cmd)
  }
  @gfx.GraphicsDriver::end(driver, false)
  let buf = StringBuilder::new()
  for py in 0..<h {
    for px in 0..<w {
      let (r, _g, _b, _a) = driver.pixel_at(px, py)
      buf.write_char(if r < 64 { '#' } else if r < 200 { '+' } else { ' ' })
    }
    buf.write_char('\n')
  }
  inspect(
    buf.to_string(),
    content=(
      #|+         
      #|#+        
      #|##+       
      #|###+      
      #|####+     
      #|#####+    
      #|######+   
      #|#######+  
      #|          
      #|          
      #|
    ),
  )
}
