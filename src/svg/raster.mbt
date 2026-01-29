///|
/// SVG Rasterizer
/// Efficient shape rasterization algorithms (Bresenham, Scanline, etc.)

///|
/// Pixel setter callback type
/// (x, y, color) -> Unit
pub(all) struct PixelSetter {
  set : (Int, Int, Color) -> Unit
}

///|
/// Draw a single pixel
pub fn PixelSetter::pixel(
  self : PixelSetter,
  x : Int,
  y : Int,
  color : Color,
) -> Unit {
  (self.set)(x, y, color)
}

///|
/// Create a clipped pixel setter that only draws within the clip rect
pub fn PixelSetter::with_clip(
  self : PixelSetter,
  clip : ClipRect,
) -> PixelSetter {
  let inner_set = self.set
  { set: fn(x, y, color) { if clip.contains(x, y) { inner_set(x, y, color) } } }
}

///|
/// Create a clipped pixel setter with offset (for camera translation)
pub fn PixelSetter::with_clip_and_offset(
  self : PixelSetter,
  clip : ClipRect,
  offset_x : Int,
  offset_y : Int,
) -> PixelSetter {
  let inner_set = self.set
  {
    set: fn(x, y, color) {
      let tx = x + offset_x
      let ty = y + offset_y
      if clip.contains(tx, ty) {
        inner_set(tx, ty, color)
      }
    },
  }
}

///|
/// Bresenham's line algorithm - integer-only, efficient line drawing
pub fn raster_line(
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  let mut x0 = x0
  let mut y0 = y0
  let dx = if x1 > x0 { x1 - x0 } else { x0 - x1 }
  let dy = if y1 > y0 { y1 - y0 } else { y0 - y1 }
  let sx = if x0 < x1 { 1 } else { -1 }
  let sy = if y0 < y1 { 1 } else { -1 }
  let mut err = dx - dy
  while true {
    setter.pixel(x0, y0, color)
    if x0 == x1 && y0 == y1 {
      break
    }
    let e2 = 2 * err
    if e2 > -dy {
      err = err - dy
      x0 = x0 + sx
    }
    if e2 < dx {
      err = err + dx
      y0 = y0 + sy
    }
  }
}

///|
/// Bresenham's line with dash pattern support
pub fn raster_line_dashed(
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  color : Color,
  dasharray : Array[Double],
  dashoffset : Double,
  setter : PixelSetter,
) -> Unit {
  if dasharray.length() == 0 {
    // No dash pattern, draw solid line
    raster_line(x0, y0, x1, y1, color, setter)
    return
  }
  // Calculate total line length
  let dx_f = (x1 - x0).to_double()
  let dy_f = (y1 - y0).to_double()
  let total_len = (dx_f * dx_f + dy_f * dy_f).sqrt()
  if total_len < 0.5 {
    return
  }
  // Dash pattern state
  let mut dash_pos = -dashoffset
  // Normalize dashoffset to be within pattern
  let total_dash = dasharray.fold(init=0.0, fn(acc, v) { acc + v })
  while dash_pos < 0.0 {
    dash_pos = dash_pos + total_dash
  }
  while dash_pos >= total_dash {
    dash_pos = dash_pos - total_dash
  }
  // Bresenham setup
  let mut x = x0
  let mut y = y0
  let dx = if x1 > x0 { x1 - x0 } else { x0 - x1 }
  let dy = if y1 > y0 { y1 - y0 } else { y0 - y1 }
  let sx = if x0 < x1 { 1 } else { -1 }
  let sy = if y0 < y1 { 1 } else { -1 }
  let mut err = dx - dy
  while true {
    // Calculate distance from start
    let cur_dx = (x - x0).to_double()
    let cur_dy = (y - y0).to_double()
    let cur_dist = (cur_dx * cur_dx + cur_dy * cur_dy).sqrt()
    // Update dash state based on distance traveled
    let travel = cur_dist
    let mut pos_in_pattern = dash_pos + travel
    while pos_in_pattern >= total_dash {
      pos_in_pattern = pos_in_pattern - total_dash
    }
    // Find current dash index
    let mut cum = 0.0
    let mut cur_idx = 0
    for i = 0; i < dasharray.length(); i = i + 1 {
      if cum + dasharray[i] > pos_in_pattern {
        cur_idx = i
        break
      }
      cum = cum + dasharray[i]
    }
    // Even indices draw, odd indices gap
    let is_drawing = cur_idx % 2 == 0
    if is_drawing {
      setter.pixel(x, y, color)
    }
    if x == x1 && y == y1 {
      break
    }
    let e2 = 2 * err
    if e2 > -dy {
      err = err - dy
      x = x + sx
    }
    if e2 < dx {
      err = err + dx
      y = y + sy
    }
  }
}

