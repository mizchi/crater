///|
/// JS host backend bridge for the gfx web driver (js target only).
///
/// `install_js_web_backend` registers `WebGraphicsHooks` whose closures
/// forward the dispatched command stream to the JS runtime installed at
/// `globalThis.__craterGfxWeb` (see js/gfx-web-runtime.mjs). That runtime
/// rasterizes the commands (CPU today, WebGPU when a device is available),
/// so crater's assembler renders to real pixels through the exact seam a
/// WebGPU backend uses.

///|
extern "js" fn js_web_init(width : Int, height : Int) -> Bool =
  #|(w, h) => (globalThis.__craterGfxWeb ? globalThis.__craterGfxWeb.init(w, h) === true : false)

///|
extern "js" fn js_web_begin(r : Int, g : Int, b : Int, a : Int) -> Unit =
  #|(r, g, b, a) => { if (globalThis.__craterGfxWeb) globalThis.__craterGfxWeb.begin([r, g, b, a]); }

///|
extern "js" fn js_web_end() -> Unit =
  #|() => { if (globalThis.__craterGfxWeb) globalThis.__craterGfxWeb.end(); }

///|
#borrow(vertex_data, indices, uniforms)
extern "js" fn js_web_draw(
  vertex_data : Array[Double],
  indices : Array[Int],
  uniforms : Array[Int],
  blend : Int,
  rx : Int,
  ry : Int,
  rw : Int,
  rh : Int,
) -> Unit =
  #|(vertexData, indices, uniforms, blend, rx, ry, rw, rh) => {
  #|  if (globalThis.__craterGfxWeb) {
  #|    globalThis.__craterGfxWeb.draw({ vertexData, indices, uniforms, blend, dstRegion: [rx, ry, rw, rh] });
  #|  }
  #|}

///|
extern "js" fn js_web_read_pixels() -> Array[Int] =
  #|() => (globalThis.__craterGfxWeb ? globalThis.__craterGfxWeb.readPixels() : [])

///|
fn channel_255(value : Double) -> Int {
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
/// Register the JS runtime (`globalThis.__craterGfxWeb`) as the gfx web
/// graphics backend. After this, driving a `webgpu_driver` / `webgl_driver`
/// (e.g. via `gfx_bridge.render_paint_tree`) rasterizes into the JS
/// runtime's framebuffer.
pub fn install_js_web_backend() -> Unit {
  let hooks = @gfx.new_web_graphics_hooks(
    fn(_kind, w, h) { js_web_init(w, h) },
    fn(active, _kind, pass) {
      if active && pass.clear_enabled {
        let c = pass.clear_color
        js_web_begin(
          channel_255(c.r),
          channel_255(c.g),
          channel_255(c.b),
          channel_255(c.a),
        )
      }
    },
    fn(active, _kind, _present) { if active { js_web_end() } },
    fn(active, _kind, command) {
      if active {
        let region = if command.dst_regions.length() > 0 {
          command.dst_regions[0]
        } else {
          @gfx.new_dst_region(0, 0, 0, 0, 0)
        }
        js_web_draw(
          command.vertex_data,
          command.indices,
          command.uniform_dwords,
          command.blend.to_int(),
          region.x,
          region.y,
          region.width,
          region.height,
        )
      }
    },
    fn(_active, _kind, _w, _h) {  },
  )
  @gfx.set_web_graphics_hooks(hooks)
}

///|
/// Read back the JS runtime's framebuffer (row-major RGBA, four 0..255
/// channels per pixel).
pub fn web_backend_read_pixels() -> Array[Int] {
  js_web_read_pixels()
}
