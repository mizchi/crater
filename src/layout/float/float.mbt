///|
/// Float Layout Module
/// Implements CSS float and clear properties

///|
/// A placed float element with its occupied region
pub(all) struct FloatBox {
  /// Left edge of the float
  x : Double
  /// Top edge of the float
  y : Double
  /// Width of the float (including margin)
  width : Double
  /// Height of the float (including margin)
  height : Double
  /// The float direction (Left or Right)
  float_type : @types.Float
}

///|
/// Get the bottom edge of this float box
pub fn FloatBox::bottom(self : FloatBox) -> Double {
  self.y + self.height
}

///|
/// Get the right edge of this float box
pub fn FloatBox::right(self : FloatBox) -> Double {
  self.x + self.width
}

///|
/// Context for tracking floats during layout
/// Tracks all currently active floats and provides methods for positioning
pub(all) struct FloatContext {
  /// Container width (available space for floats)
  container_width : Double
  /// Container left edge (content area start)
  container_left : Double
  /// Container height (inline-axis span in vertical writing)
  container_height : Double
  /// Container top edge (inline-axis start in vertical writing)
  container_top : Double
  /// Whether this float context is for vertical writing mode
  is_vertical : Bool
  /// Whether block flow runs from right to left (vertical-rl)
  block_rtl : Bool
  /// Whether line-left maps to the physical top side
  line_left_is_top : Bool
  /// All left floats currently in effect
  left_floats : Array[FloatBox]
  /// All right floats currently in effect
  right_floats : Array[FloatBox]
}

///|
/// Create a new float context
pub fn FloatContext::new(
  container_width : Double,
  container_left : Double,
) -> FloatContext {
  {
    container_width,
    container_left,
    container_height: 0.0,
    container_top: 0.0,
    is_vertical: false,
    block_rtl: false,
    line_left_is_top: true,
    left_floats: [],
    right_floats: [],
  }
}

///|
/// Create a float context for vertical writing mode.
pub fn FloatContext::new_vertical(
  container_width : Double,
  container_left : Double,
  container_height : Double,
  container_top : Double,
  block_rtl : Bool,
  line_left_is_top : Bool,
) -> FloatContext {
  {
    container_width,
    container_left,
    container_height,
    container_top,
    is_vertical: true,
    block_rtl,
    line_left_is_top,
    left_floats: [],
    right_floats: [],
  }
}

///|
fn FloatContext::float_block_start(
  self : FloatContext,
  float : FloatBox,
) -> Double {
  if self.is_vertical {
    if self.block_rtl {
      self.container_left + self.container_width - float.right()
    } else {
      float.x - self.container_left
    }
  } else {
    float.y
  }
}

///|
fn FloatContext::float_block_end(
  self : FloatContext,
  float : FloatBox,
) -> Double {
  let block_size = if self.is_vertical { float.width } else { float.height }
  self.float_block_start(float) + block_size
}

///|
fn FloatContext::float_main_start(
  self : FloatContext,
  float : FloatBox,
) -> Double {
  if self.is_vertical {
    float.y
  } else {
    float.x
  }
}

///|
fn FloatContext::float_main_end(
  self : FloatContext,
  float : FloatBox,
) -> Double {
  let main_size = if self.is_vertical { float.height } else { float.width }
  self.float_main_start(float) + main_size
}

///|
/// Get the clear Y position for a given clear type
/// Returns the Y position below all floats that need to be cleared
pub fn FloatContext::get_clear_y(
  self : FloatContext,
  clear : @types.Clear,
  current_y : Double,
) -> Double {
  let mut clear_y = current_y
  match clear {
    @types.Clear::Left | @types.Clear::Both =>
      // Find the bottom of all left floats
      for float in self.left_floats {
        let block_end = self.float_block_end(float)
        if block_end > clear_y {
          clear_y = block_end
        }
      }
    _ => ()
  }
  match clear {
    @types.Clear::Right | @types.Clear::Both =>
      // Find the bottom of all right floats
      for float in self.right_floats {
        let block_end = self.float_block_end(float)
        if block_end > clear_y {
          clear_y = block_end
        }
      }
    _ => ()
  }
  clear_y
}

///|
/// Get the available width at a given Y position
/// Returns (left_edge, right_edge) accounting for floats
pub fn FloatContext::get_available_space(
  self : FloatContext,
  y : Double,
  height : Double,
) -> (Double, Double) {
  let mut left_edge = if self.is_vertical {
    self.container_top
  } else {
    self.container_left
  }
  let mut right_edge = if self.is_vertical {
    self.container_top + self.container_height
  } else {
    self.container_left + self.container_width
  }

  // Check against left floats
  for float in self.left_floats {
    // Check if this float overlaps along the block-flow axis with the given region.
    if self.float_block_start(float) < y + height &&
      self.float_block_end(float) > y {
      if self.is_vertical {
        if self.line_left_is_top {
          let float_bottom = self.float_main_end(float)
          if float_bottom > left_edge {
            left_edge = float_bottom
          }
        } else {
          let float_top = self.float_main_start(float)
          if float_top < right_edge {
            right_edge = float_top
          }
        }
      } else if float.right() > left_edge {
        left_edge = float.right()
      }
    }
  }

  // Check against right floats
  for float in self.right_floats {
    if self.float_block_start(float) < y + height &&
      self.float_block_end(float) > y {
      if self.is_vertical {
        if self.line_left_is_top {
          let float_top = self.float_main_start(float)
          if float_top < right_edge {
            right_edge = float_top
          }
        } else {
          let float_bottom = self.float_main_end(float)
          if float_bottom > left_edge {
            left_edge = float_bottom
          }
        }
      } else if float.x < right_edge {
        right_edge = float.x
      }
    }
  }
  (left_edge, right_edge)
}

