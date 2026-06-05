///|
// Draw a full-frame quad in NDC and read back the resulting pixels.
test "software driver clears then rasterizes a full-frame quad" {
  let driver = SoftwareDriver::new(4, 4)
  driver.initialize()
  let dst = @gfx.GraphicsDriver::new_image(driver, 4, 4)
  let shader = @gfx.GraphicsDriver::new_shader(driver, "s")
  // clear to opaque white
  @gfx.GraphicsDriver::begin(
    driver,
    @gfx.new_render_pass_desc(@gfx.new_color(1.0, 1.0, 1.0, 1.0), true),
  )
  // full-frame red quad (NDC unit square), color packed as rgba 0..255
  let command = @gfx.new_draw_triangles_command(
    dst,
    shader,
    [@gfx.new_dst_region(0, 0, 4, 4, 6)],
    0,
    0,
    0,
    @gfx.BlendMode::Copy,
    [
      -1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 0.0,
      1.0,
    ],
    [0, 1, 2, 2, 3, 0],
    [],
    [255, 0, 0, 255],
  )
  @gfx.GraphicsDriver::draw_triangles(driver, command)
  @gfx.GraphicsDriver::end(driver, false)
  // every pixel is now red
  inspect(driver.pixel_at(0, 0), content="(255, 0, 0, 255)")
  inspect(driver.pixel_at(3, 3), content="(255, 0, 0, 255)")
}

///|
test "software driver fills only the covered sub-rectangle" {
  let driver = SoftwareDriver::new(4, 4)
  driver.initialize()
  let dst = @gfx.GraphicsDriver::new_image(driver, 4, 4)
  let shader = @gfx.GraphicsDriver::new_shader(driver, "s")
  @gfx.GraphicsDriver::begin(
    driver,
    @gfx.new_render_pass_desc(@gfx.new_color(0.0, 0.0, 0.0, 1.0), true),
  )
  // a 2x2 quad at the top-left pixels (pixel space [0,2)x[0,2)).
  // NDC for px 0..2 of a width-4 frame: x in [-1, 0]; y in [1, 0].
  let command = @gfx.new_draw_triangles_command(
    dst,
    shader,
    [@gfx.new_dst_region(0, 0, 4, 4, 6)],
    0,
    0,
    0,
    @gfx.BlendMode::Copy,
    [
      -1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, -1.0, 0.0, 0.0,
      1.0,
    ],
    [0, 1, 2, 2, 3, 0],
    [],
    [0, 255, 0, 255],
  )
  @gfx.GraphicsDriver::draw_triangles(driver, command)
  @gfx.GraphicsDriver::end(driver, false)
  // covered
  inspect(driver.pixel_at(0, 0), content="(0, 255, 0, 255)")
  inspect(driver.pixel_at(1, 1), content="(0, 255, 0, 255)")
  // outside the 2x2 box -> still the clear color
  inspect(driver.pixel_at(2, 2), content="(0, 0, 0, 255)")
  inspect(driver.pixel_at(3, 0), content="(0, 0, 0, 255)")
}

///|
test "read_pixels returns the requested RGBA region" {
  let driver = SoftwareDriver::new(2, 2)
  driver.initialize()
  @gfx.GraphicsDriver::begin(
    driver,
    @gfx.new_render_pass_desc(@gfx.new_color(0.0, 0.0, 1.0, 1.0), true),
  )
  @gfx.GraphicsDriver::end(driver, false)
  let pixels = @gfx.GraphicsDriver::read_pixels(driver, 0, 0, 2, 2)
  inspect(
    pixels,
    content="Some([0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255])",
  )
}

///|
test "draw is scissored to the command's destination region" {
  let driver = SoftwareDriver::new(4, 4)
  driver.initialize()
  let dst = @gfx.GraphicsDriver::new_image(driver, 4, 4)
  let shader = @gfx.GraphicsDriver::new_shader(driver, "s")
  @gfx.GraphicsDriver::begin(
    driver,
    @gfx.new_render_pass_desc(@gfx.new_color(0.0, 0.0, 0.0, 1.0), true),
  )
  // Full-frame red quad, but the destination region only covers the left
  // two columns (x:0,w:2).
  let command = @gfx.new_draw_triangles_command(
    dst,
    shader,
    [@gfx.new_dst_region(0, 0, 2, 4, 6)],
    0,
    0,
    0,
    @gfx.BlendMode::Copy,
    [
      -1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 0.0,
      1.0,
    ],
    [0, 1, 2, 2, 3, 0],
    [],
    [255, 0, 0, 255],
  )
  @gfx.GraphicsDriver::draw_triangles(driver, command)
  @gfx.GraphicsDriver::end(driver, false)
  // left columns red, right columns remain the clear color
  inspect(driver.pixel_at(0, 0), content="(255, 0, 0, 255)")
  inspect(driver.pixel_at(1, 3), content="(255, 0, 0, 255)")
  inspect(driver.pixel_at(2, 0), content="(0, 0, 0, 255)")
  inspect(driver.pixel_at(3, 3), content="(0, 0, 0, 255)")
}

///|
test "rounded-rect uniforms carve the corners" {
  let driver = SoftwareDriver::new(8, 8)
  driver.initialize()
  let dst = @gfx.GraphicsDriver::new_image(driver, 8, 8)
  let shader = @gfx.GraphicsDriver::new_shader(driver, "s")
  @gfx.GraphicsDriver::begin(
    driver,
    @gfx.new_render_pass_desc(@gfx.new_color(1.0, 1.0, 1.0, 1.0), true),
  )
  // full-frame black quad with a radius-4 round on all corners
  let command = @gfx.new_draw_triangles_command(
    dst,
    shader,
    [@gfx.new_dst_region(0, 0, 8, 8, 6)],
    0,
    0,
    0,
    @gfx.BlendMode::Copy,
    [
      -1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 0.0,
      1.0,
    ],
    [0, 1, 2, 2, 3, 0],
    [],
    [0, 0, 0, 255, 4, 4, 4, 4, 0, 0, 8, 8],
  )
  @gfx.GraphicsDriver::draw_triangles(driver, command)
  @gfx.GraphicsDriver::end(driver, false)
  // the top-left corner pixel is carved away (still the clear color)
  inspect(driver.pixel_at(0, 0), content="(255, 255, 255, 255)")
  // the center is filled
  inspect(driver.pixel_at(4, 4), content="(0, 0, 0, 255)")
  // an edge midpoint is filled (not a corner)
  inspect(
    driver.pixel_at(0, 4),
    content=(
      #|(0, 0, 0, 245)
    ),
  )
}
