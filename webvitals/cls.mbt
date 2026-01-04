///|
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Result of CLS calculation
pub struct LayoutShift {
  impact_fraction : Double // 衝撃率: affected viewport fraction
  distance_fraction : Double // 距離率: movement relative to viewport
  score : Double // impact_fraction × distance_fraction
}

///|
pub impl Show for LayoutShift with output(self, logger) {
  logger.write_string("LayoutShift { impact: ")
  self.impact_fraction.output(logger)
  logger.write_string(", distance: ")
  self.distance_fraction.output(logger)
  logger.write_string(", score: ")
  self.score.output(logger)
  logger.write_string(" }")
}

///|
/// Calculate layout shift between two bounding rects
/// viewport: the viewport size for normalization
pub fn compute_element_shift(
  before : @types.BoundingRect,
  after : @types.BoundingRect,
  viewport : @types.Size[Double],
) -> LayoutShift {
  let viewport_area = viewport.width * viewport.height

  // Impact fraction: union of before and after areas / viewport area
  let union_rect = before.union(after)
  let impact_fraction = union_rect.area() / viewport_area

  // Distance fraction: max movement / max viewport dimension
  let dx = (after.x - before.x).abs()
  let dy = (after.y - before.y).abs()
  let max_distance = max(dx, dy)
  let max_viewport_dim = max(viewport.width, viewport.height)
  let distance_fraction = max_distance / max_viewport_dim
  let score = impact_fraction * distance_fraction
  { impact_fraction, distance_fraction, score }
}

///|
/// Calculate total CLS score for multiple elements
pub fn compute_total(
  before : Array[@types.BoundingRect],
  after : Array[@types.BoundingRect],
  viewport : @types.Size[Double],
) -> Double {
  let len = min_int(before.length(), after.length())
  let mut total = 0.0
  for i = 0; i < len; i = i + 1 {
    let shift = compute_element_shift(before[i], after[i], viewport)
    total = total + shift.score
  }
  total
}
