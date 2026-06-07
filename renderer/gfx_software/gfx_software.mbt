///|
/// A CPU software-rasterizer `GraphicsDriver` backend for `mizchi/gfx`.
///
/// gfx's built-in WebGL / WebGPU / native drivers are thin stubs that
/// forward `DrawTrianglesCommand`s to externally-registered platform hooks,
/// so they cannot produce verifiable pixels on their own. This driver
/// instead executes the command stream directly into an in-memory RGBA
/// framebuffer, which makes the full pipeline (paint tree -> gfx commands
/// -> driver -> pixels) testable end-to-end without a GPU.
///
/// It implements the `@gfx.GraphicsDriver` contract, so any code written
/// against gfx (including crater's `gfx_bridge` assembler) can target it
/// unchanged. The framebuffer layout matches gfx's `read_pixels` /
/// `FramebufferSnapshot` convention: row-major, four 0..255 channels
/// (r, g, b, a) per pixel.

///|
pub struct SoftwareDriver {
  mut width : Int
  mut height : Int
  mut pixels : Array[Int]
  mut next_id : Int
  mut initialized : Bool
}

///|
pub fn SoftwareDriver::new(width : Int, height : Int) -> SoftwareDriver {
  let w = if width <= 0 { 1 } else { width }
  let h = if height <= 0 { 1 } else { height }
  {
    width: w,
    height: h,
    pixels: Array::make(w * h * 4, 0),
    next_id: 0,
    initialized: false,
  }
}

///|
/// Read back a single pixel as (r, g, b, a). Out-of-bounds reads return
/// transparent black. Intended for tests / debugging.
pub fn SoftwareDriver::pixel_at(
  self : SoftwareDriver,
  x : Int,
  y : Int,
) -> (Int, Int, Int, Int) {
  if x < 0 || y < 0 || x >= self.width || y >= self.height {
    return (0, 0, 0, 0)
  }
  let base = (y * self.width + x) * 4
  (
    self.pixels[base],
    self.pixels[base + 1],
    self.pixels[base + 2],
    self.pixels[base + 3],
  )
}

///|
fn channel_u8(value : Double) -> Int {
  let v = (value * 255.0).to_int()
  if v < 0 {
    0
  } else if v > 255 {
    255
  } else {
    v
  }
}

///|
fn SoftwareDriver::clear(self : SoftwareDriver, color : @gfx.Color) -> Unit {
  let r = channel_u8(color.r)
  let g = channel_u8(color.g)
  let b = channel_u8(color.b)
  let a = channel_u8(color.a)
  let count = self.width * self.height
  for i in 0..<count {
    let base = i * 4
    self.pixels[base] = r
    self.pixels[base + 1] = g
    self.pixels[base + 2] = b
    self.pixels[base + 3] = a
  }
}

///|
/// Blend a source rgba (0..255) over the destination pixel at (x, y).
fn SoftwareDriver::blend_pixel(
  self : SoftwareDriver,
  x : Int,
  y : Int,
  sr : Int,
  sg : Int,
  sb : Int,
  sa : Int,
  blend : @gfx.BlendMode,
) -> Unit {
  if x < 0 || y < 0 || x >= self.width || y >= self.height {
    return
  }
  let base = (y * self.width + x) * 4
  match blend {
    @gfx.BlendMode::Copy => {
      self.pixels[base] = sr
      self.pixels[base + 1] = sg
      self.pixels[base + 2] = sb
      self.pixels[base + 3] = sa
    }
    // Everything else falls back to straight source-over alpha blending,
    // which is sufficient for crater's solid fills, borders and text ink.
    _ => {
      let a = sa.to_double() / 255.0
      let inv = 1.0 - a
      let dr = self.pixels[base].to_double()
      let dg = self.pixels[base + 1].to_double()
      let db = self.pixels[base + 2].to_double()
      let da = self.pixels[base + 3].to_double()
      self.pixels[base] = (sr.to_double() * a + dr * inv).to_int()
      self.pixels[base + 1] = (sg.to_double() * a + dg * inv).to_int()
      self.pixels[base + 2] = (sb.to_double() * a + db * inv).to_int()
      self.pixels[base + 3] = (sa.to_double() + da * inv).to_int()
    }
  }
}

///|
fn ndc_x_to_pixel(ndc_x : Double, width : Int) -> Double {
  (ndc_x + 1.0) * 0.5 * width.to_double()
}

