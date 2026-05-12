///|
/// TUI hit-test shape resolution.

///|
fn resolve_visual_polygon(
  points : Array[(Double, Double)],
  abs_x : Double,
  abs_y : Double,
) -> Array[(Double, Double)] {
  let resolved : Array[(Double, Double)] = []
  for point in points {
    let (x, y) = point
    resolved.push((abs_x + x, abs_y + y))
  }
  resolved
}

///|
fn resolve_hit_radius(
  value : Double,
  width : Double,
  height : Double,
) -> Double {
  let reference = min_double(width, height)
  let raw = if value < 0.0 { -value * reference } else { value }
  let max_radius = reference / 2.0
  if raw <= 0.0 {
    0.0
  } else if raw > max_radius {
    max_radius
  } else {
    raw
  }
}

///|
fn resolve_hit_clip_shape(
  node : @tui_paint_runtime.PaintNode,
  abs_x : Double,
  abs_y : Double,
) -> HitClipShape {
  match node.paint.clip_path {
    @style.ClipPath::Circle(radius, center_x, center_y) => {
      let (cx, cy, r) = resolve_clip_path_circle(
        radius,
        center_x,
        center_y,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
      HitClipShape::Circle(cx, cy, r)
    }
    @style.ClipPath::Ellipse(radius_x, radius_y, center_x, center_y) => {
      let (cx, cy, rx, ry) = resolve_clip_path_ellipse(
        radius_x,
        radius_y,
        center_x,
        center_y,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
      HitClipShape::Ellipse(cx, cy, rx, ry)
    }
    @style.ClipPath::Polygon(points) =>
      HitClipShape::Polygon(
        resolve_clip_path_polygon(points, abs_x, abs_y, node.width, node.height),
      )
    _ => HitClipShape::Rect
  }
}