///|
/// Find the Y position where there's enough horizontal space for an element
/// Tries to find space between existing floats
pub fn FloatContext::find_y_with_space(
  self : FloatContext,
  start_y : Double,
  required_width : Double,
  element_height : Double,
) -> Double {
  // Collect all Y positions where float regions change
  let y_positions : Array[Double] = [start_y]
  for float in self.left_floats {
    let block_start = self.float_block_start(float)
    let block_end = self.float_block_end(float)
    if block_start > start_y {
      y_positions.push(block_start)
    }
    if block_end > start_y {
      y_positions.push(block_end)
    }
  }
  for float in self.right_floats {
    let block_start = self.float_block_start(float)
    let block_end = self.float_block_end(float)
    if block_start > start_y {
      y_positions.push(block_start)
    }
    if block_end > start_y {
      y_positions.push(block_end)
    }
  }

  // Sort Y positions
  y_positions.sort_by(fn(a, b) { a.compare(b) })

  // Try each Y position
  for test_y in y_positions {
    if test_y < start_y {
      continue
    }
    let (left_edge, right_edge) = self.get_available_space(
      test_y, element_height,
    )
    let available = right_edge - left_edge
    if available >= required_width {
      return test_y
    }
  }

  // If no space found, place below all floats
  let mut max_bottom = start_y
  for float in self.left_floats {
    let block_end = self.float_block_end(float)
    if block_end > max_bottom {
      max_bottom = block_end
    }
  }
  for float in self.right_floats {
    let block_end = self.float_block_end(float)
    if block_end > max_bottom {
      max_bottom = block_end
    }
  }
  max_bottom
}

///|
/// Place a float element and return its position
/// Returns (x, y) position for the float
pub fn FloatContext::place_float(
  self : FloatContext,
  float_type : @types.Float,
  width : Double,
  height : Double,
  margin_left : Double,
  margin_right : Double,
  margin_top : Double,
  margin_bottom : Double,
  current_y : Double,
) -> (Double, Double) {
  if self.is_vertical {
    let total_block_size = width + margin_left + margin_right
    let total_main_size = height + margin_top + margin_bottom
    let block_pos = self.find_y_with_space(
      current_y, total_main_size, total_block_size,
    )
    let (main_start, main_end) = self.get_available_space(
      block_pos, total_block_size,
    )
    let outer_main_pos = match float_type {
      @types.Float::Left =>
        if self.line_left_is_top {
          main_start
        } else {
          main_end - total_main_size
        }
      @types.Float::Right =>
        if self.line_left_is_top {
          main_end - total_main_size
        } else {
          main_start
        }
      @types.Float::None => main_start
    }
    let outer_x = if self.block_rtl {
      self.container_left + self.container_width - block_pos - total_block_size
    } else {
      self.container_left + block_pos
    }
    let float_box : FloatBox = {
      x: outer_x,
      y: outer_main_pos,
      width: total_block_size,
      height: total_main_size,
      float_type,
    }
    match float_type {
      @types.Float::Left => self.left_floats.push(float_box)
      @types.Float::Right => self.right_floats.push(float_box)
      @types.Float::None => ()
    }
    return (outer_x + margin_left, outer_main_pos + margin_top)
  }

  let total_width = width + margin_left + margin_right
  let total_height = height + margin_top + margin_bottom

  // Find Y position with enough space
  let y = self.find_y_with_space(current_y, total_width, total_height)
  let (left_edge, right_edge) = self.get_available_space(y, total_height)

  // Position based on float type
  let x = match float_type {
    @types.Float::Left => left_edge + margin_left
    @types.Float::Right => right_edge - width - margin_right
    @types.Float::None => left_edge + margin_left // Shouldn't happen
  }

  // Add to float list
  let float_box : FloatBox = {
    x: x - margin_left, // Store outer box position
    y,
    width: total_width,
    height: total_height,
    float_type,
  }
  match float_type {
    @types.Float::Left => self.left_floats.push(float_box)
    @types.Float::Right => self.right_floats.push(float_box)
    @types.Float::None => ()
  }
  (x, y + margin_top)
}

///|
/// Remove floats that are above a given Y position
/// Called when we've moved past floats
pub fn FloatContext::prune_floats_above(
  self : FloatContext,
  y : Double,
) -> Unit {
  // Keep only floats that extend below y
  let new_left : Array[FloatBox] = []
  for float in self.left_floats {
    if self.float_block_end(float) > y {
      new_left.push(float)
    }
  }
  self.left_floats.clear()
  for float in new_left {
    self.left_floats.push(float)
  }
  let new_right : Array[FloatBox] = []
  for float in self.right_floats {
    if self.float_block_end(float) > y {
      new_right.push(float)
    }
  }
  self.right_floats.clear()
  for float in new_right {
    self.right_floats.push(float)
  }
}

///|
/// Get the height contribution from floats (for parent sizing)
/// Returns the maximum bottom of all floats
pub fn FloatContext::get_float_height(self : FloatContext) -> Double {
  let mut max_bottom = 0.0
  for float in self.left_floats {
    let block_end = self.float_block_end(float)
    if block_end > max_bottom {
      max_bottom = block_end
    }
  }
  for float in self.right_floats {
    let block_end = self.float_block_end(float)
    if block_end > max_bottom {
      max_bottom = block_end
    }
  }
  max_bottom
}

///|
/// Check if there are any active floats
pub fn FloatContext::has_floats(self : FloatContext) -> Bool {
  self.left_floats.length() > 0 || self.right_floats.length() > 0
}
