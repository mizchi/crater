///|
/// Absolute positioning, containing-block, zoom, and transform scaling helpers.

///|
fn resolve_inset_for_root(
  value : @types.Dimension,
  available : Double,
) -> Double? {
  match value {
    @types.Length(v) => Some(v)
    @types.Percent(p) => Some(available * p)
    _ => None
  }
}

///|
fn inset_is_definite_for_root(
  value : @types.Dimension,
  available : Double,
) -> Bool {
  resolve_inset_for_root(value, available) is Some(_)
}

///|
fn resolve_non_auto_length_for_root(
  value : @types.Dimension,
  available : Double,
) -> Double {
  match value {
    @types.Length(v) => v
    @types.Percent(p) => available * p
    _ => 0.0
  }
}

///|
fn resolve_out_of_flow_root_auto_size(
  style : @style.Style,
  viewport_width : Double,
  viewport_height : Double,
) -> @style.Style {
  let inset_left = resolve_inset_for_root(style.inset.left, viewport_width)
  let inset_right = resolve_inset_for_root(style.inset.right, viewport_width)
  let inset_top = resolve_inset_for_root(style.inset.top, viewport_height)
  let inset_bottom = resolve_inset_for_root(style.inset.bottom, viewport_height)
  let margin_left = resolve_non_auto_length_for_root(
    style.margin.left,
    viewport_width,
  )
  let margin_right = resolve_non_auto_length_for_root(
    style.margin.right,
    viewport_width,
  )
  let margin_top = resolve_non_auto_length_for_root(
    style.margin.top,
    viewport_height,
  )
  let margin_bottom = resolve_non_auto_length_for_root(
    style.margin.bottom,
    viewport_height,
  )
  let mut next_style = style
  match (next_style.width, inset_left, inset_right) {
    (@types.Auto, Some(left), Some(right)) => {
      let used = viewport_width - left - right - margin_left - margin_right
      let used = if used > 0.0 { used } else { 0.0 }
      next_style = { ..next_style, width: @types.Length(used) }
    }
    _ => ()
  }
  match (next_style.height, inset_top, inset_bottom) {
    (@types.Auto, Some(top), Some(bottom)) => {
      let used = viewport_height - top - bottom - margin_top - margin_bottom
      let used = if used > 0.0 { used } else { 0.0 }
      next_style = { ..next_style, height: @types.Length(used) }
    }
    _ => ()
  }
  next_style
}

///|
fn is_svg_container_id(id : String) -> Bool {
  let mut end = id.length()
  for i = 0; i < id.length(); i = i + 1 {
    let c = id[i]
    if c == '#' || c == '.' {
      end = i
      break
    }
  }
  let tag = if end < id.length() {
    id.unsafe_substring(start=0, end~)
  } else {
    id
  }
  match tag {
    "svg"
    | "g"
    | "defs"
    | "clipPath"
    | "mask"
    | "pattern"
    | "symbol"
    | "foreignObject" => true
    _ => false
  }
}

///|
fn establishes_absolute_containing_block(node : @node.Node) -> Bool {
  let style = node.style
  let containment_applies = !is_no_principal_table_internal_display(
    style.display,
  )
  let containment_establishes_cb = containment_applies &&
    (style.contain.paint || style.contain.layout)
  let positioned = match style.position {
    @types.Static => false
    _ => true
  }
  positioned ||
  containment_establishes_cb ||
  !style.transform.is_none() ||
  style.has_filter ||
  is_svg_container_id(node.id)
}

///|
fn is_auto_inset(dim : @types.Dimension) -> Bool {
  match dim {
    @types.Dimension::Auto => true
    _ => false
  }
}

///|
fn has_non_auto_horizontal_insets(style : @style.Style) -> Bool {
  !is_auto_inset(style.inset.left) || !is_auto_inset(style.inset.right)
}

///|
fn has_non_auto_vertical_insets(style : @style.Style) -> Bool {
  !is_auto_inset(style.inset.top) || !is_auto_inset(style.inset.bottom)
}

