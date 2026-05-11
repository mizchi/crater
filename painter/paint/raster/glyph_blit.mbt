///|
/// Glyph bitmap compositing helpers.

///|
fn clamp_opacity(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn blend_color_over_pixel_alpha(
  fb : Framebuffer,
  palette : DynamicPalette,
  px : Int,
  py : Int,
  color : Color,
  alpha : Double,
) -> Unit {
  let clamped = clamp_opacity(alpha)
  if clamped <= 0.0 {
    return
  }
  if clamped >= 1.0 {
    let idx = palette.get_or_add(color)
    fb.set_pixel(px, py, idx)
    return
  }
  let bg_idx = fb.pixels[py * fb.width + px]
  let bg_color = palette_color_at(palette, bg_idx)
  let a_byte = (clamped * 255.0).to_int()
  let blended = color.blend(bg_color, a_byte)
  let idx = palette.get_or_add(blended)
  fb.set_pixel(px, py, idx)
}

///|
fn blit_glyph_bitmap(
  fb : Framebuffer,
  palette : DynamicPalette,
  bitmap : GlyphBitmap,
  draw_x : Double,
  draw_y : Double,
  color : Color,
  color_idx : Int,
  opacity : Double,
  clip : ClipRect?,
) -> Unit {
  let dx = draw_x.to_int() + bitmap.offset_x
  let dy = draw_y.to_int() + bitmap.offset_y
  let has_coverage = bitmap.coverage.length() == bitmap.width * bitmap.height
  for by = 0; by < bitmap.height; by = by + 1 {
    let py = dy + by
    if py < 0 || py >= fb.height {
      continue
    }
    for bx = 0; bx < bitmap.width; bx = bx + 1 {
      let bi = by * bitmap.width + bx
      if bitmap.pixels[bi] {
        let px = dx + bx
        if px >= 0 && px < fb.width && pixel_in_clip(clip, px, py) {
          if has_coverage {
            let cov = bitmap.coverage[bi]
            let max_cov = bitmap.ss_factor * bitmap.ss_factor
            if cov >= max_cov {
              if opacity >= 1.0 {
                fb.set_pixel(px, py, color_idx)
              } else {
                blend_color_over_pixel_alpha(
                  fb, palette, px, py, color, opacity,
                )
              }
            } else {
              let alpha = cov.to_double() / max_cov.to_double() * opacity
              blend_color_over_pixel_alpha(fb, palette, px, py, color, alpha)
            }
          } else if opacity >= 1.0 {
            fb.set_pixel(px, py, color_idx)
          } else {
            blend_color_over_pixel_alpha(fb, palette, px, py, color, opacity)
          }
        }
      }
    }
  }
}
