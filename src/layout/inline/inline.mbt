///|
/// Inline Formatting Context (IFC) implementation
/// Handles horizontal layout of inline and inline-block elements

///|
/// A single line box containing inline-level content
priv struct LineBox {
  items : Array[LineItem] // Items on this line
  mut width : Double // Current width of the line
  mut height : Double // Height of the line (max of all items)
  mut baseline : Double // Distance from top of line box to baseline
}

///|
/// An item positioned within a line box
priv struct LineItem {
  index : Int // Original child index
  layout : @types.Layout // Computed layout
  baseline : Double // Distance from top of item to its baseline
}

///|
fn LineBox::new() -> LineBox {
  { items: [], width: 0.0, height: 0.0, baseline: 0.0 }
}

///|
/// Resolve inset dimension (left/right/top/bottom) against containing size.
fn resolve_inset_dimension(
  dim : @types.Dimension,
  available : Double,
) -> Double? {
  match dim {
    @types.Length(v) => Some(v)
    @types.Percent(p) => Some(available * p)
    _ => None
  }
}

///|
priv struct WrappedTextMetrics {
  line_count : Int
  last_line_width : Double
}

///|
fn is_wide_char(c : Char) -> Bool {
  let cp = c.to_int()
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  (cp >= 0x3040 && cp <= 0x309F) ||
  (cp >= 0x30A0 && cp <= 0x30FF) ||
  (cp >= 0xAC00 && cp <= 0xD7AF) ||
  (cp >= 0xFF00 && cp <= 0xFFEF) ||
  (cp >= 0x3000 && cp <= 0x303F)
}

///|
fn char_display_width(c : Char) -> Int {
  if is_wide_char(c) {
    2
  } else {
    1
  }
}

///|
fn place_word_with_wrap(
  lines : Int,
  line_width : Int,
  word_width : Int,
  cols_available : Int,
  needs_space : Bool,
) -> (Int, Int) {
  if cols_available <= 0 {
    return (lines, line_width)
  }
  let mut new_lines = lines
  let mut new_line_width = line_width
  let mut space_width = 0
  if needs_space && new_line_width > 0 {
    space_width = 1
  }
  if new_line_width > 0 &&
    new_line_width + space_width + word_width <= cols_available {
    new_line_width = new_line_width + space_width + word_width
    return (new_lines, new_line_width)
  }
  if new_line_width > 0 {
    new_lines = new_lines + 1
    new_line_width = 0
  }
  if word_width <= cols_available {
    return (new_lines, word_width)
  }
  let full_lines = word_width / cols_available
  let remainder = word_width % cols_available
  if remainder == 0 {
    if full_lines > 0 {
      new_lines = new_lines + full_lines - 1
      new_line_width = cols_available
    } else {
      new_line_width = 0
    }
  } else {
    new_lines = new_lines + full_lines
    new_line_width = remainder
  }
  (new_lines, new_line_width)
}

