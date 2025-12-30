// =============================================================================
// Flexbox Layout Implementation
// =============================================================================

///|
fn max(a : Double, b : Double) -> Double {
  if a > b { a } else { b }
}

///|
/// Resolve a Rect[Dimension] to Rect[Double]
fn resolve_rect(
  rect : @types.Rect[@types.Dimension],
  parent_width : Double
) -> @types.Rect[Double] {
  {
    left: rect.left.resolve_or(parent_width, 0.0),
    right: rect.right.resolve_or(parent_width, 0.0),
    top: rect.top.resolve_or(parent_width, 0.0),
    bottom: rect.bottom.resolve_or(parent_width, 0.0),
  }
}

///|
/// Compute flex layout for a node and its children
pub fn compute(node : @node.Node, ctx : @node.LayoutContext) -> @node.Layout {
  let warnings : Array[@node.LayoutWarning] = []
  compute_internal(node, ctx, warnings)
}

///|
/// Compute flex layout with warnings
pub fn compute_with_warnings(
  node : @node.Node,
  ctx : @node.LayoutContext
) -> @node.LayoutResult {
  let warnings : Array[@node.LayoutWarning] = []
  let layout = compute_internal(node, ctx, warnings)
  { layout, warnings }
}

///|
fn compute_internal(
  node : @node.Node,
  ctx : @node.LayoutContext,
  warnings : Array[@node.LayoutWarning]
) -> @node.Layout {
  let style = node.style

  // Check for unsupported features
  match style.float {
    @style.Left | @style.Right =>
      warnings.push(@node.UnsupportedFloat(node.id))
    @style.None => ()
  }

  let parent_width = ctx.available_width
  let parent_height = ctx.available_height.unwrap_or(0.0)

  // Resolve box model
  let margin = resolve_rect(style.margin, parent_width)
  let padding = resolve_rect(style.padding, parent_width)
  let border = resolve_rect(style.border, parent_width)

  // Container size
  let mut container_width = match style.width {
    @types.Length(w) => w
    @types.Percent(p) => parent_width * p
    @types.Auto => parent_width - margin.horizontal_sum()
  }

  // Apply min/max width
  match style.min_width {
    @types.Length(v) => if container_width < v { container_width = v }
    @types.Percent(p) => {
      let v = parent_width * p
      if container_width < v { container_width = v }
    }
    @types.Auto => ()
  }
  match style.max_width {
    @types.Length(v) => if container_width > v { container_width = v }
    @types.Percent(p) => {
      let v = parent_width * p
      if container_width > v { container_width = v }
    }
    @types.Auto => ()
  }

  // Content area
  let content_width = container_width - padding.horizontal_sum() - border.horizontal_sum()
  let content_height : Double? = match style.height {
    @types.Length(h) => Some(h - padding.vertical_sum() - border.vertical_sum())
    @types.Percent(p) => Some(parent_height * p - padding.vertical_sum() - border.vertical_sum())
    @types.Auto => None
  }

  // Determine main/cross axis based on flex-direction
  let is_row = match style.flex_direction {
    @style.Row | @style.RowReverse => true
    @style.Column | @style.ColumnReverse => false
  }
  let is_reverse = match style.flex_direction {
    @style.RowReverse | @style.ColumnReverse => true
    _ => false
  }

  // For main size, if container size is auto, we use total of children (no shrink/grow)
  // However, if min-height/min-width is set, we use that for flex distribution
  let (main_size_defined, main_size) = if is_row {
    (true, content_width)
  } else {
    match content_height {
      Some(ch) => (true, ch)
      None => {
        // height: auto - check if min-height is set
        match style.min_height {
          @types.Length(min_h) => {
            let effective_min = min_h - padding.vertical_sum() - border.vertical_sum()
            (true, effective_min)
          }
          @types.Percent(p) => {
            let effective_min = parent_height * p - padding.vertical_sum() - border.vertical_sum()
            (true, effective_min)
          }
          @types.Auto => (false, 0.0)
        }
      }
    }
  }
  let cross_size = if is_row { content_height } else { Some(content_width) }

  // Phase 1: Calculate base sizes for each child
  let children = node.children
  let child_count = children.length()

  if child_count == 0 {
    // No children - just return container
    let container_height = match style.height {
      @types.Length(h) => h
      @types.Percent(p) => parent_height * p
      @types.Auto => padding.vertical_sum() + border.vertical_sum()
    }
    return {
      id: node.id,
      x: 0.0,
      y: 0.0,
      width: container_width,
      height: container_height,
      margin,
      padding,
      border,
      children: [],
    }
  }

  // Collect flex items info (skip display:none children)
  let flex_items : Array[FlexItem] = Array::new(capacity=child_count)
  let mut total_flex_grow = 0.0
  let mut total_flex_shrink = 0.0
  let mut total_base_main = 0.0

  for i = 0; i < child_count; i = i + 1 {
    let child = children[i]
    let child_style = child.style

    // Skip display:none children
    if child_style.display == @style.None {
      continue
    }

    let child_margin = resolve_rect(child_style.margin, content_width)

    // Calculate base size on main axis
    let base_main = if is_row {
      match child_style.width {
        @types.Length(w) => w
        @types.Percent(p) => content_width * p
        @types.Auto => 0.0  // Will grow/shrink
      }
    } else {
      match child_style.height {
        @types.Length(h) => h
        @types.Percent(p) => {
          match content_height {
            Some(ch) => ch * p
            None => 0.0
          }
        }
        @types.Auto => 0.0
      }
    }

    // Calculate size on cross axis
    let (base_cross, cross_is_auto) = if is_row {
      match child_style.height {
        @types.Length(h) => (h, false)
        @types.Percent(p) => {
          match content_height {
            Some(ch) => (ch * p, false)
            None => (0.0, false)
          }
        }
        @types.Auto => (0.0, true)
      }
    } else {
      match child_style.width {
        @types.Length(w) => (w, false)
        @types.Percent(p) => (content_width * p, false)
        @types.Auto => (0.0, true)
      }
    }

    let margin_main = if is_row {
      child_margin.left + child_margin.right
    } else {
      child_margin.top + child_margin.bottom
    }

    let margin_cross = if is_row {
      child_margin.top + child_margin.bottom
    } else {
      child_margin.left + child_margin.right
    }

    let item : FlexItem = {
      index: i,
      base_main,
      base_cross,
      final_main: base_main,
      final_cross: base_cross,
      margin_main,
      margin_cross,
      margin: child_margin,
      flex_grow: child_style.flex_grow,
      flex_shrink: child_style.flex_shrink,
      cross_is_auto,
    }
    flex_items.push(item)

    total_base_main = total_base_main + base_main + margin_main
    total_flex_grow = total_flex_grow + child_style.flex_grow
    total_flex_shrink = total_flex_shrink + child_style.flex_shrink
  }

  // Phase 2: Distribute remaining space (only if main size is defined)
  // Skip if no flex-grow/shrink needed
  if main_size_defined && (total_flex_grow > 0.0 || total_flex_shrink > 0.0) {
    let remaining_space = main_size - total_base_main

    if remaining_space > 0.0 && total_flex_grow > 0.0 {
      // Grow items
      for i = 0; i < flex_items.length(); i = i + 1 {
        let item = flex_items[i]
        if item.flex_grow > 0.0 {
          let grow_amount = remaining_space * (item.flex_grow / total_flex_grow)
          flex_items[i] = { ..item, final_main: item.base_main + grow_amount }
        }
      }
    } else if remaining_space < 0.0 && total_flex_shrink > 0.0 {
      // Shrink items
      let shrink_space = -remaining_space
      for i = 0; i < flex_items.length(); i = i + 1 {
        let item = flex_items[i]
        if item.flex_shrink > 0.0 {
          let shrink_amount = shrink_space * (item.flex_shrink / total_flex_shrink)
          let new_main = max(0.0, item.base_main - shrink_amount)
          flex_items[i] = { ..item, final_main: new_main }
        }
      }
    }
  }

  // Apply min/max constraints on main axis
  for i = 0; i < flex_items.length(); i = i + 1 {
    let item = flex_items[i]
    let child_style = children[item.index].style
    let original_main = item.final_main
    let mut final_main = original_main

    if is_row {
      match child_style.min_width {
        @types.Length(v) => if final_main < v { final_main = v }
        @types.Percent(p) => {
          let v = content_width * p
          if final_main < v { final_main = v }
        }
        @types.Auto => ()
      }
      match child_style.max_width {
        @types.Length(v) => if final_main > v { final_main = v }
        @types.Percent(p) => {
          let v = content_width * p
          if final_main > v { final_main = v }
        }
        @types.Auto => ()
      }
    } else {
      match child_style.min_height {
        @types.Length(v) => if final_main < v { final_main = v }
        @types.Percent(p) => {
          match content_height {
            Some(ch) => {
              let v = ch * p
              if final_main < v { final_main = v }
            }
            None => ()
          }
        }
        @types.Auto => ()
      }
      match child_style.max_height {
        @types.Length(v) => if final_main > v { final_main = v }
        @types.Percent(p) => {
          match content_height {
            Some(ch) => {
              let v = ch * p
              if final_main > v { final_main = v }
            }
            None => ()
          }
        }
        @types.Auto => ()
      }
    }

    // Only update if changed
    if final_main != original_main {
      flex_items[i] = { ..item, final_main }
    }
  }

  // Phase 3: Handle cross axis sizing
  let mut max_cross : Double = 0.0
  for i = 0; i < flex_items.length(); i = i + 1 {
    let item = flex_items[i]
    let child_style = children[item.index].style

    // For stretch alignment, item takes full cross size only if cross dimension is auto
    let final_cross = match style.align_items {
      @style.Stretch => {
        if item.cross_is_auto {
          match cross_size {
            Some(cs) => cs - item.margin_cross
            None => item.base_cross
          }
        } else {
          item.base_cross
        }
      }
      _ => item.base_cross
    }

    // Apply min/max on cross axis
    let mut constrained_cross = final_cross
    if is_row {
      match child_style.min_height {
        @types.Length(v) => if constrained_cross < v { constrained_cross = v }
        _ => ()
      }
      match child_style.max_height {
        @types.Length(v) => if constrained_cross > v { constrained_cross = v }
        _ => ()
      }
    } else {
      match child_style.min_width {
        @types.Length(v) => if constrained_cross < v { constrained_cross = v }
        _ => ()
      }
      match child_style.max_width {
        @types.Length(v) => if constrained_cross > v { constrained_cross = v }
        _ => ()
      }
    }

    // Only update if cross size changed from base
    if constrained_cross != item.base_cross {
      flex_items[i] = { ..item, final_cross: constrained_cross }
    }
    max_cross = max(max_cross, constrained_cross + item.margin_cross)
  }

  // Phase 4: Position items with justify-content
  let actual_main_used : Double = {
    let mut sum = 0.0
    for i = 0; i < flex_items.length(); i = i + 1 {
      let item = flex_items[i]
      sum = sum + item.final_main + item.margin_main
    }
    sum
  }
  let free_space = main_size - actual_main_used

  // Calculate start position and gap based on justify-content
  let visible_count = flex_items.length()
  let (start_offset, gap) = compute_justify(
    style.justify_content,
    free_space,
    visible_count
  )

  // Phase 5: Build child layouts
  let child_layouts : Array[@node.Layout] = Array::new(capacity=visible_count)
  let mut main_pos = start_offset

  // Iterate in order or reverse based on flex direction
  for j = 0; j < visible_count; j = j + 1 {
    // Calculate actual index based on direction
    let i = if is_reverse { visible_count - 1 - j } else { j }
    let item = flex_items[i]
    let child = children[item.index]  // Use original index from flex_items

    // Compute cross position based on align-items
    let cross_align_offset = compute_align(
      style.align_items,
      item.final_cross,
      cross_size.unwrap_or(max_cross),
      item.margin_cross
    )

    // Add margin to main position
    let main_start = if is_row { item.margin.left } else { item.margin.top }
    let cross_start = if is_row { item.margin.top } else { item.margin.left }

    // Calculate x, y based on direction
    let (child_x, child_y) = if is_row {
      let x = main_pos + main_start + padding.left + border.left
      let y = cross_align_offset + cross_start + padding.top + border.top
      (x, y)
    } else {
      let x = cross_align_offset + cross_start + padding.left + border.left
      let y = main_pos + main_start + padding.top + border.top
      (x, y)
    }

    let (child_width, child_height) = if is_row {
      (item.final_main, item.final_cross)
    } else {
      (item.final_cross, item.final_main)
    }

    // Build child layout - optimize for leaf nodes
    let child_layout : @node.Layout = if child.children.length() == 0 {
      // Leaf node: skip nested computation entirely
      let child_style = child.style
      let child_padding = resolve_rect(child_style.padding, child_width)
      let child_border = resolve_rect(child_style.border, child_width)
      {
        id: child.id,
        x: child_x,
        y: child_y,
        width: child_width,
        height: child_height,
        margin: item.margin,
        padding: child_padding,
        border: child_border,
        children: [],
      }
    } else {
      // Container node: recursively compute
      let child_ctx : @node.LayoutContext = {
        available_width: child_width,
        available_height: Some(child_height),
      }
      let nested_layout = compute_nested(child, child_ctx, warnings)
      {
        id: child.id,
        x: child_x,
        y: child_y,
        width: child_width,
        height: child_height,
        margin: item.margin,
        padding: nested_layout.padding,
        border: nested_layout.border,
        children: nested_layout.children,
      }
    }
    child_layouts.push(child_layout)

    // Advance main position
    main_pos = main_pos + item.final_main + item.margin_main + gap
  }

  // Calculate container height
  let container_height = match style.height {
    @types.Length(h) => h
    @types.Percent(p) => parent_height * p
    @types.Auto => {
      if is_row {
        max_cross + padding.vertical_sum() + border.vertical_sum()
      } else {
        actual_main_used + padding.vertical_sum() + border.vertical_sum()
      }
    }
  }

  // Apply min/max height
  let mut final_height = container_height
  match style.min_height {
    @types.Length(v) => if final_height < v { final_height = v }
    @types.Percent(p) => {
      let v = parent_height * p
      if final_height < v { final_height = v }
    }
    @types.Auto => ()
  }
  match style.max_height {
    @types.Length(v) => if final_height > v { final_height = v }
    @types.Percent(p) => {
      let v = parent_height * p
      if final_height > v { final_height = v }
    }
    @types.Auto => ()
  }

  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: container_width,
    height: final_height,
    margin,
    padding,
    border,
    children: child_layouts,
  }
}

