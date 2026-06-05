///|
/// Image (atlas) wiring unit: lower a placed image into a textured
/// `@gfx.DrawTrianglesCommand`.
///
/// This mirrors kagura's `mizchi/atlas` wiring role. Pixel upload and atlas
/// packing are the `GraphicsDriver`'s responsibility (`new_image`); this
/// package only emits the geometry that samples an already-allocated
/// `@gfx.ImageHandle` over the destination rectangle, so its only
/// dependencies are `gfx` and the shared `gfx_frame` primitives.

///|
/// A placed image: a destination rectangle (pixel space) sampling the full
/// extent of `image`. `tint` modulates the sampled texels (white = no
/// tint).
pub(all) struct ImageQuad2D {
  x : Double
  y : Double
  w : Double
  h : Double
  image : @gfx.ImageHandle
  tint : @gfx.Color
}

///|
pub fn ImageQuad2D::new(
  x~ : Double,
  y~ : Double,
  w~ : Double,
  h~ : Double,
  image~ : @gfx.ImageHandle,
  tint? : @gfx.Color = @gfx.new_color(1.0, 1.0, 1.0, 1.0),
) -> ImageQuad2D {
  { x, y, w, h, image, tint }
}

///|
/// Lower an `ImageQuad2D` into the command list as a single textured quad
/// referencing the image via `src_image_ids`.
pub fn append_image_quad(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : @gfx_frame.RenderFrame2D,
  quad : ImageQuad2D,
) -> Unit {
  if quad.w <= 0.0 || quad.h <= 0.0 {
    return
  }
  let (vertices, indices) = @gfx_frame.ndc_rect_vertices(
    quad.x,
    quad.y,
    quad.w,
    quad.h,
    frame.screen_w.to_double(),
    frame.screen_h.to_double(),
  )
  commands.push(
    @gfx_frame.new_primitive_command(frame, vertices, indices, quad.tint, src_image_ids=[
      quad.image.id,
    ]),
  )
}

///|
/// Convenience: build the command for a single placed image.
pub fn image_quad_command(
  frame : @gfx_frame.RenderFrame2D,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  image : @gfx.ImageHandle,
  tint? : @gfx.Color = @gfx.new_color(1.0, 1.0, 1.0, 1.0),
) -> @gfx.DrawTrianglesCommand {
  let (vertices, indices) = @gfx_frame.ndc_rect_vertices(
    x,
    y,
    w,
    h,
    frame.screen_w.to_double(),
    frame.screen_h.to_double(),
  )
  @gfx_frame.new_primitive_command(frame, vertices, indices, tint, src_image_ids=[
    image.id,
  ])
}