///|
fn estimate_wrapped_text_metrics(
  node : @node.Node,
  available_width : Double,
) -> WrappedTextMetrics? {
  match node.text {
    Some(raw_text) => {
      let text = raw_text.trim().to_string()
      if text.is_empty() || node.style.writing_mode.is_vertical() {
        return None
      }
      let font_size = node.style.font_size
      let char_width = if font_size > 0.0 { font_size * 0.5 } else { 0.0 }
      if char_width <= 0.0 {
        return None
      }
      let no_wrap = match node.style.white_space {
        @style.WhiteSpace::Nowrap => true
        _ => false
      }
      let use_word_wrap = match node.style.white_space {
        @style.WhiteSpace::Normal | @style.WhiteSpace::PreLine => true
        _ => false
      }
      let mut cols_available = if no_wrap {
        1000000
      } else if available_width > 0.0 {
        (available_width / char_width).to_int()
      } else {
        80
      }
      if cols_available <= 0 {
        cols_available = 80
      }

      let mut total_lines = 1
      let mut last_line_cols = 0
      if use_word_wrap && not(no_wrap) {
        let mut current_line_width = 0
        let mut current_word_width = 0
        let mut has_pending_space = false
        for c in text.iter() {
          if c == '\n' {
            if current_word_width > 0 {
              let (l, w) = place_word_with_wrap(
                total_lines, current_line_width, current_word_width, cols_available,
                has_pending_space,
              )
              total_lines = l
              current_line_width = w
              current_word_width = 0
            }
            total_lines = total_lines + 1
            current_line_width = 0
            has_pending_space = false
          } else if c == ' ' || c == '\t' {
            if current_word_width > 0 {
              let (l, w) = place_word_with_wrap(
                total_lines, current_line_width, current_word_width, cols_available,
                has_pending_space,
              )
              total_lines = l
              current_line_width = w
              current_word_width = 0
            }
            has_pending_space = true
          } else {
            current_word_width = current_word_width + char_display_width(c)
          }
        }
        if current_word_width > 0 {
          let (l, w) = place_word_with_wrap(
            total_lines, current_line_width, current_word_width, cols_available,
            has_pending_space,
          )
          total_lines = l
          current_line_width = w
        }
        last_line_cols = current_line_width
      } else {
        let mut current_line_width = 0
        total_lines = 0
        for c in text.iter() {
          if c == '\n' {
            let line_visual_lines = if cols_available > 0 &&
              current_line_width > 0 {
              (current_line_width + cols_available - 1) / cols_available
            } else {
              1
            }
            total_lines = total_lines + line_visual_lines
            current_line_width = 0
          } else if c == ' ' || c == '\t' {
            current_line_width = current_line_width + 1
          } else {
            current_line_width = current_line_width + char_display_width(c)
          }
        }
        let last_line_visual = if cols_available > 0 && current_line_width > 0 {
          (current_line_width + cols_available - 1) / cols_available
        } else {
          1
        }
        total_lines = total_lines + last_line_visual
        if cols_available > 0 && current_line_width > cols_available {
          last_line_cols = current_line_width % cols_available
          if last_line_cols == 0 {
            last_line_cols = cols_available
          }
        } else {
          last_line_cols = current_line_width
        }
      }
      Some({
        line_count: if total_lines > 0 {
          total_lines
        } else {
          1
        },
        last_line_width: last_line_cols.to_double() * char_width,
      })
    }
    None => None
  }
}

///|
/// Add an item to the line box
fn LineBox::add_item(
  self : LineBox,
  index : Int,
  layout : @types.Layout,
  baseline : Double,
  margin_left : Double,
  margin_right : Double,
) -> Unit {
  self.items.push({ index, layout, baseline })
  self.width = self.width + layout.width + margin_left + margin_right

  // Update line box baseline and height based on baseline alignment
  // Items are aligned by their baselines, so we need to track:
  // - max distance from top to baseline (above baseline)
  // - max distance from baseline to bottom (below baseline)
  let above_baseline = baseline
  let below_baseline = layout.height - baseline
  if self.items.length() == 1 {
    // First item sets the initial baseline
    self.baseline = above_baseline
    self.height = layout.height
  } else {
    // Adjust line box to accommodate this item's baseline
    if above_baseline > self.baseline {
      // This item has more content above baseline
      self.height = self.height + (above_baseline - self.baseline)
      self.baseline = above_baseline
    }
    let current_below = self.height - self.baseline
    if below_baseline > current_below {
      // This item has more content below baseline
      self.height = self.baseline + below_baseline
    }
  }
}

///|
/// Check if an item can fit in this line
fn LineBox::can_fit(
  self : LineBox,
  item_width : Double,
  margin_left : Double,
  margin_right : Double,
  available_width : Double,
) -> Bool {
  self.width + item_width + margin_left + margin_right <= available_width ||
  self.items.length() == 0 // Always fit at least one item per line
}

///|
/// Result of IFC computation
pub struct InlineLayoutResult {
  layouts : Array[@types.Layout] // Positioned child layouts
  total_height : Double // Total height of all line boxes
}

