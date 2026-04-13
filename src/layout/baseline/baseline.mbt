// =============================================================================
// Baseline Computation for CSS Alignment
// =============================================================================
//
// CSS Baseline Alignment:
// - For text nodes: baseline = font_size * 0.8 (typical ascent ratio)
// - For other leaf nodes: baseline = height (bottom of box)
// - For Flex/Block containers: baseline = first in-flow child's baseline
//
// References:
// - CSS Flexbox Level 1 - Baseline Participation
// - CSS Inline Layout - Baseline Synthesis

///|
fn text_baseline_from_style(style : @style.Style) -> Double {
  let font_size = style.font_size
  if font_size <= 0.0 {
    return 0.0
  }
  let line_height = if style.line_height > 0.0 {
    style.line_height
  } else {
    font_size
  }
  let leading = line_height - font_size
  let half_leading = if leading > 0.0 { leading / 2.0 } else { 0.0 }
  half_leading + font_size * 0.8
}

///|
fn infer_baseline_height(node : @node.Node, fallback_height : Double) -> Double {
  match node.style.height {
    @types.Length(h) => h
    @types.Percent(p) => fallback_height * p
    _ =>
      if node.id.has_prefix("#text") {
        if node.style.line_height > 0.0 {
          node.style.line_height
        } else if node.style.font_size > 0.0 {
          node.style.font_size
        } else {
          fallback_height
        }
      } else if node.style.display == @types.Inline ||
        node.style.display == @types.InlineBlock ||
        node.style.display == @types.InlineFlex ||
        node.style.display == @types.InlineGrid ||
        node.style.display == @types.Contents {
        if node.style.line_height > 0.0 {
          node.style.line_height
        } else {
          fallback_height
        }
      } else {
        fallback_height
      }
  }
}

///|
fn first_in_flow_child_baseline(
  children : Array[@node.Node],
  fallback_height : Double,
) -> Double? {
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    if child.style.display == @types.Display::None {
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
    let child_height = infer_baseline_height(child, fallback_height)
    return Some(compute_node_baseline(child, child_height))
  }
  None
}

///|
fn resolve_top_inset(style : @style.Style) -> Double {
  let padding_top = match style.padding.top {
    @types.Length(v) => v
    _ => 0.0
  }
  let border_top = match style.border.top {
    @types.Length(v) => v
    _ => 0.0
  }
  padding_top + border_top
}

///|
fn is_no_principal_table_internal_display(display : @types.Display) -> Bool {
  match display {
    @types.TableRow
    | @types.TableRowGroup
    | @types.TableHeaderGroup
    | @types.TableFooterGroup
    | @types.TableColumn
    | @types.TableColumnGroup => true
    _ => false
  }
}

///|
fn is_ruby_internal_no_principal(node_id : String) -> Bool {
  node_id == "rb" ||
  node_id.has_prefix("rb#") ||
  node_id == "rbc" ||
  node_id.has_prefix("rbc#") ||
  node_id == "rt" ||
  node_id.has_prefix("rt#") ||
  node_id == "rtc" ||
  node_id.has_prefix("rtc#")
}

///|
fn is_fieldset_node_id(node_id : String) -> Bool {
  node_id == "fieldset" ||
  node_id.has_prefix("fieldset#") ||
  node_id.has_prefix("fieldset.")
}

///|
fn is_legend_node_id(node_id : String) -> Bool {
  node_id == "legend" ||
  node_id.has_prefix("legend#") ||
  node_id.has_prefix("legend.")
}

///|
fn resolve_margin_top(style : @style.Style) -> Double {
  match style.margin.top {
    @types.Length(v) => v
    _ => 0.0
  }
}

///|
fn resolve_margin_bottom(style : @style.Style) -> Double {
  match style.margin.bottom {
    @types.Length(v) => v
    _ => 0.0
  }
}

///|
fn fieldset_non_legend_baseline(
  node : @node.Node,
  node_height : Double,
) -> Double? {
  if !is_fieldset_node_id(node.id) {
    return None
  }
  let mut block_offset = resolve_top_inset(node.style)
  let fallback_height = if node.style.line_height > 0.0 {
    node.style.line_height
  } else {
    node_height
  }
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if child.style.display == @types.Display::None {
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
    let margin_top = resolve_margin_top(child.style)
    let margin_bottom = resolve_margin_bottom(child.style)
    let child_height = infer_baseline_height(child, fallback_height)
    if !is_legend_node_id(child.id) {
      return Some(
        block_offset + margin_top + compute_node_baseline(child, child_height),
      )
    }
    block_offset = block_offset + margin_top + child_height + margin_bottom
  }
  None
}