///|
/// Draw polyline with dash pattern
pub fn raster_polyline_dashed(
  points : Array[(Int, Int)],
  color : Color,
  dasharray : Array[Double],
  dashoffset : Double,
  setter : PixelSetter,
) -> Unit {
  if points.length() < 2 {
    return
  }
  if dasharray.length() == 0 {
    raster_polyline(points, color, setter)
    return
  }
  let mut offset = dashoffset
  for i = 0; i < points.length() - 1; i = i + 1 {
    let (x0, y0) = points[i]
    let (x1, y1) = points[i + 1]
    raster_line_dashed(x0, y0, x1, y1, color, dasharray, offset, setter)
    // Calculate line length and update offset
    let dx = (x1 - x0).to_double()
    let dy = (y1 - y0).to_double()
    let len = (dx * dx + dy * dy).sqrt()
    offset = offset + len
    // Normalize offset within dash pattern total length
    let total_dash = dasharray.fold(init=0.0, fn(acc, v) { acc + v })
    while offset >= total_dash {
      offset = offset - total_dash
    }
  }
}

///|
/// Draw rectangle outline (stroke only)
pub fn raster_rect_stroke(
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  if w <= 0 || h <= 0 {
    return
  }
  // Top edge
  for px = x; px < x + w; px = px + 1 {
    setter.pixel(px, y, color)
  }
  // Bottom edge
  for px = x; px < x + w; px = px + 1 {
    setter.pixel(px, y + h - 1, color)
  }
  // Left edge
  for py = y + 1; py < y + h - 1; py = py + 1 {
    setter.pixel(x, py, color)
  }
  // Right edge
  for py = y + 1; py < y + h - 1; py = py + 1 {
    setter.pixel(x + w - 1, py, color)
  }
}

///|
/// Fill rectangle
pub fn raster_rect_fill(
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  if w <= 0 || h <= 0 {
    return
  }
  for py = y; py < y + h; py = py + 1 {
    for px = x; px < x + w; px = px + 1 {
      setter.pixel(px, py, color)
    }
  }
}

///|
/// Draw filled rectangle with linear gradient
pub fn raster_rect_gradient(
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  grad : LinearGradient,
  opacity : Double,
  setter : PixelSetter,
) -> Unit {
  if w <= 0 || h <= 0 {
    return
  }
  // Gradient direction vector (in normalized 0-1 space)
  let gx1 = grad.x1
  let gy1 = grad.y1
  let gx2 = grad.x2
  let gy2 = grad.y2
  let gdx = gx2 - gx1
  let gdy = gy2 - gy1
  let glen_sq = gdx * gdx + gdy * gdy
  for py = y; py < y + h; py = py + 1 {
    for px = x; px < x + w; px = px + 1 {
      // Normalize pixel position to 0-1 within rect
      let nx = if w > 1 {
        (px - x).to_double() / (w - 1).to_double()
      } else {
        0.5
      }
      let ny = if h > 1 {
        (py - y).to_double() / (h - 1).to_double()
      } else {
        0.5
      }
      // Project onto gradient line
      let t = if glen_sq > 0.0001 {
        ((nx - gx1) * gdx + (ny - gy1) * gdy) / glen_sq
      } else {
        0.0
      }
      // Get color at this position
      let color = grad.color_at(t)
      let final_color = if opacity < 1.0 {
        Color::rgba(
          color.r,
          color.g,
          color.b,
          (color.a.to_double() * opacity).to_int(),
        )
      } else {
        color
      }
      setter.pixel(px, py, final_color)
    }
  }
}

