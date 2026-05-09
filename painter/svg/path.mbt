///|
/// SVG Path Parser and Rasterizer
/// Full SVG 1.1 path command support

///|
/// Parse a path data string into an array of path commands
pub fn parse_path(data : String) -> Array[PathCommand] {
  @msvg.parse_path(data).map(path_command_from_msvg)
}

///|
/// Path context for tracking current position during conversion
priv struct PathContext {
  mut x : Double
  mut y : Double
  mut start_x : Double // For closepath
  mut start_y : Double
  mut last_ctrl_x : Double // For smooth curves
  mut last_ctrl_y : Double
  mut last_cmd_was_curve : Bool
  mut last_cmd_was_quad : Bool
}

///|
fn PathContext::new() -> PathContext {
  {
    x: 0.0,
    y: 0.0,
    start_x: 0.0,
    start_y: 0.0,
    last_ctrl_x: 0.0,
    last_ctrl_y: 0.0,
    last_cmd_was_curve: false,
    last_cmd_was_quad: false,
  }
}

///|
/// Convert path commands to an array of polylines (for rendering)
/// Returns array of point arrays, each representing a subpath
pub fn path_to_polylines(
  commands : Array[PathCommand],
  flatness : Double,
) -> Array[Array[(Double, Double)]] {
  let ctx = PathContext::new()
  let result : Array[Array[(Double, Double)]] = []
  let mut current_path : Array[(Double, Double)] = []
  for cmd in commands {
    match cmd {
      MoveTo(x, y) => {
        if current_path.length() > 0 {
          result.push(current_path)
        }
        current_path = [(x, y)]
        ctx.x = x
        ctx.y = y
        ctx.start_x = x
        ctx.start_y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = false
      }
      MoveToRel(dx, dy) => {
        let x = ctx.x + dx
        let y = ctx.y + dy
        if current_path.length() > 0 {
          result.push(current_path)
        }
        current_path = [(x, y)]
        ctx.x = x
        ctx.y = y
        ctx.start_x = x
        ctx.start_y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = false
      }
      LineTo(x, y) => {
        current_path.push((x, y))
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = false
      }
      LineToRel(dx, dy) => {
        let x = ctx.x + dx
        let y = ctx.y + dy
        current_path.push((x, y))
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = false
      }
      HorizontalLineTo(x) => {
        current_path.push((x, ctx.y))
        ctx.x = x
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = false
      }
      HorizontalLineToRel(dx) => {
        let x = ctx.x + dx
        current_path.push((x, ctx.y))
        ctx.x = x
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = false
      }
      VerticalLineTo(y) => {
        current_path.push((ctx.x, y))
        ctx.y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = false
      }
      VerticalLineToRel(dy) => {
        let y = ctx.y + dy
        current_path.push((ctx.x, y))
        ctx.y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = false
      }
      CurveTo(x1, y1, x2, y2, x, y) => {
        flatten_cubic(
          ctx.x,
          ctx.y,
          x1,
          y1,
          x2,
          y2,
          x,
          y,
          flatness,
          current_path,
        )
        ctx.last_ctrl_x = x2
        ctx.last_ctrl_y = y2
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = true
        ctx.last_cmd_was_quad = false
      }
      CurveToRel(dx1, dy1, dx2, dy2, dx, dy) => {
        let x1 = ctx.x + dx1
        let y1 = ctx.y + dy1
        let x2 = ctx.x + dx2
        let y2 = ctx.y + dy2
        let x = ctx.x + dx
        let y = ctx.y + dy
        flatten_cubic(
          ctx.x,
          ctx.y,
          x1,
          y1,
          x2,
          y2,
          x,
          y,
          flatness,
          current_path,
        )
        ctx.last_ctrl_x = x2
        ctx.last_ctrl_y = y2
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = true
        ctx.last_cmd_was_quad = false
      }
      SmoothCurveTo(x2, y2, x, y) => {
        // Reflect previous control point
        let x1 = if ctx.last_cmd_was_curve {
          2.0 * ctx.x - ctx.last_ctrl_x
        } else {
          ctx.x
        }
        let y1 = if ctx.last_cmd_was_curve {
          2.0 * ctx.y - ctx.last_ctrl_y
        } else {
          ctx.y
        }
        flatten_cubic(
          ctx.x,
          ctx.y,
          x1,
          y1,
          x2,
          y2,
          x,
          y,
          flatness,
          current_path,
        )
        ctx.last_ctrl_x = x2
        ctx.last_ctrl_y = y2
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = true
        ctx.last_cmd_was_quad = false
      }
      SmoothCurveToRel(dx2, dy2, dx, dy) => {
        let x1 = if ctx.last_cmd_was_curve {
          2.0 * ctx.x - ctx.last_ctrl_x
        } else {
          ctx.x
        }
        let y1 = if ctx.last_cmd_was_curve {
          2.0 * ctx.y - ctx.last_ctrl_y
        } else {
          ctx.y
        }
        let x2 = ctx.x + dx2
        let y2 = ctx.y + dy2
        let x = ctx.x + dx
        let y = ctx.y + dy
        flatten_cubic(
          ctx.x,
          ctx.y,
          x1,
          y1,
          x2,
          y2,
          x,
          y,
          flatness,
          current_path,
        )
        ctx.last_ctrl_x = x2
        ctx.last_ctrl_y = y2
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = true
        ctx.last_cmd_was_quad = false
      }
      QuadraticCurveTo(x1, y1, x, y) => {
        flatten_quadratic(ctx.x, ctx.y, x1, y1, x, y, flatness, current_path)
        ctx.last_ctrl_x = x1
        ctx.last_ctrl_y = y1
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = true
      }
      QuadraticCurveToRel(dx1, dy1, dx, dy) => {
        let x1 = ctx.x + dx1
        let y1 = ctx.y + dy1
        let x = ctx.x + dx
        let y = ctx.y + dy
        flatten_quadratic(ctx.x, ctx.y, x1, y1, x, y, flatness, current_path)
        ctx.last_ctrl_x = x1
        ctx.last_ctrl_y = y1
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = true
      }
      SmoothQuadraticCurveTo(x, y) => {
        let x1 = if ctx.last_cmd_was_quad {
          2.0 * ctx.x - ctx.last_ctrl_x
        } else {
          ctx.x
        }
        let y1 = if ctx.last_cmd_was_quad {
          2.0 * ctx.y - ctx.last_ctrl_y
        } else {
          ctx.y
        }
        flatten_quadratic(ctx.x, ctx.y, x1, y1, x, y, flatness, current_path)
        ctx.last_ctrl_x = x1
        ctx.last_ctrl_y = y1
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = true
      }
      SmoothQuadraticCurveToRel(dx, dy) => {
        let x1 = if ctx.last_cmd_was_quad {
          2.0 * ctx.x - ctx.last_ctrl_x
        } else {
          ctx.x
        }
        let y1 = if ctx.last_cmd_was_quad {
          2.0 * ctx.y - ctx.last_ctrl_y
        } else {
          ctx.y
        }
        let x = ctx.x + dx
        let y = ctx.y + dy
        flatten_quadratic(ctx.x, ctx.y, x1, y1, x, y, flatness, current_path)
        ctx.last_ctrl_x = x1
        ctx.last_ctrl_y = y1
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = true
      }
      ArcTo(rx, ry, rotation, large_arc, sweep, x, y) => {
        flatten_arc(
          ctx.x,
          ctx.y,
          rx,
          ry,
          rotation,
          large_arc,
          sweep,
          x,
          y,
          flatness,
          current_path,
        )
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = false
      }
      ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy) => {
        let x = ctx.x + dx
        let y = ctx.y + dy
        flatten_arc(
          ctx.x,
          ctx.y,
          rx,
          ry,
          rotation,
          large_arc,
          sweep,
          x,
          y,
          flatness,
          current_path,
        )
        ctx.x = x
        ctx.y = y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = false
      }
      ClosePath => {
        // Close back to start
        if current_path.length() > 0 {
          current_path.push((ctx.start_x, ctx.start_y))
        }
        ctx.x = ctx.start_x
        ctx.y = ctx.start_y
        ctx.last_cmd_was_curve = false
        ctx.last_cmd_was_quad = false
      }
    }
  }
  if current_path.length() > 0 {
    result.push(current_path)
  }
  result
}

