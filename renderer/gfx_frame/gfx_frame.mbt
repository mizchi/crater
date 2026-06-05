///|
/// Shared 2D framing primitives for crater's gfx-backed renderer.
///
/// This is the base wiring unit that the image / text / assembler packages
/// all build on, mirroring the role of kagura's renderer2d primitive
/// helpers. It depends only on `mizchi/gfx` (the graphics contract) and
/// `mizchi/css/values` (for color conversion), keeping the surface minimal.
///
/// All geometry is lowered from CSS pixel space to normalized device
/// coordinates (NDC): x in [-1, 1] rightward, y in [-1, 1] with the origin
/// at the top-left of the frame.

// ---------------------------------------------------------------------------
// Frame context
// ---------------------------------------------------------------------------

///|
/// Per-frame rendering context: the destination image, fill shader, target
/// size (used for the pixel -> NDC transform), blend mode, and a pixel-space
/// clip (scissor) rectangle shared by the commands emitted into the frame.
/// The clip is carried on each command's `dst_region`; backends that honor
/// `dst_region` (e.g. gfx_software) treat it as a scissor.
pub(all) struct RenderFrame2D {
  dst : @gfx.ImageHandle
  shader : @gfx.ShaderHandle
  screen_w : Int
  screen_h : Int
  pipeline_id : Int
  uniform_hash : Int
  blend : @gfx.BlendMode
  clip_x : Int
  clip_y : Int
  clip_w : Int
  clip_h : Int
  opacity : Double
}

///|
pub fn RenderFrame2D::new(
  dst~ : @gfx.ImageHandle,
  shader~ : @gfx.ShaderHandle,
  screen_w~ : Int,
  screen_h~ : Int,
  pipeline_id? : Int = 0,
  uniform_hash? : Int = 0,
  blend? : @gfx.BlendMode = @gfx.BlendMode::Alpha,
  clip_x? : Int = 0,
  clip_y? : Int = 0,
  clip_w? : Int = -1,
  clip_h? : Int = -1,
  opacity? : Double = 1.0,
) -> RenderFrame2D {
  // A negative clip extent means "no clip": default to the full frame.
  let cw = if clip_w < 0 { screen_w } else { clip_w }
  let ch = if clip_h < 0 { screen_h } else { clip_h }
  {
    dst,
    shader,
    screen_w,
    screen_h,
    pipeline_id,
    uniform_hash,
    blend,
    clip_x,
    clip_y,
    clip_w: cw,
    clip_h: ch,
    opacity,
  }
}

///|
/// Derive a frame whose opacity is multiplied by `factor` (clamped to
/// 0..1). Used to push a CSS opacity group multiplier onto an element and
/// its descendants.
pub fn RenderFrame2D::with_opacity(
  self : RenderFrame2D,
  factor : Double,
) -> RenderFrame2D {
  let f = if factor < 0.0 { 0.0 } else if factor > 1.0 { 1.0 } else { factor }
  { ..self, opacity: self.opacity * f }
}

