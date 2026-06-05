///|
/// Backend-agnostic bridge from crater's paint tree to `mizchi/gfx`
/// draw commands.
///
/// This package is crater's analogue of kagura's `mizchi/renderer2d`: the
/// single "assembler" layer that composes domain inputs into a stream of
/// `@gfx.DrawTrianglesCommand`s for any `GraphicsDriver` backend (null /
/// WebGL / WebGPU / native). It follows the same wiring units:
///
/// - `gfx` is the only graphics contract dependency.
/// - The 2D vocabulary mirrors renderer2d: a `RenderFrame2D` context plus
///   `RectFill2D` / `RectOutline2D` primitives, with pixel coordinates
///   lowered to normalized device coordinates (NDC).
/// - Pure axis-aligned geometry keeps the dependency surface minimal (no
///   vector/geom dependency is required for CSS boxes).
///
/// A `@paint_model.PaintNode` tree is lowered to background fills and
/// border edges today; text and image (atlas) lowering layer on through
/// the same `RenderFrame2D` seam without changing this contract.

// ---------------------------------------------------------------------------
// Frame context
// ---------------------------------------------------------------------------

///|
/// Per-frame rendering context: the destination image, fill shader, target
/// size (used for the pixel -> NDC transform) and blend mode shared by the
/// commands emitted into the frame.
pub(all) struct RenderFrame2D {
  dst : @gfx.ImageHandle
  shader : @gfx.ShaderHandle
  screen_w : Int
  screen_h : Int
  pipeline_id : Int
  uniform_hash : Int
  blend : @gfx.BlendMode
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
) -> RenderFrame2D {
  { dst, shader, screen_w, screen_h, pipeline_id, uniform_hash, blend }
}

