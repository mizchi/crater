///|
/// TUI hit-test shape resolution and predicates.

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

///|
fn point_in_rounded_corner(
  pixel_x : Double,
  pixel_y : Double,
  center_x : Double,
  center_y : Double,
  radius : Double,
) -> Bool {
  let dx = pixel_x - center_x
  let dy = pixel_y - center_y
  dx * dx + dy * dy <= radius * radius
}

///|
fn point_in_rounded_rect(
  pixel_x : Double,
  pixel_y : Double,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius_top_left : Double,
  radius_top_right : Double,
  radius_bottom_right : Double,
  radius_bottom_left : Double,
) -> Bool {
  if pixel_x < x || pixel_x >= x + width || pixel_y < y || pixel_y >= y + height {
    return false
  }
  if radius_top_left > 0.0 &&
    pixel_x < x + radius_top_left &&
    pixel_y < y + radius_top_left {
    return point_in_rounded_corner(
      pixel_x,
      pixel_y,
      x + radius_top_left,
      y + radius_top_left,
      radius_top_left,
    )
  }
  if radius_top_right > 0.0 &&
    pixel_x >= x + width - radius_top_right &&
    pixel_y < y + radius_top_right {
    return point_in_rounded_corner(
      pixel_x,
      pixel_y,
      x + width - radius_top_right,
      y + radius_top_right,
      radius_top_right,
    )
  }
  if radius_bottom_right > 0.0 &&
    pixel_x >= x + width - radius_bottom_right &&
    pixel_y >= y + height - radius_bottom_right {
    return point_in_rounded_corner(
      pixel_x,
      pixel_y,
      x + width - radius_bottom_right,
      y + height - radius_bottom_right,
      radius_bottom_right,
    )
  }
  if radius_bottom_left > 0.0 &&
    pixel_x < x + radius_bottom_left &&
    pixel_y >= y + height - radius_bottom_left {
    return point_in_rounded_corner(
      pixel_x,
      pixel_y,
      x + radius_bottom_left,
      y + height - radius_bottom_left,
      radius_bottom_left,
    )
  }
  true
}

///|
fn point_in_hit_clip_shape(
  pixel_x : Double,
  pixel_y : Double,
  shape : HitClipShape,
) -> Bool {
  match shape {
    Rect => true
    Circle(cx, cy, r) => {
      let dx = pixel_x - cx
      let dy = pixel_y - cy
      dx * dx + dy * dy <= r * r
    }
    Ellipse(cx, cy, rx, ry) =>
      if rx <= 0.0 || ry <= 0.0 {
        false
      } else {
        let dx = pixel_x - cx
        let dy = pixel_y - cy
        dx * dx / (rx * rx) + dy * dy / (ry * ry) <= 1.0
      }
    Polygon(points) => point_in_polygon(pixel_x, pixel_y, points)
  }
}

///|
fn point_in_polygon(
  pixel_x : Double,
  pixel_y : Double,
  points : Array[(Double, Double)],
) -> Bool {
  if points.length() < 3 {
    return false
  }
  let mut inside = false
  let mut j = points.length() - 1
  for i in 0..<points.length() {
    let (xi, yi) = points[i]
    let (xj, yj) = points[j]
    if (yi > pixel_y) != (yj > pixel_y) {
      let intersect_x = (xj - xi) * (pixel_y - yi) / (yj - yi) + xi
      if pixel_x < intersect_x {
        inside = !inside
      }
    }
    j = i
  }
  inside
}

///|
fn HitRegion::contains_pixel(
  self : HitRegion,
  pixel_x : Double,
  pixel_y : Double,
) -> Bool {
  pixel_x >= self.pixel_x &&
  pixel_x < self.pixel_x + self.pixel_width &&
  pixel_y >= self.pixel_y &&
  pixel_y < self.pixel_y + self.pixel_height &&
  point_in_rounded_rect(
    pixel_x,
    pixel_y,
    self.shape_x,
    self.shape_y,
    self.shape_width,
    self.shape_height,
    self.radius_top_left,
    self.radius_top_right,
    self.radius_bottom_right,
    self.radius_bottom_left,
  ) &&
  point_in_hit_clip_shape(pixel_x, pixel_y, self.visual_shape) &&
  point_in_hit_clip_shape(pixel_x, pixel_y, self.clip_shape)
}

///|
fn HitRegion::has_cell_coverage(self : HitRegion, col : Int, row : Int) -> Bool {
  if !self.allows_cell_coverage_sampling() {
    return false
  }
  let cell_x = col.to_double() * font_width
  let cell_y = (row + self.scroll_y).to_double() * font_height
  let overlap_left = max_double(cell_x, self.pixel_x)
  let overlap_top = max_double(cell_y, self.pixel_y)
  let overlap_right = min_double(
    cell_x + font_width,
    self.pixel_x + self.pixel_width,
  )
  let overlap_bottom = min_double(
    cell_y + font_height,
    self.pixel_y + self.pixel_height,
  )
  if overlap_right <= overlap_left || overlap_bottom <= overlap_top {
    return false
  }
  let samples_per_axis = 4
  let required_hits = 4
  let step_x = font_width / samples_per_axis.to_double()
  let step_y = font_height / samples_per_axis.to_double()
  let mut hits = 0
  for y in 0..<samples_per_axis {
    let sample_y = cell_y + (y.to_double() + 0.5) * step_y
    for x in 0..<samples_per_axis {
      let sample_x = cell_x + (x.to_double() + 0.5) * step_x
      if self.contains_pixel(sample_x, sample_y) {
        hits += 1
        if hits >= required_hits {
          return true
        }
      }
    }
  }
  false
}

///|
fn HitRegion::allows_cell_coverage_sampling(self : HitRegion) -> Bool {
  self.radius_top_left == 0.0 &&
  self.radius_top_right == 0.0 &&
  self.radius_bottom_right == 0.0 &&
  self.radius_bottom_left == 0.0 &&
  self.visual_shape == HitClipShape::Rect
}

///|
pub fn HitRegion::contains(self : HitRegion, col : Int, row : Int) -> Bool {
  let pixel_x = col.to_double() * font_width + font_width / 2.0
  let pixel_y = (row + self.scroll_y).to_double() * font_height +
    font_height / 2.0
  if self.contains_pixel(pixel_x, pixel_y) {
    return true
  }
  self.has_cell_coverage(col, row)
}
