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
  Camera::from_msvg(@msvg.Camera::new(viewport_width, viewport_height))
}

///|
/// Move camera by delta
pub fn Camera::pan(self : Camera, dx : Double, dy : Double) -> Unit {
  let camera = self.to_msvg()
  camera.pan(dx, dy)
  self.sync_from_msvg(camera)
}

///|
/// Set camera position
pub fn Camera::set_position(self : Camera, x : Double, y : Double) -> Unit {
  let camera = self.to_msvg()
  camera.set_position(x, y)
  self.sync_from_msvg(camera)
}

///|
/// Set zoom level
pub fn Camera::set_zoom(self : Camera, zoom : Double) -> Unit {
  let camera = self.to_msvg()
  camera.set_zoom(zoom)
  self.sync_from_msvg(camera)
}

///|
/// Zoom by factor (multiply current zoom)
pub fn Camera::zoom_by(self : Camera, factor : Double) -> Unit {
  let camera = self.to_msvg()
  camera.zoom_by(factor)
  self.sync_from_msvg(camera)
}

///|
/// Get the world-space bounding box visible through this camera
pub fn Camera::get_visible_bounds(self : Camera) -> BoundingBox {
  BoundingBox::from_msvg(self.to_msvg().get_visible_bounds())
}

///|
/// Convert world coordinates to screen coordinates
pub fn Camera::world_to_screen(
  self : Camera,
  wx : Double,
  wy : Double,
) -> (Int, Int) {
  self.to_msvg().world_to_screen(wx, wy)
}

///|
/// Convert screen coordinates to world coordinates
pub fn Camera::screen_to_world(
  self : Camera,
  sx : Int,
  sy : Int,
) -> (Double, Double) {
  self.to_msvg().screen_to_world(sx, sy)
}

///|
/// Get transform matrix for this camera
pub fn Camera::get_transform(self : Camera) -> Transform {
  Transform::from_msvg(self.to_msvg().get_transform())
}

///|
fn Camera::from_msvg(camera : @msvg.Camera) -> Camera {
  {
    x: camera.x,
    y: camera.y,
    zoom: camera.zoom,
    viewport_width: camera.viewport_width,
    viewport_height: camera.viewport_height,
  }
}

///|
fn Camera::to_msvg(self : Camera) -> @msvg.Camera {
  @msvg.Camera::{
    x: self.x,
    y: self.y,
    zoom: self.zoom,
    viewport_width: self.viewport_width,
    viewport_height: self.viewport_height,
  }
}

///|
fn Camera::sync_from_msvg(self : Camera, source : @msvg.Camera) -> Unit {
  self.x = source.x
  self.y = source.y
  self.zoom = source.zoom
}