///|
/// Flatten cubic Bezier curve using adaptive subdivision
fn flatten_cubic(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
  flatness : Double,
  points : Array[(Double, Double)],
) -> Unit {
  flatten_cubic_recursive(x0, y0, x1, y1, x2, y2, x3, y3, flatness, points, 0)
}

///|
fn flatten_cubic_recursive(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
  flatness : Double,
  points : Array[(Double, Double)],
  depth : Int,
) -> Unit {
  // Limit recursion depth
  if depth > 16 {
    points.push((x3, y3))
    return
  }
  // Check flatness: distance from control points to line
  let dx = x3 - x0
  let dy = y3 - y0
  let d2 = if dx == 0.0 && dy == 0.0 {
    // Degenerate: use distance from midpoint
    let mx = (x0 + x3) / 2.0
    let my = (y0 + y3) / 2.0
    let d1x = x1 - mx
    let d1y = y1 - my
    let d2x = x2 - mx
    let d2y = y2 - my
    max(d1x * d1x + d1y * d1y, d2x * d2x + d2y * d2y)
  } else {
    let len_sq = dx * dx + dy * dy
    // Distance from control points to line segment
    let t1 = ((x1 - x0) * dx + (y1 - y0) * dy) / len_sq
    let t2 = ((x2 - x0) * dx + (y2 - y0) * dy) / len_sq
    let px1 = x0 + t1 * dx
    let py1 = y0 + t1 * dy
    let px2 = x0 + t2 * dx
    let py2 = y0 + t2 * dy
    let d1x = x1 - px1
    let d1y = y1 - py1
    let d2x = x2 - px2
    let d2y = y2 - py2
    max(d1x * d1x + d1y * d1y, d2x * d2x + d2y * d2y)
  }
  if d2 <= flatness * flatness {
    points.push((x3, y3))
  } else {
    // Subdivide at t=0.5
    let x01 = (x0 + x1) / 2.0
    let y01 = (y0 + y1) / 2.0
    let x12 = (x1 + x2) / 2.0
    let y12 = (y1 + y2) / 2.0
    let x23 = (x2 + x3) / 2.0
    let y23 = (y2 + y3) / 2.0
    let x012 = (x01 + x12) / 2.0
    let y012 = (y01 + y12) / 2.0
    let x123 = (x12 + x23) / 2.0
    let y123 = (y12 + y23) / 2.0
    let x0123 = (x012 + x123) / 2.0
    let y0123 = (y012 + y123) / 2.0
    flatten_cubic_recursive(
      x0,
      y0,
      x01,
      y01,
      x012,
      y012,
      x0123,
      y0123,
      flatness,
      points,
      depth + 1,
    )
    flatten_cubic_recursive(
      x0123,
      y0123,
      x123,
      y123,
      x23,
      y23,
      x3,
      y3,
      flatness,
      points,
      depth + 1,
    )
  }
}