///|
/// Compute inline formatting context for children
/// Returns positioned layouts and total height
pub fn compute_ifc(
  children : Array[@node.Node],
  available_width : Double,
  available_height : Double?,
  content_offset_x : Double, // Padding + border left
  content_offset_y : Double, // Padding + border top
  dispatch : @node.DispatchFn,
) -> InlineLayoutResult {
  if children.length() == 0 {
    return { layouts: [], total_height: 0.0 }
  }

  // In vertical-rl writing-mode, inline progression columns are mirrored on x-axis.
  let mut writing_mode = children[0].style.writing_mode
  for child in children {
    if child.style.display != @types.Display::None {
      writing_mode = child.style.writing_mode
      break
    }
  }
  let is_vertical_rl = writing_mode.is_vertical() && writing_mode.is_block_rtl()
  if writing_mode.is_vertical() {
    let columns : Array[Array[Int]] = []
    let column_widths : Array[Double] = []
    let column_heights : Array[Double] = []
    let layout_map : Map[Int, @types.Layout] = {}
    let child_layout_cache : Map[Int, @types.Layout] = {}
    let child_margin_cache : Map[Int, @types.Rect[Double]] = {}

    let mut current_column : Array[Int] = []
    let mut current_width = 0.0
    let mut current_height = 0.0

    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      if child.style.display == @types.Display::None {
        layout_map[i] = create_zero_layout(child)
        continue
      }
      let child_margin = @types.resolve_rect(
        child.style.margin,
        available_width,
      )
      let child_layout = compute_inline_child(
        child, available_width, available_height, dispatch,
      )
      child_layout_cache[i] = child_layout
      child_margin_cache[i] = child_margin

      current_column.push(i)
      let outer_width = child_layout.width +
        child_margin.left +
        child_margin.right
      if outer_width > current_width {
        current_width = outer_width
      }
      current_height = current_height +
        child_layout.height +
        child_margin.top +
        child_margin.bottom

      if child.id == "br" {
        columns.push(current_column)
        column_widths.push(current_width)
        column_heights.push(current_height)
        current_column = []
        current_width = 0.0
        current_height = 0.0
      }
    }

    if current_column.length() > 0 {
      columns.push(current_column)
      column_widths.push(current_width)
      column_heights.push(current_height)
    }

    let mut total_height = 0.0
    let mut total_columns_width = 0.0
    for col_width in column_widths {
      total_columns_width = total_columns_width + col_width
    }
    let resolved_inline_span = if available_width > total_columns_width {
      available_width
    } else {
      total_columns_width
    }
    let mut x_cursor = if is_vertical_rl {
      content_offset_x + resolved_inline_span
    } else {
      content_offset_x
    }

    for col_idx = 0; col_idx < columns.length(); col_idx = col_idx + 1 {
      let column = columns[col_idx]
      let col_width = column_widths[col_idx]
      let col_height = column_heights[col_idx]
      if col_height > total_height {
        total_height = col_height
      }

      let mut col_x = x_cursor
      if is_vertical_rl {
        x_cursor = x_cursor - col_width
        col_x = x_cursor
      } else {
        col_x = x_cursor
        x_cursor = x_cursor + col_width
      }

      let mut y_cursor = content_offset_y
      for item_index in column {
        match child_layout_cache.get(item_index) {
          Some(item_layout) =>
            match child_margin_cache.get(item_index) {
              Some(child_margin) => {
                let positioned : @types.Layout = {
                  id: item_layout.id,
                  x: col_x + child_margin.left,
                  y: y_cursor + child_margin.top,
                  width: item_layout.width,
                  height: item_layout.height,
                  margin: child_margin,
                  padding: item_layout.padding,
                  border: item_layout.border,
                  overflow_x: item_layout.overflow_x,
                  overflow_y: item_layout.overflow_y,
                  scroll_width: item_layout.scroll_width,
                  scroll_height: item_layout.scroll_height,
                  children: item_layout.children,
                  text: item_layout.text,
                }
                layout_map[item_index] = positioned
                y_cursor = positioned.y +
                  item_layout.height +
                  child_margin.bottom
              }
              None => ()
            }
          None => ()
        }
      }
    }

    let layouts : Array[@types.Layout] = []
    for i = 0; i < children.length(); i = i + 1 {
      match layout_map.get(i) {
        Some(layout) => layouts.push(layout)
        None => ()
      }
    }
    return { layouts, total_height }
  }

  // Collect inline-level children and compute their layouts
  let line_boxes : Array[LineBox] = []
  let mut current_line = LineBox::new()
  let layout_map : Map[Int, @types.Layout] = {}
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]

    // Skip display:none children
    if child.style.display == @types.Display::None {
      layout_map[i] = create_zero_layout(child)
      continue
    }

    // Resolve child's box model
    let child_margin = @types.resolve_rect(child.style.margin, available_width)

    // Compute child's intrinsic size
    let child_layout = compute_inline_child(
      child, available_width, available_height, dispatch,
    )

    // Calculate baseline based on font metrics
    // For text nodes, baseline is at font_size * ascender_ratio from top
    // Typical ascender ratio is ~0.8 (80% of font height is above baseline)
    let baseline = if child.id == "br" {
      // <br> participates in line boxes but its baseline should align with text baseline,
      // not with its full line-height box bottom.
      let font_size = child.style.font_size
      let ascender_ratio = 0.8
      font_size * ascender_ratio +
      child_layout.padding.top +
      child_layout.border.top
    } else if child.text is Some(_) {
      // Text node: use font metrics
      let font_size = child.style.font_size
      let ascender_ratio = 0.8 // Standard approximation
      font_size * ascender_ratio +
      child_layout.padding.top +
      child_layout.border.top
    } else {
      // Non-text element: baseline is at bottom (last baseline of content)
      child_layout.height
    }

    // <br> always forces a line break after itself.
    if child.id == "br" {
      current_line.add_item(
        i,
        child_layout,
        baseline,
        child_margin.left,
        child_margin.right,
      )
      line_boxes.push(current_line)
      current_line = LineBox::new()
      continue
    }

    // Check if this item fits in the current line
    if current_line.can_fit(
        child_layout.width,
        child_margin.left,
        child_margin.right,
        available_width,
      ) {
      current_line.add_item(
        i,
        child_layout,
        baseline,
        child_margin.left,
        child_margin.right,
      )
    } else {
      // Start a new line
      line_boxes.push(current_line)
      current_line = LineBox::new()
      current_line.add_item(
        i,
        child_layout,
        baseline,
        child_margin.left,
        child_margin.right,
      )
    }
  }

  // Don't forget the last line
  if current_line.items.length() > 0 {
    line_boxes.push(current_line)
  }

  // Position items within line boxes
  let mut current_y = content_offset_y
  for line in line_boxes {
    let mut current_x = content_offset_x
    for item_index = 0
        item_index < line.items.length()
        item_index = item_index + 1 {
      let item = line.items[item_index]
      let child = children[item.index]
      let child_margin = @types.resolve_rect(
        child.style.margin,
        available_width,
      )

      // Position at current x with margin
      let x = current_x + child_margin.left

      // Vertical alignment based on child's vertical-align property
      let y = match child.style.vertical_align {
        @style.VerticalAlign::Top | @style.VerticalAlign::TextTop =>
          // Align to top of line box
          current_y
        @style.VerticalAlign::Middle =>
          // Align to middle of line box
          current_y + (line.height - item.layout.height) / 2.0
        @style.VerticalAlign::Bottom | @style.VerticalAlign::TextBottom =>
          // Align to bottom of line box
          current_y + (line.height - item.layout.height)
        @style.VerticalAlign::Baseline =>
          // Align item's baseline to line box's baseline
          // y_offset = line_baseline - item_baseline
          current_y + (line.baseline - item.baseline)
        @style.VerticalAlign::Sub => {
          // Subscript: baseline shifted down by ~30% of font size
          let baseline_y = current_y + (line.baseline - item.baseline)
          baseline_y + child.style.font_size * 0.3
        }
        @style.VerticalAlign::Super => {
          // Superscript: baseline shifted up by ~40% of font size
          let baseline_y = current_y + (line.baseline - item.baseline)
          baseline_y - child.style.font_size * 0.4
        }
      }
      let mut positioned_x = x
      let mut positioned_y = y
      if child.id == "br" && item_index > 0 {
        let prev_item = line.items[item_index - 1]
        let prev_child = children[prev_item.index]
        if prev_child.text is Some(_) {
          match estimate_wrapped_text_metrics(prev_child, available_width) {
            Some(metrics) if metrics.line_count > 1 =>
              match layout_map.get(prev_item.index) {
                Some(prev_layout) => {
                  let line_height = if prev_child.style.line_height > 0.0 {
                    prev_child.style.line_height
                  } else {
                    prev_layout.height
                  }
                  let fallback_last_width = prev_layout.width
                  let mut last_line_width = metrics.last_line_width
                  if last_line_width <= 0.0 {
                    last_line_width = fallback_last_width
                  }
                  let max_x = content_offset_x + available_width
                  let raw_x = prev_layout.x + last_line_width
                  positioned_x = if raw_x > max_x { max_x } else { raw_x }
                  positioned_y = prev_layout.y +
                    (metrics.line_count - 1).to_double() * line_height
                }
                _ => ()
              }
            _ => ()
          }
        }
      }
      if is_vertical_rl {
        let rel_x = positioned_x - content_offset_x
        positioned_x = content_offset_x +
          available_width -
          rel_x -
          item.layout.width
        if child.id == "br" {
          // br is positioned at inline advance end before forcing next column.
          // After x-mirroring for vertical-rl, compensate the consumed advance.
          positioned_x = positioned_x + item.layout.width * 2.0
        }
      }
      let positioned : @types.Layout = {
        id: item.layout.id,
        x: positioned_x,
        y: positioned_y,
        width: item.layout.width,
        height: item.layout.height,
        margin: child_margin,
        padding: item.layout.padding,
        border: item.layout.border,
        overflow_x: item.layout.overflow_x,
        overflow_y: item.layout.overflow_y,
        scroll_width: item.layout.scroll_width,
        scroll_height: item.layout.scroll_height,
        children: item.layout.children,
        text: item.layout.text,
      }
      layout_map[item.index] = positioned
      current_x = positioned_x + item.layout.width + child_margin.right
    }
    current_y = current_y + line.height
  }

  // Assemble layouts in original order
  let layouts : Array[@types.Layout] = []
  for i = 0; i < children.length(); i = i + 1 {
    match layout_map.get(i) {
      Some(layout) => layouts.push(layout)
      None => ()
    }
  }
  { layouts, total_height: current_y - content_offset_y }
}

