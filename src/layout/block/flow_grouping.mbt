///|
/// Flow child group for anonymous block box processing
/// When a block container has mixed inline/block children,
/// contiguous inline children are grouped together for IFC processing
priv enum FlowChildGroup {
  /// Contiguous inline elements (processed through IFC as anonymous block)
  InlineGroup(nodes~ : Array[@node.Node], indices~ : Array[Int])
  /// Single block-level element
  BlockChild(node~ : @node.Node, index~ : Int)
}

///|
/// Check if flow_nodes contains both inline and block level elements
/// This determines whether we need anonymous block box processing
fn has_mixed_inline_block_content(flow_nodes : Array[@node.Node]) -> Bool {
  let mut has_inline = false
  let mut has_block = false
  for node in flow_nodes {
    if node.style.display == @types.Display::None {
      continue
    }
    if is_inline_group_participant(node) {
      has_inline = true
    } else {
      has_block = true
    }
    if has_inline && has_block {
      return true
    }
  }
  false
}

///|
fn is_inline_group_participant(node : @node.Node) -> Bool {
  if node.id == "br" || node.id.has_prefix("#text") {
    return true
  }
  if @inline.is_inline_level(node.style.display) {
    return true
  }
  if node.style.display == @types.Contents && contents_is_inline_flow(node) {
    return true
  }
  false
}

///|
fn has_table_internal_flow_content(flow_nodes : Array[@node.Node]) -> Bool {
  for node in flow_nodes {
    if is_table_internal_flow_node(node) {
      return true
    }
  }
  false
}

///|
fn contents_is_inline_flow(node : @node.Node) -> Bool {
  let mut has_inline = false
  for child in node.children {
    if child.style.display == @types.Display::None {
      continue
    }
    if child.id == "br" || child.id.has_prefix("#text") {
      has_inline = true
      continue
    }
    if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    match child.style.float {
      @types.Float::Left | @types.Float::Right => return false
      @types.Float::None => ()
    }
    if child.style.display == @types.Contents {
      if not(contents_is_inline_flow(child)) {
        return false
      }
      has_inline = true
    } else if @inline.is_inline_level(child.style.display) {
      has_inline = true
    } else {
      return false
    }
  }
  has_inline
}

///|
fn should_establish_ifc_with_contents(children : Array[@node.Node]) -> Bool {
  if children.length() == 0 {
    return false
  }
  let mut has_inline = false
  for child in children {
    if child.style.display == @types.Display::None {
      continue
    }
    if child.id == "br" || child.id.has_prefix("#text") {
      has_inline = true
      continue
    }
    if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    match child.style.float {
      @types.Float::Left | @types.Float::Right => continue
      @types.Float::None => ()
    }
    if @inline.is_inline_level(child.style.display) {
      has_inline = true
    } else if child.style.display == @types.Contents {
      if contents_is_inline_flow(child) {
        has_inline = true
      } else {
        return false
      }
    } else {
      return false
    }
  }
  has_inline
}

///|
/// Group contiguous inline elements together for anonymous block box processing
/// Block elements become individual BlockChild entries
/// Contiguous inline elements are grouped into InlineGroup entries
fn group_flow_children_for_anonymous_blocks(
  flow_nodes : Array[@node.Node],
  flow_indices : Array[Int],
) -> Array[FlowChildGroup] {
  let groups : Array[FlowChildGroup] = []
  let mut current_inline_nodes : Array[@node.Node] = []
  let mut current_inline_indices : Array[Int] = []
  for i = 0; i < flow_nodes.length(); i = i + 1 {
    let node = flow_nodes[i]
    let index = flow_indices[i]
    if is_inline_group_participant(node) {
      // Add to current inline group
      current_inline_nodes.push(node)
      current_inline_indices.push(index)
    } else {
      // Block element: flush current inline group first
      if current_inline_nodes.length() > 0 {
        groups.push(
          InlineGroup(
            nodes=current_inline_nodes,
            indices=current_inline_indices,
          ),
        )
        current_inline_nodes = []
        current_inline_indices = []
      }
      // Add block child
      groups.push(BlockChild(node~, index~))
    }
  }
  // Flush remaining inline group
  if current_inline_nodes.length() > 0 {
    groups.push(
      InlineGroup(nodes=current_inline_nodes, indices=current_inline_indices),
    )
  }
  groups
}

///|
/// Result of mixed content layout processing
priv struct MixedContentResult {
  content_height : Double
  escaped_top : Double?
  escaped_bottom : Double?
}

