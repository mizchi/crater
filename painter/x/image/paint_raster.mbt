///|
/// Framebuffer and paint tree rasterization for image outputs.
/// Terminal protocols are encoded by crater-painter-terminal packages.

///|
fn draw_text_decoration_line(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
) -> Unit {
  if y < 0 || y >= fb.height {
    return
  }
  for px = x; px < x + w && px < fb.width; px = px + 1 {
    if px >= 0 && pixel_in_clip(clip, px, y) {
      blend_types_color_over_pixel(fb, palette, px, y, color, opacity)
    }
  }
}

///|
fn resolve_text_render_box(
  node : @paint_model.PaintNode,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> (Int, Int, Int) {
  if node.tag == "input" {
    let inset = @cmp.maximum(2, (node.paint.font_size * 0.75).round().to_int())
    let vertical_offset = @cmp.maximum(
      0,
      ((h.to_double() - node.paint.font_size) / 2.0).round().to_int(),
    )
    (x + inset, y + vertical_offset, @cmp.maximum(0, w - inset * 2))
  } else {
    (x, y, w)
  }
}

///|
fn resolve_glyph_text_wrap_width(
  w : Int,
  h : Int,
  font_size : Double,
  text : String,
) -> Int {
  if h.to_double() <= font_size * 1.3 && text.length() <= 72 {
    0
  } else {
    w
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
    // Draw text if this is a text node
    match node.text {
      Some(text_content) => {
        let (text_x, text_y, text_w) = resolve_text_render_box(node, x, y, w, h)
        match glyph_provider_override.val {
          Some(provider) => {
            let svg_color = @svg.Color::rgb(
              node.paint.color.r,
              node.paint.color.g,
              node.paint.color.b,
            )
            let font_size = node.paint.font_size
            let wrap_width = resolve_glyph_text_wrap_width(
              text_w, h, font_size, text_content,
            )
            let _ = draw_text_with_glyphs_clipped(
              fb,
              palette,
              provider,
              text_x,
              text_y,
              text_content,
              wrap_width,
              svg_color,
              font_size,
              node.paint.line_height,
              node.paint.is_bold,
              clip,
              font_family=node.paint.font_family,
              opacity=node.paint.opacity,
              letter_spacing=node.paint.letter_spacing,
              word_spacing=node.paint.word_spacing,
              font_weight=node.paint.font_weight,
            )
          }
          None => {
            let text_idx = palette.get_or_add(
              types_color_to_image(node.paint.color),
            )
            let scale = 1
            let _ = draw_text_clipped(
              fb, text_x, text_y, text_content, text_w, text_idx, scale, clip,
            )
          }
        }
      }
      None => ()
    }
    // Draw text decorations
    match node.text {
      Some(_) => {
        let font_size = node.paint.font_size
        if node.paint.text_decoration_overline {
          draw_text_decoration_line(
            fb,
            palette,
            x,
            y + (font_size * 0.15).to_int(),
            w,
            node.paint.color,
            node.paint.opacity,
            clip,
          )
        }
        if node.paint.text_decoration_line_through {
          draw_text_decoration_line(
            fb,
            palette,
            x,
            y + (font_size * 0.6).to_int(),
            w,
            node.paint.color,
            node.paint.opacity,
            clip,
          )
        }
        if node.paint.text_decoration_underline {
          draw_text_decoration_line(
            fb,
            palette,
            x,
            y + (font_size * 1.1).to_int(),
            w,
            node.paint.color,
            node.paint.opacity,
            clip,
          )
        }
      }
      None => ()
    }
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
fn resolve_image_src(src : String) -> ResolvedImage? {
  match image_provider_override.val {
    Some(provider) =>
      match (provider.resolve)(src) {
        Some(image) => Some(image)
        None =>
          if src.has_prefix("data:image/svg+xml") {
            let svg_text = decode_svg_data_uri(src)
            if svg_text.length() > 0 {
              Some(ResolvedImage::Svg(svg_text))
            } else {
              None
            }
          } else {
            None
          }
      }
    None =>
      if src.has_prefix("data:image/svg+xml") {
        let svg_text = decode_svg_data_uri(src)
        if svg_text.length() > 0 {
          Some(ResolvedImage::Svg(svg_text))
        } else {
          None
        }
      } else {
        None
      }
  }
}

///|
fn render_image_src_into_region(
  fb : Framebuffer,
  palette : DynamicPalette,
  src : String,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
  opacity : Double,
) -> Bool {
  match resolve_image_src(src) {
    Some(ResolvedImage::Raster(image)) =>
      render_raster_image_into_region(
        fb, palette, image, x, y, w, h, clip, opacity,
      )
    Some(ResolvedImage::Svg(svg_text)) =>
      if svg_text.length() > 0 {
        render_svg_into_region(fb, palette, svg_text, x, y, w, h, clip)
        true
      } else {
        false
      }
    None => false
  }
}

///|
fn render_raster_image_into_region(
  fb : Framebuffer,
  palette : DynamicPalette,
  image : RasterImage,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
  opacity : Double,
) -> Bool {
  if image.width <= 0 ||
    image.height <= 0 ||
    w <= 0 ||
    h <= 0 ||
    image.rgba.length() < image.width * image.height * 4 {
    return false
  }
  for py = 0; py < h; py = py + 1 {
    let dst_y = y + py
    if dst_y < 0 || dst_y >= fb.height {
      continue
    }
    let src_y = (py * image.height / h).min(image.height - 1)
    for px = 0; px < w; px = px + 1 {
      let dst_x = x + px
      if dst_x < 0 || dst_x >= fb.width {
        continue
      }
      if !pixel_in_clip(clip, dst_x, dst_y) {
        continue
      }
      let src_x = (px * image.width / w).min(image.width - 1)
      let idx = (src_y * image.width + src_x) * 4
      let alpha = clamp_byte(
        (image.rgba[idx + 3].to_double() * opacity).to_int(),
      )
      if alpha <= 0 {
        continue
      }
      blend_raster_color_over_pixel(
        fb,
        palette,
        dst_x,
        dst_y,
        {
          r: clamp_byte(image.rgba[idx]),
          g: clamp_byte(image.rgba[idx + 1]),
          b: clamp_byte(image.rgba[idx + 2]),
        },
        alpha,
      )
    }
  }
  true
}

///|
/// Decode SVG data URI to SVG text
fn decode_svg_data_uri(src : String) -> String {
  // Handle data:image/svg+xml,<svg>...</svg> (URL-encoded)
  // and data:image/svg+xml;utf8,<svg>...</svg>
  let prefixes = [
    "data:image/svg+xml,", "data:image/svg+xml;utf8,", "data:image/svg+xml;charset=utf-8,",
  ]
  for prefix in prefixes {
    if src.has_prefix(prefix) {
      let encoded = src.unsafe_substring(
        start=prefix.length(),
        end=src.length(),
      )
      return url_decode_simple(encoded)
    }
  }
  // data:image/svg+xml;base64,... not handled yet
  ""
}

///|
/// Simple URL decode (%XX → char)
fn url_decode_simple(s : String) -> String {
  let buf = StringBuilder::new()
  let chars = s.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    if chars[i] == '%' && i + 2 < len {
      let hi = hex_digit(chars[i + 1])
      let lo = hex_digit(chars[i + 2])
      if hi >= 0 && lo >= 0 {
        buf.write_char((hi * 16 + lo).unsafe_to_char())
        i = i + 3
        continue
      }
    }
    buf.write_char(chars[i])
    i = i + 1
  }
  buf.to_string()
}

///|
fn hex_digit(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
/// Render SVG into a region of the framebuffer
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
  // Render SVG to temporary framebuffer at target size
  let tmp_fb = Framebuffer::new(w, h)
  let tmp_palette = DynamicPalette::new()
  tmp_fb.fill_rect(0, 0, w, h, 0)
  let camera = @svg.Camera::new(w, h)
  camera.set_position(vw / 2.0, vh / 2.0)
  let zoom = (w.to_double() / vw).min(h.to_double() / vh)
  camera.set_zoom(zoom)
  render_svg_scene_with_camera(scene, tmp_fb, tmp_palette, camera)
  // Blit temporary framebuffer into main framebuffer
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
        // Non-white pixel: map from tmp palette to main palette
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
  // CSS canvas background propagation (CSS 2.1 §14.2):
  // If root (<html>) background is transparent, use <body> background instead
  let mut canvas_bg = sorted_node.paint.background_color
  if canvas_bg.is_transparent() {
    for child in sorted_node.children {
      if child.tag == "body" && !child.paint.background_color.is_transparent() {
        canvas_bg = child.paint.background_color
        break
      }
    }
  }
  if !canvas_bg.is_transparent() {
    let bg_raster = { r: canvas_bg.r, g: canvas_bg.g, b: canvas_bg.b }
    let bg_idx = palette.get_or_add(bg_raster)
    fb.fill_rect(0, 0, fb.width, fb.height, bg_idx)
  }
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
  // CSS canvas background propagation (CSS 2.1 §14.2):
  // If root (<html>) background is transparent, use <body> background instead
  let mut canvas_bg = sorted_node.paint.background_color
  if canvas_bg.is_transparent() {
    // Look for body element among root's children
    for child in sorted_node.children {
      if child.tag == "body" && !child.paint.background_color.is_transparent() {
        canvas_bg = child.paint.background_color
        break
      }
    }
  }
  if !canvas_bg.is_transparent() {
    let bg_raster = { r: canvas_bg.r, g: canvas_bg.g, b: canvas_bg.b }
    let bg_idx = palette.get_or_add(bg_raster)
    fb.fill_rect(0, 0, fb.width, fb.height, bg_idx)
  }
  // Render the tree
  render_paint_node(fb, palette, sorted_node, 0.0, 0.0)
}