///|
/// Compute layout for an inline-level child
fn compute_inline_child(
  node : @node.Node,
  available_width : Double,
  available_height : Double?,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let style = node.style
  let padding = @types.resolve_rect(style.padding, available_width)
  let border = @types.resolve_rect(style.border, available_width)

  // Handle leaf nodes with MeasureFunc (e.g., text nodes, replaced elements)
  match node.measure {
    Some(mf) => {
      // First, get unconstrained intrinsic sizes (for min-content, max-content)
      let unconstrained = (mf.func)(
        @double.infinity,
        available_height.unwrap_or(0.0),
      )

      // Check if we should use aspect_ratio to derive dimensions
      // For replaced elements like canvas/img with aspect_ratio:
      // - If width is Auto and height is definite (Length or Percent), derive width from height * aspect_ratio
      let height_is_definite = match style.height {
        @types.Length(_) | @types.Percent(_) => true
        _ => false
      }
      let width_is_definite = match style.width {
        @types.Length(_) | @types.Percent(_) => true
        _ => false
      }

      // Calculate height first (needed for aspect_ratio calculation)
      let initial_height : Double? = match style.height {
        @types.Length(h) => Some(h)
        @types.Percent(p) =>
          match available_height {
            Some(ah) => Some(ah * p)
            None => None
          }
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => None
      }

      // Calculate content width based on sizing mode and aspect_ratio
      let content_width = match style.width {
        @types.Length(w) =>
          w - padding.horizontal_sum() - border.horizontal_sum()
        @types.Percent(p) =>
          available_width * p -
          padding.horizontal_sum() -
          border.horizontal_sum()
        @types.MinContent => unconstrained.min_width
        @types.MaxContent => unconstrained.max_width
        @types.FitContent(_) | @types.Auto =>
          // Check if we can derive width from aspect_ratio
          match (style.aspect_ratio, initial_height, height_is_definite) {
            (Some(ratio), Some(h), true) if ratio > 0.0 =>
              // Derive width from height using aspect_ratio
              // For content-box sizing, use content height
              if style.box_sizing == @types.BorderBox {
                h * ratio - padding.horizontal_sum() - border.horizontal_sum()
              } else {
                let content_h = h -
                  padding.vertical_sum() -
                  border.vertical_sum()
                if content_h > 0.0 {
                  content_h * ratio
                } else {
                  unconstrained.max_width
                }
              }
            _ => {
              // Fallback: use intrinsic width, constrained to available_width
              let max_content = unconstrained.max_width
              let content_available = available_width -
                padding.horizontal_sum() -
                border.horizontal_sum()
              let clamped_available = if content_available > 0.0 {
                content_available
              } else {
                0.0
              }
              if max_content < clamped_available {
                max_content
              } else {
                clamped_available
              }
            }
          }
      }

      // Re-call MeasureFunc with constrained width to get correct height
      let constrained = (mf.func)(
        content_width,
        available_height.unwrap_or(0.0),
      )
      let width = content_width +
        padding.horizontal_sum() +
        border.horizontal_sum()

      // Calculate final height
      let height = match style.height {
        @types.Length(h) => h
        @types.Percent(p) =>
          match available_height {
            Some(ah) => ah * p
            None =>
              // No definite parent height, fall back to intrinsic + aspect_ratio
              match style.aspect_ratio {
                Some(ratio) if ratio > 0.0 => width / ratio
                _ =>
                  constrained.max_height +
                  padding.vertical_sum() +
                  border.vertical_sum()
              }
          }
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) =>
          // Check if we can derive height from aspect_ratio
          match (style.aspect_ratio, width_is_definite) {
            (Some(ratio), true) if ratio > 0.0 =>
              // Derive height from width using aspect_ratio
              if style.box_sizing == @types.BorderBox {
                width / ratio
              } else {
                content_width / ratio +
                padding.vertical_sum() +
                border.vertical_sum()
              }
            _ =>
              constrained.max_height +
              padding.vertical_sum() +
              border.vertical_sum()
          }
      }
      return {
        id: node.id,
        x: 0.0,
        y: 0.0,
        width,
        height,
        margin: @types.Rect::zero(),
        padding,
        border,
        overflow_x: style.overflow_x,
        overflow_y: style.overflow_y,
        scroll_width: 0.0,
        scroll_height: 0.0,
        children: [],
        text: node.text,
      }
    }
    None => ()
  }

  // For inline-block, inline-flex, inline-grid, use shrink-to-fit via layout dispatcher
  if style.display == @types.InlineBlock ||
    style.display == @types.InlineFlex ||
    style.display == @types.InlineGrid {
    // Use the dispatch function to get proper block/flex/grid layout
    let ctx : @types.LayoutContext = {
      available_width,
      available_height,
      sizing_mode: @types.MaxContent,
      viewport_width: available_width,
      viewport_height: available_height.unwrap_or(0.0),
      stretch_width: false,
      stretch_height: false,
    } // Use MaxContent for shrink-to-fit
    let @node.DispatchFn(dispatch_fn) = dispatch
    let layout = dispatch_fn(node, ctx, dispatch)
    return layout
  }

  // For plain inline elements (no MeasureFunc), calculate size based on children
  // and handle absolute positioned children
  let children : Array[@types.Layout] = []
  let mut content_width = 0.0
  let mut content_height = 0.0

  // Process children - handle absolute positioned elements
  let absolute_entries : Array[(Int, @node.Node)] = []
  for child in node.children {
    if child.style.display == @types.Display::None {
      children.push(create_zero_layout(child))
    } else if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      // Absolute/fixed children need to be laid out
      // Use dispatch to get proper sizing
      let child_ctx : @types.LayoutContext = {
        available_width,
        available_height,
        sizing_mode: @types.MaxContent,
        viewport_width: available_width,
        viewport_height: available_height.unwrap_or(0.0),
        stretch_width: false,
        stretch_height: false,
      }
      let @node.DispatchFn(dispatch_fn) = dispatch
      let child_layout = dispatch_fn(child, child_ctx, dispatch)
      let child_index = children.length()
      children.push(child_layout)
      if child.style.position == @types.Absolute {
        absolute_entries.push((child_index, child))
      }
      // Absolute children don't contribute to inline element's size
    } else if is_inline_level(child.style.display) {
      // Recursively process inline children
      let child_layout = compute_inline_child(
        child, available_width, available_height, dispatch,
      )
      children.push(child_layout)
      // Accumulate content size from flow children
      // For inline elements, children are laid out horizontally
      content_width = content_width + child_layout.width
      if child_layout.height > content_height {
        content_height = child_layout.height
      }
    }
    // Block-level children in inline context are not supported (would need anonymous blocks)
  }

  // Calculate final width and height
  // For inline elements, content width is the sum of children widths
  // Content height is the maximum child height
  let final_width = content_width +
    padding.horizontal_sum() +
    border.horizontal_sum()
  let final_height = content_height +
    padding.vertical_sum() +
    border.vertical_sum()

  // Resolve absolute child positions against this inline element's content box.
  if absolute_entries.length() > 0 {
    let area_left = padding.left + border.left
    let area_top = padding.top + border.top
    let area_width_raw = final_width -
      padding.horizontal_sum() -
      border.horizontal_sum()
    let area_height_raw = final_height -
      padding.vertical_sum() -
      border.vertical_sum()
    let area_width = if area_width_raw > 0.0 { area_width_raw } else { 0.0 }
    let area_height = if area_height_raw > 0.0 { area_height_raw } else { 0.0 }
    for entry in absolute_entries {
      let (idx, abs_child) = entry
      let abs_layout = children[idx]
      let child_style = abs_child.style
      let inset_left = resolve_inset_dimension(
        child_style.inset.left,
        area_width,
      )
      let inset_right = resolve_inset_dimension(
        child_style.inset.right,
        area_width,
      )
      let inset_top = resolve_inset_dimension(
        child_style.inset.top,
        area_height,
      )
      let inset_bottom = resolve_inset_dimension(
        child_style.inset.bottom,
        area_height,
      )
      let x = match (inset_left, inset_right) {
        (Some(l), _) => area_left + l
        (None, Some(r)) => area_left + area_width - r - abs_layout.width
        (None, None) => abs_layout.x
      }
      let y = match (inset_top, inset_bottom) {
        (Some(t), _) => area_top + t
        (None, Some(b)) => area_top + area_height - b - abs_layout.height
        (None, None) => abs_layout.y
      }
      children[idx] = { ..abs_layout, x, y }
    }
  }

  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: final_width,
    height: final_height,
    margin: @types.Rect::zero(),
    padding,
    border,
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children,
    text: node.text,
  }
}

///|
/// Create a zero-sized layout for display:none nodes
fn create_zero_layout(node : @node.Node) -> @types.Layout {
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let children : Array[@types.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    children.push(create_zero_layout(node.children[i]))
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children,
    text: node.text,
  }
}

///|
/// Check if a node is inline-level (inline or inline-block)
pub fn is_inline_level(display : @types.Display) -> Bool {
  match display {
    @types.Inline
    | @types.InlineBlock
    | @types.InlineFlex
    | @types.InlineGrid => true
    _ => false
  }
}

///|
/// Check if children should establish an IFC
/// Returns true if all non-absolute children are inline-level
pub fn should_establish_ifc(children : Array[@node.Node]) -> Bool {
  if children.length() == 0 {
    return false
  }
  let mut has_inline = false
  for child in children {
    // Skip absolute positioned children
    if child.style.position == @types.Absolute {
      continue
    }
    // Skip display:none
    if child.style.display == @types.Display::None {
      continue
    }
    if is_inline_level(child.style.display) {
      has_inline = true
    } else {
      // Found a block-level child, no IFC
      return false
    }
  }
  has_inline
}
