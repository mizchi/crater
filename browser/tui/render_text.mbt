///|
/// TUI text rendering helpers.

///|
fn render_text_node(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  col : Int,
  row : Int,
  w : Int,
  h : Int,
  inside_link : Bool,
  child_link_source_id : String?,
  child_inside_pre : Bool,
  visible_rect : (Double, Double, Double, Double)?,
) -> Unit {
  match node.text {
    Some(text_content) =>
      if row >= 0 && row < ctx.viewport_height {
        let (style, is_link) = resolve_text_style(
          ctx, node, text_content, inside_link,
        )
        write_text_content(
          ctx, text_content, col, row, w, h, style, child_inside_pre,
        )
        collect_link_region(
          ctx, text_content, child_link_source_id, is_link, col, row, w, h, visible_rect,
        )
      }
    None => ()
  }
}

///|
fn resolve_text_style(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  text_content : String,
  inside_link : Bool,
) -> (TextStyle, Bool) {
  let is_link = node.tag == "a" || inside_link
  let is_focused = match ctx.focused_element_name {
    Some(focused_name) => is_link && text_content == focused_name
    None => false
  }
  let (fg_color, bg_color, use_underline, use_bold) = if is_focused {
    (
      @types.Color::rgb(255, 255, 255),
      @types.Color::rgb(0, 100, 200),
      false,
      true,
    )
  } else if is_link {
    (@types.Color::rgb(0, 0, 238), node.paint.background_color, true, false)
  } else {
    (node.paint.color, node.paint.background_color, false, false)
  }
  (
    { fg: fg_color, bg: bg_color, bold: use_bold, underline: use_underline },
    is_link,
  )
}

///|
fn write_text_content(
  ctx : TuiContext,
  text_content : String,
  col : Int,
  row : Int,
  w : Int,
  h : Int,
  style : TextStyle,
  child_inside_pre : Bool,
) -> Unit {
  let text_display_width = calculate_text_display_width(text_content)
  let effective_width = w.max(text_display_width)
  let needs_wrapping = text_display_width > w
  let max_rows = (row + h).min(ctx.viewport_height) - row
  if child_inside_pre {
    let _ = ctx.buffer.write_text_pre(
      col, row, text_content, style, effective_width, max_rows,
    )
  } else if needs_wrapping {
    let _ = ctx.buffer.write_text_wrapped(
      col, row, text_content, style, w, max_rows,
    )
  } else {
    let _ = ctx.buffer.write_text(
      col, row, text_content, style, effective_width,
    )
  }
}

///|
fn collect_link_region(
  ctx : TuiContext,
  text_content : String,
  child_link_source_id : String?,
  is_link : Bool,
  col : Int,
  row : Int,
  w : Int,
  h : Int,
  visible_rect : (Double, Double, Double, Double)?,
) -> Unit {
  if !(is_link && w > 0 && h > 0) {
    return
  }
  match child_link_source_id {
    Some(source_id) => {
      let text_len = text_content.to_array().length()
      let link_col = match visible_rect {
        Some((visible_x, _, _, _)) => px_to_col(visible_x)
        None => col
      }
      let link_row = match visible_rect {
        Some((_, visible_y, _, _)) => px_to_row(visible_y) - ctx.scroll_y
        None => row
      }
      let link_width = match visible_rect {
        Some((_, _, visible_w, _)) => text_len.min(px_to_col_width(visible_w))
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
