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
        node.style.display == @types.InlineGrid {
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
/// Compute the baseline of a node for baseline alignment
/// For text nodes: baseline = font_size * 0.8 (typical ascent ratio)
/// For other leaf nodes: baseline = height (bottom of box)
/// For Column flex containers: baseline = first child's baseline + padding + margin
/// For Row flex containers: baseline = first child's baseline
/// For Block containers: baseline = first in-flow child's baseline
pub fn compute_node_baseline(node : @node.Node, node_height : Double) -> Double {
  let children = node.children
  let style = node.style

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
    @types.Block =>
      // For Block containers with children: use first in-flow child's baseline
      match first_in_flow_child_baseline(children, node_height) {
        Some(child_baseline) => child_baseline
        None => node_height
      }
    @types.Inline =>
      // Inline containers participate in baseline from their first line box.
      match first_in_flow_child_baseline(children, node_height) {
        Some(child_baseline) => child_baseline
        None => text_baseline_from_style(style)
      }
    _ => node_height
  }
}
