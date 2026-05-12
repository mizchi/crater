///|
/// TUI image rendering helpers.

///|
fn render_image_node(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  col : Int,
  row : Int,
  w : Int,
  h : Int,
) -> Unit {
  let draw_row = row.max(0)
  let draw_h = (row + h).min(ctx.viewport_height) - draw_row
  match node.src {
    Some(src) => render_image_region(ctx, node, col, draw_row, w, draw_h, src)
    None => draw_image_placeholder(ctx, node, col, draw_row, w, draw_h)
  }
}

///|
fn render_image_region(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  col : Int,
  draw_row : Int,
  w : Int,
  draw_h : Int,
  src : String,
) -> Unit {
  if draw_h <= 0 {
    return
  }
  let source_id = match extract_source_id(node.id) {
    Some(id) => id
    None => node.id
  }
  // Keep CSS background visible when terminal image protocols are unavailable.
  if !node.paint.background_color.is_transparent() {
    ctx.buffer.fill_bg(col, draw_row, w, draw_h, node.paint.background_color)
  }
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

///|
fn draw_image_placeholder(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  col : Int,
  draw_row : Int,
  w : Int,
  draw_h : Int,
) -> Unit {
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
    draw_image_placeholder_border(ctx, col, draw_row, w, draw_h, border_style)
  }
  draw_image_placeholder_label(ctx, node, col, draw_row, w, draw_h, img_bg)
}

///|
fn draw_image_placeholder_border(
  ctx : TuiContext,
  col : Int,
  draw_row : Int,
  w : Int,
  draw_h : Int,
  border_style : TextStyle,
) -> Unit {
  if draw_row >= 0 && draw_row < ctx.viewport_height {
    let border_line = String::make(w, '-')
    let _ = ctx.buffer.write_text(col, draw_row, border_line, border_style, w)
  }
  let bottom_row = draw_row + draw_h - 1
  if bottom_row >= 0 &&
    bottom_row < ctx.viewport_height &&
    bottom_row > draw_row {
    let border_line = String::make(w, '-')
    let _ = ctx.buffer.write_text(col, bottom_row, border_line, border_style, w)
  }
}

///|
fn draw_image_placeholder_label(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  col : Int,
  draw_row : Int,
  w : Int,
  draw_h : Int,
  img_bg : @types.Color,
) -> Unit {
  if draw_row < 0 || draw_row >= ctx.viewport_height || draw_h <= 0 {
    return
  }
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
