///|
/// SVG path commands (full SVG 1.1 spec)
pub(all) enum PathCommand {
  // Absolute commands
  MoveTo(Double, Double) // M x y
  LineTo(Double, Double) // L x y
  HorizontalLineTo(Double) // H x
  VerticalLineTo(Double) // V y
  CurveTo(Double, Double, Double, Double, Double, Double) // C x1 y1 x2 y2 x y
  SmoothCurveTo(Double, Double, Double, Double) // S x2 y2 x y
  QuadraticCurveTo(Double, Double, Double, Double) // Q x1 y1 x y
  SmoothQuadraticCurveTo(Double, Double) // T x y
  ArcTo(Double, Double, Double, Bool, Bool, Double, Double) // A rx ry rotation large-arc sweep x y
  ClosePath // Z
  // Relative commands
  MoveToRel(Double, Double) // m dx dy
  LineToRel(Double, Double) // l dx dy
  HorizontalLineToRel(Double) // h dx
  VerticalLineToRel(Double) // v dy
  CurveToRel(Double, Double, Double, Double, Double, Double) // c dx1 dy1 dx2 dy2 dx dy
  SmoothCurveToRel(Double, Double, Double, Double) // s dx2 dy2 dx dy
  QuadraticCurveToRel(Double, Double, Double, Double) // q dx1 dy1 dx dy
  SmoothQuadraticCurveToRel(Double, Double) // t dx dy
  ArcToRel(Double, Double, Double, Bool, Bool, Double, Double) // a rx ry rotation large-arc sweep dx dy
} derive(Debug)

///|
/// SVG shape primitives
pub(all) enum Shape {
  Rect(
    x~ : Double,
    y~ : Double,
    width~ : Double,
    height~ : Double,
    rx~ : Double,
    ry~ : Double
  )
  Circle(cx~ : Double, cy~ : Double, r~ : Double)
  Ellipse(cx~ : Double, cy~ : Double, rx~ : Double, ry~ : Double)
  Line(x1~ : Double, y1~ : Double, x2~ : Double, y2~ : Double)
  Polyline(points~ : Array[(Double, Double)])
  Polygon(points~ : Array[(Double, Double)])
  Path(commands~ : Array[PathCommand])
  Text(x~ : Double, y~ : Double, text~ : String, font_size~ : Double)
  Group // Container for children
} derive(Debug)

///|
pub impl Show for PathCommand with output(self, logger) {
  match self {
    MoveTo(x, y) => logger.write_string("MoveTo(\{x}, \{y})")
    LineTo(x, y) => logger.write_string("LineTo(\{x}, \{y})")
    HorizontalLineTo(x) => logger.write_string("HorizontalLineTo(\{x})")
    VerticalLineTo(y) => logger.write_string("VerticalLineTo(\{y})")
    CurveTo(x1, y1, x2, y2, x, y) =>
      logger.write_string("CurveTo(\{x1}, \{y1}, \{x2}, \{y2}, \{x}, \{y})")
    SmoothCurveTo(x2, y2, x, y) =>
      logger.write_string("SmoothCurveTo(\{x2}, \{y2}, \{x}, \{y})")
    QuadraticCurveTo(x1, y1, x, y) =>
      logger.write_string("QuadraticCurveTo(\{x1}, \{y1}, \{x}, \{y})")
    SmoothQuadraticCurveTo(x, y) =>
      logger.write_string("SmoothQuadraticCurveTo(\{x}, \{y})")
    ArcTo(rx, ry, rotation, large_arc, sweep, x, y) =>
      logger.write_string(
        "ArcTo(\{rx}, \{ry}, \{rotation}, \{large_arc}, \{sweep}, \{x}, \{y})",
      )
    ClosePath => logger.write_string("ClosePath")
    MoveToRel(dx, dy) => logger.write_string("MoveToRel(\{dx}, \{dy})")
    LineToRel(dx, dy) => logger.write_string("LineToRel(\{dx}, \{dy})")
    HorizontalLineToRel(dx) => logger.write_string("HorizontalLineToRel(\{dx})")
    VerticalLineToRel(dy) => logger.write_string("VerticalLineToRel(\{dy})")
    CurveToRel(dx1, dy1, dx2, dy2, dx, dy) =>
      logger.write_string(
        "CurveToRel(\{dx1}, \{dy1}, \{dx2}, \{dy2}, \{dx}, \{dy})",
      )
    SmoothCurveToRel(dx2, dy2, dx, dy) =>
      logger.write_string("SmoothCurveToRel(\{dx2}, \{dy2}, \{dx}, \{dy})")
    QuadraticCurveToRel(dx1, dy1, dx, dy) =>
      logger.write_string("QuadraticCurveToRel(\{dx1}, \{dy1}, \{dx}, \{dy})")
    SmoothQuadraticCurveToRel(dx, dy) =>
      logger.write_string("SmoothQuadraticCurveToRel(\{dx}, \{dy})")
    ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy) =>
      logger.write_string(
        "ArcToRel(\{rx}, \{ry}, \{rotation}, \{large_arc}, \{sweep}, \{dx}, \{dy})",
      )
  }
}

///|
pub impl Show for Shape with output(self, logger) {
  match self {
    Rect(x~, y~, width~, height~, rx~, ry~) =>
      logger.write_string(
        "Rect(x=\{x}, y=\{y}, width=\{width}, height=\{height}, rx=\{rx}, ry=\{ry})",
      )
    Circle(cx~, cy~, r~) =>
      logger.write_string("Circle(cx=\{cx}, cy=\{cy}, r=\{r})")
    Ellipse(cx~, cy~, rx~, ry~) =>
      logger.write_string("Ellipse(cx=\{cx}, cy=\{cy}, rx=\{rx}, ry=\{ry})")
    Line(x1~, y1~, x2~, y2~) =>
      logger.write_string("Line(x1=\{x1}, y1=\{y1}, x2=\{x2}, y2=\{y2})")
    Polyline(points~) => {
      logger.write_string("Polyline(points=")
      logger.write_object(to_repr(points))
      logger.write_string(")")
    }
    Polygon(points~) => {
      logger.write_string("Polygon(points=")
      logger.write_object(to_repr(points))
      logger.write_string(")")
    }
    Path(commands~) => {
      logger.write_string("Path(commands=")
      logger.write_object(to_repr(commands))
      logger.write_string(")")
    }
    Text(x~, y~, text~, font_size~) => {
      logger.write_string("Text(x=\{x}, y=\{y}, text=")
      logger.write_string("\"")
      logger.write_string(text)
      logger.write_string("\"")
      logger.write_string(", font_size=\{font_size})")
    }
    Group => logger.write_string("Group")
  }
}