///|
fn ndc_y_to_pixel(ndc_y : Double, height : Int) -> Double {
  (1.0 - ndc_y) * 0.5 * height.to_double()
}

///|
fn edge_function(
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
  cx : Double,
  cy : Double,
) -> Double {
  (cx - ax) * (by - ay) - (cy - ay) * (bx - ax)
}

///|
/// Whether the directed edge a -> b is a top or left edge for a
/// winding-normalized (interior w >= 0) triangle. A shared edge is
/// traversed in opposite directions by the two adjacent triangles, so
/// exactly one of them sees it as top-left.
fn edge_is_top_left(ax : Double, ay : Double, bx : Double, by : Double) -> Bool {
  let dx = bx - ax
  let dy = by - ay
  dy > 0.0 || (dy == 0.0 && dx < 0.0)
}

///|
/// Coverage test for one edge: strictly inside, or exactly on a top-left
/// edge (the half-open fill rule).
fn edge_ok(w : Double, top_left : Bool) -> Bool {
  w > 0.0 || (w == 0.0 && top_left)
}

///|
/// Anti-aliased coverage (0..1) of a pixel center against a rounded
/// rectangle's corner arcs, from the shape uniforms
/// `[_, _, _, _, rx_tl, ry_tl, rx_tr, ry_tr, rx_br, ry_br, rx_bl, ry_bl, x, y, w, h]`.
/// Pixels outside any corner region have full coverage; inside a corner,
/// coverage falls off over a ~1px band along the (elliptical) arc, matching a
/// signed-distance edge.
fn rounded_corner_coverage(
  pcx : Double,
  pcy : Double,
  u : Array[Int],
) -> Double {
  let rx_tl = u[4].to_double()
  let ry_tl = u[5].to_double()
  let rx_tr = u[6].to_double()
  let ry_tr = u[7].to_double()
  let rx_br = u[8].to_double()
  let ry_br = u[9].to_double()
  let rx_bl = u[10].to_double()
  let ry_bl = u[11].to_double()
  let x = u[12].to_double()
  let y = u[13].to_double()
  let w = u[14].to_double()
  let h = u[15].to_double()
  // Coverage of an axis-aligned elliptical corner centered at (cx, cy) with
  // radii (rx, ry): approximate the signed distance to the ellipse boundary
  // (positive inside) as -f / |grad f| for f = (dx/rx)^2 + (dy/ry)^2 - 1, then
  // soften over a 1px band. Reduces to the circular `r - dist` case when
  // rx == ry.
  fn cov(cx : Double, cy : Double, rx : Double, ry : Double) -> Double {
    let dx = pcx - cx
    let dy = pcy - cy
    let c = if (rx - ry).abs() < 0.001 {
      // Circular corner: exact distance to the arc.
      rx - (dx * dx + dy * dy).sqrt() + 0.5
    } else {
      // Elliptical corner: approximate signed distance to the boundary.
      let nx = dx / rx
      let ny = dy / ry
      let gx = dx / (rx * rx)
      let gy = dy / (ry * ry)
      let glen = 2.0 * (gx * gx + gy * gy).sqrt()
      if glen < 0.000001 {
        return 1.0
      }
      (1.0 - (nx * nx + ny * ny)) / glen + 0.5
    }
    if c < 0.0 {
      0.0
    } else if c > 1.0 {
      1.0
    } else {
      c
    }
  }

  if rx_tl > 0.0 && ry_tl > 0.0 && pcx < x + rx_tl && pcy < y + ry_tl {
    return cov(x + rx_tl, y + ry_tl, rx_tl, ry_tl)
  }
  if rx_tr > 0.0 && ry_tr > 0.0 && pcx > x + w - rx_tr && pcy < y + ry_tr {
    return cov(x + w - rx_tr, y + ry_tr, rx_tr, ry_tr)
  }
  if rx_br > 0.0 && ry_br > 0.0 && pcx > x + w - rx_br && pcy > y + h - ry_br {
    return cov(x + w - rx_br, y + h - ry_br, rx_br, ry_br)
  }
  if rx_bl > 0.0 && ry_bl > 0.0 && pcx < x + rx_bl && pcy > y + h - ry_bl {
    return cov(x + rx_bl, y + h - ry_bl, rx_bl, ry_bl)
  }
  1.0
}

///|
fn fmin3(a : Double, b : Double, c : Double) -> Double {
  let ab = if a < b { a } else { b }
  if ab < c {
    ab
  } else {
    c
  }
}

