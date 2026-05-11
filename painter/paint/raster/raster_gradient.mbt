///|
/// Linear gradient sampling and raster fill helpers.

///|
/// Interpolate between two colors at position t (0.0-1.0)
fn lerp_color(a : @types.Color, b : @types.Color, t : Double) -> @types.Color {
  let r = (a.r.to_double() * (1.0 - t) + b.r.to_double() * t).to_int()
  let g = (a.g.to_double() * (1.0 - t) + b.g.to_double() * t).to_int()
  let b_val = (a.b.to_double() * (1.0 - t) + b.b.to_double() * t).to_int()
  let alpha = a.a * (1.0 - t) + b.a * t
  @types.Color::rgba(clamp_byte(r), clamp_byte(g), clamp_byte(b_val), alpha)
}

///|
/// Sample a gradient at position t (0.0-1.0)
fn sample_gradient(grad : @types.LinearGradient, t : Double) -> @types.Color {
  let stops = grad.stops
  if stops.length() == 0 {
    return @types.Color::transparent()
  }
  if t <= stops[0].position {
    return stops[0].color
  }
  let last = stops.length() - 1
  if t >= stops[last].position {
    return stops[last].color
  }
  // Find the two stops that bracket t
  for i = 0; i < last; i = i + 1 {
    if t >= stops[i].position && t <= stops[i + 1].position {
      let range = stops[i + 1].position - stops[i].position
      let local_t = if range > 0.0 {
        (t - stops[i].position) / range
      } else {
        0.0
      }
      return lerp_color(stops[i].color, stops[i + 1].color, local_t)
    }
  }
  stops[last].color
}

///|
/// Fill a rect with a linear gradient (with optional clip and border-radius)
fn fill_linear_gradient_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  grad : @types.LinearGradient,
  opacity : Double,
  clip : ClipRect?,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Unit {
  // Determine draw bounds
  let x1 = match clip {
    Some(c) => @cmp.maximum(x, c.x)
    None => x
  }
  let y1 = match clip {
    Some(c) => @cmp.maximum(y, c.y)
    None => y
  }
  let x2 = match clip {
    Some(c) => @cmp.minimum(x + w, c.x + c.w)
    None => x + w
  }
  let y2 = match clip {
    Some(c) => @cmp.minimum(y + h, c.y + c.h)
    None => y + h
  }
  if x2 <= x1 || y2 <= y1 {
    return
  }
  let has_radius = tl > 0 || tr > 0 || br > 0 || bl > 0
  // Convert angle to direction vector
  // CSS gradient angles: 0deg = to top, 90deg = to right, 180deg = to bottom
  let pi = 3.14159265358979
  let rad = (grad.angle_deg - 90.0) * pi / 180.0
  let dx = @math.cos(rad)
  let dy = @math.sin(rad)
  // Project rect corners onto gradient line to find the extent
  let cx = w.to_double() / 2.0
  let cy = h.to_double() / 2.0
  let half_len = (cx * dx.abs() + cy * dy.abs()).abs()
  let inv_len = if half_len > 0.001 { 1.0 / (2.0 * half_len) } else { 0.0 }
  for py = y1; py < y2; py = py + 1 {
    let fy = (py - y).to_double() - cy
    for px = x1; px < x2; px = px + 1 {
      let cov = if has_radius {
        rounded_corner_coverage(px, py, x, y, w, h, tl, tr, br, bl)
      } else {
        1.0
      }
      if cov <= 0.0 {
        continue
      }
      let fx = (px - x).to_double() - cx
      let proj = fx * dx + fy * dy
      let t = (proj + half_len) * inv_len
      // Clamp t
      let tc = if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
      let color = sample_gradient(grad, tc)
      if color.a > 0.0 {
        let effective_opacity = opacity * cov
        if effective_opacity >= 1.0 && color.a >= 1.0 {
          let idx = palette.get_or_add(types_color_to_image(color))
          fb.set_pixel(px, py, idx)
        } else {
          blend_types_color_over_pixel(
            fb, palette, px, py, color, effective_opacity,
          )
        }
      }
    }
  }
}