///|
/// Compute layout for mixed inline/block content using anonymous block boxes
/// Each InlineGroup is processed through IFC, each BlockChild through block layout
fn compute_mixed_content_layout(
  groups : Array[FlowChildGroup],
  available_width : Double,
  available_height : Double?,
  padding : @types.Rect[Double],
  border : @types.Rect[Double],
  ctx : @types.LayoutContext,
  warnings : Array[@types.LayoutWarning],
  layout_map : Map[Int, @types.Layout],
  dispatch : @node.DispatchFn,
  writing_mode? : @style.WritingMode = @style.WritingMode::HorizontalTb,
  direction? : @style.Direction = @style.Direction::Ltr,
  text_align? : @style.TextAlign = @style.TextAlign::Start,
  white_space? : @style.WhiteSpace = @style.WhiteSpace::Normal,
  justify_items? : @types.Alignment = @types.Stretch,
  allow_mixed_auto_shrink? : Bool = true,
) -> MixedContentResult {
  // In vertical writing-mode, blocks flow horizontally instead of vertically
  let is_vertical = writing_mode.is_vertical()
  let mut current_pos = 0.0 // y in horizontal, x in vertical
  let mut prev_margin_end = 0.0
  let mut escaped_start : Double? = None
  let mut escaped_end : Double? = None
  let content_offset_x = padding.left + border.left
  let content_offset_y = padding.top + border.top
  fn resolve_mixed_justify_offset(
    item_width : Double,
    margin_left : Double,
    margin_right : Double,
  ) -> Double {
    if is_vertical {
      return 0.0
    }
    let free_space = available_width - item_width - margin_left - margin_right
    if free_space <= 0.0 {
      return 0.0
    }
    match justify_items {
      @types.Stretch
      | @types.Baseline
      | @types.SpaceBetween
      | @types.SpaceAround
      | @types.SpaceEvenly => 0.0
      @types.Center => free_space / 2.0
      @types.End | @types.Right | @types.FlexEnd => free_space
      @types.Start | @types.Left | @types.FlexStart => 0.0
    }
  }
  for i = 0; i < groups.length(); i = i + 1 {
    let group = groups[i]
    let is_first = i == 0
    let _is_last = i == groups.length() - 1
    match group {
      InlineGroup(nodes~, indices~) => {
        // Collapse previous block's margin with anonymous block (no margin)
        current_pos = current_pos + prev_margin_end
        prev_margin_end = 0.0
        // Process inline group through IFC (anonymous block box)
        let ifc_result = @inline.compute_ifc(
          nodes,
          available_width,
          available_height,
          if is_vertical {
            content_offset_x + current_pos
          } else {
            content_offset_x
          },
          if is_vertical {
            content_offset_y
          } else {
            content_offset_y + current_pos
          },
          dispatch,
          container_writing_mode=writing_mode,
          container_direction=direction,
          container_text_align=text_align,
          container_white_space=white_space,
        )
        let use_inline_fallback = ifc_result.layouts.length() == 0 &&
          nodes.length() > 0
        if use_inline_fallback {
          let fallback_layouts : Array[@types.Layout] = []
          let mut fallback_cursor = 0.0
          let mut fallback_line_height = 0.0
          for inline_node in nodes {
            let inline_ctx : @types.LayoutContext = {
              available_width,
              available_height,
              sizing_mode: @types.Definite,
              viewport_width: ctx.viewport_width,
              viewport_height: ctx.viewport_height,
              stretch_width: false,
              stretch_height: false,
            }
            let @node.DispatchFn(dispatch_fn) = dispatch
            let inline_layout = match inline_node.style.display {
              @types.Flex
              | @types.InlineFlex
              | @types.Grid
              | @types.InlineGrid
              | @types.Table
              | @types.InlineTable =>
                dispatch_fn(inline_node, inline_ctx, dispatch)
              _ =>
                compute_with_collapse(
                  inline_node, inline_ctx, warnings, dispatch,
                ).layout
            }
            fallback_layouts.push({
              ..inline_layout,
              x: content_offset_x + fallback_cursor + inline_layout.margin.left,
              y: content_offset_y + current_pos,
            })
            fallback_cursor = fallback_cursor +
              inline_layout.width +
              inline_layout.margin.left +
              inline_layout.margin.right
            let candidate_line_height = inline_layout.height +
              inline_layout.margin.top +
              inline_layout.margin.bottom
            if candidate_line_height > fallback_line_height {
              fallback_line_height = candidate_line_height
            }
          }
          let fallback_offset = resolve_mixed_justify_offset(
            fallback_cursor, 0.0, 0.0,
          )
          for j = 0; j < indices.length(); j = j + 1 {
            if j < fallback_layouts.length() {
              let child_layout = fallback_layouts[j]
              let aligned_layout = if fallback_offset.abs() > 0.0001 {
                { ..child_layout, x: child_layout.x + fallback_offset }
              } else {
                child_layout
              }
              let normalized_layout = if j < nodes.length() &&
                nodes[j].style.display == @types.Contents {
                {
                  ..aligned_layout,
                  width: 0.0,
                  height: 0.0,
                  padding: @types.Rect::zero(),
                  border: @types.Rect::zero(),
                  scroll_width: 0.0,
                  scroll_height: 0.0,
                }
              } else {
                aligned_layout
              }
              layout_map[indices[j]] = normalized_layout
            }
          }
          current_pos = current_pos + fallback_line_height
        } else {
          let mut group_min_x = 0.0
          let mut group_max_x = 0.0
          let mut has_group_box = false
          if not(is_vertical) {
            for child_layout in ifc_result.layouts {
              let child_left = child_layout.x - child_layout.margin.left
              let child_right = child_layout.x +
                child_layout.width +
                child_layout.margin.right
              if not(has_group_box) {
                group_min_x = child_left
                group_max_x = child_right
                has_group_box = true
              } else {
                if child_left < group_min_x {
                  group_min_x = child_left
                }
                if child_right > group_max_x {
                  group_max_x = child_right
                }
              }
            }
          }
          let inline_group_width = if has_group_box {
            group_max_x - group_min_x
          } else {
            0.0
          }
          let inline_group_offset = resolve_mixed_justify_offset(
            inline_group_width, 0.0, 0.0,
          )
          // Store layouts with original indices
          for j = 0; j < indices.length(); j = j + 1 {
            if j < ifc_result.layouts.length() {
              let child_layout = ifc_result.layouts[j]
              let aligned_layout = if inline_group_offset.abs() > 0.0001 {
                { ..child_layout, x: child_layout.x + inline_group_offset }
              } else {
                child_layout
              }
              let normalized_layout = if j < nodes.length() &&
                nodes[j].style.display == @types.Contents {
                {
                  ..aligned_layout,
                  width: 0.0,
                  height: 0.0,
                  padding: @types.Rect::zero(),
                  border: @types.Rect::zero(),
                  scroll_width: 0.0,
                  scroll_height: 0.0,
                }
              } else {
                aligned_layout
              }
              layout_map[indices[j]] = normalized_layout
            }
          }
          // Anonymous blocks don't have margins, so no collapse
          current_pos = current_pos + ifc_result.total_height
        }
      }
      BlockChild(node~, index~) => {
        // Process block child with margin collapsing
        // Keep auto-height flex/grid children unconstrained on block axis.
        // Otherwise mixed-content path can incorrectly stretch them to the
        // parent's available height (e.g. viewport-sized body context).
        let child_height_for_ctx : Double? = match node.style.display {
          @types.Flex
          | @types.InlineFlex
          | @types.Grid
          | @types.InlineGrid
          | @types.Table
          | @types.InlineTable =>
            match node.style.height {
              @types.Auto =>
                if node.style.writing_mode.is_vertical() {
                  available_height
                } else {
                  None
                }
              _ => available_height
            }
          _ => available_height
        }
        let child_ctx : @types.LayoutContext = {
          available_width,
          available_height: child_height_for_ctx,
          sizing_mode: @types.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
          stretch_width: false,
          stretch_height: false,
        }
        // Use dispatch for flex/grid/table containers, block layout for others
        let @node.DispatchFn(dispatch_fn) = dispatch
        let child_layout = match node.style.display {
          @types.Flex
          | @types.InlineFlex
          | @types.Grid
          | @types.InlineGrid
          | @types.Table
          | @types.InlineTable => dispatch_fn(node, child_ctx, dispatch)
          _ => {
            let raw = compute_with_collapse(node, child_ctx, warnings, dispatch)
            apply_initial_scroll_snap(node, raw.layout)
          }
        }
        let mut aligned_child_width = child_layout.width
        let justify_items_enables_self_alignment = match justify_items {
          @types.Stretch
          | @types.Baseline
          | @types.SpaceBetween
          | @types.SpaceAround
          | @types.SpaceEvenly => false
          _ => true
        }
        if allow_mixed_auto_shrink &&
          not(is_vertical) &&
          justify_items_enables_self_alignment &&
          node.style.width == @types.Auto {
          let intrinsic_inline = if node.children.length() == 0 &&
            node.measure is None &&
            node.text is None {
            0.0
          } else {
            calculate_children_max_content_width(node, available_width)
          }
          let min_box_width = child_layout.padding.horizontal_sum() +
            child_layout.border.horizontal_sum()
          let fit_content_width = intrinsic_inline + min_box_width
          if fit_content_width < aligned_child_width {
            aligned_child_width = fit_content_width
          }
          if aligned_child_width < min_box_width {
            aligned_child_width = min_box_width
          }
        }
        // Calculate margin values - use appropriate axis based on writing mode
        let margin_start = if is_vertical {
          child_layout.margin.left
        } else {
          child_layout.margin.top
        }
        let margin_end = if is_vertical {
          child_layout.margin.right
        } else {
          child_layout.margin.bottom
        }
        // Collapse margins (only in horizontal mode; vertical mode uses physical margins)
        let collapsed = if is_vertical {
          margin_start // No collapse in vertical mode for now
        } else {
          collapse_margins(prev_margin_end, margin_start)
        }
        // Handle first child - check if margin escapes
        let edge_padding = if is_vertical { padding.left } else { padding.top }
        let edge_border = if is_vertical { border.left } else { border.top }
        if is_first && escaped_start is None {
          // Check if we can collapse through (parent has no padding/border on start edge)
          if edge_padding == 0.0 && edge_border == 0.0 {
            escaped_start = Some(margin_start)
          } else {
            current_pos = current_pos + margin_start
          }
        } else {
          current_pos = current_pos + collapsed
        }
        // Position and store layout - swap x/y based on writing mode
        let base_x = if is_vertical {
          content_offset_x + current_pos
        } else {
          content_offset_x +
          child_layout.margin.left +
          resolve_mixed_justify_offset(
            aligned_child_width,
            child_layout.margin.left,
            child_layout.margin.right,
          )
        }
        let base_y = if is_vertical {
          content_offset_y + child_layout.margin.top
        } else {
          content_offset_y + current_pos
        }
        let (layout_x, layout_width, layout_children) = if node.id == "span" {
          let mut has_visible_child = false
          for grand_layout in child_layout.children {
            if grand_layout.width > 0.0 || grand_layout.height > 0.0 {
              has_visible_child = true
              break
            }
          }
          if has_visible_child {
            let shifted_children : Array[@types.Layout] = []
            for grand_layout in child_layout.children {
              shifted_children.push({
                ..grand_layout,
                x: grand_layout.x - child_layout.width,
              })
            }
            (base_x + child_layout.width, 0.0, shifted_children)
          } else {
            (base_x, child_layout.width, child_layout.children)
          }
        } else {
          (base_x, child_layout.width, child_layout.children)
        }
        let positioned_layout : @types.Layout = {
          id: child_layout.id,
          x: layout_x,
          y: base_y,
          width: if node.id == "span" {
            layout_width
          } else {
            aligned_child_width
          },
          height: child_layout.height,
          margin: child_layout.margin,
          padding: child_layout.padding,
          border: child_layout.border,
          overflow_x: child_layout.overflow_x,
          overflow_y: child_layout.overflow_y,
          scroll_width: child_layout.scroll_width,
          scroll_height: child_layout.scroll_height,
          children: layout_children,
          text: child_layout.text,
        }
        layout_map[index] = positioned_layout
        // Update state - advance by width in vertical mode, height in horizontal
        let explicit_zero_height = match node.style.height {
          @types.Length(v) => v == 0.0
          _ => false
        }
        let child_size = if not(is_vertical) && explicit_zero_height {
          0.0
        } else if is_vertical {
          if child_layout.width > 0.0 {
            child_layout.width
          } else {
            get_children_flow_extent_width(child_layout.children)
          }
        } else if child_layout.height > 0.0 {
          child_layout.height
        } else {
          get_children_flow_extent_height(child_layout.children)
        }
        current_pos = current_pos + child_size
        prev_margin_end = margin_end
        escaped_end = Some(margin_end)
      }
    }
  }
  // Add final margin if not escaping
  let end_padding = if is_vertical { padding.right } else { padding.bottom }
  let end_border = if is_vertical { border.right } else { border.bottom }
  if end_padding > 0.0 || end_border > 0.0 {
    current_pos = current_pos + prev_margin_end
    escaped_end = None
  }
  // content_height represents the content size in the block flow direction
  // In vertical mode, this is actually content width, but we use the same name for simplicity
  {
    content_height: current_pos,
    escaped_top: escaped_start,
    escaped_bottom: escaped_end,
  }
}