///|
fn is_flex_or_grid_container_display(display : @types.Display) -> Bool {
  match display {
    @types.Grid | @types.InlineGrid | @types.Flex | @types.InlineFlex => true
    _ => false
  }
}

///|
fn compute_abspos_non_auto_inset_alignment_offset(
  self_alignment : @types.AlignSelf,
  inset_start : @types.Dimension,
  inset_end : @types.Dimension,
  containing_block_size : Double,
  child_size : Double,
) -> Double {
  if is_auto_inset(inset_start) || is_auto_inset(inset_end) {
    return 0.0
  }
  let start = resolve_dimension_with_percent_basis(
    inset_start, containing_block_size,
  )
  let end = resolve_dimension_with_percent_basis(
    inset_end, containing_block_size,
  )
  let free_space = containing_block_size - start - end - child_size
  match self_alignment {
    @types.AlignSelf::Center => free_space / 2.0
    @types.AlignSelf::End => free_space
    _ => 0.0
  }
}

///|
/// Apply zoom and transform scale to a layout tree
/// This modifies the layout dimensions to reflect the visual bounding box
/// as reported by getBoundingClientRect() in browsers
///
/// Note: While CSS zoom is inherited, transform scale is not. However, for
/// getBoundingClientRect() calculations, parent transform affects children's
/// visual bounding boxes. So we pass both zoom and parent_scale to children.
fn apply_zoom_and_scale(
  layout : @layout_types.Layout,
  node : @node.Node,
  parent_zoom : Double,
  parent_scale_x : Double,
  parent_scale_y : Double,
  parent_global_x : Double,
  parent_global_y : Double,
  has_abs_containing_block_ancestor : Bool,
  abs_containing_block_global_x : Double,
  abs_containing_block_global_y : Double,
  abs_containing_block_width : Double,
  abs_containing_block_height : Double,
) -> @layout_types.Layout {
  // Calculate effective zoom (parent zoom * node zoom)
  let effective_zoom = parent_zoom * node.style.zoom

  // Calculate effective scale from transform (node's own scale)
  let node_scale_x = node.style.transform.scale_x
  let node_scale_y = node.style.transform.scale_y

  // Total scale = parent_scale * zoom * node_scale
  let total_scale_x = parent_scale_x * effective_zoom * node_scale_x
  let total_scale_y = parent_scale_y * effective_zoom * node_scale_y

  // Scale for children includes this node's transform (since parent transform affects children visually)
  let child_parent_scale_x = total_scale_x / effective_zoom // Remove node zoom, will be re-applied
  let child_parent_scale_y = total_scale_y / effective_zoom

  // Scale the layout dimensions
  let scaled_width = layout.width * total_scale_x
  let scaled_height = layout.height * total_scale_y

  // Compute translate offset (uses original layout dimensions before scaling)
  let translate_x = node.style.transform.compute_translate_x(layout.width)
  let translate_y = node.style.transform.compute_translate_y(layout.height)

  // Scale position (x, y are relative to parent, scaled by parent's total scale)
  // Add translate offset (translate is applied in local coordinates, then scaled)
  // CSS transforms scale around the element center by default (transform-origin: 50% 50%).
  let origin_adjust_x = (1.0 - node_scale_x) *
    layout.width /
    2.0 *
    parent_scale_x *
    effective_zoom
  let origin_adjust_y = (1.0 - node_scale_y) *
    layout.height /
    2.0 *
    parent_scale_y *
    effective_zoom
  let scaled_x = layout.x * parent_scale_x * effective_zoom +
    translate_x * parent_scale_x * effective_zoom +
    origin_adjust_x
  let scaled_y = layout.y * parent_scale_y * effective_zoom +
    translate_y * parent_scale_y * effective_zoom +
    origin_adjust_y
  let global_x = parent_global_x + scaled_x
  let global_y = parent_global_y + scaled_y
  let establishes_abs_containing_block_here = establishes_absolute_containing_block(
    node,
  )
  let has_abs_containing_block = has_abs_containing_block_ancestor ||
    establishes_abs_containing_block_here
  let current_abs_containing_block_global_x = if establishes_abs_containing_block_here {
    global_x
  } else {
    abs_containing_block_global_x
  }
  let current_abs_containing_block_global_y = if establishes_abs_containing_block_here {
    global_y
  } else {
    abs_containing_block_global_y
  }
  let current_abs_containing_block_width = if establishes_abs_containing_block_here {
    scaled_width
  } else {
    abs_containing_block_width
  }
  let current_abs_containing_block_height = if establishes_abs_containing_block_here {
    scaled_height
  } else {
    abs_containing_block_height
  }

  // Process children with updated parent zoom and scale
  let scaled_children : Array[@layout_types.Layout] = []
  let mut child_node_cursor = 0
  for i = 0; i < layout.children.length(); i = i + 1 {
    let child_layout = layout.children[i]
    if node.children.length() == 0 {
      scaled_children.push(child_layout)
      continue
    }
    let mut matched_index : Int? = None
    let mut scan_index = child_node_cursor
    while scan_index < node.children.length() {
      let candidate = node.children[scan_index]
      if candidate.style.display == @types.Display::None {
        scan_index = scan_index + 1
        continue
      }
      if candidate.id == child_layout.id {
        matched_index = Some(scan_index)
        break
      }
      scan_index = scan_index + 1
    }
    let child_node = match matched_index {
      Some(index) => {
        child_node_cursor = index + 1
        node.children[index]
      }
      None =>
        if child_node_cursor < node.children.length() {
          let fallback_index = child_node_cursor
          child_node_cursor = fallback_index + 1
          node.children[fallback_index]
        } else {
          node.children[node.children.length() - 1]
        }
    }
    let scaled_child = apply_zoom_and_scale(
      child_layout, child_node, effective_zoom, child_parent_scale_x, child_parent_scale_y,
      global_x, global_y, has_abs_containing_block, current_abs_containing_block_global_x,
      current_abs_containing_block_global_y, current_abs_containing_block_width,
      current_abs_containing_block_height,
    )
    if child_node.style.position == @types.Absolute {
      let inset_left_auto = is_auto_inset(child_node.style.inset.left)
      let inset_right_auto = is_auto_inset(child_node.style.inset.right)
      let inset_top_auto = is_auto_inset(child_node.style.inset.top)
      let inset_bottom_auto = is_auto_inset(child_node.style.inset.bottom)
      let parent_based_horizontal = if has_non_auto_horizontal_insets(
          child_node.style,
        ) {
        if !inset_left_auto {
          let parent_left = resolve_dimension_with_percent_basis(
            child_node.style.inset.left,
            scaled_width,
          )
          let parent_based_x = parent_left + scaled_child.margin.left
          (scaled_child.x - parent_based_x).abs() <= 0.5
        } else if !inset_right_auto {
          let parent_right = resolve_dimension_with_percent_basis(
            child_node.style.inset.right,
            scaled_width,
          )
          let parent_based_x = scaled_width -
            scaled_child.width -
            parent_right -
            scaled_child.margin.right
          (scaled_child.x - parent_based_x).abs() <= 0.5
        } else {
          false
        }
      } else {
        false
      }
      let parent_based_vertical = if has_non_auto_vertical_insets(
          child_node.style,
        ) {
        if !inset_top_auto {
          let parent_top = resolve_dimension_with_percent_basis(
            child_node.style.inset.top,
            scaled_height,
          )
          let parent_based_y = parent_top + scaled_child.margin.top
          (scaled_child.y - parent_based_y).abs() <= 0.5
        } else if !inset_bottom_auto {
          let parent_bottom = resolve_dimension_with_percent_basis(
            child_node.style.inset.bottom,
            scaled_height,
          )
          let parent_based_y = scaled_height -
            scaled_child.height -
            parent_bottom -
            scaled_child.margin.bottom
          (scaled_child.y - parent_based_y).abs() <= 0.5
        } else {
          false
        }
      } else {
        false
      }
      let adjust_x = if has_non_auto_horizontal_insets(child_node.style) {
        if parent_based_horizontal {
          let cb_global_x = if has_abs_containing_block {
            current_abs_containing_block_global_x
          } else {
            0.0
          }
          cb_global_x - global_x
        } else {
          0.0
        }
      } else {
        0.0
      }
      let adjust_y = if has_non_auto_vertical_insets(child_node.style) {
        if parent_based_vertical {
          let cb_global_y = if has_abs_containing_block {
            current_abs_containing_block_global_y
          } else {
            0.0
          }
          cb_global_y - global_y
        } else {
          0.0
        }
      } else {
        0.0
      }
      // Absolute children are laid out in their immediate static parent first.
      // For right/bottom inset cases, convert to the true containing-block size.
      let cb_size_adjust_x = if !inset_right_auto && inset_left_auto {
        let parent_right = resolve_dimension_with_percent_basis(
          child_node.style.inset.right,
          scaled_width,
        )
        let parent_based_x = scaled_width -
          scaled_child.width -
          parent_right -
          scaled_child.margin.right
        if (scaled_child.x - parent_based_x).abs() <= 0.5 {
          current_abs_containing_block_width - scaled_width
        } else {
          0.0
        }
      } else {
        0.0
      }
      let cb_size_adjust_y = if !inset_bottom_auto && inset_top_auto {
        let parent_bottom = resolve_dimension_with_percent_basis(
          child_node.style.inset.bottom,
          scaled_height,
        )
        let parent_based_y = scaled_height -
          scaled_child.height -
          parent_bottom -
          scaled_child.margin.bottom
        if (scaled_child.y - parent_based_y).abs() <= 0.5 {
          current_abs_containing_block_height - scaled_height
        } else {
          0.0
        }
      } else {
        0.0
      }
      let align_adjust_x = if is_flex_or_grid_container_display(
          node.style.display,
        ) {
        compute_abspos_non_auto_inset_alignment_offset(
          child_node.style.justify_self,
          child_node.style.inset.left,
          child_node.style.inset.right,
          current_abs_containing_block_width,
          scaled_child.width,
        )
      } else {
        0.0
      }
      let align_adjust_y = if is_flex_or_grid_container_display(
          node.style.display,
        ) {
        compute_abspos_non_auto_inset_alignment_offset(
          child_node.style.align_self,
          child_node.style.inset.top,
          child_node.style.inset.bottom,
          current_abs_containing_block_height,
          scaled_child.height,
        )
      } else {
        0.0
      }
      scaled_children.push({
        ..scaled_child,
        x: scaled_child.x + adjust_x + cb_size_adjust_x + align_adjust_x,
        y: scaled_child.y + adjust_y + cb_size_adjust_y + align_adjust_y,
      })
    } else {
      scaled_children.push(scaled_child)
    }
  }
  // Scale margin, padding, border
  let scaled_margin : @types.Rect[Double] = {
    left: layout.margin.left * total_scale_x,
    right: layout.margin.right * total_scale_x,
    top: layout.margin.top * total_scale_y,
    bottom: layout.margin.bottom * total_scale_y,
  }
  let scaled_padding : @types.Rect[Double] = {
    left: layout.padding.left * total_scale_x,
    right: layout.padding.right * total_scale_x,
    top: layout.padding.top * total_scale_y,
    bottom: layout.padding.bottom * total_scale_y,
  }
  let scaled_border : @types.Rect[Double] = {
    left: layout.border.left * total_scale_x,
    right: layout.border.right * total_scale_x,
    top: layout.border.top * total_scale_y,
    bottom: layout.border.bottom * total_scale_y,
  }
  {
    id: layout.id,
    x: scaled_x,
    y: scaled_y,
    width: scaled_width,
    height: scaled_height,
    margin: scaled_margin,
    padding: scaled_padding,
    border: scaled_border,
    overflow_x: layout.overflow_x,
    overflow_y: layout.overflow_y,
    scroll_width: layout.scroll_width * total_scale_x,
    scroll_height: layout.scroll_height * total_scale_y,
    children: scaled_children,
    text: layout.text,
  }
}