///|
/// Draw filled rectangle with radial gradient
pub fn raster_rect_radial_gradient(
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  grad : RadialGradient,
  opacity : Double,
  setter : PixelSetter,
) -> Unit {
  if w <= 0 || h <= 0 {
    return
  }
  for py = y; py < y + h; py = py + 1 {
    for px = x; px < x + w; px = px + 1 {
      // Normalize pixel position to 0-1 within rect
      let nx = if w > 1 {
        (px - x).to_double() / (w - 1).to_double()
      } else {
        0.5
      }
      let ny = if h > 1 {
        (py - y).to_double() / (h - 1).to_double()
      } else {
        0.5
      }
      // Get color using radial gradient
      let color = grad.color_at(nx, ny, 1.0, 1.0)
      let final_color = if opacity < 1.0 {
        Color::rgba(
          color.r,
          color.g,
          color.b,
          (color.a.to_double() * opacity).to_int(),
        )
      } else {
        color
      }
      setter.pixel(px, py, final_color)
    }
  }
}

///|
/// Draw filled circle with radial gradient
pub fn raster_circle_radial_gradient(
  cx : Int,
  cy : Int,
  r : Int,
  grad : RadialGradient,
  opacity : Double,
  setter : PixelSetter,
) -> Unit {
  if r <= 0 {
    return
  }
  let r_sq = r * r
  for py = cy - r; py <= cy + r; py = py + 1 {
    for px = cx - r; px <= cx + r; px = px + 1 {
      let dx = px - cx
      let dy = py - cy
      let dist_sq = dx * dx + dy * dy
      if dist_sq <= r_sq {
        // Normalize position: center is (0.5, 0.5), edges at distance r
        let nx = 0.5 + dx.to_double() / (2.0 * r.to_double())
        let ny = 0.5 + dy.to_double() / (2.0 * r.to_double())
        let color = grad.color_at(nx, ny, 1.0, 1.0)
        let final_color = if opacity < 1.0 {
          Color::rgba(
            color.r,
            color.g,
            color.b,
            (color.a.to_double() * opacity).to_int(),
          )
        } else {
          color
        }
        setter.pixel(px, py, final_color)
      }
    }
  }
}

///|
/// Draw filled ellipse with radial gradient
pub fn raster_ellipse_radial_gradient(
  cx : Int,
  cy : Int,
  rx : Int,
  ry : Int,
  grad : RadialGradient,
  opacity : Double,
  setter : PixelSetter,
) -> Unit {
  if rx <= 0 || ry <= 0 {
    return
  }
  for py = cy - ry; py <= cy + ry; py = py + 1 {
    for px = cx - rx; px <= cx + rx; px = px + 1 {
      let dx = (px - cx).to_double() / rx.to_double()
      let dy = (py - cy).to_double() / ry.to_double()
      let dist_sq = dx * dx + dy * dy
      if dist_sq <= 1.0 {
        // Normalize position to 0-1 range
        let nx = 0.5 + (px - cx).to_double() / (2.0 * rx.to_double())
        let ny = 0.5 + (py - cy).to_double() / (2.0 * ry.to_double())
        let color = grad.color_at(nx, ny, 1.0, 1.0)
        let final_color = if opacity < 1.0 {
          Color::rgba(
            color.r,
            color.g,
            color.b,
            (color.a.to_double() * opacity).to_int(),
          )
        } else {
          color
        }
        setter.pixel(px, py, final_color)
      }
    }
  }
}

