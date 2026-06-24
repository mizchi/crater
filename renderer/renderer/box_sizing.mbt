///|
// Box-sizing and dimension conversion helpers for layout style normalization.

///|
/// Helper to resolve a dimension to pixels (for padding/border calculation)
fn resolve_dimension_to_px(dim : @types.Dimension) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(_) => 0.0 // Percentages are resolved later
    @types.Calc(px, _) => px // Percent part resolved later; keep px term
    @types.MathFn(__mop, __mterms) => {
      let px = @types.apply_math_op(__mop, __mterms.map(fn(__t) { __t.0 }))
      px // Percent part resolved later; keep px term
    }
    @types.Auto => 0.0
    @types.MinContent => 0.0 // Intrinsic sizing resolved during layout
    @types.MaxContent => 0.0
    @types.FitContent(_) => 0.0
  }
}

///|
fn resolve_dimension_with_percent_basis(
  dim : @types.Dimension,
  percent_basis : Double,
) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(p) =>
      if percent_basis > 0.0 {
        percent_basis * p
      } else {
        0.0
      }
    @types.Calc(px, pct) =>
      if percent_basis > 0.0 {
        percent_basis * pct + px
      } else {
        px
      }
    @types.MathFn(__mop, __mterms) =>
      if percent_basis > 0.0 {
        @types.apply_math_op(
          __mop,
          __mterms.map(fn(__t) { percent_basis * __t.1 + __t.0 }),
        )
      } else {
        @types.apply_math_op(__mop, __mterms.map(fn(__t) { __t.0 }))
      }
    @types.Auto => 0.0
    @types.MinContent => 0.0
    @types.MaxContent => 0.0
    @types.FitContent(_) => 0.0
  }
}

///|
fn is_zero_dimension_value(dim : @types.Dimension) -> Bool {
  match dim {
    @types.Length(v) => v == 0.0
    @types.Percent(v) => v == 0.0
    _ => false
  }
}

///|
fn has_zero_box_offsets(style : @style.Style) -> Bool {
  is_zero_dimension_value(style.padding.left) &&
  is_zero_dimension_value(style.padding.right) &&
  is_zero_dimension_value(style.padding.top) &&
  is_zero_dimension_value(style.padding.bottom) &&
  is_zero_dimension_value(style.border.left) &&
  is_zero_dimension_value(style.border.right) &&
  is_zero_dimension_value(style.border.top) &&
  is_zero_dimension_value(style.border.bottom)
}

///|
/// Adjust dimensions for box-sizing: content-box
/// When box-sizing is content-box (default), specified width/height are content dimensions.
/// The layout engine expects outer dimensions (border-box), so we adjust here.
fn adjust_for_box_sizing(style : @style.Style) -> @style.Style {
  match style.box_sizing {
    @types.BorderBox => {
      let padding_h = resolve_dimension_to_px(style.padding.left) +
        resolve_dimension_to_px(style.padding.right)
      let padding_v = resolve_dimension_to_px(style.padding.top) +
        resolve_dimension_to_px(style.padding.bottom)
      let border_h = resolve_dimension_to_px(style.border.left) +
        resolve_dimension_to_px(style.border.right)
      let border_v = resolve_dimension_to_px(style.border.top) +
        resolve_dimension_to_px(style.border.bottom)
      let min_outer_width = padding_h + border_h
      let min_outer_height = padding_v + border_v

      let clamped_width = match style.width {
        @types.Length(w) =>
          @types.Dimension::Length(
            if w < min_outer_width {
              min_outer_width
            } else {
              w
            },
          )
        other => other
      }
      let clamped_height = match style.height {
        @types.Length(h) =>
          @types.Dimension::Length(
            if h < min_outer_height {
              min_outer_height
            } else {
              h
            },
          )
        other => other
      }
      let clamped_min_width = match style.min_width {
        @types.Length(w) =>
          @types.Dimension::Length(
            if w < min_outer_width {
              min_outer_width
            } else {
              w
            },
          )
        other => other
      }
      let clamped_min_height = match style.min_height {
        @types.Length(h) =>
          @types.Dimension::Length(
            if h < min_outer_height {
              min_outer_height
            } else {
              h
            },
          )
        other => other
      }
      let clamped_max_width = match style.max_width {
        @types.Length(w) =>
          @types.Dimension::Length(
            if w < min_outer_width {
              min_outer_width
            } else {
              w
            },
          )
        other => other
      }
      let clamped_max_height = match style.max_height {
        @types.Length(h) =>
          @types.Dimension::Length(
            if h < min_outer_height {
              min_outer_height
            } else {
              h
            },
          )
        other => other
      }

      {
        ..style,
        width: clamped_width,
        height: clamped_height,
        min_width: clamped_min_width,
        min_height: clamped_min_height,
        max_width: clamped_max_width,
        max_height: clamped_max_height,
      }
    }
    @types.ContentBox => {
      if has_zero_box_offsets(style) {
        return { ..style, box_sizing: @types.BorderBox }
      }
      let percent_basis = match style.width {
        @types.Length(w) =>
          if w > 0.0 {
            w +
            resolve_dimension_to_px(style.padding.left) +
            resolve_dimension_to_px(style.padding.right) +
            resolve_dimension_to_px(style.border.left) +
            resolve_dimension_to_px(style.border.right)
          } else {
            0.0
          }
        _ => 0.0
      }
      // Calculate padding and border sums
      let padding_h = resolve_dimension_with_percent_basis(
          style.padding.left,
          percent_basis,
        ) +
        resolve_dimension_with_percent_basis(style.padding.right, percent_basis)
      let padding_v = resolve_dimension_with_percent_basis(
          style.padding.top,
          percent_basis,
        ) +
        resolve_dimension_with_percent_basis(
          style.padding.bottom,
          percent_basis,
        )
      let border_h = resolve_dimension_with_percent_basis(
          style.border.left,
          percent_basis,
        ) +
        resolve_dimension_with_percent_basis(style.border.right, percent_basis)
      let border_v = resolve_dimension_with_percent_basis(
          style.border.top,
          percent_basis,
        ) +
        resolve_dimension_with_percent_basis(style.border.bottom, percent_basis)

      // Adjust width and height to include padding+border
      let adjusted_width = match style.width {
        @types.Length(w) => @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_height = match style.height {
        @types.Length(h) => @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      // Adjust min/max constraints too
      let adjusted_min_width = match style.min_width {
        @types.Length(w) => @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_min_height = match style.min_height {
        @types.Length(h) => @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      let adjusted_max_width = match style.max_width {
        @types.Length(w) => @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_max_height = match style.max_height {
        @types.Length(h) => @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      {
        ..style,
        width: adjusted_width,
        height: adjusted_height,
        min_width: adjusted_min_width,
        min_height: adjusted_min_height,
        max_width: adjusted_max_width,
        max_height: adjusted_max_height,
        // Mark as adjusted (now using border-box semantics internally)
        box_sizing: @types.BorderBox,
      }
    }
  }
}
