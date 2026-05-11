// ============================================================================
// Particle System
// ============================================================================

///|
/// Single particle state
pub(all) struct Particle {
  mut x : Double
  mut y : Double
  mut vx : Double // Velocity x
  mut vy : Double // Velocity y
  mut life : Double // Remaining life (seconds)
  mut max_life : Double // Initial life
  mut size : Double
  mut color : Color
  mut active : Bool
}

///|
pub fn Particle::new() -> Particle {
  particle_from_msvg(@msvg.Particle::new())
}

///|
/// Particle emitter configuration
pub(all) struct EmitterConfig {
  emit_rate : Double // Particles per second
  life_min : Double // Minimum particle life
  life_max : Double // Maximum particle life
  speed_min : Double // Minimum initial speed
  speed_max : Double // Maximum initial speed
  angle_min : Double // Minimum emission angle (radians)
  angle_max : Double // Maximum emission angle
  size_start : Double // Initial size
  size_end : Double // Final size (interpolated)
  color_start : Color
  color_end : Color
  gravity_x : Double
  gravity_y : Double
}

///|
pub fn EmitterConfig::default() -> EmitterConfig {
  emitter_config_from_msvg(@msvg.EmitterConfig::default())
}

///|
/// Particle emitter
pub(all) struct ParticleEmitter {
  x : Double
  y : Double
  config : EmitterConfig
  particles : Array[Particle]
  mut emit_accumulator : Double
  mut active : Bool
}

///|
pub fn ParticleEmitter::new(
  x : Double,
  y : Double,
  config : EmitterConfig,
  max_particles : Int,
) -> ParticleEmitter {
  particle_emitter_from_msvg(
    @msvg.ParticleEmitter::new(
      x,
      y,
      emitter_config_to_msvg(config),
      max_particles,
    ),
  )
}

///|
/// Update particles with delta time
pub fn ParticleEmitter::update(self : ParticleEmitter, dt : Double) -> Unit {
  let emitter = particle_emitter_to_msvg(self)
  emitter.update(dt)
  copy_particle_emitter_state_from_msvg(self, emitter)
}

///|
/// Simple pseudo-random number generator
pub(all) struct SimpleRNG {
  mut state : Int
}

///|
pub fn SimpleRNG::new(seed : Int) -> SimpleRNG {
  simple_rng_from_msvg(@msvg.SimpleRNG::new(seed))
}

///|
pub fn SimpleRNG::next(self : SimpleRNG) -> Double {
  let rng = simple_rng_to_msvg(self)
  let value = rng.next()
  self.state = rng.state
  value
}

///|
pub fn SimpleRNG::range(self : SimpleRNG, min : Double, max : Double) -> Double {
  let rng = simple_rng_to_msvg(self)
  let value = rng.range(min, max)
  self.state = rng.state
  value
}

///|
/// Get active particle count
pub fn ParticleEmitter::active_count(self : ParticleEmitter) -> Int {
  particle_emitter_to_msvg(self).active_count()
}
