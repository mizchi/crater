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
fn color_from_msvg_option(color : @msvg.Color?) -> Color? {
  match color {
    Some(c) => Some(color_from_msvg(c))
    None => None
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
fn linecap_from_msvg(linecap : @msvg.LineCap) -> LineCap {
  match linecap {
    Butt => Butt
    Round => Round
    Square => Square
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
fn spread_method_from_msvg(spread : @msvg.SpreadMethod) -> SpreadMethod {
  match spread {
    Pad => Pad
    Repeat => Repeat
    Reflect => Reflect
  }
}

///|
fn gradient_stop_from_msvg(stop : @msvg.GradientStop) -> GradientStop {
  { offset: stop.offset, color: color_from_msvg(stop.color) }
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
fn bounding_box_from_msvg_option(bbox : @msvg.BoundingBox?) -> BoundingBox? {
  match bbox {
    Some(b) => Some(bounding_box_from_msvg(b))
    None => None
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
