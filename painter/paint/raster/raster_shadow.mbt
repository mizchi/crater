///|
/// Box shadow raster fill helpers.

///|
fn fill_box_shadow_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
  spread : Int,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Unit {
  if w <= 0 || h <= 0 || color.is_transparent() {
    return
  }
  let draw_tl = @cmp.maximum(tl + spread, 0)
  let draw_tr = @cmp.maximum(tr + spread, 0)
  let draw_br = @cmp.maximum(br + spread, 0)
  let draw_bl = @cmp.maximum(bl + spread, 0)
  let has_radius = draw_tl > 0 || draw_tr > 0 || draw_br > 0 || draw_bl > 0
  if has_radius {
    fill_rounded_rect_clipped(
      fb, palette, x, y, w, h, color, opacity, clip, draw_tl, draw_tr, draw_br, draw_bl,
    )
  } else {
    fill_rect_clipped(fb, palette, x, y, w, h, color, opacity, clip)
  }
}

///|
fn blurred_shadow_layer_count(blur : Int) -> Int {
  let by_radius = blur / 8 + 4
  if by_radius < 4 {
    4
  } else if by_radius > 12 {
    12
  } else {
    by_radius
  }
}

///|
fn fill_blurred_box_shadow_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
  spread : Int,
  blur : Int,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Unit {
  if blur <= 0 {
    fill_box_shadow_clipped(
      fb, palette, x, y, w, h, color, opacity, clip, spread, tl, tr, br, bl,
    )
    return
  }
  let steps = blurred_shadow_layer_count(blur)
  let layer_opacity = opacity / steps.to_double()
  for i = steps; i > 0; i = i - 1 {
    let expansion = (blur.to_double() * i.to_double() / steps.to_double()).to_int()
    fill_box_shadow_clipped(
      fb,
      palette,
      x - expansion,
      y - expansion,
      w + expansion * 2,
      h + expansion * 2,
      color,
      layer_opacity,
      clip,
      spread + expansion,
      tl,
      tr,
      br,
      bl,
    )
  }
}