///|
/// Draw rounded rectangle outline
pub fn raster_rounded_rect_stroke(
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  rx : Int,
  ry : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  if w <= 0 || h <= 0 {
    return
  }
  // Clamp radii to half dimensions
  let rx = min_int(rx, w / 2)
  let ry = min_int(ry, h / 2)
  if rx <= 0 || ry <= 0 {
    // No rounding, draw regular rect
    raster_rect_stroke(x, y, w, h, color, setter)
    return
  }
  // Top edge (middle)
  for px = x + rx; px < x + w - rx; px = px + 1 {
    setter.pixel(px, y, color)
  }
  // Bottom edge (middle)
  for px = x + rx; px < x + w - rx; px = px + 1 {
    setter.pixel(px, y + h - 1, color)
  }
  // Left edge (middle)
  for py = y + ry; py < y + h - ry; py = py + 1 {
    setter.pixel(x, py, color)
  }
  // Right edge (middle)
  for py = y + ry; py < y + h - ry; py = py + 1 {
    setter.pixel(x + w - 1, py, color)
  }
  // Draw corners using ellipse arc algorithm
  draw_corner_arc(x + rx, y + ry, rx, ry, 2, color, setter) // top-left
  draw_corner_arc(x + w - rx - 1, y + ry, rx, ry, 1, color, setter) // top-right
  draw_corner_arc(x + rx, y + h - ry - 1, rx, ry, 3, color, setter) // bottom-left
  draw_corner_arc(x + w - rx - 1, y + h - ry - 1, rx, ry, 4, color, setter) // bottom-right
}

///|
/// Draw corner arc (quadrant of ellipse)
/// quadrant: 1=top-right, 2=top-left, 3=bottom-left, 4=bottom-right
fn draw_corner_arc(
  cx : Int,
  cy : Int,
  rx : Int,
  ry : Int,
  quadrant : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  // Simplified ellipse arc using midpoint algorithm
  let rx2 = rx * rx
  let ry2 = ry * ry
  let two_rx2 = 2 * rx2
  let two_ry2 = 2 * ry2
  let mut x = 0
  let mut y = ry
  let mut px = 0
  let mut py = two_rx2 * y
  // Plot initial point
  plot_corner_point(cx, cy, x, y, quadrant, color, setter)
  // Region 1
  let mut p = ry2 - rx2 * ry + rx2 / 4
  while px < py {
    x = x + 1
    px = px + two_ry2
    if p < 0 {
      p = p + ry2 + px
    } else {
      y = y - 1
      py = py - two_rx2
      p = p + ry2 + px - py
    }
    plot_corner_point(cx, cy, x, y, quadrant, color, setter)
  }
  // Region 2
  p = ry2 * (x * 2 + 1) * (x * 2 + 1) / 4 + rx2 * (y - 1) * (y - 1) - rx2 * ry2
  while y > 0 {
    y = y - 1
    py = py - two_rx2
    if p > 0 {
      p = p + rx2 - py
    } else {
      x = x + 1
      px = px + two_ry2
      p = p + rx2 - py + px
    }
    plot_corner_point(cx, cy, x, y, quadrant, color, setter)
  }
}

///|
/// Plot point in specific quadrant relative to center
fn plot_corner_point(
  cx : Int,
  cy : Int,
  x : Int,
  y : Int,
  quadrant : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  match quadrant {
    1 => setter.pixel(cx + x, cy - y, color) // top-right
    2 => setter.pixel(cx - x, cy - y, color) // top-left
    3 => setter.pixel(cx - x, cy + y, color) // bottom-left
    4 => setter.pixel(cx + x, cy + y, color) // bottom-right
    _ => ()
  }
}

///|
/// Midpoint circle algorithm - draw circle outline
pub fn raster_circle_stroke(
  cx : Int,
  cy : Int,
  r : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  if r <= 0 {
    setter.pixel(cx, cy, color)
    return
  }
  let mut x = r
  let mut y = 0
  let mut err = 1 - r
  while x >= y {
    // Draw all 8 octants
    setter.pixel(cx + x, cy + y, color)
    setter.pixel(cx - x, cy + y, color)
    setter.pixel(cx + x, cy - y, color)
    setter.pixel(cx - x, cy - y, color)
    setter.pixel(cx + y, cy + x, color)
    setter.pixel(cx - y, cy + x, color)
    setter.pixel(cx + y, cy - x, color)
    setter.pixel(cx - y, cy - x, color)
    y = y + 1
    if err < 0 {
      err = err + 2 * y + 1
    } else {
      x = x - 1
      err = err + 2 * (y - x) + 1
    }
  }
}

