///|
/// Animation manager for coordinating multiple tweens
pub(all) struct AnimationManager {
  tweens : Array[Tween]
}

///|
pub fn AnimationManager::new() -> AnimationManager {
  animation_manager_from_msvg(@msvg.AnimationManager::new())
}

///|
/// Add a new tween animation
pub fn AnimationManager::add(self : AnimationManager, tween : Tween) -> Unit {
  let manager = animation_manager_to_msvg(self)
  manager.add(tween_to_msvg(tween))
  copy_animation_manager_state_from_msvg(self, manager)
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
  let manager = animation_manager_to_msvg(self)
  manager.animate_translate(target_id, x, y, duration, easing_to_msvg(easing))
  copy_animation_manager_state_from_msvg(self, manager)
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
  let manager = animation_manager_to_msvg(self)
  manager.animate_opacity(target_id, opacity, duration, easing_to_msvg(easing))
  copy_animation_manager_state_from_msvg(self, manager)
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
  let manager = animation_manager_to_msvg(self)
  manager.animate_scale(target_id, scale, duration, easing_to_msvg(easing))
  copy_animation_manager_state_from_msvg(self, manager)
}

///|
/// Update all animations with delta time
/// Returns true if any animations are still running
pub fn AnimationManager::update(
  self : AnimationManager,
  dt : Double,
  scene : Scene,
) -> Bool {
  let manager = animation_manager_to_msvg(self)
  let msvg_scene = scene_to_msvg(scene)
  let any_running = manager.update(dt, msvg_scene)
  copy_animation_manager_state_from_msvg(self, manager)
  copy_svg_scene_animation_state_from_msvg(scene, msvg_scene)
  any_running
}

///|
/// Remove completed animations
pub fn AnimationManager::cleanup(self : AnimationManager) -> Unit {
  let manager = animation_manager_to_msvg(self)
  manager.cleanup()
  copy_animation_manager_state_from_msvg(self, manager)
}

///|
/// Check if any animations are running
pub fn AnimationManager::is_animating(self : AnimationManager) -> Bool {
  animation_manager_to_msvg(self).is_animating()
}

///|
/// Clear all animations
pub fn AnimationManager::clear(self : AnimationManager) -> Unit {
  let manager = animation_manager_to_msvg(self)
  manager.clear()
  copy_animation_manager_state_from_msvg(self, manager)
}
