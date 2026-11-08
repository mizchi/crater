// Min/max-content sizing and intrinsic grid-track estimates for block layout.

///|
fn calculate_children_max_content_width(
  node : @node.Node,
  parent_width : Double,
) -> Double {
  let key = node.uid.to_string() + "|" + parent_width.to_string()
  match max_intrinsic_width_cache.val.get(key) {
    Some(v) => v
    None => {
      let v = calculate_children_max_content_width_uncached(node, parent_width)
      max_intrinsic_width_cache.val.set(key, v)
      v
    }
  }
}

///|
fn calculate_children_max_content_width_uncached(
  node : @node.Node,
  parent_width : Double,
) -> Double {
  let mut max_content_width = 0.0
  let is_vertical_writing = node.style.writing_mode.is_vertical()
  let flow_children : Array[@node.Node] = []
  for child in node.children {
    if child.style.display == @types.Display::None ||
      child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    match child.style.float {
      @types.CssFloat::Left | @types.CssFloat::Right => continue
      @types.CssFloat::None => ()
    }
    flow_children.push(child)
  }
  let inline_only = @inline.should_establish_ifc(flow_children) ||
    is_ruby_internal_id(node.id)
  let mut inline_has_forced_break = false
  if inline_only && !is_vertical_writing {
    for child in flow_children {
      if child.id == "br" {
        inline_has_forced_break = true
        break
      }
    }
  }
  let mut current_inline_line_width = 0.0
  // Check if node itself has MeasureFunc (leaf node with intrinsic size)
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(0.0, 0.0)
      max_content_width = intrinsic.max_width
    }
    None => ()
  }
  // Calculate max-content width from children
  for i = 0; i < flow_children.length(); i = i + 1 {
    let child = flow_children[i]
    if inline_only && is_replaced_only_whitespace_separator(flow_children, i) {
      continue
    }
    let child_style = child.style
    let child_suppress_intrinsic_inline = child_style.suppresses_intrinsic_width() &&
      !is_ruby_internal_id(child.id)
    // Calculate child's margin contribution (percentages resolve to 0)
    let child_margin_left = resolve_dimension_intrinsic(child_style.margin.left)
    let child_margin_right = resolve_dimension_intrinsic(
      child_style.margin.right,
    )
    let child_margin_sum = child_margin_left + child_margin_right
    // Calculate child's padding (percentages resolve to 0)
    let child_padding_left = resolve_dimension_intrinsic(
      child_style.padding.left,
    )
    let child_padding_right = resolve_dimension_intrinsic(
      child_style.padding.right,
    )
    let child_border = @types.resolve_rect(child_style.border, parent_width)
    let child_min_box = child_padding_left +
      child_padding_right +
      child_border.horizontal_sum()
    // Calculate child's intrinsic width
    let child_intrinsic_width : Double = match child_style.width {
      @types.Length(w) => @types.max(w, child_min_box)
      @types.Percent(p) =>
        if child_style.writing_mode.is_vertical() &&
          child.children.length() == 0 {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.max_width * p + child_min_box, child_min_box)
            }
            None => child_min_box
          }
        } else {
          child_min_box
        }
      @types.Calc(_, p) =>
        if child_style.writing_mode.is_vertical() &&
          child.children.length() == 0 {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.max_width * p + child_min_box, child_min_box)
            }
            None => child_min_box
          }
        } else {
          child_min_box
        }
      @types.MathFn(__mop, __mterms) => {
        let p = @types.apply_math_op(__mop, __mterms.map(fn(__t) { __t.1 }))
        if child_style.writing_mode.is_vertical() &&
          child.children.length() == 0 {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.max_width * p + child_min_box, child_min_box)
            }
            None => child_min_box
          }
        } else {
          child_min_box
        }
      }
      @types.Auto =>
        if child_suppress_intrinsic_inline {
          child_style.contained_intrinsic_width_fallback() + child_min_box
        } else {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.max_width + child_min_box, child_min_box)
            }
            None => {
              let recursive_width = calculate_children_max_content_width(
                child, parent_width,
              )
              let grid_track_width = estimate_grid_track_intrinsic_width(
                child_style,
              )
              let content_width = if grid_track_width > recursive_width {
                grid_track_width
              } else {
                recursive_width
              }
              content_width + child_min_box
            }
          }
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        if child_suppress_intrinsic_inline {
          child_style.contained_intrinsic_width_fallback() + child_min_box
        } else {
          child_min_box
        }
    }
    let child_contribution = child_intrinsic_width + child_margin_sum
    if is_vertical_writing {
      // In vertical writing mode, normal-flow blocks advance horizontally.
      max_content_width = max_content_width + child_contribution
    } else if inline_only && inline_has_forced_break {
      // Respect forced line breaks (<br>) in inline formatting contexts.
      // max-content width is the widest forced line, not total sum.
      current_inline_line_width = current_inline_line_width + child_contribution
      if child.id == "br" {
        if current_inline_line_width > max_content_width {
          max_content_width = current_inline_line_width
        }
        current_inline_line_width = 0.0
      }
    } else if inline_only {
      // No forced breaks: max-content is one unwrapped line.
      max_content_width = max_content_width + child_contribution
    } else if child_contribution > max_content_width {
      max_content_width = child_contribution
    }
  }
  if inline_only &&
    inline_has_forced_break &&
    current_inline_line_width > max_content_width {
    max_content_width = current_inline_line_width
  }
  if max_content_width < 0.0 {
    0.0
  } else {
    max_content_width
  }
}

///|
/// Calculate min-content width of children for intrinsic sizing
fn calculate_children_min_content_width(
  node : @node.Node,
  parent_width : Double,
  parent_content_height : Double?,
) -> Double {
  let ph = match parent_content_height {
    Some(h) => h.to_string()
    None => "n"
  }
  let key = node.uid.to_string() + "|" + parent_width.to_string() + "|" + ph
  match min_intrinsic_width_cache.val.get(key) {
    Some(v) => v
    None => {
      let v = calculate_children_min_content_width_uncached(
        node, parent_width, parent_content_height,
      )
      min_intrinsic_width_cache.val.set(key, v)
      v
    }
  }
}