///|
/// Fill circle using scanlines
pub fn raster_circle_fill(
  cx : Int,
  cy : Int,
  r : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  if r <= 0 {
    setter.pixel(cx, cy, color)
    return
  }
  let mut x = r
  let mut y = 0
  let mut err = 1 - r
  while x >= y {
    // Draw horizontal lines for each y level
    for px = cx - x; px <= cx + x; px = px + 1 {
      setter.pixel(px, cy + y, color)
      setter.pixel(px, cy - y, color)
    }
    for px = cx - y; px <= cx + y; px = px + 1 {
      setter.pixel(px, cy + x, color)
      setter.pixel(px, cy - x, color)
    }
    y = y + 1
    if err < 0 {
      err = err + 2 * y + 1
    } else {
      x = x - 1
      err = err + 2 * (y - x) + 1
    }
  }
}

///|
/// Midpoint ellipse algorithm - draw ellipse outline
pub fn raster_ellipse_stroke(
  cx : Int,
  cy : Int,
  rx : Int,
  ry : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  if rx <= 0 && ry <= 0 {
    setter.pixel(cx, cy, color)
    return
  }
  if rx <= 0 {
    // Vertical line
    for y = cy - ry; y <= cy + ry; y = y + 1 {
      setter.pixel(cx, y, color)
    }
    return
  }
  if ry <= 0 {
    // Horizontal line
    for x = cx - rx; x <= cx + rx; x = x + 1 {
      setter.pixel(x, cy, color)
    }
    return
  }
  let rx2 = rx * rx
  let ry2 = ry * ry
  let two_rx2 = 2 * rx2
  let two_ry2 = 2 * ry2
  let mut x = 0
  let mut y = ry
  let mut px = 0
  let mut py = two_rx2 * y
  // Plot initial points
  setter.pixel(cx + x, cy + y, color)
  setter.pixel(cx - x, cy + y, color)
  setter.pixel(cx + x, cy - y, color)
  setter.pixel(cx - x, cy - y, color)
  // Region 1
  let mut p = ry2 - rx2 * ry + rx2 / 4
  while px < py {
    x = x + 1
    px = px + two_ry2
    if p < 0 {
      p = p + ry2 + px
    } else {
      y = y - 1
      py = py - two_rx2
      p = p + ry2 + px - py
    }
    setter.pixel(cx + x, cy + y, color)
    setter.pixel(cx - x, cy + y, color)
    setter.pixel(cx + x, cy - y, color)
    setter.pixel(cx - x, cy - y, color)
  }
  // Region 2
  p = ry2 * (x * 2 + 1) * (x * 2 + 1) / 4 + rx2 * (y - 1) * (y - 1) - rx2 * ry2
  while y > 0 {
    y = y - 1
    py = py - two_rx2
    if p > 0 {
      p = p + rx2 - py
    } else {
      x = x + 1
      px = px + two_ry2
      p = p + rx2 - py + px
    }
    setter.pixel(cx + x, cy + y, color)
    setter.pixel(cx - x, cy + y, color)
    setter.pixel(cx + x, cy - y, color)
    setter.pixel(cx - x, cy - y, color)
  }
}

///|
/// Fill ellipse using scanlines
pub fn raster_ellipse_fill(
  cx : Int,
  cy : Int,
  rx : Int,
  ry : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  if rx <= 0 && ry <= 0 {
    setter.pixel(cx, cy, color)
    return
  }
  if rx <= 0 {
    for y = cy - ry; y <= cy + ry; y = y + 1 {
      setter.pixel(cx, y, color)
    }
    return
  }
  if ry <= 0 {
    for x = cx - rx; x <= cx + rx; x = x + 1 {
      setter.pixel(x, cy, color)
    }
    return
  }
  // Fill using scanline for each y from -ry to +ry
  for dy = -ry; dy <= ry; dy = dy + 1 {
    // Calculate x extent for this y using ellipse equation
    // x^2/rx^2 + y^2/ry^2 = 1
    // x = rx * sqrt(1 - y^2/ry^2)
    let y_frac = dy.to_double() / ry.to_double()
    let x_extent_sq = 1.0 - y_frac * y_frac
    if x_extent_sq >= 0.0 {
      let x_extent = (x_extent_sq.sqrt() * rx.to_double()).to_int()
      for dx = -x_extent; dx <= x_extent; dx = dx + 1 {
        setter.pixel(cx + dx, cy + dy, color)
      }
    }
  }
}

