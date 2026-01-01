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
  float_type : @style.Float
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
  /// All left floats currently in effect
  left_floats : Array[FloatBox]
  /// All right floats currently in effect
  right_floats : Array[FloatBox]
}

///|
/// Create a new float context
pub fn FloatContext::new(container_width : Double, container_left : Double) -> FloatContext {
  {
    container_width,
    container_left,
    left_floats: [],
    right_floats: [],
  }
}

///|
/// Get the clear Y position for a given clear type
/// Returns the Y position below all floats that need to be cleared
pub fn FloatContext::get_clear_y(self : FloatContext, clear : @style.Clear, current_y : Double) -> Double {
  let mut clear_y = current_y

  match clear {
    @style.Clear::Left | @style.Clear::Both => {
      // Find the bottom of all left floats
      for float in self.left_floats {
        if float.bottom() > clear_y {
          clear_y = float.bottom()
        }
      }
    }
    _ => ()
  }

  match clear {
    @style.Clear::Right | @style.Clear::Both => {
      // Find the bottom of all right floats
      for float in self.right_floats {
        if float.bottom() > clear_y {
          clear_y = float.bottom()
        }
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
  height : Double
) -> (Double, Double) {
  let mut left_edge = self.container_left
  let mut right_edge = self.container_left + self.container_width

  // Check against left floats
  for float in self.left_floats {
    // Check if this float overlaps vertically with the given region
    if float.y < y + height && float.bottom() > y {
      // Float overlaps, push left edge to the right
      if float.right() > left_edge {
        left_edge = float.right()
      }
    }
  }

  // Check against right floats
  for float in self.right_floats {
    if float.y < y + height && float.bottom() > y {
      // Float overlaps, push right edge to the left
      if float.x < right_edge {
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
  element_height : Double
) -> Double {
  // Collect all Y positions where float regions change
  let y_positions : Array[Double] = [start_y]
  for float in self.left_floats {
    if float.y > start_y {
      y_positions.push(float.y)
    }
    if float.bottom() > start_y {
      y_positions.push(float.bottom())
    }
  }
  for float in self.right_floats {
    if float.y > start_y {
      y_positions.push(float.y)
    }
    if float.bottom() > start_y {
      y_positions.push(float.bottom())
    }
  }

  // Sort Y positions
  y_positions.sort_by(fn(a, b) { a.compare(b) })

  // Try each Y position
  for test_y in y_positions {
    if test_y < start_y {
      continue
    }
    let (left_edge, right_edge) = self.get_available_space(test_y, element_height)
    let available = right_edge - left_edge
    if available >= required_width {
      return test_y
    }
  }

  // If no space found, place below all floats
  let mut max_bottom = start_y
  for float in self.left_floats {
    if float.bottom() > max_bottom {
      max_bottom = float.bottom()
    }
  }
  for float in self.right_floats {
    if float.bottom() > max_bottom {
      max_bottom = float.bottom()
    }
  }

  max_bottom
}

///|
/// Place a float element and return its position
/// Returns (x, y) position for the float
pub fn FloatContext::place_float(
  self : FloatContext,
  float_type : @style.Float,
  width : Double,
  height : Double,
  margin_left : Double,
  margin_right : Double,
  margin_top : Double,
  margin_bottom : Double,
  current_y : Double
) -> (Double, Double) {
  let total_width = width + margin_left + margin_right
  let total_height = height + margin_top + margin_bottom

  // Find Y position with enough space
  let y = self.find_y_with_space(current_y, total_width, total_height)
  let (left_edge, right_edge) = self.get_available_space(y, total_height)

  // Position based on float type
  let x = match float_type {
    @style.Float::Left => left_edge + margin_left
    @style.Float::Right => right_edge - width - margin_right
    @style.Float::None => left_edge + margin_left // Shouldn't happen
  }

  // Add to float list
  let float_box : FloatBox = {
    x: x - margin_left,  // Store outer box position
    y,
    width: total_width,
    height: total_height,
    float_type,
  }

  match float_type {
    @style.Float::Left => self.left_floats.push(float_box)
    @style.Float::Right => self.right_floats.push(float_box)
    @style.Float::None => ()
  }

  (x, y + margin_top)
}

///|
/// Remove floats that are above a given Y position
/// Called when we've moved past floats
pub fn FloatContext::prune_floats_above(self : FloatContext, y : Double) -> Unit {
  // Keep only floats that extend below y
  let new_left : Array[FloatBox] = []
  for float in self.left_floats {
    if float.bottom() > y {
      new_left.push(float)
    }
  }
  self.left_floats.clear()
  for float in new_left {
    self.left_floats.push(float)
  }

  let new_right : Array[FloatBox] = []
  for float in self.right_floats {
    if float.bottom() > y {
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
    if float.bottom() > max_bottom {
      max_bottom = float.bottom()
    }
  }
  for float in self.right_floats {
    if float.bottom() > max_bottom {
      max_bottom = float.bottom()
    }
  }
  max_bottom
}

///|
/// Check if there are any active floats
pub fn FloatContext::has_floats(self : FloatContext) -> Bool {
  self.left_floats.length() > 0 || self.right_floats.length() > 0
}
