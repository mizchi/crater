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