///|
/// Polygon fill using scanline algorithm with edge table
pub fn raster_polygon_fill(
  points : Array[(Int, Int)],
  color : Color,
  setter : PixelSetter,
) -> Unit {
  let n = points.length()
  if n < 3 {
    return
  }
  // Find bounding box
  let mut min_y = points[0].1
  let mut max_y = points[0].1
  for i = 1; i < n; i = i + 1 {
    let y = points[i].1
    if y < min_y {
      min_y = y
    }
    if y > max_y {
      max_y = y
    }
  }
  // Scanline fill
  for y = min_y; y <= max_y; y = y + 1 {
    // Find all intersections with polygon edges
    let intersections : Array[Int] = []
    for i = 0; i < n; i = i + 1 {
      let j = (i + 1) % n
      let (x1, y1) = points[i]
      let (x2, y2) = points[j]
      // Check if edge crosses this scanline
      if (y1 <= y && y < y2) || (y2 <= y && y < y1) {
        // Calculate x intersection
        let x = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
        intersections.push(x)
      }
    }
    // Sort intersections
    sort_ints(intersections)
    // Fill between pairs of intersections
    let mut i = 0
    while i + 1 < intersections.length() {
      let x_start = intersections[i]
      let x_end = intersections[i + 1]
      for x = x_start; x <= x_end; x = x + 1 {
        setter.pixel(x, y, color)
      }
      i = i + 2
    }
  }
}

///|
/// Draw polygon outline
pub fn raster_polygon_stroke(
  points : Array[(Int, Int)],
  color : Color,
  setter : PixelSetter,
) -> Unit {
  let n = points.length()
  if n < 2 {
    return
  }
  for i = 0; i < n; i = i + 1 {
    let j = (i + 1) % n
    let (x1, y1) = points[i]
    let (x2, y2) = points[j]
    raster_line(x1, y1, x2, y2, color, setter)
  }
}

///|
/// Draw polyline (open polygon)
pub fn raster_polyline(
  points : Array[(Int, Int)],
  color : Color,
  setter : PixelSetter,
) -> Unit {
  let n = points.length()
  if n < 2 {
    return
  }
  for i = 0; i < n - 1; i = i + 1 {
    let (x1, y1) = points[i]
    let (x2, y2) = points[i + 1]
    raster_line(x1, y1, x2, y2, color, setter)
  }
}

///|
/// Helper: min of two ints
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Helper: simple insertion sort for small arrays
fn sort_ints(arr : Array[Int]) -> Unit {
  let n = arr.length()
  for i = 1; i < n; i = i + 1 {
    let key = arr[i]
    let mut j = i - 1
    while j >= 0 && arr[j] > key {
      arr[j + 1] = arr[j]
      j = j - 1
    }
    arr[j + 1] = key
  }
}

///|
/// Draw a thick line (stroke width > 1)
pub fn raster_thick_line(
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  width : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  if width <= 1 {
    raster_line(x0, y0, x1, y1, color, setter)
    return
  }
  // For thick lines, draw multiple parallel lines
  let half_w = width / 2
  let dx = x1 - x0
  let dy = y1 - y0
  let len = (dx * dx + dy * dy).to_double().sqrt()
  if len < 0.001 {
    // Point - draw filled circle
    raster_circle_fill(x0, y0, half_w, color, setter)
    return
  }
  // Perpendicular direction
  let px = (-dy.to_double() / len * half_w.to_double()).to_int()
  let py = (dx.to_double() / len * half_w.to_double()).to_int()
  // Draw as polygon
  let points : Array[(Int, Int)] = [
    (x0 + px, y0 + py),
    (x1 + px, y1 + py),
    (x1 - px, y1 - py),
    (x0 - px, y0 - py),
  ]
  raster_polygon_fill(points, color, setter)
}

