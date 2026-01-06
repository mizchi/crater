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
  layout : @node.Layout // Computed layout
  baseline : Double // Distance from top of item to its baseline
}

///|
fn LineBox::new() -> LineBox {
  { items: [], width: 0.0, height: 0.0, baseline: 0.0 }
}

///|
/// Add an item to the line box
fn LineBox::add_item(
  self : LineBox,
  index : Int,
  layout : @node.Layout,
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
  layouts : Array[@node.Layout] // Positioned child layouts
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
) -> InlineLayoutResult {
  if children.length() == 0 {
    return { layouts: [], total_height: 0.0 }
  }

  // Collect inline-level children and compute their layouts
  let line_boxes : Array[LineBox] = []
  let mut current_line = LineBox::new()
  let layout_map : Map[Int, @node.Layout] = {}
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]

    // Skip display:none children
    if child.style.display == @style.None {
      layout_map[i] = create_zero_layout(child)
      continue
    }

    // Resolve child's box model
    let child_margin = @types.resolve_rect(child.style.margin, available_width)

    // Compute child's intrinsic size
    let child_layout = compute_inline_child(
      child, available_width, available_height,
    )

    // Calculate baseline based on font metrics
    // For text nodes, baseline is at font_size * ascender_ratio from top
    // Typical ascender ratio is ~0.8 (80% of font height is above baseline)
    let baseline = if child.text is Some(_) {
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
    for item in line.items {
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
      let positioned : @node.Layout = {
        id: item.layout.id,
        x,
        y,
        width: item.layout.width,
        height: item.layout.height,
        margin: child_margin,
        padding: item.layout.padding,
        border: item.layout.border,
        overflow_x: item.layout.overflow_x,
        overflow_y: item.layout.overflow_y,
        children: item.layout.children,
        text: item.layout.text,
      }
      layout_map[item.index] = positioned
      current_x = x + item.layout.width + child_margin.right
    }
    current_y = current_y + line.height
  }

  // Assemble layouts in original order
  let layouts : Array[@node.Layout] = []
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
) -> @node.Layout {
  let style = node.style
  let padding = @types.resolve_rect(style.padding, available_width)
  let border = @types.resolve_rect(style.border, available_width)

  // Handle leaf nodes with MeasureFunc (e.g., text nodes)
  match node.measure {
    Some(mf) => {
      // First, get unconstrained intrinsic sizes (for min-content, max-content)
      let unconstrained = (mf.func)(
        @double.infinity,
        available_height.unwrap_or(0.0),
      )

      // Calculate content width based on sizing mode
      let content_width = match style.width {
        @types.Length(w) =>
          w - padding.horizontal_sum() - border.horizontal_sum()
        @types.Percent(p) =>
          available_width * p -
          padding.horizontal_sum() -
          border.horizontal_sum()
        @types.MinContent => unconstrained.min_width
        @types.MaxContent => unconstrained.max_width
        @types.FitContent(_) | @types.Auto => {
          // Auto: constrain to available_width
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

      // Re-call MeasureFunc with constrained width to get correct height
      let constrained = (mf.func)(
        content_width,
        available_height.unwrap_or(0.0),
      )
      let width = content_width +
        padding.horizontal_sum() +
        border.horizontal_sum()

      // Calculate height
      let height = match style.height {
        @types.Length(h) => h
        @types.Percent(p) => available_height.unwrap_or(0.0) * p
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) =>
          constrained.max_height +
          padding.vertical_sum() +
          border.vertical_sum()
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
        children: [],
        text: node.text,
      }
    }
    None => ()
  }

  // For inline-block, use shrink-to-fit via layout dispatcher
  if style.display == @style.InlineBlock {
    // Use the global layout dispatcher to get proper block/flex/grid layout
    let ctx : @node.LayoutContext = {
      available_width,
      available_height,
      sizing_mode: @node.MaxContent,
      viewport_width: available_width,
      viewport_height: available_height.unwrap_or(0.0),
    } // Use MaxContent for shrink-to-fit
    let layout = @node.dispatch_layout(node, ctx)
    return layout
  }

  // For plain inline elements (no MeasureFunc), calculate size based on children
  // and handle absolute positioned children
  let children : Array[@node.Layout] = []

  // Process children - handle absolute positioned elements
  for child in node.children {
    if child.style.display == @style.None {
      children.push(create_zero_layout(child))
    } else if child.style.position == @style.Absolute ||
      child.style.position == @style.Fixed {
      // Absolute/fixed children need to be laid out
      // Use dispatch_layout to get proper sizing
      let child_ctx : @node.LayoutContext = {
        available_width,
        available_height,
        sizing_mode: @node.MaxContent,
        viewport_width: available_width,
        viewport_height: available_height.unwrap_or(0.0),
      }
      let child_layout = @node.dispatch_layout(child, child_ctx)
      children.push(child_layout)
    } else if is_inline_level(child.style.display) {
      // Recursively process inline children
      let child_layout = compute_inline_child(
        child, available_width, available_height,
      )
      children.push(child_layout)
    }
    // Block-level children in inline context are not supported (would need anonymous blocks)
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: padding.horizontal_sum() + border.horizontal_sum(),
    height: padding.vertical_sum() + border.vertical_sum(),
    margin: @types.Rect::zero(),
    padding,
    border,
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    children,
    text: node.text,
  }
}

///|
/// Create a zero-sized layout for display:none nodes
fn create_zero_layout(node : @node.Node) -> @node.Layout {
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let children : Array[@node.Layout] = []
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
    overflow_x: @style.Visible,
    overflow_y: @style.Visible,
    children,
    text: node.text,
  }
}

///|
/// Check if a node is inline-level (inline or inline-block)
pub fn is_inline_level(display : @style.Display) -> Bool {
  match display {
    @style.Inline
    | @style.InlineBlock
    | @style.InlineFlex
    | @style.InlineGrid => true
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
    if child.style.position == @style.Absolute {
      continue
    }
    // Skip display:none
    if child.style.display == @style.None {
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
