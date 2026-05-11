///|
/// Render the scene to a pixel setter
pub fn Scene::render(self : Scene, ctx : RenderContext) -> Unit {
  let scene = scene_to_msvg(self)
  scene.render(render_context_to_msvg(ctx))
  self.clear_dirty()
}

///|
/// Render the scene with a camera transform
pub fn Scene::render_with_camera(
  self : Scene,
  ctx : RenderContext,
  camera : Camera,
) -> Unit {
  let scene = scene_to_msvg(self)
  scene.render_with_camera(render_context_to_msvg(ctx), camera_to_msvg(camera))
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
  let scene = scene_to_msvg(self)
  scene.render_with_viewbox(
    render_context_to_msvg(ctx),
    view_box_to_msvg(viewbox),
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
  let scene = scene_to_msvg(self)
  scene.render_with_viewbox_and_camera(
    render_context_to_msvg(ctx),
    view_box_to_msvg(viewbox),
    preserve_aspect_ratio.to_msvg(),
    camera_to_msvg(camera),
  )
  self.clear_dirty()
}
