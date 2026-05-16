///|
fn image_from_msvg(image : @msvg.Image) -> Image {
  {
    width: image.width,
    height: image.height,
    pixels: image.pixels.map(Color::from_msvg),
  }
}

///|
fn image_to_msvg(image : Image) -> @msvg.Image {
  @msvg.Image::{
    width: image.width,
    height: image.height,
    pixels: image.pixels.map(fn(c) { c.to_msvg() }),
  }
}

///|
fn copy_image_pixels_from_msvg(target : Image, source : @msvg.Image) -> Unit {
  let len = if target.pixels.length() < source.pixels.length() {
    target.pixels.length()
  } else {
    source.pixels.length()
  }
  for i in 0..<len {
    target.pixels[i] = Color::from_msvg(source.pixels[i])
  }
}

///|
fn image_rows_from_msvg(
  rows : Array[Array[@msvg.Color]],
) -> Array[Array[Color]] {
  rows.map(fn(row) { row.map(Color::from_msvg) })
}

///|
fn image_rows_to_msvg(rows : Array[Array[Color]]) -> Array[Array[@msvg.Color]] {
  rows.map(fn(row) { row.map(fn(c) { c.to_msvg() }) })
}

///|
fn sprite_from_msvg(sprite : @msvg.Sprite) -> Sprite {
  {
    image: image_from_msvg(sprite.image),
    x: sprite.x,
    y: sprite.y,
    width: sprite.width,
    height: sprite.height,
  }
}

///|
fn sprite_to_msvg(sprite : Sprite) -> @msvg.Sprite {
  @msvg.Sprite::{
    image: image_to_msvg(sprite.image),
    x: sprite.x,
    y: sprite.y,
    width: sprite.width,
    height: sprite.height,
  }
}

///|
fn sprite_sheet_from_msvg(sheet : @msvg.SpriteSheet) -> SpriteSheet {
  {
    image: image_from_msvg(sheet.image),
    tile_width: sheet.tile_width,
    tile_height: sheet.tile_height,
    columns: sheet.columns,
    rows: sheet.rows,
  }
}

///|
fn sprite_sheet_to_msvg(sheet : SpriteSheet) -> @msvg.SpriteSheet {
  @msvg.SpriteSheet::{
    image: image_to_msvg(sheet.image),
    tile_width: sheet.tile_width,
    tile_height: sheet.tile_height,
    columns: sheet.columns,
    rows: sheet.rows,
  }
}

///|
fn animated_sprite_from_msvg(sprite : @msvg.AnimatedSprite) -> AnimatedSprite {
  {
    sheet: sprite_sheet_from_msvg(sprite.sheet),
    frames: sprite.frames,
    current_frame: sprite.current_frame,
    frame_duration: sprite.frame_duration,
    elapsed: sprite.elapsed,
    looping: sprite.looping,
    playing: sprite.playing,
  }
}

///|
fn animated_sprite_to_msvg(sprite : AnimatedSprite) -> @msvg.AnimatedSprite {
  @msvg.AnimatedSprite::{
    sheet: sprite_sheet_to_msvg(sprite.sheet),
    frames: sprite.frames,
    current_frame: sprite.current_frame,
    frame_duration: sprite.frame_duration,
    elapsed: sprite.elapsed,
    looping: sprite.looping,
    playing: sprite.playing,
  }
}

///|
fn copy_animated_sprite_state_from_msvg(
  target : AnimatedSprite,
  source : @msvg.AnimatedSprite,
) -> Unit {
  target.current_frame = source.current_frame
  target.elapsed = source.elapsed
  target.looping = source.looping
  target.playing = source.playing
}

