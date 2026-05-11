///|
/// TUI Rendering - Convert PaintNode tree to CharBuffer
/// Implements pixel-to-character coordinate transformation

///|
/// Element scroll position (used for element-level scrollbar rendering)
pub(all) struct ElementScrollPos {
  scroll_top : Double
  scroll_height : Double
  client_height : Double
}

///|
/// Rendering context for TUI
pub struct TuiContext {
  buffer : CharBuffer
  scroll_y : Int // Scroll offset in character rows
  viewport_height : Int // Visible height in character rows
  link_regions : Array[LinkRegion] // Collected link regions
  hit_regions : Array[HitRegion] // Paint-order hit regions
  image_regions : Array[ImageRegion] // Collected image regions for graphics protocol
  focused_element_name : String? // Name of currently focused element (for :focus styling)
  dark_mode : Bool // Dark mode enabled
  element_scroll_positions : Map[String, ElementScrollPos] // Element-level scroll positions
}

///|
/// Render a PaintNode to the CharBuffer
fn render_paint_node(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  parent_x : Double,
  parent_y : Double,
  inside_link : Bool,
  current_link_source_id? : String? = None,
  inside_pre? : Bool = false,
  clip_rect? : (Double, Double, Double, Double)? = None,
) -> Unit {
  // Skip invisible nodes
  if !node.paint.should_render() {
    return
  }
  // Calculate absolute position
  let abs_x = parent_x + node.x
  let abs_y = parent_y + node.y
  // Convert to character coordinates
  let col = px_to_col(abs_x)
  let row = px_to_row(abs_y) - ctx.scroll_y
  // Use ceiling for width and height to ensure text content fits
  let w = px_to_col_width(node.width)
  let h = px_to_row_height(node.height)
  let node_rect = (abs_x, abs_y, node.width, node.height)
  let effective_clip = combine_clip_rects(
    clip_rect,
    get_local_clip_rect(node, abs_x, abs_y),
  )
  let visible_rect = match effective_clip {
    Some(clip) => intersect_pixel_rects(node_rect, clip)
    None => Some(node_rect)
  }
  // Check if we're inside a pre/code element (no text wrapping)
  // Also disable wrapping inside table cells (th/td) - cells should clip, not wrap
  let is_pre = node.tag == "pre" || node.tag == "code"
  let is_table_cell = node.tag == "th" || node.tag == "td"
  let child_inside_pre = inside_pre || is_pre || is_table_cell
  let child_link_source_id = if node.tag == "a" &&
    node.paint.pointer_events != @style.PointerEvents::None {
    extract_source_id(node.id)
  } else {
    current_link_source_id
  }
  // Skip if completely outside viewport
  if row + h < 0 || row >= ctx.viewport_height {
    // Still need to render children that might be visible
    let child_inside_link = inside_link || node.tag == "a"
    for child in node.children {
      render_paint_node(
        ctx,
        child,
        abs_x,
        abs_y,
        child_inside_link,
        current_link_source_id=child_link_source_id,
        inside_pre=child_inside_pre,
        clip_rect=effective_clip,
      )
    }
    return
  }
  // Skip zero-sized nodes
  if w <= 0 || h <= 0 {
    let child_inside_link = inside_link || node.tag == "a"
    for child in node.children {
      render_paint_node(
        ctx,
        child,
        abs_x,
        abs_y,
        child_inside_link,
        current_link_source_id=child_link_source_id,
        inside_pre=child_inside_pre,
        clip_rect=effective_clip,
      )
    }
    return
  }
  match (extract_source_id(node.id), visible_rect) {
    (Some(source_id), Some((visible_x, visible_y, visible_w, visible_h))) =>
      if node.tag != "#text" &&
        node.paint.pointer_events != @style.PointerEvents::None &&
        visible_w > 0.0 &&
        visible_h > 0.0 {
        let radius_top_left = resolve_hit_radius(
          node.paint.border_top_left_radius,
          node.width,
          node.height,
        )
        let radius_top_right = resolve_hit_radius(
          node.paint.border_top_right_radius,
          node.width,
          node.height,
        )
        let radius_bottom_right = resolve_hit_radius(
          node.paint.border_bottom_right_radius,
          node.width,
          node.height,
        )
        let radius_bottom_left = resolve_hit_radius(
          node.paint.border_bottom_left_radius,
          node.width,
          node.height,
        )
        let visual_shape = if node.visual_polygon.is_empty() {
          HitClipShape::Rect
        } else {
          HitClipShape::Polygon(
            resolve_visual_polygon(node.visual_polygon, abs_x, abs_y),
          )
        }
        let clip_shape = match node.paint.clip_path {
          @style.ClipPath::Circle(radius, center_x, center_y) => {
            let (cx, cy, r) = resolve_clip_path_circle(
              radius,
              center_x,
              center_y,
              abs_x,
              abs_y,
              node.width,
              node.height,
            )
            HitClipShape::Circle(cx, cy, r)
          }
          @style.ClipPath::Ellipse(radius_x, radius_y, center_x, center_y) => {
            let (cx, cy, rx, ry) = resolve_clip_path_ellipse(
              radius_x,
              radius_y,
              center_x,
              center_y,
              abs_x,
              abs_y,
              node.width,
              node.height,
            )
            HitClipShape::Ellipse(cx, cy, rx, ry)
          }
          @style.ClipPath::Polygon(points) =>
            HitClipShape::Polygon(
              resolve_clip_path_polygon(
                points,
                abs_x,
                abs_y,
                node.width,
                node.height,
              ),
            )
          _ => HitClipShape::Rect
        }
        ctx.hit_regions.push({
          col: px_to_col(visible_x),
          row: px_to_row(visible_y) - ctx.scroll_y,
          width: px_to_col_width(visible_w),
          height: px_to_row_height(visible_h),
          pixel_x: visible_x,
          pixel_y: visible_y,
          pixel_width: visible_w,
          pixel_height: visible_h,
          shape_x: abs_x,
          shape_y: abs_y,
          shape_width: node.width,
          shape_height: node.height,
          radius_top_left,
          radius_top_right,
          radius_bottom_right,
          radius_bottom_left,
          scroll_y: ctx.scroll_y,
          visual_shape,
          clip_shape,
          source_id,
        })
      }
    _ => ()
  }
  // Draw background if not transparent
  if !node.paint.background_color.is_transparent() {
    // Clip to viewport
    let draw_row = row.max(0)
    let draw_h = (row + h).min(ctx.viewport_height) - draw_row
    if draw_h > 0 {
      // Use CSS-computed color directly (dark mode is handled by CSS cascade)
      ctx.buffer.fill_bg(col, draw_row, w, draw_h, node.paint.background_color)
    }
  }
  // Handle image placeholder (check BEFORE text to ensure background is drawn)
  if node.tag == "img" && w > 0 && h > 0 {
    let draw_row = row.max(0)
    let draw_h = (row + h).min(ctx.viewport_height) - draw_row
    // If image has src, record for graphics protocol rendering
    match node.src {
      Some(src) =>
        if draw_h > 0 {
          let source_id = match extract_source_id(node.id) {
            Some(id) => id
            None => node.id
          }
          // Fill background color (from CSS) so it shows even without graphics
          if !node.paint.background_color.is_transparent() {
            ctx.buffer.fill_bg(
              col,
              draw_row,
              w,
              draw_h,
              node.paint.background_color,
            )
          }
          // Record image region for kitty/sixel rendering
          ctx.image_regions.push({
            col,
            row: draw_row,
            width: w,
            height: draw_h,
            pixel_width: node.width,
            pixel_height: node.height,
            src,
            source_id,
          })
        }
      None => {
        // No src: show placeholder
        let img_bg = @types.Color::rgb(200, 200, 210)
        let border_color = @types.Color::rgb(150, 150, 160)
        if draw_h > 0 {
          ctx.buffer.fill_bg(col, draw_row, w, draw_h, img_bg)
          let border_style : TextStyle = {
            fg: border_color,
            bg: img_bg,
            bold: false,
            underline: false,
          }
          if draw_row >= 0 && draw_row < ctx.viewport_height {
            let border_line = String::make(w, '-')
            let _ = ctx.buffer.write_text(
              col, draw_row, border_line, border_style, w,
            )
          }
          let bottom_row = draw_row + draw_h - 1
          if bottom_row >= 0 &&
            bottom_row < ctx.viewport_height &&
            bottom_row > draw_row {
            let border_line = String::make(w, '-')
            let _ = ctx.buffer.write_text(
              col, bottom_row, border_line, border_style, w,
            )
          }
        }
        // Draw alt text (or "[IMG]" if no alt) centered
        if draw_row >= 0 && draw_row < ctx.viewport_height && draw_h > 0 {
          let label = match node.text {
            Some(alt) => if alt.length() > 0 { alt } else { "[IMG]" }
            None => "[IMG]"
          }
          let label_style : TextStyle = {
            fg: @types.Color::rgb(60, 60, 70),
            bg: img_bg,
            bold: false,
            underline: false,
          }
          let center_row = draw_row + draw_h / 2
          if center_row >= 0 && center_row < ctx.viewport_height {
            let max_label_width = w - 2
            let visible_label = if label.to_array().length() > max_label_width &&
              max_label_width > 3 {
              let chars = label.to_array()
              let truncated_chars = chars[:max_label_width - 3]
              truncated_chars.to_string() + "..."
            } else {
              label
            }
            let label_len = visible_label.to_array().length()
            let label_col = col + (w - label_len) / 2
            if label_col >= 0 {
              let _ = ctx.buffer.write_text(
                label_col.max(col),
                center_row,
                visible_label,
                label_style,
                w,
              )
            }
          }
        }
      }
    }
  } else {
    // Draw text content for non-image elements
    match node.text {
      Some(text_content) =>
        if row >= 0 && row < ctx.viewport_height {
          // Check if this is a link or inside a link - force underline and blue color
          let is_link = node.tag == "a" || inside_link
          // Check if this element is currently focused
          let is_focused = match ctx.focused_element_name {
            Some(focused_name) => is_link && text_content == focused_name
            None => false
          }
          let (fg_color, bg_color, use_underline, use_bold) = if is_focused {
            // Focus styling: reverse video effect (white text on blue background)
            (
              @types.Color::rgb(255, 255, 255),
              @types.Color::rgb(0, 100, 200),
              false,
              true,
            )
          } else if is_link {
            // Force blue color and underline for links in TUI mode
            // This overrides site CSS to ensure links are always visible
            (
              @types.Color::rgb(0, 0, 238),
              node.paint.background_color,
              true,
              false,
            )
          } else {
            // Use CSS-computed colors directly (dark mode is handled by CSS cascade)
            (node.paint.color, node.paint.background_color, false, false)
          }
          let style : TextStyle = {
            fg: fg_color,
            bg: bg_color,
            bold: use_bold,
            underline: use_underline,
          }
          // Calculate text display width (accounts for wide characters like CJK)
          let text_display_width = calculate_text_display_width(text_content)
          // Effective width ensures text is not clipped due to font-size differences
          let effective_width = w.max(text_display_width)
          // Check if text needs wrapping: exceeds container width
          // CJK text can wrap at any character boundary, so we don't require spaces
          let needs_wrapping = text_display_width > w
          // Use preformatted text for pre/code elements to preserve formatting
          // This respects newlines but doesn't auto-wrap at word boundaries
          if child_inside_pre {
            let _ = ctx.buffer.write_text_pre(
              col,
              row,
              text_content,
              style,
              effective_width,
              (row + h).min(ctx.viewport_height) - row,
            )
          } else if needs_wrapping {
            // Text with spaces that exceeds width - use w for proper line wrapping
            let _ = ctx.buffer.write_text_wrapped(
              col,
              row,
              text_content,
              style,
              w,
              (row + h).min(ctx.viewport_height) - row,
            )
          } else {
            // Single word or short text - use effective_width to prevent clipping
            let _ = ctx.buffer.write_text(
              col, row, text_content, style, effective_width,
            )
          }
          // Collect link region for hit testing
          if is_link && w > 0 && h > 0 {
            match child_link_source_id {
              Some(source_id) => {
                let text_len = text_content.to_array().length()
                let link_col = match visible_rect {
                  Some((visible_x, _, _, _)) => px_to_col(visible_x)
                  None => col
                }
                let link_row = match visible_rect {
                  Some((_, visible_y, _, _)) =>
                    px_to_row(visible_y) - ctx.scroll_y
                  None => row
                }
                let link_width = match visible_rect {
                  Some((_, _, visible_w, _)) =>
                    text_len.min(px_to_col_width(visible_w))
                  None => text_len.min(w)
                }
                let link_height = match visible_rect {
                  Some((_, _, _, visible_h)) => px_to_row_height(visible_h)
                  None => 1
                }
                ctx.link_regions.push({
                  col: link_col,
                  row: link_row,
                  width: link_width,
                  height: link_height,
                  text: text_content,
                  source_id,
                })
              }
              None => ()
            }
          }
        }
      None => ()
    }
  }
  // Render children - pass inside_link and inside_pre flags
  let child_inside_link = inside_link || node.tag == "a"
  for child in node.children {
    render_paint_node(
      ctx,
      child,
      abs_x,
      abs_y,
      child_inside_link,
      current_link_source_id=child_link_source_id,
      inside_pre=child_inside_pre,
      clip_rect=effective_clip,
    )
  }
  // Draw scrollbar for scrollable elements
  if node.is_scrollable() && h >= 3 {
    // Get scroll position from context (default to 0 if not found)
    let scroll_pos = match ctx.element_scroll_positions.get(node.id) {
      Some(pos) => pos.scroll_top.to_int()
      None => 0
    }
    let content_height = px_to_row_height(node.scroll_height)
    let visible_height = h
    // Draw scrollbar on the right edge of the element
    let scrollbar_col = col + w - 1
    let scrollbar_row = row.max(0)
    let scrollbar_height = (row + h).min(ctx.viewport_height) - scrollbar_row
    if scrollbar_height >= 3 && content_height > visible_height {
      draw_scrollbar(
        ctx.buffer,
        scrollbar_col,
        scrollbar_row,
        scrollbar_height,
        scroll_pos,
        content_height,
        visible_height,
      )
    }
  }
}
