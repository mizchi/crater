///|
/// CSS clip-path scalar value resolution helpers for TUI rendering.

///|
fn resolve_clip_path_position(value : Double, size : Double) -> Double {
  if value < 0.0 {
    -value * size
  } else {
    value
  }
}

///|
fn resolve_clip_path_axis_radius(value : Double, size : Double) -> Double {
  let raw = if value < 0.0 { -value * size } else { value }
  if raw <= 0.0 {
    0.0
  } else {
    raw
  }
}

///|
fn resolve_clip_path_radius(
  value : Double,
  width : Double,
  height : Double,
) -> Double {
  let reference = min_double(width, height)
  let raw = if value < 0.0 { -value * reference } else { value }
  if raw <= 0.0 {
    0.0
  } else {
    raw
  }
}

///|
fn resolve_clip_path_inset(value : Double, size : Double) -> Double {
  let raw = if value < 0.0 { -value * size } else { value }
  if raw <= 0.0 {
    0.0
  } else if raw > size {
    size
  } else {
    raw
  }
}
