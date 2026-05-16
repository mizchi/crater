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
  self.to_msvg().apply(t)
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
  Tween::from_msvg(
    @msvg.Tween::new(
      target_id,
      property.to_msvg(),
      duration,
      easing.to_msvg(),
    ),
  )
}

///|
/// Check if the tween is complete
pub fn Tween::is_complete(self : Tween) -> Bool {
  self.to_msvg().is_complete()
}

///|
/// Update the tween with delta time
/// Returns true if still running, false if complete
pub fn Tween::update(self : Tween, dt : Double, node : SVGNode) -> Bool {
  let tween = self.to_msvg()
  let msvg_node = svg_node_to_msvg(node)
  let running = tween.update(dt, msvg_node)
  self.sync_state_from_msvg(tween)
  node.sync_animation_state_from_msvg(msvg_node)
  running
}

///|
fn Easing::to_msvg(self : Easing) -> @msvg.Easing {
  match self {
    Linear => @msvg.Easing::Linear
    EaseIn => @msvg.Easing::EaseIn
    EaseOut => @msvg.Easing::EaseOut
    EaseInOut => @msvg.Easing::EaseInOut
    EaseInCubic => @msvg.Easing::EaseInCubic
    EaseOutCubic => @msvg.Easing::EaseOutCubic
    EaseInOutCubic => @msvg.Easing::EaseInOutCubic
  }
}

///|
fn Easing::from_msvg(easing : @msvg.Easing) -> Easing {
  match easing {
    Linear => Linear
    EaseIn => EaseIn
    EaseOut => EaseOut
    EaseInOut => EaseInOut
    EaseInCubic => EaseInCubic
    EaseOutCubic => EaseOutCubic
    EaseInOutCubic => EaseInOutCubic
  }
}

///|
fn AnimProperty::to_msvg(self : AnimProperty) -> @msvg.AnimProperty {
  match self {
    TranslateX(x) => @msvg.AnimProperty::TranslateX(x)
    TranslateY(y) => @msvg.AnimProperty::TranslateY(y)
    Translate(x, y) => @msvg.AnimProperty::Translate(x, y)
    ScaleX(sx) => @msvg.AnimProperty::ScaleX(sx)
    ScaleY(sy) => @msvg.AnimProperty::ScaleY(sy)
    Scale(sx, sy) => @msvg.AnimProperty::Scale(sx, sy)
    ScaleUniform(s) => @msvg.AnimProperty::ScaleUniform(s)
    Rotation(r) => @msvg.AnimProperty::Rotation(r)
    Opacity(o) => @msvg.AnimProperty::Opacity(o)
    FillColor(color) => @msvg.AnimProperty::FillColor(color.to_msvg())
  }
}

///|
fn AnimProperty::from_msvg(property : @msvg.AnimProperty) -> AnimProperty {
  match property {
    TranslateX(x) => TranslateX(x)
    TranslateY(y) => TranslateY(y)
    Translate(x, y) => Translate(x, y)
    ScaleX(sx) => ScaleX(sx)
    ScaleY(sy) => ScaleY(sy)
    Scale(sx, sy) => Scale(sx, sy)
    ScaleUniform(s) => ScaleUniform(s)
    Rotation(r) => Rotation(r)
    Opacity(o) => Opacity(o)
    FillColor(color) => FillColor(Color::from_msvg(color))
  }
}

///|
fn Tween::from_msvg(tween : @msvg.Tween) -> Tween {
  {
    target_id: tween.target_id,
    property: AnimProperty::from_msvg(tween.property),
    start_value: AnimProperty::from_msvg(tween.start_value),
    duration: tween.duration,
    elapsed: tween.elapsed,
    easing: Easing::from_msvg(tween.easing),
    started: tween.started,
    completed: tween.completed,
  }
}

///|
fn Tween::to_msvg(self : Tween) -> @msvg.Tween {
  @msvg.Tween::{
    target_id: self.target_id,
    property: self.property.to_msvg(),
    start_value: self.start_value.to_msvg(),
    duration: self.duration,
    elapsed: self.elapsed,
    easing: self.easing.to_msvg(),
    started: self.started,
    completed: self.completed,
  }
}

///|
fn Tween::sync_state_from_msvg(self : Tween, source : @msvg.Tween) -> Unit {
  self.start_value = AnimProperty::from_msvg(source.start_value)
  self.elapsed = source.elapsed
  self.started = source.started
  self.completed = source.completed
}
