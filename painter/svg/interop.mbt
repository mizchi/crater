///|
/// Extract the root SVG viewBox with the shared SVG parser.
pub fn extract_root_view_box(svg_text : String) -> ViewBox? {
  match @msvg.parse_svg_document(svg_text) {
    Some(doc) =>
      match doc.root.view_box {
        Some(view_box) =>
          Some(ViewBox::{
            min_x: view_box.min_x,
            min_y: view_box.min_y,
            width: view_box.width,
            height: view_box.height,
          })
        None => None
      }
    None => None
  }
}

///|
fn transform_from_msvg(transform : @msvg.Transform) -> Transform {
  {
    a: transform.a,
    b: transform.b,
    c: transform.c,
    d: transform.d,
    e: transform.e,
    f: transform.f,
  }
}

///|
fn view_box_from_msvg(view_box : @msvg.ViewBox) -> ViewBox {
  {
    min_x: view_box.min_x,
    min_y: view_box.min_y,
    width: view_box.width,
    height: view_box.height,
  }
}

///|
fn view_box_to_msvg(view_box : ViewBox) -> @msvg.ViewBox {
  @msvg.ViewBox::{
    min_x: view_box.min_x,
    min_y: view_box.min_y,
    width: view_box.width,
    height: view_box.height,
  }
}

///|
fn view_box_from_msvg_option(view_box : @msvg.ViewBox?) -> ViewBox? {
  match view_box {
    Some(vb) => Some(view_box_from_msvg(vb))
    None => None
  }
}

///|
fn view_box_to_msvg_option(view_box : ViewBox?) -> @msvg.ViewBox? {
  match view_box {
    Some(vb) => Some(view_box_to_msvg(vb))
    None => None
  }
}

///|
fn color_from_msvg(color : @msvg.Color) -> Color {
  { r: color.r, g: color.g, b: color.b, a: color.a }
}

///|
fn color_to_msvg(color : Color) -> @msvg.Color {
  @msvg.Color::{ r: color.r, g: color.g, b: color.b, a: color.a }
}

///|
fn pointer_event_from_msvg(event : @msvg.PointerEvent) -> PointerEvent {
  {
    x: event.x,
    y: event.y,
    button: event.button,
    target: event.target,
    propagation_stopped: event.propagation_stopped,
  }
}

///|
fn pointer_event_to_msvg(event : PointerEvent) -> @msvg.PointerEvent {
  let msvg_event = @msvg.PointerEvent::new(
    event.x,
    event.y,
    event.button,
    event.target,
  )
  if event.propagation_stopped {
    msvg_event.stop_propagation()
  }
  msvg_event
}

///|
fn copy_pointer_event_state_from_msvg(
  target : PointerEvent,
  source : @msvg.PointerEvent,
) -> Unit {
  target.propagation_stopped = source.propagation_stopped
}

///|
fn[T] object_pool_from_msvg(pool : @msvg.ObjectPool[T]) -> ObjectPool[T] {
  { available: pool.available, factory: pool.factory, reset: pool.reset }
}

///|
fn[T] object_pool_to_msvg(pool : ObjectPool[T]) -> @msvg.ObjectPool[T] {
  @msvg.ObjectPool::{
    available: pool.available,
    factory: pool.factory,
    reset: pool.reset,
  }
}

///|
fn white_space_to_msvg(mode : WhiteSpace) -> @msvg.WhiteSpace {
  match mode {
    Normal => @msvg.WhiteSpace::Normal
    Pre => @msvg.WhiteSpace::Pre
    NoWrap => @msvg.WhiteSpace::NoWrap
    PreWrap => @msvg.WhiteSpace::PreWrap
    PreLine => @msvg.WhiteSpace::PreLine
    BreakSpaces => @msvg.WhiteSpace::BreakSpaces
  }
}

///|
fn text_overflow_to_msvg(overflow : TextOverflow) -> @msvg.TextOverflow {
  match overflow {
    Clip => @msvg.TextOverflow::Clip
    Ellipsis => @msvg.TextOverflow::Ellipsis
    Custom(indicator) => @msvg.TextOverflow::Custom(indicator)
  }
}

///|
fn text_anchor_from_msvg(anchor : @msvg.TextAnchor) -> TextAnchor {
  match anchor {
    Start => Start
    Middle => Middle
    End => End
  }
}

///|
fn text_anchor_to_msvg(anchor : TextAnchor) -> @msvg.TextAnchor {
  match anchor {
    Start => @msvg.TextAnchor::Start
    Middle => @msvg.TextAnchor::Middle
    End => @msvg.TextAnchor::End
  }
}

///|
fn writing_mode_from_msvg(mode : @msvg.WritingMode) -> WritingMode {
  match mode {
    HorizontalTB => HorizontalTB
    VerticalRL => VerticalRL
    VerticalLR => VerticalLR
  }
}

///|
fn writing_mode_to_msvg(mode : WritingMode) -> @msvg.WritingMode {
  match mode {
    HorizontalTB => @msvg.WritingMode::HorizontalTB
    VerticalRL => @msvg.WritingMode::VerticalRL
    VerticalLR => @msvg.WritingMode::VerticalLR
  }
}

///|
fn text_orientation_from_msvg(
  orientation : @msvg.TextOrientation,
) -> TextOrientation {
  match orientation {
    Mixed => Mixed
    Upright => Upright
    Sideways => Sideways
  }
}

