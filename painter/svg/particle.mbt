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
  Particle::from_msvg(@msvg.Particle::new())
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
  EmitterConfig::from_msvg(@msvg.EmitterConfig::default())
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
  ParticleEmitter::from_msvg(
    @msvg.ParticleEmitter::new(
      x,
      y,
      config.to_msvg(),
      max_particles,
    ),
  )
}

///|
/// Update particles with delta time
pub fn ParticleEmitter::update(self : ParticleEmitter, dt : Double) -> Unit {
  let emitter = self.to_msvg()
  emitter.update(dt)
  self.sync_state_from_msvg(emitter)
}

///|
/// Simple pseudo-random number generator
pub(all) struct SimpleRNG {
  mut state : Int
}

///|
pub fn SimpleRNG::new(seed : Int) -> SimpleRNG {
  SimpleRNG::from_msvg(@msvg.SimpleRNG::new(seed))
}

///|
pub fn SimpleRNG::next(self : SimpleRNG) -> Double {
  let rng = self.to_msvg()
  let value = rng.next()
  self.state = rng.state
  value
}

///|
pub fn SimpleRNG::range(self : SimpleRNG, min : Double, max : Double) -> Double {
  let rng = self.to_msvg()
  let value = rng.range(min, max)
  self.state = rng.state
  value
}

///|
/// Get active particle count
pub fn ParticleEmitter::active_count(self : ParticleEmitter) -> Int {
  self.to_msvg().active_count()
}

///|
fn Particle::from_msvg(particle : @msvg.Particle) -> Particle {
  {
    x: particle.x,
    y: particle.y,
    vx: particle.vx,
    vy: particle.vy,
    life: particle.life,
    max_life: particle.max_life,
    size: particle.size,
    color: Color::from_msvg(particle.color),
    active: particle.active,
  }
}

///|
fn Particle::to_msvg(self : Particle) -> @msvg.Particle {
  @msvg.Particle::{
    x: self.x,
    y: self.y,
    vx: self.vx,
    vy: self.vy,
    life: self.life,
    max_life: self.max_life,
    size: self.size,
    color: self.color.to_msvg(),
    active: self.active,
  }
}

///|
fn Particle::sync_from_msvg(self : Particle, source : @msvg.Particle) -> Unit {
  self.x = source.x
  self.y = source.y
  self.vx = source.vx
  self.vy = source.vy
  self.life = source.life
  self.max_life = source.max_life
  self.size = source.size
  self.color = Color::from_msvg(source.color)
  self.active = source.active
}

///|
fn EmitterConfig::from_msvg(config : @msvg.EmitterConfig) -> EmitterConfig {
  {
    emit_rate: config.emit_rate,
    life_min: config.life_min,
    life_max: config.life_max,
    speed_min: config.speed_min,
    speed_max: config.speed_max,
    angle_min: config.angle_min,
    angle_max: config.angle_max,
    size_start: config.size_start,
    size_end: config.size_end,
    color_start: Color::from_msvg(config.color_start),
    color_end: Color::from_msvg(config.color_end),
    gravity_x: config.gravity_x,
    gravity_y: config.gravity_y,
  }
}

///|
fn EmitterConfig::to_msvg(self : EmitterConfig) -> @msvg.EmitterConfig {
  @msvg.EmitterConfig::{
    emit_rate: self.emit_rate,
    life_min: self.life_min,
    life_max: self.life_max,
    speed_min: self.speed_min,
    speed_max: self.speed_max,
    angle_min: self.angle_min,
    angle_max: self.angle_max,
    size_start: self.size_start,
    size_end: self.size_end,
    color_start: self.color_start.to_msvg(),
    color_end: self.color_end.to_msvg(),
    gravity_x: self.gravity_x,
    gravity_y: self.gravity_y,
  }
}

///|
fn ParticleEmitter::from_msvg(
  emitter : @msvg.ParticleEmitter,
) -> ParticleEmitter {
  {
    x: emitter.x,
    y: emitter.y,
    config: EmitterConfig::from_msvg(emitter.config),
    particles: emitter.particles.map(Particle::from_msvg),
    emit_accumulator: emitter.emit_accumulator,
    active: emitter.active,
  }
}

///|
fn ParticleEmitter::to_msvg(self : ParticleEmitter) -> @msvg.ParticleEmitter {
  @msvg.ParticleEmitter::{
    x: self.x,
    y: self.y,
    config: self.config.to_msvg(),
    particles: self.particles.map(fn(p) { p.to_msvg() }),
    emit_accumulator: self.emit_accumulator,
    active: self.active,
  }
}

///|
fn ParticleEmitter::sync_state_from_msvg(
  self : ParticleEmitter,
  source : @msvg.ParticleEmitter,
) -> Unit {
  self.emit_accumulator = source.emit_accumulator
  self.active = source.active
  let len = if self.particles.length() < source.particles.length() {
    self.particles.length()
  } else {
    source.particles.length()
  }
  for i in 0..<len {
    self.particles[i].sync_from_msvg(source.particles[i])
  }
}

///|
fn SimpleRNG::from_msvg(rng : @msvg.SimpleRNG) -> SimpleRNG {
  { state: rng.state }
}

///|
fn SimpleRNG::to_msvg(self : SimpleRNG) -> @msvg.SimpleRNG {
  @msvg.SimpleRNG::{ state: self.state }
}
