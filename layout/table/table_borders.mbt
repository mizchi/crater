///|
/// Table border conflict helpers
///
/// Collapsed-border resolution stays separate from table flow layout.

///|
/// CSS 2.1 17.6.2.1: Resolve conflicting borders in collapsed border model.
/// Returns (winning_width, winning_style) for the border at a shared edge.
fn resolve_border_conflict(
  width_a : Double,
  style_a : @style.BorderStyle,
  width_b : Double,
  style_b : @style.BorderStyle,
) -> (Double, @style.BorderStyle) {
  // 1. hidden suppresses all borders
  if style_a == @style.BorderStyle::Hidden {
    return (0.0, @style.BorderStyle::Hidden)
  }
  if style_b == @style.BorderStyle::Hidden {
    return (0.0, @style.BorderStyle::Hidden)
  }
  // 2. none loses to everything
  if style_a == @style.BorderStyle::None && style_b == @style.BorderStyle::None {
    return (0.0, @style.BorderStyle::None)
  }
  if style_a == @style.BorderStyle::None {
    return (width_b, style_b)
  }
  if style_b == @style.BorderStyle::None {
    return (width_a, style_a)
  }
  // 3. Wider border wins
  if width_a > width_b {
    return (width_a, style_a)
  }
  if width_b > width_a {
    return (width_b, style_b)
  }
  // 4. Same width: higher priority style wins
  if style_a.priority() >= style_b.priority() {
    (width_a, style_a)
  } else {
    (width_b, style_b)
  }
}

///|
/// Get the resolved collapsed border width for a shared edge.
fn resolve_collapsed_border_width(
  width_a : Double,
  style_a : @style.BorderStyle,
  width_b : Double,
  style_b : @style.BorderStyle,
) -> Double {
  let (w, _) = resolve_border_conflict(width_a, style_a, width_b, style_b)
  w
}
// - Fixed table layout (table-layout: fixed)
// - colspan (cells spanning multiple columns)
// - rowspan (cells spanning multiple rows)
// - border-collapse and border-spacing
// - caption-side (top/bottom)

///|
/// Helper function for max
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// In collapsed border model, only half of the table border contributes to the
/// inner table area on each side.
fn table_border_inset(
  border : @types.Rect[Double],
  border_collapse : Bool,
) -> @types.Rect[Double] {
  if border_collapse {
    {
      left: border.left * 0.5,
      right: border.right * 0.5,
      top: border.top * 0.5,
      bottom: border.bottom * 0.5,
    }
  } else {
    border
  }
}
