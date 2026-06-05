///|
/// Image-based visual regression testing on top of the gfx pipeline.
///
/// crater's existing VRT compares *paint trees* (geometry). This package
/// closes the loop to *pixels*: it drives the same paint tree through the
/// `gfx_bridge` assembler onto the `gfx_software` CPU backend and exposes
/// the resulting RGBA framebuffer plus a deterministic ASCII rendering that
/// is convenient to snapshot.
///
/// `render_html_to_image` reuses the existing `vrt` HTML -> paint tree
/// entry point, so image VRT runs against the very same input as the
/// paint-tree VRT.

///|
/// A rendered RGBA framebuffer: row-major, four 0..255 channels per pixel.
pub(all) struct RenderedImage {
  width : Int
  height : Int
  pixels : Array[Int]
}

///|
/// Read back a single pixel as (r, g, b, a).
pub fn RenderedImage::pixel_at(
  self : RenderedImage,
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
/// Render a paint tree to an RGBA image of the given size via the software
/// backend. The tree is expected to be laid out in the same pixel space
/// (its root box matching the viewport).
pub fn render_paint_tree_to_image(
  root : @paint_model.PaintNode,
  width : Int,
  height : Int,
) -> RenderedImage {
  let driver = @gfx_software.SoftwareDriver::new(width, height)
  // The software backend never actually raises; keep the public API total.
  @gfx_bridge.render_paint_tree(driver, root) catch {
    _ => ()
  }
  let pixels = try {
    match @gfx.GraphicsDriver::read_pixels(driver, 0, 0, width, height) {
      Some(p) => p
      None => Array::make(width * height * 4, 0)
    }
  } catch {
    _ => Array::make(width * height * 4, 0)
  }
  { width, height, pixels }
}

///|
/// Render an HTML document to an RGBA image at `viewport`, reusing the
/// existing VRT HTML -> paint tree pipeline.
pub fn render_html_to_image(
  html : String,
  viewport : @types.Size[Double],
) -> RenderedImage {
  let root = @vrt.render_html_to_paint_tree(html, viewport)
  render_paint_tree_to_image(
    root,
    viewport.width.to_int(),
    viewport.height.to_int(),
  )
}

///|
/// Render the image as ASCII art for snapshotting: each pixel maps to a
/// ramp character by brightness (light -> space, dark -> '@'). Fully
/// transparent pixels render as a space.
pub fn RenderedImage::to_ascii(self : RenderedImage) -> String {
  let ramp = [' ', '.', ':', '-', '=', '+', '*', '#', '%', '@']
  let last = ramp.length() - 1
  let buf = StringBuilder::new()
  for y in 0..<self.height {
    for x in 0..<self.width {
      let base = (y * self.width + x) * 4
      let r = self.pixels[base]
      let g = self.pixels[base + 1]
      let b = self.pixels[base + 2]
      let a = self.pixels[base + 3]
      if a == 0 {
        buf.write_char(' ')
      } else {
        let lum = (r * 30 + g * 59 + b * 11) / 100
        let idx = (255 - lum) * last / 255
        buf.write_char(ramp[idx])
      }
    }
    buf.write_char('\n')
  }
  buf.to_string()
}