///|
fn text_orientation_to_msvg(
  orientation : TextOrientation,
) -> @msvg.TextOrientation {
  match orientation {
    Mixed => @msvg.TextOrientation::Mixed
    Upright => @msvg.TextOrientation::Upright
    Sideways => @msvg.TextOrientation::Sideways
  }
}

///|
fn white_space_from_msvg(mode : @msvg.WhiteSpace) -> WhiteSpace {
  match mode {
    Normal => Normal
    Pre => Pre
    NoWrap => NoWrap
    PreWrap => PreWrap
    PreLine => PreLine
    BreakSpaces => BreakSpaces
  }
}

///|
fn text_overflow_from_msvg(overflow : @msvg.TextOverflow) -> TextOverflow {
  match overflow {
    Clip => Clip
    Ellipsis => Ellipsis
    Custom(indicator) => Custom(indicator)
  }
}

///|
fn text_decoration_style_from_msvg(
  style : @msvg.TextDecorationStyle,
) -> TextDecorationStyle {
  match style {
    Solid => Solid
    Double => Double
    Dotted => Dotted
    Dashed => Dashed
    Wavy => Wavy
  }
}

///|
fn text_decoration_from_msvg(
  decoration : @msvg.TextDecoration,
) -> TextDecoration {
  match decoration {
    NoDecoration => NoDecoration
    Underline => Underline
    Overline => Overline
    LineThrough => LineThrough
  }
}

///|
fn text_decoration_to_msvg(decoration : TextDecoration) -> @msvg.TextDecoration {
  match decoration {
    NoDecoration => @msvg.TextDecoration::NoDecoration
    Underline => @msvg.TextDecoration::Underline
    Overline => @msvg.TextDecoration::Overline
    LineThrough => @msvg.TextDecoration::LineThrough
  }
}

///|
fn font_weight_from_msvg(weight : @msvg.FontWeight) -> FontWeight {
  match weight {
    Normal => Normal
    Bold => Bold
    Lighter => Lighter
    Bolder => Bolder
    Weight(value) => Weight(value)
  }
}

///|
fn font_weight_to_msvg(weight : FontWeight) -> @msvg.FontWeight {
  match weight {
    Normal => @msvg.FontWeight::Normal
    Bold => @msvg.FontWeight::Bold
    Lighter => @msvg.FontWeight::Lighter
    Bolder => @msvg.FontWeight::Bolder
    Weight(value) => @msvg.FontWeight::Weight(value)
  }
}

///|
fn font_style_from_msvg(style : @msvg.FontStyle) -> FontStyle {
  match style {
    NormalStyle => NormalStyle
    Italic => Italic
    Oblique => Oblique
  }
}

///|
fn font_style_to_msvg(style : FontStyle) -> @msvg.FontStyle {
  match style {
    NormalStyle => @msvg.FontStyle::NormalStyle
    Italic => @msvg.FontStyle::Italic
    Oblique => @msvg.FontStyle::Oblique
  }
}

///|
fn dominant_baseline_from_msvg(
  baseline : @msvg.DominantBaseline,
) -> DominantBaseline {
  match baseline {
    Auto => Auto
    TextTop => TextTop
    Hanging => Hanging
    Middle => Middle
    Central => Central
    TextBottom => TextBottom
    Alphabetic => Alphabetic
    Ideographic => Ideographic
  }
}

///|
fn dominant_baseline_to_msvg(
  baseline : DominantBaseline,
) -> @msvg.DominantBaseline {
  match baseline {
    Auto => @msvg.DominantBaseline::Auto
    TextTop => @msvg.DominantBaseline::TextTop
    Hanging => @msvg.DominantBaseline::Hanging
    Middle => @msvg.DominantBaseline::Middle
    Central => @msvg.DominantBaseline::Central
    TextBottom => @msvg.DominantBaseline::TextBottom
    Alphabetic => @msvg.DominantBaseline::Alphabetic
    Ideographic => @msvg.DominantBaseline::Ideographic
  }
}

///|
fn paint_order_from_msvg(order : @msvg.PaintOrder) -> PaintOrder {
  if order.order.length() == 1 {
    match order.order[0] {
      Fill => FillOnly
      Stroke => StrokeOnly
      Markers => Normal
    }
  } else if order.order.length() >= 2 {
    match (order.order[0], order.order[1]) {
      (Stroke, Fill) => StrokeFirst
      _ => Normal
    }
  } else {
    Normal
  }
}

///|
fn paint_order_to_msvg(order : PaintOrder) -> @msvg.PaintOrder {
  let items = match order {
    Normal =>
      [
        @msvg.PaintOrderItem::Fill,
        @msvg.PaintOrderItem::Stroke,
        @msvg.PaintOrderItem::Markers,
      ]
    StrokeFirst =>
      [
        @msvg.PaintOrderItem::Stroke,
        @msvg.PaintOrderItem::Fill,
        @msvg.PaintOrderItem::Markers,
      ]
    FillOnly => [@msvg.PaintOrderItem::Fill]
    StrokeOnly => [@msvg.PaintOrderItem::Stroke]
  }
  @msvg.PaintOrder::{ order: items }
}

///|
fn text_decoration_full_from_msvg(
  decoration : @msvg.TextDecorationFull,
) -> TextDecorationFull {
  {
    line: text_decoration_from_msvg(decoration.line),
    style: text_decoration_style_from_msvg(decoration.style),
    color: color_from_msvg_option(decoration.color),
    thickness: decoration.thickness,
  }
}

