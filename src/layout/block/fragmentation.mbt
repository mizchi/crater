///|
fn get_effective_layout_height(layout : @types.Layout) -> Double {
  if layout.height > 0.0 || layout.children.length() == 0 {
    return layout.height
  }
  let mut total_height = 0.0
  for child in layout.children {
    total_height = total_height + get_effective_layout_height(child)
  }
  total_height
}

///|
/// Calculate total height contribution from children layouts
/// Used for display: contents elements where the parent needs children's height
/// Note: margins are handled through margin collapsing, not added to height
fn get_children_total_height(children : Array[@types.Layout]) -> Double {
  let mut total_height = 0.0
  for child in children {
    total_height = total_height + get_effective_layout_height(child)
  }
  total_height
}

///|
/// Heuristic: treat boxes with only inline in-flow descendants as unbreakable
/// units for multicol overflow-avoid placement.
fn is_unbreakable_fragment_unit(
  source_node : @node.Node,
  layout : @types.Layout,
) -> Bool {
  if layout.children.length() == 0 {
    return true
  }
  let mut has_inflow_block_descendant = false
  for child in source_node.children {
    if child.style.display == @types.Display::None {
      continue
    }
    if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    if child.style.float != @types.Float::None {
      continue
    }
    if not(@inline.is_inline_level(child.style.display)) {
      has_inflow_block_descendant = true
      break
    }
  }
  not(has_inflow_block_descendant)
}

///|
/// Compute occupied height extent from positioned children in local coordinates.
fn get_children_flow_extent_height(children : Array[@types.Layout]) -> Double {
  if children.length() == 0 {
    return 0.0
  }
  let mut min_top = @double.infinity
  let mut max_bottom = -@double.infinity
  for child in children {
    let child_height = if child.height > 0.0 {
      child.height
    } else {
      get_children_flow_extent_height(child.children)
    }
    let top = child.y
    let bottom = child.y + child_height
    if top < min_top {
      min_top = top
    }
    if bottom > max_bottom {
      max_bottom = bottom
    }
  }
  if min_top == @double.infinity || max_bottom == -@double.infinity {
    0.0
  } else {
    let extent = max_bottom - min_top
    if extent > 0.0 {
      extent
    } else {
      0.0
    }
  }
}

///|
/// Compute occupied width extent from positioned children in local coordinates.
fn get_children_flow_extent_width(children : Array[@types.Layout]) -> Double {
  if children.length() == 0 {
    return 0.0
  }
  let mut min_left = @double.infinity
  let mut max_right = -@double.infinity
  for child in children {
    let child_width = if child.width > 0.0 {
      child.width
    } else {
      get_children_flow_extent_width(child.children)
    }
    let left = child.x
    let right = child.x + child_width
    if left < min_left {
      min_left = left
    }
    if right > max_right {
      max_right = right
    }
  }
  if min_left == @double.infinity || max_right == -@double.infinity {
    0.0
  } else {
    let extent = max_right - min_left
    if extent > 0.0 {
      extent
    } else {
      0.0
    }
  }
}