///|
fn calculate_children_min_content_width_uncached(
  node : @node.Node,
  parent_width : Double,
  parent_content_height : Double?,
) -> Double {
  let mut min_content_width = 0.0
  let is_vertical_writing = node.style.writing_mode.is_vertical()
  let flow_children : Array[@node.Node] = []
  for child in node.children {
    // Skip display:none, absolute, fixed, and float elements
    if child.style.display == @types.Display::None ||
      child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    match child.style.float {
      @types.CssFloat::Left | @types.CssFloat::Right => continue
      @types.CssFloat::None => ()
    }
    flow_children.push(child)
  }
  let inline_only = @inline.should_establish_ifc(flow_children) ||
    is_ruby_internal_id(node.id)
  let mut inline_needs_line_width = false
  if inline_only && !is_vertical_writing {
    for child in flow_children {
      if child.id == "br" {
        inline_needs_line_width = true
        break
      }
      let margin_left = resolve_dimension_intrinsic(child.style.margin.left)
      let margin_right = resolve_dimension_intrinsic(child.style.margin.right)
      if margin_left + margin_right < 0.0 {
        inline_needs_line_width = true
        break
      }
    }
  }
  let mut current_inline_line_width = 0.0
  // Check if node itself has MeasureFunc (leaf node with intrinsic size)
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(0.0, 0.0)
      min_content_width = intrinsic.min_width
    }
    None => ()
  }
  // Calculate min-content width from children
  for i = 0; i < flow_children.length(); i = i + 1 {
    let child = flow_children[i]
    if inline_needs_line_width &&
      is_replaced_only_whitespace_separator(flow_children, i) {
      continue
    }
    let child_style = child.style
    let child_suppress_intrinsic_inline = child_style.suppresses_intrinsic_width() &&
      !is_ruby_internal_id(child.id)
    // Calculate child's margin contribution (percentages resolve to 0)
    let child_margin_left = resolve_dimension_intrinsic(child_style.margin.left)
    let child_margin_right = resolve_dimension_intrinsic(
      child_style.margin.right,
    )
    let child_margin_sum = child_margin_left + child_margin_right
    // Calculate child's padding (percentages resolve to 0)
    let child_padding_left = resolve_dimension_intrinsic(
      child_style.padding.left,
    )
    let child_padding_right = resolve_dimension_intrinsic(
      child_style.padding.right,
    )
    let child_padding_top = resolve_dimension_intrinsic(child_style.padding.top)
    let child_padding_bottom = resolve_dimension_intrinsic(
      child_style.padding.bottom,
    )
    let child_border = @types.resolve_rect(child_style.border, parent_width)
    let child_min_box = child_padding_left +
      child_padding_right +
      child_border.horizontal_sum()
    fn calc_aspect_width(
      ratio : Double,
      h : Double,
      box_sizing : @types.BoxSizing,
      padding_v : Double,
      border_v : Double,
      padding_h : Double,
      border_h : Double,
      min_box : Double,
    ) -> Double {
      if box_sizing == @types.BorderBox {
        if h > 0.0 {
          h * ratio
        } else {
          min_box
        }
      } else {
        let content_height = h - padding_v - border_v
        if content_height > 0.0 {
          content_height * ratio + padding_h + border_h
        } else {
          min_box
        }
      }
    }
    fn fallback_auto_min_width() -> Double {
      if child_suppress_intrinsic_inline {
        return child_style.contained_intrinsic_width_fallback() + child_min_box
      }
      match child.measure {
        Some(mf) => {
          let intrinsic = (mf.func)(0.0, 0.0)
          @types.max(intrinsic.min_width + child_min_box, child_min_box)
        }
        None => {
          let recursive_width = calculate_children_min_content_width(
            child, parent_width, parent_content_height,
          )
          recursive_width + child_min_box
        }
      }
    }
    fn apply_intrinsic_inline_constraints(raw_width : Double) -> Double {
      let mut resolved = raw_width
      let width_is_inline_axis = !child_style.writing_mode.is_vertical()
      let is_table_principal = is_table_principal_display(child_style.display)
      let intrinsic_min_width = if child_suppress_intrinsic_inline {
        child_style.contained_intrinsic_width_fallback() + child_min_box
      } else {
        calculate_children_min_content_width(
          child, parent_width, parent_content_height,
        ) +
        child_min_box
      }
      let intrinsic_max_width = if child_suppress_intrinsic_inline {
        child_style.contained_intrinsic_width_fallback() + child_min_box
      } else {
        calculate_children_max_content_width(child, parent_width) +
        child_min_box
      }
      // For intrinsic min-content contribution, percentages are indefinite and
      // resolve to 0 for inline-size constraints.
      match child_style.max_width {
        @types.Length(max_w) => if resolved > max_w { resolved = max_w }
        @types.Percent(_) =>
          if width_is_inline_axis && resolved > 0.0 {
            resolved = 0.0
          }
        @types.Calc(_, _) =>
          if width_is_inline_axis && resolved > 0.0 {
            resolved = 0.0
          }
        @types.MathFn(__mop, __mterms) =>
          if width_is_inline_axis && resolved > 0.0 {
            resolved = 0.0
          }
        @types.MinContent =>
          if resolved > intrinsic_min_width {
            resolved = intrinsic_min_width
          }
        @types.MaxContent | @types.FitContent(_) =>
          if resolved > intrinsic_max_width {
            resolved = intrinsic_max_width
          }
        _ => ()
      }
      // min-width takes precedence over max-width when both are specified.
      match child_style.min_width {
        @types.Length(min_w) => if resolved < min_w { resolved = min_w }
        @types.Percent(_) =>
          if width_is_inline_axis && resolved < 0.0 {
            resolved = 0.0
          }
        @types.Calc(_, _) =>
          if width_is_inline_axis && resolved < 0.0 {
            resolved = 0.0
          }
        @types.MathFn(__mop, __mterms) =>
          if width_is_inline_axis && resolved < 0.0 {
            resolved = 0.0
          }
        @types.MinContent | @types.FitContent(_) =>
          if resolved < intrinsic_min_width {
            resolved = intrinsic_min_width
          }
        @types.MaxContent =>
          if resolved < intrinsic_max_width {
            resolved = intrinsic_max_width
          }
        _ => ()
      }
      if is_table_principal && resolved < intrinsic_min_width {
        resolved = intrinsic_min_width
      }
      if resolved < child_min_box {
        child_min_box
      } else {
        resolved
      }
    }
    // Calculate child's intrinsic min-content width
    let child_intrinsic_width_raw : Double = match child_style.width {
      @types.Length(w) => @types.max(w, child_min_box)
      @types.Percent(p) =>
        if child_style.writing_mode.is_vertical() &&
          child.children.length() == 0 {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.min_width * p + child_min_box, child_min_box)
            }
            None => child_min_box
          }
        } else {
          child_min_box
        }
      @types.Calc(_, p) =>
        if child_style.writing_mode.is_vertical() &&
          child.children.length() == 0 {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.min_width * p + child_min_box, child_min_box)
            }
            None => child_min_box
          }
        } else {
          child_min_box
        }
      @types.MathFn(__mop, __mterms) => {
        let p = @types.apply_math_op(__mop, __mterms.map(fn(__t) { __t.1 }))
        if child_style.writing_mode.is_vertical() &&
          child.children.length() == 0 {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.min_width * p + child_min_box, child_min_box)
            }
            None => child_min_box
          }
        } else {
          child_min_box
        }
      }
      @types.Auto =>
        match (child_style.aspect_ratio, child_style.height) {
          (Some(ratio), @types.Length(h)) if ratio > 0.0 =>
            calc_aspect_width(
              ratio,
              h,
              child_style.box_sizing,
              child_padding_top + child_padding_bottom,
              child_border.vertical_sum(),
              child_padding_left + child_padding_right,
              child_border.horizontal_sum(),
              child_min_box,
            )
          (Some(ratio), @types.Percent(p)) if ratio > 0.0 =>
            match parent_content_height {
              Some(parent_h) =>
                calc_aspect_width(
                  ratio,
                  parent_h * p,
                  child_style.box_sizing,
                  child_padding_top + child_padding_bottom,
                  child_border.vertical_sum(),
                  child_padding_left + child_padding_right,
                  child_border.horizontal_sum(),
                  child_min_box,
                )
              None => fallback_auto_min_width()
            }
          (Some(ratio), @types.Auto) if ratio > 0.0 => {
            let is_flex_row_parent = match
              (node.style.display, node.style.flex_direction) {
              (@types.Flex | @types.InlineFlex, @types.Row | @types.RowReverse) =>
                true
              _ => false
            }
            let align_cross = match child_style.align_self {
              @types.AlignSelf::Auto => node.style.align_items
              @types.AlignSelf::Start => @types.Start
              @types.AlignSelf::End => @types.End
              @types.AlignSelf::Center => @types.Center
              @types.AlignSelf::Stretch => @types.Stretch
              @types.AlignSelf::Baseline => @types.Baseline
            }
            if is_flex_row_parent && align_cross == @types.Stretch {
              match parent_content_height {
                Some(parent_h) =>
                  calc_aspect_width(
                    ratio,
                    parent_h,
                    child_style.box_sizing,
                    child_padding_top + child_padding_bottom,
                    child_border.vertical_sum(),
                    child_padding_left + child_padding_right,
                    child_border.horizontal_sum(),
                    child_min_box,
                  )
                None => fallback_auto_min_width()
              }
            } else {
              fallback_auto_min_width()
            }
          }
          _ => fallback_auto_min_width()
        }
      @types.MinContent | @types.FitContent(_) =>
        if child_suppress_intrinsic_inline {
          child_style.contained_intrinsic_width_fallback() + child_min_box
        } else {
          let recursive_width = calculate_children_min_content_width(
            child,
            parent_width,
            None,
          )
          recursive_width + child_min_box
        }
      @types.MaxContent =>
        if child_suppress_intrinsic_inline {
          child_style.contained_intrinsic_width_fallback() + child_min_box
        } else {
          let recursive_width = calculate_children_max_content_width(
            child, parent_width,
          )
          recursive_width + child_min_box
        }
    }
    let child_intrinsic_width = apply_intrinsic_inline_constraints(
      child_intrinsic_width_raw,
    )
    let child_contribution = child_intrinsic_width + child_margin_sum
    if is_vertical_writing {
      min_content_width = min_content_width + child_contribution
    } else if inline_needs_line_width {
      current_inline_line_width = current_inline_line_width + child_contribution
      if child.id == "br" {
        if current_inline_line_width > min_content_width {
          min_content_width = current_inline_line_width
        }
        current_inline_line_width = 0.0
      }
    } else if child_contribution > min_content_width {
      min_content_width = child_contribution
    }
  }
  if inline_needs_line_width && current_inline_line_width > min_content_width {
    min_content_width = current_inline_line_width
  }
  if min_content_width < 0.0 {
    0.0
  } else {
    min_content_width
  }
}