///|
fn text_style_from_msvg(style : @msvg.TextStyle) -> TextStyle {
  {
    font_family: style.font_family,
    font_size: style.font_size,
    font_weight: font_weight_from_msvg(style.font_weight),
    font_style: font_style_from_msvg(style.font_style),
    text_anchor: text_anchor_from_msvg(style.text_anchor),
    dominant_baseline: dominant_baseline_from_msvg(style.dominant_baseline),
    text_decoration: text_decoration_from_msvg(style.text_decoration),
    letter_spacing: style.letter_spacing,
    word_spacing: style.word_spacing,
    line_height: style.line_height,
    writing_mode: writing_mode_from_msvg(style.writing_mode),
    text_orientation: text_orientation_from_msvg(style.text_orientation),
    white_space: white_space_from_msvg(style.white_space),
    paint_order: paint_order_from_msvg(style.paint_order),
  }
}

///|
fn text_style_to_msvg(style : TextStyle) -> @msvg.TextStyle {
  @msvg.TextStyle::{
    font_family: style.font_family,
    font_size: style.font_size,
    font_weight: font_weight_to_msvg(style.font_weight),
    font_style: font_style_to_msvg(style.font_style),
    text_anchor: text_anchor_to_msvg(style.text_anchor),
    dominant_baseline: dominant_baseline_to_msvg(style.dominant_baseline),
    text_decoration: text_decoration_to_msvg(style.text_decoration),
    letter_spacing: style.letter_spacing,
    word_spacing: style.word_spacing,
    line_height: style.line_height,
    writing_mode: writing_mode_to_msvg(style.writing_mode),
    text_orientation: text_orientation_to_msvg(style.text_orientation),
    white_space: white_space_to_msvg(style.white_space),
    paint_order: paint_order_to_msvg(style.paint_order),
  }
}

///|
fn text_span_from_msvg(span : @msvg.TextSpan) -> TextSpan {
  {
    text: span.text,
    x: span.x,
    y: span.y,
    dx: span.dx,
    dy: span.dy,
    style: match span.style {
      Some(style) => Some(text_style_from_msvg(style))
      None => None
    },
  }
}

///|
fn text_span_to_msvg(span : TextSpan) -> @msvg.TextSpan {
  @msvg.TextSpan::{
    text: span.text,
    x: span.x,
    y: span.y,
    dx: span.dx,
    dy: span.dy,
    style: match span.style {
      Some(style) => Some(text_style_to_msvg(style))
      None => None
    },
  }
}

///|
fn text_block_from_msvg(block : @msvg.TextBlock) -> TextBlock {
  {
    spans: block.spans.map(text_span_from_msvg),
    x: block.x,
    y: block.y,
    style: text_style_from_msvg(block.style),
    inline_size: block.inline_size,
    text_overflow: text_overflow_from_msvg(block.text_overflow),
  }
}

///|
fn text_block_to_msvg(block : TextBlock) -> @msvg.TextBlock {
  @msvg.TextBlock::{
    spans: block.spans.map(text_span_to_msvg),
    x: block.x,
    y: block.y,
    style: text_style_to_msvg(block.style),
    inline_size: block.inline_size,
    text_overflow: text_overflow_to_msvg(block.text_overflow),
  }
}

///|
fn use_element_from_msvg(use_element : @msvg.UseElement) -> UseElement {
  {
    href: use_element.href,
    x: use_element.x,
    y: use_element.y,
    width: use_element.width,
    height: use_element.height,
    transform: transform_from_msvg(use_element.transform),
  }
}

///|
fn use_element_to_msvg(use_element : UseElement) -> @msvg.UseElement {
  @msvg.UseElement::{
    href: use_element.href,
    x: use_element.x,
    y: use_element.y,
    width: use_element.width,
    height: use_element.height,
    transform: use_element.transform.to_msvg(),
  }
}

///|
fn symbol_from_msvg(symbol : @msvg.Symbol) -> Symbol {
  {
    id: symbol.id,
    content: svg_node_from_msvg(symbol.content),
    view_box: view_box_from_msvg_option(symbol.view_box),
    preserve_aspect_ratio: PreserveAspectRatio::default(),
  }
}

///|
fn color_from_msvg_option(color : @msvg.Color?) -> Color? {
  match color {
    Some(c) => Some(color_from_msvg(c))
    None => None
  }
}

///|
fn image_from_msvg(image : @msvg.Image) -> Image {
  {
    width: image.width,
    height: image.height,
    pixels: image.pixels.map(color_from_msvg),
  }
}

///|
fn image_to_msvg(image : Image) -> @msvg.Image {
  @msvg.Image::{
    width: image.width,
    height: image.height,
    pixels: image.pixels.map(color_to_msvg),
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
    target.pixels[i] = color_from_msvg(source.pixels[i])
  }
}

///|
fn image_rows_from_msvg(
  rows : Array[Array[@msvg.Color]],
) -> Array[Array[Color]] {
  rows.map(fn(row) { row.map(color_from_msvg) })
}

///|
fn image_rows_to_msvg(rows : Array[Array[Color]]) -> Array[Array[@msvg.Color]] {
  rows.map(fn(row) { row.map(color_to_msvg) })
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
    color: color_from_msvg(particle.color),
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
    color: color_to_msvg(particle.color),
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
  target.color = color_from_msvg(source.color)
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
    color_start: color_from_msvg(config.color_start),
    color_end: color_from_msvg(config.color_end),
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
    color_start: color_to_msvg(config.color_start),
    color_end: color_to_msvg(config.color_end),
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
    FillColor(color) => @msvg.AnimProperty::FillColor(color_to_msvg(color))
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
    FillColor(color) => FillColor(color_from_msvg(color))
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
  let current_color = color_from_msvg_option(source.color)
  target.transform = transform_from_msvg(source.transform)
  target.fill = paint_from_msvg(source.fill, current_color)
  target.opacity = source.opacity
}

