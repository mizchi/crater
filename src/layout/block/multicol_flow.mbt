///|
fn resolve_multicol_explicit_width(
  style : @style.Style,
  content_width : Double,
  parent_width : Double,
) -> Double? {
  match style.column_width {
    @types.Length(v) => if v > 0.0 { Some(v) } else { None }
    @types.Percent(p) =>
      if p > 0.0 {
        let basis = if content_width > 0.0 {
          content_width
        } else {
          parent_width
        }
        Some(basis * p)
      } else {
        None
      }
    @types.Auto
    | @types.MinContent
    | @types.MaxContent
    | @types.FitContent(_) => None
  }
}

///|
fn estimate_multicol_intrinsic_content_width(
  style : @style.Style,
  parent_width : Double,
) -> Double {
  if not(style.has_multicol()) {
    return 0.0
  }
  let gap = if style.column_gap_is_normal {
    style.font_size
  } else {
    style.column_gap.resolve_or(parent_width, 0.0)
  }
  let gap = if gap > 0.0 { gap } else { 0.0 }
  let count = match style.column_count {
    Some(v) => if v > 0 { v } else { 1 }
    None => 1
  }
  let gap_total = if count > 1 { gap * (count - 1).to_double() } else { 0.0 }
  match resolve_multicol_explicit_width(style, 0.0, parent_width) {
    Some(width) =>
      if count > 1 {
        width * count.to_double() + gap_total
      } else {
        width
      }
    None => gap_total
  }
}

///|
fn resolve_multicol_track_geometry(
  style : @style.Style,
  content_width : Double,
  parent_width : Double,
) -> (Int, Double, Double) {
  let gap_basis = if content_width > 0.0 { content_width } else { parent_width }
  let resolved_gap = if style.column_gap_is_normal {
    style.font_size
  } else {
    style.column_gap.resolve_or(gap_basis, 0.0)
  }
  let gap = if resolved_gap > 0.0 { resolved_gap } else { 0.0 }

  let explicit_count = match style.column_count {
    Some(v) => if v > 0 { v } else { 1 }
    None => 0
  }
  let explicit_width = resolve_multicol_explicit_width(
    style, content_width, parent_width,
  )

  if explicit_count > 0 {
    let gaps = gap * (explicit_count - 1).to_double()
    let width = if content_width > gaps {
      (content_width - gaps) / explicit_count.to_double()
    } else if explicit_width is Some(v) {
      v
    } else {
      0.0
    }
    return (explicit_count, if width > 0.0 { width } else { 0.0 }, gap)
  }

  match explicit_width {
    Some(target_width) =>
      if content_width > 0.0 {
        let denom = target_width + gap
        let count = if denom > 0.0 {
          let candidate = ((content_width + gap) / denom).to_int()
          if candidate > 0 {
            candidate
          } else {
            1
          }
        } else {
          1
        }
        let gaps = gap * (count - 1).to_double()
        let width = if content_width > gaps {
          (content_width - gaps) / count.to_double()
        } else {
          0.0
        }
        (count, if width > 0.0 { width } else { target_width }, gap)
      } else {
        (1, target_width, gap)
      }
    None => (1, content_width, gap)
  }
}

///|
fn estimate_multicol_column_height_limit(
  child_available_height : Double?,
  flow_children : Array[LayoutWithCollapse],
  flow_styles : Array[@style.Style],
  column_count : Int,
  column_fill : @style.ColumnFill,
) -> Double? {
  fn estimate_balanced_limit(
    flow_children : Array[LayoutWithCollapse],
    flow_styles : Array[@style.Style],
    column_count : Int,
  ) -> Double? {
    if column_count <= 1 {
      return None
    }
    let mut total = 0.0
    for i = 0; i < flow_children.length() && i < flow_styles.length(); i = i + 1 {
      if flow_styles[i].column_span == @style.ColumnSpan::All {
        continue
      }
      let layout = flow_children[i].layout
      let flow_height = if flow_styles[i].display == @types.Contents {
        get_children_total_height(layout.children)
      } else {
        layout.height
      }
      total = total + flow_height + layout.margin.top + layout.margin.bottom
    }
    if total > 0.0 {
      Some(total / column_count.to_double())
    } else {
      None
    }
  }
  let balanced = estimate_balanced_limit(
    flow_children, flow_styles, column_count,
  )
  match column_fill {
    @style.ColumnFill::Auto =>
      match child_available_height {
        Some(h) => if h > 0.0 { Some(h) } else { balanced }
        None => balanced
      }
    @style.ColumnFill::Balance =>
      match balanced {
        Some(limit) =>
          match child_available_height {
            Some(h) => if h > 0.0 && limit > h { Some(h) } else { Some(limit) }
            None => Some(limit)
          }
        None =>
          match child_available_height {
            Some(h) => if h > 0.0 { Some(h) } else { None }
            None => None
          }
      }
  }
}

