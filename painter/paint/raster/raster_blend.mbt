///|
/// Pixel blending helpers for palette-backed raster output.

///|
fn blend_types_color_over_pixel(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int32,
  y : Int32,
  color : @types.Color,
  opacity : Double,
) -> Unit {
  let alpha = effective_alpha_byte(color, opacity)
  if alpha <= 0 {
    return
  }
  let src = types_color_to_image(color)
  if alpha >= 255 {
    let idx = palette.get_or_add(src)
    fb.set_pixel(x, y, idx)
    return
  }
  let dst_idx = fb.get_pixel(x, y)
  let dst = palette_color_at(palette, dst_idx)
  let blended = src.blend(dst, alpha)
  let idx = palette.get_or_add(blended)
  fb.set_pixel(x, y, idx)
}

///|
fn blend_raster_color_over_pixel(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int32,
  y : Int32,
  color : Color,
  alpha : Int32,
) -> Unit {
  let a = clamp_byte(alpha)
  if a <= 0 {
    return
  }
  if a >= 255 {
    let idx = palette.get_or_add(color)
    fb.set_pixel(x, y, idx)
    return
  }
  let dst_idx = fb.get_pixel(x, y)
  let dst = palette_color_at(palette, dst_idx)
  let blended = color.blend(dst, a)
  let idx = palette.get_or_add(blended)
  fb.set_pixel(x, y, idx)
}

///|
fn ensure_blend_cache_size(cache : Array[Int32], idx : Int32) -> Unit {
  while idx >= cache.length() {
    cache.push(-1)
  }
}

///|
fn cached_blended_index(
  palette : DynamicPalette,
  color : Color,
  alpha : Int32,
  dst_idx : Int32,
  cache : Array[Int32],
) -> Int32 {
  if dst_idx < 0 {
    let dst = Color::white()
    let blended = color.blend(dst, alpha)
    return palette.get_or_add(blended)
  }
  ensure_blend_cache_size(cache, dst_idx)
  match cache[dst_idx] {
    cached if cached >= 0 => cached
    _ => {
      let dst = palette_color_at(palette, dst_idx)
      let blended = color.blend(dst, alpha)
      let idx = palette.get_or_add(blended)
      cache[dst_idx] = idx
      idx
    }
  }
}

///|
fn blend_span_with_raster_color(
  fb : Framebuffer,
  palette : DynamicPalette,
  y : Int32,
  x1 : Int32,
  x2 : Int32,
  color : Color,
  alpha : Int32,
  cache : Array[Int32],
) -> Unit {
  let a = clamp_byte(alpha)
  if a <= 0 {
    return
  }
  if a >= 255 {
    let idx = palette.get_or_add(color)
    fb.fill_span(y, x1, x2, idx)
    return
  }
  if y < 0 || y >= fb.height {
    return
  }
  let cx1 = @cmp.maximum(x1, 0)
  let cx2 = @cmp.minimum(x2, fb.width)
  if cx2 <= cx1 {
    return
  }
  let row = y * fb.width
  for px = cx1; px < cx2; px = px + 1 {
    let pos = row + px
    let dst_idx = fb.pixels[pos]
    let blended_idx = cached_blended_index(palette, color, a, dst_idx, cache)
    fb.pixels[pos] = blended_idx
  }
}

///|
fn fill_rect_with_types_color(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int32,
  y : Int32,
  w : Int32,
  h : Int32,
  color : @types.Color,
  opacity : Double,
) -> Unit {
  let alpha = effective_alpha_byte(color, opacity)
  if alpha <= 0 {
    return
  }
  if alpha >= 255 {
    let idx = palette.get_or_add(types_color_to_image(color))
    fb.fill_rect(x, y, w, h, idx)
    return
  }
  let x1 = @cmp.maximum(x, 0)
  let y1 = @cmp.maximum(y, 0)
  let x2 = @cmp.minimum(x + w, fb.width)
  let y2 = @cmp.minimum(y + h, fb.height)
  if x2 <= x1 || y2 <= y1 {
    return
  }
  let src = types_color_to_image(color)
  let cache = Array::make(palette.colors.length(), -1)
  for py = y1; py < y2; py = py + 1 {
    blend_span_with_raster_color(fb, palette, py, x1, x2, src, alpha, cache)
  }
}