///|
fn current_color_or_black(current_color : Color?) -> Color {
  match current_color {
    Some(color) => color
    None => Color::black()
  }
}

///|
fn fill_rule_from_msvg(rule : @msvg.FillRule) -> FillRule {
  match rule {
    NonZero => NonZero
    EvenOdd => EvenOdd
  }
}

///|
fn fill_rule_to_msvg(rule : FillRule) -> @msvg.FillRule {
  match rule {
    NonZero => @msvg.FillRule::NonZero
    EvenOdd => @msvg.FillRule::EvenOdd
  }
}

///|
fn linecap_from_msvg(linecap : @msvg.LineCap) -> LineCap {
  match linecap {
    Butt => Butt
    Round => Round
    Square => Square
  }
}

///|
fn linecap_to_msvg(linecap : LineCap) -> @msvg.LineCap {
  match linecap {
    Butt => @msvg.LineCap::Butt
    Round => @msvg.LineCap::Round
    Square => @msvg.LineCap::Square
  }
}

///|
fn linejoin_from_msvg(linejoin : @msvg.LineJoin) -> LineJoin {
  match linejoin {
    Miter => Miter
    Round => Round
    Bevel => Bevel
  }
}

///|
fn linejoin_to_msvg(linejoin : LineJoin) -> @msvg.LineJoin {
  match linejoin {
    Miter => @msvg.LineJoin::Miter
    Round => @msvg.LineJoin::Round
    Bevel => @msvg.LineJoin::Bevel
  }
}

///|
fn spread_method_from_msvg(spread : @msvg.SpreadMethod) -> SpreadMethod {
  match spread {
    Pad => Pad
    Repeat => Repeat
    Reflect => Reflect
  }
}

///|
fn spread_method_to_msvg(spread : SpreadMethod) -> @msvg.SpreadMethod {
  match spread {
    Pad => @msvg.SpreadMethod::Pad
    Repeat => @msvg.SpreadMethod::Repeat
    Reflect => @msvg.SpreadMethod::Reflect
  }
}

///|
fn gradient_stop_from_msvg(stop : @msvg.GradientStop) -> GradientStop {
  { offset: stop.offset, color: color_from_msvg(stop.color) }
}

///|
fn gradient_stop_to_msvg(stop : GradientStop) -> @msvg.GradientStop {
  @msvg.GradientStop::{ offset: stop.offset, color: color_to_msvg(stop.color) }
}

///|
fn linear_gradient_from_msvg(grad : @msvg.LinearGradient) -> LinearGradient {
  {
    x1: grad.x1,
    y1: grad.y1,
    x2: grad.x2,
    y2: grad.y2,
    stops: grad.stops.map(gradient_stop_from_msvg),
    spread_method: spread_method_from_msvg(grad.spread_method),
  }
}

///|
fn linear_gradient_to_msvg(grad : LinearGradient) -> @msvg.LinearGradient {
  @msvg.LinearGradient::{
    x1: grad.x1,
    y1: grad.y1,
    x2: grad.x2,
    y2: grad.y2,
    stops: grad.stops.map(gradient_stop_to_msvg),
    spread_method: spread_method_to_msvg(grad.spread_method),
    units: @msvg.GradientUnits::ObjectBoundingBox,
    transform: @msvg.Transform::identity(),
  }
}

///|
fn radial_gradient_from_msvg(grad : @msvg.RadialGradient) -> RadialGradient {
  {
    cx: grad.cx,
    cy: grad.cy,
    fx: grad.fx,
    fy: grad.fy,
    r: grad.r,
    stops: grad.stops.map(gradient_stop_from_msvg),
    spread_method: spread_method_from_msvg(grad.spread_method),
  }
}

///|
fn radial_gradient_to_msvg(grad : RadialGradient) -> @msvg.RadialGradient {
  @msvg.RadialGradient::{
    cx: grad.cx,
    cy: grad.cy,
    fx: grad.fx,
    fy: grad.fy,
    r: grad.r,
    stops: grad.stops.map(gradient_stop_to_msvg),
    spread_method: spread_method_to_msvg(grad.spread_method),
    units: @msvg.GradientUnits::ObjectBoundingBox,
    transform: @msvg.Transform::identity(),
  }
}

///|
fn pixel_setter_to_msvg(setter : PixelSetter) -> @msvg.PixelSetter {
  @msvg.PixelSetter::{
    set: fn(x, y, color) { setter.pixel(x, y, color_from_msvg(color)) },
  }
}

///|
fn paint_fallback_from_msvg(
  fallback : @msvg.PaintFallback,
  current_color : Color?,
) -> Paint {
  match fallback {
    NoPaint => SolidColor(Color::black())
    SolidColor(color) => SolidColor(color_from_msvg(color))
    CurrentColor => SolidColor(current_color_or_black(current_color))
  }
}

