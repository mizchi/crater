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
  // Scissor: honor the command's destination region as a clip rectangle.
  let (scissor_x0, scissor_y0, scissor_x1, scissor_y1) = if command.dst_regions.length() >
    0 {
    let r = command.dst_regions[0]
    (r.x, r.y, r.x + r.width, r.y + r.height)
  } else {
    (0, 0, self.width, self.height)
  }
  let stride = 4
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
          self.blend_pixel(px, py, sr, sg, sb, sa, command.blend)
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
