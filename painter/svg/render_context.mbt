///|
/// Render context for drawing
pub(all) struct RenderContext {
  setter : PixelSetter
  width : Int
  height : Int
  flatness : Double // For path flattening
  clip : ClipRect? // Optional clipping rectangle for culling
}

///|
/// Create a RenderContext with default settings
pub fn RenderContext::new(
  setter : PixelSetter,
  width : Int,
  height : Int,
) -> RenderContext {
  render_context_from_msvg(
    @msvg.RenderContext::new(pixel_setter_to_msvg(setter), width, height),
  )
}

///|
/// Create a RenderContext with clipping
pub fn RenderContext::with_clip(
  setter : PixelSetter,
  width : Int,
  height : Int,
  clip : ClipRect,
) -> RenderContext {
  render_context_from_msvg(
    @msvg.RenderContext::with_clip(
      pixel_setter_to_msvg(setter),
      width,
      height,
      clip_rect_to_msvg(clip),
    ),
  )
}

///|
/// Create a RenderContext for a camera
pub fn RenderContext::for_camera(
  setter : PixelSetter,
  camera : Camera,
) -> RenderContext {
  render_context_from_msvg(
    @msvg.RenderContext::for_camera(
      pixel_setter_to_msvg(setter),
      camera_to_msvg(camera),
    ),
  )
}