///|
fn paint_from_msvg(paint : @msvg.Paint, current_color : Color?) -> Paint {
  match paint {
    None => None
    SolidColor(color) => SolidColor(color_from_msvg(color))
    LinearGrad(grad) => LinearGrad(linear_gradient_from_msvg(grad))
    RadialGrad(grad) => RadialGrad(radial_gradient_from_msvg(grad))
    CurrentColor => SolidColor(current_color_or_black(current_color))
    PaintServerRef(_, fallback) =>
      paint_fallback_from_msvg(fallback, current_color)
  }
}

///|
fn paint_to_msvg(paint : Paint) -> @msvg.Paint {
  match paint {
    None => @msvg.Paint::None
    SolidColor(color) => @msvg.Paint::SolidColor(color_to_msvg(color))
    LinearGrad(grad) => @msvg.Paint::LinearGrad(linear_gradient_to_msvg(grad))
    RadialGrad(grad) => @msvg.Paint::RadialGrad(radial_gradient_to_msvg(grad))
  }
}

///|
fn stroke_style_from_msvg(
  stroke : @msvg.StrokeStyle,
  current_color : Color?,
) -> StrokeStyle {
  {
    paint: paint_from_msvg(stroke.paint, current_color),
    width: stroke.width,
    linecap: linecap_from_msvg(stroke.linecap),
    linejoin: linejoin_from_msvg(stroke.linejoin),
    miterlimit: stroke.miterlimit,
    dasharray: stroke.dasharray,
    dashoffset: stroke.dashoffset,
  }
}

///|
fn stroke_style_to_msvg(stroke : StrokeStyle) -> @msvg.StrokeStyle {
  @msvg.StrokeStyle::{
    paint: paint_to_msvg(stroke.paint),
    width: stroke.width,
    linecap: linecap_to_msvg(stroke.linecap),
    linejoin: linejoin_to_msvg(stroke.linejoin),
    miterlimit: stroke.miterlimit,
    dasharray: stroke.dasharray,
    dashoffset: stroke.dashoffset,
  }
}

///|
fn filter_from_msvg(filter : @msvg.Filter) -> Filter {
  match filter {
    Blur(value) => Blur(value)
    DropShadow(dx, dy, blur, color) =>
      DropShadow(dx, dy, blur, color_from_msvg(color))
    Brightness(value) => Brightness(value)
    Contrast(value) => Contrast(value)
    Grayscale(value) => Grayscale(value)
    Sepia(value) => Sepia(value)
    HueRotate(value) => HueRotate(value)
    Invert(value) => Invert(value)
    Saturate(value) => Saturate(value)
    ColorMatrix(values) => ColorMatrix(values)
  }
}

///|
fn filter_to_msvg(filter : Filter) -> @msvg.Filter {
  match filter {
    Blur(value) => @msvg.Filter::Blur(value)
    DropShadow(dx, dy, blur, color) =>
      @msvg.Filter::DropShadow(dx, dy, blur, color_to_msvg(color))
    Brightness(value) => @msvg.Filter::Brightness(value)
    Contrast(value) => @msvg.Filter::Contrast(value)
    Grayscale(value) => @msvg.Filter::Grayscale(value)
    Sepia(value) => @msvg.Filter::Sepia(value)
    HueRotate(value) => @msvg.Filter::HueRotate(value)
    Invert(value) => @msvg.Filter::Invert(value)
    Saturate(value) => @msvg.Filter::Saturate(value)
    ColorMatrix(values) => @msvg.Filter::ColorMatrix(values)
  }
}

///|
fn blend_mode_to_msvg(mode : BlendMode) -> @msvg.BlendMode {
  match mode {
    Normal => @msvg.BlendMode::Normal
    Multiply => @msvg.BlendMode::Multiply
    Screen => @msvg.BlendMode::Screen
    Overlay => @msvg.BlendMode::Overlay
    Darken => @msvg.BlendMode::Darken
    Lighten => @msvg.BlendMode::Lighten
    ColorDodge => @msvg.BlendMode::ColorDodge
    ColorBurn => @msvg.BlendMode::ColorBurn
    HardLight => @msvg.BlendMode::HardLight
    SoftLight => @msvg.BlendMode::SoftLight
    Difference => @msvg.BlendMode::Difference
    Exclusion => @msvg.BlendMode::Exclusion
    Hue => @msvg.BlendMode::Hue
    Saturation => @msvg.BlendMode::Saturation
    ColorMode => @msvg.BlendMode::ColorMode
    Luminosity => @msvg.BlendMode::Luminosity
  }
}

///|
fn pattern_units_from_msvg(units : @msvg.PatternUnits) -> PatternUnits {
  match units {
    UserSpaceOnUse => UserSpaceOnUse
    ObjectBoundingBox => ObjectBoundingBox
  }
}

///|
fn pattern_units_to_msvg(units : PatternUnits) -> @msvg.PatternUnits {
  match units {
    UserSpaceOnUse => @msvg.PatternUnits::UserSpaceOnUse
    ObjectBoundingBox => @msvg.PatternUnits::ObjectBoundingBox
  }
}

///|
fn mask_units_from_msvg(units : @msvg.MaskUnits) -> MaskUnits {
  match units {
    UserSpaceOnUse => UserSpaceOnUse
    ObjectBoundingBox => ObjectBoundingBox
  }
}

///|
fn mask_units_to_msvg(units : MaskUnits) -> @msvg.MaskUnits {
  match units {
    UserSpaceOnUse => @msvg.MaskUnits::UserSpaceOnUse
    ObjectBoundingBox => @msvg.MaskUnits::ObjectBoundingBox
  }
}