///|
fn resolve_text_align_offset(
  text_align : @style.TextAlign,
  direction : @style.Direction,
  available_width : Double,
  line_width : Double,
) -> Double {
  let remaining = if available_width > line_width {
    available_width - line_width
  } else {
    0.0
  }
  match text_align {
    @style.TextAlign::Center => remaining / 2.0
    @style.TextAlign::Right => remaining
    @style.TextAlign::Left => 0.0
    @style.TextAlign::End => if direction.is_rtl() { 0.0 } else { remaining }
    @style.TextAlign::Start => if direction.is_rtl() { remaining } else { 0.0 }
    @style.TextAlign::Justify => 0.0
  }
}

///|
fn is_inline_flow_participant(node : @node.Node, style : @style.Style) -> Bool {
  node.id == "br" ||
  node.id.has_prefix("#text") ||
  @inline.is_inline_level(style.display)
}

///|
fn estimate_multicol_inline_line_width(
  start_index : Int,
  flow_children : Array[LayoutWithCollapse],
  flow_styles : Array[@style.Style],
  flow_nodes : Array[@node.Node],
  column_width : Double,
) -> Double {
  let mut total = 0.0
  let mut has_item = false
  for j = start_index; j < flow_children.length(); j = j + 1 {
    if j >= flow_styles.length() || j >= flow_nodes.length() {
      break
    }
    let child_style = flow_styles[j]
    let child_node = flow_nodes[j]
    if not(is_inline_flow_participant(child_node, child_style)) ||
      child_style.position == @types.Absolute ||
      child_style.position == @types.Fixed {
      break
    }
    if child_node.id == "br" {
      break
    }
    let child_layout = flow_children[j].layout
    let advance = child_layout.width +
      child_layout.margin.left +
      child_layout.margin.right
    if has_item && column_width > 0.0 && total + advance > column_width {
      break
    }
    total = total + advance
    has_item = true
  }
  total
}

///|
fn collect_preserved_flow_source_children(
  children : Array[@node.Node],
) -> Array[@node.Node] {
  let result : Array[@node.Node] = []
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    if is_whitespace_only_flow_text(child) &&
      not(should_preserve_flow_whitespace_text(children, i)) {
      continue
    }
    result.push(child)
  }
  result
}

///|
fn has_inflow_fragment_child(children : Array[@node.Node]) -> Bool {
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
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
    if is_whitespace_only_flow_text(child) &&
      not(should_preserve_flow_whitespace_text(children, i)) {
      continue
    }
    return true
  }
  false
}

///|
fn resolve_multicol_nested_fragment_offset(
  column_span : @style.ColumnSpan,
  local_y : Double,
) -> Double {
  if column_span == @style.ColumnSpan::All {
    0.0
  } else {
    local_y
  }
}

///|
fn resolve_nested_fragment_flow_height(
  nested_layout : @types.Layout,
  nested_style : @style.Style,
) -> Double {
  if nested_style.display == @types.Contents {
    get_children_total_height(nested_layout.children)
  } else if nested_layout.height <= 0.0 && nested_layout.children.length() > 0 {
    get_children_total_height(nested_layout.children)
  } else {
    nested_layout.height
  }
}

///|
fn has_forced_column_break_descendant(children : Array[@node.Node]) -> Bool {
  for child in children {
    if child.style.break_before == @style.BreakBefore::Column ||
      child.style.break_after == @style.BreakBefore::Column {
      return true
    }
  }
  false
}

///|
fn has_break_inside_avoid_descendant(children : Array[@node.Node]) -> Bool {
  for child in children {
    if child.style.break_inside == @style.BreakInside::Avoid {
      return true
    }
    if has_break_inside_avoid_descendant(child.children) {
      return true
    }
  }
  false
}

///|
fn is_multicol_nested_reflow_candidate(
  multicol_participates_in_inline_run : Bool,
  child_layout : @types.Layout,
  multicol_column_width : Double,
) -> Bool {
  not(multicol_participates_in_inline_run) ||
  (
    child_layout.children.length() > 0 &&
    child_layout.width + 0.01 >= multicol_column_width
  )
}

