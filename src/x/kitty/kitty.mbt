///|
/// Kitty Graphics Protocol support
/// For terminals like Ghostty, Kitty, WezTerm that support this protocol

///|
/// Base64 encoding table
let base64_chars : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
/// Encode bytes to base64
fn encode_base64(data : Array[Int]) -> String {
  let buf = StringBuilder::new()
  let len = data.length()
  let mut i = 0
  while i < len {
    let b0 = data[i]
    let b1 = if i + 1 < len { data[i + 1] } else { 0 }
    let b2 = if i + 2 < len { data[i + 2] } else { 0 }
    // Encode 3 bytes to 4 base64 characters
    let c0 = (b0 >> 2) & 0x3F
    let c1 = ((b0 << 4) | (b1 >> 4)) & 0x3F
    let c2 = ((b1 << 2) | (b2 >> 6)) & 0x3F
    let c3 = b2 & 0x3F
    buf.write_char(base64_chars[c0].unsafe_to_char())
    buf.write_char(base64_chars[c1].unsafe_to_char())
    if i + 1 < len {
      buf.write_char(base64_chars[c2].unsafe_to_char())
    } else {
      buf.write_char('=')
    }
    if i + 2 < len {
      buf.write_char(base64_chars[c3].unsafe_to_char())
    } else {
      buf.write_char('=')
    }
    i = i + 3
  }
  buf.to_string()
}

///|
/// Convert Framebuffer to RGB byte array
fn framebuffer_to_rgb(
  fb : @sixel.Framebuffer,
  palette : @sixel.DynamicPalette,
) -> Array[Int] {
  let data : Array[Int] = []
  for y = 0; y < fb.height; y = y + 1 {
    for x = 0; x < fb.width; x = x + 1 {
      let idx = fb.get_pixel(x, y)
      let color = if idx < palette.colors.length() {
        palette.colors[idx]
      } else {
        @sixel.Color::white()
      }
      data.push(color.r)
      data.push(color.g)
      data.push(color.b)
    }
  }
  data
}

///|
/// Convert Framebuffer to Kitty Graphics Protocol string
pub fn to_kitty(
  fb : @sixel.Framebuffer,
  palette : @sixel.DynamicPalette,
) -> String {
  let rgb_data = framebuffer_to_rgb(fb, palette)
  let base64_data = encode_base64(rgb_data)
  let buf = StringBuilder::new()
  // Kitty graphics escape sequence
  // ESC _ G a=T,f=24,s=<width>,v=<height>,m=0 ; <base64_data> ESC \
  // a=T: direct transmission
  // f=24: RGB format (24 bits per pixel)
  // s: width in pixels
  // v: height in pixels
  // m=0: no more data chunks
  buf.write_string("\u001b_Ga=T,f=24,s=")
  buf.write_string(fb.width.to_string())
  buf.write_string(",v=")
  buf.write_string(fb.height.to_string())
  // If data is large, split into chunks (max ~4096 bytes per chunk recommended)
  let chunk_size = 4096
  if base64_data.length() <= chunk_size {
    buf.write_string(",m=0;")
    buf.write_string(base64_data)
    buf.write_string("\u001b\\")
  } else {
    // Send in chunks
    let mut offset = 0
    let data_len = base64_data.length()
    let mut first = true
    while offset < data_len {
      let remaining = data_len - offset
      let this_chunk = if remaining > chunk_size {
        chunk_size
      } else {
        remaining
      }
      let is_last = offset + this_chunk >= data_len
      if first {
        buf.write_string(",m=")
        buf.write_string(if is_last { "0" } else { "1" })
        buf.write_string(";")
        first = false
      } else {
        buf.write_string("\u001b_Gm=")
        buf.write_string(if is_last { "0" } else { "1" })
        buf.write_string(";")
      }
      // Extract substring
      for i = offset; i < offset + this_chunk; i = i + 1 {
        buf.write_char(base64_data[i].unsafe_to_char())
      }
      buf.write_string("\u001b\\")
      offset = offset + this_chunk
    }
  }
  buf.to_string()
}

///|
/// Render SVG scene to Kitty Graphics Protocol string
pub fn render_svg_to_kitty(
  scene : @svg.Scene,
  width : Int,
  height : Int,
) -> String {
  let fb = @sixel.Framebuffer::new(width, height)
  let palette = @sixel.DynamicPalette::new()
  // Fill with white background
  fb.fill_rect(0, 0, width, height, 0)
  // Render SVG
  @sixel.render_svg_scene(scene, fb, palette)
  // Convert to Kitty
  to_kitty(fb, palette)
}

///|
/// Render SVG node to Kitty Graphics Protocol string
pub fn render_svg_node_to_kitty(
  node : @svg.SVGNode,
  width : Int,
  height : Int,
) -> String {
  let scene = @svg.Scene::new(node)
  render_svg_to_kitty(scene, width, height)
}

///|
/// Render PaintNode to Kitty Graphics Protocol string
pub fn render_paint_node_to_kitty(
  node : @paint.PaintNode,
  width : Int,
  height : Int,
) -> String {
  let fb = @sixel.Framebuffer::new(width, height)
  let palette = @sixel.DynamicPalette::new()
  // Fill with white background
  fb.fill_rect(0, 0, width, height, 0)
  // Render paint node
  @sixel.render_paint_node_to_framebuffer(node, fb, palette)
  // Convert to Kitty
  to_kitty(fb, palette)
}

///|
/// Render SVG scene with camera to Kitty Graphics Protocol string
pub fn render_svg_to_kitty_with_camera(
  scene : @svg.Scene,
  camera : @svg.Camera,
) -> String {
  let fb = @sixel.Framebuffer::new(
    camera.viewport_width,
    camera.viewport_height,
  )
  let palette = @sixel.DynamicPalette::new()
  // Fill with white background
  fb.fill_rect(0, 0, camera.viewport_width, camera.viewport_height, 0)
  // Render SVG with camera
  @sixel.render_svg_scene_with_camera(scene, fb, palette, camera)
  // Convert to Kitty
  to_kitty(fb, palette)
}