///|
fn mask_type_from_msvg(mask_type : @msvg.MaskType) -> MaskType {
  match mask_type {
    Luminance => Luminance
    Alpha => Alpha
  }
}

///|
fn mask_type_to_msvg(mask_type : MaskType) -> @msvg.MaskType {
  match mask_type {
    Luminance => @msvg.MaskType::Luminance
    Alpha => @msvg.MaskType::Alpha
  }
}

///|
fn mask_from_msvg(mask : @msvg.Mask, content : Array[SVGNode]) -> Mask {
  {
    id: mask.id,
    content,
    x: mask.x,
    y: mask.y,
    width: mask.width,
    height: mask.height,
    mask_units: mask_units_from_msvg(mask.mask_units),
    mask_content_units: mask_units_from_msvg(mask.mask_content_units),
    mask_type: mask_type_from_msvg(mask.mask_type),
  }
}

///|
fn mask_to_msvg(mask : Mask) -> @msvg.Mask {
  @msvg.Mask::{
    id: mask.id,
    content: [],
    x: mask.x,
    y: mask.y,
    width: mask.width,
    height: mask.height,
    x_is_percent: false,
    y_is_percent: false,
    width_is_percent: false,
    height_is_percent: false,
    mask_units: mask_units_to_msvg(mask.mask_units),
    mask_content_units: mask_units_to_msvg(mask.mask_content_units),
    mask_type: mask_type_to_msvg(mask.mask_type),
  }
}

///|
pub fn path_command_from_msvg(cmd : @msvg.PathCommand) -> PathCommand {
  match cmd {
    MoveTo(x, y) => MoveTo(x, y)
    LineTo(x, y) => LineTo(x, y)
    HorizontalLineTo(x) => HorizontalLineTo(x)
    VerticalLineTo(y) => VerticalLineTo(y)
    CurveTo(x1, y1, x2, y2, x, y) => CurveTo(x1, y1, x2, y2, x, y)
    SmoothCurveTo(x2, y2, x, y) => SmoothCurveTo(x2, y2, x, y)
    QuadraticCurveTo(x1, y1, x, y) => QuadraticCurveTo(x1, y1, x, y)
    SmoothQuadraticCurveTo(x, y) => SmoothQuadraticCurveTo(x, y)
    ArcTo(rx, ry, rotation, large_arc, sweep, x, y) =>
      ArcTo(rx, ry, rotation, large_arc, sweep, x, y)
    ClosePath => ClosePath
    MoveToRel(dx, dy) => MoveToRel(dx, dy)
    LineToRel(dx, dy) => LineToRel(dx, dy)
    HorizontalLineToRel(dx) => HorizontalLineToRel(dx)
    VerticalLineToRel(dy) => VerticalLineToRel(dy)
    CurveToRel(dx1, dy1, dx2, dy2, dx, dy) =>
      CurveToRel(dx1, dy1, dx2, dy2, dx, dy)
    SmoothCurveToRel(dx2, dy2, dx, dy) => SmoothCurveToRel(dx2, dy2, dx, dy)
    QuadraticCurveToRel(dx1, dy1, dx, dy) =>
      QuadraticCurveToRel(dx1, dy1, dx, dy)
    SmoothQuadraticCurveToRel(dx, dy) => SmoothQuadraticCurveToRel(dx, dy)
    ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy) =>
      ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy)
  }
}

///|
fn path_command_to_msvg(cmd : PathCommand) -> @msvg.PathCommand {
  match cmd {
    MoveTo(x, y) => @msvg.PathCommand::MoveTo(x, y)
    LineTo(x, y) => @msvg.PathCommand::LineTo(x, y)
    HorizontalLineTo(x) => @msvg.PathCommand::HorizontalLineTo(x)
    VerticalLineTo(y) => @msvg.PathCommand::VerticalLineTo(y)
    CurveTo(x1, y1, x2, y2, x, y) =>
      @msvg.PathCommand::CurveTo(x1, y1, x2, y2, x, y)
    SmoothCurveTo(x2, y2, x, y) =>
      @msvg.PathCommand::SmoothCurveTo(x2, y2, x, y)
    QuadraticCurveTo(x1, y1, x, y) =>
      @msvg.PathCommand::QuadraticCurveTo(x1, y1, x, y)
    SmoothQuadraticCurveTo(x, y) =>
      @msvg.PathCommand::SmoothQuadraticCurveTo(x, y)
    ArcTo(rx, ry, rotation, large_arc, sweep, x, y) =>
      @msvg.PathCommand::ArcTo(rx, ry, rotation, large_arc, sweep, x, y)
    ClosePath => @msvg.PathCommand::ClosePath
    MoveToRel(dx, dy) => @msvg.PathCommand::MoveToRel(dx, dy)
    LineToRel(dx, dy) => @msvg.PathCommand::LineToRel(dx, dy)
    HorizontalLineToRel(dx) => @msvg.PathCommand::HorizontalLineToRel(dx)
    VerticalLineToRel(dy) => @msvg.PathCommand::VerticalLineToRel(dy)
    CurveToRel(dx1, dy1, dx2, dy2, dx, dy) =>
      @msvg.PathCommand::CurveToRel(dx1, dy1, dx2, dy2, dx, dy)
    SmoothCurveToRel(dx2, dy2, dx, dy) =>
      @msvg.PathCommand::SmoothCurveToRel(dx2, dy2, dx, dy)
    QuadraticCurveToRel(dx1, dy1, dx, dy) =>
      @msvg.PathCommand::QuadraticCurveToRel(dx1, dy1, dx, dy)
    SmoothQuadraticCurveToRel(dx, dy) =>
      @msvg.PathCommand::SmoothQuadraticCurveToRel(dx, dy)
    ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy) =>
      @msvg.PathCommand::ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy)
  }
}

