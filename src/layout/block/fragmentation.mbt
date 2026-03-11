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
  if source_node.style.break_inside == @style.BreakInside::Avoid {
    return true
  }
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
fn is_fragmentation_block_flow_box(
  node : @node.Node,
  style : @style.Style,
) -> Bool {
  not(@inline.is_inline_level(style.display)) ||
  (
    @inline.is_inline_level(style.display) &&
    node.children.length() > 0 &&
    not(contents_is_inline_flow(node))
  )
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
  first_fragment_end_reserve : Double,
  normalize_to_row_start : Bool,
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
    let child_following_reserved_height = if first_fragment_end_reserve > 0.0 {
      first_fragment_end_reserve
    } else {
      resolve_multicol_nested_following_reserved_height(
        j, child_layouts, source_children,
      )
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
    let child_style_margin_top = match child_style.margin.top {
      @types.Dimension::Length(v) => v
      _ => 0.0
    }
    let child_visual_margin_top = if child_layout.margin.top >
      child_style_margin_top {
      child_layout.margin.top
    } else {
      child_style_margin_top
    }
    let child_outer_height = child_flow_height +
      child_visual_margin_top +
      child_layout.margin.bottom
    let child_fragment_start_margin_top = if child_visual_margin_top > 0.0 {
      0.0
    } else {
      child_visual_margin_top
    }
    let child_fragment_start_outer_height = child_flow_height +
      child_fragment_start_margin_top +
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
    let effective_limit = if child_following_reserved_height > 0.0 {
      let col = (effective_pos / limit).to_int()
      if col == 0 && child_following_reserved_height < limit {
        limit - child_following_reserved_height
      } else {
        limit
      }
    } else {
      limit
    }
    let mut effective_child_outer_height = child_outer_height
    let mut discard_top_margin_at_fragment_start = false
    if not(child_is_inflow_float) &&
      child_visual_margin_top > 0.0 &&
      child_fragment_start_outer_height <= effective_limit &&
      effective_pos > 0.0 {
      let col = (effective_pos / limit).to_int()
      let local_pos = effective_pos - col.to_double() * limit
      let local_limit = if col == 0 { effective_limit } else { limit }
      if local_pos > 0.0 &&
        local_pos + child_fragment_start_outer_height > local_limit {
        discard_top_margin_at_fragment_start = true
        effective_child_outer_height = child_fragment_start_outer_height
      }
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
      effective_child_outer_height <= effective_limit &&
      effective_pos > 0.0 {
      let col = (effective_pos / limit).to_int()
      let local_pos = effective_pos - col.to_double() * limit
      let local_limit = if col == 0 { effective_limit } else { limit }
      if local_pos > 0.0 &&
        local_pos + effective_child_outer_height > local_limit {
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
    let source_child_node = if j < source_children.length() {
      source_children[j]
    } else {
      @node.Node::new(child_layout.id, @style.Style::default(), [])
    }
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
      let child_fragment_offset = if discard_top_margin_at_fragment_start {
        0.0
      } else if child_has_direct_inflow_float {
        fragment_offset
      } else {
        local_pos
      }
      let deep_single_child_reserve_case = child_following_reserved_height > 0.0 &&
        child_layout.children.length() == 1 &&
        child_layout.children[0].children.length() > 0 &&
        not(@inline.is_inline_level(child_style.display))
      if deep_single_child_reserve_case {
        let deep_layout = child_layout.children[0]
        let deep_source_node = if child_source_children.length() > 0 {
          child_source_children[0]
        } else {
          @node.Node::new(deep_layout.id, @style.Style::default(), [])
        }
        let deep_source_children = collect_preserved_flow_source_children(
          deep_source_node.children,
        )
        let deep_first_child_y = if deep_layout.children.length() > 0 {
          deep_layout.children[0].y
        } else {
          0.0
        }
        let deep_fragment_offset = child_fragment_offset + deep_first_child_y
        let deep_positioned_children = reflow_fragmented_children_with_offset(
          deep_layout.children,
          deep_source_children,
          limit,
          deep_fragment_offset,
          child_following_reserved_height,
          normalize_to_row_start,
          false,
          multicol_fragment_contained,
          multicol_column_count,
          multicol_column_width,
          multicol_column_gap,
        )
        let deep_positioned_span = resolve_multicol_positioned_column_span(
          deep_positioned_children, multicol_column_width, multicol_column_gap,
        )
        let deep_children_width = get_children_flow_extent_width(
          deep_positioned_children,
        )
        let deep_base_width = if deep_positioned_span > 1 {
          deep_layout.width +
          (multicol_column_width + multicol_column_gap) *
          (deep_positioned_span - 1).to_double()
        } else {
          deep_layout.width
        }
        let deep_width = if deep_children_width > deep_base_width {
          deep_children_width
        } else {
          deep_base_width
        }
        let deep_height = if deep_positioned_span > 1 &&
          deep_layout.height > 0.0 &&
          deep_layout.height < limit {
          limit
        } else {
          deep_layout.height
        }
        [
          {
            ..deep_layout,
            width: deep_width,
            height: deep_height,
            children: deep_positioned_children,
          },
        ]
      } else {
        reflow_fragmented_children_with_offset(
          child_layout.children,
          child_source_children,
          limit,
          child_fragment_offset,
          child_following_reserved_height,
          normalize_to_row_start,
          nested_prefer_next_column,
          multicol_fragment_contained,
          multicol_column_count,
          multicol_column_width,
          multicol_column_gap,
        )
      }
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
    let positioned_children_flow_extent = if adjusted_positioned_children.length() >
      0 {
      let column_step = multicol_column_width + multicol_column_gap
      let mut max_bottom = 0.0
      for positioned_child in adjusted_positioned_children {
        let nested_extent = if positioned_child.children.length() > 0 {
          get_children_flow_extent_height(positioned_child.children)
        } else {
          0.0
        }
        let child_extent = if nested_extent > positioned_child.height {
          nested_extent
        } else {
          positioned_child.height
        }
        let column_index = if column_step > 0.0 && positioned_child.x > 0.0 {
          (positioned_child.x / column_step).floor().to_int()
        } else {
          0
        }
        let bottom = positioned_child.y +
          child_extent +
          column_index.to_double() * limit
        if bottom > max_bottom {
          max_bottom = bottom
        }
      }
      max_bottom
    } else {
      0.0
    }
    let child_fragment_columns = if child_style.column_span !=
      @style.ColumnSpan::All &&
      is_fragmentation_block_flow_box(source_child_node, child_style) &&
      effective_child_outer_height > limit {
      let mut needed = (effective_child_outer_height / limit).ceil().to_int()
      if needed < 1 {
        needed = 1
      }
      if multicol_fragment_contained && needed > multicol_column_count {
        multicol_column_count
      } else {
        needed
      }
    } else {
      1
    }
    let single_column_fragment_width = if child_style.display != @types.Contents &&
      child_style.column_span != @style.ColumnSpan::All &&
      child_fragment_columns == 1 &&
      multicol_column_width > 0.0 {
      match child_style.width {
        @types.Dimension::Auto => multicol_column_width
        _ => child_layout.width
      }
    } else {
      child_layout.width
    }
    let base_fragmented_width = if child_fragment_columns > 1 {
      child_layout.width +
      (multicol_column_width + multicol_column_gap) *
      (child_fragment_columns - 1).to_double()
    } else {
      single_column_fragment_width
    }
    let base_fragmented_height = if child_fragment_columns > 1 {
      limit
    } else {
      child_layout.height
    }
    let child_auto_height = match child_style.height {
      @types.Dimension::Auto => true
      _ => false
    }
    let allow_fragment_box_expansion = child_auto_height &&
      child_style.column_span != @style.ColumnSpan::All &&
      is_fragmentation_block_flow_box(source_child_node, child_style) &&
      not(child_has_direct_inflow_float)
    let positioned_width = if allow_fragment_box_expansion &&
      positioned_children_width > base_fragmented_width {
      positioned_children_width
    } else {
      base_fragmented_width
    }
    let positioned_height = if allow_fragment_box_expansion &&
      positioned_width > base_fragmented_width &&
      base_fragmented_height < limit &&
      base_fragmented_height > 0.0 {
      limit
    } else {
      base_fragmented_height
    }
    let normalize_child_box_to_row_start = child_fragment_columns > 1 ||
      positioned_children_width > base_fragmented_width + 0.01 ||
      positioned_children_flow_extent > effective_child_outer_height + 0.01
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
      y: if normalize_to_row_start {
        if normalize_child_box_to_row_start {
          row.to_double() * limit
        } else {
          row.to_double() * limit + local_pos
        }
      } else {
        row.to_double() * limit + local_pos - fragment_offset
      },
      width: positioned_width,
      height: positioned_height,
      children: adjusted_positioned_children,
    })
    if not(child_is_inflow_float) {
      if positioned_children_flow_extent > child_outer_height + 0.01 {
        pos = row.to_double() * limit +
          positioned_children_flow_extent -
          fragment_offset
        if pos < 0.0 {
          pos = 0.0
        }
      } else {
        pos = pos + child_outer_height
      }
    }
  }
  positioned
}

///|
fn source_children_only_contribute_floats(children : Array[@node.Node]) -> Bool {
  let mut has_float_contribution = false
  for child in children {
    if child.style.display == @types.Display::None {
      continue
    }
    if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    if child.id.has_prefix("#text") {
      match child.text {
        Some(text) =>
          if not(is_whitespace_only_flow_text(child)) && not(text.is_empty()) {
            return false
          }
        None => ()
      }
      continue
    }
    match child.style.float {
      @types.Float::Left | @types.Float::Right => {
        has_float_contribution = true
        continue
      }
      @types.Float::None => ()
    }
    if child.children.length() == 0 ||
      @inline.is_inline_level(child.style.display) ||
      child.style.display == @types.Contents ||
      not(source_children_only_contribute_floats(child.children)) {
      return false
    }
    has_float_contribution = true
  }
  has_float_contribution
}

///|
/// Browser-compat quirk for inline wrappers that only contain floated content.
/// Browsers report zero-sized inline box shifted after its float contribution.
fn adjust_inline_span_float_quirk(
  layout : @types.Layout,
  source_node : @node.Node,
  is_vertical_writing : Bool,
) -> @types.Layout {
  if not(id_matches_tag(layout.id, "span")) ||
    not(id_matches_tag(source_node.id, "span")) ||
    is_vertical_writing ||
    layout.height != 0.0 ||
    layout.width <= 0.0 ||
    layout.children.length() == 0 {
    return layout
  }

  let has_inflow_float = source_children_only_contribute_floats(
    source_node.children,
  )
  if not(has_inflow_float) {
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
