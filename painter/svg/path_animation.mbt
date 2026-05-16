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
  PathFollower::from_msvg(@msvg.PathFollower::new(path_data))
}

///|
/// Get position at current progress
pub fn PathFollower::get_position(self : PathFollower) -> (Double, Double) {
  self.to_msvg().get_position()
}

///|
/// Update progress with delta time and speed
pub fn PathFollower::update(
  self : PathFollower,
  dt : Double,
  speed : Double,
) -> Bool {
  let follower = self.to_msvg()
  let active = follower.update(dt, speed)
  self.sync_state_from_msvg(follower)
  active
}

///|
fn PathFollower::from_msvg(follower : @msvg.PathFollower) -> PathFollower {
  {
    path: follower.path.map(PathCommand::from_msvg),
    polyline: follower.polyline,
    lengths: follower.lengths,
    total_length: follower.total_length,
    progress: follower.progress,
    loop_anim: follower.loop_anim,
  }
}

///|
fn PathFollower::to_msvg(self : PathFollower) -> @msvg.PathFollower {
  @msvg.PathFollower::{
    path: self.path.map(fn(c) { c.to_msvg() }),
    polyline: self.polyline,
    lengths: self.lengths,
    total_length: self.total_length,
    progress: self.progress,
    loop_anim: self.loop_anim,
  }
}

///|
fn PathFollower::sync_state_from_msvg(
  self : PathFollower,
  source : @msvg.PathFollower,
) -> Unit {
  self.progress = source.progress
  self.loop_anim = source.loop_anim
}