///|
fn resolve_single_track_intrinsic(track : @types.SingleTrackSizing) -> Double {
  match track {
    @types.SingleTrackSizing::Length(v) => v
    @types.SingleTrackSizing::FitContentLength(v) => v
    @types.SingleTrackSizing::MinMax(min_track, _max_track) =>
      match min_track {
        @types.MinTrackSizing::Length(v) => v
        _ => 0.0
      }
    _ => 0.0
  }
}

///|
fn resolve_track_intrinsic(track : @types.TrackSizingFunction) -> Double {
  match track {
    @types.TrackSizingFunction::Length(v) => v
    @types.FitContentLength(v) => v
    @types.TrackSizingFunction::MinMax(min_track, _max_track) =>
      match min_track {
        @types.MinTrackSizing::Length(v) => v
        _ => 0.0
      }
    @types.TrackSizingFunction::Repeat(count, tracks, _line_names) =>
      match count {
        @types.RepeatCount::Count(n) => {
          let mut unit = 0.0
          for t in tracks {
            unit = unit + resolve_single_track_intrinsic(t)
          }
          unit * n.to_double()
        }
        _ => 0.0
      }
    _ => 0.0
  }
}

///|
fn estimate_grid_track_intrinsic_width(style : @style.Style) -> Double {
  if style.display != @types.Grid && style.display != @types.InlineGrid {
    return 0.0
  }
  let mut width = 0.0
  for track in style.grid_template_columns {
    width = width + resolve_track_intrinsic(track)
  }
  if style.grid_template_columns.length() > 1 {
    let gap = resolve_dimension_intrinsic(style.column_gap)
    width = width + gap * (style.grid_template_columns.length() - 1).to_double()
  }
  width
}

///|
/// Calculate max-content height of children for intrinsic sizing
/// This is used when min-height or max-height is max-content/min-content
fn calculate_children_max_content_height(
  node : @node.Node,
  parent_width : Double,
) -> Double {
  let mut total_height = 0.0
  // Check if node itself has MeasureFunc (leaf node with intrinsic size)
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(0.0, 0.0)
      total_height = intrinsic.min_height
    }
    None => ()
  }
  // Calculate height from children (simplified - sum of heights)
  for child in node.children {
    // Skip display:none, absolute, fixed elements
    if child.style.display == @types.Display::None ||
      child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    // Skip floats for height calculation in normal flow
    match child.style.float {
      @types.CssFloat::Left | @types.CssFloat::Right => continue
      @types.CssFloat::None => ()
    }
    let child_style = child.style
    // Calculate child's vertical margins (percentages resolve to parent WIDTH, not height)
    let child_margin_top = resolve_dimension_intrinsic(child_style.margin.top)
    let child_margin_bottom = resolve_dimension_intrinsic(
      child_style.margin.bottom,
    )
    // Calculate child's padding and border
    let child_padding_top = resolve_dimension_intrinsic(child_style.padding.top)
    let child_padding_bottom = resolve_dimension_intrinsic(
      child_style.padding.bottom,
    )
    let child_border = @types.resolve_rect(child_style.border, parent_width)
    let child_min_box = child_padding_top +
      child_padding_bottom +
      child_border.vertical_sum()
    // Calculate child's intrinsic height
    let child_intrinsic_height : Double = match child_style.height {
      @types.Length(h) => @types.max(h, child_min_box)
      @types.Percent(_) => child_min_box
      @types.Calc(_, _) => child_min_box
      @types.MathFn(_, _) => child_min_box
      @types.Auto =>
        match child.measure {
          Some(mf) => {
            let intrinsic = (mf.func)(0.0, 0.0)
            @types.max(intrinsic.min_height + child_min_box, child_min_box)
          }
          None =>
            // Recursively calculate for nested elements
            calculate_children_max_content_height(child, parent_width) +
            child_min_box
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        child_min_box
    }
    // Add to total (simplified - not doing margin collapsing here)
    total_height = total_height +
      child_intrinsic_height +
      child_margin_top +
      child_margin_bottom
  }
  total_height
}

