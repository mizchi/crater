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