///|
fn fmax3(a : Double, b : Double, c : Double) -> Double {
  let ab = if a > b { a } else { b }
  if ab > c {
    ab
  } else {
    c
  }
}

///|
fn clamp_int(value : Int, lo : Int, hi : Int) -> Int {
  if value < lo {
    lo
  } else if value > hi {
    hi
  } else {
    value
  }
}

///|
/// Smallest integer >= v (for v >= 0, the pixel-space domain here).
fn ceil_to_int(v : Double) -> Int {
  let truncated = v.to_int()
  if truncated.to_double() < v {
    truncated + 1
  } else {
    truncated
  }
}

///|
/// Rasterize one draw command into the framebuffer. Vertices are
/// interleaved (x, y, u, v) in NDC; the fill color is read from the
/// command's uniform dwords (four 0..255 channels). Textured commands fall
/// back to the uniform color (used here as a tint).
fn SoftwareDriver::rasterize(
  self : SoftwareDriver,
  command : @gfx.DrawTrianglesCommand,
) -> Unit {
  let verts = command.vertex_data
  let indices = command.indices
  let u = command.uniform_dwords
  let sr = if u.length() > 0 { u[0] } else { 0 }
  let sg = if u.length() > 1 { u[1] } else { 0 }
  let sb = if u.length() > 2 { u[2] } else { 0 }
  let sa = if u.length() > 3 { u[3] } else { 255 }
  // Optional rounded-rect shape uniforms (packed after the color):
  //   [r,g,b,a, rx_tl,ry_tl, rx_tr,ry_tr, rx_br,ry_br, rx_bl,ry_bl, x,y,w,h]
  let rounded = u.length() >= 16 &&
    (
      u[4] > 0 ||
      u[5] > 0 ||
      u[6] > 0 ||
      u[7] > 0 ||
      u[8] > 0 ||
      u[9] > 0 ||
      u[10] > 0 ||
      u[11] > 0
    )
  // Scissor: honor the command's destination region as a clip rectangle.
  let (scissor_x0, scissor_y0, scissor_x1, scissor_y1) = if command.dst_regions.length() >
    0 {
    let r = command.dst_regions[0]
    (r.x, r.y, r.x + r.width, r.y + r.height)
  } else {
    (0, 0, self.width, self.height)
  }
  let stride = 4
  // Fast path: a single axis-aligned rectangle (the common case for
  // backgrounds, borders, gradient strips, and rounded boxes) covers a
  // contiguous pixel span, so the per-pixel edge-function test is pure
  // overhead. Detect it and fill the span directly. For rounded rects only the
  // top/bottom corner-radius row bands need per-pixel coverage; the middle
  // rows are fully covered. Bit-identical to the general path (same
  // pixel-center + top-left fill rule).
  if indices.length() == 6 {
    // bbox over the referenced vertices, in pixel space
    let p0x = ndc_x_to_pixel(verts[indices[0] * stride], self.width)
    let p0y = ndc_y_to_pixel(verts[indices[0] * stride + 1], self.height)
    let mut rminx = p0x
    let mut rmaxx = p0x
    let mut rminy = p0y
    let mut rmaxy = p0y
    for k in 1..<indices.length() {
      let vi = indices[k]
      let vx = ndc_x_to_pixel(verts[vi * stride], self.width)
      let vy = ndc_y_to_pixel(verts[vi * stride + 1], self.height)
      if vx < rminx {
        rminx = vx
      }
      if vx > rmaxx {
        rmaxx = vx
      }
      if vy < rminy {
        rminy = vy
      }
      if vy > rmaxy {
        rmaxy = vy
      }
    }
    // Axis-aligned iff every referenced vertex sits on a bbox corner.
    let eps = 0.0001
    let mut axis_aligned = rmaxx - rminx > eps && rmaxy - rminy > eps
    if axis_aligned {
      for k in 0..<indices.length() {
        let vi = indices[k]
        let vx = ndc_x_to_pixel(verts[vi * stride], self.width)
        let vy = ndc_y_to_pixel(verts[vi * stride + 1], self.height)
        let on_x = (vx - rminx).abs() < eps || (vx - rmaxx).abs() < eps
        let on_y = (vy - rminy).abs() < eps || (vy - rmaxy).abs() < eps
        if !(on_x && on_y) {
          axis_aligned = false
          break
        }
      }
    }
    if axis_aligned {
      // Pixel `px` is covered iff its center px+0.5 lies in [rminx, rmaxx)
      // (left/top edge inclusive, right/bottom exclusive: the top-left rule).
      let lo_x = clamp_int(scissor_x0, 0, self.width)
      let hi_x = clamp_int(scissor_x1, 0, self.width)
      let lo_y = clamp_int(scissor_y0, 0, self.height)
      let hi_y = clamp_int(scissor_y1, 0, self.height)
      let fx0 = clamp_int(ceil_to_int(rminx - 0.5), lo_x, hi_x)
      let fx1 = clamp_int(ceil_to_int(rmaxx - 0.5), lo_x, hi_x)
      let fy0 = clamp_int(ceil_to_int(rminy - 0.5), lo_y, hi_y)
      let fy1 = clamp_int(ceil_to_int(rmaxy - 0.5), lo_y, hi_y)
      // Full-coverage row span (no corner cuts it): direct write / blend.
      fn fill_row(py : Int) -> Unit {
        if sa >= 255 {
          // Opaque: the result is the source colour for every blend mode.
          let row = py * self.width
          for px in fx0..<fx1 {
            let base = (row + px) * 4
            self.pixels[base] = sr
            self.pixels[base + 1] = sg
            self.pixels[base + 2] = sb
            self.pixels[base + 3] = 255
          }
        } else {
          for px in fx0..<fx1 {
            self.blend_pixel(px, py, sr, sg, sb, sa, command.blend)
          }
        }
      }

      // Corner-band row: per-pixel rounded coverage across the span.
      fn coverage_row(py : Int) -> Unit {
        let pcy = py.to_double() + 0.5
        for px in fx0..<fx1 {
          let pcx = px.to_double() + 0.5
          let cov = rounded_corner_coverage(pcx, pcy, u)
          if cov > 0.0 {
            let a = (sa.to_double() * cov).to_int()
            self.blend_pixel(px, py, sr, sg, sb, a, command.blend)
          }
        }
      }

      if fx1 > fx0 && fy1 > fy0 {
        if !rounded {
          for py in fy0..<fy1 {
            fill_row(py)
          }
        } else {
          // Rows outside [inner_y0, inner_y1) intersect a corner radius and
          // need per-pixel coverage; the rest are fully covered.
          let uy = u[13].to_double()
          let uh = u[15].to_double()
          let max_top = (if u[5] > u[7] { u[5] } else { u[7] }).to_double()
          let max_bot = (if u[9] > u[11] { u[9] } else { u[11] }).to_double()
          let inner_y0 = uy + max_top
          let inner_y1 = uy + uh - max_bot
          for py in fy0..<fy1 {
            let pcy = py.to_double() + 0.5
            if pcy >= inner_y0 && pcy < inner_y1 {
              fill_row(py)
            } else {
              coverage_row(py)
            }
          }
        }
      }
      return
    }
  }
  let mut t = 0
  while t + 2 < indices.length() {
    let i0 = indices[t]
    let i1 = indices[t + 1]
    let i2 = indices[t + 2]
    t = t + 3
    let x0 = ndc_x_to_pixel(verts[i0 * stride], self.width)
    let y0 = ndc_y_to_pixel(verts[i0 * stride + 1], self.height)
    let x1 = ndc_x_to_pixel(verts[i1 * stride], self.width)
    let y1 = ndc_y_to_pixel(verts[i1 * stride + 1], self.height)
    let x2 = ndc_x_to_pixel(verts[i2 * stride], self.width)
    let y2 = ndc_y_to_pixel(verts[i2 * stride + 1], self.height)
    let area = edge_function(x0, y0, x1, y1, x2, y2)
    if area == 0.0 {
      continue
    }
    // Normalize winding so interior points satisfy w >= 0, then apply a
    // top-left fill rule: shared edges (e.g. a quad's split diagonal) are
    // half-open so each pixel is covered by exactly one triangle. Without
    // this, pixel centers lying exactly on the diagonal double-blend, which
    // is visible for translucent fills.
    let ax = x0
    let ay = y0
    let mut bx = x1
    let mut by = y1
    let mut cx = x2
    let mut cy = y2
    if area < 0.0 {
      bx = x2
      by = y2
      cx = x1
      cy = y1
    }
    let tl0 = edge_is_top_left(bx, by, cx, cy)
    let tl1 = edge_is_top_left(cx, cy, ax, ay)
    let tl2 = edge_is_top_left(ax, ay, bx, by)
    // Intersect the triangle bounding box with the framebuffer and the
    // scissor; skip the triangle entirely when the intersection is empty.
    let lo_x = clamp_int(scissor_x0, 0, self.width)
    let hi_x = clamp_int(scissor_x1, 0, self.width) - 1
    let lo_y = clamp_int(scissor_y0, 0, self.height)
    let hi_y = clamp_int(scissor_y1, 0, self.height) - 1
    let tri_min_x = fmin3(x0, x1, x2).to_int()
    let tri_max_x = fmax3(x0, x1, x2).to_int()
    let tri_min_y = fmin3(y0, y1, y2).to_int()
    let tri_max_y = fmax3(y0, y1, y2).to_int()
    let min_x = if tri_min_x > lo_x { tri_min_x } else { lo_x }
    let max_x = if tri_max_x < hi_x { tri_max_x } else { hi_x }
    let min_y = if tri_min_y > lo_y { tri_min_y } else { lo_y }
    let max_y = if tri_max_y < hi_y { tri_max_y } else { hi_y }
    if min_x > max_x || min_y > max_y {
      continue
    }
    for py in min_y..<=max_y {
      for px in min_x..<=max_x {
        let pcx = px.to_double() + 0.5
        let pcy = py.to_double() + 0.5
        let w0 = edge_function(bx, by, cx, cy, pcx, pcy)
        let w1 = edge_function(cx, cy, ax, ay, pcx, pcy)
        let w2 = edge_function(ax, ay, bx, by, pcx, pcy)
        let inside = edge_ok(w0, tl0) && edge_ok(w1, tl1) && edge_ok(w2, tl2)
        if inside {
          let coverage = if rounded {
            rounded_corner_coverage(pcx, pcy, u)
          } else {
            1.0
          }
          if coverage > 0.0 {
            let a = (sa.to_double() * coverage).to_int()
            self.blend_pixel(px, py, sr, sg, sb, a, command.blend)
          }
        }
      }
    }
  }
}

