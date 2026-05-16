///|
/// Render the scene to a pixel setter
pub fn Scene::render(self : Scene, ctx : RenderContext) -> Unit {
  let scene = self.to_msvg()
  scene.render(ctx.to_msvg())
  self.clear_dirty()
}

///|
/// Render the scene with a camera transform
pub fn Scene::render_with_camera(
  self : Scene,
  ctx : RenderContext,
  camera : Camera,
) -> Unit {
  let scene = self.to_msvg()
  scene.render_with_camera(ctx.to_msvg(), camera.to_msvg())
  self.clear_dirty()
}

///|
/// Render the scene with viewBox coordinate mapping
pub fn Scene::render_with_viewbox(
  self : Scene,
  ctx : RenderContext,
  viewbox : ViewBox,
  preserve_aspect_ratio : PreserveAspectRatio,
) -> Unit {
  let scene = self.to_msvg()
  scene.render_with_viewbox(
    ctx.to_msvg(),
    viewbox.to_msvg(),
    preserve_aspect_ratio.to_msvg(),
  )
  self.clear_dirty()
}

///|
/// Render the scene with both viewBox and camera
pub fn Scene::render_with_viewbox_and_camera(
  self : Scene,
  ctx : RenderContext,
  viewbox : ViewBox,
  preserve_aspect_ratio : PreserveAspectRatio,
  camera : Camera,
) -> Unit {
  let scene = self.to_msvg()
  scene.render_with_viewbox_and_camera(
    ctx.to_msvg(),
    viewbox.to_msvg(),
    preserve_aspect_ratio.to_msvg(),
    camera.to_msvg(),
  )
  self.clear_dirty()
}
