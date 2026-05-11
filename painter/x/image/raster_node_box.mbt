///|
/// CSS box decoration rendering for PaintNode rasterization.

///|
fn render_node_box_decorations(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
) -> Unit {
  let min_dim = @cmp.minimum(w, h)
  let max_r = min_dim / 2
  let tl_r = resolve_radius(node.paint.border_top_left_radius, min_dim).min(
    max_r,
  )
  let tr_r = resolve_radius(node.paint.border_top_right_radius, min_dim).min(
    max_r,
  )
  let br_r = resolve_radius(node.paint.border_bottom_right_radius, min_dim).min(
    max_r,
  )
  let bl_r = resolve_radius(node.paint.border_bottom_left_radius, min_dim).min(
    max_r,
  )
  let has_radius = tl_r > 0 || tr_r > 0 || br_r > 0 || bl_r > 0

  for shadow in node.paint.box_shadows {
    if shadow.inset || shadow.color.is_transparent() {
      continue
    }
    let spread = shadow.spread_radius.to_int()
    let blur = shadow.blur_radius.to_int()
    let shadow_x = x + shadow.offset_x.to_int() - spread
    let shadow_y = y + shadow.offset_y.to_int() - spread
    let shadow_w = w + spread * 2
    let shadow_h = h + spread * 2
    fill_blurred_box_shadow_clipped(
      fb,
      palette,
      shadow_x,
      shadow_y,
      shadow_w,
      shadow_h,
      shadow.color,
      node.paint.opacity,
      clip,
      spread,
      blur,
      tl_r,
      tr_r,
      br_r,
      bl_r,
    )
  }

  match node.paint.background_image {
    @types.Gradient(grad) =>
      fill_linear_gradient_clipped(
        fb,
        palette,
        x,
        y,
        w,
        h,
        grad,
        node.paint.opacity,
        clip,
        tl_r,
        tr_r,
        br_r,
        bl_r,
      )
    @types.None =>
      if !node.paint.background_color.is_transparent() {
        if has_radius {
          fill_rounded_rect_clipped(
            fb,
            palette,
            x,
            y,
            w,
            h,
            node.paint.background_color,
            node.paint.opacity,
            clip,
            tl_r,
            tr_r,
            br_r,
            bl_r,
          )
        } else {
          fill_rect_clipped(
            fb,
            palette,
            x,
            y,
            w,
            h,
            node.paint.background_color,
            node.paint.opacity,
            clip,
          )
        }
      }
  }

  let bt = node.paint.border_top_width.to_int()
  let br = node.paint.border_right_width.to_int()
  let bb = node.paint.border_bottom_width.to_int()
  let bl = node.paint.border_left_width.to_int()
  let opacity = node.paint.opacity
  let rounded_border_drawn = if can_draw_uniform_rounded_border_ring(
      node, bt, br, bb, bl, has_radius,
    ) {
    draw_uniform_rounded_border_ring_clipped(
      fb, palette, node, x, y, w, h, bt, clip, tl_r, tr_r, br_r, bl_r,
    )
    true
  } else {
    false
  }
  if !rounded_border_drawn &&
    bt > 0 &&
    !node.paint.border_top_color.is_transparent() {
    fill_rect_clipped(
      fb,
      palette,
      x,
      y,
      w,
      bt,
      node.paint.border_top_color,
      opacity,
      clip,
    )
  }
  if !rounded_border_drawn &&
    bb > 0 &&
    !node.paint.border_bottom_color.is_transparent() {
    fill_rect_clipped(
      fb,
      palette,
      x,
      y + h - bb,
      w,
      bb,
      node.paint.border_bottom_color,
      opacity,
      clip,
    )
  }
  if !rounded_border_drawn &&
    bl > 0 &&
    !node.paint.border_left_color.is_transparent() {
    fill_rect_clipped(
      fb,
      palette,
      x,
      y + bt,
      bl,
      h - bt - bb,
      node.paint.border_left_color,
      opacity,
      clip,
    )
  }
  if !rounded_border_drawn &&
    br > 0 &&
    !node.paint.border_right_color.is_transparent() {
    fill_rect_clipped(
      fb,
      palette,
      x + w - br,
      y + bt,
      br,
      h - bt - bb,
      node.paint.border_right_color,
      opacity,
      clip,
    )
  }
}
