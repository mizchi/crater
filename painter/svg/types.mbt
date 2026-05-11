///|
/// SVG Layout Engine - Standalone Types
/// Independent of HTML/CSS layout system

///|
/// RGB Color (0-255 range)
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
  a : Int // Alpha (0-255, 255 = opaque)
}

///|
pub fn Color::rgb(r : Int, g : Int, b : Int) -> Color {
  color_from_msvg(@msvg.Color::rgb(r, g, b))
}

///|
pub fn Color::rgba(r : Int, g : Int, b : Int, a : Int) -> Color {
  color_from_msvg(@msvg.Color::rgba(r, g, b, a))
}

///|
pub fn Color::transparent() -> Color {
  color_from_msvg(@msvg.Color::transparent())
}

///|
pub fn Color::black() -> Color {
  color_from_msvg(@msvg.Color::black())
}

///|
pub fn Color::white() -> Color {
  color_from_msvg(@msvg.Color::white())
}

///|
pub fn Color::is_transparent(self : Color) -> Bool {
  color_to_msvg(self).is_transparent()
}

///|
/// ViewBox specification for SVG coordinate system mapping
pub(all) struct ViewBox {
  min_x : Double
  min_y : Double
  width : Double
  height : Double
}

///|
/// preserveAspectRatio alignment values
pub(all) enum Align {
  None // No forced uniform scaling
  XMinYMin
  XMidYMin
  XMaxYMin
  XMinYMid
  XMidYMid // Default
  XMaxYMid
  XMinYMax
  XMidYMax
  XMaxYMax
} derive(Eq, Debug)

///|
/// preserveAspectRatio meet/slice
pub(all) enum MeetOrSlice {
  Meet // Scale to fit entirely (default)
  Slice // Scale to cover entirely
} derive(Eq, Debug)

///|
/// Complete preserveAspectRatio setting
pub(all) struct PreserveAspectRatio {
  align : Align
  meet_or_slice : MeetOrSlice
}

///|
pub fn PreserveAspectRatio::default() -> PreserveAspectRatio {
  { align: XMidYMid, meet_or_slice: Meet }
}

///|
pub impl Show for Align with output(self, logger) {
  let name = match self {
    None => "None"
    XMinYMin => "XMinYMin"
    XMidYMin => "XMidYMin"
    XMaxYMin => "XMaxYMin"
    XMinYMid => "XMinYMid"
    XMidYMid => "XMidYMid"
    XMaxYMid => "XMaxYMid"
    XMinYMax => "XMinYMax"
    XMidYMax => "XMidYMax"
    XMaxYMax => "XMaxYMax"
  }
  logger.write_string(name)
}

///|
pub impl Show for MeetOrSlice with output(self, logger) {
  let name = match self {
    Meet => "Meet"
    Slice => "Slice"
  }
  logger.write_string(name)
}

///|
/// Calculate the transform matrix to map viewBox coordinates to viewport
/// viewport_width/height: the actual pixel dimensions of the SVG element
pub fn ViewBox::get_transform(
  self : ViewBox,
  viewport_width : Double,
  viewport_height : Double,
  preserve_aspect_ratio : PreserveAspectRatio,
) -> Transform {
  let transform = @msvg.ViewBox::{
    min_x: self.min_x,
    min_y: self.min_y,
    width: self.width,
    height: self.height,
  }.get_transform(
    viewport_width,
    viewport_height,
    preserve_aspect_ratio.to_msvg(),
  )
  Transform::{
    a: transform.a,
    b: transform.b,
    c: transform.c,
    d: transform.d,
    e: transform.e,
    f: transform.f,
  }
}

///|
fn Align::to_msvg(self : Align) -> @msvg.Align {
  match self {
    None => @msvg.Align::None
    XMinYMin => @msvg.Align::XMinYMin
    XMidYMin => @msvg.Align::XMidYMin
    XMaxYMin => @msvg.Align::XMaxYMin
    XMinYMid => @msvg.Align::XMinYMid
    XMidYMid => @msvg.Align::XMidYMid
    XMaxYMid => @msvg.Align::XMaxYMid
    XMinYMax => @msvg.Align::XMinYMax
    XMidYMax => @msvg.Align::XMidYMax
    XMaxYMax => @msvg.Align::XMaxYMax
  }
}

///|
fn MeetOrSlice::to_msvg(self : MeetOrSlice) -> @msvg.MeetOrSlice {
  match self {
    Meet => @msvg.MeetOrSlice::Meet
    Slice => @msvg.MeetOrSlice::Slice
  }
}

///|
fn PreserveAspectRatio::to_msvg(
  self : PreserveAspectRatio,
) -> @msvg.PreserveAspectRatio {
  @msvg.PreserveAspectRatio::{
    align: self.align.to_msvg(),
    meet_or_slice: self.meet_or_slice.to_msvg(),
  }
}

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
    Polyline(points~) => logger.write_string("Polyline(points=\{points})")
    Polygon(points~) => logger.write_string("Polygon(points=\{points})")
    Path(commands~) => logger.write_string("Path(commands=\{commands})")
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

///|
/// Paint style (fill or stroke)
pub(all) enum Paint {
  None
  SolidColor(Color)
  LinearGrad(LinearGradient)
  RadialGrad(RadialGradient)
}

///|
/// Stroke properties
pub(all) struct StrokeStyle {
  paint : Paint
  width : Double
  linecap : LineCap
  linejoin : LineJoin
  miterlimit : Double
  dasharray : Array[Double]?
  dashoffset : Double
}

///|
pub fn StrokeStyle::default() -> StrokeStyle {
  stroke_style_from_msvg(@msvg.StrokeStyle::default(), None)
}

///|
pub(all) enum LineCap {
  Butt
  Round
  Square
} derive(Eq, Debug)

///|
pub(all) enum LineJoin {
  Miter
  Round
  Bevel
} derive(Eq, Debug)

///|
/// Fill rule for paths and polygons
pub(all) enum FillRule {
  NonZero // Default
  EvenOdd
} derive(Eq, Debug)

///|
pub impl Show for LineCap with output(self, logger) {
  let name = match self {
    Butt => "Butt"
    Round => "Round"
    Square => "Square"
  }
  logger.write_string(name)
}

///|
pub impl Show for LineJoin with output(self, logger) {
  let name = match self {
    Miter => "Miter"
    Round => "Round"
    Bevel => "Bevel"
  }
  logger.write_string(name)
}

///|
pub impl Show for FillRule with output(self, logger) {
  let name = match self {
    NonZero => "NonZero"
    EvenOdd => "EvenOdd"
  }
  logger.write_string(name)
}
