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
/// Convert pixel X to character column (truncates for position)
pub fn px_to_col(px : Double) -> Int {
  (px / font_width).to_int()
}

///|
/// Convert pixel width to character width (rounds up to ensure content fits)
fn px_to_col_width(px : Double) -> Int {
  let result = px / font_width
  let int_part = result.to_int()
  // Ceiling: if there's any fractional part, add 1
  if result > int_part.to_double() {
    int_part + 1
  } else {
    int_part
  }
}

///|
/// Convert pixel Y to character row
pub fn px_to_row(px : Double) -> Int {
  (px / font_height).to_int()
}

///|
/// Convert pixel height to character height (rounds up)
fn px_to_row_height(px : Double) -> Int {
  let result = px / font_height
  let int_part = result.to_int()
  if result > int_part.to_double() {
    int_part + 1
  } else {
    int_part
  }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Convert dirty rects in pixel coordinates to character grid rectangles
pub fn dirty_rects_to_cells(
  rects : Array[@types.BoundingRect],
  scroll_y_px : Int,
  viewport_cols : Int,
  viewport_rows : Int,
  row_offset : Int,
) -> Array[DirtyRect] {
  let result : Array[DirtyRect] = []
  let view_left = 0.0
  let view_right = viewport_cols.to_double() * font_width
  let view_top = scroll_y_px.to_double()
  let view_bottom = view_top + viewport_rows.to_double() * font_height
  for rect in rects {
    let x0 = max_double(rect.x, view_left)
    let y0 = max_double(rect.y, view_top)
    let x1 = min_double(rect.x + rect.width, view_right)
    let y1 = min_double(rect.y + rect.height, view_bottom)
    if x1 <= x0 || y1 <= y0 {
      continue
    }
    let col = px_to_col(x0)
    let row = px_to_row(y0 - view_top) + row_offset
    let w = px_to_col_width(x1 - x0)
    let h = px_to_row_height(y1 - y0)
    if w <= 0 || h <= 0 {
      continue
    }
    result.push({ col, row, width: w, height: h })
  }
  result
}

///|
/// A clickable link region on screen
pub(all) struct LinkRegion {
  col : Int // Start column
  row : Int // Start row
  width : Int // Width in characters
  height : Int // Height in characters
  text : String // Link text (used to match with Browser.links for href)
}

///|
/// Hint data for hit-a-hint feature
pub(all) struct HintData {
  label : String // The hint label (e.g., "a", "b", "aa")
  href : String // Link URL
  text : String // Link text
  col : Int // Screen column position
  row : Int // Screen row position
}

///|
/// Check if a point is inside this link region
pub fn LinkRegion::contains(self : LinkRegion, col : Int, row : Int) -> Bool {
  col >= self.col &&
  col < self.col + self.width &&
  row >= self.row &&
  row < self.row + self.height
}

///|
/// Find link at given screen coordinates
pub fn find_link_at(
  regions : Array[LinkRegion],
  col : Int,
  row : Int,
) -> String? {
  for region in regions {
    if region.contains(col, row) {
      return Some(region.text)
    }
  }
  None
}

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
  focused_element_name : String? // Name of currently focused element (for :focus styling)
  dark_mode : Bool // Dark mode enabled
  element_scroll_positions : Map[String, ElementScrollPos] // Element-level scroll positions
}

