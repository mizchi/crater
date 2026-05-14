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
fn pixel_setter_from_msvg(setter : @msvg.PixelSetter) -> PixelSetter {
  { set: fn(x, y, color) { setter.pixel(x, y, color_to_msvg(color)) } }
}

///|
fn render_context_to_msvg(ctx : RenderContext) -> @msvg.RenderContext {
  let clip = match ctx.clip {
    Some(clip) => Some(clip_rect_to_msvg(clip))
    None => None
  }
  @msvg.RenderContext::{
    setter: pixel_setter_to_msvg(ctx.setter),
    width: ctx.width,
    height: ctx.height,
    flatness: ctx.flatness,
    clip,
    text_to_paths: None,
  }
}

///|
fn render_context_from_msvg(ctx : @msvg.RenderContext) -> RenderContext {
  let clip = match ctx.clip {
    Some(clip) => Some(clip_rect_from_msvg(clip))
    None => None
  }
  {
    setter: pixel_setter_from_msvg(ctx.setter),
    width: ctx.width,
    height: ctx.height,
    flatness: ctx.flatness,
    clip,
  }
}

///|
fn scene_to_msvg(scene : Scene) -> @msvg.Scene {
  @msvg.Scene::{ root: svg_node_to_msvg(scene.root), dirty: scene.dirty }
}

///|
fn svg_scene_from_msvg(scene : @msvg.Scene) -> Scene {
  { root: svg_node_from_msvg(scene.root), dirty: scene.dirty }
}

///|
fn copy_svg_scene_dirty_state_from_msvg(
  target : Scene,
  source : @msvg.Scene,
) -> Unit {
  target.dirty = source.dirty
  copy_svg_node_dirty_state_from_msvg(target.root, source.root)
}

///|
fn copy_svg_node_dirty_state_from_msvg(
  target : SVGNode,
  source : @msvg.SVGNode,
) -> Unit {
  target.node_dirty = source.node_dirty
  target.prev_bounds = bounding_box_from_msvg_option(source.prev_bounds)
  let len = if target.children.length() < source.children.length() {
    target.children.length()
  } else {
    source.children.length()
  }
  for i = 0; i < len; i = i + 1 {
    copy_svg_node_dirty_state_from_msvg(target.children[i], source.children[i])
  }
}

///|
fn copy_svg_scene_z_order_state_from_msvg(
  target : Scene,
  source : @msvg.Scene,
) -> Unit {
  target.dirty = source.dirty
  copy_svg_node_z_order_state_from_msvg(target.root, source.root)
}

///|
fn copy_svg_node_z_order_state_from_msvg(
  target : SVGNode,
  source : @msvg.SVGNode,
) -> Unit {
  target.z_index = source.z_index
  let len = if target.children.length() < source.children.length() {
    target.children.length()
  } else {
    source.children.length()
  }
  for i = 0; i < len; i = i + 1 {
    copy_svg_node_z_order_state_from_msvg(
      target.children[i],
      source.children[i],
    )
  }
}

///|
fn copy_svg_node_effect_state_from_msvg(
  target : SVGNode,
  source : @msvg.SVGNode,
) -> Unit {
  target.filters = source.filters.map(filter_from_msvg)
  target.mask_id = source.mask_id
  target.clip_path_id = source.clip_path_id
  target.node_dirty = source.node_dirty
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