///|
/// Reflow one level of descendants for multicol fragmentation, preserving each
/// child's local x offset while allowing column-break carry-over from a parent
/// fragment offset.
fn reflow_fragmented_children_with_offset(
  child_layouts : Array[@types.Layout],
  source_children : Array[@node.Node],
  limit : Double,
  fragment_offset : Double,
  prefer_next_column_for_block_children : Bool,
  multicol_fragment_contained : Bool,
  multicol_column_count : Int,
  multicol_column_width : Double,
  multicol_column_gap : Double,
) -> Array[@types.Layout] {
  if child_layouts.length() == 0 || limit <= 0.0 {
    return child_layouts
  }
  let positioned : Array[@types.Layout] = []
  let mut pos = 0.0
  for j = 0; j < child_layouts.length(); j = j + 1 {
    let child_layout = child_layouts[j]
    let child_style = if j < source_children.length() {
      source_children[j].style
    } else {
      @style.Style::default()
    }
    let child_is_inflow_float = child_style.float != @types.Float::None &&
      child_style.position != @types.Absolute &&
      child_style.position != @types.Fixed
    let child_unbreakable = if j < source_children.length() {
      is_unbreakable_fragment_unit(source_children[j], child_layout)
    } else {
      child_layout.children.length() == 0
    }
    let child_flow_height = if child_style.display == @types.Contents {
      get_children_total_height(child_layout.children)
    } else if child_layout.height <= 0.0 && child_layout.children.length() > 0 {
      get_children_total_height(child_layout.children)
    } else {
      child_layout.height
    }
    let child_outer_height = child_flow_height +
      child_layout.margin.top +
      child_layout.margin.bottom
    if not(child_is_inflow_float) {
      if j > 0 {
        let prev_style = if j - 1 < source_children.length() {
          source_children[j - 1].style
        } else {
          @style.Style::default()
        }
        if prev_style.break_after == @style.BreakBefore::Column && pos > 0.0 {
          let effective_pos = pos + fragment_offset
          let col = (effective_pos / limit).to_int()
          let next_effective = (col + 1).to_double() * limit
          pos = next_effective - fragment_offset
          if pos < 0.0 {
            pos = 0.0
          }
        }
      }
      if child_style.break_before == @style.BreakBefore::Column && pos > 0.0 {
        let effective_pos = pos + fragment_offset
        let col = (effective_pos / limit).to_int()
        let next_effective = (col + 1).to_double() * limit
        pos = next_effective - fragment_offset
        if pos < 0.0 {
          pos = 0.0
        }
      }
    }
    let mut effective_pos = if child_is_inflow_float {
      child_layout.y + fragment_offset
    } else {
      pos + fragment_offset
    }
    if not(child_is_inflow_float) &&
      prefer_next_column_for_block_children &&
      j > 0 &&
      child_layout.children.length() > 0 {
      let col = (effective_pos / limit).to_int()
      let local_pos = effective_pos - col.to_double() * limit
      if local_pos > 0.0 {
        let next_effective = (col + 1).to_double() * limit
        pos = next_effective - fragment_offset
        if pos < 0.0 {
          pos = 0.0
        }
        effective_pos = pos + fragment_offset
      }
    }
    if not(child_is_inflow_float) &&
      child_unbreakable &&
      child_outer_height <= limit &&
      effective_pos > 0.0 {
      let col = (effective_pos / limit).to_int()
      let local_pos = effective_pos - col.to_double() * limit
      if local_pos > 0.0 && local_pos + child_outer_height > limit {
        let next_effective = (col + 1).to_double() * limit
        pos = next_effective - fragment_offset
        if pos < 0.0 {
          pos = 0.0
        }
        effective_pos = pos + fragment_offset
      }
    }
    let col = (effective_pos / limit).to_int()
    let row = if multicol_fragment_contained {
      col / multicol_column_count
    } else {
      0
    }
    let col_index = if multicol_fragment_contained {
      col % multicol_column_count
    } else {
      col
    }
    let local_pos = effective_pos - col.to_double() * limit
    let child_source_children : Array[@node.Node] = []
    let mut child_has_direct_inflow_float = false
    if j < source_children.length() {
      let source_child = source_children[j]
      for g = 0; g < source_child.children.length(); g = g + 1 {
        let source_grand = source_child.children[g]
        if source_grand.style.float != @types.Float::None &&
          source_grand.style.position != @types.Absolute &&
          source_grand.style.position != @types.Fixed {
          child_has_direct_inflow_float = true
        }
        if is_whitespace_only_flow_text(source_grand) &&
          not(should_preserve_flow_whitespace_text(source_child.children, g)) {
          continue
        }
        child_source_children.push(source_grand)
      }
    }
    let child_height_zero_by_layout = child_layout.height <= 0.01
    let child_height_zero_by_style = match child_style.height {
      @types.Dimension::Length(h) => h == 0.0
      _ => false
    }
    let child_height_zero = child_height_zero_by_layout ||
      child_height_zero_by_style
    let positioned_children = if child_layout.children.length() > 0 {
      let nested_prefer_next_column = prefer_next_column_for_block_children ||
        child_height_zero
      let child_fragment_offset = if child_has_direct_inflow_float {
        fragment_offset
      } else {
        local_pos
      }
      reflow_fragmented_children_with_offset(
        child_layout.children,
        child_source_children,
        limit,
        child_fragment_offset,
        nested_prefer_next_column,
        multicol_fragment_contained,
        multicol_column_count,
        multicol_column_width,
        multicol_column_gap,
      )
    } else {
      child_layout.children
    }
    let adjusted_positioned_children = if prefer_next_column_for_block_children &&
      not(child_has_direct_inflow_float) &&
      positioned_children.length() > 1 {
      let shifted_children : Array[@types.Layout] = []
      let mut shifted_any = false
      let column_shift = multicol_column_width + multicol_column_gap
      for idx = 0; idx < positioned_children.length(); idx = idx + 1 {
        let positioned_child = positioned_children[idx]
        if not(shifted_any) &&
          idx > 0 &&
          positioned_child.children.length() > 0 &&
          positioned_child.x <= 0.01 {
          shifted_children.push(
            shift_layout_subtree(positioned_child, column_shift, 0.0),
          )
          shifted_any = true
        } else {
          shifted_children.push(positioned_child)
        }
      }
      shifted_children
    } else {
      positioned_children
    }
    let positioned_children_width = get_children_flow_extent_width(
      adjusted_positioned_children,
    )
    let child_auto_height = match child_style.height {
      @types.Dimension::Auto => true
      _ => false
    }
    let allow_fragment_box_expansion = child_auto_height &&
      child_style.column_span != @style.ColumnSpan::All &&
      not(@inline.is_inline_level(child_style.display)) &&
      not(child_has_direct_inflow_float)
    let positioned_width = if allow_fragment_box_expansion &&
      positioned_children_width > child_layout.width {
      positioned_children_width
    } else {
      child_layout.width
    }
    let positioned_height = if allow_fragment_box_expansion &&
      positioned_width > child_layout.width &&
      child_layout.height < limit &&
      child_layout.height > 0.0 {
      limit
    } else {
      child_layout.height
    }
    let mut positioned_x = child_layout.x +
      col_index.to_double() * (multicol_column_width + multicol_column_gap)
    if prefer_next_column_for_block_children &&
      j > 0 &&
      child_layout.children.length() > 0 &&
      not(child_has_direct_inflow_float) &&
      local_pos <= 0.01 &&
      positioned.length() > 0 {
      let prev_x = positioned[positioned.length() - 1].x
      if positioned_x > prev_x {
        positioned_x = prev_x
      }
    }
    positioned.push({
      ..child_layout,
      x: positioned_x,
      y: row.to_double() * limit + local_pos - fragment_offset,
      width: positioned_width,
      height: positioned_height,
      children: adjusted_positioned_children,
    })
    if not(child_is_inflow_float) {
      pos = pos + child_outer_height
    }
  }
  positioned
}

///|
/// Browser-compat quirk for inline wrappers that only contain floated content.
/// Browsers report zero-sized inline box shifted after its float contribution.
fn adjust_inline_span_float_quirk(
  layout : @types.Layout,
  is_vertical_writing : Bool,
) -> @types.Layout {
  if layout.id != "span" ||
    is_vertical_writing ||
    layout.height != 0.0 ||
    layout.width <= 0.0 ||
    layout.children.length() == 0 {
    return layout
  }

  let mut has_visible_child = false
  for child in layout.children {
    if child.width > 0.0 || child.height > 0.0 {
      has_visible_child = true
      break
    }
  }

  if not(has_visible_child) {
    return layout
  }

  let shifted_children : Array[@types.Layout] = []
  for child in layout.children {
    shifted_children.push({ ..child, x: child.x - layout.width })
  }

  {
    ..layout,
    x: layout.x + layout.width,
    width: 0.0,
    children: shifted_children,
  }
}