///|
/// Render a PaintNode to the CharBuffer
fn render_paint_node(
  ctx : TuiContext,
  node : @paint.PaintNode,
  parent_x : Double,
  parent_y : Double,
  inside_link : Bool,
  inside_pre? : Bool = false,
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
  // Use ceiling for width and height to ensure text content fits
  let w = px_to_col_width(node.width)
  let h = px_to_row_height(node.height)
  // Check if we're inside a pre/code element (no text wrapping)
  // Also disable wrapping inside table cells (th/td) - cells should clip, not wrap
  let is_pre = node.tag == "pre" || node.tag == "code"
  let is_table_cell = node.tag == "th" || node.tag == "td"
  let child_inside_pre = inside_pre || is_pre || is_table_cell
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
        inside_pre=child_inside_pre,
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
        inside_pre=child_inside_pre,
      )
    }
    return
  }
  // Draw background if not transparent
  if not(node.paint.background_color.is_transparent()) {
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
        let _ = ctx.buffer.write_text(
          col, draw_row, border_line, border_style, w,
        )

      }
      // Bottom border
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
        let visible_label = if label.to_array().length() > max_label_width &&
          max_label_width > 3 {
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
            let text_len = text_content.to_array().length()
            ctx.link_regions.push({
              col,
              row,
              width: text_len.min(w),
              height: 1,
              text: text_content,
            })
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
      inside_pre=child_inside_pre,
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

///|
/// Render result containing ANSI string and link regions
pub(all) struct RenderResult {
  ansi : String
  link_regions : Array[LinkRegion]
}

///|
/// Render result with raw buffer (for diff rendering)
pub(all) struct BufferRenderResult {
  buffer : CharBuffer
  link_regions : Array[LinkRegion]
  scrollable_elements : Array[@paint.ScrollableElement]
}

///|
/// Render a Node + Layout tree to ANSI string
pub fn render_to_ansi(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  focused_element_name? : String? = None,
) -> RenderResult {
  let result = render_to_buffer(
    node,
    layout,
    width,
    height,
    scroll_y,
    focused_element_name~,
  )
  { ansi: buffer_to_ansi(result.buffer), link_regions: result.link_regions }
}

///|
/// Render a Node + Layout tree to a CharBuffer
pub fn render_to_buffer(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  focused_element_name? : String? = None,
) -> BufferRenderResult {
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
  // Convert to PaintNode with viewport culling
  let viewport_top = scroll_y.to_double() * font_height
  let viewport_bottom = (scroll_y + height).to_double() * font_height
  let paint_node = match
    @paint.from_node_and_layout_with_viewport(
      node, layout, viewport_top, viewport_bottom, 0.0,
    ) {
    Some(n) => n
    None => return { buffer: buf, link_regions: [], scrollable_elements: [] }
  }
  let sorted = @paint.sort_tree_by_stacking_order(paint_node)
  let link_regions : Array[LinkRegion] = []
  let scrollable_elements = @paint.collect_scrollable_elements(sorted)
  let ctx : TuiContext = {
    buffer: buf,
    scroll_y,
    viewport_height: height,
    link_regions,
    focused_element_name,
    dark_mode: false,
    element_scroll_positions: {},
  }
  render_paint_node(ctx, sorted, 0.0, 0.0, false)
  { buffer: buf, link_regions, scrollable_elements }
}

///|
/// Render a Node + Layout tree with status bar at top
pub fn render_to_ansi_with_status(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  url : String,
  link_count : Int,
  focused_link : Int,
  focused_element_name? : String? = None,
  focused_link_url? : String? = None,
  selection_mode? : Bool = false,
  dark_mode? : Bool = false,
) -> RenderResult {
  let result = render_to_buffer_with_status(
    node,
    layout,
    width,
    height,
    scroll_y,
    url,
    link_count,
    focused_link,
    focused_element_name~,
    focused_link_url~,
    selection_mode~,
    dark_mode~,
  )
  { ansi: buffer_to_ansi(result.buffer), link_regions: result.link_regions }
}

///|
/// Render a Node + Layout tree with status bar to a CharBuffer
pub fn render_to_buffer_with_status(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  url : String,
  link_count : Int,
  focused_link : Int,
  focused_element_name? : String? = None,
  focused_link_url? : String? = None,
  selection_mode? : Bool = false,
  dark_mode? : Bool = false,
  total_content_height? : Int = 0,
  show_scrollbar? : Bool = false,
  element_scroll_positions? : Map[String, ElementScrollPos] = {},
) -> BufferRenderResult {
  // Reserve first row for status bar at top
  let content_height = height - 1
  let content_start_row = 1 // Content starts at row 1 (after status bar)
  // Create character buffer
  let buf = CharBuffer::new(width, height)
  // Clear with background color based on theme
  let (content_fg, content_bg) = if dark_mode {
    (@types.Color::rgb(220, 220, 220), @types.Color::rgb(30, 30, 30))
  } else {
    (@types.Color::black(), @types.Color::white())
  }
  let bg_cell : CharCell = {
    char: ' ',
    fg: content_fg,
    bg: content_bg,
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(0, content_start_row, width, content_height, bg_cell)
  // Convert to PaintNode with viewport culling
  // Calculate viewport bounds in pixels (font_height = 16.0)
  let viewport_top = scroll_y.to_double() * font_height
  let viewport_bottom = (scroll_y + content_height).to_double() * font_height
  let paint_node = match
    @paint.from_node_and_layout_with_viewport(
      node, layout, viewport_top, viewport_bottom, 0.0,
    ) {
    Some(n) => n
    None => {
      // Content is outside viewport, draw status bar and return
      draw_status_bar(
        buf,
        0,
        url,
        link_count,
        focused_link,
        focused_link_url~,
        selection_mode~,
        dark_mode~,
      )
      return { buffer: buf, link_regions: [], scrollable_elements: [] }
    }
  }
  // Sort by stacking order
  let sorted = @paint.sort_tree_by_stacking_order(paint_node)
  // Collect scrollable elements from the paint tree
  let scrollable_elements = @paint.collect_scrollable_elements(sorted)
  // Create context with link regions array
  // Content is drawn with a 1-row offset via parent_y
  let link_regions : Array[LinkRegion] = []
  let ctx : TuiContext = {
    buffer: buf,
    scroll_y,
    viewport_height: content_height,
    link_regions,
    focused_element_name,
    dark_mode,
    element_scroll_positions,
  }
  // Render content with offset (start with inside_link=false)
  render_paint_node(
    ctx,
    sorted,
    0.0,
    content_start_row.to_double() * font_height,
    false,
  )
  // Draw status bar at top (row 0) - drawn after content to ensure it's not overwritten
  draw_status_bar(
    buf,
    0,
    url,
    link_count,
    focused_link,
    focused_link_url~,
    selection_mode~,
    dark_mode~,
  )
  // Draw scrollbar if enabled and content overflows
  if show_scrollbar && total_content_height > content_height * 16 {
    let content_height_chars = total_content_height / 16 // Convert px to char rows
    draw_scrollbar(
      buf,
      width - 1, // x: right edge
      content_start_row, // y: start row
      content_height, // height of track
      scroll_y, // scroll position
      content_height_chars, // total content height in chars
      content_height, // visible height in chars
    )
  }
  // Return buffer, link regions, and scrollable elements
  { buffer: buf, link_regions, scrollable_elements }
}

///|
/// Get total content height in character rows
pub fn get_content_height_chars(layout : @types.Layout) -> Int {
  px_to_row(layout.height)
}

///|
/// Calculate display width of a string (full-width chars count as 2)
fn display_width(s : String) -> Int {
  let mut width = 0
  for c in s {
    // Full-width characters (CJK, etc.) take 2 columns
    // Basic check: characters above U+2E80 are typically full-width
    let code = c.to_int()
    if code >= 0x2E80 {
      width = width + 2
    } else {
      width = width + 1
    }
  }
  width
}

///|
/// Calculate text display width for TUI rendering
/// Uses character-based width (not pixel-based) to ensure text is not clipped
/// due to font-size differences between layout and TUI
fn calculate_text_display_width(text : String) -> Int {
  let mut width = 0
  for c in text {
    if c == '\n' {
      // Stop at newline for single-line width
      break
    }
    width = width + char_display_width(c)
  }
  width
}

///|
/// Draw hint overlays on the buffer
/// Hints are displayed as bright yellow background with black text
/// Labels are shown to the RIGHT of link text for better visibility
fn draw_hints(
  buf : CharBuffer,
  hints : Array[HintData],
  viewport_height : Int,
) -> Unit {
  let hint_style : TextStyle = {
    fg: @types.Color::rgb(0, 0, 0), // Black text
    bg: @types.Color::rgb(255, 220, 0), // Bright yellow background
    bold: true,
    underline: false,
  }
  for hint in hints {
    // Skip if not visible (row = -1 means position unknown)
    if hint.row < 0 || hint.row >= viewport_height {
      continue
    }
    // Draw hint label to the RIGHT of link text
    // Format: [label] e.g. [a], [ab]
    let label_text = "[" + hint.label + "]"
    // Use display_width to handle full-width characters (CJK)
    let label_col = hint.col + display_width(hint.text)
    let _ = buf.write_text(
      label_col,
      hint.row,
      label_text,
      hint_style,
      label_text.length(),
    )

  }
}

///|
/// Render with hints overlay (for hit-a-hint mode)
pub fn render_to_ansi_with_hints(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  hints : Array[HintData],
  hint_input : String,
  focused_element_name? : String? = None,
) -> RenderResult {
  let result = render_to_buffer_with_hints(
    node,
    layout,
    width,
    height,
    scroll_y,
    hints,
    hint_input,
    focused_element_name~,
  )
  { ansi: buffer_to_ansi(result.buffer), link_regions: result.link_regions }
}

///|
/// Render with hints overlay to a CharBuffer
pub fn render_to_buffer_with_hints(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  hints : Array[HintData],
  hint_input : String,
  focused_element_name? : String? = None,
) -> BufferRenderResult {
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
  // Convert to PaintNode with viewport culling
  // Calculate viewport bounds in pixels (font_height = 16.0)
  let viewport_top = scroll_y.to_double() * font_height
  let viewport_bottom = (scroll_y + content_height).to_double() * font_height
  let paint_node = match
    @paint.from_node_and_layout_with_viewport(
      node, layout, viewport_top, viewport_bottom, 0.0,
    ) {
    Some(n) => n
    None => {
      // Content is outside viewport, just draw hints and status bar
      draw_hints(buf, hints, content_height)
      draw_hint_mode_status_bar(buf, content_height, hint_input, hints)
      return { buffer: buf, link_regions: [], scrollable_elements: [] }
    }
  }
  // Sort by stacking order
  let sorted = @paint.sort_tree_by_stacking_order(paint_node)
  // Collect scrollable elements from the paint tree
  let scrollable_elements = @paint.collect_scrollable_elements(sorted)
  // Create context with link regions array
  let link_regions : Array[LinkRegion] = []
  let ctx : TuiContext = {
    buffer: buf,
    scroll_y,
    viewport_height: content_height,
    link_regions,
    focused_element_name,
    dark_mode: false, // TODO: Add dark_mode support for hints
    element_scroll_positions: {},
  }
  // Render content (start with inside_link=false)
  render_paint_node(ctx, sorted, 0.0, 0.0, false)
  // Draw hint overlays (hint positions are already screen coordinates)
  draw_hints(buf, hints, content_height)
  // Draw status bar with hint list
  draw_hint_mode_status_bar(buf, content_height, hint_input, hints)
  // Return buffer, link regions, and scrollable elements
  { buffer: buf, link_regions, scrollable_elements }
}

///|
/// Draw status bar for hint mode with hint list
fn draw_hint_mode_status_bar(
  buf : CharBuffer,
  y : Int,
  hint_input : String,
  hints : Array[HintData],
) -> Unit {
  // Black on yellow background for hint mode
  let style : TextStyle = {
    fg: @types.Color::rgb(0, 0, 0),
    bg: @types.Color::rgb(255, 220, 0),
    bold: true,
    underline: false,
  }
  // Fill the entire row first
  for col = 0; col < buf.width; col = col + 1 {
    let cell : CharCell = {
      char: ' ',
      fg: @types.Color::rgb(0, 0, 0),
      bg: @types.Color::rgb(255, 220, 0),
      bold: false,
      underline: false,
      reverse: false,
    }
    buf.set_cell(col, y, cell)
  }
  // Build hint list (show first few that match current input)
  let sb = StringBuilder::new()
  sb.write_string(" HINT [")
  sb.write_string(hint_input)
  sb.write_string("]: ")
  let mut shown = 0
  let max_show = 8
  for hint in hints {
    if hint_input.length() == 0 || hint.label.has_prefix(hint_input) {
      if shown > 0 {
        sb.write_string(" ")
      }
      sb.write_string(hint.label)
      sb.write_string(":")
      // Truncate text if too long
      let text = hint.text
      let max_len = 12
      if text.to_array().length() > max_len {
        let chars = text.to_array()
        for i = 0; i < max_len - 2; i = i + 1 {
          sb.write_char(chars[i])
        }
        sb.write_string("..")
      } else {
        sb.write_string(text)
      }
      shown = shown + 1
      if shown >= max_show {
        sb.write_string(" ...")
        break
      }
    }
  }
  if shown == 0 {
    sb.write_string("(no match)")
  }
  sb.write_string(" | ESC:cancel")
  let status = sb.to_string()
  let _ = buf.write_text(0, y, status, style, buf.width)

}