///|
/// Flatten quadratic Bezier curve using adaptive subdivision
fn flatten_quadratic(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  flatness : Double,
  points : Array[(Double, Double)],
) -> Unit {
  flatten_quadratic_recursive(x0, y0, x1, y1, x2, y2, flatness, points, 0)
}

///|
fn flatten_quadratic_recursive(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  flatness : Double,
  points : Array[(Double, Double)],
  depth : Int,
) -> Unit {
  if depth > 16 {
    points.push((x2, y2))
    return
  }
  // Check flatness
  let dx = x2 - x0
  let dy = y2 - y0
  let d2 = if dx == 0.0 && dy == 0.0 {
    let d1x = x1 - x0
    let d1y = y1 - y0
    d1x * d1x + d1y * d1y
  } else {
    let len_sq = dx * dx + dy * dy
    let t = ((x1 - x0) * dx + (y1 - y0) * dy) / len_sq
    let px = x0 + t * dx
    let py = y0 + t * dy
    let d1x = x1 - px
    let d1y = y1 - py
    d1x * d1x + d1y * d1y
  }
  if d2 <= flatness * flatness {
    points.push((x2, y2))
  } else {
    // Subdivide
    let x01 = (x0 + x1) / 2.0
    let y01 = (y0 + y1) / 2.0
    let x12 = (x1 + x2) / 2.0
    let y12 = (y1 + y2) / 2.0
    let x012 = (x01 + x12) / 2.0
    let y012 = (y01 + y12) / 2.0
    flatten_quadratic_recursive(
      x0,
      y0,
      x01,
      y01,
      x012,
      y012,
      flatness,
      points,
      depth + 1,
    )
    flatten_quadratic_recursive(
      x012,
      y012,
      x12,
      y12,
      x2,
      y2,
      flatness,
      points,
      depth + 1,
    )
  }
}

