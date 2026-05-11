///|
/// Rounded rectangle scanline helpers for raster output.

///|
/// Compute coverage (0.0-1.0) for a pixel near a rounded corner boundary.
/// Returns 1.0 if fully inside, 0.0 if fully outside, fractional at the edge.
fn rounded_corner_coverage(
  px : Int,
  py : Int,
  rect_x : Int,
  rect_y : Int,
  rect_w : Int,
  rect_h : Int,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Double {
  let lx = px - rect_x
  let ly = py - rect_y
  // Check each corner; if pixel is not in any corner zone, fully inside
  // Top-left corner
  if tl > 0 && lx < tl && ly < tl {
    let dx = (tl - lx).to_double() - 0.5
    let dy = (tl - ly).to_double() - 0.5
    let dist = (dx * dx + dy * dy).sqrt()
    let r = tl.to_double()
    if dist >= r + 0.5 {
      return 0.0
    }
    if dist <= r - 0.5 {
      return 1.0
    }
    return r + 0.5 - dist
  }
  // Top-right corner
  if tr > 0 && lx >= rect_w - tr && ly < tr {
    let dx = (lx - (rect_w - tr - 1)).to_double() - 0.5
    let dy = (tr - ly).to_double() - 0.5
    let dist = (dx * dx + dy * dy).sqrt()
    let r = tr.to_double()
    if dist >= r + 0.5 {
      return 0.0
    }
    if dist <= r - 0.5 {
      return 1.0
    }
    return r + 0.5 - dist
  }
  // Bottom-right corner
  if br > 0 && lx >= rect_w - br && ly >= rect_h - br {
    let dx = (lx - (rect_w - br - 1)).to_double() - 0.5
    let dy = (ly - (rect_h - br - 1)).to_double() - 0.5
    let dist = (dx * dx + dy * dy).sqrt()
    let r = br.to_double()
    if dist >= r + 0.5 {
      return 0.0
    }
    if dist <= r - 0.5 {
      return 1.0
    }
    return r + 0.5 - dist
  }
  // Bottom-left corner
  if bl > 0 && lx < bl && ly >= rect_h - bl {
    let dx = (bl - lx).to_double() - 0.5
    let dy = (ly - (rect_h - bl - 1)).to_double() - 0.5
    let dist = (dx * dx + dy * dy).sqrt()
    let r = bl.to_double()
    if dist >= r + 0.5 {
      return 0.0
    }
    if dist <= r - 0.5 {
      return 1.0
    }
    return r + 0.5 - dist
  }
  1.0
}

///|
fn fill_rounded_corner_pixels_fast(
  fb : Framebuffer,
  palette : DynamicPalette,
  rect_x : Int,
  rect_y : Int,
  rect_w : Int,
  rect_h : Int,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  idx : Int,
  src : Color,
  alpha : Int,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
  corner_x : Int,
  corner_y : Int,
  radius : Int,
) -> Unit {
  if radius <= 0 {
    return
  }
  let cx1 = @cmp.maximum(corner_x, x1)
  let cy1 = @cmp.maximum(corner_y, y1)
  let cx2 = @cmp.minimum(corner_x + radius, x2)
  let cy2 = @cmp.minimum(corner_y + radius, y2)
  if cx2 <= cx1 || cy2 <= cy1 {
    return
  }
  for py = cy1; py < cy2; py = py + 1 {
    for px = cx1; px < cx2; px = px + 1 {
      let cov = rounded_corner_coverage(
        px, py, rect_x, rect_y, rect_w, rect_h, tl, tr, br, bl,
      )
      if cov >= 1.0 {
        if alpha >= 255 {
          fb.set_pixel(px, py, idx)
        } else {
          blend_raster_color_over_pixel(fb, palette, px, py, src, alpha)
        }
      } else if cov > 0.0 {
        blend_raster_color_over_pixel(
          fb,
          palette,
          px,
          py,
          src,
          (cov * alpha.to_double()).to_int(),
        )
      }
    }
  }
}

///|
fn fill_rounded_rect_fast(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  src : Color,
  alpha : Int,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Unit {
  let idx = palette.get_or_add(src)
  let cache = Array::make(palette.colors.length(), -1)
  for py = y1; py < y2; py = py + 1 {
    let mut row_x1 = x
    let mut row_x2 = x + w
    if tl > 0 && py < y + tl {
      row_x1 = @cmp.maximum(row_x1, x + tl)
    }
    if bl > 0 && py >= y + h - bl {
      row_x1 = @cmp.maximum(row_x1, x + bl)
    }
    if tr > 0 && py < y + tr {
      row_x2 = @cmp.minimum(row_x2, x + w - tr)
    }
    if br > 0 && py >= y + h - br {
      row_x2 = @cmp.minimum(row_x2, x + w - br)
    }
    let cx1 = @cmp.maximum(row_x1, x1)
    let cx2 = @cmp.minimum(row_x2, x2)
    if cx2 > cx1 {
      if alpha >= 255 {
        fb.fill_span(py, cx1, cx2, idx)
      } else {
        blend_span_with_raster_color(
          fb, palette, py, cx1, cx2, src, alpha, cache,
        )
      }
    }
  }
  fill_rounded_corner_pixels_fast(
    fb, palette, x, y, w, h, x1, y1, x2, y2, idx, src, alpha, tl, tr, br, bl, x,
    y, tl,
  )
  fill_rounded_corner_pixels_fast(
    fb,
    palette,
    x,
    y,
    w,
    h,
    x1,
    y1,
    x2,
    y2,
    idx,
    src,
    alpha,
    tl,
    tr,
    br,
    bl,
    x + w - tr,
    y,
    tr,
  )
  fill_rounded_corner_pixels_fast(
    fb,
    palette,
    x,
    y,
    w,
    h,
    x1,
    y1,
    x2,
    y2,
    idx,
    src,
    alpha,
    tl,
    tr,
    br,
    bl,
    x + w - br,
    y + h - br,
    br,
  )
  fill_rounded_corner_pixels_fast(
    fb,
    palette,
    x,
    y,
    w,
    h,
    x1,
    y1,
    x2,
    y2,
    idx,
    src,
    alpha,
    tl,
    tr,
    br,
    bl,
    x,
    y + h - bl,
    bl,
  )
}

///|
/// Fill a rounded rect (with optional clip)
fn fill_rounded_rect_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Unit {
  let alpha = effective_alpha_byte(color, opacity)
  if alpha <= 0 {
    return
  }
  let src = types_color_to_image(color)
  // Determine draw bounds (intersect with clip)
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
  if has_radius {
    fill_rounded_rect_fast(
      fb, palette, x, y, w, h, x1, y1, x2, y2, src, alpha, tl, tr, br, bl,
    )
  } else if alpha >= 255 {
    let idx = palette.get_or_add(src)
    for py = y1; py < y2; py = py + 1 {
      fb.fill_span(py, x1, x2, idx)
    }
  } else {
    let cache = Array::make(palette.colors.length(), -1)
    for py = y1; py < y2; py = py + 1 {
      blend_span_with_raster_color(fb, palette, py, x1, x2, src, alpha, cache)
    }
  }
}