///|
/// Compute nested children for a flex item
fn compute_nested(
  node : @node.Node,
  ctx : @node.LayoutContext,
  warnings : Array[@node.LayoutWarning]
) -> @node.Layout {
  let style = node.style
  let parent_width = ctx.available_width

  let padding = resolve_rect(style.padding, parent_width)
  let border = resolve_rect(style.border, parent_width)

  // For leaf nodes, just return the computed layout
  if node.children.length() == 0 {
    return {
      id: node.id,
      x: 0.0,
      y: 0.0,
      width: ctx.available_width,
      height: ctx.available_height.unwrap_or(0.0),
      margin: @types.Rect::zero(),
      padding,
      border,
      children: [],
    }
  }

  // For containers, recurse based on display type
  match style.display {
    @style.Flex => compute_internal(node, ctx, warnings)
    _ => {
      // Default to flex for now (block will be handled by dispatcher)
      compute_internal(node, ctx, warnings)
    }
  }
}

///|
/// Flex item intermediate data
priv struct FlexItem {
  index : Int
  base_main : Double
  base_cross : Double
  final_main : Double
  final_cross : Double
  margin_main : Double
  margin_cross : Double
  margin : @types.Rect[Double]
  flex_grow : Double
  flex_shrink : Double
  cross_is_auto : Bool
}