///|
fn containment_layout_applies_to_baseline(node : @node.Node) -> Bool {
  if !node.style.contain.layout {
    return false
  }
  if is_no_principal_table_internal_display(node.style.display) {
    return false
  }
  !is_ruby_internal_no_principal(node.id)
}

///|
/// Compute the baseline of a node for baseline alignment
/// For text nodes: baseline = font_size * 0.8 (typical ascent ratio)
/// For other leaf nodes: baseline = height (bottom of box)
/// For Column flex containers: baseline = first child's baseline + padding + margin
/// For Row flex containers: baseline = first child's baseline
/// For Block containers: baseline = first in-flow child's baseline
pub fn compute_node_baseline(node : @node.Node, node_height : Double) -> Double {
  let children = node.children
  let style = node.style

  // contain:layout suppresses baseline participation and synthesizes one from
  // the element border box when containment actually applies.
  if containment_layout_applies_to_baseline(node) {
    return node_height
  }

  // Leaf nodes: use font-based baseline for text, height for others
  if children.length() == 0 {
    // For text nodes, baseline is ascent + half leading.
    // For other leaf nodes (like images), baseline is the bottom of the box.
    if node.id.has_prefix("#text") {
      return text_baseline_from_style(style)
    }
    return node_height
  }

  // Only Flex containers have special baseline behavior
  match style.display {
    @types.Flex =>
      match style.flex_direction {
        @types.Column | @types.ColumnReverse => {
          // For Column flex: baseline is padding-top + first child's margin-top + child's baseline
          // Get container's padding-top
          let padding_top = match style.padding.top {
            @types.Length(v) => v
            _ => 0.0
          }
          match first_in_flow_child_baseline(children, node_height) {
            Some(child_baseline) => {
              // Find first in-flow child margin-top (contributes to baseline position)
              let mut child_margin_top = 0.0
              for i = 0; i < children.length(); i = i + 1 {
                let child = children[i]
                if child.style.display == @types.Display::None {
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
                child_margin_top = match child.style.margin.top {
                  @types.Length(v) => v
                  _ => 0.0
                }
                break
              }
              return padding_top + child_margin_top + child_baseline
            }
            None => ()
          }
          // No in-flow children, use own height
          return node_height
        }
        @types.Row | @types.RowReverse =>
          // For Row flex: baseline is first in-flow child's baseline
          match first_in_flow_child_baseline(children, node_height) {
            Some(child_baseline) => child_baseline
            None => node_height
          }
      }
    @types.Block | @types.FlowRoot | @types.Grid | @types.InlineGrid =>
      match fieldset_non_legend_baseline(node, node_height) {
        Some(fieldset_baseline) => fieldset_baseline
        None =>
          // For block-like containers with children: use first in-flow child's baseline
          match first_in_flow_child_baseline(children, node_height) {
            Some(child_baseline) => child_baseline
            None => node_height
          }
      }
    @types.Table
    | @types.InlineTable
    | @types.TableRowGroup
    | @types.TableHeaderGroup
    | @types.TableFooterGroup
    | @types.TableRow
    | @types.TableCell
    | @types.TableCaption =>
      // Table wrappers contribute top inset before descendants' baseline.
      match first_in_flow_child_baseline(children, node_height) {
        Some(child_baseline) => resolve_top_inset(style) + child_baseline
        None => node_height
      }
    @types.Inline =>
      // Inline containers participate in baseline from their first line box.
      match first_in_flow_child_baseline(children, node_height) {
        Some(child_baseline) => child_baseline
        None => text_baseline_from_style(style)
      }
    @types.Contents =>
      // display: contents participates through descendants; do not synthesize
      // baseline from its aggregate box height.
      match first_in_flow_child_baseline(children, node_height) {
        Some(child_baseline) => child_baseline
        None => text_baseline_from_style(style)
      }
    _ => node_height
  }
}
