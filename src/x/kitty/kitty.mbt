///|
/// Kitty Graphics Protocol support
/// For terminals like Ghostty, Kitty, WezTerm that support this protocol

///|
/// Base64 encoding table
let base64_chars : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
let kitty_chunk_size = 4096

///|
fn write_base64_triplet(
  buf : StringBuilder,
  b0 : Int,
  b1 : Int,
  b2 : Int,
) -> Unit {
  let c0 = (b0 >> 2) & 0x3F
  let c1 = ((b0 << 4) | (b1 >> 4)) & 0x3F
  let c2 = ((b1 << 2) | (b2 >> 6)) & 0x3F
  let c3 = b2 & 0x3F
  buf.write_char(base64_chars[c0].unsafe_to_char())
  buf.write_char(base64_chars[c1].unsafe_to_char())
  buf.write_char(base64_chars[c2].unsafe_to_char())
  buf.write_char(base64_chars[c3].unsafe_to_char())
}

///|
fn kitty_palette_color_at(
  palette : @sixel.DynamicPalette,
  idx : Int,
) -> @sixel.Color {
  if idx >= 0 && idx < palette.colors.length() {
    palette.colors[idx]
  } else {
    @sixel.Color::white()
  }
}

///|
fn write_kitty_chunk_header(
  buf : StringBuilder,
  width : Int,
  height : Int,
  is_first : Bool,
  has_more : Bool,
) -> Unit {
  if is_first {
    buf.write_string("\u001b_Ga=T,f=24,s=")
    buf.write_string(width.to_string())
    buf.write_string(",v=")
    buf.write_string(height.to_string())
    buf.write_string(",m=")
  } else {
    buf.write_string("\u001b_Gm=")
  }
  buf.write_string(if has_more { "1" } else { "0" })
  buf.write_string(";")
}

///|
async fn[T : @io.Writer] write_kitty_chunk_header_to(
  writer : T,
  width : Int,
  height : Int,
  is_first : Bool,
  has_more : Bool,
) -> Unit {
  if is_first {
    writer.write("\u001b_Ga=T,f=24,s=") catch {
      _ => return
    }
    writer.write(width.to_string()) catch {
      _ => return
    }
    writer.write(",v=") catch {
      _ => return
    }
    writer.write(height.to_string()) catch {
      _ => return
    }
    writer.write(",m=") catch {
      _ => return
    }
  } else {
    writer.write("\u001b_Gm=") catch {
      _ => return
    }
  }
  writer.write(if has_more { "1" } else { "0" }) catch {
    _ => return
  }
  writer.write(";") catch {
    _ => return
  }
}

///|
/// Convert Framebuffer to Kitty Graphics Protocol string
pub fn to_kitty(
  fb : @sixel.Framebuffer,
  palette : @sixel.DynamicPalette,
) -> String {
  let buf = StringBuilder::new()
  let mut chunk = StringBuilder::new()
  let mut chunk_len = 0
  let mut first_chunk = true
  let pixel_count = fb.width * fb.height
  for pixel_index in 0..<pixel_count {
    if chunk_len + 4 > kitty_chunk_size {
      write_kitty_chunk_header(buf, fb.width, fb.height, first_chunk, true)
      buf.write_string(chunk.to_string())
      buf.write_string("\u001b\\")
      chunk = StringBuilder::new()
      chunk_len = 0
      first_chunk = false
    }
    let color = kitty_palette_color_at(palette, fb.pixels[pixel_index])
    write_base64_triplet(chunk, color.r, color.g, color.b)
    chunk_len += 4
  }
  write_kitty_chunk_header(buf, fb.width, fb.height, first_chunk, false)
  if chunk_len > 0 {
    buf.write_string(chunk.to_string())
  }
  buf.write_string("\u001b\\")
  buf.to_string()
}

///|
pub async fn[T : @io.Writer] write_kitty(
  writer : T,
  fb : @sixel.Framebuffer,
  palette : @sixel.DynamicPalette,
) -> Unit {
  let mut chunk = StringBuilder::new()
  let mut chunk_len = 0
  let mut first_chunk = true
  let pixel_count = fb.width * fb.height
  for pixel_index in 0..<pixel_count {
    if chunk_len + 4 > kitty_chunk_size {
      write_kitty_chunk_header_to(
        writer,
        fb.width,
        fb.height,
        first_chunk,
        true,
      )
      writer.write(chunk.to_string()) catch {
        _ => return
      }
      writer.write("\u001b\\") catch {
        _ => return
      }
      chunk = StringBuilder::new()
      chunk_len = 0
      first_chunk = false
    }
    let color = kitty_palette_color_at(palette, fb.pixels[pixel_index])
    write_base64_triplet(chunk, color.r, color.g, color.b)
    chunk_len += 4
  }
  write_kitty_chunk_header_to(writer, fb.width, fb.height, first_chunk, false)
  if chunk_len > 0 {
    writer.write(chunk.to_string()) catch {
      _ => return
    }
  }
  writer.write("\u001b\\") catch {
    _ => return
  }
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
pub async fn[T : @io.Writer] write_svg_to_kitty(
  writer : T,
  scene : @svg.Scene,
  width : Int,
  height : Int,
) -> Unit {
  let fb = @sixel.Framebuffer::new(width, height)
  let palette = @sixel.DynamicPalette::new()
  fb.fill_rect(0, 0, width, height, 0)
  @sixel.render_svg_scene(scene, fb, palette)
  write_kitty(writer, fb, palette)
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
  render_paint_node_to_kitty_scrolled(node, width, height, 0)
}

///|
/// Render PaintNode to Kitty Graphics Protocol string with scroll offset
pub fn render_paint_node_to_kitty_scrolled(
  node : @paint.PaintNode,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> String {
  let fb = @sixel.Framebuffer::new(width, height)
  let palette = @sixel.DynamicPalette::new()
  @sixel.render_paint_node_to_framebuffer_scrolled(node, fb, palette, scroll_y)
  // Convert to Kitty
  to_kitty(fb, palette)
}

///|
pub async fn[T : @io.Writer] write_paint_node_to_kitty_scrolled(
  writer : T,
  node : @paint.PaintNode,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> Unit {
  let fb = @sixel.Framebuffer::new(width, height)
  let palette = @sixel.DynamicPalette::new()
  @sixel.render_paint_node_to_framebuffer_scrolled(node, fb, palette, scroll_y)
  write_kitty(writer, fb, palette)
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