///|
fn path_commands_to_msvg(
  commands : Array[PathCommand],
) -> Array[@msvg.PathCommand] {
  commands.map(path_command_to_msvg)
}

///|
fn bounding_box_from_msvg(bbox : @msvg.BoundingBox) -> BoundingBox {
  { min_x: bbox.min_x, min_y: bbox.min_y, max_x: bbox.max_x, max_y: bbox.max_y }
}

///|
fn bounding_box_to_msvg(bbox : BoundingBox) -> @msvg.BoundingBox {
  @msvg.BoundingBox::{
    min_x: bbox.min_x,
    min_y: bbox.min_y,
    max_x: bbox.max_x,
    max_y: bbox.max_y,
  }
}

///|
fn bounding_box_from_msvg_option(bbox : @msvg.BoundingBox?) -> BoundingBox? {
  match bbox {
    Some(b) => Some(bounding_box_from_msvg(b))
    None => None
  }
}

///|
fn clip_rect_from_msvg(clip : @msvg.ClipRect) -> ClipRect {
  { x: clip.x, y: clip.y, width: clip.width, height: clip.height }
}

///|
fn clip_rect_to_msvg(clip : ClipRect) -> @msvg.ClipRect {
  @msvg.ClipRect::{
    x: clip.x,
    y: clip.y,
    width: clip.width,
    height: clip.height,
  }
}

///|
fn camera_from_msvg(camera : @msvg.Camera) -> Camera {
  {
    x: camera.x,
    y: camera.y,
    zoom: camera.zoom,
    viewport_width: camera.viewport_width,
    viewport_height: camera.viewport_height,
  }
}

///|
fn copy_camera_from_msvg(target : Camera, source : @msvg.Camera) -> Unit {
  target.x = source.x
  target.y = source.y
  target.zoom = source.zoom
}

///|
fn camera_to_msvg(camera : Camera) -> @msvg.Camera {
  @msvg.Camera::{
    x: camera.x,
    y: camera.y,
    zoom: camera.zoom,
    viewport_width: camera.viewport_width,
    viewport_height: camera.viewport_height,
  }
}

///|
fn shape_from_msvg(shape : @msvg.Shape) -> Shape {
  match shape {
    Rect(x~, y~, width~, height~, rx~, ry~) =>
      Rect(x~, y~, width~, height~, rx~, ry~)
    Circle(cx~, cy~, r~) => Circle(cx~, cy~, r~)
    Ellipse(cx~, cy~, rx~, ry~) => Ellipse(cx~, cy~, rx~, ry~)
    Line(x1~, y1~, x2~, y2~) => Line(x1~, y1~, x2~, y2~)
    Polyline(points~) => Polyline(points~)
    Polygon(points~) => Polygon(points~)
    Path(commands~) => Path(commands=commands.map(path_command_from_msvg))
    Text(x~, y~, text~, font_size~) => Text(x~, y~, text~, font_size~)
    Image(..) => Group
    Group => Group
  }
}

///|
fn shape_to_msvg(shape : Shape) -> @msvg.Shape {
  match shape {
    Rect(x~, y~, width~, height~, rx~, ry~) =>
      @msvg.Shape::Rect(x~, y~, width~, height~, rx~, ry~)
    Circle(cx~, cy~, r~) => @msvg.Shape::Circle(cx~, cy~, r~)
    Ellipse(cx~, cy~, rx~, ry~) => @msvg.Shape::Ellipse(cx~, cy~, rx~, ry~)
    Line(x1~, y1~, x2~, y2~) => @msvg.Shape::Line(x1~, y1~, x2~, y2~)
    Polyline(points~) => @msvg.Shape::Polyline(points~)
    Polygon(points~) => @msvg.Shape::Polygon(points~)
    Path(commands~) =>
      @msvg.Shape::Path(commands=path_commands_to_msvg(commands))
    Text(x~, y~, text~, font_size~) =>
      @msvg.Shape::Text(x~, y~, text~, font_size~)
    Group => @msvg.Shape::Group
  }
}

///|
fn clip_path_from_msvg(clip : @msvg.ClipPath) -> ClipPath {
  {
    id: clip.id,
    shape: shape_from_msvg(clip.shape),
    transform: transform_from_msvg(clip.transform),
    clip_rule: fill_rule_from_msvg(clip.clip_rule),
  }
}

///|
fn clip_path_to_msvg(clip : ClipPath) -> @msvg.ClipPath {
  @msvg.ClipPath::{
    id: clip.id,
    shape: shape_to_msvg(clip.shape),
    transform: clip.transform.to_msvg(),
    clip_rule: fill_rule_to_msvg(clip.clip_rule),
    units: @msvg.ClipPathUnits::UserSpaceOnUse,
  }
}

