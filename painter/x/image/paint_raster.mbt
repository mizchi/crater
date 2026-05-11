///|
/// Framebuffer and paint tree rasterization for image outputs.
/// Terminal protocols are encoded by crater-painter-terminal packages.

///|
/// Render a PaintNode tree to framebuffer
fn render_paint_node(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  parent_x : Double,
  parent_y : Double,
) -> Unit {
  render_paint_node_clipped(fb, palette, node, parent_x, parent_y, None)
}

///|
/// Render a PaintNode tree to framebuffer with optional clip rect
fn render_paint_node_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  parent_x : Double,
  parent_y : Double,
  clip : ClipRect?,
) -> Unit {
  // Skip invisible nodes
  if !node.paint.should_render() {
    return
  }
  let abs_x = parent_x + node.x
  let abs_y = parent_y + node.y
  let x = abs_x.to_int()
  let y = abs_y.to_int()
  let w = node.width.to_int()
  let h = node.height.to_int()

  // Skip zero-sized nodes
  if w <= 0 || h <= 0 {
    for child in node.children {
      render_paint_node_clipped(fb, palette, child, abs_x, abs_y, clip)
    }
    return
  }

  // Skip "visually hidden" accessibility pattern:
  // Elements with clip/overflow clipping and very small size (1px x 1px)
  if node.clips_content() && w <= 1 && h <= 1 {
    return
  }

  // Skip very small elements that are likely visually hidden
  if w <= 1 && h <= 1 {
    return
  }
  if w <= 1 && node.tag == "#text" {
    return
  }

  // Skip nodes entirely outside the framebuffer
  if x >= fb.width || y >= fb.height || x + w <= 0 || y + h <= 0 {
    return
  }
  // If there's a clip rect, check if this node is fully outside it
  match clip {
    Some(c) =>
      if x >= c.x + c.w || y >= c.y + c.h || x + w <= c.x || y + h <= c.y {
        return
      }
    None => ()
  }
  if node.paint.opacity < 1.0 && !node.children.is_empty() {
    render_group_opacity_clipped(fb, palette, node, parent_x, parent_y, clip)
    return
  }

  // Compute border-radius values (negative means percentage)
  // Clamp to half of element dimensions per CSS spec
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

  // Draw background: gradient or solid color
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

  // Draw borders
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

  // Draw resolved image content before alt fallback text.
  let drew_replaced_image = if node.tag == "img" && w > 0 && h > 0 {
    match node.src {
      Some(src) =>
        render_image_src_into_region(
          fb,
          palette,
          src,
          x,
          y,
          w,
          h,
          clip,
          node.paint.opacity,
        )
      None => false
    }
  } else {
    false
  }
  if !drew_replaced_image {
    render_node_text_content(fb, palette, node, x, y, w, h, clip)
    render_node_text_decorations(fb, palette, node, x, y, w, clip)
  }

  // Compute child clip: if this node clips content, intersect with current clip
  let child_clip = if node.clips_content() {
    let node_clip : ClipRect = { x, y, w, h }
    match clip {
      None => Some(node_clip)
      Some(parent_clip) => clip_intersect(parent_clip, node_clip)
    }
  } else {
    clip
  }

  // If clip intersection is empty, skip all children
  match (node.clips_content(), child_clip) {
    (true, None) => return
    _ => ()
  }

  // Render children with (possibly narrowed) clip
  // Propagate opacity to children (CSS opacity affects entire subtree)
  if node.paint.opacity < 1.0 {
    for child in node.children {
      let child_with_opacity = {
        ..child,
        paint: {
          ..child.paint,
          opacity: child.paint.opacity * node.paint.opacity,
        },
      }
      render_paint_node_clipped(
        fb, palette, child_with_opacity, abs_x, abs_y, child_clip,
      )
    }
  } else {
    for child in node.children {
      render_paint_node_clipped(fb, palette, child, abs_x, abs_y, child_clip)
    }
  }
}

///|
/// Render PaintNode tree to framebuffer with scroll offset
pub fn render_paint_node_to_framebuffer_scrolled(
  node : @paint_model.PaintNode,
  fb : Framebuffer,
  palette : DynamicPalette,
  scroll_y : Int,
) -> Unit {
  // Fill with white background
  fb.fill_rect(0, 0, fb.width, fb.height, 0)
  // Sort by stacking order (z-index) for correct rendering
  let sorted_node = @paint_traversal.sort_tree_by_stacking_order(node)
  fill_canvas_background(fb, palette, sorted_node)
  // Render the tree with scroll offset
  render_paint_node(fb, palette, sorted_node, 0.0, -scroll_y.to_double())
}

///|
/// Render PaintNode tree to framebuffer (for use by other renderers like Kitty)
pub fn render_paint_node_to_framebuffer(
  node : @paint_model.PaintNode,
  fb : Framebuffer,
  palette : DynamicPalette,
) -> Unit {
  // Sort by stacking order (z-index) for correct rendering
  let sorted_node = @paint_traversal.sort_tree_by_stacking_order(node)
  fill_canvas_background(fb, palette, sorted_node)
  // Render the tree
  render_paint_node(fb, palette, sorted_node, 0.0, 0.0)
}