///|
fn should_reflow_multicol_nested_children(
  child_layout : @types.Layout,
  child_style : @style.Style,
  has_nested_forced_column_break : Bool,
  fragmented_columns : Int,
  multicol_nested_reflow_candidate : Bool,
  local_y : Double,
) -> Bool {
  child_layout.children.length() > 1 &&
  (
    has_nested_forced_column_break ||
    child_style.display == @types.Contents ||
    (fragmented_columns > 1 && multicol_nested_reflow_candidate) ||
    (
      multicol_nested_reflow_candidate &&
      child_style.column_span != @style.ColumnSpan::All &&
      local_y > 0.0
    )
  )
}

///|
fn process_multicol_flow_child(
  i : Int,
  current_pos : Double,
  prev_margin_end : Double,
  inline_run_active : Bool,
  inline_run_x : Double,
  inline_run_height : Double,
  inline_run_align_offset : Double,
  padding : @types.Rect[Double],
  border : @types.Rect[Double],
  style : @style.Style,
  flow_children : Array[LayoutWithCollapse],
  flow_styles : Array[@style.Style],
  flow_nodes : Array[@node.Node],
  flow_indices : Array[Int],
  multicol_column_count : Int,
  multicol_column_width : Double,
  multicol_column_gap : Double,
  multicol_height_limit : Double?,
  multicol_fragment_contained : Bool,
  default_text_align : Bool,
  layout_map : Map[Int, @types.Layout],
  flow_y_positions : Array[Double],
) -> (Double, Double, Bool, Double, Double, Double) {
  let mut current_pos = current_pos
  let mut prev_margin_end = prev_margin_end
  let mut inline_run_active = inline_run_active
  let mut inline_run_x = inline_run_x
  let mut inline_run_height = inline_run_height
  let mut inline_run_align_offset = inline_run_align_offset

  fn reset_inline_run_state() -> Unit {
    inline_run_active = false
    inline_run_x = 0.0
    inline_run_height = 0.0
    inline_run_align_offset = 0.0
    prev_margin_end = 0.0
  }

  fn flush_inline_run_state() -> Unit {
    current_pos = current_pos + inline_run_height
    reset_inline_run_state()
  }

  fn resolve_inline_run_line_height(
    inline_item_height : Double,
    child_line_height : Double,
  ) -> Double {
    let mut line_height = if inline_run_height > inline_item_height {
      inline_run_height
    } else {
      inline_item_height
    }
    let inline_strut_height = if child_line_height > 0.0 {
      child_line_height
    } else if style.line_height > 0.0 {
      style.line_height
    } else {
      inline_item_height
    }
    if inline_strut_height > line_height {
      line_height = inline_strut_height
    }
    line_height
  }

  fn extend_inline_run(
    inline_advance : Double,
    inline_item_height : Double,
  ) -> Unit {
    inline_run_x = inline_run_x + inline_advance
    if inline_item_height > inline_run_height {
      inline_run_height = inline_item_height
    }
    inline_run_active = true
  }

  let child_result = flow_children[i]
  let child_layout = child_result.layout
  let child_collapsed = child_result.collapsed
  let child_style = flow_styles[i]
  let child_node = flow_nodes[i]
  let multicol_participates_in_inline_run = is_inline_flow_participant(
      child_node, child_style,
    ) &&
    child_style.position != @types.Absolute &&
    child_style.position != @types.Fixed
  if not(multicol_participates_in_inline_run) && inline_run_active {
    flush_inline_run_state()
  }
  let child_inline_advance = child_layout.width +
    child_layout.margin.left +
    child_layout.margin.right
  if multicol_participates_in_inline_run && child_node.id != "br" {
    if inline_run_active &&
      multicol_column_width > 0.0 &&
      inline_run_x + child_inline_advance > multicol_column_width {
      flush_inline_run_state()
    }
    if not(inline_run_active) {
      let line_width = estimate_multicol_inline_line_width(
        i, flow_children, flow_styles, flow_nodes, multicol_column_width,
      )
      inline_run_align_offset = if default_text_align {
        0.0
      } else {
        resolve_text_align_offset(
          style.text_align,
          style.direction,
          multicol_column_width,
          line_width,
        )
      }
    }
  }
  let effective_margin_top = match child_collapsed.top {
    Some(escaped) => collapse_margins(child_layout.margin.top, escaped)
    None => child_layout.margin.top
  }
  let effective_margin_bottom = match child_collapsed.bottom {
    Some(escaped) => collapse_margins(child_layout.margin.bottom, escaped)
    None => child_layout.margin.bottom
  }
  let visual_margin_top = if effective_margin_top < child_layout.margin.top {
    child_layout.margin.top
  } else {
    effective_margin_top
  }
  let visual_margin_bottom = if effective_margin_bottom <
    child_layout.margin.bottom {
    child_layout.margin.bottom
  } else {
    effective_margin_bottom
  }
  let mut effective_pos = current_pos
  if effective_pos < 0.0 {
    effective_pos = 0.0
    if current_pos < 0.0 {
      current_pos = 0.0
    }
  }
  let child_flow_height = if child_style.display == @types.Contents {
    get_children_total_height(child_layout.children)
  } else if child_layout.height <= 0.0 &&
    child_layout.children.length() > 0 &&
    not(child_style.contain.size) &&
    has_inflow_fragment_child(child_node.children) {
    get_children_total_height(child_layout.children)
  } else {
    child_layout.height
  }
  let child_outer_height = child_flow_height +
    visual_margin_top +
    visual_margin_bottom
  if multicol_participates_in_inline_run &&
    child_node.id != "br" &&
    inline_run_x == 0.0 {
    match multicol_height_limit {
      Some(limit) if limit > 0.0 => {
        let absolute_col = (effective_pos / limit).to_int()
        let local_y = effective_pos - absolute_col.to_double() * limit
        if local_y > 0.0 && local_y + child_outer_height > limit {
          effective_pos = (absolute_col + 1).to_double() * limit
          current_pos = effective_pos
        }
      }
      _ => ()
    }
  }
  let keep_unfragmented_for_monolithic = child_style.contain.size ||
    child_style.break_inside == @style.BreakInside::Avoid ||
    has_break_inside_avoid_descendant(child_node.children)
  let multicol_fragmentable_box = child_style.column_span !=
    @style.ColumnSpan::All &&
    not(multicol_participates_in_inline_run) &&
    not(keep_unfragmented_for_monolithic)
  let fragmented_columns = if multicol_fragmentable_box {
    match multicol_height_limit {
      Some(limit) if limit > 0.0 => {
        let mut needed = (child_outer_height / limit).ceil().to_int()
        if needed < 1 {
          needed = 1
        }
        if multicol_fragment_contained && needed > multicol_column_count {
          multicol_column_count
        } else {
          needed
        }
      }
      _ =>
        if child_outer_height <= 0.0 {
          1
        } else if multicol_column_count > 0 {
          multicol_column_count
        } else {
          1
        }
    }
  } else {
    1
  }
  let fragmented_union_width = if child_style.display == @types.Contents {
    child_layout.width
  } else if fragmented_columns > 1 {
    child_layout.width +
    (multicol_column_width + multicol_column_gap) *
    (fragmented_columns - 1).to_double()
  } else {
    child_layout.width
  }
  match multicol_height_limit {
    Some(limit) =>
      if limit <= 0.0 {
        ()
      } else {
        if child_style.column_span != @style.ColumnSpan::All &&
          not(multicol_participates_in_inline_run) &&
          style.column_fill == @style.ColumnFill::Auto &&
          child_outer_height <= limit &&
          effective_pos > 0.0 {
          let absolute_col = (effective_pos / limit).to_int()
          let local_y = effective_pos - absolute_col.to_double() * limit
          if local_y > 0.0 && local_y + child_outer_height > limit {
            effective_pos = (absolute_col + 1).to_double() * limit
          }
        }
        let force_column_break_before = child_style.break_before ==
          @style.BreakBefore::Column ||
          (
            i > 0 &&
            flow_styles[i - 1].break_after == @style.BreakBefore::Column
          )
        if force_column_break_before && effective_pos > 0.0 {
          let absolute_col = (effective_pos / limit).to_int()
          effective_pos = (absolute_col + 1).to_double() * limit
        }

        if child_style.column_span == @style.ColumnSpan::All {
          let absolute_col = (effective_pos / limit).to_int()
          let row_index = absolute_col / multicol_column_count
          let row_start = row_index.to_double() * limit
          effective_pos = if effective_pos > row_start {
            row_start + limit
          } else {
            row_start
          }
        }

        let absolute_col = (effective_pos / limit).to_int()
        let row_index = if multicol_fragment_contained {
          absolute_col / multicol_column_count
        } else {
          0
        }
        let column_index = if multicol_fragment_contained {
          absolute_col % multicol_column_count
        } else {
          absolute_col
        }
        let local_y = effective_pos - absolute_col.to_double() * limit
        let col_offset = if child_style.column_span == @style.ColumnSpan::All {
          0.0
        } else {
          column_index.to_double() *
          (multicol_column_width + multicol_column_gap)
        }
        let clipped_height = if fragmented_columns > 1 &&
          multicol_fragment_contained &&
          child_style.column_span != @style.ColumnSpan::All &&
          not(multicol_participates_in_inline_run) &&
          child_layout.height > limit {
          limit
        } else if fragmented_columns > 1 &&
          not(multicol_fragment_contained) &&
          child_style.column_span != @style.ColumnSpan::All &&
          not(multicol_participates_in_inline_run) &&
          child_layout.height > limit {
          limit
        } else {
          child_layout.height
        }
        let positioned_y = if child_style.column_span == @style.ColumnSpan::All {
          effective_pos
        } else {
          row_index.to_double() * limit + local_y
        }
        let has_nested_forced_column_break = has_forced_column_break_descendant(
          child_node.children,
        )
        let multicol_nested_reflow_candidate = is_multicol_nested_reflow_candidate(
          multicol_participates_in_inline_run, child_layout, multicol_column_width,
        )
        let should_reflow_nested_children = should_reflow_multicol_nested_children(
          child_layout, child_style, has_nested_forced_column_break, fragmented_columns,
          multicol_nested_reflow_candidate, local_y,
        )
        let positioned_children : Array[@types.Layout] = if should_reflow_nested_children {
          let nested_layouts : Array[@types.Layout] = []
          let nested_source_children = collect_preserved_flow_source_children(
            child_node.children,
          )
          let use_existing_nested_offsets = fragmented_columns > 1 &&
            not(has_nested_forced_column_break) &&
            child_style.display != @types.Contents
          if use_existing_nested_offsets {
            let nested_fragment_offset = resolve_multicol_nested_fragment_offset(
              child_style.column_span,
              local_y,
            )
            let mut nested_carry_delta = 0.0
            for j = 0; j < child_layout.children.length(); j = j + 1 {
              let nested_layout = child_layout.children[j]
              let nested_style = if j < nested_source_children.length() {
                nested_source_children[j].style
              } else {
                @style.Style::default()
              }
              let nested_height_zero_by_layout = nested_layout.height <= 0.01
              let nested_height_zero_by_style = match nested_style.height {
                @types.Dimension::Length(h) => h == 0.0
                _ => false
              }
              let nested_height_zero = nested_height_zero_by_layout ||
                nested_height_zero_by_style
              let nested_flow_height = resolve_nested_fragment_flow_height(
                nested_layout, nested_style,
              )
              let nested_outer_height = nested_flow_height +
                nested_layout.margin.top +
                nested_layout.margin.bottom
              let nested_is_inflow_float = nested_style.float !=
                @types.Float::None &&
                nested_style.position != @types.Absolute &&
                nested_style.position != @types.Fixed
              let nested_is_hr = nested_layout.id == "hr"
              let nested_base_unbreakable = if j <
                nested_source_children.length() {
                is_unbreakable_fragment_unit(
                  nested_source_children[j],
                  nested_layout,
                )
              } else {
                nested_layout.children.length() == 0
              }
              let nested_unbreakable = not(nested_is_hr) &&
                nested_base_unbreakable
              let mut effective_nested_y = nested_layout.y +
                nested_fragment_offset +
                nested_carry_delta
              let mut nested_col = (effective_nested_y / limit).to_int()
              let mut nested_local_y = effective_nested_y -
                nested_col.to_double() * limit
              if nested_unbreakable &&
                nested_outer_height <= limit &&
                nested_local_y > 0.0 &&
                nested_local_y + nested_outer_height > limit {
                let next_effective = (nested_col + 1).to_double() * limit
                let float_line_adjust = if nested_is_inflow_float &&
                  nested_style.line_height > 0.0 {
                  nested_style.line_height
                } else {
                  0.0
                }
                nested_carry_delta = nested_carry_delta +
                  (next_effective - effective_nested_y) +
                  float_line_adjust
                effective_nested_y = next_effective + float_line_adjust
                nested_col = (effective_nested_y / limit).to_int()
                nested_local_y = effective_nested_y -
                  nested_col.to_double() * limit
              }
              let nested_row = if multicol_fragment_contained {
                nested_col / multicol_column_count
              } else {
                0
              }
              let nested_col_index = if multicol_fragment_contained {
                nested_col % multicol_column_count
              } else {
                nested_col
              }
              let mut nested_has_direct_inflow_float = false
              let nested_positioned_children = if nested_layout.children.length() >
                0 {
                let mut matched_source_index = -1
                if j < nested_source_children.length() &&
                  nested_source_children[j].id == nested_layout.id {
                  matched_source_index = j
                } else {
                  for s = 0; s < nested_source_children.length(); s = s + 1 {
                    if nested_source_children[s].id == nested_layout.id {
                      matched_source_index = s
                      break
                    }
                  }
                }
                let nested_source_node = if matched_source_index >= 0 {
                  nested_source_children[matched_source_index]
                } else {
                  @node.Node::new(nested_layout.id, @style.Style::default(), [])
                }
                let nested_grand_source_children : Array[@node.Node] = []
                for g = 0; g < nested_source_node.children.length(); g = g + 1 {
                  let source_grand = nested_source_node.children[g]
                  if source_grand.style.float != @types.Float::None &&
                    source_grand.style.position != @types.Absolute &&
                    source_grand.style.position != @types.Fixed {
                    nested_has_direct_inflow_float = true
                  }
                  if is_whitespace_only_flow_text(source_grand) &&
                    not(
                      should_preserve_flow_whitespace_text(
                        nested_source_node.children,
                        g,
                      ),
                    ) {
                    continue
                  }
                  nested_grand_source_children.push(source_grand)
                }
                reflow_fragmented_children_with_offset(
                  nested_layout.children,
                  nested_grand_source_children,
                  limit,
                  nested_local_y,
                  nested_height_zero,
                  multicol_fragment_contained,
                  multicol_column_count,
                  multicol_column_width,
                  multicol_column_gap,
                )
              } else {
                nested_layout.children
              }
              let mut nested_child_y_offset = 0.0
              let adjusted_nested_positioned_children = if nested_height_zero &&
                nested_local_y > 0.0 &&
                nested_positioned_children.length() > 1 {
                let shifted_children : Array[@types.Layout] = []
                let mut shifted_any = false
                let column_shift = multicol_column_width + multicol_column_gap
                for idx = 0
                    idx < nested_positioned_children.length()
                    idx = idx + 1 {
                  let nested_child = nested_positioned_children[idx]
                  let shift_zero_height_float = nested_child.id == "div.float" &&
                    nested_child.y > 0.0
                  let should_shift_nested_child = idx > 0 &&
                    nested_child.children.length() > 0 &&
                    nested_child.y > 0.0 &&
                    (nested_child.x <= 0.01 || shift_zero_height_float)
                  if not(shifted_any) && should_shift_nested_child {
                    let shift_y = if shift_zero_height_float {
                      -nested_child.y
                    } else {
                      -nested_local_y - nested_child.y
                    }
                    shifted_children.push(
                      shift_layout_subtree(nested_child, column_shift, shift_y),
                    )
                    shifted_any = true
                  } else {
                    shifted_children.push(nested_child)
                  }
                }
                shifted_children
              } else {
                nested_positioned_children
              }
              let should_normalize_negative_nested_children = nested_layout.height >
                0.0
              let normalized_nested_children = if should_normalize_negative_nested_children &&
                adjusted_nested_positioned_children.length() > 0 {
                let mut min_nested_child_y = 0.0
                for nested_child in adjusted_nested_positioned_children {
                  if nested_child.y < min_nested_child_y {
                    min_nested_child_y = nested_child.y
                  }
                }
                if min_nested_child_y < 0.0 {
                  nested_child_y_offset = min_nested_child_y
                  let shifted_nested_children : Array[@types.Layout] = []
                  for nested_child in adjusted_nested_positioned_children {
                    shifted_nested_children.push(
                      shift_layout_subtree(
                        nested_child,
                        0.0,
                        -min_nested_child_y,
                      ),
                    )
                  }
                  shifted_nested_children
                } else {
                  adjusted_nested_positioned_children
                }
              } else {
                adjusted_nested_positioned_children
              }
              let nested_children_width = get_children_flow_extent_width(
                normalized_nested_children,
              )
              let nested_auto_height = match nested_style.height {
                @types.Dimension::Auto => true
                _ => false
              }
              let allow_nested_fragment_box_expansion = nested_auto_height &&
                nested_style.column_span != @style.ColumnSpan::All &&
                not(@inline.is_inline_level(nested_style.display)) &&
                not(nested_has_direct_inflow_float)
              let nested_fragmented_width = if allow_nested_fragment_box_expansion &&
                nested_children_width > nested_layout.width {
                nested_children_width
              } else {
                nested_layout.width
              }
              let nested_fragmented_height = if allow_nested_fragment_box_expansion &&
                nested_fragmented_width > nested_layout.width &&
                nested_layout.height < limit &&
                nested_layout.height > 0.0 {
                limit
              } else {
                nested_layout.height
              }
              let mut nested_positioned_x = nested_layout.x +
                nested_col_index.to_double() *
                (multicol_column_width + multicol_column_gap)
              let nested_is_block_with_children_by_style = not(
                  @inline.is_inline_level(nested_style.display),
                ) &&
                nested_style.display != @types.Contents &&
                nested_layout.children.length() > 0
              let nested_is_block_with_children_by_geometry = nested_layout.children.length() >
                0 &&
                nested_layout.width + 0.01 >= multicol_column_width
              let nested_is_block_with_children = nested_is_block_with_children_by_style ||
                nested_is_block_with_children_by_geometry
              if nested_height_zero &&
                j > 0 &&
                nested_is_block_with_children &&
                nested_local_y <= 0.01 &&
                nested_layouts.length() > 0 {
                let prev_nested_x = nested_layouts[nested_layouts.length() - 1].x
                if nested_positioned_x > prev_nested_x {
                  nested_positioned_x = prev_nested_x
                }
              }
              nested_layouts.push({
                ..nested_layout,
                x: nested_positioned_x,
                y: nested_row.to_double() * limit +
                nested_local_y -
                nested_fragment_offset +
                nested_child_y_offset,
                width: nested_fragmented_width,
                height: nested_fragmented_height,
                children: normalized_nested_children,
              })
            }
          } else {
            let mut nested_pos = 0.0
            let nested_fragment_offset = resolve_multicol_nested_fragment_offset(
              child_style.column_span,
              local_y,
            )
            for j = 0; j < child_layout.children.length(); j = j + 1 {
              let nested_layout = child_layout.children[j]
              let nested_style = if j < nested_source_children.length() {
                nested_source_children[j].style
              } else {
                @style.Style::default()
              }
              let nested_flow_height = resolve_nested_fragment_flow_height(
                nested_layout, nested_style,
              )
              let nested_outer_height = nested_flow_height +
                nested_layout.margin.top +
                nested_layout.margin.bottom
              let nested_unbreakable = if j < nested_source_children.length() {
                is_unbreakable_fragment_unit(
                  nested_source_children[j],
                  nested_layout,
                )
              } else {
                nested_layout.children.length() == 0
              }
              if j > 0 {
                let prev_nested_style = if j - 1 <
                  nested_source_children.length() {
                  nested_source_children[j - 1].style
                } else {
                  @style.Style::default()
                }
                if prev_nested_style.break_after == @style.BreakBefore::Column &&
                  nested_pos > 0.0 {
                  let nested_col = (nested_pos / limit).to_int()
                  nested_pos = (nested_col + 1).to_double() * limit
                }
              }
              if nested_style.break_before == @style.BreakBefore::Column &&
                nested_pos > 0.0 {
                let effective_nested_pos = nested_pos + nested_fragment_offset
                let nested_col = (effective_nested_pos / limit).to_int()
                let next_effective = (nested_col + 1).to_double() * limit
                nested_pos = next_effective - nested_fragment_offset
                if nested_pos < 0.0 {
                  nested_pos = 0.0
                }
              }
              let effective_nested_pos = nested_pos + nested_fragment_offset
              if nested_unbreakable &&
                nested_outer_height <= limit &&
                effective_nested_pos > 0.0 {
                let nested_col = (effective_nested_pos / limit).to_int()
                let nested_local_y = effective_nested_pos -
                  nested_col.to_double() * limit
                if nested_local_y > 0.0 &&
                  nested_local_y + nested_outer_height > limit {
                  let next_effective = (nested_col + 1).to_double() * limit
                  nested_pos = next_effective - nested_fragment_offset
                  if nested_pos < 0.0 {
                    nested_pos = 0.0
                  }
                }
              }
              let effective_nested_pos = nested_pos + nested_fragment_offset
              let nested_col = (effective_nested_pos / limit).to_int()
              let nested_row = if multicol_fragment_contained {
                nested_col / multicol_column_count
              } else {
                0
              }
              let nested_col_index = if multicol_fragment_contained {
                nested_col % multicol_column_count
              } else {
                nested_col
              }
              let nested_local_y = effective_nested_pos -
                nested_col.to_double() * limit
              nested_layouts.push({
                ..nested_layout,
                x: nested_col_index.to_double() *
                (multicol_column_width + multicol_column_gap) +
                nested_layout.margin.left,
                y: nested_row.to_double() * limit +
                nested_local_y +
                nested_layout.margin.top -
                nested_fragment_offset,
              })
              nested_pos = nested_pos + nested_outer_height
            }
          }
          nested_layouts
        } else {
          child_layout.children
        }
        let multicol_inline_run_offset = if multicol_participates_in_inline_run {
          inline_run_align_offset + inline_run_x
        } else {
          0.0
        }
        let final_positioned_children = positioned_children
        let positioned_layout : @types.Layout = {
          id: child_layout.id,
          x: padding.left +
          border.left +
          col_offset +
          multicol_inline_run_offset +
          child_layout.margin.left,
          y: padding.top + border.top + positioned_y + visual_margin_top,
          width: fragmented_union_width,
          height: clipped_height,
          margin: child_layout.margin,
          padding: child_layout.padding,
          border: child_layout.border,
          overflow_x: child_layout.overflow_x,
          overflow_y: child_layout.overflow_y,
          scroll_width: child_layout.scroll_width,
          scroll_height: child_layout.scroll_height,
          children: final_positioned_children,
          text: child_layout.text,
        }
        layout_map[flow_indices[i]] = positioned_layout
        if multicol_participates_in_inline_run {
          let inline_descendant_height = get_children_flow_extent_height(
            child_layout.children,
          )
          let inline_visual_height = if child_style.contain.size {
            child_layout.height
          } else if inline_descendant_height > child_layout.height {
            inline_descendant_height
          } else {
            child_layout.height
          }
          let inline_item_height = inline_visual_height +
            effective_margin_top +
            effective_margin_bottom
          if child_node.id == "br" {
            let line_height = resolve_inline_run_line_height(
              inline_item_height,
              child_style.line_height,
            )
            if line_height > 0.0 {
              current_pos = effective_pos + line_height
            } else {
              current_pos = effective_pos
            }
            reset_inline_run_state()
          } else {
            extend_inline_run(child_inline_advance, inline_item_height)
            current_pos = effective_pos
          }
        } else {
          let child_fragment_advance = if child_flow_height > child_outer_height {
            child_flow_height
          } else {
            child_outer_height
          }
          let advance = if multicol_fragment_contained &&
            child_style.column_span != @style.ColumnSpan::All &&
            fragmented_columns > 1 &&
            child_fragment_advance > limit {
            limit
          } else {
            child_fragment_advance
          }
          current_pos = effective_pos + advance
        }
        flow_y_positions.push(current_pos)
        return (
          current_pos, prev_margin_end, inline_run_active, inline_run_x, inline_run_height,
          inline_run_align_offset,
        )
      }
    _ => ()
  }
  let multicol_inline_run_offset = if multicol_participates_in_inline_run {
    inline_run_align_offset + inline_run_x
  } else {
    0.0
  }
  let positioned_layout : @types.Layout = {
    id: child_layout.id,
    x: padding.left +
    border.left +
    multicol_inline_run_offset +
    child_layout.margin.left,
    y: padding.top + border.top + current_pos + visual_margin_top,
    width: fragmented_union_width,
    height: child_layout.height,
    margin: child_layout.margin,
    padding: child_layout.padding,
    border: child_layout.border,
    overflow_x: child_layout.overflow_x,
    overflow_y: child_layout.overflow_y,
    scroll_width: child_layout.scroll_width,
    scroll_height: child_layout.scroll_height,
    children: child_layout.children,
    text: child_layout.text,
  }
  layout_map[flow_indices[i]] = positioned_layout
  if multicol_participates_in_inline_run {
    let inline_descendant_height = get_children_flow_extent_height(
      child_layout.children,
    )
    let inline_visual_height = if child_style.contain.size {
      child_layout.height
    } else if inline_descendant_height > child_layout.height {
      inline_descendant_height
    } else {
      child_layout.height
    }
    let inline_item_height = inline_visual_height +
      effective_margin_top +
      effective_margin_bottom
    if child_node.id == "br" {
      let line_height = resolve_inline_run_line_height(
        inline_item_height,
        child_style.line_height,
      )
      if line_height > 0.0 {
        current_pos = current_pos + line_height
      }
      reset_inline_run_state()
    } else {
      extend_inline_run(child_inline_advance, inline_item_height)
    }
  } else {
    current_pos = current_pos + child_outer_height
  }
  flow_y_positions.push(current_pos)
  return (
    current_pos, prev_margin_end, inline_run_active, inline_run_x, inline_run_height,
    inline_run_align_offset,
  )
}
