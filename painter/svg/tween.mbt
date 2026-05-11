// ============================================================================
// Animation / Tween System
// ============================================================================

///|
/// Easing functions for smooth animations
pub(all) enum Easing {
  Linear
  EaseIn // Quadratic ease in
  EaseOut // Quadratic ease out
  EaseInOut // Quadratic ease in-out
  EaseInCubic
  EaseOutCubic
  EaseInOutCubic
} derive(Eq, Debug)

///|
pub impl Show for Easing with output(self, logger) {
  let name = match self {
    Linear => "Linear"
    EaseIn => "EaseIn"
    EaseOut => "EaseOut"
    EaseInOut => "EaseInOut"
    EaseInCubic => "EaseInCubic"
    EaseOutCubic => "EaseOutCubic"
    EaseInOutCubic => "EaseInOutCubic"
  }
  logger.write_string(name)
}

///|
/// Apply easing function to a normalized time (0.0 to 1.0)
pub fn Easing::apply(self : Easing, t : Double) -> Double {
  easing_to_msvg(self).apply(t)
}

///|
/// Animatable property types
pub(all) enum AnimProperty {
  TranslateX(Double) // Target x translation
  TranslateY(Double) // Target y translation
  Translate(Double, Double) // Target (x, y) translation
  ScaleX(Double) // Target x scale
  ScaleY(Double) // Target y scale
  Scale(Double, Double) // Target (sx, sy) scale
  ScaleUniform(Double) // Target uniform scale
  Rotation(Double) // Target rotation in radians
  Opacity(Double) // Target opacity
  FillColor(Color) // Target fill color
}

///|
/// A single tween animation
pub(all) struct Tween {
  target_id : String // ID of the node to animate
  property : AnimProperty
  mut start_value : AnimProperty // Captured at start
  duration : Double // Duration in seconds
  mut elapsed : Double // Elapsed time in seconds
  easing : Easing
  mut started : Bool // Has the animation captured start values?
  mut completed : Bool
}

///|
/// Create a new tween
pub fn Tween::new(
  target_id : String,
  property : AnimProperty,
  duration : Double,
  easing : Easing,
) -> Tween {
  tween_from_msvg(
    @msvg.Tween::new(
      target_id,
      anim_property_to_msvg(property),
      duration,
      easing_to_msvg(easing),
    ),
  )
}

///|
/// Check if the tween is complete
pub fn Tween::is_complete(self : Tween) -> Bool {
  tween_to_msvg(self).is_complete()
}

///|
/// Update the tween with delta time
/// Returns true if still running, false if complete
pub fn Tween::update(self : Tween, dt : Double, node : SVGNode) -> Bool {
  let tween = tween_to_msvg(self)
  let msvg_node = svg_node_to_msvg(node)
  let running = tween.update(dt, msvg_node)
  copy_tween_state_from_msvg(self, tween)
  copy_svg_node_animation_state_from_msvg(node, msvg_node)
  running
}
