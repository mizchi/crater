///|
/// Web (WebGPU / WebGL2) backend wiring for crater's gfx-backed renderer.
///
/// gfx's web drivers are `StubGraphicsDriver`s that forward every
/// `begin` / `draw_triangles` / `end` / `resize` to a globally registered
/// `WebGraphicsHooks` set (`@gfx.set_web_graphics_hooks`). The real GPU
/// implementation is supplied by the host runtime (a JS WebGPU/WebGL layer,
/// analogous to kagura_js_runtime) by installing FFI-backed hooks into that
/// same seam.
///
/// This package provides:
/// - constructors for the gfx web drivers sized from a surface
///   (`webgpu_driver` / `webgl_driver`), which crater's `gfx_bridge`
///   assembler can drive unchanged (they implement `@gfx.GraphicsDriver`);
/// - a pure-MoonBit `CaptureSink` hook implementation that records the
///   dispatched command stream, so the wiring is verifiable headlessly and
///   can stand in for the host GPU layer in tests.

///|
/// Create a WebGPU `GraphicsDriver` backed by an offscreen-sized surface.
/// Drive it with `gfx_bridge.render_paint_tree` (or any gfx command queue).
pub fn webgpu_driver(
  width : Int,
  height : Int,
  opaque_id? : Int = 0,
  device_scale? : Double = 1.0,
  options? : @gfx.GraphicsBackendOptions = @gfx.default_graphics_backend_options(),
) -> @gfx.StubGraphicsDriver {
  let surface = @gfx.create_webgpu_surface_token(
    opaque_id, width, height, device_scale,
  )
  @gfx.create_webgpu_graphics(surface, options)
}

///|
/// Create a WebGL2 `GraphicsDriver` backed by an offscreen-sized surface.
pub fn webgl_driver(
  width : Int,
  height : Int,
  opaque_id? : Int = 0,
  device_scale? : Double = 1.0,
  options? : @gfx.GraphicsBackendOptions = @gfx.default_graphics_backend_options(),
) -> @gfx.StubGraphicsDriver {
  let surface = @gfx.create_webgl_surface_token(
    opaque_id, width, height, device_scale,
  )
  @gfx.create_webgl_graphics(surface, options)
}

///|
/// Records the command stream dispatched to the web backend. Stands in for
/// the host GPU layer so the wiring can be asserted without a real device.
pub struct CaptureSink {
  mut initialized : Bool
  mut begin_count : Int
  mut end_count : Int
  mut resize_count : Int
  mut last_present : Bool
  draws : Array[@gfx.DrawTrianglesCommand]
}

///|
/// Number of draw commands captured.
pub fn CaptureSink::draw_count(self : CaptureSink) -> Int {
  self.draws.length()
}

///|
/// The captured draw commands, in dispatch order.
pub fn CaptureSink::draws(
  self : CaptureSink,
) -> Array[@gfx.DrawTrianglesCommand] {
  self.draws
}

///|
/// Install a fresh `CaptureSink` as the global web graphics hooks and
/// return it. `try_initialize` reports success so the driver activates its
/// web path and forwards the command stream. Call `reset_hooks()` when done.
pub fn install_capture_hooks() -> CaptureSink {
  let sink : CaptureSink = {
    initialized: false,
    begin_count: 0,
    end_count: 0,
    resize_count: 0,
    last_present: false,
    draws: [],
  }
  let hooks = @gfx.new_web_graphics_hooks(
    fn(_kind, _w, _h) {
      sink.initialized = true
      true
    },
    fn(active, _kind, _pass) {
      if active {
        sink.begin_count = sink.begin_count + 1
      }
    },
    fn(active, _kind, present) {
      if active {
        sink.end_count = sink.end_count + 1
        sink.last_present = present
      }
    },
    fn(active, _kind, command) { if active { sink.draws.push(command) } },
    fn(active, _kind, _w, _h) {
      if active {
        sink.resize_count = sink.resize_count + 1
      }
    },
  )
  @gfx.set_web_graphics_hooks(hooks)
  sink
}

///|
/// Restore gfx's default (no-op) web graphics hooks.
pub fn reset_hooks() -> Unit {
  @gfx.reset_web_graphics_hooks()
}
