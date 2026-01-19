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
/// Compute the baseline of a node for baseline alignment
/// For text nodes: baseline = font_size * 0.8 (typical ascent ratio)
/// For other leaf nodes: baseline = height (bottom of box)
/// For Column flex containers: baseline = first child's baseline + padding + margin
/// For Row flex containers: baseline = first child's baseline
/// For Block containers: baseline = first in-flow child's baseline
pub fn compute_node_baseline(node : @node.Node, node_height : Double) -> Double {
  let children = node.children

  // Leaf nodes: use font-based baseline for text, height for others
  if children.length() == 0 {
    // For text nodes, baseline is approximately font_size * 0.8 (ascent ratio)
    // For other leaf nodes (like images), baseline is the bottom of the box
    let font_size = node.style.font_size
    if font_size > 0.0 && node.id.has_prefix("#text") {
      // Text baseline is at the ascent position (about 80% of font-size from top)
      return font_size * 0.8
    }
    return node_height
  }
  let style = node.style

  // Only Flex containers have special baseline behavior
  match style.display {
    @style.Flex =>
      match style.flex_direction {
        @style.Column | @style.ColumnReverse => {
          // For Column flex: baseline is padding-top + first child's margin-top + child's baseline
          // Get container's padding-top
          let padding_top = match style.padding.top {
            @types.Length(v) => v
            _ => 0.0
          }
          // Find first in-flow child
          for i = 0; i < children.length(); i = i + 1 {
            let child = children[i]
            if child.style.display == @style.None {
              continue
            }
            if child.style.position == @style.Absolute {
              continue
            }
            // Get first child's margin-top (contributes to baseline position)
            let child_margin_top = match child.style.margin.top {
              @types.Length(v) => v
              _ => 0.0
            }
            // Get first child's height
            let child_height = match child.style.height {
              @types.Length(h) => h
              _ => 0.0 // For auto height, use 0 (will be computed later)
            }
            // Recursively compute child's baseline, add padding-top and margin-top
            return padding_top +
              child_margin_top +
              compute_node_baseline(child, child_height)
          }
          // No in-flow children, use own height
          return node_height
        }
        @style.Row | @style.RowReverse => {
          // For Row flex: baseline is first in-flow child's baseline
          for i = 0; i < children.length(); i = i + 1 {
            let child = children[i]
            if child.style.display == @style.None {
              continue
            }
            if child.style.position == @style.Absolute {
              continue
            }
            // Get first child's height
            let child_height = match child.style.height {
              @types.Length(h) => h
              _ => 0.0
            }
            // Recursively compute child's baseline
            return compute_node_baseline(child, child_height)
          }
          // No in-flow children, use own height
          node_height
        }
      }
    @style.Block => {
      // For Block containers with children: use first in-flow child's baseline
      for i = 0; i < children.length(); i = i + 1 {
        let child = children[i]
        if child.style.display == @style.None {
          continue
        }
        if child.style.position == @style.Absolute {
          continue
        }
        // Get first child's height
        let child_height = match child.style.height {
          @types.Length(h) => h
          _ => 0.0
        }
        // Recursively compute child's baseline
        return compute_node_baseline(child, child_height)
      }
      // No in-flow children, use own height
      node_height
    }
    _ => node_height
  }
}
