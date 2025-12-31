///|
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Resolve a Rect[Dimension] (margin/padding/border) to Rect[Double]
/// CSS spec: percentage values are ALWAYS relative to parent's WIDTH
/// (even for top/bottom margin/padding)
fn resolve_rect(
  rect : @types.Rect[@types.Dimension],
  parent_width : Double,
) -> @types.Rect[Double] {
  {
    left: rect.left.resolve_or(parent_width, 0.0),
    right: rect.right.resolve_or(parent_width, 0.0),
    top: rect.top.resolve_or(parent_width, 0.0),
    bottom: rect.bottom.resolve_or(parent_width, 0.0),
  }
}

///|
/// Compute block layout with warnings for unsupported features
pub fn compute_with_warnings(
  node : @node.Node,
  ctx : @node.LayoutContext,
) -> @node.LayoutResult {
  let warnings : Array[@node.LayoutWarning] = []
  let layout = compute_internal(node, ctx, warnings)
  { layout, warnings }
}

///|
/// Compute block layout for a node and its children
pub fn compute(node : @node.Node, ctx : @node.LayoutContext) -> @node.Layout {
  let warnings : Array[@node.LayoutWarning] = []
  compute_internal(node, ctx, warnings)
}

///|
fn compute_internal(
  node : @node.Node,
  ctx : @node.LayoutContext,
  warnings : Array[@node.LayoutWarning],
) -> @node.Layout {
  let style = node.style

  // Check for unsupported features
  match style.float {
    @style.Left | @style.Right => warnings.push(@node.UnsupportedFloat(node.id))
    @style.None => ()
  }
  match style.position {
    @style.Absolute => warnings.push(@node.UnsupportedPosition(node.id))
    @style.Relative => ()
  }

  // Resolve box model
  // CSS spec: percentage margins/padding are always relative to parent's WIDTH
  let parent_width = ctx.available_width
  let parent_height = ctx.available_height.unwrap_or(0.0)
  let margin = resolve_rect(style.margin, parent_width)
  let padding = resolve_rect(style.padding, parent_width)
  let border = resolve_rect(style.border, parent_width)

  // Box width (border-box model, like CSS box-sizing: border-box)
  // This is the total width including padding and border
  let mut box_width = match style.width {
    @types.Length(w) => w
    @types.Percent(p) => parent_width * p
    @types.Auto => parent_width - margin.horizontal_sum()
  }

  // Apply min/max width constraints
  match style.min_width {
    @types.Length(min_w) => if box_width < min_w { box_width = min_w }
    @types.Percent(p) => {
      let min_w = parent_width * p
      if box_width < min_w {
        box_width = min_w
      }
    }
    @types.Auto => ()
  }
  match style.max_width {
    @types.Length(max_w) => if box_width > max_w { box_width = max_w }
    @types.Percent(p) => {
      let max_w = parent_width * p
      if box_width > max_w {
        box_width = max_w
      }
    }
    @types.Auto => ()
  }

  // Available width for children (content area)
  let child_available_width = box_width -
    padding.horizontal_sum() -
    border.horizontal_sum()

  // Calculate available height for children based on parent's specified height
  let child_available_height : Double? = match style.height {
    @types.Length(h) => Some(h - padding.vertical_sum() - border.vertical_sum())
    @types.Percent(p) =>
      Some(parent_height * p - padding.vertical_sum() - border.vertical_sum())
    @types.Auto => None
  }

  // Layout children with margin collapsing
  let child_layouts : Array[@node.Layout] = Array::new(
    capacity=node.children.length(),
  )
  let mut current_y = 0.0
  let mut prev_margin_bottom = 0.0
  let mut is_first_visible = true
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]

    // Skip children with display: none
    if child.style.display == @style.None {
      continue
    }
    let child_ctx : @node.LayoutContext = {
      available_width: child_available_width,
      available_height: child_available_height,
    }
    let child_layout = compute_internal(child, child_ctx, warnings)

    // Calculate collapsed margin between siblings
    // Adjacent vertical margins collapse to the maximum of the two
    let collapsed_margin = if is_first_visible {
      child_layout.margin.top
    } else {
      max(prev_margin_bottom, child_layout.margin.top)
    }
    is_first_visible = false

    // Position child relative to content area
    let positioned_layout : @node.Layout = {
      id: child_layout.id,
      x: child_layout.margin.left + padding.left + border.left,
      y: current_y + collapsed_margin + padding.top + border.top,
      width: child_layout.width,
      height: child_layout.height,
      margin: child_layout.margin,
      padding: child_layout.padding,
      border: child_layout.border,
      children: child_layout.children,
    }
    child_layouts.push(positioned_layout)
    current_y = current_y + collapsed_margin + child_layout.height
    prev_margin_bottom = child_layout.margin.bottom
  }

  // Add final margin to content height
  current_y = current_y + prev_margin_bottom

  // Box height (border-box model)
  let mut box_height = match style.height {
    @types.Length(h) => h
    @types.Percent(p) => parent_height * p
    @types.Auto => current_y + padding.vertical_sum() + border.vertical_sum()
  }

  // Apply min/max height constraints
  match style.min_height {
    @types.Length(min_h) => if box_height < min_h { box_height = min_h }
    @types.Percent(p) => {
      let min_h = parent_height * p
      if box_height < min_h {
        box_height = min_h
      }
    }
    @types.Auto => ()
  }
  match style.max_height {
    @types.Length(max_h) => if box_height > max_h { box_height = max_h }
    @types.Percent(p) => {
      let max_h = parent_height * p
      if box_height > max_h {
        box_height = max_h
      }
    }
    @types.Auto => ()
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: box_width,
    height: box_height,
    margin,
    padding,
    border,
    children: child_layouts,
  }
}