///|
pub impl @gfx.GraphicsDriver for SoftwareDriver with fn initialize(self) {
  self.initialized = true
}

///|
pub impl @gfx.GraphicsDriver for SoftwareDriver with fn begin(self, pass) {
  if pass.clear_enabled {
    self.clear(pass.clear_color)
  }
}

///|
pub impl @gfx.GraphicsDriver for SoftwareDriver with fn end(self, _present) {

}

///|
pub impl @gfx.GraphicsDriver for SoftwareDriver with fn resize(
  self,
  width,
  height,
) {
  let w = if width <= 0 { 1 } else { width }
  let h = if height <= 0 { 1 } else { height }
  if w == self.width && h == self.height {
    return
  }
  self.width = w
  self.height = h
  self.pixels = Array::make(w * h * 4, 0)
}

///|
pub impl @gfx.GraphicsDriver for SoftwareDriver with fn new_image(
  self,
  width,
  height,
) {
  self.next_id = self.next_id + 1
  { id: self.next_id, width, height }
}

///|
pub impl @gfx.GraphicsDriver for SoftwareDriver with fn new_shader(self, source) {
  self.next_id = self.next_id + 1
  { id: self.next_id, source }
}

///|
pub impl @gfx.GraphicsDriver for SoftwareDriver with fn draw_triangles(
  self,
  command,
) {
  if self.initialized {
    self.rasterize(command)
  }
}

///|
pub impl @gfx.GraphicsDriver for SoftwareDriver with fn read_pixels(
  self,
  x,
  y,
  width,
  height,
) {
  if !self.initialized {
    return None
  }
  let read_w = if x + width > self.width { self.width - x } else { width }
  let read_h = if y + height > self.height { self.height - y } else { height }
  if x < 0 || y < 0 || read_w <= 0 || read_h <= 0 {
    return None
  }
  let out = Array::make(read_w * read_h * 4, 0)
  for row in 0..<read_h {
    for col in 0..<read_w {
      let src = ((y + row) * self.width + (x + col)) * 4
      let dst = (row * read_w + col) * 4
      out[dst] = self.pixels[src]
      out[dst + 1] = self.pixels[src + 1]
      out[dst + 2] = self.pixels[src + 2]
      out[dst + 3] = self.pixels[src + 3]
    }
  }
  Some(out)
}
