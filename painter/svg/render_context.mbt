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
  RenderContext::from_msvg(
    @msvg.RenderContext::new(setter.to_msvg(), width, height),
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
  RenderContext::from_msvg(
    @msvg.RenderContext::with_clip(
      setter.to_msvg(),
      width,
      height,
      clip.to_msvg(),
    ),
  )
}

///|
/// Create a RenderContext for a camera
pub fn RenderContext::for_camera(
  setter : PixelSetter,
  camera : Camera,
) -> RenderContext {
  RenderContext::from_msvg(
    @msvg.RenderContext::for_camera(
      setter.to_msvg(),
      camera.to_msvg(),
    ),
  )
}

///|
fn RenderContext::from_msvg(ctx : @msvg.RenderContext) -> RenderContext {
  let clip = match ctx.clip {
    Some(c) => Some(ClipRect::from_msvg(c))
    None => None
  }
  {
    setter: PixelSetter::from_msvg(ctx.setter),
    width: ctx.width,
    height: ctx.height,
    flatness: ctx.flatness,
    clip,
  }
}

///|
fn RenderContext::to_msvg(self : RenderContext) -> @msvg.RenderContext {
  let clip = match self.clip {
    Some(c) => Some(c.to_msvg())
    None => None
  }
  @msvg.RenderContext::{
    setter: self.setter.to_msvg(),
    width: self.width,
    height: self.height,
    flatness: self.flatness,
    clip,
    text_to_paths: None,
  }
}
