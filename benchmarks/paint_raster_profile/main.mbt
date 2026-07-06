///|
/// Native profiling / A-B harness for the software-raster -> RGBA base64 encode
/// scenario (the BiDi captureScreenshot path). Renders a heavy page once, then
/// repeatedly rasterizes the paint tree and base64-encodes the framebuffer.

///|
fn build_css(rules : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("body{margin:0;font-family:sans-serif}")
  buf.write_string("section{display:block;padding:8px}")
  buf.write_string(".row{display:flex;gap:8px}")
  for i = 0; i < rules; i = i + 1 {
    buf.write_string(".c")
    buf.write_string(i.to_string())
    buf.write_string("{padding:")
    buf.write_string((i % 12).to_string())
    buf.write_string("px;border:1px solid #ddd;background:#f")
    buf.write_string((i % 10).to_string())
    buf.write_string("f8ff;color:#1")
    buf.write_string((i % 10).to_string())
    buf.write_string("2}")
  }
  buf.to_string()
}

///|
fn build_html(blocks : Int, rules : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body><main-shell>")
  for i = 0; i < blocks; i = i + 1 {
    let c = i % rules
    buf.write_string("<section class=\"card c")
    buf.write_string(c.to_string())
    buf.write_string("\"><div class=\"row c")
    buf.write_string(((c + 1) % rules).to_string())
    buf.write_string("\"><span class=\"cell\">Item ")
    buf.write_string(i.to_string())
    buf.write_string(
      "</span></div><p class=\"body\">Synthetic paragraph.</p></section>",
    )
  }
  buf.write_string("</main-shell></body></html>")
  buf.to_string()
}

///|
fn main {
  let width = 800
  let height = 600
  let iters = 150
  let css = [build_css(60)]
  let html = build_html(90, 60)
  let ctx = {
    ..@renderer.RenderContext::default(),
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
  }
  let (node, layout) = @renderer.render_to_node_and_layout_with_external_css(
    html, ctx, css,
  )
  let paint : @paint_model.PaintNode = @paint_render.from_node_and_layout(
    node, layout,
  )
  let mut acc = 0
  for i = 0; i < iters; i = i + 1 {
    let fb = @raster.Framebuffer::new(width, height)
    let palette = @raster.DynamicPalette::new()
    @raster.render_paint_node_to_framebuffer(paint, fb, palette)
    let encoded = @raster.framebuffer_to_rgba_base64(fb, palette)
    acc = acc + encoded.length()
  }
  println("rasterized \{iters}x \{width}x\{height} acc=\{acc}")
}
