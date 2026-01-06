///|
/// TUI Rendering - Convert PaintNode tree to CharBuffer
/// Implements pixel-to-character coordinate transformation

///|
/// Font metrics for coordinate conversion
/// These match the sixel renderer's assumptions
let font_width : Double = 8.0

///|
let font_height : Double = 16.0

///|
/// Convert pixel X to character column
fn px_to_col(px : Double) -> Int {
  (px / font_width).to_int()
}

///|
/// Convert pixel Y to character row
fn px_to_row(px : Double) -> Int {
  (px / font_height).to_int()
}

///|
/// Rendering context for TUI
pub struct TuiContext {
  buffer : CharBuffer
  scroll_y : Int // Scroll offset in character rows
  viewport_height : Int // Visible height in character rows
}

///|
/// Render a PaintNode to the CharBuffer
fn render_paint_node(
  ctx : TuiContext,
  node : @paint.PaintNode,
  parent_x : Double,
  parent_y : Double,
) -> Unit {
  // Skip invisible nodes
  if not(node.paint.should_render()) {
    return
  }
  // Calculate absolute position
  let abs_x = parent_x + node.x
  let abs_y = parent_y + node.y
  // Convert to character coordinates
  let col = px_to_col(abs_x)
  let row = px_to_row(abs_y) - ctx.scroll_y
  let w = px_to_col(node.width)
  let h = px_to_row(node.height)
  // Skip if completely outside viewport
  if row + h < 0 || row >= ctx.viewport_height {
    // Still need to render children that might be visible
    for child in node.children {
      render_paint_node(ctx, child, abs_x, abs_y)
    }
    return
  }
  // Skip zero-sized nodes
  if w <= 0 || h <= 0 {
    for child in node.children {
      render_paint_node(ctx, child, abs_x, abs_y)
    }
    return
  }
  // Draw background if not transparent
  if not(node.paint.background_color.is_transparent()) {
    // Clip to viewport
    let draw_row = row.max(0)
    let draw_h = (row + h).min(ctx.viewport_height) - draw_row
    if draw_h > 0 {
      ctx.buffer.fill_bg(col, draw_row, w, draw_h, node.paint.background_color)
    }
  }
  // Handle image placeholder (check BEFORE text to ensure background is drawn)
  if node.tag == "img" && w > 0 && h > 0 {
    // Use a more visible background color for image placeholder
    let img_bg = @types.Color::rgb(200, 200, 210)
    let border_color = @types.Color::rgb(150, 150, 160)
    let draw_row = row.max(0)
    let draw_h = (row + h).min(ctx.viewport_height) - draw_row
    if draw_h > 0 {
      // Fill background
      ctx.buffer.fill_bg(col, draw_row, w, draw_h, img_bg)
      // Draw top and bottom borders with darker color
      let border_style : TextStyle = {
        fg: border_color,
        bg: img_bg,
        bold: false,
        underline: false,
      }
      // Top border
      if draw_row >= 0 && draw_row < ctx.viewport_height {
        let border_line = String::make(w, '-')
        let _ = ctx.buffer.write_text(col, draw_row, border_line, border_style, w)
      }
      // Bottom border
      let bottom_row = draw_row + draw_h - 1
      if bottom_row >= 0 && bottom_row < ctx.viewport_height && bottom_row > draw_row {
        let border_line = String::make(w, '-')
        let _ = ctx.buffer.write_text(col, bottom_row, border_line, border_style, w)
      }
    }
    // Draw alt text (or "[IMG]" if no alt) centered in the image area
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
      // Center vertically (middle row of the image area)
      let center_row = draw_row + draw_h / 2
      if center_row >= 0 && center_row < ctx.viewport_height {
        // Calculate visible label width (truncate if needed)
        let max_label_width = w - 2 // Leave 1 char margin on each side
        let visible_label = if label.to_array().length() > max_label_width && max_label_width > 3 {
          // Truncate with "..."
          let chars = label.to_array()
          let truncated_chars = chars[:max_label_width - 3]
          truncated_chars.to_string() + "..."
        } else {
          label
        }
        let label_len = visible_label.to_array().length()
        // Center horizontally
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
  } else {
    // Draw text content for non-image elements
    match node.text {
      Some(text_content) =>
        if row >= 0 && row < ctx.viewport_height {
          let style : TextStyle = {
            fg: node.paint.color,
            bg: node.paint.background_color,
            bold: false,
            underline: false,
          }
          let _ = ctx.buffer.write_text_wrapped(
            col,
            row,
            text_content,
            style,
            w,
            (row + h).min(ctx.viewport_height) - row,
          )
        }
      None => ()
    }
  }
  // Render children
  for child in node.children {
    render_paint_node(ctx, child, abs_x, abs_y)
  }
}

///|
/// Render a Node + Layout tree to ANSI string
pub fn render_to_ansi(
  node : @node.Node,
  layout : @node.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> String {
  // Create character buffer
  let buf = CharBuffer::new(width, height)
  // Clear with white background
  let white_cell : CharCell = {
    char: ' ',
    fg: @types.Color::black(),
    bg: @types.Color::white(),
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(0, 0, width, height, white_cell)
  // Convert to PaintNode
  let paint_node = @paint.from_node_and_layout(node, layout)
  // Sort by stacking order
  let sorted = @paint.sort_tree_by_stacking_order(paint_node)
  // Create context
  let ctx : TuiContext = { buffer: buf, scroll_y, viewport_height: height }
  // Render
  render_paint_node(ctx, sorted, 0.0, 0.0)
  // Convert to ANSI
  buffer_to_ansi(buf)
}

///|
/// Render a Node + Layout tree with status bar
pub fn render_to_ansi_with_status(
  node : @node.Node,
  layout : @node.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  url : String,
  link_count : Int,
  focused_link : Int,
) -> String {
  // Reserve last row for status bar
  let content_height = height - 1
  // Create character buffer
  let buf = CharBuffer::new(width, height)
  // Clear with white background
  let white_cell : CharCell = {
    char: ' ',
    fg: @types.Color::black(),
    bg: @types.Color::white(),
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(0, 0, width, content_height, white_cell)
  // Convert to PaintNode
  let paint_node = @paint.from_node_and_layout(node, layout)
  // Sort by stacking order
  let sorted = @paint.sort_tree_by_stacking_order(paint_node)
  // Create context
  let ctx : TuiContext = {
    buffer: buf,
    scroll_y,
    viewport_height: content_height,
  }
  // Render content
  render_paint_node(ctx, sorted, 0.0, 0.0)
  // Draw status bar
  draw_status_bar(buf, content_height, url, link_count, focused_link)
  // Convert to ANSI
  buffer_to_ansi(buf)
}

///|
/// Get total content height in character rows
pub fn get_content_height_chars(layout : @node.Layout) -> Int {
  px_to_row(layout.height)
}
