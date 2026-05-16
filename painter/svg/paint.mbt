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
  StrokeStyle::from_msvg(@msvg.StrokeStyle::default(), None)
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

///|
fn current_color_or_black(current_color : Color?) -> Color {
  match current_color {
    Some(color) => color
    None => Color::black()
  }
}

///|
fn FillRule::from_msvg(rule : @msvg.FillRule) -> FillRule {
  match rule {
    NonZero => NonZero
    EvenOdd => EvenOdd
  }
}

///|
fn FillRule::to_msvg(self : FillRule) -> @msvg.FillRule {
  match self {
    NonZero => @msvg.FillRule::NonZero
    EvenOdd => @msvg.FillRule::EvenOdd
  }
}

///|
fn LineCap::from_msvg(linecap : @msvg.LineCap) -> LineCap {
  match linecap {
    Butt => Butt
    Round => Round
    Square => Square
  }
}

///|
fn LineCap::to_msvg(self : LineCap) -> @msvg.LineCap {
  match self {
    Butt => @msvg.LineCap::Butt
    Round => @msvg.LineCap::Round
    Square => @msvg.LineCap::Square
  }
}

///|
fn LineJoin::from_msvg(linejoin : @msvg.LineJoin) -> LineJoin {
  match linejoin {
    Miter => Miter
    Round => Round
    Bevel => Bevel
  }
}

///|
fn LineJoin::to_msvg(self : LineJoin) -> @msvg.LineJoin {
  match self {
    Miter => @msvg.LineJoin::Miter
    Round => @msvg.LineJoin::Round
    Bevel => @msvg.LineJoin::Bevel
  }
}

///|
fn paint_fallback_from_msvg(
  fallback : @msvg.PaintFallback,
  current_color : Color?,
) -> Paint {
  match fallback {
    NoPaint => SolidColor(Color::black())
    SolidColor(color) => SolidColor(Color::from_msvg(color))
    CurrentColor => SolidColor(current_color_or_black(current_color))
  }
}

///|
fn Paint::from_msvg(paint : @msvg.Paint, current_color : Color?) -> Paint {
  match paint {
    None => None
    SolidColor(color) => SolidColor(Color::from_msvg(color))
    LinearGrad(grad) => LinearGrad(LinearGradient::from_msvg(grad))
    RadialGrad(grad) => RadialGrad(RadialGradient::from_msvg(grad))
    CurrentColor => SolidColor(current_color_or_black(current_color))
    PaintServerRef(_, fallback) =>
      paint_fallback_from_msvg(fallback, current_color)
  }
}

///|
fn Paint::to_msvg(self : Paint) -> @msvg.Paint {
  match self {
    None => @msvg.Paint::None
    SolidColor(color) => @msvg.Paint::SolidColor(color.to_msvg())
    LinearGrad(grad) => @msvg.Paint::LinearGrad(grad.to_msvg())
    RadialGrad(grad) => @msvg.Paint::RadialGrad(grad.to_msvg())
  }
}

///|
fn StrokeStyle::from_msvg(
  stroke : @msvg.StrokeStyle,
  current_color : Color?,
) -> StrokeStyle {
  {
    paint: Paint::from_msvg(stroke.paint, current_color),
    width: stroke.width,
    linecap: LineCap::from_msvg(stroke.linecap),
    linejoin: LineJoin::from_msvg(stroke.linejoin),
    miterlimit: stroke.miterlimit,
    dasharray: stroke.dasharray,
    dashoffset: stroke.dashoffset,
  }
}

///|
fn StrokeStyle::to_msvg(self : StrokeStyle) -> @msvg.StrokeStyle {
  @msvg.StrokeStyle::{
    paint: self.paint.to_msvg(),
    width: self.width,
    linecap: self.linecap.to_msvg(),
    linejoin: self.linejoin.to_msvg(),
    miterlimit: self.miterlimit,
    dasharray: self.dasharray,
    dashoffset: self.dashoffset,
  }
}