///|
fn max_content_box_width(
  node : @node.Node,
  ctx : @layout_types.LayoutContext,
  warnings : Array[@layout_types.LayoutWarning],
  dispatch : @node.DispatchFn,
  flow_nodes : Array[@node.Node],
  flow_styles : Array[@style.Style],
  float_nodes : Array[@node.Node],
  parent_width : Double,
  padding : @types.Rect[Double],
  border : @types.Rect[Double],
  min_box_width : Double,
  is_inline_block : Bool,
  child_available_height : Double?,
  initial_box_width : Double,
) -> Double {
  let style = node.style
  let mut box_width = initial_box_width
  let mut max_content_width = 0.0
  let multicol_intrinsic_content_width = estimate_multicol_intrinsic_content_width(
    style, parent_width,
  )
  let inline_only = @inline.should_establish_ifc(flow_nodes) ||
    is_ruby_internal_id(node.id)
  let mut inline_has_forced_break = false
  if inline_only && !style.writing_mode.is_vertical() {
    for child in flow_nodes {
      if child.id == "br" {
        inline_has_forced_break = true
        break
      }
    }
  }
  let mut current_inline_line_width = 0.0
  // CSS Containment: contain: inline-size means intrinsic width is 0 (no content contribution)
  let skip_content_contribution = style.suppresses_intrinsic_width()
  if skip_content_contribution {
    max_content_width = style.contained_intrinsic_width_fallback()
  } else {
    // Check if root itself has MeasureFunc (leaf node with intrinsic size)
    match node.measure {
      Some(mf) => {
        let intrinsic = (mf.func)(0.0, 0.0)
        max_content_width = intrinsic.max_width
      }
      None => ()
    }
  }
  // Skip children content calculation when contain: inline-size or size is set
  if !skip_content_contribution {
    for i = 0; i < flow_nodes.length(); i = i + 1 {
      let child = flow_nodes[i]
      let child_style = flow_styles[i]

      // For intrinsic sizing, percentage margins resolve to 0 (CSS spec)
      // Only fixed margins contribute to intrinsic width
      let child_margin_left : Double = match child_style.margin.left {
        @types.Length(l) => l
        @types.Percent(_) => 0.0
        @types.Calc(_, _) => 0.0
        @types.MathFn(_, _) => 0.0
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 0.0
      }
      let child_margin_right : Double = match child_style.margin.right {
        @types.Length(r) => r
        @types.Percent(_) => 0.0
        @types.Calc(_, _) => 0.0
        @types.MathFn(_, _) => 0.0
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 0.0
      }
      let child_margin_sum = child_margin_left + child_margin_right

      // Calculate child's intrinsic width contribution
      // Note: padding+border override explicit width if too small
      // For intrinsic sizing, percentage padding also resolves to 0
      let child_padding_left : Double = match child_style.padding.left {
        @types.Length(l) => l
        @types.Percent(_) => 0.0
        @types.Calc(_, _) => 0.0
        @types.MathFn(_, _) => 0.0
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 0.0
      }
      let child_padding_right : Double = match child_style.padding.right {
        @types.Length(r) => r
        @types.Percent(_) => 0.0
        @types.Calc(_, _) => 0.0
        @types.MathFn(_, _) => 0.0
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 0.0
      }
      let child_border = @types.resolve_rect(child_style.border, parent_width)
      let child_min_box = child_padding_left +
        child_padding_right +
        child_border.horizontal_sum()
      let has_intrinsic_width_constraint = match
        (child_style.min_width, child_style.max_width) {
        (@types.MinContent | @types.MaxContent | @types.FitContent(_), _) =>
          true
        (_, @types.MinContent | @types.MaxContent | @types.FitContent(_)) =>
          true
        _ => false
      }
      let child_recursive_intrinsic_width : Double? = if has_intrinsic_width_constraint &&
        child.children.length() > 0 {
        // Recursively compute child's intrinsic width so min/max intrinsic
        // constraints (e.g. fit-content) are applied on the child itself.
        let intrinsic_ctx : @layout_types.LayoutContext = {
          available_width: parent_width,
          available_height: child_available_height,
          sizing_mode: @layout_types.MaxContent,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
          stretch_width: false,
          stretch_height: false,
        }
        let @node.DispatchFn(dispatch_fn) = dispatch
        let child_width = match child_style.display {
          @types.Flex
          | @types.InlineFlex
          | @types.Grid
          | @types.InlineGrid
          | @types.Table
          | @types.InlineTable =>
            dispatch_fn(child, intrinsic_ctx, dispatch).width
          _ =>
            compute_with_collapse(child, intrinsic_ctx, warnings, dispatch).layout.width
        }
        Some(child_width)
      } else {
        None
      }
      // Helper function to calculate width from aspect-ratio
      fn calc_aspect_width(
        ratio : Double,
        h : Double,
        box_sizing : @types.BoxSizing,
        padding_v : Double,
        border_v : Double,
        padding_h : Double,
        border_h : Double,
        min_box : Double,
      ) -> Double {
        if box_sizing is @types.BorderBox {
          h * ratio
        } else {
          let content_height = h - padding_v - border_v
          if content_height > 0.0 {
            content_height * ratio + padding_h + border_h
          } else {
            min_box
          }
        }
      }

      let child_padding_v = resolve_dimension_intrinsic(child_style.padding.top) +
        resolve_dimension_intrinsic(child_style.padding.bottom)
      fn compute_recursive_child_width() -> Double {
        let intrinsic_ctx : @layout_types.LayoutContext = {
          available_width: parent_width, // Use parent_width as reference for percentages
          available_height: child_available_height,
          sizing_mode: @layout_types.MaxContent,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
          stretch_width: false,
          stretch_height: false,
        }
        let @node.DispatchFn(dispatch_fn) = dispatch
        match child_style.display {
          @types.Flex
          | @types.InlineFlex
          | @types.Grid
          | @types.InlineGrid
          | @types.Table
          | @types.InlineTable =>
            dispatch_fn(child, intrinsic_ctx, dispatch).width
          _ =>
            compute_with_collapse(child, intrinsic_ctx, warnings, dispatch).layout.width
        }
      }
      let mut child_intrinsic_width : Double = match child_style.width {
        @types.Length(w) =>
          match child_recursive_intrinsic_width {
            Some(recursive_w) => recursive_w
            None => @types.max(w, child_min_box)
          }
        @types.Percent(p) =>
          if child_style.writing_mode.is_vertical() &&
            child.children.length() == 0 {
            match child.measure {
              Some(mf) => {
                let intrinsic = (mf.func)(0.0, 0.0)
                @types.max(
                  intrinsic.max_width * p + child_min_box,
                  child_min_box,
                )
              }
              None => child_min_box
            }
          } else if child.children.length() == 0 {
            let measured_aspect_width : Double? = match
              (child.measure, child_style.aspect_ratio) {
              (Some(mf), Some(ratio)) if ratio > 0.0 => {
                let intrinsic = (mf.func)(0.0, 0.0)
                let resolved_height : Double? = match child_style.height {
                  @types.Length(h) => Some(h)
                  @types.Percent(height_p) =>
                    match child_available_height {
                      Some(parent_content_h) =>
                        Some(parent_content_h * height_p)
                      None => None
                    }
                  @types.Calc(height_px, height_p) =>
                    match child_available_height {
                      Some(parent_content_h) =>
                        Some(parent_content_h * height_p + height_px)
                      None => None
                    }
                  @types.MathFn(__mop, __mterms) =>
                    match child_available_height {
                      Some(parent_content_h) =>
                        Some(
                          @types.apply_math_op(
                            __mop,
                            __mterms.map(fn(__t) {
                              parent_content_h * __t.1 + __t.0
                            }),
                          ),
                        )
                      None => None
                    }
                  @types.Auto
                  | @types.MinContent
                  | @types.MaxContent
                  | @types.FitContent(_) => {
                    let min_h = match child_style.min_height {
                      @types.Length(h) => h
                      @types.Percent(height_p) =>
                        match child_available_height {
                          Some(parent_content_h) => parent_content_h * height_p
                          None => 0.0
                        }
                      _ => 0.0
                    }
                    let max_h = match child_style.max_height {
                      @types.Length(h) => h
                      @types.Percent(height_p) =>
                        match child_available_height {
                          Some(parent_content_h) => parent_content_h * height_p
                          None => @double.infinity
                        }
                      _ => @double.infinity
                    }
                    if max_h < @double.infinity || min_h > 0.0 {
                      Some(
                        @types.clamp(
                          intrinsic.max_height +
                          child_padding_v +
                          child_border.vertical_sum(),
                          min_h,
                          max_h,
                        ),
                      )
                    } else {
                      None
                    }
                  }
                }
                match resolved_height {
                  Some(h) =>
                    Some(
                      calc_aspect_width(
                        ratio,
                        h,
                        child_style.box_sizing,
                        child_padding_v,
                        child_border.vertical_sum(),
                        child_padding_left + child_padding_right,
                        child_border.horizontal_sum(),
                        child_min_box,
                      ),
                    )
                  None => None
                }
              }
              _ => None
            }
            match measured_aspect_width {
              Some(w) => @types.max(w, child_min_box)
              None =>
                if has_intrinsic_width_constraint {
                  match child_recursive_intrinsic_width {
                    Some(recursive_w) => recursive_w
                    None => child_min_box
                  }
                } else if has_percent_sized_replaced_descendant(child) {
                  match child_available_height {
                    Some(h) => @types.max(h * p + child_min_box, child_min_box)
                    None =>
                      if child.children.length() == 0 {
                        child_min_box
                      } else {
                        let recursive_w = compute_recursive_child_width()
                        @types.max(recursive_w, child_min_box)
                      }
                  }
                } else {
                  child_min_box
                }
            }
          } else if has_intrinsic_width_constraint {
            match child_recursive_intrinsic_width {
              Some(recursive_w) => recursive_w
              None => child_min_box
            }
          } else if has_percent_sized_replaced_descendant(child) {
            match child_available_height {
              Some(h) => @types.max(h * p + child_min_box, child_min_box)
              None =>
                if child.children.length() == 0 {
                  child_min_box
                } else {
                  let recursive_w = compute_recursive_child_width()
                  @types.max(recursive_w, child_min_box)
                }
            }
          } else {
            child_min_box // At minimum, padding+border
          }
        @types.Calc(_, p) =>
          if child_style.writing_mode.is_vertical() &&
            child.children.length() == 0 {
            match child.measure {
              Some(mf) => {
                let intrinsic = (mf.func)(0.0, 0.0)
                @types.max(
                  intrinsic.max_width * p + child_min_box,
                  child_min_box,
                )
              }
              None => child_min_box
            }
          } else if child.children.length() == 0 {
            let measured_aspect_width : Double? = match
              (child.measure, child_style.aspect_ratio) {
              (Some(mf), Some(ratio)) if ratio > 0.0 => {
                let intrinsic = (mf.func)(0.0, 0.0)
                let resolved_height : Double? = match child_style.height {
                  @types.Length(h) => Some(h)
                  @types.Percent(height_p) =>
                    match child_available_height {
                      Some(parent_content_h) =>
                        Some(parent_content_h * height_p)
                      None => None
                    }
                  @types.Calc(height_px, height_p) =>
                    match child_available_height {
                      Some(parent_content_h) =>
                        Some(parent_content_h * height_p + height_px)
                      None => None
                    }
                  @types.MathFn(__mop, __mterms) =>
                    match child_available_height {
                      Some(parent_content_h) =>
                        Some(
                          @types.apply_math_op(
                            __mop,
                            __mterms.map(fn(__t) {
                              parent_content_h * __t.1 + __t.0
                            }),
                          ),
                        )
                      None => None
                    }
                  @types.Auto
                  | @types.MinContent
                  | @types.MaxContent
                  | @types.FitContent(_) => {
                    let min_h = match child_style.min_height {
                      @types.Length(h) => h
                      @types.Percent(height_p) =>
                        match child_available_height {
                          Some(parent_content_h) => parent_content_h * height_p
                          None => 0.0
                        }
                      _ => 0.0
                    }
                    let max_h = match child_style.max_height {
                      @types.Length(h) => h
                      @types.Percent(height_p) =>
                        match child_available_height {
                          Some(parent_content_h) => parent_content_h * height_p
                          None => @double.infinity
                        }
                      _ => @double.infinity
                    }
                    if max_h < @double.infinity || min_h > 0.0 {
                      Some(
                        @types.clamp(
                          intrinsic.max_height +
                          child_padding_v +
                          child_border.vertical_sum(),
                          min_h,
                          max_h,
                        ),
                      )
                    } else {
                      None
                    }
                  }
                }
                match resolved_height {
                  Some(h) =>
                    Some(
                      calc_aspect_width(
                        ratio,
                        h,
                        child_style.box_sizing,
                        child_padding_v,
                        child_border.vertical_sum(),
                        child_padding_left + child_padding_right,
                        child_border.horizontal_sum(),
                        child_min_box,
                      ),
                    )
                  None => None
                }
              }
              _ => None
            }
            match measured_aspect_width {
              Some(w) => @types.max(w, child_min_box)
              None =>
                if has_intrinsic_width_constraint {
                  match child_recursive_intrinsic_width {
                    Some(recursive_w) => recursive_w
                    None => child_min_box
                  }
                } else if has_percent_sized_replaced_descendant(child) {
                  match child_available_height {
                    Some(h) => @types.max(h * p + child_min_box, child_min_box)
                    None =>
                      if child.children.length() == 0 {
                        child_min_box
                      } else {
                        let recursive_w = compute_recursive_child_width()
                        @types.max(recursive_w, child_min_box)
                      }
                  }
                } else {
                  child_min_box
                }
            }
          } else if has_intrinsic_width_constraint {
            match child_recursive_intrinsic_width {
              Some(recursive_w) => recursive_w
              None => child_min_box
            }
          } else if has_percent_sized_replaced_descendant(child) {
            match child_available_height {
              Some(h) => @types.max(h * p + child_min_box, child_min_box)
              None =>
                if child.children.length() == 0 {
                  child_min_box
                } else {
                  let recursive_w = compute_recursive_child_width()
                  @types.max(recursive_w, child_min_box)
                }
            }
          } else {
            child_min_box // At minimum, padding+border
          }
        @types.MathFn(__mop, __mterms) => {
          let p = @types.apply_math_op(__mop, __mterms.map(fn(__t) { __t.1 }))
          if child_style.writing_mode.is_vertical() &&
            child.children.length() == 0 {
            match child.measure {
              Some(mf) => {
                let intrinsic = (mf.func)(0.0, 0.0)
                @types.max(
                  intrinsic.max_width * p + child_min_box,
                  child_min_box,
                )
              }
              None => child_min_box
            }
          } else if child.children.length() == 0 {
            let measured_aspect_width : Double? = match
              (child.measure, child_style.aspect_ratio) {
              (Some(mf), Some(ratio)) if ratio > 0.0 => {
                let intrinsic = (mf.func)(0.0, 0.0)
                let resolved_height : Double? = match child_style.height {
                  @types.Length(h) => Some(h)
                  @types.Percent(height_p) =>
                    match child_available_height {
                      Some(parent_content_h) =>
                        Some(parent_content_h * height_p)
                      None => None
                    }
                  @types.Calc(height_px, height_p) =>
                    match child_available_height {
                      Some(parent_content_h) =>
                        Some(parent_content_h * height_p + height_px)
                      None => None
                    }
                  @types.MathFn(__mop, __mterms) =>
                    match child_available_height {
                      Some(parent_content_h) =>
                        Some(
                          @types.apply_math_op(
                            __mop,
                            __mterms.map(fn(__t) {
                              parent_content_h * __t.1 + __t.0
                            }),
                          ),
                        )
                      None => None
                    }
                  @types.Auto
                  | @types.MinContent
                  | @types.MaxContent
                  | @types.FitContent(_) => {
                    let min_h = match child_style.min_height {
                      @types.Length(h) => h
                      @types.Percent(height_p) =>
                        match child_available_height {
                          Some(parent_content_h) => parent_content_h * height_p
                          None => 0.0
                        }
                      _ => 0.0
                    }
                    let max_h = match child_style.max_height {
                      @types.Length(h) => h
                      @types.Percent(height_p) =>
                        match child_available_height {
                          Some(parent_content_h) => parent_content_h * height_p
                          None => @double.infinity
                        }
                      _ => @double.infinity
                    }
                    if max_h < @double.infinity || min_h > 0.0 {
                      Some(
                        @types.clamp(
                          intrinsic.max_height +
                          child_padding_v +
                          child_border.vertical_sum(),
                          min_h,
                          max_h,
                        ),
                      )
                    } else {
                      None
                    }
                  }
                }
                match resolved_height {
                  Some(h) =>
                    Some(
                      calc_aspect_width(
                        ratio,
                        h,
                        child_style.box_sizing,
                        child_padding_v,
                        child_border.vertical_sum(),
                        child_padding_left + child_padding_right,
                        child_border.horizontal_sum(),
                        child_min_box,
                      ),
                    )
                  None => None
                }
              }
              _ => None
            }
            match measured_aspect_width {
              Some(w) => @types.max(w, child_min_box)
              None =>
                if has_intrinsic_width_constraint {
                  match child_recursive_intrinsic_width {
                    Some(recursive_w) => recursive_w
                    None => child_min_box
                  }
                } else if has_percent_sized_replaced_descendant(child) {
                  match child_available_height {
                    Some(h) => @types.max(h * p + child_min_box, child_min_box)
                    None =>
                      if child.children.length() == 0 {
                        child_min_box
                      } else {
                        let recursive_w = compute_recursive_child_width()
                        @types.max(recursive_w, child_min_box)
                      }
                  }
                } else {
                  child_min_box
                }
            }
          } else if has_intrinsic_width_constraint {
            match child_recursive_intrinsic_width {
              Some(recursive_w) => recursive_w
              None => child_min_box
            }
          } else if has_percent_sized_replaced_descendant(child) {
            match child_available_height {
              Some(h) => @types.max(h * p + child_min_box, child_min_box)
              None =>
                if child.children.length() == 0 {
                  child_min_box
                } else {
                  let recursive_w = compute_recursive_child_width()
                  @types.max(recursive_w, child_min_box)
                }
            }
          } else {
            child_min_box // At minimum, padding+border
          }
        }
        @types.Auto =>
          // For width:auto, check if aspect-ratio can determine width from height
          // This applies to both MeasureFunc elements (canvas, img) and regular elements
          match (child_style.aspect_ratio, child_style.height) {
            (Some(ratio), @types.Length(h)) if ratio > 0.0 =>
              // Height is explicit length, use aspect-ratio
              calc_aspect_width(
                ratio,
                h,
                child_style.box_sizing,
                child_padding_v,
                child_border.vertical_sum(),
                child_padding_left + child_padding_right,
                child_border.horizontal_sum(),
                child_min_box,
              )
            (Some(ratio), @types.Percent(p)) if ratio > 0.0 =>
              // Height is percentage, resolve from parent height
              match child_available_height {
                Some(parent_content_h) => {
                  // Percentage heights resolve against containing block content box.
                  let h = parent_content_h * p
                  calc_aspect_width(
                    ratio,
                    h,
                    child_style.box_sizing,
                    child_padding_v,
                    child_border.vertical_sum(),
                    child_padding_left + child_padding_right,
                    child_border.horizontal_sum(),
                    child_min_box,
                  )
                }
                None => child_min_box // Parent has no definite height
              }
            _ =>
              // No aspect-ratio or height is auto, fall back to intrinsic/content width
              match child.measure {
                Some(mf) => {
                  let intrinsic = (mf.func)(0.0, 0.0)
                  @types.max(intrinsic.max_width + child_min_box, child_min_box)
                }
                None =>
                  if child.children.length() == 0 {
                    child_min_box // Leaf nodes with no content have padding+border as minimum
                  } else if child_style.display is @types.Contents {
                    if has_table_internal_descendant(child) {
                      // Measure contiguous table-internal descendants as one
                      // anonymous table run so intrinsic width is not fragmented.
                      let run_nodes : Array[@node.Node] = []
                      let run_indices : Array[Int32] = []
                      let mut run_index = 0
                      let mut j = i
                      while j < flow_nodes.length() {
                        let run_child = flow_nodes[j]
                        if is_table_internal_flow_node(run_child) {
                          run_nodes.push(run_child)
                          run_indices.push(run_index)
                          run_index = run_index + 1
                          j = j + 1
                          continue
                        }
                        if is_whitespace_only_table_run_text(run_child) {
                          j = j + 1
                          continue
                        }
                        break
                      }
                      if run_nodes.length() > 0 {
                        let (run_result, _) = compute_anonymous_table_run(
                          run_nodes,
                          run_indices,
                          parent_width,
                          child_available_height,
                          style.writing_mode,
                          ctx.viewport_width,
                          ctx.viewport_height,
                          dispatch,
                        )
                        @types.max(run_result.layout.width, child_min_box)
                      } else {
                        child_min_box
                      }
                    } else {
                      // display: contents has no own box, but its descendants
                      // still contribute to intrinsic width.
                      let recursive_w = calculate_children_max_content_width(
                        child, parent_width,
                      )
                      @types.max(recursive_w, child_min_box)
                    }
                  } else {
                    // Recursively compute child's max-content width.
                    // Grid/Flex/Table children must be dispatched to their own
                    // layout algorithms in intrinsic sizing.
                    compute_recursive_child_width()
                  }
              }
          }
        @types.MinContent | @types.MaxContent => child_min_box
        @types.FitContent(_) =>
          if child.children.length() == 0 {
            child_min_box
          } else {
            let recursive_w = compute_recursive_child_width()
            @types.max(recursive_w, child_min_box)
          }
      }
      if is_ruby_internal_id(child.id) {
        let ruby_internal_width = calculate_children_max_content_width(
            child, parent_width,
          ) +
          child_min_box
        if ruby_internal_width > child_intrinsic_width {
          child_intrinsic_width = ruby_internal_width
        }
      }
      let child_contribution = child_intrinsic_width + child_margin_sum
      if style.writing_mode.is_vertical() {
        max_content_width = max_content_width + child_contribution
      } else if inline_only && inline_has_forced_break {
        current_inline_line_width = current_inline_line_width +
          child_contribution
        if child.id == "br" {
          if current_inline_line_width > max_content_width {
            max_content_width = current_inline_line_width
          }
          current_inline_line_width = 0.0
        }
      } else if inline_only {
        max_content_width = max_content_width + child_contribution
      } else if child_contribution > max_content_width {
        max_content_width = child_contribution
      }
    }
    if inline_only &&
      inline_has_forced_break &&
      current_inline_line_width > max_content_width {
      max_content_width = current_inline_line_width
    }

    // Floats also contribute to shrink-to-fit/max-content width.
    // Use the total inline span of floats to match fit-content behavior.
    let mut float_total_width = 0.0
    for child in float_nodes {
      let child_style = child.style
      let child_margin_left : Double = match child_style.margin.left {
        @types.Length(l) => l
        @types.Percent(_) => 0.0
        @types.Calc(_, _) => 0.0
        @types.MathFn(_, _) => 0.0
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 0.0
      }
      let child_margin_right : Double = match child_style.margin.right {
        @types.Length(r) => r
        @types.Percent(_) => 0.0
        @types.Calc(_, _) => 0.0
        @types.MathFn(_, _) => 0.0
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 0.0
      }
      let child_margin_sum = child_margin_left + child_margin_right
      let child_padding_left : Double = match child_style.padding.left {
        @types.Length(l) => l
        @types.Percent(_) => 0.0
        @types.Calc(_, _) => 0.0
        @types.MathFn(_, _) => 0.0
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 0.0
      }
      let child_padding_right : Double = match child_style.padding.right {
        @types.Length(r) => r
        @types.Percent(_) => 0.0
        @types.Calc(_, _) => 0.0
        @types.MathFn(_, _) => 0.0
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 0.0
      }
      let child_border = @types.resolve_rect(child_style.border, parent_width)
      let child_min_box = child_padding_left +
        child_padding_right +
        child_border.horizontal_sum()
      let child_padding_v = resolve_dimension_intrinsic(child_style.padding.top) +
        resolve_dimension_intrinsic(child_style.padding.bottom)
      fn calc_float_aspect_width(
        ratio : Double,
        h : Double,
        box_sizing : @types.BoxSizing,
        padding_v : Double,
        border_v : Double,
        padding_h : Double,
        border_h : Double,
        min_box : Double,
      ) -> Double {
        if box_sizing is @types.BorderBox {
          h * ratio
        } else {
          let content_height = h - padding_v - border_v
          if content_height > 0.0 {
            content_height * ratio + padding_h + border_h
          } else {
            min_box
          }
        }
      }
      fn compute_float_recursive_width(
        width_keyword : @types.Dimension,
      ) -> Double {
        let intrinsic_basis_width = if parent_width > 0.0 {
          parent_width
        } else {
          ctx.viewport_width
        }
        let intrinsic_child = @node.Node::with_uid_and_measure(
          child.id,
          child.uid,
          { ..child_style, width: width_keyword, },
          child.children,
          child.measure,
          child.text,
        )
        let intrinsic_ctx : @layout_types.LayoutContext = {
          available_width: intrinsic_basis_width,
          available_height: child_available_height,
          sizing_mode: @layout_types.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
          stretch_width: false,
          stretch_height: false,
        }
        let @node.DispatchFn(dispatch_fn) = dispatch
        match child_style.display {
          @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid =>
            dispatch_fn(intrinsic_child, intrinsic_ctx, dispatch).width
          _ =>
            compute_with_collapse(
              intrinsic_child, intrinsic_ctx, warnings, dispatch,
            ).layout.width
        }
      }
      let child_intrinsic_width : Double = match child_style.width {
        @types.Length(w) => @types.max(w, child_min_box)
        @types.Percent(_) => child_min_box
        @types.Calc(_, _) => child_min_box
        @types.MathFn(_, _) => child_min_box
        @types.Auto =>
          match (child_style.aspect_ratio, child_style.height) {
            (Some(ratio), @types.Length(h)) if ratio > 0.0 =>
              calc_float_aspect_width(
                ratio,
                h,
                child_style.box_sizing,
                child_padding_v,
                child_border.vertical_sum(),
                child_padding_left + child_padding_right,
                child_border.horizontal_sum(),
                child_min_box,
              )
            (Some(ratio), @types.Percent(p)) if ratio > 0.0 =>
              match child_available_height {
                Some(parent_content_h) => {
                  let h = parent_content_h * p
                  calc_float_aspect_width(
                    ratio,
                    h,
                    child_style.box_sizing,
                    child_padding_v,
                    child_border.vertical_sum(),
                    child_padding_left + child_padding_right,
                    child_border.horizontal_sum(),
                    child_min_box,
                  )
                }
                None => child_min_box
              }
            _ =>
              match child.measure {
                Some(mf) => {
                  let intrinsic = (mf.func)(0.0, 0.0)
                  @types.max(intrinsic.max_width + child_min_box, child_min_box)
                }
                None =>
                  if child.children.length() == 0 {
                    child_min_box
                  } else {
                    let recursive_w = compute_float_recursive_width(
                      @types.MaxContent,
                    )
                    @types.max(recursive_w, child_min_box)
                  }
              }
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
          child_min_box
      }
      float_total_width = float_total_width +
        child_intrinsic_width +
        child_margin_sum
    }
    if float_total_width > max_content_width {
      max_content_width = float_total_width
    }
  }
  if multicol_intrinsic_content_width > max_content_width {
    max_content_width = multicol_intrinsic_content_width
  }
  if max_content_width < 0.0 {
    max_content_width = 0.0
  }
  let skip_intrinsic_inline = style.suppresses_intrinsic_width()
  let mut min_content_width = if skip_intrinsic_inline {
    style.contained_intrinsic_width_fallback() +
    padding.horizontal_sum() +
    border.horizontal_sum()
  } else {
    calculate_children_min_content_width(
      node, parent_width, child_available_height,
    ) +
    padding.horizontal_sum() +
    border.horizontal_sum()
  }
  if min_content_width < multicol_intrinsic_content_width {
    min_content_width = multicol_intrinsic_content_width
  }
  let shrink_available_width = if box_width > 0.0 { box_width } else { 0.0 }
  // Update box_width from intrinsic width according to specified width keyword.
  box_width = match style.width {
    @types.MinContent => min_content_width
    @types.Auto =>
      if is_inline_block {
        // Inline-block width:auto uses shrink-to-fit.
        let preferred_max = max_content_width +
          padding.horizontal_sum() +
          border.horizontal_sum()
        let mut shrink_to_fit = @types.max(
          min_content_width, shrink_available_width,
        )
        if shrink_to_fit > preferred_max {
          shrink_to_fit = preferred_max
        }
        shrink_to_fit
      } else {
        max_content_width + padding.horizontal_sum() + border.horizontal_sum()
      }
    @types.MaxContent | @types.FitContent(_) =>
      max_content_width + padding.horizontal_sum() + border.horizontal_sum()
    _ => max_content_width + padding.horizontal_sum() + border.horizontal_sum()
  }
  let intrinsic_max_width_for_constraints = if skip_intrinsic_inline {
    style.contained_intrinsic_width_fallback() +
    padding.horizontal_sum() +
    border.horizontal_sum()
  } else {
    calculate_children_max_content_width(node, parent_width) +
    padding.horizontal_sum() +
    border.horizontal_sum()
  }
  let intrinsic_min_width_for_constraints = if skip_intrinsic_inline {
    style.contained_intrinsic_width_fallback() +
    padding.horizontal_sum() +
    border.horizontal_sum()
  } else {
    calculate_children_min_content_width(
      node, parent_width, child_available_height,
    ) +
    padding.horizontal_sum() +
    border.horizontal_sum()
  }
  // Re-apply min/max constraints (max first, then min for precedence)
  match style.max_width {
    @types.Length(max_w) => if box_width > max_w { box_width = max_w }
    @types.Percent(p) => {
      let max_w = parent_width * p
      if box_width > max_w {
        box_width = max_w
      }
    }
    @types.Calc(px, p) => {
      let max_w = parent_width * p + px
      if box_width > max_w {
        box_width = max_w
      }
    }
    @types.MathFn(__mop, __mterms) => {
      let max_w = @types.apply_math_op(
        __mop,
        __mterms.map(fn(__t) { parent_width * __t.1 + __t.0 }),
      )
      if box_width > max_w {
        box_width = max_w
      }
    }
    @types.MaxContent | @types.FitContent(_) => {
      let intrinsic_width = intrinsic_max_width_for_constraints
      if box_width > intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.MinContent => {
      let intrinsic_width = intrinsic_min_width_for_constraints
      if box_width > intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.Auto => ()
  }
  match style.min_width {
    @types.Length(min_w) => if box_width < min_w { box_width = min_w }
    @types.Percent(p) => {
      let min_w = parent_width * p
      if box_width < min_w {
        box_width = min_w
      }
    }
    @types.Calc(px, p) => {
      let min_w = parent_width * p + px
      if box_width < min_w {
        box_width = min_w
      }
    }
    @types.MathFn(__mop, __mterms) => {
      let min_w = @types.apply_math_op(
        __mop,
        __mterms.map(fn(__t) { parent_width * __t.1 + __t.0 }),
      )
      if box_width < min_w {
        box_width = min_w
      }
    }
    @types.MaxContent => {
      let intrinsic_width = intrinsic_max_width_for_constraints
      if box_width < intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.MinContent | @types.FitContent(_) => {
      let intrinsic_width = intrinsic_min_width_for_constraints
      if box_width < intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.Auto => ()
  }
  // Ensure box_width is at least padding + border (CSS rule: padding/border override max-size)
  if box_width < min_box_width {
    box_width = min_box_width
  }
  box_width
}
