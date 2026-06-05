///|
/// Backend-agnostic bridge from crater's paint tree to `mizchi/gfx`
/// draw commands.
///
/// `mizchi/gfx` provides the GPU command-buffer and driver contracts
/// (`GraphicsDriver`, `CommandQueue`, `DrawTrianglesCommand`, ...) that
/// were extracted from kagura. This package wires crater's renderer onto
/// those contracts: a `@paint_model.PaintNode` tree is lowered into a
/// stream of `@gfx.DrawTrianglesCommand`s that any `GraphicsDriver`
/// backend (null / WebGL / WebGPU / native) can consume.
///
/// Only background fills are lowered today; border, text and image
/// painting are layered on later without changing this contract seam.

///|
/// Fixed pipeline id used for solid-color quad fills. Keeping it constant
/// lets the command queue merge adjacent fills that share a pipeline.
const FILL_PIPELINE_ID : Int = 1

///|
/// Placeholder fill shader source handed to the driver. Real backends
/// substitute their own builtin solid-color program; the null driver only
/// needs a stable, non-empty source string.
pub fn default_fill_shader_source() -> String {
  "// crater gfx_bridge: solid color fill\n" +
  "// frag = uniform color (rgba f32x4)"
}

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
/// Build the interleaved vertex data (x, y, u, v per vertex) for an axis
/// aligned rectangle, in clockwise order: top-left, top-right,
/// bottom-left, bottom-right.
fn rect_quad_vertices(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Array[Double] {
  [
    x,
    y,
    0.0,
    0.0, // top-left
    x + w,
    y,
    1.0,
    0.0, // top-right
    x,
    y + h,
    0.0,
    1.0, // bottom-left
    x + w,
    y + h,
    1.0,
    1.0, // bottom-right
  ]
}

///|
/// Triangle indices for the quad emitted by `rect_quad_vertices`.
fn quad_indices() -> Array[Int] {
  [0, 1, 2, 1, 3, 2]
}

///|
/// Pack an `@gfx.Color` into the uniform dword stream as four f32 bit
/// patterns (r, g, b, a).
fn pack_color_uniform(c : @gfx.Color) -> Array[Int] {
  [
    @gfx.double_to_f32_bits(c.r),
    @gfx.double_to_f32_bits(c.g),
    @gfx.double_to_f32_bits(c.b),
    @gfx.double_to_f32_bits(c.a),
  ]
}

///|
/// Lower a single paint node's background fill into a draw command.
///
/// Returns `None` when the node has nothing to fill (transparent
/// background or a zero-area box).
pub fn paint_node_fill_command(
  node : @paint_model.PaintNode,
  dst : @gfx.ImageHandle,
  shader : @gfx.ShaderHandle,
) -> @gfx.DrawTrianglesCommand? {
  let bg = node.paint.background_color
  if bg.is_transparent() || node.width <= 0.0 || node.height <= 0.0 {
    return None
  }
  let color = to_gfx_color(bg)
  let uniforms = pack_color_uniform(color)
  let uniform_hash = @gfx.build_resource_cache_key(FILL_PIPELINE_ID, uniforms)
  let region = @gfx.new_dst_region(
    node.x.to_int(),
    node.y.to_int(),
    node.width.to_int(),
    node.height.to_int(),
    6,
  )
  let blend = if bg.is_opaque() {
    @gfx.BlendMode::Copy
  } else {
    @gfx.BlendMode::Alpha
  }
  Some(
    @gfx.new_draw_triangles_command(
      dst,
      shader,
      [region],
      0,
      FILL_PIPELINE_ID,
      uniform_hash,
      blend,
      rect_quad_vertices(node.x, node.y, node.width, node.height),
      quad_indices(),
      [],
      uniforms,
      resource_cache_key=uniform_hash,
      vertex_stride_hint=4,
    ),
  )
}

///|
/// Walk the paint tree in paint order (parent box before its children) and
/// collect one fill command per visible node.
pub fn collect_fill_commands(
  root : @paint_model.PaintNode,
  dst : @gfx.ImageHandle,
  shader : @gfx.ShaderHandle,
) -> Array[@gfx.DrawTrianglesCommand] {
  let commands : Array[@gfx.DrawTrianglesCommand] = []
  fn visit(node : @paint_model.PaintNode) -> Unit {
    match paint_node_fill_command(node, dst, shader) {
      Some(cmd) => commands.push(cmd)
      None => ()
    }
    for child in node.children {
      visit(child)
    }
  }

  visit(root)
  commands
}

///|
/// Enqueue every fill command for the paint tree into a command queue,
/// letting the queue merge compatible draws.
pub fn[Q : @gfx.CommandQueue] enqueue_paint_tree(
  queue : Q,
  root : @paint_model.PaintNode,
  dst : @gfx.ImageHandle,
  shader : @gfx.ShaderHandle,
) -> Unit {
  for cmd in collect_fill_commands(root, dst, shader) {
    queue.enqueue_draw_triangles(cmd)
  }
}

///|
/// Drive a `GraphicsDriver` backend end-to-end from a paint tree:
/// initialize, allocate the destination image and fill shader, lower the
/// tree into a queue, then flush a single render pass.
///
/// The destination image is sized from the root node's box. Pass a custom
/// `clear_color`/`present` to control the render pass.
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
  let queue = @gfx.new_simple_command_queue()
  enqueue_paint_tree(queue, root, dst, shader)
  @gfx.flush_commands(driver, queue, present, clear_color~)
}
