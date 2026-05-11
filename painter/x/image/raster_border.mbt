///|
/// Border radius and uniform rounded border raster helpers.

///|
/// Resolve border-radius value: negative means percentage of reference dimension
fn resolve_radius(val : Double, ref_dim : Int) -> Int {
  if val < 0.0 {
    // Negative encodes percentage: -0.5 means 50%
    let frac = -val
    (frac * ref_dim.to_double()).to_int()
  } else {
    val.to_int()
  }
}

///|
fn same_types_color(a : @types.Color, b : @types.Color) -> Bool {
  a.r == b.r && a.g == b.g && a.b == b.b && (a.a - b.a).abs() < 0.000001
}

///|
fn can_draw_uniform_rounded_border_ring(
  node : @paint_model.PaintNode,
  bt : Int,
  br : Int,
  bb : Int,
  bl : Int,
  has_radius : Bool,
) -> Bool {
  let solid_background = match node.paint.background_image {
    @types.None => true
    @types.Gradient(_) => false
  }
  has_radius &&
  bt > 0 &&
  bt == br &&
  bt == bb &&
  bt == bl &&
  !node.paint.border_top_color.is_transparent() &&
  same_types_color(node.paint.border_top_color, node.paint.border_right_color) &&
  same_types_color(node.paint.border_top_color, node.paint.border_bottom_color) &&
  same_types_color(node.paint.border_top_color, node.paint.border_left_color) &&
  !node.paint.background_color.is_transparent() &&
  solid_background
}

///|
fn draw_uniform_rounded_border_ring_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  border_width : Int,
  clip : ClipRect?,
  tl_r : Int,
  tr_r : Int,
  br_r : Int,
  bl_r : Int,
) -> Unit {
  fill_rounded_rect_clipped(
    fb,
    palette,
    x,
    y,
    w,
    h,
    node.paint.border_top_color,
    node.paint.opacity,
    clip,
    tl_r,
    tr_r,
    br_r,
    bl_r,
  )
  let inner_w = w - border_width * 2
  let inner_h = h - border_width * 2
  if inner_w <= 0 || inner_h <= 0 {
    return
  }
  fill_rounded_rect_clipped(
    fb,
    palette,
    x + border_width,
    y + border_width,
    inner_w,
    inner_h,
    node.paint.background_color,
    node.paint.opacity,
    clip,
    @cmp.maximum(tl_r - border_width, 0),
    @cmp.maximum(tr_r - border_width, 0),
    @cmp.maximum(br_r - border_width, 0),
    @cmp.maximum(bl_r - border_width, 0),
  )
}