///|
/// Simple 5x7 bitmap font for ASCII characters
/// Each character is represented as 7 bytes (rows), each byte has 5 bits (columns)
/// Bit 0x10 = leftmost pixel, 0x01 = rightmost pixel
fn get_char_bitmap(c : Char) -> Array[Int] {
  match c {
    ' ' => [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    '!' => [0x04, 0x04, 0x04, 0x04, 0x04, 0x00, 0x04]
    '"' => [0x0A, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00]
    '#' => [0x0A, 0x1F, 0x0A, 0x0A, 0x1F, 0x0A, 0x00]
    '$' => [0x04, 0x0F, 0x14, 0x0E, 0x05, 0x1E, 0x04]
    '%' => [0x18, 0x19, 0x02, 0x04, 0x08, 0x13, 0x03]
    '&' => [0x08, 0x14, 0x14, 0x08, 0x15, 0x12, 0x0D]
    '\'' => [0x04, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00]
    '(' => [0x02, 0x04, 0x08, 0x08, 0x08, 0x04, 0x02]
    ')' => [0x08, 0x04, 0x02, 0x02, 0x02, 0x04, 0x08]
    '*' => [0x04, 0x15, 0x0E, 0x1F, 0x0E, 0x15, 0x04]
    '+' => [0x00, 0x04, 0x04, 0x1F, 0x04, 0x04, 0x00]
    ',' => [0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x08]
    '-' => [0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00]
    '.' => [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04]
    '/' => [0x01, 0x02, 0x02, 0x04, 0x08, 0x08, 0x10]
    '0' => [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E]
    '1' => [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E]
    '2' => [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F]
    '3' => [0x0E, 0x11, 0x01, 0x06, 0x01, 0x11, 0x0E]
    '4' => [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02]
    '5' => [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E]
    '6' => [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E]
    '7' => [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08]
    '8' => [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E]
    '9' => [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C]
    ':' => [0x00, 0x00, 0x04, 0x00, 0x00, 0x04, 0x00]
    ';' => [0x00, 0x00, 0x04, 0x00, 0x00, 0x04, 0x08]
    '<' => [0x02, 0x04, 0x08, 0x10, 0x08, 0x04, 0x02]
    '=' => [0x00, 0x00, 0x1F, 0x00, 0x1F, 0x00, 0x00]
    '>' => [0x08, 0x04, 0x02, 0x01, 0x02, 0x04, 0x08]
    '?' => [0x0E, 0x11, 0x01, 0x02, 0x04, 0x00, 0x04]
    '@' => [0x0E, 0x11, 0x17, 0x15, 0x17, 0x10, 0x0E]
    'A' => [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11]
    'B' => [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E]
    'C' => [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E]
    'D' => [0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E]
    'E' => [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F]
    'F' => [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10]
    'G' => [0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0E]
    'H' => [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11]
    'I' => [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E]
    'J' => [0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C]
    'K' => [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11]
    'L' => [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F]
    'M' => [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11]
    'N' => [0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11]
    'O' => [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E]
    'P' => [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10]
    'Q' => [0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D]
    'R' => [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11]
    'S' => [0x0E, 0x11, 0x10, 0x0E, 0x01, 0x11, 0x0E]
    'T' => [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04]
    'U' => [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E]
    'V' => [0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04]
    'W' => [0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11]
    'X' => [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11]
    'Y' => [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04]
    'Z' => [0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F]
    '[' => [0x0E, 0x08, 0x08, 0x08, 0x08, 0x08, 0x0E]
    '\\' => [0x10, 0x08, 0x08, 0x04, 0x02, 0x02, 0x01]
    ']' => [0x0E, 0x02, 0x02, 0x02, 0x02, 0x02, 0x0E]
    '^' => [0x04, 0x0A, 0x11, 0x00, 0x00, 0x00, 0x00]
    '_' => [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1F]
    '`' => [0x08, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00]
    'a' => [0x00, 0x00, 0x0E, 0x01, 0x0F, 0x11, 0x0F]
    'b' => [0x10, 0x10, 0x1E, 0x11, 0x11, 0x11, 0x1E]
    'c' => [0x00, 0x00, 0x0E, 0x10, 0x10, 0x10, 0x0E]
    'd' => [0x01, 0x01, 0x0F, 0x11, 0x11, 0x11, 0x0F]
    'e' => [0x00, 0x00, 0x0E, 0x11, 0x1F, 0x10, 0x0E]
    'f' => [0x06, 0x08, 0x08, 0x1E, 0x08, 0x08, 0x08]
    'g' => [0x00, 0x00, 0x0F, 0x11, 0x0F, 0x01, 0x0E]
    'h' => [0x10, 0x10, 0x1E, 0x11, 0x11, 0x11, 0x11]
    'i' => [0x04, 0x00, 0x0C, 0x04, 0x04, 0x04, 0x0E]
    'j' => [0x02, 0x00, 0x06, 0x02, 0x02, 0x12, 0x0C]
    'k' => [0x10, 0x10, 0x12, 0x14, 0x18, 0x14, 0x12]
    'l' => [0x0C, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E]
    'm' => [0x00, 0x00, 0x1A, 0x15, 0x15, 0x11, 0x11]
    'n' => [0x00, 0x00, 0x1E, 0x11, 0x11, 0x11, 0x11]
    'o' => [0x00, 0x00, 0x0E, 0x11, 0x11, 0x11, 0x0E]
    'p' => [0x00, 0x00, 0x1E, 0x11, 0x1E, 0x10, 0x10]
    'q' => [0x00, 0x00, 0x0F, 0x11, 0x0F, 0x01, 0x01]
    'r' => [0x00, 0x00, 0x16, 0x19, 0x10, 0x10, 0x10]
    's' => [0x00, 0x00, 0x0E, 0x10, 0x0E, 0x01, 0x1E]
    't' => [0x08, 0x08, 0x1E, 0x08, 0x08, 0x09, 0x06]
    'u' => [0x00, 0x00, 0x11, 0x11, 0x11, 0x11, 0x0E]
    'v' => [0x00, 0x00, 0x11, 0x11, 0x11, 0x0A, 0x04]
    'w' => [0x00, 0x00, 0x11, 0x11, 0x15, 0x15, 0x0A]
    'x' => [0x00, 0x00, 0x11, 0x0A, 0x04, 0x0A, 0x11]
    'y' => [0x00, 0x00, 0x11, 0x11, 0x0F, 0x01, 0x0E]
    'z' => [0x00, 0x00, 0x1F, 0x02, 0x04, 0x08, 0x1F]
    '{' => [0x02, 0x04, 0x04, 0x08, 0x04, 0x04, 0x02]
    '|' => [0x04, 0x04, 0x04, 0x00, 0x04, 0x04, 0x04]
    '}' => [0x08, 0x04, 0x04, 0x02, 0x04, 0x04, 0x08]
    '~' => [0x00, 0x08, 0x15, 0x02, 0x00, 0x00, 0x00]
    _ => [0x1F, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1F] // Default: box
  }
}

///|
/// Render text using bitmap font
pub fn raster_text(
  x : Int,
  y : Int,
  text : String,
  font_size : Int,
  color : Color,
  setter : PixelSetter,
) -> Unit {
  // Base font is 5x7 pixels
  // Scale factor based on font_size (base is 7 pixels high)
  let scale = if font_size <= 7 { 1 } else { font_size / 7 }
  let char_width = 5 * scale
  let char_height = 7 * scale
  let spacing = scale // Space between characters
  let mut cursor_x = x
  // y is the baseline, so move up by font height
  let start_y = y - char_height
  for i = 0; i < text.length(); i = i + 1 {
    let c = text[i].unsafe_to_char()
    let bitmap = get_char_bitmap(c)
    // Draw the character
    for row = 0; row < 7; row = row + 1 {
      let row_bits = bitmap[row]
      for col = 0; col < 5; col = col + 1 {
        // Check if bit is set (MSB is left side)
        let bit_mask = 0x10 >> col
        if (row_bits & bit_mask) != 0 {
          // Draw scaled pixel
          for sy = 0; sy < scale; sy = sy + 1 {
            for sx = 0; sx < scale; sx = sx + 1 {
              let px = cursor_x + col * scale + sx
              let py = start_y + row * scale + sy
              setter.pixel(px, py, color)
            }
          }
        }
      }
    }
    cursor_x = cursor_x + char_width + spacing
  }
}
