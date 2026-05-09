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