///|
fn svg_node_to_msvg(source : SVGNode) -> @msvg.SVGNode {
  let node = @msvg.SVGNode::new(shape_to_msvg(source.shape))
  node.id = source.id
  node.transform = source.transform.to_msvg()
  node.fill = paint_to_msvg(source.fill)
  node.fill_rule = fill_rule_to_msvg(source.fill_rule)
  node.fill_opacity = source.fill_opacity
  node.stroke = stroke_style_to_msvg(source.stroke)
  node.stroke_opacity = source.stroke_opacity
  node.opacity = source.opacity
  node.z_index = source.z_index
  node.node_dirty = source.node_dirty
  node.prev_bounds = match source.prev_bounds {
    Some(bbox) => Some(bounding_box_to_msvg(bbox))
    None => None
  }
  node.filters = source.filters.map(filter_to_msvg)
  node.mask_id = source.mask_id
  node.clip_path_id = source.clip_path_id
  for child in source.children {
    node.children.push(svg_node_to_msvg(child))
  }
  node
}

///|
fn svg_node_from_msvg(source : @msvg.SVGNode) -> SVGNode {
  let current_color = color_from_msvg_option(source.color)
  let node = SVGNode::new(shape_from_msvg(source.shape))
  node.id = source.id
  node.transform = transform_from_msvg(source.transform)
  node.fill = paint_from_msvg(source.fill, current_color)
  node.fill_rule = fill_rule_from_msvg(source.fill_rule)
  node.fill_opacity = source.fill_opacity
  node.stroke = stroke_style_from_msvg(source.stroke, current_color)
  node.stroke_opacity = source.stroke_opacity
  node.opacity = source.opacity
  node.z_index = source.z_index
  node.node_dirty = source.node_dirty
  node.prev_bounds = bounding_box_from_msvg_option(source.prev_bounds)
  node.filters = source.filters.map(filter_from_msvg)
  node.mask_id = source.mask_id
  node.clip_path_id = source.clip_path_id
  for child in source.children {
    node.children.push(svg_node_from_msvg(child))
  }
  node
}

///|
fn pattern_from_msvg(
  pattern : @msvg.Pattern,
  content : Array[SVGNode],
) -> Pattern {
  {
    id: pattern.id,
    width: pattern.width,
    height: pattern.height,
    content,
    pattern_units: pattern_units_from_msvg(pattern.pattern_units),
    pattern_content_units: pattern_units_from_msvg(
      pattern.pattern_content_units,
    ),
    transform: transform_from_msvg(pattern.transform),
  }
}

///|
fn pattern_to_msvg(pattern : Pattern) -> @msvg.Pattern {
  @msvg.Pattern::{
    id: pattern.id,
    width: pattern.width,
    height: pattern.height,
    content: pattern.content.map(svg_node_to_msvg),
    pattern_units: pattern_units_to_msvg(pattern.pattern_units),
    pattern_content_units: pattern_units_to_msvg(pattern.pattern_content_units),
    transform: pattern.transform.to_msvg(),
    view_box: None,
    preserve_aspect_ratio: @msvg.PreserveAspectRatio::default(),
  }
}

///|
fn marker_orient_from_msvg(orient : @msvg.MarkerOrient) -> MarkerOrient {
  match orient {
    Auto => Auto
    AutoStartReverse => AutoStartReverse
    Angle(angle) => Angle(angle)
  }
}

///|
fn marker_orient_to_msvg(orient : MarkerOrient) -> @msvg.MarkerOrient {
  match orient {
    Auto => @msvg.MarkerOrient::Auto
    AutoStartReverse => @msvg.MarkerOrient::AutoStartReverse
    Angle(angle) => @msvg.MarkerOrient::Angle(angle)
  }
}

///|
fn marker_units_from_msvg(units : @msvg.MarkerUnits) -> MarkerUnits {
  match units {
    StrokeWidth => StrokeWidth
    UserSpaceOnUse_ => UserSpaceOnUse_
  }
}

///|
fn marker_units_to_msvg(units : MarkerUnits) -> @msvg.MarkerUnits {
  match units {
    StrokeWidth => @msvg.MarkerUnits::StrokeWidth
    UserSpaceOnUse_ => @msvg.MarkerUnits::UserSpaceOnUse_
  }
}

///|
fn marker_from_msvg(marker : @msvg.Marker) -> Marker {
  {
    id: marker.id,
    content: svg_node_from_msvg(marker.content),
    ref_x: marker.ref_x,
    ref_y: marker.ref_y,
    marker_width: marker.marker_width,
    marker_height: marker.marker_height,
    orient: marker_orient_from_msvg(marker.orient),
    marker_units: marker_units_from_msvg(marker.marker_units),
    view_box: view_box_from_msvg_option(marker.view_box),
  }
}

///|
fn marker_to_msvg(marker : Marker) -> @msvg.Marker {
  @msvg.Marker::{
    id: marker.id,
    content: svg_node_to_msvg(marker.content),
    ref_x: marker.ref_x,
    ref_y: marker.ref_y,
    marker_width: marker.marker_width,
    marker_height: marker.marker_height,
    orient: marker_orient_to_msvg(marker.orient),
    marker_units: marker_units_to_msvg(marker.marker_units),
    view_box: view_box_to_msvg_option(marker.view_box),
    preserve_aspect_ratio: @msvg.PreserveAspectRatio::default(),
    clip_overflow: true,
  }
}

///|
fn marked_line_from_msvg(line : @msvg.MarkedLine) -> MarkedLine {
  {
    points: line.points,
    marker_start: line.marker_start,
    marker_mid: line.marker_mid,
    marker_end: line.marker_end,
  }
}

///|
fn marked_line_to_msvg(line : MarkedLine) -> @msvg.MarkedLine {
  @msvg.MarkedLine::{
    points: line.points,
    marker_start: line.marker_start,
    marker_mid: line.marker_mid,
    marker_end: line.marker_end,
  }
}