///|
/// Compute justify-content positioning
fn compute_justify(
  justify : @style.Alignment,
  free_space : Double,
  item_count : Int
) -> (Double, Double) {
  // Returns (start_offset, gap_between_items)
  if item_count == 0 {
    return (0.0, 0.0)
  }

  match justify {
    @style.Start => (0.0, 0.0)
    @style.End => (free_space, 0.0)
    @style.Center => (free_space / 2.0, 0.0)
    @style.SpaceBetween => {
      if item_count == 1 {
        (0.0, 0.0)
      } else {
        (0.0, free_space / (item_count - 1).to_double())
      }
    }
    @style.SpaceAround => {
      let gap = free_space / item_count.to_double()
      (gap / 2.0, gap)
    }
    @style.SpaceEvenly => {
      let gap = free_space / (item_count + 1).to_double()
      (gap, gap)
    }
    @style.Stretch => (0.0, 0.0)  // Stretch doesn't apply to main axis
  }
}

///|
/// Compute align-items positioning
fn compute_align(
  align : @style.Alignment,
  item_cross : Double,
  container_cross : Double,
  margin_cross : Double
) -> Double {
  let available = container_cross - item_cross - margin_cross
  match align {
    @style.Start => 0.0
    @style.End => available
    @style.Center => available / 2.0
    @style.Stretch => 0.0  // Already handled in cross size calculation
    _ => 0.0  // Default to start for space-* alignments
  }
}