///|
/// Flatten elliptical arc
fn flatten_arc(
  x1 : Double,
  y1 : Double,
  rx_in : Double,
  ry_in : Double,
  rotation_degrees : Double,
  large_arc : Bool,
  sweep : Bool,
  x2 : Double,
  y2 : Double,
  flatness : Double,
  points : Array[(Double, Double)],
) -> Unit {
  // Handle degenerate cases
  if (x1 == x2 && y1 == y2) || rx_in == 0.0 || ry_in == 0.0 {
    points.push((x2, y2))
    return
  }
  // Ensure radii are positive
  let mut rx = if rx_in < 0.0 { -rx_in } else { rx_in }
  let mut ry = if ry_in < 0.0 { -ry_in } else { ry_in }
  // Convert to center parameterization
  let phi = degrees_to_radians(rotation_degrees)
  let cos_phi = @math.cos(phi)
  let sin_phi = @math.sin(phi)
  // Step 1: Transform to unit circle coordinates
  let dx = (x1 - x2) / 2.0
  let dy = (y1 - y2) / 2.0
  let x1p = cos_phi * dx + sin_phi * dy
  let y1p = -sin_phi * dx + cos_phi * dy
  // Scale correction if needed
  let lambda = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
  if lambda > 1.0 {
    let sqrt_lambda = lambda.sqrt()
    rx = rx * sqrt_lambda
    ry = ry * sqrt_lambda
  }
  // Step 2: Compute center
  let rx2 = rx * rx
  let ry2 = ry * ry
  let x1p2 = x1p * x1p
  let y1p2 = y1p * y1p
  let sq = (rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2) / (rx2 * y1p2 + ry2 * x1p2)
  let sq_abs = if sq < 0.0 { 0.0 } else { sq }
  let coef = sq_abs.sqrt() * (if large_arc == sweep { -1.0 } else { 1.0 })
  let cxp = coef * rx * y1p / ry
  let cyp = -coef * ry * x1p / rx
  // Transform back to original coordinates
  let cx = cos_phi * cxp - sin_phi * cyp + (x1 + x2) / 2.0
  let cy = sin_phi * cxp + cos_phi * cyp + (y1 + y2) / 2.0
  // Step 3: Compute angles
  let theta1 = angle_between(1.0, 0.0, (x1p - cxp) / rx, (y1p - cyp) / ry)
  let mut dtheta = angle_between(
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
    (-x1p - cxp) / rx,
    (-y1p - cyp) / ry,
  )
  // Adjust sweep
  let pi = 3.14159265358979323846
  if !sweep && dtheta > 0.0 {
    dtheta = dtheta - 2.0 * pi
  } else if sweep && dtheta < 0.0 {
    dtheta = dtheta + 2.0 * pi
  }
  // Generate points along the arc
  let n = max_int(((dtheta / flatness).abs() / 0.5).to_int(), 2)
  for i = 1; i <= n; i = i + 1 {
    let t = i.to_double() / n.to_double()
    let theta = theta1 + t * dtheta
    let cos_t = @math.cos(theta)
    let sin_t = @math.sin(theta)
    // Point on unit circle, scaled and rotated
    let x = cos_phi * rx * cos_t - sin_phi * ry * sin_t + cx
    let y = sin_phi * rx * cos_t + cos_phi * ry * sin_t + cy
    points.push((x, y))
  }
}

///|
/// Compute angle between two vectors
fn angle_between(ux : Double, uy : Double, vx : Double, vy : Double) -> Double {
  let dot = ux * vx + uy * vy
  let len_u = (ux * ux + uy * uy).sqrt()
  let len_v = (vx * vx + vy * vy).sqrt()
  let len_prod = len_u * len_v
  if len_prod == 0.0 {
    return 0.0
  }
  let mut cos_angle = dot / len_prod
  // Clamp to [-1, 1]
  if cos_angle > 1.0 {
    cos_angle = 1.0
  }
  if cos_angle < -1.0 {
    cos_angle = -1.0
  }
  let angle = @math.acos(cos_angle)
  // Check sign using cross product
  let cross = ux * vy - uy * vx
  if cross < 0.0 {
    -angle
  } else {
    angle
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Rasterize path commands
pub fn raster_path(
  commands : Array[PathCommand],
  fill_color : Color?,
  stroke_color : Color?,
  flatness : Double,
  setter : PixelSetter,
) -> Unit {
  let polylines = path_to_polylines(commands, flatness)
  // Fill
  match fill_color {
    Some(color) =>
      for polyline in polylines {
        let int_points = polyline.map(fn(p) { (p.0.to_int(), p.1.to_int()) })
        if int_points.length() >= 3 {
          raster_polygon_fill(int_points, color, setter)
        }
      }
    None => ()
  }
  // Stroke
  match stroke_color {
    Some(color) =>
      for polyline in polylines {
        let int_points = polyline.map(fn(p) { (p.0.to_int(), p.1.to_int()) })
        raster_polyline(int_points, color, setter)
      }
    None => ()
  }
}

///|
/// Compute bounding box of path commands
pub fn path_bbox(commands : Array[PathCommand]) -> BoundingBox {
  let polylines = path_to_polylines(commands, 1.0)
  let mut bbox = BoundingBox::empty()
  for polyline in polylines {
    for point in polyline {
      bbox = bbox.expand_by_point(point.0, point.1)
    }
  }
  bbox
}
