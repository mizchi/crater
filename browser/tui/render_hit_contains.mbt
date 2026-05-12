///|
/// Hit-test containment and cell coverage sampling.

///|
fn HitRegion::contains_pixel(
  self : HitRegion,
  pixel_x : Double,
  pixel_y : Double,
) -> Bool {
  pixel_x >= self.pixel_x &&
  pixel_x < self.pixel_x + self.pixel_width &&
  pixel_y >= self.pixel_y &&
  pixel_y < self.pixel_y + self.pixel_height &&
  point_in_rounded_rect(
    pixel_x,
    pixel_y,
    self.shape_x,
    self.shape_y,
    self.shape_width,
    self.shape_height,
    self.radius_top_left,
    self.radius_top_right,
    self.radius_bottom_right,
    self.radius_bottom_left,
  ) &&
  point_in_hit_clip_shape(pixel_x, pixel_y, self.visual_shape) &&
  point_in_hit_clip_shape(pixel_x, pixel_y, self.clip_shape)
}

///|
fn HitRegion::has_cell_coverage(self : HitRegion, col : Int, row : Int) -> Bool {
  if !self.allows_cell_coverage_sampling() {
    return false
  }
  let cell_x = col.to_double() * font_width
  let cell_y = (row + self.scroll_y).to_double() * font_height
  let overlap_left = max_double(cell_x, self.pixel_x)
  let overlap_top = max_double(cell_y, self.pixel_y)
  let overlap_right = min_double(
    cell_x + font_width,
    self.pixel_x + self.pixel_width,
  )
  let overlap_bottom = min_double(
    cell_y + font_height,
    self.pixel_y + self.pixel_height,
  )
  if overlap_right <= overlap_left || overlap_bottom <= overlap_top {
    return false
  }
  let samples_per_axis = 4
  let required_hits = 4
  let step_x = font_width / samples_per_axis.to_double()
  let step_y = font_height / samples_per_axis.to_double()
  let mut hits = 0
  for y in 0..<samples_per_axis {
    let sample_y = cell_y + (y.to_double() + 0.5) * step_y
    for x in 0..<samples_per_axis {
      let sample_x = cell_x + (x.to_double() + 0.5) * step_x
      if self.contains_pixel(sample_x, sample_y) {
        hits += 1
        if hits >= required_hits {
          return true
        }
      }
    }
  }
  false
}

///|
fn HitRegion::allows_cell_coverage_sampling(self : HitRegion) -> Bool {
  self.radius_top_left == 0.0 &&
  self.radius_top_right == 0.0 &&
  self.radius_bottom_right == 0.0 &&
  self.radius_bottom_left == 0.0 &&
  self.visual_shape == HitClipShape::Rect
}

///|
pub fn HitRegion::contains(self : HitRegion, col : Int, row : Int) -> Bool {
  let pixel_x = col.to_double() * font_width + font_width / 2.0
  let pixel_y = (row + self.scroll_y).to_double() * font_height +
    font_height / 2.0
  if self.contains_pixel(pixel_x, pixel_y) {
    return true
  }
  self.has_cell_coverage(col, row)
}
