///|
/// Animation manager for coordinating multiple tweens
pub(all) struct AnimationManager {
  tweens : Array[Tween]
}

///|
pub fn AnimationManager::new() -> AnimationManager {
  AnimationManager::from_msvg(@msvg.AnimationManager::new())
}

///|
/// Add a new tween animation
pub fn AnimationManager::add(self : AnimationManager, tween : Tween) -> Unit {
  let manager = self.to_msvg()
  manager.add(tween.to_msvg())
  self.sync_state_from_msvg(manager)
}

///|
/// Create and add a simple translate animation
pub fn AnimationManager::animate_translate(
  self : AnimationManager,
  target_id : String,
  x : Double,
  y : Double,
  duration : Double,
  easing : Easing,
) -> Unit {
  let manager = self.to_msvg()
  manager.animate_translate(target_id, x, y, duration, easing.to_msvg())
  self.sync_state_from_msvg(manager)
}

///|
/// Create and add a simple opacity animation
pub fn AnimationManager::animate_opacity(
  self : AnimationManager,
  target_id : String,
  opacity : Double,
  duration : Double,
  easing : Easing,
) -> Unit {
  let manager = self.to_msvg()
  manager.animate_opacity(target_id, opacity, duration, easing.to_msvg())
  self.sync_state_from_msvg(manager)
}

///|
/// Create and add a simple scale animation
pub fn AnimationManager::animate_scale(
  self : AnimationManager,
  target_id : String,
  scale : Double,
  duration : Double,
  easing : Easing,
) -> Unit {
  let manager = self.to_msvg()
  manager.animate_scale(target_id, scale, duration, easing.to_msvg())
  self.sync_state_from_msvg(manager)
}

///|
/// Update all animations with delta time
/// Returns true if any animations are still running
pub fn AnimationManager::update(
  self : AnimationManager,
  dt : Double,
  scene : Scene,
) -> Bool {
  let manager = self.to_msvg()
  let msvg_scene = scene.to_msvg()
  let any_running = manager.update(dt, msvg_scene)
  self.sync_state_from_msvg(manager)
  scene.sync_animation_state_from_msvg(msvg_scene)
  any_running
}

///|
/// Remove completed animations
pub fn AnimationManager::cleanup(self : AnimationManager) -> Unit {
  let manager = self.to_msvg()
  manager.cleanup()
  self.sync_state_from_msvg(manager)
}

///|
/// Check if any animations are running
pub fn AnimationManager::is_animating(self : AnimationManager) -> Bool {
  self.to_msvg().is_animating()
}

///|
/// Clear all animations
pub fn AnimationManager::clear(self : AnimationManager) -> Unit {
  let manager = self.to_msvg()
  manager.clear()
  self.sync_state_from_msvg(manager)
}

///|
fn AnimationManager::from_msvg(
  manager : @msvg.AnimationManager,
) -> AnimationManager {
  { tweens: manager.tweens.map(Tween::from_msvg) }
}

///|
fn AnimationManager::to_msvg(
  self : AnimationManager,
) -> @msvg.AnimationManager {
  @msvg.AnimationManager::{ tweens: self.tweens.map(fn(t) { t.to_msvg() }) }
}

///|
fn AnimationManager::sync_state_from_msvg(
  self : AnimationManager,
  source : @msvg.AnimationManager,
) -> Unit {
  self.tweens.clear()
  for tween in source.tweens {
    self.tweens.push(Tween::from_msvg(tween))
  }
}
