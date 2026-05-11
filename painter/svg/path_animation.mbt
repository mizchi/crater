// ============================================================================
// Path Animation
// ============================================================================

///|
/// Path follower for animating along a path
pub(all) struct PathFollower {
  path : Array[PathCommand]
  polyline : Array[(Double, Double)] // Flattened path points
  lengths : Array[Double] // Cumulative lengths
  total_length : Double
  mut progress : Double // 0.0 to 1.0
  mut loop_anim : Bool
}

///|
pub fn PathFollower::new(path_data : String) -> PathFollower {
  path_follower_from_msvg(@msvg.PathFollower::new(path_data))
}

///|
/// Get position at current progress
pub fn PathFollower::get_position(self : PathFollower) -> (Double, Double) {
  path_follower_to_msvg(self).get_position()
}

///|
/// Update progress with delta time and speed
pub fn PathFollower::update(
  self : PathFollower,
  dt : Double,
  speed : Double,
) -> Bool {
  let follower = path_follower_to_msvg(self)
  let active = follower.update(dt, speed)
  copy_path_follower_state_from_msvg(self, follower)
  active
}
