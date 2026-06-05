///|
// End-to-end: a paint tree rendered through the assembler onto the
// software rasterizer backend produces the expected pixels.
test "paint tree renders to pixels via the software backend" {
  // white root background with a red box at (1,1) sized 2x2.
  let root = @paint_model.PaintNode::new(
    "root",
    "div",
    0.0,
    0.0,
    4.0,
    4.0,
    {
      ..@paint_model.PaintProperties::default(),
      background_color: @types.Color::rgb(255, 255, 255),
    },
    [
      @paint_model.PaintNode::new(
        "box",
        "div",
        1.0,
        1.0,
        2.0,
        2.0,
        {
          ..@paint_model.PaintProperties::default(),
          background_color: @types.Color::rgb(255, 0, 0),
        },
        [],
      ),
    ],
  )
  let driver = @gfx_software.SoftwareDriver::new(4, 4)
  render_paint_tree(driver, root)
  // background pixel (corner) stays white
  inspect(driver.pixel_at(0, 0), content="(255, 255, 255, 255)")
  // the red box covers the inner 2x2 region
  inspect(driver.pixel_at(1, 1), content="(255, 0, 0, 255)")
  inspect(driver.pixel_at(2, 2), content="(255, 0, 0, 255)")
  // just outside the box is still white
  inspect(driver.pixel_at(3, 3), content="(255, 255, 255, 255)")
}
