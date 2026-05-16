///|
/// Gradient stop (position 0.0-1.0 and color)
pub(all) struct GradientStop {
  offset : Double // 0.0 to 1.0
  color : Color
}

///|
/// Linear gradient definition
pub(all) struct LinearGradient {
  x1 : Double // Start point x (0.0-1.0 or absolute)
  y1 : Double // Start point y
  x2 : Double // End point x
  y2 : Double // End point y
  stops : Array[GradientStop]
  spread_method : SpreadMethod
}

///|
pub fn LinearGradient::new(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  stops : Array[GradientStop],
) -> LinearGradient {
  LinearGradient::from_msvg(
    @msvg.LinearGradient::new(x1, y1, x2, y2, stops.map(fn(s) { s.to_msvg() })),
  )
}

///|
/// Simple horizontal gradient (left to right)
pub fn LinearGradient::horizontal(
  start_color : Color,
  end_color : Color,
) -> LinearGradient {
  LinearGradient::from_msvg(
    @msvg.LinearGradient::horizontal(
      start_color.to_msvg(),
      end_color.to_msvg(),
    ),
  )
}

///|
/// Simple vertical gradient (top to bottom)
pub fn LinearGradient::vertical(
  start_color : Color,
  end_color : Color,
) -> LinearGradient {
  LinearGradient::from_msvg(
    @msvg.LinearGradient::vertical(
      start_color.to_msvg(),
      end_color.to_msvg(),
    ),
  )
}

///|
/// Interpolate color at position t (0.0-1.0)
pub fn LinearGradient::color_at(self : LinearGradient, t : Double) -> Color {
  Color::from_msvg(self.to_msvg().color_at(t))
}

///|
/// How gradient extends beyond its bounds
pub(all) enum SpreadMethod {
  Pad // Extend with end colors (default)
  Repeat // Repeat pattern
  Reflect // Mirror pattern
} derive(Eq, Debug)

///|
pub impl Show for SpreadMethod with output(self, logger) {
  let name = match self {
    Pad => "Pad"
    Repeat => "Repeat"
    Reflect => "Reflect"
  }
  logger.write_string(name)
}

///|
/// Radial gradient definition
pub(all) struct RadialGradient {
  cx : Double // Center x (0.0-1.0 relative)
  cy : Double // Center y
  fx : Double // Focal point x
  fy : Double // Focal point y
  r : Double // Radius
  stops : Array[GradientStop]
  spread_method : SpreadMethod
}

///|
pub fn RadialGradient::new(
  cx : Double,
  cy : Double,
  r : Double,
  stops : Array[GradientStop],
) -> RadialGradient {
  RadialGradient::from_msvg(
    @msvg.RadialGradient::new(cx, cy, r, stops.map(fn(s) { s.to_msvg() })),
  )
}

///|
/// Get color at a point (px, py) relative to the gradient bounds
pub fn RadialGradient::color_at(
  self : RadialGradient,
  px : Double,
  py : Double,
  width : Double,
  height : Double,
) -> Color {
  Color::from_msvg(self.to_msvg().color_at(px, py, width, height))
}

///|
fn SpreadMethod::from_msvg(spread : @msvg.SpreadMethod) -> SpreadMethod {
  match spread {
    Pad => Pad
    Repeat => Repeat
    Reflect => Reflect
  }
}

///|
fn SpreadMethod::to_msvg(self : SpreadMethod) -> @msvg.SpreadMethod {
  match self {
    Pad => @msvg.SpreadMethod::Pad
    Repeat => @msvg.SpreadMethod::Repeat
    Reflect => @msvg.SpreadMethod::Reflect
  }
}

///|
fn GradientStop::from_msvg(stop : @msvg.GradientStop) -> GradientStop {
  { offset: stop.offset, color: Color::from_msvg(stop.color) }
}

///|
fn GradientStop::to_msvg(self : GradientStop) -> @msvg.GradientStop {
  @msvg.GradientStop::{ offset: self.offset, color: self.color.to_msvg() }
}

///|
fn LinearGradient::from_msvg(grad : @msvg.LinearGradient) -> LinearGradient {
  {
    x1: grad.x1,
    y1: grad.y1,
    x2: grad.x2,
    y2: grad.y2,
    stops: grad.stops.map(GradientStop::from_msvg),
    spread_method: SpreadMethod::from_msvg(grad.spread_method),
  }
}

///|
fn LinearGradient::to_msvg(self : LinearGradient) -> @msvg.LinearGradient {
  @msvg.LinearGradient::{
    x1: self.x1,
    y1: self.y1,
    x2: self.x2,
    y2: self.y2,
    stops: self.stops.map(fn(s) { s.to_msvg() }),
    spread_method: self.spread_method.to_msvg(),
    units: @msvg.GradientUnits::ObjectBoundingBox,
    transform: @msvg.Transform::identity(),
  }
}

///|
fn RadialGradient::from_msvg(grad : @msvg.RadialGradient) -> RadialGradient {
  {
    cx: grad.cx,
    cy: grad.cy,
    fx: grad.fx,
    fy: grad.fy,
    r: grad.r,
    stops: grad.stops.map(GradientStop::from_msvg),
    spread_method: SpreadMethod::from_msvg(grad.spread_method),
  }
}

///|
fn RadialGradient::to_msvg(self : RadialGradient) -> @msvg.RadialGradient {
  @msvg.RadialGradient::{
    cx: self.cx,
    cy: self.cy,
    fx: self.fx,
    fy: self.fy,
    r: self.r,
    stops: self.stops.map(fn(s) { s.to_msvg() }),
    spread_method: self.spread_method.to_msvg(),
    units: @msvg.GradientUnits::ObjectBoundingBox,
    transform: @msvg.Transform::identity(),
  }
}