///|
fn particle_from_msvg(particle : @msvg.Particle) -> Particle {
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
fn particle_to_msvg(particle : Particle) -> @msvg.Particle {
  @msvg.Particle::{
    x: particle.x,
    y: particle.y,
    vx: particle.vx,
    vy: particle.vy,
    life: particle.life,
    max_life: particle.max_life,
    size: particle.size,
    color: particle.color.to_msvg(),
    active: particle.active,
  }
}

///|
fn copy_particle_from_msvg(target : Particle, source : @msvg.Particle) -> Unit {
  target.x = source.x
  target.y = source.y
  target.vx = source.vx
  target.vy = source.vy
  target.life = source.life
  target.max_life = source.max_life
  target.size = source.size
  target.color = Color::from_msvg(source.color)
  target.active = source.active
}

///|
fn emitter_config_from_msvg(config : @msvg.EmitterConfig) -> EmitterConfig {
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
fn emitter_config_to_msvg(config : EmitterConfig) -> @msvg.EmitterConfig {
  @msvg.EmitterConfig::{
    emit_rate: config.emit_rate,
    life_min: config.life_min,
    life_max: config.life_max,
    speed_min: config.speed_min,
    speed_max: config.speed_max,
    angle_min: config.angle_min,
    angle_max: config.angle_max,
    size_start: config.size_start,
    size_end: config.size_end,
    color_start: config.color_start.to_msvg(),
    color_end: config.color_end.to_msvg(),
    gravity_x: config.gravity_x,
    gravity_y: config.gravity_y,
  }
}

///|
fn particle_emitter_from_msvg(
  emitter : @msvg.ParticleEmitter,
) -> ParticleEmitter {
  {
    x: emitter.x,
    y: emitter.y,
    config: emitter_config_from_msvg(emitter.config),
    particles: emitter.particles.map(particle_from_msvg),
    emit_accumulator: emitter.emit_accumulator,
    active: emitter.active,
  }
}

///|
fn particle_emitter_to_msvg(emitter : ParticleEmitter) -> @msvg.ParticleEmitter {
  @msvg.ParticleEmitter::{
    x: emitter.x,
    y: emitter.y,
    config: emitter_config_to_msvg(emitter.config),
    particles: emitter.particles.map(particle_to_msvg),
    emit_accumulator: emitter.emit_accumulator,
    active: emitter.active,
  }
}

///|
fn copy_particle_emitter_state_from_msvg(
  target : ParticleEmitter,
  source : @msvg.ParticleEmitter,
) -> Unit {
  target.emit_accumulator = source.emit_accumulator
  target.active = source.active
  let len = if target.particles.length() < source.particles.length() {
    target.particles.length()
  } else {
    source.particles.length()
  }
  for i in 0..<len {
    copy_particle_from_msvg(target.particles[i], source.particles[i])
  }
}

///|
fn simple_rng_from_msvg(rng : @msvg.SimpleRNG) -> SimpleRNG {
  { state: rng.state }
}

///|
fn simple_rng_to_msvg(rng : SimpleRNG) -> @msvg.SimpleRNG {
  @msvg.SimpleRNG::{ state: rng.state }
}

///|
fn path_follower_from_msvg(follower : @msvg.PathFollower) -> PathFollower {
  {
    path: follower.path.map(path_command_from_msvg),
    polyline: follower.polyline,
    lengths: follower.lengths,
    total_length: follower.total_length,
    progress: follower.progress,
    loop_anim: follower.loop_anim,
  }
}

///|
fn path_follower_to_msvg(follower : PathFollower) -> @msvg.PathFollower {
  @msvg.PathFollower::{
    path: follower.path.map(path_command_to_msvg),
    polyline: follower.polyline,
    lengths: follower.lengths,
    total_length: follower.total_length,
    progress: follower.progress,
    loop_anim: follower.loop_anim,
  }
}

///|
fn copy_path_follower_state_from_msvg(
  target : PathFollower,
  source : @msvg.PathFollower,
) -> Unit {
  target.progress = source.progress
  target.loop_anim = source.loop_anim
}

///|
fn easing_to_msvg(easing : Easing) -> @msvg.Easing {
  match easing {
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
fn easing_from_msvg(easing : @msvg.Easing) -> Easing {
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
fn anim_property_to_msvg(property : AnimProperty) -> @msvg.AnimProperty {
  match property {
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
fn anim_property_from_msvg(property : @msvg.AnimProperty) -> AnimProperty {
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
fn tween_from_msvg(tween : @msvg.Tween) -> Tween {
  {
    target_id: tween.target_id,
    property: anim_property_from_msvg(tween.property),
    start_value: anim_property_from_msvg(tween.start_value),
    duration: tween.duration,
    elapsed: tween.elapsed,
    easing: easing_from_msvg(tween.easing),
    started: tween.started,
    completed: tween.completed,
  }
}

///|
fn tween_to_msvg(tween : Tween) -> @msvg.Tween {
  @msvg.Tween::{
    target_id: tween.target_id,
    property: anim_property_to_msvg(tween.property),
    start_value: anim_property_to_msvg(tween.start_value),
    duration: tween.duration,
    elapsed: tween.elapsed,
    easing: easing_to_msvg(tween.easing),
    started: tween.started,
    completed: tween.completed,
  }
}

///|
fn copy_tween_state_from_msvg(target : Tween, source : @msvg.Tween) -> Unit {
  target.start_value = anim_property_from_msvg(source.start_value)
  target.elapsed = source.elapsed
  target.started = source.started
  target.completed = source.completed
}

///|
fn copy_svg_node_animation_state_from_msvg(
  target : SVGNode,
  source : @msvg.SVGNode,
) -> Unit {
  let current_color = Color::from_msvg_option(source.color)
  target.transform = Transform::from_msvg(source.transform)
  target.fill = paint_from_msvg(source.fill, current_color)
  target.opacity = source.opacity
}

///|
fn animation_manager_from_msvg(
  manager : @msvg.AnimationManager,
) -> AnimationManager {
  { tweens: manager.tweens.map(tween_from_msvg) }
}

///|
fn animation_manager_to_msvg(
  manager : AnimationManager,
) -> @msvg.AnimationManager {
  @msvg.AnimationManager::{ tweens: manager.tweens.map(tween_to_msvg) }
}

///|
fn copy_animation_manager_state_from_msvg(
  target : AnimationManager,
  source : @msvg.AnimationManager,
) -> Unit {
  target.tweens.clear()
  for tween in source.tweens {
    target.tweens.push(tween_from_msvg(tween))
  }
}

///|
fn copy_svg_scene_animation_state_from_msvg(
  target : Scene,
  source : @msvg.Scene,
) -> Unit {
  target.dirty = source.dirty
  copy_svg_node_animation_tree_state_from_msvg(target.root, source.root)
}

///|
fn copy_svg_node_animation_tree_state_from_msvg(
  target : SVGNode,
  source : @msvg.SVGNode,
) -> Unit {
  copy_svg_node_animation_state_from_msvg(target, source)
  let len = if target.children.length() < source.children.length() {
    target.children.length()
  } else {
    source.children.length()
  }
  for i = 0; i < len; i = i + 1 {
    copy_svg_node_animation_tree_state_from_msvg(
      target.children[i],
      source.children[i],
    )
  }
}
