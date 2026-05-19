///|
/// Generic clipped fill helpers for raster output.

///|
/// Fill a horizontal border slab as a mitred trapezoid: outer edge runs the
/// full width, the opposite edge is inset by `bl` on the left and `br` on the
/// right. `inverted=false` means the outer edge is at the top (top border);
/// `inverted=true` means the outer edge is at the bottom (bottom border).
/// Each row is rendered as a 1-px-tall fill so that mitred corners produce
/// the right diagonal — this is what lets the classic 0×0+border-trick
/// triangle actually render as a triangle rather than as a solid rectangle.
fn fill_horizontal_border_trapezoid_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  thickness : Int,
  bl : Int,
  br : Int,
  inverted : Bool,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
) -> Unit {
  if thickness <= 0 || w <= 0 {
    return
  }
  for r = 0; r < thickness; r = r + 1 {
    let t = if thickness > 0 {
      (r.to_double() + 0.5) / thickness.to_double()
    } else {
      0.0
    }
    let inset = if inverted { 1.0 - t } else { t }
    let lx = x + (bl.to_double() * inset).to_int()
    let rx = x + w - (br.to_double() * inset).to_int()
    let line_w = rx - lx
    if line_w <= 0 {
      continue
    }
    fill_rect_clipped(fb, palette, lx, y + r, line_w, 1, color, opacity, clip)
  }
}

///|
/// Fill a vertical border slab as a mitred trapezoid. Mirror of the horizontal
/// helper: the outer edge runs the full height; the opposite edge is inset by
/// `bt` on top and `bb` on the bottom. `inverted=true` places the outer edge
/// on the right (right border); `inverted=false` places it on the left.
fn fill_vertical_border_trapezoid_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  h : Int,
  thickness : Int,
  bt : Int,
  bb : Int,
  inverted : Bool,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
) -> Unit {
  if thickness <= 0 || h <= 0 {
    return
  }
  for c = 0; c < thickness; c = c + 1 {
    let t = if thickness > 0 {
      (c.to_double() + 0.5) / thickness.to_double()
    } else {
      0.0
    }
    let inset = if inverted { 1.0 - t } else { t }
    let ty = y + (bt.to_double() * inset).to_int()
    let by = y + h - (bb.to_double() * inset).to_int()
    let col_h = by - ty
    if col_h <= 0 {
      continue
    }
    fill_rect_clipped(fb, palette, x + c, ty, 1, col_h, color, opacity, clip)
  }
}

///|
/// Fill a rect clipped to the given clip rectangle
fn fill_rect_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
) -> Unit {
  match clip {
    None => fill_rect_with_types_color(fb, palette, x, y, w, h, color, opacity)
    Some(c) => {
      let cx1 = @cmp.maximum(x, c.x)
      let cy1 = @cmp.maximum(y, c.y)
      let cx2 = @cmp.minimum(x + w, c.x + c.w)
      let cy2 = @cmp.minimum(y + h, c.y + c.h)
      if cx2 > cx1 && cy2 > cy1 {
        fill_rect_with_types_color(
          fb,
          palette,
          cx1,
          cy1,
          cx2 - cx1,
          cy2 - cy1,
          color,
          opacity,
        )
      }
    }
  }
}
