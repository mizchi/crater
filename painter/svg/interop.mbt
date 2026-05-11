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
  Transform::matrix(
    transform.a,
    transform.b,
    transform.c,
    transform.d,
    transform.e,
    transform.f,
  )
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
