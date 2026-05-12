///|
/// Point-in-shape predicates for TUI hit testing.

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