///|
/// The full-frame destination region (6 indices = one quad).
pub fn RenderFrame2D::dst_region(self : RenderFrame2D) -> @gfx.DstRegion {
  @gfx.new_dst_region(0, 0, self.screen_w, self.screen_h, 6)
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
pub fn ndc_rect_fill_vertices(
  px : Double,
  py : Double,
  pw : Double,
  ph : Double,
  screen_w : Double,
  screen_h : Double,
) -> (Array[Double], Array[Int]) {
  let x0 = px / screen_w * 2.0 - 1.0
  let y0 = 1.0 - py / screen_h * 2.0
  let x1 = (px + pw) / screen_w * 2.0 - 1.0
  let y1 = 1.0 - (py + ph) / screen_h * 2.0
  let vertices = [
    x0, y0, 0.0, 0.0, x1, y0, 1.0, 0.0, x1, y1, 1.0, 1.0, x0, y1, 0.0, 1.0,
  ]
  (vertices, quad_fill_indices())
}

///|
/// Pixel-space vertices for an axis-aligned rectangle outline, emitted as
/// four edge quads (top, right, bottom, left) of `line_width`. CSS borders
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
// Draw command + primitives (mirrors renderer2d vocabulary)
// ---------------------------------------------------------------------------

///|
/// Core command builder: wraps NDC vertex data + indices for `frame` into a
/// single `@gfx.DrawTrianglesCommand` with the color packed as uniforms.
fn new_primitive_command(
  frame : RenderFrame2D,
  vertex_data : Array[Double],
  indices : Array[Int],
  color : @gfx.Color,
) -> @gfx.DrawTrianglesCommand {
  @gfx.new_draw_triangles_command(
    frame.dst,
    frame.shader,
    [
      @gfx.new_dst_region(
        0,
        0,
        frame.screen_w,
        frame.screen_h,
        indices.length(),
      ),
    ],
    0,
    frame.pipeline_id,
    frame.uniform_hash,
    frame.blend,
    vertex_data,
    indices,
    [],
    color_to_uniform_dwords(color),
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

// ---------------------------------------------------------------------------
// Paint tree lowering (the assembler responsibility)
// ---------------------------------------------------------------------------

///|
/// Append the node's background fill, if it has a visible one.
pub fn append_paint_node_background(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  node : @paint_model.PaintNode,
) -> Unit {
  let bg = node.paint.background_color
  if bg.is_transparent() || node.width <= 0.0 || node.height <= 0.0 {
    return
  }
  append_rect_fill(
    commands,
    frame,
    RectFill2D::new(
      x=node.x,
      y=node.y,
      w=node.width,
      h=node.height,
      color=to_gfx_color(bg),
    ),
  )
}

///|
/// Append the node's borders as up to four edge fills. Each side carries
/// its own width and color (the CSS box model), so they are emitted as
/// individual `RectFill2D` edges rather than a single uniform outline.
pub fn append_paint_node_borders(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  node : @paint_model.PaintNode,
) -> Unit {
  let p = node.paint
  let x = node.x
  let y = node.y
  let w = node.width
  let h = node.height
  fn edge(
    width : Double,
    color : @types.Color,
    ex : Double,
    ey : Double,
    ew : Double,
    eh : Double,
  ) -> Unit {
    if width > 0.0 && !color.is_transparent() && ew > 0.0 && eh > 0.0 {
      append_rect_fill(
        commands,
        frame,
        RectFill2D::new(x=ex, y=ey, w=ew, h=eh, color=to_gfx_color(color)),
      )
    }
  }

  edge(p.border_top_width, p.border_top_color, x, y, w, p.border_top_width)
  edge(
    p.border_bottom_width,
    p.border_bottom_color,
    x,
    y + h - p.border_bottom_width,
    w,
    p.border_bottom_width,
  )
  edge(p.border_left_width, p.border_left_color, x, y, p.border_left_width, h)
  edge(
    p.border_right_width,
    p.border_right_color,
    x + w - p.border_right_width,
    y,
    p.border_right_width,
    h,
  )
}

///|
/// Append a single node's paint (background then borders).
pub fn append_paint_node(
  commands : Array[@gfx.DrawTrianglesCommand],
  frame : RenderFrame2D,
  node : @paint_model.PaintNode,
) -> Unit {
  append_paint_node_background(commands, frame, node)
  append_paint_node_borders(commands, frame, node)
}

///|
/// Walk the paint tree in paint order (a node's box before its children)
/// and collect all draw commands.
pub fn collect_paint_commands(
  frame : RenderFrame2D,
  root : @paint_model.PaintNode,
) -> Array[@gfx.DrawTrianglesCommand] {
  let commands : Array[@gfx.DrawTrianglesCommand] = []
  fn visit(node : @paint_model.PaintNode) -> Unit {
    append_paint_node(commands, frame, node)
    for child in node.children {
      visit(child)
    }
  }

  visit(root)
  commands
}

///|
/// Enqueue every command for the paint tree into a command queue, letting
/// the queue merge compatible draws.
pub fn[Q : @gfx.CommandQueue] enqueue_paint_tree(
  queue : Q,
  frame : RenderFrame2D,
  root : @paint_model.PaintNode,
) -> Unit {
  for cmd in collect_paint_commands(frame, root) {
    queue.enqueue_draw_triangles(cmd)
  }
}

// ---------------------------------------------------------------------------
// End-to-end driver entry point
// ---------------------------------------------------------------------------

///|
/// Placeholder fill shader source handed to the driver. Real backends
/// substitute their own builtin solid-color program; the null driver only
/// needs a stable, non-empty source string.
pub fn default_fill_shader_source() -> String {
  "// crater gfx_bridge: solid color fill\n" +
  "// frag = uniform color (rgba u8x4)"
}

///|
/// Drive a `GraphicsDriver` backend end-to-end from a paint tree:
/// initialize, allocate the destination image and fill shader, build a
/// `RenderFrame2D` sized from the root box, lower the tree into a queue,
/// then flush a single render pass.
pub fn[D : @gfx.GraphicsDriver] render_paint_tree(
  driver : D,
  root : @paint_model.PaintNode,
  clear_color? : @gfx.Color = @gfx.new_color(1.0, 1.0, 1.0, 1.0),
  present? : Bool = false,
) -> Unit raise {
  driver.initialize()
  let width = if root.width > 0.0 { root.width.to_int() } else { 1 }
  let height = if root.height > 0.0 { root.height.to_int() } else { 1 }
  let dst = driver.new_image(width, height)
  let shader = driver.new_shader(default_fill_shader_source())
  let frame = RenderFrame2D::new(dst~, shader~, screen_w=width, screen_h=height)
  let queue = @gfx.new_simple_command_queue()
  enqueue_paint_tree(queue, frame, root)
  @gfx.flush_commands(driver, queue, present, clear_color~)
}
