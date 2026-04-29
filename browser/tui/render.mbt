///|
/// TUI Rendering - Convert PaintNode tree to CharBuffer
/// Implements pixel-to-character coordinate transformation

///|
/// Font metrics for coordinate conversion
let font_width : Double = 8.0

///|
let font_height : Double = 16.0

///|
/// Convert pixel X to character column (truncates for position)
pub fn px_to_col(px : Double) -> Int {
  (px / font_width).to_int()
}

///|
/// Convert pixel width to character width (rounds up to ensure content fits)
fn px_to_col_width(px : Double) -> Int {
  let result = px / font_width
  let int_part = result.to_int()
  if result > int_part.to_double() {
    int_part + 1
  } else {
    int_part
  }
}

///|
/// Convert pixel Y to character row
pub fn px_to_row(px : Double) -> Int {
  (px / font_height).to_int()
}

///|
/// Convert pixel height to character height (rounds up)
fn px_to_row_height(px : Double) -> Int {
  let result = px / font_height
  let int_part = result.to_int()
  if result > int_part.to_double() {
    int_part + 1
  } else {
    int_part
  }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn intersect_pixel_rects(
  a : (Double, Double, Double, Double),
  b : (Double, Double, Double, Double),
) -> (Double, Double, Double, Double)? {
  let (ax, ay, aw, ah) = a
  let (bx, by, bw, bh) = b
  let left = max_double(ax, bx)
  let top = max_double(ay, by)
  let right = min_double(ax + aw, bx + bw)
  let bottom = min_double(ay + ah, by + bh)
  if right <= left || bottom <= top {
    None
  } else {
    Some((left, top, right - left, bottom - top))
  }
}

///|
fn get_local_clip_rect(
  node : @tui_paint_runtime.PaintNode,
  abs_x : Double,
  abs_y : Double,
) -> (Double, Double, Double, Double)? {
  let legacy_clip = match node.clip {
    @types.ClipRect::Rect(top~, right~, bottom~, left~) =>
      Some((abs_x + left, abs_y + top, right - left, bottom - top))
    @types.ClipRect::Auto =>
      match (node.overflow_x, node.overflow_y) {
        (@types.Visible, @types.Visible) => None
        _ => Some((abs_x, abs_y, node.width, node.height))
      }
  }
  let clip_path = match node.paint.clip_path {
    @style.ClipPath::None => None
    @style.ClipPath::Inset(top, right, bottom, left) => {
      let inset_top = resolve_clip_path_inset(top, node.height)
      let inset_right = resolve_clip_path_inset(right, node.width)
      let inset_bottom = resolve_clip_path_inset(bottom, node.height)
      let inset_left = resolve_clip_path_inset(left, node.width)
      let clip_left = abs_x + inset_left
      let clip_top = abs_y + inset_top
      let clip_right = abs_x + node.width - inset_right
      let clip_bottom = abs_y + node.height - inset_bottom
      if clip_right <= clip_left || clip_bottom <= clip_top {
        None
      } else {
        Some(
          (clip_left, clip_top, clip_right - clip_left, clip_bottom - clip_top),
        )
      }
    }
    @style.ClipPath::Rect(top, right, bottom, left) =>
      resolve_clip_path_rect(
        top,
        right,
        bottom,
        left,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
    @style.ClipPath::Xywh(x, y, width, height) =>
      resolve_clip_path_xywh(
        x,
        y,
        width,
        height,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
    @style.ClipPath::Circle(radius, center_x, center_y) => {
      let (cx, cy, r) = resolve_clip_path_circle(
        radius,
        center_x,
        center_y,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
      if r <= 0.0 {
        None
      } else {
        Some((cx - r, cy - r, r * 2.0, r * 2.0))
      }
    }
    @style.ClipPath::Ellipse(radius_x, radius_y, center_x, center_y) => {
      let (cx, cy, rx, ry) = resolve_clip_path_ellipse(
        radius_x,
        radius_y,
        center_x,
        center_y,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
      if rx <= 0.0 || ry <= 0.0 {
        None
      } else {
        Some((cx - rx, cy - ry, rx * 2.0, ry * 2.0))
      }
    }
    @style.ClipPath::Polygon(points) => {
      let resolved = resolve_clip_path_polygon(
        points,
        abs_x,
        abs_y,
        node.width,
        node.height,
      )
      polygon_bounding_rect(resolved)
    }
  }
  match (legacy_clip, clip_path) {
    (Some(a), Some(b)) => intersect_pixel_rects(a, b)
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
}

///|
fn combine_clip_rects(
  inherited : (Double, Double, Double, Double)?,
  local_clip : (Double, Double, Double, Double)?,
) -> (Double, Double, Double, Double)? {
  match (inherited, local_clip) {
    (Some(a), Some(b)) => intersect_pixel_rects(a, b)
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
}

///|
fn polygon_bounding_rect(
  points : Array[(Double, Double)],
) -> (Double, Double, Double, Double)? {
  if points.length() < 3 {
    return None
  }
  let (first_x, first_y) = points[0]
  let mut min_x = first_x
  let mut max_x = first_x
  let mut min_y = first_y
  let mut max_y = first_y
  for i in 1..<points.length() {
    let (x, y) = points[i]
    min_x = min_double(min_x, x)
    max_x = max_double(max_x, x)
    min_y = min_double(min_y, y)
    max_y = max_double(max_y, y)
  }
  if max_x <= min_x || max_y <= min_y {
    None
  } else {
    Some((min_x, min_y, max_x - min_x, max_y - min_y))
  }
}

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
fn resolve_clip_path_polygon(
  points : Array[(Double, Double)],
  abs_x : Double,
  abs_y : Double,
  width : Double,
  height : Double,
) -> Array[(Double, Double)] {
  let resolved : Array[(Double, Double)] = []
  for point in points {
    let (x, y) = point
    resolved.push(
      (
        abs_x + resolve_clip_path_position(x, width),
        abs_y + resolve_clip_path_position(y, height),
      ),
    )
  }
  resolved
}

///|
fn resolve_clip_path_ellipse(
  radius_x : Double,
  radius_y : Double,
  center_x : Double,
  center_y : Double,
  abs_x : Double,
  abs_y : Double,
  width : Double,
  height : Double,
) -> (Double, Double, Double, Double) {
  (
    abs_x + resolve_clip_path_position(center_x, width),
    abs_y + resolve_clip_path_position(center_y, height),
    resolve_clip_path_axis_radius(radius_x, width),
    resolve_clip_path_axis_radius(radius_y, height),
  )
}

///|
fn resolve_clip_path_circle(
  radius : Double,
  center_x : Double,
  center_y : Double,
  abs_x : Double,
  abs_y : Double,
  width : Double,
  height : Double,
) -> (Double, Double, Double) {
  (
    abs_x + resolve_clip_path_position(center_x, width),
    abs_y + resolve_clip_path_position(center_y, height),
    resolve_clip_path_radius(radius, width, height),
  )
}

///|
fn resolve_clip_path_rect(
  top : Double,
  right : Double,
  bottom : Double,
  left : Double,
  abs_x : Double,
  abs_y : Double,
  width : Double,
  height : Double,
) -> (Double, Double, Double, Double)? {
  let clip_top = abs_y + resolve_clip_path_position(top, height)
  let clip_right = abs_x + resolve_clip_path_position(right, width)
  let clip_bottom = abs_y + resolve_clip_path_position(bottom, height)
  let clip_left = abs_x + resolve_clip_path_position(left, width)
  if clip_right <= clip_left || clip_bottom <= clip_top {
    None
  } else {
    Some((clip_left, clip_top, clip_right - clip_left, clip_bottom - clip_top))
  }
}

///|
fn resolve_clip_path_xywh(
  x : Double,
  y : Double,
  clip_width : Double,
  clip_height : Double,
  abs_x : Double,
  abs_y : Double,
  width : Double,
  height : Double,
) -> (Double, Double, Double, Double)? {
  let clip_left = abs_x + resolve_clip_path_position(x, width)
  let clip_top = abs_y + resolve_clip_path_position(y, height)
  let resolved_width = resolve_clip_path_axis_radius(clip_width, width)
  let resolved_height = resolve_clip_path_axis_radius(clip_height, height)
  if resolved_width <= 0.0 || resolved_height <= 0.0 {
    None
  } else {
    Some((clip_left, clip_top, resolved_width, resolved_height))
  }
}

///|
fn resolve_visual_polygon(
  points : Array[(Double, Double)],
  abs_x : Double,
  abs_y : Double,
) -> Array[(Double, Double)] {
  let resolved : Array[(Double, Double)] = []
  for point in points {
    let (x, y) = point
    resolved.push((abs_x + x, abs_y + y))
  }
  resolved
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

///|
fn resolve_hit_radius(
  value : Double,
  width : Double,
  height : Double,
) -> Double {
  let reference = min_double(width, height)
  let raw = if value < 0.0 { -value * reference } else { value }
  let max_radius = reference / 2.0
  if raw <= 0.0 {
    0.0
  } else if raw > max_radius {
    max_radius
  } else {
    raw
  }
}

///|
/// Convert dirty rects in pixel coordinates to character grid rectangles
pub fn dirty_rects_to_cells(
  rects : Array[@types.BoundingRect],
  scroll_y_px : Int,
  viewport_cols : Int,
  viewport_rows : Int,
  row_offset : Int,
) -> Array[DirtyRect] {
  let result : Array[DirtyRect] = []
  let view_left = 0.0
  let view_right = viewport_cols.to_double() * font_width
  let view_top = scroll_y_px.to_double()
  let view_bottom = view_top + viewport_rows.to_double() * font_height
  for rect in rects {
    let x0 = max_double(rect.x, view_left)
    let y0 = max_double(rect.y, view_top)
    let x1 = min_double(rect.x + rect.width, view_right)
    let y1 = min_double(rect.y + rect.height, view_bottom)
    if x1 <= x0 || y1 <= y0 {
      continue
    }
    let col = px_to_col(x0)
    let row = px_to_row(y0 - view_top) + row_offset
    let w = px_to_col_width(x1 - x0)
    let h = px_to_row_height(y1 - y0)
    if w <= 0 || h <= 0 {
      continue
    }
    result.push({ col, row, width: w, height: h })
  }
  result
}

///|
/// A clickable link region on screen
pub(all) struct LinkRegion {
  col : Int // Start column
  row : Int // Start row
  width : Int // Width in characters
  height : Int // Height in characters
  text : String // Link text (used to match with Browser.links for href)
  source_id : String // Source element id for DOM event dispatch
}

///|
pub(all) struct HitRegion {
  col : Int
  row : Int
  width : Int
  height : Int
  pixel_x : Double
  pixel_y : Double
  pixel_width : Double
  pixel_height : Double
  shape_x : Double
  shape_y : Double
  shape_width : Double
  shape_height : Double
  radius_top_left : Double
  radius_top_right : Double
  radius_bottom_right : Double
  radius_bottom_left : Double
  scroll_y : Int
  visual_shape : HitClipShape
  clip_shape : HitClipShape
  source_id : String
}

///|
pub(all) enum HitClipShape {
  Rect
  Circle(Double, Double, Double) // center-x, center-y, radius
  Ellipse(Double, Double, Double, Double) // center-x, center-y, radius-x, radius-y
  Polygon(Array[(Double, Double)])
} derive(Debug, Eq)

///|
fn point_in_rounded_corner(
  pixel_x : Double,
  pixel_y : Double,
  center_x : Double,
  center_y : Double,
  radius : Double,
) -> Bool {
  let dx = pixel_x - center_x
  let dy = pixel_y - center_y
  dx * dx + dy * dy <= radius * radius
}

///|
fn point_in_rounded_rect(
  pixel_x : Double,
  pixel_y : Double,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius_top_left : Double,
  radius_top_right : Double,
  radius_bottom_right : Double,
  radius_bottom_left : Double,
) -> Bool {
  if pixel_x < x || pixel_x >= x + width || pixel_y < y || pixel_y >= y + height {
    return false
  }
  if radius_top_left > 0.0 &&
    pixel_x < x + radius_top_left &&
    pixel_y < y + radius_top_left {
    return point_in_rounded_corner(
      pixel_x,
      pixel_y,
      x + radius_top_left,
      y + radius_top_left,
      radius_top_left,
    )
  }
  if radius_top_right > 0.0 &&
    pixel_x >= x + width - radius_top_right &&
    pixel_y < y + radius_top_right {
    return point_in_rounded_corner(
      pixel_x,
      pixel_y,
      x + width - radius_top_right,
      y + radius_top_right,
      radius_top_right,
    )
  }
  if radius_bottom_right > 0.0 &&
    pixel_x >= x + width - radius_bottom_right &&
    pixel_y >= y + height - radius_bottom_right {
    return point_in_rounded_corner(
      pixel_x,
      pixel_y,
      x + width - radius_bottom_right,
      y + height - radius_bottom_right,
      radius_bottom_right,
    )
  }
  if radius_bottom_left > 0.0 &&
    pixel_x < x + radius_bottom_left &&
    pixel_y >= y + height - radius_bottom_left {
    return point_in_rounded_corner(
      pixel_x,
      pixel_y,
      x + radius_bottom_left,
      y + height - radius_bottom_left,
      radius_bottom_left,
    )
  }
  true
}

///|
fn point_in_hit_clip_shape(
  pixel_x : Double,
  pixel_y : Double,
  shape : HitClipShape,
) -> Bool {
  match shape {
    Rect => true
    Circle(cx, cy, r) => {
      let dx = pixel_x - cx
      let dy = pixel_y - cy
      dx * dx + dy * dy <= r * r
    }
    Ellipse(cx, cy, rx, ry) =>
      if rx <= 0.0 || ry <= 0.0 {
        false
      } else {
        let dx = pixel_x - cx
        let dy = pixel_y - cy
        dx * dx / (rx * rx) + dy * dy / (ry * ry) <= 1.0
      }
    Polygon(points) => point_in_polygon(pixel_x, pixel_y, points)
  }
}

///|
fn point_in_polygon(
  pixel_x : Double,
  pixel_y : Double,
  points : Array[(Double, Double)],
) -> Bool {
  if points.length() < 3 {
    return false
  }
  let mut inside = false
  let mut j = points.length() - 1
  for i in 0..<points.length() {
    let (xi, yi) = points[i]
    let (xj, yj) = points[j]
    if (yi > pixel_y) != (yj > pixel_y) {
      let intersect_x = (xj - xi) * (pixel_y - yi) / (yj - yi) + xi
      if pixel_x < intersect_x {
        inside = !inside
      }
    }
    j = i
  }
  inside
}

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

///|
pub fn find_hit_region_at(
  regions : Array[HitRegion],
  col : Int,
  row : Int,
) -> HitRegion? {
  if regions.is_empty() {
    return None
  }
  let mut i = regions.length() - 1
  while i >= 0 {
    let region = regions[i]
    if region.contains(col, row) {
      return Some(region)
    }
    i = i - 1
  }
  None
}

///|
fn extract_source_id(node_id : String) -> String? {
  match node_id.find("#") {
    Some(idx) =>
      if idx + 1 < node_id.length() {
        Some(node_id.unsafe_substring(start=idx + 1, end=node_id.length()))
      } else {
        None
      }
    None => None
  }
}

///|
/// Hint data for hit-a-hint feature
pub(all) struct HintData {
  label : String // The hint label (e.g., "a", "b", "aa")
  href : String // Link URL
  text : String // Link text
  col : Int // Screen column position
  row : Int // Screen row position
}

///|
/// Check if a point is inside this link region
pub fn LinkRegion::contains(self : LinkRegion, col : Int, row : Int) -> Bool {
  col >= self.col &&
  col < self.col + self.width &&
  row >= self.row &&
  row < self.row + self.height
}

///|
/// Find link at given screen coordinates
pub fn find_link_at(
  regions : Array[LinkRegion],
  col : Int,
  row : Int,
) -> String? {
  match find_link_region_at(regions, col, row) {
    Some(region) => Some(region.text)
    None => None
  }
}

///|
/// Find link region at given screen coordinates
pub fn find_link_region_at(
  regions : Array[LinkRegion],
  col : Int,
  row : Int,
) -> LinkRegion? {
  for region in regions {
    if region.contains(col, row) {
      return Some(region)
    }
  }
  None
}

///|
/// Element scroll position (used for element-level scrollbar rendering)
pub(all) struct ElementScrollPos {
  scroll_top : Double
  scroll_height : Double
  client_height : Double
}

///|
/// Rendering context for TUI
pub struct TuiContext {
  buffer : CharBuffer
  scroll_y : Int // Scroll offset in character rows
  viewport_height : Int // Visible height in character rows
  link_regions : Array[LinkRegion] // Collected link regions
  hit_regions : Array[HitRegion] // Paint-order hit regions
  image_regions : Array[ImageRegion] // Collected image regions for graphics protocol
  focused_element_name : String? // Name of currently focused element (for :focus styling)
  dark_mode : Bool // Dark mode enabled
  element_scroll_positions : Map[String, ElementScrollPos] // Element-level scroll positions
}

///|
/// Render a PaintNode to the CharBuffer
fn render_paint_node(
  ctx : TuiContext,
  node : @tui_paint_runtime.PaintNode,
  parent_x : Double,
  parent_y : Double,
  inside_link : Bool,
  current_link_source_id? : String? = None,
  inside_pre? : Bool = false,
  clip_rect? : (Double, Double, Double, Double)? = None,
) -> Unit {
  // Skip invisible nodes
  if !node.paint.should_render() {
    return
  }
  // Calculate absolute position
  let abs_x = parent_x + node.x
  let abs_y = parent_y + node.y
  // Convert to character coordinates
  let col = px_to_col(abs_x)
  let row = px_to_row(abs_y) - ctx.scroll_y
  // Use ceiling for width and height to ensure text content fits
  let w = px_to_col_width(node.width)
  let h = px_to_row_height(node.height)
  let node_rect = (abs_x, abs_y, node.width, node.height)
  let effective_clip = combine_clip_rects(
    clip_rect,
    get_local_clip_rect(node, abs_x, abs_y),
  )
  let visible_rect = match effective_clip {
    Some(clip) => intersect_pixel_rects(node_rect, clip)
    None => Some(node_rect)
  }
  // Check if we're inside a pre/code element (no text wrapping)
  // Also disable wrapping inside table cells (th/td) - cells should clip, not wrap
  let is_pre = node.tag == "pre" || node.tag == "code"
  let is_table_cell = node.tag == "th" || node.tag == "td"
  let child_inside_pre = inside_pre || is_pre || is_table_cell
  let child_link_source_id = if node.tag == "a" &&
    node.paint.pointer_events != @style.PointerEvents::None {
    extract_source_id(node.id)
  } else {
    current_link_source_id
  }
  // Skip if completely outside viewport
  if row + h < 0 || row >= ctx.viewport_height {
    // Still need to render children that might be visible
    let child_inside_link = inside_link || node.tag == "a"
    for child in node.children {
      render_paint_node(
        ctx,
        child,
        abs_x,
        abs_y,
        child_inside_link,
        current_link_source_id=child_link_source_id,
        inside_pre=child_inside_pre,
        clip_rect=effective_clip,
      )
    }
    return
  }
  // Skip zero-sized nodes
  if w <= 0 || h <= 0 {
    let child_inside_link = inside_link || node.tag == "a"
    for child in node.children {
      render_paint_node(
        ctx,
        child,
        abs_x,
        abs_y,
        child_inside_link,
        current_link_source_id=child_link_source_id,
        inside_pre=child_inside_pre,
        clip_rect=effective_clip,
      )
    }
    return
  }
  match (extract_source_id(node.id), visible_rect) {
    (Some(source_id), Some((visible_x, visible_y, visible_w, visible_h))) =>
      if node.tag != "#text" &&
        node.paint.pointer_events != @style.PointerEvents::None &&
        visible_w > 0.0 &&
        visible_h > 0.0 {
        let radius_top_left = resolve_hit_radius(
          node.paint.border_top_left_radius,
          node.width,
          node.height,
        )
        let radius_top_right = resolve_hit_radius(
          node.paint.border_top_right_radius,
          node.width,
          node.height,
        )
        let radius_bottom_right = resolve_hit_radius(
          node.paint.border_bottom_right_radius,
          node.width,
          node.height,
        )
        let radius_bottom_left = resolve_hit_radius(
          node.paint.border_bottom_left_radius,
          node.width,
          node.height,
        )
        let visual_shape = if node.visual_polygon.is_empty() {
          HitClipShape::Rect
        } else {
          HitClipShape::Polygon(
            resolve_visual_polygon(node.visual_polygon, abs_x, abs_y),
          )
        }
        let clip_shape = match node.paint.clip_path {
          @style.ClipPath::Circle(radius, center_x, center_y) => {
            let (cx, cy, r) = resolve_clip_path_circle(
              radius,
              center_x,
              center_y,
              abs_x,
              abs_y,
              node.width,
              node.height,
            )
            HitClipShape::Circle(cx, cy, r)
          }
          @style.ClipPath::Ellipse(radius_x, radius_y, center_x, center_y) => {
            let (cx, cy, rx, ry) = resolve_clip_path_ellipse(
              radius_x,
              radius_y,
              center_x,
              center_y,
              abs_x,
              abs_y,
              node.width,
              node.height,
            )
            HitClipShape::Ellipse(cx, cy, rx, ry)
          }
          @style.ClipPath::Polygon(points) =>
            HitClipShape::Polygon(
              resolve_clip_path_polygon(
                points,
                abs_x,
                abs_y,
                node.width,
                node.height,
              ),
            )
          _ => HitClipShape::Rect
        }
        ctx.hit_regions.push({
          col: px_to_col(visible_x),
          row: px_to_row(visible_y) - ctx.scroll_y,
          width: px_to_col_width(visible_w),
          height: px_to_row_height(visible_h),
          pixel_x: visible_x,
          pixel_y: visible_y,
          pixel_width: visible_w,
          pixel_height: visible_h,
          shape_x: abs_x,
          shape_y: abs_y,
          shape_width: node.width,
          shape_height: node.height,
          radius_top_left,
          radius_top_right,
          radius_bottom_right,
          radius_bottom_left,
          scroll_y: ctx.scroll_y,
          visual_shape,
          clip_shape,
          source_id,
        })
      }
    _ => ()
  }
  // Draw background if not transparent
  if !node.paint.background_color.is_transparent() {
    // Clip to viewport
    let draw_row = row.max(0)
    let draw_h = (row + h).min(ctx.viewport_height) - draw_row
    if draw_h > 0 {
      // Use CSS-computed color directly (dark mode is handled by CSS cascade)
      ctx.buffer.fill_bg(col, draw_row, w, draw_h, node.paint.background_color)
    }
  }
  // Handle image placeholder (check BEFORE text to ensure background is drawn)
  if node.tag == "img" && w > 0 && h > 0 {
    let draw_row = row.max(0)
    let draw_h = (row + h).min(ctx.viewport_height) - draw_row
    // If image has src, record for graphics protocol rendering
    match node.src {
      Some(src) =>
        if draw_h > 0 {
          let source_id = match extract_source_id(node.id) {
            Some(id) => id
            None => node.id
          }
          // Fill background color (from CSS) so it shows even without graphics
          if !node.paint.background_color.is_transparent() {
            ctx.buffer.fill_bg(
              col,
              draw_row,
              w,
              draw_h,
              node.paint.background_color,
            )
          }
          // Record image region for kitty/sixel rendering
          ctx.image_regions.push({
            col,
            row: draw_row,
            width: w,
            height: draw_h,
            pixel_width: node.width,
            pixel_height: node.height,
            src,
            source_id,
          })
        }
      None => {
        // No src: show placeholder
        let img_bg = @types.Color::rgb(200, 200, 210)
        let border_color = @types.Color::rgb(150, 150, 160)
        if draw_h > 0 {
          ctx.buffer.fill_bg(col, draw_row, w, draw_h, img_bg)
          let border_style : TextStyle = {
            fg: border_color,
            bg: img_bg,
            bold: false,
            underline: false,
          }
          if draw_row >= 0 && draw_row < ctx.viewport_height {
            let border_line = String::make(w, '-')
            let _ = ctx.buffer.write_text(
              col, draw_row, border_line, border_style, w,
            )
          }
          let bottom_row = draw_row + draw_h - 1
          if bottom_row >= 0 &&
            bottom_row < ctx.viewport_height &&
            bottom_row > draw_row {
            let border_line = String::make(w, '-')
            let _ = ctx.buffer.write_text(
              col, bottom_row, border_line, border_style, w,
            )
          }
        }
        // Draw alt text (or "[IMG]" if no alt) centered
        if draw_row >= 0 && draw_row < ctx.viewport_height && draw_h > 0 {
          let label = match node.text {
            Some(alt) => if alt.length() > 0 { alt } else { "[IMG]" }
            None => "[IMG]"
          }
          let label_style : TextStyle = {
            fg: @types.Color::rgb(60, 60, 70),
            bg: img_bg,
            bold: false,
            underline: false,
          }
          let center_row = draw_row + draw_h / 2
          if center_row >= 0 && center_row < ctx.viewport_height {
            let max_label_width = w - 2
            let visible_label = if label.to_array().length() > max_label_width &&
              max_label_width > 3 {
              let chars = label.to_array()
              let truncated_chars = chars[:max_label_width - 3]
              truncated_chars.to_string() + "..."
            } else {
              label
            }
            let label_len = visible_label.to_array().length()
            let label_col = col + (w - label_len) / 2
            if label_col >= 0 {
              let _ = ctx.buffer.write_text(
                label_col.max(col),
                center_row,
                visible_label,
                label_style,
                w,
              )
            }
          }
        }
      }
    }
  } else {
    // Draw text content for non-image elements
    match node.text {
      Some(text_content) =>
        if row >= 0 && row < ctx.viewport_height {
          // Check if this is a link or inside a link - force underline and blue color
          let is_link = node.tag == "a" || inside_link
          // Check if this element is currently focused
          let is_focused = match ctx.focused_element_name {
            Some(focused_name) => is_link && text_content == focused_name
            None => false
          }
          let (fg_color, bg_color, use_underline, use_bold) = if is_focused {
            // Focus styling: reverse video effect (white text on blue background)
            (
              @types.Color::rgb(255, 255, 255),
              @types.Color::rgb(0, 100, 200),
              false,
              true,
            )
          } else if is_link {
            // Force blue color and underline for links in TUI mode
            // This overrides site CSS to ensure links are always visible
            (
              @types.Color::rgb(0, 0, 238),
              node.paint.background_color,
              true,
              false,
            )
          } else {
            // Use CSS-computed colors directly (dark mode is handled by CSS cascade)
            (node.paint.color, node.paint.background_color, false, false)
          }
          let style : TextStyle = {
            fg: fg_color,
            bg: bg_color,
            bold: use_bold,
            underline: use_underline,
          }
          // Calculate text display width (accounts for wide characters like CJK)
          let text_display_width = calculate_text_display_width(text_content)
          // Effective width ensures text is not clipped due to font-size differences
          let effective_width = w.max(text_display_width)
          // Check if text needs wrapping: exceeds container width
          // CJK text can wrap at any character boundary, so we don't require spaces
          let needs_wrapping = text_display_width > w
          // Use preformatted text for pre/code elements to preserve formatting
          // This respects newlines but doesn't auto-wrap at word boundaries
          if child_inside_pre {
            let _ = ctx.buffer.write_text_pre(
              col,
              row,
              text_content,
              style,
              effective_width,
              (row + h).min(ctx.viewport_height) - row,
            )
          } else if needs_wrapping {
            // Text with spaces that exceeds width - use w for proper line wrapping
            let _ = ctx.buffer.write_text_wrapped(
              col,
              row,
              text_content,
              style,
              w,
              (row + h).min(ctx.viewport_height) - row,
            )
          } else {
            // Single word or short text - use effective_width to prevent clipping
            let _ = ctx.buffer.write_text(
              col, row, text_content, style, effective_width,
            )
          }
          // Collect link region for hit testing
          if is_link && w > 0 && h > 0 {
            match child_link_source_id {
              Some(source_id) => {
                let text_len = text_content.to_array().length()
                let link_col = match visible_rect {
                  Some((visible_x, _, _, _)) => px_to_col(visible_x)
                  None => col
                }
                let link_row = match visible_rect {
                  Some((_, visible_y, _, _)) =>
                    px_to_row(visible_y) - ctx.scroll_y
                  None => row
                }
                let link_width = match visible_rect {
                  Some((_, _, visible_w, _)) =>
                    text_len.min(px_to_col_width(visible_w))
                  None => text_len.min(w)
                }
                let link_height = match visible_rect {
                  Some((_, _, _, visible_h)) => px_to_row_height(visible_h)
                  None => 1
                }
                ctx.link_regions.push({
                  col: link_col,
                  row: link_row,
                  width: link_width,
                  height: link_height,
                  text: text_content,
                  source_id,
                })
              }
              None => ()
            }
          }
        }
      None => ()
    }
  }
  // Render children - pass inside_link and inside_pre flags
  let child_inside_link = inside_link || node.tag == "a"
  for child in node.children {
    render_paint_node(
      ctx,
      child,
      abs_x,
      abs_y,
      child_inside_link,
      current_link_source_id=child_link_source_id,
      inside_pre=child_inside_pre,
      clip_rect=effective_clip,
    )
  }
  // Draw scrollbar for scrollable elements
  if node.is_scrollable() && h >= 3 {
    // Get scroll position from context (default to 0 if not found)
    let scroll_pos = match ctx.element_scroll_positions.get(node.id) {
      Some(pos) => pos.scroll_top.to_int()
      None => 0
    }
    let content_height = px_to_row_height(node.scroll_height)
    let visible_height = h
    // Draw scrollbar on the right edge of the element
    let scrollbar_col = col + w - 1
    let scrollbar_row = row.max(0)
    let scrollbar_height = (row + h).min(ctx.viewport_height) - scrollbar_row
    if scrollbar_height >= 3 && content_height > visible_height {
      draw_scrollbar(
        ctx.buffer,
        scrollbar_col,
        scrollbar_row,
        scrollbar_height,
        scroll_pos,
        content_height,
        visible_height,
      )
    }
  }
}

///|
/// Render result containing ANSI string and link regions
pub(all) struct RenderResult {
  ansi : String
  link_regions : Array[LinkRegion]
  hit_regions : Array[HitRegion]
}

///|
/// Render result with raw buffer (for diff rendering)

///|
/// Region where an image should be rendered via graphics protocol
pub(all) struct ImageRegion {
  col : Int // Start column in character grid
  row : Int // Start row in character grid
  width : Int // Width in characters
  height : Int // Height in characters
  pixel_width : Double // Original pixel width
  pixel_height : Double // Original pixel height
  src : String // Image source URL
  source_id : String // Source element id for stable placement reuse
}

///|
pub(all) struct BufferRenderResult {
  buffer : CharBuffer
  link_regions : Array[LinkRegion]
  hit_regions : Array[HitRegion]
  scrollable_elements : Array[@tui_paint_runtime.ScrollableElement]
  image_regions : Array[ImageRegion]
}

///|
fn prepare_viewport_paint(
  node : @node.Node,
  layout : @types.Layout,
  viewport_top : Double,
  viewport_bottom : Double,
) -> @tui_paint_runtime.PreparedPaint? {
  @tui_paint_runtime.prepare_viewport_paint(
    node, layout, viewport_top, viewport_bottom, 0.0,
  )
}

///|
/// Render a Node + Layout tree to ANSI string
pub fn render_to_ansi(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  focused_element_name? : String? = None,
) -> RenderResult {
  let result = render_to_buffer(
    node,
    layout,
    width,
    height,
    scroll_y,
    focused_element_name~,
  )
  {
    ansi: buffer_to_ansi(result.buffer),
    link_regions: result.link_regions,
    hit_regions: result.hit_regions,
  }
}

///|
/// Render a Node + Layout tree to a CharBuffer
pub fn render_to_buffer(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  focused_element_name? : String? = None,
) -> BufferRenderResult {
  // Create character buffer
  let buf = CharBuffer::new(width, height)
  // Clear with white background
  let white_cell : CharCell = {
    char: ' ',
    fg: @types.Color::black(),
    bg: @types.Color::white(),
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(0, 0, width, height, white_cell)
  // Convert to PaintNode with viewport culling
  let viewport_top = scroll_y.to_double() * font_height
  let viewport_bottom = (scroll_y + height).to_double() * font_height
  let prepared = match
    prepare_viewport_paint(node, layout, viewport_top, viewport_bottom) {
    Some(p) => p
    None =>
      return {
        buffer: buf,
        link_regions: [],
        hit_regions: [],
        scrollable_elements: [],
        image_regions: [],
      }
  }
  let link_regions : Array[LinkRegion] = []
  let hit_regions : Array[HitRegion] = []
  let image_regions : Array[ImageRegion] = []
  let scrollable_elements = prepared.scrollable_elements
  let ctx : TuiContext = {
    buffer: buf,
    scroll_y,
    viewport_height: height,
    link_regions,
    hit_regions,
    image_regions,
    focused_element_name,
    dark_mode: false,
    element_scroll_positions: {},
  }
  render_paint_node(ctx, prepared.tree, 0.0, 0.0, false)
  { buffer: buf, link_regions, hit_regions, scrollable_elements, image_regions }
}

///|
/// Render a Node + Layout tree with status bar at top
pub fn render_to_ansi_with_status(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  url : String,
  link_count : Int,
  focused_link : Int,
  focused_element_name? : String? = None,
  focused_link_url? : String? = None,
  selection_mode? : Bool = false,
  dark_mode? : Bool = false,
) -> RenderResult {
  let result = render_to_buffer_with_status(
    node,
    layout,
    width,
    height,
    scroll_y,
    url,
    link_count,
    focused_link,
    focused_element_name~,
    focused_link_url~,
    selection_mode~,
    dark_mode~,
  )
  {
    ansi: buffer_to_ansi(result.buffer),
    link_regions: result.link_regions,
    hit_regions: result.hit_regions,
  }
}

///|
/// Render a Node + Layout tree with status bar to a CharBuffer
pub fn render_to_buffer_with_status(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  url : String,
  link_count : Int,
  focused_link : Int,
  focused_element_name? : String? = None,
  focused_link_url? : String? = None,
  selection_mode? : Bool = false,
  dark_mode? : Bool = false,
  total_content_height? : Int = 0,
  show_scrollbar? : Bool = false,
  element_scroll_positions? : Map[String, ElementScrollPos] = {},
) -> BufferRenderResult {
  // Reserve first row for status bar at top
  let content_height = height - 1
  let content_start_row = 1 // Content starts at row 1 (after status bar)
  // Create character buffer
  let buf = CharBuffer::new(width, height)
  // Clear with background color based on theme
  let (content_fg, content_bg) = if dark_mode {
    (@types.Color::rgb(220, 220, 220), @types.Color::rgb(30, 30, 30))
  } else {
    (@types.Color::black(), @types.Color::white())
  }
  let bg_cell : CharCell = {
    char: ' ',
    fg: content_fg,
    bg: content_bg,
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(0, content_start_row, width, content_height, bg_cell)
  // Convert to PaintNode with viewport culling
  // Calculate viewport bounds in pixels (font_height = 16.0)
  let viewport_top = scroll_y.to_double() * font_height
  let viewport_bottom = (scroll_y + content_height).to_double() * font_height
  let prepared = match
    prepare_viewport_paint(node, layout, viewport_top, viewport_bottom) {
    Some(p) => p
    None => {
      // Content is outside viewport, draw status bar and return
      draw_status_bar(
        buf,
        0,
        url,
        link_count,
        focused_link,
        focused_link_url~,
        selection_mode~,
        dark_mode~,
      )
      return {
        buffer: buf,
        link_regions: [],
        hit_regions: [],
        scrollable_elements: [],
        image_regions: [],
      }
    }
  }
  let scrollable_elements = prepared.scrollable_elements
  // Create context with link regions array
  // Content is drawn with a 1-row offset via parent_y
  let link_regions : Array[LinkRegion] = []
  let hit_regions : Array[HitRegion] = []
  let image_regions : Array[ImageRegion] = []
  let ctx : TuiContext = {
    buffer: buf,
    scroll_y,
    viewport_height: content_height,
    link_regions,
    hit_regions,
    image_regions,
    focused_element_name,
    dark_mode,
    element_scroll_positions,
  }
  // Render content with offset (start with inside_link=false)
  render_paint_node(
    ctx,
    prepared.tree,
    0.0,
    content_start_row.to_double() * font_height,
    false,
  )
  // Draw status bar at top (row 0) - drawn after content to ensure it's not overwritten
  draw_status_bar(
    buf,
    0,
    url,
    link_count,
    focused_link,
    focused_link_url~,
    selection_mode~,
    dark_mode~,
  )
  // Draw scrollbar if enabled and content overflows
  if show_scrollbar && total_content_height > content_height * 16 {
    let content_height_chars = total_content_height / 16 // Convert px to char rows
    draw_scrollbar(
      buf,
      width - 1, // x: right edge
      content_start_row, // y: start row
      content_height, // height of track
      scroll_y, // scroll position
      content_height_chars, // total content height in chars
      content_height, // visible height in chars
    )
  }
  // Return buffer, link regions, and scrollable elements
  { buffer: buf, link_regions, hit_regions, scrollable_elements, image_regions }
}

///|
/// Get total content height in character rows
pub fn get_content_height_chars(layout : @types.Layout) -> Int {
  px_to_row(layout.height)
}

///|
/// Calculate display width of a string (full-width chars count as 2)
fn display_width(s : String) -> Int {
  let mut width = 0
  for c in s {
    // Full-width characters (CJK, etc.) take 2 columns
    // Basic check: characters above U+2E80 are typically full-width
    let code = c.to_int()
    if code >= 0x2E80 {
      width = width + 2
    } else {
      width = width + 1
    }
  }
  width
}

///|
/// Calculate text display width for TUI rendering
/// Uses character-based width (not pixel-based) to ensure text is not clipped
/// due to font-size differences between layout and TUI
fn calculate_text_display_width(text : String) -> Int {
  let mut width = 0
  for c in text {
    if c == '\n' {
      // Stop at newline for single-line width
      break
    }
    width = width + char_display_width(c)
  }
  width
}

///|
/// Draw hint overlays on the buffer
/// Hints are displayed as bright yellow background with black text
/// Labels are shown to the RIGHT of link text for better visibility
fn draw_hints(
  buf : CharBuffer,
  hints : Array[HintData],
  viewport_height : Int,
) -> Unit {
  let hint_style : TextStyle = {
    fg: @types.Color::rgb(0, 0, 0), // Black text
    bg: @types.Color::rgb(255, 220, 0), // Bright yellow background
    bold: true,
    underline: false,
  }
  for hint in hints {
    // Skip if not visible (row = -1 means position unknown)
    if hint.row < 0 || hint.row >= viewport_height {
      continue
    }
    // Draw hint label to the RIGHT of link text
    // Format: [label] e.g. [a], [ab]
    let label_text = "[" + hint.label + "]"
    // Use display_width to handle full-width characters (CJK)
    let label_col = hint.col + display_width(hint.text)
    let _ = buf.write_text(
      label_col,
      hint.row,
      label_text,
      hint_style,
      label_text.length(),
    )
  }
}

///|
/// Render with hints overlay (for hit-a-hint mode)
pub fn render_to_ansi_with_hints(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  hints : Array[HintData],
  hint_input : String,
  focused_element_name? : String? = None,
) -> RenderResult {
  let result = render_to_buffer_with_hints(
    node,
    layout,
    width,
    height,
    scroll_y,
    hints,
    hint_input,
    focused_element_name~,
  )
  {
    ansi: buffer_to_ansi(result.buffer),
    link_regions: result.link_regions,
    hit_regions: result.hit_regions,
  }
}

///|
/// Render with hints overlay to a CharBuffer
pub fn render_to_buffer_with_hints(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
  hints : Array[HintData],
  hint_input : String,
  focused_element_name? : String? = None,
) -> BufferRenderResult {
  // Reserve last row for status bar
  let content_height = height - 1
  // Create character buffer
  let buf = CharBuffer::new(width, height)
  // Clear with white background
  let white_cell : CharCell = {
    char: ' ',
    fg: @types.Color::black(),
    bg: @types.Color::white(),
    bold: false,
    underline: false,
    reverse: false,
  }
  buf.fill_rect(0, 0, width, content_height, white_cell)
  // Convert to PaintNode with viewport culling
  // Calculate viewport bounds in pixels (font_height = 16.0)
  let viewport_top = scroll_y.to_double() * font_height
  let viewport_bottom = (scroll_y + content_height).to_double() * font_height
  let prepared = match
    prepare_viewport_paint(node, layout, viewport_top, viewport_bottom) {
    Some(p) => p
    None => {
      // Content is outside viewport, just draw hints and status bar
      draw_hints(buf, hints, content_height)
      draw_hint_mode_status_bar(buf, content_height, hint_input, hints)
      return {
        buffer: buf,
        link_regions: [],
        hit_regions: [],
        scrollable_elements: [],
        image_regions: [],
      }
    }
  }
  let scrollable_elements = prepared.scrollable_elements
  // Create context with link regions array
  let link_regions : Array[LinkRegion] = []
  let hit_regions : Array[HitRegion] = []
  let image_regions : Array[ImageRegion] = []
  let ctx : TuiContext = {
    buffer: buf,
    scroll_y,
    viewport_height: content_height,
    link_regions,
    hit_regions,
    image_regions,
    focused_element_name,
    dark_mode: false, // TODO: Add dark_mode support for hints
    element_scroll_positions: {},
  }
  // Render content (start with inside_link=false)
  render_paint_node(ctx, prepared.tree, 0.0, 0.0, false)
  // Draw hint overlays (hint positions are already screen coordinates)
  draw_hints(buf, hints, content_height)
  // Draw status bar with hint list
  draw_hint_mode_status_bar(buf, content_height, hint_input, hints)
  // Return buffer, link regions, and scrollable elements
  { buffer: buf, link_regions, hit_regions, scrollable_elements, image_regions }
}

///|
/// Draw status bar for hint mode with hint list
fn draw_hint_mode_status_bar(
  buf : CharBuffer,
  y : Int,
  hint_input : String,
  hints : Array[HintData],
) -> Unit {
  // Black on yellow background for hint mode
  let style : TextStyle = {
    fg: @types.Color::rgb(0, 0, 0),
    bg: @types.Color::rgb(255, 220, 0),
    bold: true,
    underline: false,
  }
  // Fill the entire row first
  for col = 0; col < buf.width; col = col + 1 {
    let cell : CharCell = {
      char: ' ',
      fg: @types.Color::rgb(0, 0, 0),
      bg: @types.Color::rgb(255, 220, 0),
      bold: false,
      underline: false,
      reverse: false,
    }
    buf.set_cell(col, y, cell)
  }
  // Build hint list (show first few that match current input)
  let sb = StringBuilder::new()
  sb.write_string(" HINT [")
  sb.write_string(hint_input)
  sb.write_string("]: ")
  let mut shown = 0
  let max_show = 8
  for hint in hints {
    if hint_input.length() == 0 || hint.label.has_prefix(hint_input) {
      if shown > 0 {
        sb.write_string(" ")
      }
      sb.write_string(hint.label)
      sb.write_string(":")
      // Truncate text if too long
      let text = hint.text
      let max_len = 12
      if text.to_array().length() > max_len {
        let chars = text.to_array()
        for i = 0; i < max_len - 2; i = i + 1 {
          sb.write_char(chars[i])
        }
        sb.write_string("..")
      } else {
        sb.write_string(text)
      }
      shown = shown + 1
      if shown >= max_show {
        sb.write_string(" ...")
        break
      }
    }
  }
  if shown == 0 {
    sb.write_string("(no match)")
  }
  sb.write_string(" | ESC:cancel")
  let status = sb.to_string()
  let _ = buf.write_text(0, y, status, style, buf.width)
}

///|
/// Calculate content extent from layout tree (max y + height of descendants)
pub fn get_content_extent(layout : @types.Layout) -> Double {
  let mut max_extent = layout.y + layout.height
  for child in layout.children {
    let child_extent = get_content_extent(child)
    if child_extent > max_extent {
      max_extent = child_extent
    }
  }
  max_extent
}
