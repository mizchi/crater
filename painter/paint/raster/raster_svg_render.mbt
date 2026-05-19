///|
/// SVG raster region rendering helpers.

///|
fn render_svg_into_region(
  fb : Framebuffer,
  palette : DynamicPalette,
  svg_text : String,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
) -> Unit {
  let svg_node = match @svg.parse_svg(svg_text) {
    Some(n) => n
    None => return
  }
  let scene = @svg.Scene::new(svg_node)
  let bounds = scene.get_bounds()
  let vw = bounds.width()
  let vh = bounds.height()
  if vw <= 0.0 || vh <= 0.0 {
    return
  }
  let tmp_fb = Framebuffer::new(w, h)
  let tmp_palette = DynamicPalette::new()
  tmp_fb.fill_rect(0, 0, w, h, 0)
  match svg_node.view_box {
    Some(_) => render_svg_scene(scene, tmp_fb, tmp_palette)
    None => {
      let camera = @svg.Camera::new(w, h)
      camera.set_position(bounds.min_x + vw / 2.0, bounds.min_y + vh / 2.0)
      let zoom = (w.to_double() / vw).min(h.to_double() / vh)
      camera.set_zoom(zoom)
      render_svg_scene_with_camera(scene, tmp_fb, tmp_palette, camera)
    }
  }
  for py = 0; py < h; py = py + 1 {
    let dst_y = y + py
    if dst_y < 0 || dst_y >= fb.height {
      continue
    }
    for px = 0; px < w; px = px + 1 {
      let dst_x = x + px
      if dst_x < 0 || dst_x >= fb.width {
        continue
      }
      if !pixel_in_clip(clip, dst_x, dst_y) {
        continue
      }
      let tmp_idx = tmp_fb.pixels[py * w + px]
      if tmp_idx > 0 {
        let color = if tmp_idx < tmp_palette.colors.length() {
          tmp_palette.colors[tmp_idx]
        } else {
          Color::white()
        }
        let main_idx = palette.get_or_add(color)
        fb.set_pixel(dst_x, dst_y, main_idx)
      }
    }
  }
}
