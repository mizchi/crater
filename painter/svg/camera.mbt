///|
/// Camera for 2D scene navigation
/// Supports pan (translation) and zoom
pub(all) struct Camera {
  mut x : Double // Camera position X (center)
  mut y : Double // Camera position Y (center)
  mut zoom : Double // Zoom level (1.0 = 100%)
  viewport_width : Int // Viewport width in pixels
  viewport_height : Int // Viewport height in pixels
}

///|
pub fn Camera::new(viewport_width : Int, viewport_height : Int) -> Camera {
  camera_from_msvg(@msvg.Camera::new(viewport_width, viewport_height))
}

///|
/// Move camera by delta
pub fn Camera::pan(self : Camera, dx : Double, dy : Double) -> Unit {
  let camera = camera_to_msvg(self)
  camera.pan(dx, dy)
  copy_camera_from_msvg(self, camera)
}

///|
/// Set camera position
pub fn Camera::set_position(self : Camera, x : Double, y : Double) -> Unit {
  let camera = camera_to_msvg(self)
  camera.set_position(x, y)
  copy_camera_from_msvg(self, camera)
}

///|
/// Set zoom level
pub fn Camera::set_zoom(self : Camera, zoom : Double) -> Unit {
  let camera = camera_to_msvg(self)
  camera.set_zoom(zoom)
  copy_camera_from_msvg(self, camera)
}

///|
/// Zoom by factor (multiply current zoom)
pub fn Camera::zoom_by(self : Camera, factor : Double) -> Unit {
  let camera = camera_to_msvg(self)
  camera.zoom_by(factor)
  copy_camera_from_msvg(self, camera)
}

///|
/// Get the world-space bounding box visible through this camera
pub fn Camera::get_visible_bounds(self : Camera) -> BoundingBox {
  bounding_box_from_msvg(camera_to_msvg(self).get_visible_bounds())
}

///|
/// Convert world coordinates to screen coordinates
pub fn Camera::world_to_screen(
  self : Camera,
  wx : Double,
  wy : Double,
) -> (Int, Int) {
  camera_to_msvg(self).world_to_screen(wx, wy)
}

///|
/// Convert screen coordinates to world coordinates
pub fn Camera::screen_to_world(
  self : Camera,
  sx : Int,
  sy : Int,
) -> (Double, Double) {
  camera_to_msvg(self).screen_to_world(sx, sy)
}

///|
/// Get transform matrix for this camera
pub fn Camera::get_transform(self : Camera) -> Transform {
  Transform::from_msvg(camera_to_msvg(self).get_transform())
}
