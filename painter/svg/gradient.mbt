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
  linear_gradient_from_msvg(
    @msvg.LinearGradient::new(x1, y1, x2, y2, stops.map(gradient_stop_to_msvg)),
  )
}

///|
/// Simple horizontal gradient (left to right)
pub fn LinearGradient::horizontal(
  start_color : Color,
  end_color : Color,
) -> LinearGradient {
  linear_gradient_from_msvg(
    @msvg.LinearGradient::horizontal(
      color_to_msvg(start_color),
      color_to_msvg(end_color),
    ),
  )
}

///|
/// Simple vertical gradient (top to bottom)
pub fn LinearGradient::vertical(
  start_color : Color,
  end_color : Color,
) -> LinearGradient {
  linear_gradient_from_msvg(
    @msvg.LinearGradient::vertical(
      color_to_msvg(start_color),
      color_to_msvg(end_color),
    ),
  )
}

///|
/// Interpolate color at position t (0.0-1.0)
pub fn LinearGradient::color_at(self : LinearGradient, t : Double) -> Color {
  color_from_msvg(linear_gradient_to_msvg(self).color_at(t))
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
  radial_gradient_from_msvg(
    @msvg.RadialGradient::new(cx, cy, r, stops.map(gradient_stop_to_msvg)),
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
  color_from_msvg(radial_gradient_to_msvg(self).color_at(px, py, width, height))
}