///|
/// Derive a frame with its clip rectangle intersected with `(x, y, w, h)`
/// (pixel space). Used to push an overflow/clip boundary onto descendants.
pub fn RenderFrame2D::with_clip(
  self : RenderFrame2D,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> RenderFrame2D {
  let x0 = if x > self.clip_x { x } else { self.clip_x }
  let y0 = if y > self.clip_y { y } else { self.clip_y }
  let x1a = x + w
  let x1b = self.clip_x + self.clip_w
  let x1 = if x1a < x1b { x1a } else { x1b }
  let y1a = y + h
  let y1b = self.clip_y + self.clip_h
  let y1 = if y1a < y1b { y1a } else { y1b }
  let cw = if x1 > x0 { x1 - x0 } else { 0 }
  let ch = if y1 > y0 { y1 - y0 } else { 0 }
  { ..self, clip_x: x0, clip_y: y0, clip_w: cw, clip_h: ch }
}

///|
/// The frame's clip rectangle as a destination region (`index_count`
/// indices). Defaults to the full frame.
pub fn RenderFrame2D::dst_region(
  self : RenderFrame2D,
  index_count? : Int = 6,
) -> @gfx.DstRegion {
  @gfx.new_dst_region(
    self.clip_x,
    self.clip_y,
    self.clip_w,
    self.clip_h,
    index_count,
  )
}

// ---------------------------------------------------------------------------
// Color
// ---------------------------------------------------------------------------

///|
/// Convert a crater css color (`r`/`g`/`b` in 0..255, `a` in 0..1) into a
/// `@gfx.Color` (all channels normalized to 0..1).
pub fn to_gfx_color(c : @types.Color) -> @gfx.Color {
  @gfx.new_color(
    c.r.to_double() / 255.0,
    c.g.to_double() / 255.0,
    c.b.to_double() / 255.0,
    c.a,
  )
}

///|
/// Pack a `@gfx.Color` into the uniform dword stream as four 0..255
/// channels (r, g, b, a), matching the renderer2d convention.
pub fn color_to_uniform_dwords(color : @gfx.Color) -> Array[Int] {
  [
    (color.r * 255.0).to_int(),
    (color.g * 255.0).to_int(),
    (color.b * 255.0).to_int(),
    (color.a * 255.0).to_int(),
  ]
}

// ---------------------------------------------------------------------------
// Geometry helpers (axis-aligned, dependency-free)
// ---------------------------------------------------------------------------

///|
/// Triangle indices for a single quad (two triangles).
pub fn quad_fill_indices() -> Array[Int] {
  [0, 1, 2, 2, 3, 0]
}

///|
/// Transform interleaved pixel-space vertices (x, y, u, v per vertex) into
/// NDC: x in [-1, 1] rightward, y in [-1, 1] with the origin at top-left.
pub fn pixel_to_ndc_vertices(
  vertices : Array[Double],
  screen_w : Double,
  screen_h : Double,
) -> Array[Double] {
  let out : Array[Double] = []
  let mut i = 0
  while i < vertices.length() {
    let px = vertices[i]
    let py = vertices[i + 1]
    let u = vertices[i + 2]
    let v = vertices[i + 3]
    out.push(px / screen_w * 2.0 - 1.0)
    out.push(1.0 - py / screen_h * 2.0)
    out.push(u)
    out.push(v)
    i = i + 4
  }
  out
}

///|
/// Interleaved NDC vertices (x, y, u, v) for a filled axis-aligned rect.
/// The uv coordinates span the unit square so textured backends can sample
/// an image or glyph atlas over the quad.
pub fn ndc_rect_vertices(
  px : Double,
  py : Double,
  pw : Double,
  ph : Double,
  screen_w : Double,
  screen_h : Double,
  u0? : Double = 0.0,
  v0? : Double = 0.0,
  u1? : Double = 1.0,
  v1? : Double = 1.0,
) -> (Array[Double], Array[Int]) {
  let x0 = px / screen_w * 2.0 - 1.0
  let y0 = 1.0 - py / screen_h * 2.0
  let x1 = (px + pw) / screen_w * 2.0 - 1.0
  let y1 = 1.0 - (py + ph) / screen_h * 2.0
  let vertices = [
    x0, y0, u0, v0, x1, y0, u1, v0, x1, y1, u1, v1, x0, y1, u0, v1,
  ]
  (vertices, quad_fill_indices())
}

///|
/// Interleaved NDC vertices (x, y, u, v) for a filled axis-aligned rect
/// spanning the full unit uv square.
pub fn ndc_rect_fill_vertices(
  px : Double,
  py : Double,
  pw : Double,
  ph : Double,
  screen_w : Double,
  screen_h : Double,
) -> (Array[Double], Array[Int]) {
  ndc_rect_vertices(px, py, pw, ph, screen_w, screen_h)
}

///|
/// Pixel-space vertices for an axis-aligned rectangle outline, emitted as
/// four edge quads (top, bottom, left, right) of `line_width`. CSS borders
/// are axis-aligned, so no rotated line geometry (and no vector
/// dependency) is needed.
pub fn rect_outline_vertices(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  line_width : Double,
) -> (Array[Double], Array[Int]) {
  let all_vertices : Array[Double] = []
  let all_indices : Array[Int] = []
  let edges = [
    (x, y, w, line_width), // top
    (x, y + h - line_width, w, line_width), // bottom
    (x, y, line_width, h), // left
    (x + w - line_width, y, line_width, h), // right
  ]
  let mut base = 0
  for edge in edges {
    let (ex, ey, ew, eh) = edge
    let verts = [
      ex,
      ey,
      0.0,
      0.0,
      ex + ew,
      ey,
      1.0,
      0.0,
      ex + ew,
      ey + eh,
      1.0,
      1.0,
      ex,
      ey + eh,
      0.0,
      1.0,
    ]
    for value in verts {
      all_vertices.push(value)
    }
    for idx in quad_fill_indices() {
      all_indices.push(idx + base)
    }
    base = base + 4
  }
  (all_vertices, all_indices)
}

// ---------------------------------------------------------------------------
// Draw command builder + primitives
// ---------------------------------------------------------------------------

///|
/// Core command builder: wrap NDC vertex data + indices for `frame` into a
/// single `@gfx.DrawTrianglesCommand`, with `color` packed as uniforms and
/// optional `src_image_ids` for textured draws (images / glyph atlases).
pub fn new_primitive_command(
  frame : RenderFrame2D,
  vertex_data : Array[Double],
  indices : Array[Int],
  color : @gfx.Color,
  src_image_ids? : Array[Int] = [],
  extra_uniforms? : Array[Int] = [],
) -> @gfx.DrawTrianglesCommand {
  // Modulate the color's alpha by the frame opacity (CSS group opacity).
  let effective = if frame.opacity >= 1.0 {
    color
  } else {
    { ..color, a: color.a * frame.opacity }
  }
  let uniforms = color_to_uniform_dwords(effective)
  for value in extra_uniforms {
    uniforms.push(value)
  }
  @gfx.new_draw_triangles_command(
    frame.dst,
    frame.shader,
    [frame.dst_region(index_count=indices.length())],
    0,
    frame.pipeline_id,
    frame.uniform_hash,
    frame.blend,
    vertex_data,
    indices,
    src_image_ids,
    uniforms,
  )
}

///|
/// A solid-color filled rectangle in pixel space (e.g. a background box).
pub(all) struct RectFill2D {
  x : Double
  y : Double
  w : Double
  h : Double
  color : @gfx.Color
}

///|
pub fn RectFill2D::new(
  x~ : Double,
  y~ : Double,
  w~ : Double,
  h~ : Double,
  color~ : @gfx.Color,
) -> RectFill2D {
  { x, y, w, h, color }
}

///|
/// Lower a `RectFill2D` into the command list (one quad).
pub fn append_rect_fill(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  rect : RectFill2D,
) -> Unit {
  let (vertices, indices) = ndc_rect_fill_vertices(
    rect.x,
    rect.y,
    rect.w,
    rect.h,
    frame.screen_w.to_double(),
    frame.screen_h.to_double(),
  )
  commands.push(new_primitive_command(frame, vertices, indices, rect.color))
}

///|
/// Lower a solid rounded-rectangle fill. The per-corner radii and the rect
/// (pixel space) are packed into the command's uniforms after the four
/// color channels (`[r, g, b, a, r_tl, r_tr, r_br, r_bl, x, y, w, h]`), so a
/// backend's "shader" can carve the corners. gfx_software honors this; other
/// backends that ignore the extra uniforms fall back to a square fill.
pub fn append_rounded_rect_fill(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  rect : RectFill2D,
  radius_tl~ : Double,
  radius_tr~ : Double,
  radius_br~ : Double,
  radius_bl~ : Double,
) -> Unit {
  let (vertices, indices) = ndc_rect_fill_vertices(
    rect.x,
    rect.y,
    rect.w,
    rect.h,
    frame.screen_w.to_double(),
    frame.screen_h.to_double(),
  )
  let extra = [
    radius_tl.to_int(),
    radius_tr.to_int(),
    radius_br.to_int(),
    radius_bl.to_int(),
    rect.x.to_int(),
    rect.y.to_int(),
    rect.w.to_int(),
    rect.h.to_int(),
  ]
  commands.push(
    new_primitive_command(
      frame,
      vertices,
      indices,
      rect.color,
      extra_uniforms=extra,
    ),
  )
}

///|
/// A uniform-width, single-color rectangle outline in pixel space.
pub(all) struct RectOutline2D {
  x : Double
  y : Double
  w : Double
  h : Double
  line_width : Double
  color : @gfx.Color
}

///|
pub fn RectOutline2D::new(
  x~ : Double,
  y~ : Double,
  w~ : Double,
  h~ : Double,
  line_width? : Double = 1.0,
  color~ : @gfx.Color,
) -> RectOutline2D {
  { x, y, w, h, line_width, color }
}

///|
/// Lower a `RectOutline2D` into the command list (four edge quads in one
/// command).
pub fn append_rect_outline(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  rect : RectOutline2D,
) -> Unit {
  let (vertices, indices) = rect_outline_vertices(
    rect.x,
    rect.y,
    rect.w,
    rect.h,
    rect.line_width,
  )
  commands.push(
    new_primitive_command(
      frame,
      pixel_to_ndc_vertices(
        vertices,
        frame.screen_w.to_double(),
        frame.screen_h.to_double(),
      ),
      indices,
      rect.color,
    ),
  )
}
