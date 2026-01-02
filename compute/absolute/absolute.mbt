///|
/// Shared absolute positioning logic for Block, Flex, and Grid layouts

///|
/// Resolve inset dimension (left, right, top, bottom)
/// Returns None for Auto, Some(value) for Length/Percent
pub fn resolve_inset(dim : @types.Dimension, available : Double) -> Double? {
  match dim {
    @types.Length(v) => Some(v)
    @types.Percent(p) => Some(available * p)
    @types.Auto => None
  }
}

///|
/// Resolve length dimension (margin, etc.) - Auto becomes 0
pub fn resolve_length_dimension(
  dim : @types.Dimension,
  available : Double,
) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(p) => available * p
    @types.Auto => 0.0
  }
}

///|
/// Clamp a value between min and max
/// CSS spec: min takes precedence over max when they conflict
/// So apply max first, then min
pub fn clamp_value(
  value : Double,
  min_val : Double,
  max_val : Double,
) -> Double {
  // First apply max constraint
  let clamped = if value > max_val { max_val } else { value }
  // Then apply min constraint (min wins if min > max)
  if clamped < min_val {
    min_val
  } else {
    clamped
  }
}

///|
/// Parameters for absolute size calculation
pub(all) struct AbsoluteSizeParams {
  // Resolved margin values
  margin_left : Double
  margin_right : Double
  margin_top : Double
  margin_bottom : Double
  // Resolved inset values (None = auto)
  inset_left : Double?
  inset_right : Double?
  inset_top : Double?
  inset_bottom : Double?
  // Initial dimensions (None = needs intrinsic sizing)
  initial_width : Double?
  initial_height : Double?
  // Min/max constraints
  min_width : Double
  max_width : Double
  min_height : Double
  max_height : Double
}

///|
/// Compute size parameters for absolute positioning
/// This resolves margins, insets, initial size, and min/max from style
pub fn compute_size_params(
  style : @style.Style,
  area_width : Double,
  area_height : Double,
) -> AbsoluteSizeParams {
  // Resolve margin values
  let margin_left = resolve_length_dimension(style.margin.left, area_width)
  let margin_right = resolve_length_dimension(style.margin.right, area_width)
  let margin_top = resolve_length_dimension(style.margin.top, area_height)
  let margin_bottom = resolve_length_dimension(style.margin.bottom, area_height)

  // Resolve inset values
  let inset_left = resolve_inset(style.inset.left, area_width)
  let inset_right = resolve_inset(style.inset.right, area_width)
  let inset_top = resolve_inset(style.inset.top, area_height)
  let inset_bottom = resolve_inset(style.inset.bottom, area_height)

  // Calculate initial width
  let initial_width : Double? = match style.width {
    @types.Length(w) => Some(w)
    @types.Percent(p) => Some(area_width * p)
    @types.Auto =>
      match (inset_left, inset_right) {
        (Some(l), Some(r)) => {
          let w = area_width - l - r - margin_left - margin_right
          Some(if w > 0.0 { w } else { 0.0 })
        }
        _ => None
      }
  }

  // Calculate initial height
  let initial_height : Double? = match style.height {
    @types.Length(h) => Some(h)
    @types.Percent(p) => Some(area_height * p)
    @types.Auto =>
      match (inset_top, inset_bottom) {
        (Some(t), Some(b)) => {
          let h = area_height - t - b - margin_top - margin_bottom
          Some(if h > 0.0 { h } else { 0.0 })
        }
        _ => None
      }
  }

  // Resolve min/max constraints
  let min_width = match style.min_width {
    @types.Length(v) => v
    @types.Percent(p) => area_width * p
    @types.Auto => 0.0
  }
  let max_width = match style.max_width {
    @types.Length(v) => v
    @types.Percent(p) => area_width * p
    @types.Auto => @double.infinity
  }
  let min_height = match style.min_height {
    @types.Length(v) => v
    @types.Percent(p) => area_height * p
    @types.Auto => 0.0
  }
  let max_height = match style.max_height {
    @types.Length(v) => v
    @types.Percent(p) => area_height * p
    @types.Auto => @double.infinity
  }
  {
    margin_left,
    margin_right,
    margin_top,
    margin_bottom,
    inset_left,
    inset_right,
    inset_top,
    inset_bottom,
    initial_width,
    initial_height,
    min_width,
    max_width,
    min_height,
    max_height,
  }
}

///|
/// Check if a dimension has explicit constraint (min or max)
/// Note: min-width/height: 0 is not considered a real constraint since it's
/// typically used to disable auto min-width/height behavior, not to actually
/// constrain the dimension.
pub fn has_dimension_constraint(style : @style.Style, is_width : Bool) -> Bool {
  if is_width {
    match style.max_width {
      @types.Length(_) | @types.Percent(_) => true
      @types.Auto =>
        match style.min_width {
          @types.Length(v) if v > 0.0 => true
          @types.Percent(p) if p > 0.0 => true
          _ => false
        }
    }
  } else {
    match style.max_height {
      @types.Length(_) | @types.Percent(_) => true
      @types.Auto =>
        match style.min_height {
          @types.Length(v) if v > 0.0 => true
          @types.Percent(p) if p > 0.0 => true
          _ => false
        }
    }
  }
}

