///|
/// Glyph path geometry helpers.

///|
/// Translate path commands by (dx, dy) offset.
fn translate_path_commands(
  commands : Array[@svg.PathCommand],
  dx : Double,
  dy : Double,
) -> Array[@svg.PathCommand] {
  commands.map(fn(cmd) {
    match cmd {
      MoveTo(x, y) => @svg.PathCommand::MoveTo(x + dx, y + dy)
      LineTo(x, y) => @svg.PathCommand::LineTo(x + dx, y + dy)
      HorizontalLineTo(x) => @svg.PathCommand::HorizontalLineTo(x + dx)
      VerticalLineTo(y) => @svg.PathCommand::VerticalLineTo(y + dy)
      CurveTo(x1, y1, x2, y2, x, y) =>
        @svg.PathCommand::CurveTo(
          x1 + dx,
          y1 + dy,
          x2 + dx,
          y2 + dy,
          x + dx,
          y + dy,
        )
      SmoothCurveTo(x2, y2, x, y) =>
        @svg.PathCommand::SmoothCurveTo(x2 + dx, y2 + dy, x + dx, y + dy)
      QuadraticCurveTo(x1, y1, x, y) =>
        @svg.PathCommand::QuadraticCurveTo(x1 + dx, y1 + dy, x + dx, y + dy)
      SmoothQuadraticCurveTo(x, y) =>
        @svg.PathCommand::SmoothQuadraticCurveTo(x + dx, y + dy)
      ArcTo(rx, ry, rot, large, sweep, x, y) =>
        @svg.PathCommand::ArcTo(rx, ry, rot, large, sweep, x + dx, y + dy)
      ClosePath => @svg.PathCommand::ClosePath
      _ => cmd
    }
  })
}
