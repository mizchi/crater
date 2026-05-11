///|
/// Offscreen group opacity compositing helpers.

///|
fn make_transparent_framebuffer(width : Int, height : Int) -> Framebuffer {
  { width, height, pixels: Array::make(width * height, -1) }
}

///|
fn blend_group_framebuffer_over(
  fb : Framebuffer,
  palette : DynamicPalette,
  group_fb : Framebuffer,
  group_palette : DynamicPalette,
  opacity : Double,
  clip : ClipRect?,
) -> Unit {
  let alpha = clamp_byte((opacity * 255.0).to_int())
  if alpha <= 0 {
    return
  }
  let x1 = match clip {
    Some(c) => @cmp.maximum(c.x, 0)
    None => 0
  }
  let y1 = match clip {
    Some(c) => @cmp.maximum(c.y, 0)
    None => 0
  }
  let x2 = match clip {
    Some(c) => @cmp.minimum(c.x + c.w, fb.width)
    None => fb.width
  }
  let y2 = match clip {
    Some(c) => @cmp.minimum(c.y + c.h, fb.height)
    None => fb.height
  }
  if x2 <= x1 || y2 <= y1 {
    return
  }
  for py = y1; py < y2; py = py + 1 {
    let row = py * group_fb.width
    for px = x1; px < x2; px = px + 1 {
      let idx = group_fb.pixels[row + px]
      if idx >= 0 && idx < group_palette.colors.length() {
        blend_raster_color_over_pixel(
          fb,
          palette,
          px,
          py,
          group_palette.colors[idx],
          alpha,
        )
      }
    }
  }
}

///|
fn render_group_opacity_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  parent_x : Double,
  parent_y : Double,
  clip : ClipRect?,
) -> Unit {
  let group_fb = make_transparent_framebuffer(fb.width, fb.height)
  let group_palette = DynamicPalette::new()
  let opaque_node = { ..node, paint: { ..node.paint, opacity: 1.0 } }
  render_paint_node_clipped(
    group_fb, group_palette, opaque_node, parent_x, parent_y, clip,
  )
  blend_group_framebuffer_over(
    fb,
    palette,
    group_fb,
    group_palette,
    node.paint.opacity,
    clip,
  )
}