///|
/// Apply min/max constraints and re-apply aspect ratio
/// Returns (final_width, final_height)
pub fn apply_constraints_with_aspect_ratio(
  width : Double,
  height : Double,
  style : @style.Style,
  min_w : Double,
  max_w : Double,
  min_h : Double,
  max_h : Double,
) -> (Double, Double) {
  // Apply min/max constraints
  let clamped_width = clamp_value(width, min_w, max_w)
  let clamped_height = clamp_value(height, min_h, max_h)

  // Re-apply aspect ratio after min/max constraints
  match style.aspect_ratio {
    Some(ar) if ar > 0.0 => {
      let width_has_constraint = has_dimension_constraint(style, true)
      let height_has_constraint = has_dimension_constraint(style, false)
      if height_has_constraint && not(width_has_constraint) {
        // Height is the driver, calculate width
        (clamped_height * ar, clamped_height)
      } else {
        // Width is the driver, calculate height
        (clamped_width, clamped_width / ar)
      }
    }
    _ => (clamped_width, clamped_height)
  }
}

///|
/// Compute position from insets (basic case without alignment)
/// Returns (x, y)
pub fn compute_inset_position(
  params : AbsoluteSizeParams,
  child_width : Double,
  child_height : Double,
  area_left : Double,
  area_top : Double,
  area_width : Double,
  area_height : Double,
) -> (Double, Double) {
  let area_right = area_left + area_width
  let area_bottom = area_top + area_height

  // Calculate x position
  let x = match params.inset_left {
    Some(l) => area_left + l + params.margin_left
    None =>
      match params.inset_right {
        Some(r) => area_right - r - params.margin_right - child_width
        None => area_left + params.margin_left // Default to start
      }
  }

  // Calculate y position
  let y = match params.inset_top {
    Some(t) => area_top + t + params.margin_top
    None =>
      match params.inset_bottom {
        Some(b) => area_bottom - b - params.margin_bottom - child_height
        None => area_top + params.margin_top // Default to start
      }
  }
  (x, y)
}

///|
/// Check if margin is auto
pub fn is_margin_auto(dim : @types.Dimension) -> Bool {
  match dim {
    @types.Auto => true
    _ => false
  }
}

///|
/// Compute position with margin:auto centering (for Block layout)
/// Returns (x, y)
pub fn compute_position_with_margin_auto(
  params : AbsoluteSizeParams,
  style : @style.Style,
  child_width : Double,
  child_height : Double,
  area_left : Double,
  area_top : Double,
  area_width : Double,
  area_height : Double,
) -> (Double, Double) {
  let area_right = area_left + area_width
  let area_bottom = area_top + area_height
  let margin_left_is_auto = is_margin_auto(style.margin.left)
  let margin_right_is_auto = is_margin_auto(style.margin.right)
  let margin_top_is_auto = is_margin_auto(style.margin.top)
  let margin_bottom_is_auto = is_margin_auto(style.margin.bottom)

  // Calculate x position with margin:auto support
  let x = match params.inset_left {
    Some(l) =>
      match params.inset_right {
        Some(r) => {
          // Both insets specified - check for margin:auto centering
          let available = area_width - l - r - child_width
          if margin_left_is_auto && margin_right_is_auto && available > 0.0 {
            // Center horizontally
            area_left + l + available / 2.0
          } else if margin_right_is_auto && available > 0.0 {
            // Push to left
            area_left + l + params.margin_left
          } else if margin_left_is_auto && available > 0.0 {
            // Push to right
            area_right - r - child_width - params.margin_right
          } else {
            area_left + l + params.margin_left
          }
        }
        None => area_left + l + params.margin_left
      }
    None =>
      match params.inset_right {
        Some(r) => area_right - r - params.margin_right - child_width
        None => area_left + params.margin_left
      }
  }

  // Calculate y position with margin:auto support
  let y = match params.inset_top {
    Some(t) =>
      match params.inset_bottom {
        Some(b) => {
          // Both insets specified - check for margin:auto centering
          let available = area_height - t - b - child_height
          if margin_top_is_auto && margin_bottom_is_auto && available > 0.0 {
            // Center vertically
            area_top + t + available / 2.0
          } else if margin_bottom_is_auto && available > 0.0 {
            // Push to top
            area_top + t + params.margin_top
          } else if margin_top_is_auto && available > 0.0 {
            // Push to bottom
            area_bottom - b - child_height - params.margin_bottom
          } else {
            area_top + t + params.margin_top
          }
        }
        None => area_top + t + params.margin_top
      }
    None =>
      match params.inset_bottom {
        Some(b) => area_bottom - b - params.margin_bottom - child_height
        None => area_top + params.margin_top
      }
  }
  (x, y)
}

///|
/// Create a zero-sized layout for display:none elements
pub fn create_zero_layout(id : String) -> @node.Layout {
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  {
    id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    children: [],
    text: None,
  }
}
