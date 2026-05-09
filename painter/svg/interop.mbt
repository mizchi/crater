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
