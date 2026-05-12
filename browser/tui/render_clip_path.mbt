///|
/// CSS clip-path coordinate resolution helpers for TUI rendering.

///|
fn polygon_bounding_rect(
  points : Array[(Double, Double)],
) -> (Double, Double, Double, Double)? {
  if points.length() < 3 {
    return None
  }
  let (first_x, first_y) = points[0]
  let mut min_x = first_x
  let mut max_x = first_x
  let mut min_y = first_y
  let mut max_y = first_y
  for i in 1..<points.length() {
    let (x, y) = points[i]
    min_x = min_double(min_x, x)
    max_x = max_double(max_x, x)
    min_y = min_double(min_y, y)
    max_y = max_double(max_y, y)
  }
  if max_x <= min_x || max_y <= min_y {
    None
  } else {
    Some((min_x, min_y, max_x - min_x, max_y - min_y))
  }
}

///|
fn resolve_clip_path_position(value : Double, size : Double) -> Double {
  if value < 0.0 {
    -value * size
  } else {
    value
  }
}

///|
fn resolve_clip_path_axis_radius(value : Double, size : Double) -> Double {
  let raw = if value < 0.0 { -value * size } else { value }
  if raw <= 0.0 {
    0.0
  } else {
    raw
  }
}

///|
fn resolve_clip_path_radius(
  value : Double,
  width : Double,
  height : Double,
) -> Double {
  let reference = min_double(width, height)
  let raw = if value < 0.0 { -value * reference } else { value }
  if raw <= 0.0 {
    0.0
  } else {
    raw
  }
}

///|
fn resolve_clip_path_polygon(
  points : Array[(Double, Double)],
  abs_x : Double,
  abs_y : Double,
  width : Double,
  height : Double,
) -> Array[(Double, Double)] {
  let resolved : Array[(Double, Double)] = []
  for point in points {
    let (x, y) = point
    resolved.push(
      (
        abs_x + resolve_clip_path_position(x, width),
        abs_y + resolve_clip_path_position(y, height),
      ),
    )
  }
  resolved
}

///|
fn resolve_clip_path_ellipse(
  radius_x : Double,
  radius_y : Double,
  center_x : Double,
  center_y : Double,
  abs_x : Double,
  abs_y : Double,
  width : Double,
  height : Double,
) -> (Double, Double, Double, Double) {
  (
    abs_x + resolve_clip_path_position(center_x, width),
    abs_y + resolve_clip_path_position(center_y, height),
    resolve_clip_path_axis_radius(radius_x, width),
    resolve_clip_path_axis_radius(radius_y, height),
  )
}

///|
fn resolve_clip_path_circle(
  radius : Double,
  center_x : Double,
  center_y : Double,
  abs_x : Double,
  abs_y : Double,
  width : Double,
  height : Double,
) -> (Double, Double, Double) {
  (
    abs_x + resolve_clip_path_position(center_x, width),
    abs_y + resolve_clip_path_position(center_y, height),
    resolve_clip_path_radius(radius, width, height),
  )
}

///|
fn resolve_clip_path_rect(
  top : Double,
  right : Double,
  bottom : Double,
  left : Double,
  abs_x : Double,
  abs_y : Double,
  width : Double,
  height : Double,
) -> (Double, Double, Double, Double)? {
  let clip_top = abs_y + resolve_clip_path_position(top, height)
  let clip_right = abs_x + resolve_clip_path_position(right, width)
  let clip_bottom = abs_y + resolve_clip_path_position(bottom, height)
  let clip_left = abs_x + resolve_clip_path_position(left, width)
  if clip_right <= clip_left || clip_bottom <= clip_top {
    None
  } else {
    Some((clip_left, clip_top, clip_right - clip_left, clip_bottom - clip_top))
  }
}

///|
fn resolve_clip_path_xywh(
  x : Double,
  y : Double,
  clip_width : Double,
  clip_height : Double,
  abs_x : Double,
  abs_y : Double,
  width : Double,
  height : Double,
) -> (Double, Double, Double, Double)? {
  let clip_left = abs_x + resolve_clip_path_position(x, width)
  let clip_top = abs_y + resolve_clip_path_position(y, height)
  let resolved_width = resolve_clip_path_axis_radius(clip_width, width)
  let resolved_height = resolve_clip_path_axis_radius(clip_height, height)
  if resolved_width <= 0.0 || resolved_height <= 0.0 {
    None
  } else {
    Some((clip_left, clip_top, resolved_width, resolved_height))
  }
}

///|
fn resolve_clip_path_inset(value : Double, size : Double) -> Double {
  let raw = if value < 0.0 { -value * size } else { value }
  if raw <= 0.0 {
    0.0
  } else if raw > size {
    size
  } else {
    raw
  }
}
