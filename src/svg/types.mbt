///|
/// SVG Layout Engine - Standalone Types
/// Independent of HTML/CSS layout system

///|
/// RGB Color (0-255 range)
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
  a : Int // Alpha (0-255, 255 = opaque)
}

///|
pub fn Color::rgb(r : Int, g : Int, b : Int) -> Color {
  { r, g, b, a: 255 }
}

///|
pub fn Color::rgba(r : Int, g : Int, b : Int, a : Int) -> Color {
  { r, g, b, a }
}

///|
pub fn Color::transparent() -> Color {
  { r: 0, g: 0, b: 0, a: 0 }
}

///|
pub fn Color::black() -> Color {
  { r: 0, g: 0, b: 0, a: 255 }
}

///|
pub fn Color::white() -> Color {
  { r: 255, g: 255, b: 255, a: 255 }
}

///|
pub fn Color::is_transparent(self : Color) -> Bool {
  self.a == 0
}

///|
/// 2D affine transformation matrix
/// | a c e |
/// | b d f |
/// | 0 0 1 |
pub(all) struct Transform {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
/// ViewBox specification for SVG coordinate system mapping
pub(all) struct ViewBox {
  min_x : Double
  min_y : Double
  width : Double
  height : Double
}

///|
/// preserveAspectRatio alignment values
pub(all) enum Align {
  None // No forced uniform scaling
  XMinYMin
  XMidYMin
  XMaxYMin
  XMinYMid
  XMidYMid // Default
  XMaxYMid
  XMinYMax
  XMidYMax
  XMaxYMax
} derive(Show, Eq)

///|
/// preserveAspectRatio meet/slice
pub(all) enum MeetOrSlice {
  Meet // Scale to fit entirely (default)
  Slice // Scale to cover entirely
} derive(Show, Eq)

///|
/// Complete preserveAspectRatio setting
pub(all) struct PreserveAspectRatio {
  align : Align
  meet_or_slice : MeetOrSlice
}

///|
pub fn PreserveAspectRatio::default() -> PreserveAspectRatio {
  { align: XMidYMid, meet_or_slice: Meet }
}

///|
/// Calculate the transform matrix to map viewBox coordinates to viewport
/// viewport_width/height: the actual pixel dimensions of the SVG element
pub fn ViewBox::get_transform(
  self : ViewBox,
  viewport_width : Double,
  viewport_height : Double,
  preserve_aspect_ratio : PreserveAspectRatio,
) -> Transform {
  // Handle zero-size viewBox
  if self.width <= 0.0 || self.height <= 0.0 {
    return Transform::identity()
  }
  // Calculate scale factors
  let scale_x = viewport_width / self.width
  let scale_y = viewport_height / self.height
  // Determine actual scale based on preserveAspectRatio
  let (sx, sy, tx, ty) = match preserve_aspect_ratio.align {
    None =>
      // No uniform scaling - stretch to fit
      (scale_x, scale_y, -self.min_x * scale_x, -self.min_y * scale_y)
    _ => {
      // Uniform scaling
      let scale = match preserve_aspect_ratio.meet_or_slice {
        Meet => if scale_x < scale_y { scale_x } else { scale_y } // Fit entirely
        Slice => if scale_x > scale_y { scale_x } else { scale_y } // Cover entirely
      }
      // Calculate translation based on alignment
      let (align_x, align_y) = get_alignment_factors(
        preserve_aspect_ratio.align,
      )
      // Extra space after scaling
      let extra_x = viewport_width - self.width * scale
      let extra_y = viewport_height - self.height * scale
      let translate_x = -self.min_x * scale + extra_x * align_x
      let translate_y = -self.min_y * scale + extra_y * align_y
      (scale, scale, translate_x, translate_y)
    }
  }
  // Combine: first translate by viewBox min, then scale
  Transform::{ a: sx, b: 0.0, c: 0.0, d: sy, e: tx, f: ty }
}

///|
/// Get alignment factors (0.0 = min, 0.5 = mid, 1.0 = max)
fn get_alignment_factors(align : Align) -> (Double, Double) {
  match align {
    None => (0.0, 0.0)
    XMinYMin => (0.0, 0.0)
    XMidYMin => (0.5, 0.0)
    XMaxYMin => (1.0, 0.0)
    XMinYMid => (0.0, 0.5)
    XMidYMid => (0.5, 0.5)
    XMaxYMid => (1.0, 0.5)
    XMinYMax => (0.0, 1.0)
    XMidYMax => (0.5, 1.0)
    XMaxYMax => (1.0, 1.0)
  }
}

///|
/// SVG path commands (full SVG 1.1 spec)
pub(all) enum PathCommand {
  // Absolute commands
  MoveTo(Double, Double) // M x y
  LineTo(Double, Double) // L x y
  HorizontalLineTo(Double) // H x
  VerticalLineTo(Double) // V y
  CurveTo(Double, Double, Double, Double, Double, Double) // C x1 y1 x2 y2 x y
  SmoothCurveTo(Double, Double, Double, Double) // S x2 y2 x y
  QuadraticCurveTo(Double, Double, Double, Double) // Q x1 y1 x y
  SmoothQuadraticCurveTo(Double, Double) // T x y
  ArcTo(Double, Double, Double, Bool, Bool, Double, Double) // A rx ry rotation large-arc sweep x y
  ClosePath // Z
  // Relative commands
  MoveToRel(Double, Double) // m dx dy
  LineToRel(Double, Double) // l dx dy
  HorizontalLineToRel(Double) // h dx
  VerticalLineToRel(Double) // v dy
  CurveToRel(Double, Double, Double, Double, Double, Double) // c dx1 dy1 dx2 dy2 dx dy
  SmoothCurveToRel(Double, Double, Double, Double) // s dx2 dy2 dx dy
  QuadraticCurveToRel(Double, Double, Double, Double) // q dx1 dy1 dx dy
  SmoothQuadraticCurveToRel(Double, Double) // t dx dy
  ArcToRel(Double, Double, Double, Bool, Bool, Double, Double) // a rx ry rotation large-arc sweep dx dy
} derive(Show)

///|
/// SVG shape primitives
pub(all) enum Shape {
  Rect(
    x~ : Double,
    y~ : Double,
    width~ : Double,
    height~ : Double,
    rx~ : Double,
    ry~ : Double
  )
  Circle(cx~ : Double, cy~ : Double, r~ : Double)
  Ellipse(cx~ : Double, cy~ : Double, rx~ : Double, ry~ : Double)
  Line(x1~ : Double, y1~ : Double, x2~ : Double, y2~ : Double)
  Polyline(points~ : Array[(Double, Double)])
  Polygon(points~ : Array[(Double, Double)])
  Path(commands~ : Array[PathCommand])
  Text(x~ : Double, y~ : Double, text~ : String, font_size~ : Double)
  Group // Container for children
} derive(Show)

///|
/// Gradient stop (position 0.0-1.0 and color)
pub(all) struct GradientStop {
  offset : Double // 0.0 to 1.0
  color : Color
}

///|
/// Linear gradient definition
pub(all) struct LinearGradient {
  x1 : Double // Start point x (0.0-1.0 or absolute)
  y1 : Double // Start point y
  x2 : Double // End point x
  y2 : Double // End point y
  stops : Array[GradientStop]
  spread_method : SpreadMethod
}

///|
pub fn LinearGradient::new(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  stops : Array[GradientStop],
) -> LinearGradient {
  { x1, y1, x2, y2, stops, spread_method: Pad }
}

///|
/// Simple horizontal gradient (left to right)
pub fn LinearGradient::horizontal(
  start_color : Color,
  end_color : Color,
) -> LinearGradient {
  {
    x1: 0.0,
    y1: 0.0,
    x2: 1.0,
    y2: 0.0,
    stops: [
      { offset: 0.0, color: start_color },
      { offset: 1.0, color: end_color },
    ],
    spread_method: Pad,
  }
}

///|
/// Simple vertical gradient (top to bottom)
pub fn LinearGradient::vertical(
  start_color : Color,
  end_color : Color,
) -> LinearGradient {
  {
    x1: 0.0,
    y1: 0.0,
    x2: 0.0,
    y2: 1.0,
    stops: [
      { offset: 0.0, color: start_color },
      { offset: 1.0, color: end_color },
    ],
    spread_method: Pad,
  }
}

///|
/// Interpolate color at position t (0.0-1.0)
pub fn LinearGradient::color_at(self : LinearGradient, t : Double) -> Color {
  if self.stops.length() == 0 {
    return Color::black()
  }
  if self.stops.length() == 1 {
    return self.stops[0].color
  }
  // Apply spread method
  let t = match self.spread_method {
    Pad => if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
    Repeat => {
      let t2 = t - t.floor()
      if t2 < 0.0 {
        t2 + 1.0
      } else {
        t2
      }
    }
    Reflect => {
      let t2 = t - t.floor()
      let t2 = if t2 < 0.0 { t2 + 1.0 } else { t2 }
      let cycle = t.floor().to_int() % 2
      if cycle == 1 {
        1.0 - t2
      } else {
        t2
      }
    }
  }
  // Find surrounding stops
  let mut prev_stop = self.stops[0]
  let mut next_stop = self.stops[self.stops.length() - 1]
  for i = 0; i < self.stops.length() - 1; i = i + 1 {
    if t >= self.stops[i].offset && t <= self.stops[i + 1].offset {
      prev_stop = self.stops[i]
      next_stop = self.stops[i + 1]
      break
    }
  }
  // Interpolate
  let range = next_stop.offset - prev_stop.offset
  if range < 0.0001 {
    return prev_stop.color
  }
  let local_t = (t - prev_stop.offset) / range
  Color::rgba(
    (prev_stop.color.r.to_double() * (1.0 - local_t) +
    next_stop.color.r.to_double() * local_t).to_int(),
    (prev_stop.color.g.to_double() * (1.0 - local_t) +
    next_stop.color.g.to_double() * local_t).to_int(),
    (prev_stop.color.b.to_double() * (1.0 - local_t) +
    next_stop.color.b.to_double() * local_t).to_int(),
    (prev_stop.color.a.to_double() * (1.0 - local_t) +
    next_stop.color.a.to_double() * local_t).to_int(),
  )
}

///|
/// How gradient extends beyond its bounds
pub(all) enum SpreadMethod {
  Pad // Extend with end colors (default)
  Repeat // Repeat pattern
  Reflect // Mirror pattern
} derive(Show, Eq)

///|
/// Paint style (fill or stroke)
pub(all) enum Paint {
  None
  SolidColor(Color)
  LinearGrad(LinearGradient)
  RadialGrad(RadialGradient)
}

///|
/// Stroke properties
pub(all) struct StrokeStyle {
  paint : Paint
  width : Double
  linecap : LineCap
  linejoin : LineJoin
  miterlimit : Double
  dasharray : Array[Double]?
  dashoffset : Double
}

///|
pub fn StrokeStyle::default() -> StrokeStyle {
  {
    paint: None,
    width: 1.0,
    linecap: Butt,
    linejoin: Miter,
    miterlimit: 4.0,
    dasharray: None,
    dashoffset: 0.0,
  }
}

///|
pub(all) enum LineCap {
  Butt
  Round
  Square
} derive(Show, Eq)

///|
pub(all) enum LineJoin {
  Miter
  Round
  Bevel
} derive(Show, Eq)

///|
/// Fill rule for paths and polygons
pub(all) enum FillRule {
  NonZero // Default
  EvenOdd
} derive(Show, Eq)

///|
/// SVG node (element in the scene graph)
pub(all) struct SVGNode {
  mut id : String
  mut shape : Shape
  mut transform : Transform
  mut fill : Paint
  mut fill_rule : FillRule
  mut fill_opacity : Double
  mut stroke : StrokeStyle
  mut stroke_opacity : Double
  mut opacity : Double
  mut z_index : Int // Layer order (higher = front)
  mut node_dirty : Bool // Per-node dirty flag
  mut prev_bounds : BoundingBox? // Previous bounding box for dirty rect
  mut filters : Array[Filter] // Filter effects to apply
  mut mask_id : String? // Reference to mask by ID
  mut clip_path_id : String? // Reference to clip path by ID
  children : Array[SVGNode]
}

///|
pub fn SVGNode::new(shape : Shape) -> SVGNode {
  {
    id: "",
    shape,
    transform: Transform::identity(),
    fill: SolidColor(Color::black()),
    fill_rule: NonZero,
    fill_opacity: 1.0,
    stroke: StrokeStyle::default(),
    stroke_opacity: 1.0,
    opacity: 1.0,
    z_index: 0,
    node_dirty: true,
    prev_bounds: None,
    filters: [],
    mask_id: None,
    clip_path_id: None,
    children: [],
  }
}

///|
/// Add a filter to the node
pub fn SVGNode::add_filter(self : SVGNode, filter : Filter) -> Unit {
  self.filters.push(filter)
  self.mark_dirty()
}

///|
/// Clear all filters from the node
pub fn SVGNode::clear_filters(self : SVGNode) -> Unit {
  self.filters.clear()
  self.mark_dirty()
}

///|
/// Set mask reference by ID
pub fn SVGNode::set_mask(self : SVGNode, mask_id : String) -> Unit {
  self.mask_id = Some(mask_id)
  self.mark_dirty()
}

///|
/// Clear mask reference
pub fn SVGNode::clear_mask(self : SVGNode) -> Unit {
  self.mask_id = None
  self.mark_dirty()
}

///|
/// Set clip path reference by ID
pub fn SVGNode::set_clip_path(self : SVGNode, clip_path_id : String) -> Unit {
  self.clip_path_id = Some(clip_path_id)
  self.mark_dirty()
}

///|
/// Clear clip path reference
pub fn SVGNode::clear_clip_path(self : SVGNode) -> Unit {
  self.clip_path_id = None
  self.mark_dirty()
}

///|
/// Mark a node as dirty (needs re-render)
pub fn SVGNode::mark_dirty(self : SVGNode) -> Unit {
  self.node_dirty = true
}

///|
/// Clear the dirty flag
pub fn SVGNode::clear_dirty(self : SVGNode) -> Unit {
  self.node_dirty = false
}

///|

///|
/// Helper function for min of two doubles
fn min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Helper function for max of two doubles
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Bounding box for a shape
pub(all) struct BoundingBox {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
}

///|
pub fn BoundingBox::empty() -> BoundingBox {
  {
    min_x: @double.infinity,
    min_y: @double.infinity,
    max_x: @double.neg_infinity,
    max_y: @double.neg_infinity,
  }
}

///|
pub fn BoundingBox::from_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> BoundingBox {
  { min_x: x, min_y: y, max_x: x + w, max_y: y + h }
}

///|
pub fn BoundingBox::width(self : BoundingBox) -> Double {
  self.max_x - self.min_x
}

///|
pub fn BoundingBox::height(self : BoundingBox) -> Double {
  self.max_y - self.min_y
}

///|
pub fn BoundingBox::is_empty(self : BoundingBox) -> Bool {
  self.min_x > self.max_x || self.min_y > self.max_y
}

///|
pub fn BoundingBox::union(
  self : BoundingBox,
  other : BoundingBox,
) -> BoundingBox {
  if self.is_empty() {
    other
  } else if other.is_empty() {
    self
  } else {
    {
      min_x: min(self.min_x, other.min_x),
      min_y: min(self.min_y, other.min_y),
      max_x: max(self.max_x, other.max_x),
      max_y: max(self.max_y, other.max_y),
    }
  }
}

///|
pub fn BoundingBox::expand_by_point(
  self : BoundingBox,
  x : Double,
  y : Double,
) -> BoundingBox {
  {
    min_x: min(self.min_x, x),
    min_y: min(self.min_y, y),
    max_x: max(self.max_x, x),
    max_y: max(self.max_y, y),
  }
}

///|
/// Check if two bounding boxes intersect
pub fn BoundingBox::intersects(self : BoundingBox, other : BoundingBox) -> Bool {
  if self.is_empty() || other.is_empty() {
    false
  } else {
    self.min_x <= other.max_x &&
    self.max_x >= other.min_x &&
    self.min_y <= other.max_y &&
    self.max_y >= other.min_y
  }
}

///|
/// Check if this bounding box contains a point
pub fn BoundingBox::contains_point(
  self : BoundingBox,
  x : Double,
  y : Double,
) -> Bool {
  x >= self.min_x && x <= self.max_x && y >= self.min_y && y <= self.max_y
}

///|
/// Clipping rectangle for camera/viewport
pub(all) struct ClipRect {
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
pub fn ClipRect::new(x : Int, y : Int, width : Int, height : Int) -> ClipRect {
  { x, y, width, height }
}

///|
pub fn ClipRect::from_size(width : Int, height : Int) -> ClipRect {
  { x: 0, y: 0, width, height }
}

///|
/// Check if a point is inside the clip rect
pub fn ClipRect::contains(self : ClipRect, x : Int, y : Int) -> Bool {
  x >= self.x &&
  x < self.x + self.width &&
  y >= self.y &&
  y < self.y + self.height
}

///|
/// Convert to BoundingBox
pub fn ClipRect::to_bbox(self : ClipRect) -> BoundingBox {
  {
    min_x: self.x.to_double(),
    min_y: self.y.to_double(),
    max_x: (self.x + self.width).to_double(),
    max_y: (self.y + self.height).to_double(),
  }
}

///|
/// Camera for 2D scene navigation
/// Supports pan (translation) and zoom
pub(all) struct Camera {
  mut x : Double // Camera position X (center)
  mut y : Double // Camera position Y (center)
  mut zoom : Double // Zoom level (1.0 = 100%)
  viewport_width : Int // Viewport width in pixels
  viewport_height : Int // Viewport height in pixels
}

///|
pub fn Camera::new(viewport_width : Int, viewport_height : Int) -> Camera {
  { x: 0.0, y: 0.0, zoom: 1.0, viewport_width, viewport_height }
}

///|
/// Move camera by delta
pub fn Camera::pan(self : Camera, dx : Double, dy : Double) -> Unit {
  self.x = self.x + dx
  self.y = self.y + dy
}

///|
/// Set camera position
pub fn Camera::set_position(self : Camera, x : Double, y : Double) -> Unit {
  self.x = x
  self.y = y
}

///|
/// Set zoom level
pub fn Camera::set_zoom(self : Camera, zoom : Double) -> Unit {
  self.zoom = if zoom < 0.1 { 0.1 } else if zoom > 10.0 { 10.0 } else { zoom }
}

///|
/// Zoom by factor (multiply current zoom)
pub fn Camera::zoom_by(self : Camera, factor : Double) -> Unit {
  self.set_zoom(self.zoom * factor)
}

///|
/// Get the world-space bounding box visible through this camera
pub fn Camera::get_visible_bounds(self : Camera) -> BoundingBox {
  let half_w = self.viewport_width.to_double() / 2.0 / self.zoom
  let half_h = self.viewport_height.to_double() / 2.0 / self.zoom
  {
    min_x: self.x - half_w,
    min_y: self.y - half_h,
    max_x: self.x + half_w,
    max_y: self.y + half_h,
  }
}

///|
/// Convert world coordinates to screen coordinates
pub fn Camera::world_to_screen(
  self : Camera,
  wx : Double,
  wy : Double,
) -> (Int, Int) {
  let sx = (wx - self.x) * self.zoom + self.viewport_width.to_double() / 2.0
  let sy = (wy - self.y) * self.zoom + self.viewport_height.to_double() / 2.0
  (sx.to_int(), sy.to_int())
}

///|
/// Convert screen coordinates to world coordinates
pub fn Camera::screen_to_world(
  self : Camera,
  sx : Int,
  sy : Int,
) -> (Double, Double) {
  let wx = (sx.to_double() - self.viewport_width.to_double() / 2.0) / self.zoom +
    self.x
  let wy = (sy.to_double() - self.viewport_height.to_double() / 2.0) / self.zoom +
    self.y
  (wx, wy)
}

///|
/// Get transform matrix for this camera
pub fn Camera::get_transform(self : Camera) -> Transform {
  // Translate to center, scale by zoom, then translate by camera position
  let tx = self.viewport_width.to_double() / 2.0 - self.x * self.zoom
  let ty = self.viewport_height.to_double() / 2.0 - self.y * self.zoom
  { a: self.zoom, b: 0.0, c: 0.0, d: self.zoom, e: tx, f: ty }
}

// ============================================================================
// Hit Testing
// ============================================================================

///|
/// Check if a point is inside a rectangle
fn hit_test_rect(
  px : Double,
  py : Double,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Bool {
  px >= x && px <= x + width && py >= y && py <= y + height
}

///|
/// Check if a point is inside a circle
fn hit_test_circle(
  px : Double,
  py : Double,
  cx : Double,
  cy : Double,
  r : Double,
) -> Bool {
  let dx = px - cx
  let dy = py - cy
  dx * dx + dy * dy <= r * r
}

///|
/// Check if a point is inside an ellipse
fn hit_test_ellipse(
  px : Double,
  py : Double,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
) -> Bool {
  if rx <= 0.0 || ry <= 0.0 {
    return false
  }
  let dx = (px - cx) / rx
  let dy = (py - cy) / ry
  dx * dx + dy * dy <= 1.0
}

///|
/// Check if a point is inside a polygon using ray casting algorithm
fn hit_test_polygon(
  px : Double,
  py : Double,
  points : Array[(Double, Double)],
) -> Bool {
  let n = points.length()
  if n < 3 {
    return false
  }
  let mut inside = false
  let mut j = n - 1
  for i = 0; i < n; i = i + 1 {
    let (xi, yi) = points[i]
    let (xj, yj) = points[j]
    // Ray casting: count intersections with polygon edges
    if (yi > py) != (yj > py) && px < (xj - xi) * (py - yi) / (yj - yi) + xi {
      inside = not(inside)
    }
    j = i
  }
  inside
}

///|
/// Check if a point is on a line (with tolerance)
fn hit_test_line(
  px : Double,
  py : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  tolerance : Double,
) -> Bool {
  // Distance from point to line segment
  let dx = x2 - x1
  let dy = y2 - y1
  let len_sq = dx * dx + dy * dy
  if len_sq < 0.0001 {
    // Line is a point
    let d = (px - x1) * (px - x1) + (py - y1) * (py - y1)
    return d <= tolerance * tolerance
  }
  // Project point onto line
  let t = ((px - x1) * dx + (py - y1) * dy) / len_sq
  let t_clamped = if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
  let proj_x = x1 + t_clamped * dx
  let proj_y = y1 + t_clamped * dy
  let dist_sq = (px - proj_x) * (px - proj_x) + (py - proj_y) * (py - proj_y)
  dist_sq <= tolerance * tolerance
}

///|
/// Hit test a shape (without transform)
pub fn hit_test_shape(px : Double, py : Double, shape : Shape) -> Bool {
  match shape {
    Rect(x~, y~, width~, height~, ..) =>
      hit_test_rect(px, py, x, y, width, height)
    Circle(cx~, cy~, r~) => hit_test_circle(px, py, cx, cy, r)
    Ellipse(cx~, cy~, rx~, ry~) => hit_test_ellipse(px, py, cx, cy, rx, ry)
    Line(x1~, y1~, x2~, y2~) => hit_test_line(px, py, x1, y1, x2, y2, 2.0)
    Polyline(points~) => {
      // Hit test each line segment
      for i = 0; i < points.length() - 1; i = i + 1 {
        let (x1, y1) = points[i]
        let (x2, y2) = points[i + 1]
        if hit_test_line(px, py, x1, y1, x2, y2, 2.0) {
          return true
        }
      }
      false
    }
    Polygon(points~) => hit_test_polygon(px, py, points)
    Path(_) => false // TODO: convert path to polygon for hit testing
    Text(x~, y~, text~, font_size~) => {
      // Approximate text bounding box
      let char_width = font_size * 0.6
      let width = char_width * text.length().to_double()
      hit_test_rect(px, py, x, y - font_size, width, font_size)
    }
    Group => false
  }
}

///|
/// Hit test an SVGNode at a point (in world coordinates)
/// Returns true if the point is inside the node's shape
pub fn SVGNode::hit_test(self : SVGNode, px : Double, py : Double) -> Bool {
  // Apply inverse transform to the point
  let inv = self.transform.inverse()
  let (local_x, local_y) = inv.apply(px, py)
  hit_test_shape(local_x, local_y, self.shape)
}

///|
/// Find all nodes at a point (recursive, returns in front-to-back order)
pub fn SVGNode::hit_test_all(
  self : SVGNode,
  px : Double,
  py : Double,
) -> Array[SVGNode] {
  let results : Array[SVGNode] = []
  hit_test_recursive(self, px, py, Transform::identity(), results)
  results
}

///|
fn hit_test_recursive(
  node : SVGNode,
  px : Double,
  py : Double,
  parent_transform : Transform,
  results : Array[SVGNode],
) -> Unit {
  let world_transform = parent_transform.multiply(node.transform)
  let inv = world_transform.inverse()
  let (local_x, local_y) = inv.apply(px, py)
  // Check children first (front-to-back: last child is on top)
  for i = node.children.length() - 1; i >= 0; i = i - 1 {
    hit_test_recursive(node.children[i], px, py, world_transform, results)
  }
  // Then check this node
  if hit_test_shape(local_x, local_y, node.shape) {
    results.push(node)
  }
}

// ============================================================================
// Animation / Tween System
// ============================================================================

///|
/// Easing functions for smooth animations
pub(all) enum Easing {
  Linear
  EaseIn // Quadratic ease in
  EaseOut // Quadratic ease out
  EaseInOut // Quadratic ease in-out
  EaseInCubic
  EaseOutCubic
  EaseInOutCubic
} derive(Show, Eq)

///|
/// Apply easing function to a normalized time (0.0 to 1.0)
pub fn Easing::apply(self : Easing, t : Double) -> Double {
  let t_clamped = if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
  match self {
    Linear => t_clamped
    EaseIn => t_clamped * t_clamped
    EaseOut => t_clamped * (2.0 - t_clamped)
    EaseInOut =>
      if t_clamped < 0.5 {
        2.0 * t_clamped * t_clamped
      } else {
        -1.0 + (4.0 - 2.0 * t_clamped) * t_clamped
      }
    EaseInCubic => t_clamped * t_clamped * t_clamped
    EaseOutCubic => {
      let t1 = t_clamped - 1.0
      t1 * t1 * t1 + 1.0
    }
    EaseInOutCubic =>
      if t_clamped < 0.5 {
        4.0 * t_clamped * t_clamped * t_clamped
      } else {
        let t1 = 2.0 * t_clamped - 2.0
        (t1 * t1 * t1 + 2.0) / 2.0
      }
  }
}

///|
/// Animatable property types
pub(all) enum AnimProperty {
  TranslateX(Double) // Target x translation
  TranslateY(Double) // Target y translation
  Translate(Double, Double) // Target (x, y) translation
  ScaleX(Double) // Target x scale
  ScaleY(Double) // Target y scale
  Scale(Double, Double) // Target (sx, sy) scale
  ScaleUniform(Double) // Target uniform scale
  Rotation(Double) // Target rotation in radians
  Opacity(Double) // Target opacity
  FillColor(Color) // Target fill color
}

///|
/// A single tween animation
pub(all) struct Tween {
  target_id : String // ID of the node to animate
  property : AnimProperty
  mut start_value : AnimProperty // Captured at start
  duration : Double // Duration in seconds
  mut elapsed : Double // Elapsed time in seconds
  easing : Easing
  mut started : Bool // Has the animation captured start values?
  mut completed : Bool
}

///|
/// Create a new tween
pub fn Tween::new(
  target_id : String,
  property : AnimProperty,
  duration : Double,
  easing : Easing,
) -> Tween {
  {
    target_id,
    property,
    start_value: property, // Will be overwritten when started
    duration,
    elapsed: 0.0,
    easing,
    started: false,
    completed: false,
  }
}

///|
/// Check if the tween is complete
pub fn Tween::is_complete(self : Tween) -> Bool {
  self.completed
}

///|
/// Update the tween with delta time
/// Returns true if still running, false if complete
pub fn Tween::update(self : Tween, dt : Double, node : SVGNode) -> Bool {
  if self.completed {
    return false
  }
  // Capture start values on first update
  if not(self.started) {
    self.start_value = capture_property(node, self.property)
    self.started = true
  }
  self.elapsed = self.elapsed + dt
  let t = if self.duration <= 0.0 { 1.0 } else { self.elapsed / self.duration }
  if t >= 1.0 {
    // Complete: set final value
    apply_property(node, self.property, 1.0)
    self.completed = true
    false
  } else {
    // Interpolate
    let eased_t = self.easing.apply(t)
    apply_interpolated_property(node, self.start_value, self.property, eased_t)
    true
  }
}

///|
/// Capture current property value from node
fn capture_property(node : SVGNode, property : AnimProperty) -> AnimProperty {
  let (tx, ty) = node.transform.get_translate()
  let (sx, sy) = node.transform.get_scale()
  let rotation = node.transform.get_rotation()
  match property {
    TranslateX(_) => TranslateX(tx)
    TranslateY(_) => TranslateY(ty)
    Translate(_, _) => Translate(tx, ty)
    ScaleX(_) => ScaleX(sx)
    ScaleY(_) => ScaleY(sy)
    Scale(_, _) => Scale(sx, sy)
    ScaleUniform(_) => ScaleUniform((sx + sy) / 2.0)
    Rotation(_) => Rotation(rotation)
    Opacity(_) => Opacity(node.opacity)
    FillColor(_) =>
      match node.fill {
        SolidColor(c) => FillColor(c)
        _ => FillColor(Color::black())
      }
  }
}

///|
/// Apply final property value to node
fn apply_property(node : SVGNode, property : AnimProperty, t : Double) -> Unit {
  let _ = t // t=1.0 means final value
  match property {
    TranslateX(x) => {
      let (_, ty) = node.transform.get_translate()
      node.transform = Transform::translate(x, ty)
    }
    TranslateY(y) => {
      let (tx, _) = node.transform.get_translate()
      node.transform = Transform::translate(tx, y)
    }
    Translate(x, y) => node.transform = Transform::translate(x, y)
    ScaleX(sx) => {
      let (_, sy) = node.transform.get_scale()
      node.transform = Transform::scale(sx, sy)
    }
    ScaleY(sy) => {
      let (sx, _) = node.transform.get_scale()
      node.transform = Transform::scale(sx, sy)
    }
    Scale(sx, sy) => node.transform = Transform::scale(sx, sy)
    ScaleUniform(s) => node.transform = Transform::scale(s, s)
    Rotation(r) => node.transform = Transform::rotate(r)
    Opacity(o) => node.opacity = o
    FillColor(c) => node.fill = SolidColor(c)
  }
}

///|
/// Apply interpolated property value to node
fn apply_interpolated_property(
  node : SVGNode,
  start : AnimProperty,
  end : AnimProperty,
  t : Double,
) -> Unit {
  match (start, end) {
    (TranslateX(x0), TranslateX(x1)) => {
      let x = lerp(x0, x1, t)
      let (_, ty) = node.transform.get_translate()
      node.transform = Transform::translate(x, ty)
    }
    (TranslateY(y0), TranslateY(y1)) => {
      let y = lerp(y0, y1, t)
      let (tx, _) = node.transform.get_translate()
      node.transform = Transform::translate(tx, y)
    }
    (Translate(x0, y0), Translate(x1, y1)) => {
      let x = lerp(x0, x1, t)
      let y = lerp(y0, y1, t)
      node.transform = Transform::translate(x, y)
    }
    (ScaleX(sx0), ScaleX(sx1)) => {
      let sx = lerp(sx0, sx1, t)
      let (_, sy) = node.transform.get_scale()
      node.transform = Transform::scale(sx, sy)
    }
    (ScaleY(sy0), ScaleY(sy1)) => {
      let sy = lerp(sy0, sy1, t)
      let (sx, _) = node.transform.get_scale()
      node.transform = Transform::scale(sx, sy)
    }
    (Scale(sx0, sy0), Scale(sx1, sy1)) => {
      let sx = lerp(sx0, sx1, t)
      let sy = lerp(sy0, sy1, t)
      node.transform = Transform::scale(sx, sy)
    }
    (ScaleUniform(s0), ScaleUniform(s1)) => {
      let s = lerp(s0, s1, t)
      node.transform = Transform::scale(s, s)
    }
    (Rotation(r0), Rotation(r1)) => {
      let r = lerp(r0, r1, t)
      node.transform = Transform::rotate(r)
    }
    (Opacity(o0), Opacity(o1)) => node.opacity = lerp(o0, o1, t)
    (FillColor(c0), FillColor(c1)) => {
      let c = lerp_color(c0, c1, t)
      node.fill = SolidColor(c)
    }
    _ => () // Mismatched types, do nothing
  }
}

///|
/// Linear interpolation
fn lerp(a : Double, b : Double, t : Double) -> Double {
  a + (b - a) * t
}

///|
/// Color interpolation
fn lerp_color(c0 : Color, c1 : Color, t : Double) -> Color {
  {
    r: lerp(c0.r.to_double(), c1.r.to_double(), t).to_int(),
    g: lerp(c0.g.to_double(), c1.g.to_double(), t).to_int(),
    b: lerp(c0.b.to_double(), c1.b.to_double(), t).to_int(),
    a: lerp(c0.a.to_double(), c1.a.to_double(), t).to_int(),
  }
}

// ============================================================================
// Event System
// ============================================================================

///|
/// Mouse/pointer event data
pub(all) struct PointerEvent {
  x : Double // World coordinates
  y : Double
  button : Int // 0=left, 1=middle, 2=right
  target : String // ID of the target node
  mut propagation_stopped : Bool
}

///|
pub fn PointerEvent::new(
  x : Double,
  y : Double,
  button : Int,
  target : String,
) -> PointerEvent {
  { x, y, button, target, propagation_stopped: false }
}

///|
/// Stop event propagation (prevent bubbling)
pub fn PointerEvent::stop_propagation(self : PointerEvent) -> Unit {
  self.propagation_stopped = true
}

///|
/// Event handler type
pub(all) struct EventHandler {
  call : (PointerEvent) -> Unit
}

///|
/// Event types
pub(all) enum EventType {
  Click
  MouseDown
  MouseUp
  MouseMove
  MouseEnter
  MouseLeave
  DragStart
  DragMove
  DragEnd
} derive(Show, Eq)

///|
/// Event listener entry
pub(all) struct EventListener {
  event_type : EventType
  handler : EventHandler
}

///|
/// Event manager for handling input events
pub(all) struct EventManager {
  listeners : Map[String, Array[EventListener]] // node_id -> listeners
  mut hovered_node : String? // Currently hovered node
  mut dragging_node : String? // Currently dragging node
  mut drag_start_x : Double
  mut drag_start_y : Double
}

///|
pub fn EventManager::new() -> EventManager {
  {
    listeners: {},
    hovered_node: None,
    dragging_node: None,
    drag_start_x: 0.0,
    drag_start_y: 0.0,
  }
}

///|
/// Register an event listener for a node
pub fn EventManager::on(
  self : EventManager,
  node_id : String,
  event_type : EventType,
  handler : EventHandler,
) -> Unit {
  let listener = EventListener::{ event_type, handler }
  match self.listeners.get(node_id) {
    Some(arr) => arr.push(listener)
    None => self.listeners.set(node_id, [listener])
  }
}

///|
/// Remove all listeners for a node
pub fn EventManager::off_all(self : EventManager, node_id : String) -> Unit {
  let _ = self.listeners.remove(node_id)
}

///|
/// Dispatch a click event at coordinates
pub fn EventManager::dispatch_click(
  self : EventManager,
  x : Double,
  y : Double,
  button : Int,
  scene : Scene,
) -> Unit {
  let hit_nodes = scene.root.hit_test_all(x, y)
  for node in hit_nodes {
    let event = PointerEvent::new(x, y, button, node.id)
    self.dispatch_to_node(node.id, Click, event)
    if event.propagation_stopped {
      break
    }
  }
}

///|
/// Dispatch mouse down event
pub fn EventManager::dispatch_mouse_down(
  self : EventManager,
  x : Double,
  y : Double,
  button : Int,
  scene : Scene,
) -> Unit {
  let hit_nodes = scene.root.hit_test_all(x, y)
  for node in hit_nodes {
    let event = PointerEvent::new(x, y, button, node.id)
    self.dispatch_to_node(node.id, MouseDown, event)
    // Start drag
    if not(event.propagation_stopped) {
      self.dragging_node = Some(node.id)
      self.drag_start_x = x
      self.drag_start_y = y
      let drag_event = PointerEvent::new(x, y, button, node.id)
      self.dispatch_to_node(node.id, DragStart, drag_event)
    }
    if event.propagation_stopped {
      break
    }
  }
}

///|
/// Dispatch mouse up event
pub fn EventManager::dispatch_mouse_up(
  self : EventManager,
  x : Double,
  y : Double,
  button : Int,
  scene : Scene,
) -> Unit {
  // End drag if dragging
  match self.dragging_node {
    Some(node_id) => {
      let event = PointerEvent::new(x, y, button, node_id)
      self.dispatch_to_node(node_id, DragEnd, event)
      self.dragging_node = None
    }
    None => ()
  }
  // Dispatch mouse up
  let hit_nodes = scene.root.hit_test_all(x, y)
  for node in hit_nodes {
    let event = PointerEvent::new(x, y, button, node.id)
    self.dispatch_to_node(node.id, MouseUp, event)
    if event.propagation_stopped {
      break
    }
  }
}

///|
/// Dispatch mouse move event (handles hover and drag)
pub fn EventManager::dispatch_mouse_move(
  self : EventManager,
  x : Double,
  y : Double,
  scene : Scene,
) -> Unit {
  // Handle drag
  match self.dragging_node {
    Some(node_id) => {
      let event = PointerEvent::new(x, y, 0, node_id)
      self.dispatch_to_node(node_id, DragMove, event)
    }
    None => ()
  }
  // Handle hover (enter/leave)
  let hit_nodes = scene.root.hit_test_all(x, y)
  let new_hovered = if hit_nodes.length() > 0 {
    Some(hit_nodes[0].id)
  } else {
    None
  }
  // Check for mouse leave
  match (self.hovered_node, new_hovered) {
    (Some(old_id), Some(new_id)) =>
      if old_id != new_id {
        let leave_event = PointerEvent::new(x, y, 0, old_id)
        self.dispatch_to_node(old_id, MouseLeave, leave_event)
        let enter_event = PointerEvent::new(x, y, 0, new_id)
        self.dispatch_to_node(new_id, MouseEnter, enter_event)
      }
    (Some(old_id), None) => {
      let leave_event = PointerEvent::new(x, y, 0, old_id)
      self.dispatch_to_node(old_id, MouseLeave, leave_event)
    }
    (None, Some(new_id)) => {
      let enter_event = PointerEvent::new(x, y, 0, new_id)
      self.dispatch_to_node(new_id, MouseEnter, enter_event)
    }
    (None, None) => ()
  }
  self.hovered_node = new_hovered
  // Dispatch mouse move to hovered node
  match new_hovered {
    Some(node_id) => {
      let event = PointerEvent::new(x, y, 0, node_id)
      self.dispatch_to_node(node_id, MouseMove, event)
    }
    None => ()
  }
}

///|
fn EventManager::dispatch_to_node(
  self : EventManager,
  node_id : String,
  event_type : EventType,
  event : PointerEvent,
) -> Unit {
  match self.listeners.get(node_id) {
    Some(listeners) =>
      for listener in listeners {
        if listener.event_type == event_type {
          (listener.handler.call)(event)
        }
      }
    None => ()
  }
}

// ============================================================================
// Collision Detection
// ============================================================================

///|
/// Check collision between two circles
pub fn collide_circle_circle(
  cx1 : Double,
  cy1 : Double,
  r1 : Double,
  cx2 : Double,
  cy2 : Double,
  r2 : Double,
) -> Bool {
  let dx = cx2 - cx1
  let dy = cy2 - cy1
  let dist_sq = dx * dx + dy * dy
  let radii_sum = r1 + r2
  dist_sq <= radii_sum * radii_sum
}

///|
/// Check collision between two axis-aligned rectangles
pub fn collide_rect_rect(
  x1 : Double,
  y1 : Double,
  w1 : Double,
  h1 : Double,
  x2 : Double,
  y2 : Double,
  w2 : Double,
  h2 : Double,
) -> Bool {
  x1 < x2 + w2 && x1 + w1 > x2 && y1 < y2 + h2 && y1 + h1 > y2
}

///|
/// Check collision between circle and rectangle
pub fn collide_circle_rect(
  cx : Double,
  cy : Double,
  r : Double,
  rx : Double,
  ry : Double,
  rw : Double,
  rh : Double,
) -> Bool {
  // Find the closest point on the rectangle to the circle center
  let closest_x = if cx < rx { rx } else if cx > rx + rw { rx + rw } else { cx }
  let closest_y = if cy < ry { ry } else if cy > ry + rh { ry + rh } else { cy }
  // Check if the closest point is within the circle
  let dx = cx - closest_x
  let dy = cy - closest_y
  dx * dx + dy * dy <= r * r
}

///|
/// Check collision between two shapes
pub fn collide_shapes(shape1 : Shape, shape2 : Shape) -> Bool {
  match (shape1, shape2) {
    (Circle(cx~, cy~, r~), Circle(..)) => {
      let (cx2, cy2, r2) = match shape2 {
        Circle(cx~, cy~, r~) => (cx, cy, r)
        _ => (0.0, 0.0, 0.0)
      }
      collide_circle_circle(cx, cy, r, cx2, cy2, r2)
    }
    (Rect(x~, y~, width~, height~, ..), Rect(..)) => {
      let (x2, y2, w2, h2) = match shape2 {
        Rect(x~, y~, width~, height~, ..) => (x, y, width, height)
        _ => (0.0, 0.0, 0.0, 0.0)
      }
      collide_rect_rect(x, y, width, height, x2, y2, w2, h2)
    }
    (Circle(cx~, cy~, r~), Rect(x~, y~, width~, height~, ..)) =>
      collide_circle_rect(cx, cy, r, x, y, width, height)
    (Rect(x~, y~, width~, height~, ..), Circle(cx~, cy~, r~)) =>
      collide_circle_rect(cx, cy, r, x, y, width, height)
    (Ellipse(cx~, cy~, rx~, ry~), Ellipse(..)) => {
      // Approximate with average radius
      let r1 = (rx + ry) / 2.0
      let (cx2, cy2, r2) = match shape2 {
        Ellipse(cx~, cy~, rx~, ry~) => (cx, cy, (rx + ry) / 2.0)
        _ => (0.0, 0.0, 0.0)
      }
      collide_circle_circle(cx, cy, r1, cx2, cy2, r2)
    }
    _ => {
      // Fall back to bounding box collision for other shapes
      let bbox1 = get_shape_bbox(shape1)
      let bbox2 = get_shape_bbox(shape2)
      bbox1.intersects(bbox2)
    }
  }
}

///|
/// Get bounding box for a shape
fn get_shape_bbox(shape : Shape) -> BoundingBox {
  match shape {
    Rect(x~, y~, width~, height~, ..) =>
      BoundingBox::from_rect(x, y, width, height)
    Circle(cx~, cy~, r~) =>
      BoundingBox::from_rect(cx - r, cy - r, r * 2.0, r * 2.0)
    Ellipse(cx~, cy~, rx~, ry~) =>
      BoundingBox::from_rect(cx - rx, cy - ry, rx * 2.0, ry * 2.0)
    Line(x1~, y1~, x2~, y2~) => {
      let min_x = if x1 < x2 { x1 } else { x2 }
      let max_x = if x1 > x2 { x1 } else { x2 }
      let min_y = if y1 < y2 { y1 } else { y2 }
      let max_y = if y1 > y2 { y1 } else { y2 }
      { min_x, min_y, max_x, max_y }
    }
    Polyline(points~) | Polygon(points~) => {
      if points.is_empty() {
        return BoundingBox::empty()
      }
      let mut min_x = points[0].0
      let mut max_x = points[0].0
      let mut min_y = points[0].1
      let mut max_y = points[0].1
      for p in points {
        if p.0 < min_x {
          min_x = p.0
        }
        if p.0 > max_x {
          max_x = p.0
        }
        if p.1 < min_y {
          min_y = p.1
        }
        if p.1 > max_y {
          max_y = p.1
        }
      }
      { min_x, min_y, max_x, max_y }
    }
    _ => BoundingBox::empty()
  }
}

///|
/// Check collision between two SVGNodes (considering transforms)
pub fn SVGNode::collides_with(self : SVGNode, other : SVGNode) -> Bool {
  // Get transformed bounding boxes for quick rejection
  let bbox1 = self.transform.apply_bbox(get_shape_bbox(self.shape))
  let bbox2 = other.transform.apply_bbox(get_shape_bbox(other.shape))
  if not(bbox1.intersects(bbox2)) {
    return false
  }
  // For now, use bounding box collision
  // More precise collision would require transforming shapes
  true
}

// ============================================================================
// Object Pooling
// ============================================================================

///|
/// Generic object pool for reusing objects
pub(all) struct ObjectPool[T] {
  available : Array[T]
  factory : () -> T
  reset : (T) -> Unit
}

///|
pub fn[T] ObjectPool::new(
  factory : () -> T,
  reset : (T) -> Unit,
  initial_size : Int,
) -> ObjectPool[T] {
  let pool : ObjectPool[T] = { available: [], factory, reset }
  for i = 0; i < initial_size; i = i + 1 {
    pool.available.push(factory())
  }
  pool
}

///|
/// Acquire an object from the pool
pub fn[T] ObjectPool::acquire(self : ObjectPool[T]) -> T {
  if self.available.is_empty() {
    (self.factory)()
  } else {
    self.available.pop().unwrap()
  }
}

///|
/// Release an object back to the pool
pub fn[T] ObjectPool::release(self : ObjectPool[T], obj : T) -> Unit {
  (self.reset)(obj)
  self.available.push(obj)
}

///|
/// Get the number of available objects
pub fn[T] ObjectPool::available_count(self : ObjectPool[T]) -> Int {
  self.available.length()
}

// ============================================================================
// RadialGradient
// ============================================================================

///|
/// Radial gradient definition
pub(all) struct RadialGradient {
  cx : Double // Center x (0.0-1.0 relative)
  cy : Double // Center y
  fx : Double // Focal point x
  fy : Double // Focal point y
  r : Double // Radius
  stops : Array[GradientStop]
  spread_method : SpreadMethod
}

///|
pub fn RadialGradient::new(
  cx : Double,
  cy : Double,
  r : Double,
  stops : Array[GradientStop],
) -> RadialGradient {
  { cx, cy, fx: cx, fy: cy, r, stops, spread_method: Pad }
}

///|
/// Get color at a point (px, py) relative to the gradient bounds
pub fn RadialGradient::color_at(
  self : RadialGradient,
  px : Double,
  py : Double,
  width : Double,
  height : Double,
) -> Color {
  // Convert to gradient space
  let gx = self.cx * width
  let gy = self.cy * height
  let gr = self.r * (if width < height { width } else { height })
  // Distance from center
  let dx = px - gx
  let dy = py - gy
  let dist = (dx * dx + dy * dy).sqrt()
  // Normalized position (0.0 at center, 1.0 at radius)
  let mut t = if gr > 0.0 { dist / gr } else { 0.0 }
  // Apply spread method
  t = apply_spread(t, self.spread_method)
  // Interpolate color
  interpolate_gradient_color(t, self.stops)
}

///|
fn apply_spread(t : Double, spread : SpreadMethod) -> Double {
  match spread {
    Pad => if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
    Repeat => t - t.floor()
    Reflect => {
      let t2 = t - t.floor()
      if t.to_int() % 2 == 0 {
        t2
      } else {
        1.0 - t2
      }
    }
  }
}

///|
fn interpolate_gradient_color(t : Double, stops : Array[GradientStop]) -> Color {
  if stops.is_empty() {
    return Color::black()
  }
  if stops.length() == 1 {
    return stops[0].color
  }
  // Find surrounding stops
  let mut prev_stop = stops[0]
  let mut next_stop = stops[stops.length() - 1]
  for stop in stops {
    if stop.offset <= t {
      prev_stop = stop
    }
    if stop.offset >= t && next_stop.offset < stop.offset {
      next_stop = stop
    }
  }
  for stop in stops {
    if stop.offset >= t {
      next_stop = stop
      break
    }
  }
  // Interpolate
  if prev_stop.offset >= next_stop.offset {
    return prev_stop.color
  }
  let local_t = (t - prev_stop.offset) / (next_stop.offset - prev_stop.offset)
  lerp_color(prev_stop.color, next_stop.color, local_t)
}

// ============================================================================
// Particle System
// ============================================================================

///|
/// Single particle state
pub(all) struct Particle {
  mut x : Double
  mut y : Double
  mut vx : Double // Velocity x
  mut vy : Double // Velocity y
  mut life : Double // Remaining life (seconds)
  mut max_life : Double // Initial life
  mut size : Double
  mut color : Color
  mut active : Bool
}

///|
pub fn Particle::new() -> Particle {
  {
    x: 0.0,
    y: 0.0,
    vx: 0.0,
    vy: 0.0,
    life: 0.0,
    max_life: 1.0,
    size: 5.0,
    color: Color::white(),
    active: false,
  }
}

///|
/// Particle emitter configuration
pub(all) struct EmitterConfig {
  emit_rate : Double // Particles per second
  life_min : Double // Minimum particle life
  life_max : Double // Maximum particle life
  speed_min : Double // Minimum initial speed
  speed_max : Double // Maximum initial speed
  angle_min : Double // Minimum emission angle (radians)
  angle_max : Double // Maximum emission angle
  size_start : Double // Initial size
  size_end : Double // Final size (interpolated)
  color_start : Color
  color_end : Color
  gravity_x : Double
  gravity_y : Double
}

///|
pub fn EmitterConfig::default() -> EmitterConfig {
  {
    emit_rate: 10.0,
    life_min: 0.5,
    life_max: 2.0,
    speed_min: 50.0,
    speed_max: 100.0,
    angle_min: 0.0,
    angle_max: 6.28318, // 2π
    size_start: 10.0,
    size_end: 2.0,
    color_start: Color::white(),
    color_end: Color::transparent(),
    gravity_x: 0.0,
    gravity_y: 0.0,
  }
}

///|
/// Particle emitter
pub(all) struct ParticleEmitter {
  x : Double
  y : Double
  config : EmitterConfig
  particles : Array[Particle]
  mut emit_accumulator : Double
  mut active : Bool
}

///|
pub fn ParticleEmitter::new(
  x : Double,
  y : Double,
  config : EmitterConfig,
  max_particles : Int,
) -> ParticleEmitter {
  let particles : Array[Particle] = []
  for i = 0; i < max_particles; i = i + 1 {
    particles.push(Particle::new())
  }
  { x, y, config, particles, emit_accumulator: 0.0, active: true }
}

///|
/// Update particles with delta time
pub fn ParticleEmitter::update(self : ParticleEmitter, dt : Double) -> Unit {
  // Emit new particles
  if self.active {
    self.emit_accumulator = self.emit_accumulator + dt * self.config.emit_rate
    while self.emit_accumulator >= 1.0 {
      self.emit_one()
      self.emit_accumulator = self.emit_accumulator - 1.0
    }
  }
  // Update existing particles
  for p in self.particles {
    if p.active {
      // Apply velocity
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      // Apply gravity
      p.vx = p.vx + self.config.gravity_x * dt
      p.vy = p.vy + self.config.gravity_y * dt
      // Update life
      p.life = p.life - dt
      if p.life <= 0.0 {
        p.active = false
      } else {
        // Interpolate size and color based on life
        let t = 1.0 - p.life / p.max_life
        p.size = lerp(self.config.size_start, self.config.size_end, t)
        p.color = lerp_color(self.config.color_start, self.config.color_end, t)
      }
    }
  }
}

///|
fn ParticleEmitter::emit_one(self : ParticleEmitter) -> Unit {
  // Find inactive particle
  for p in self.particles {
    if not(p.active) {
      p.active = true
      p.x = self.x
      p.y = self.y
      // Random life
      p.life = random_range(self.config.life_min, self.config.life_max)
      p.max_life = p.life
      // Random angle and speed
      let angle = random_range(self.config.angle_min, self.config.angle_max)
      let speed = random_range(self.config.speed_min, self.config.speed_max)
      p.vx = @math.cos(angle) * speed
      p.vy = @math.sin(angle) * speed
      // Initial size and color
      p.size = self.config.size_start
      p.color = self.config.color_start
      return
    }
  }
}

///|
/// Simple pseudo-random number generator
pub(all) struct SimpleRNG {
  mut state : Int
}

///|
pub fn SimpleRNG::new(seed : Int) -> SimpleRNG {
  { state: seed }
}

///|
pub fn SimpleRNG::next(self : SimpleRNG) -> Double {
  // Linear congruential generator
  self.state = (self.state * 1103515245 + 12345) & 0x7FFFFFFF
  self.state.to_double() / 2147483647.0
}

///|
pub fn SimpleRNG::range(self : SimpleRNG, min : Double, max : Double) -> Double {
  let t = self.next()
  min + t * (max - min)
}

///|
/// Default global RNG instance
let default_rng : SimpleRNG = SimpleRNG::new(12345)

///|
fn random_range(min : Double, max : Double) -> Double {
  default_rng.range(min, max)
}

///|
/// Get active particle count
pub fn ParticleEmitter::active_count(self : ParticleEmitter) -> Int {
  let mut count = 0
  for p in self.particles {
    if p.active {
      count = count + 1
    }
  }
  count
}

// ============================================================================
// Path Animation
// ============================================================================

///|
/// Path follower for animating along a path
pub(all) struct PathFollower {
  path : Array[PathCommand]
  polyline : Array[(Double, Double)] // Flattened path points
  lengths : Array[Double] // Cumulative lengths
  total_length : Double
  mut progress : Double // 0.0 to 1.0
  mut loop_anim : Bool
}

///|
pub fn PathFollower::new(path_data : String) -> PathFollower {
  let path = parse_path(path_data)
  let polyline = flatten_path(path)
  let (lengths, total) = compute_path_lengths(polyline)
  {
    path,
    polyline,
    lengths,
    total_length: total,
    progress: 0.0,
    loop_anim: false,
  }
}

///|
fn flatten_path(path : Array[PathCommand]) -> Array[(Double, Double)] {
  // Simplified flattening - converts path to line segments
  let points : Array[(Double, Double)] = []
  let mut cx = 0.0
  let mut cy = 0.0
  for cmd in path {
    match cmd {
      MoveTo(x, y) => {
        cx = x
        cy = y
        points.push((cx, cy))
      }
      LineTo(x, y) => {
        cx = x
        cy = y
        points.push((cx, cy))
      }
      MoveToRel(dx, dy) => {
        cx = cx + dx
        cy = cy + dy
        points.push((cx, cy))
      }
      LineToRel(dx, dy) => {
        cx = cx + dx
        cy = cy + dy
        points.push((cx, cy))
      }
      HorizontalLineTo(x) => {
        cx = x
        points.push((cx, cy))
      }
      VerticalLineTo(y) => {
        cy = y
        points.push((cx, cy))
      }
      ClosePath => if points.length() > 0 { points.push(points[0]) }
      _ => () // Skip complex curves for now
    }
  }
  points
}

///|
fn compute_path_lengths(
  points : Array[(Double, Double)],
) -> (Array[Double], Double) {
  let lengths : Array[Double] = [0.0]
  let mut total = 0.0
  for i = 1; i < points.length(); i = i + 1 {
    let dx = points[i].0 - points[i - 1].0
    let dy = points[i].1 - points[i - 1].1
    total = total + (dx * dx + dy * dy).sqrt()
    lengths.push(total)
  }
  (lengths, total)
}

///|
/// Get position at current progress
pub fn PathFollower::get_position(self : PathFollower) -> (Double, Double) {
  if self.polyline.is_empty() {
    return (0.0, 0.0)
  }
  if self.total_length <= 0.0 {
    return self.polyline[0]
  }
  let target_len = self.progress * self.total_length
  // Find segment
  for i = 1; i < self.lengths.length(); i = i + 1 {
    if self.lengths[i] >= target_len {
      let prev_len = self.lengths[i - 1]
      let seg_len = self.lengths[i] - prev_len
      if seg_len <= 0.0 {
        return self.polyline[i - 1]
      }
      let t = (target_len - prev_len) / seg_len
      let (x1, y1) = self.polyline[i - 1]
      let (x2, y2) = self.polyline[i]
      return (lerp(x1, x2, t), lerp(y1, y2, t))
    }
  }
  self.polyline[self.polyline.length() - 1]
}

///|
/// Update progress with delta time and speed
pub fn PathFollower::update(
  self : PathFollower,
  dt : Double,
  speed : Double,
) -> Bool {
  if self.total_length <= 0.0 {
    return false
  }
  self.progress = self.progress + dt * speed / self.total_length
  if self.progress >= 1.0 {
    if self.loop_anim {
      self.progress = self.progress - 1.0
      true
    } else {
      self.progress = 1.0
      false
    }
  } else {
    true
  }
}

// ============================================================================
// Blend Modes (mix-blend-mode / isolation)
// ============================================================================

///|
/// CSS mix-blend-mode values
pub(all) enum BlendMode {
  Normal
  Multiply
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  HardLight
  SoftLight
  Difference
  Exclusion
  Hue
  Saturation
  ColorMode // 'color' in CSS
  Luminosity
} derive(Show, Eq)

///|
/// CSS isolation values
pub(all) enum Isolation {
  Auto
  Isolate
} derive(Show, Eq)

///|
/// Blend two colors using the specified blend mode
pub fn blend_with_mode(
  backdrop : Color,
  source : Color,
  mode : BlendMode,
) -> Color {
  let bd_r = backdrop.r.to_double() / 255.0
  let bd_g = backdrop.g.to_double() / 255.0
  let bd_b = backdrop.b.to_double() / 255.0
  let bd_a = backdrop.a.to_double() / 255.0
  let src_r = source.r.to_double() / 255.0
  let src_g = source.g.to_double() / 255.0
  let src_b = source.b.to_double() / 255.0
  let src_a = source.a.to_double() / 255.0
  // Apply blend mode to RGB
  let (blended_r, blended_g, blended_b) = match mode {
    Normal => (src_r, src_g, src_b)
    Multiply => (bd_r * src_r, bd_g * src_g, bd_b * src_b)
    Screen =>
      (
        1.0 - (1.0 - bd_r) * (1.0 - src_r),
        1.0 - (1.0 - bd_g) * (1.0 - src_g),
        1.0 - (1.0 - bd_b) * (1.0 - src_b),
      )
    Overlay =>
      (
        blend_overlay_channel(bd_r, src_r),
        blend_overlay_channel(bd_g, src_g),
        blend_overlay_channel(bd_b, src_b),
      )
    Darken =>
      (
        if bd_r < src_r {
          bd_r
        } else {
          src_r
        },
        if bd_g < src_g {
          bd_g
        } else {
          src_g
        },
        if bd_b < src_b {
          bd_b
        } else {
          src_b
        },
      )
    Lighten =>
      (
        if bd_r > src_r {
          bd_r
        } else {
          src_r
        },
        if bd_g > src_g {
          bd_g
        } else {
          src_g
        },
        if bd_b > src_b {
          bd_b
        } else {
          src_b
        },
      )
    ColorDodge =>
      (
        blend_color_dodge_channel(bd_r, src_r),
        blend_color_dodge_channel(bd_g, src_g),
        blend_color_dodge_channel(bd_b, src_b),
      )
    ColorBurn =>
      (
        blend_color_burn_channel(bd_r, src_r),
        blend_color_burn_channel(bd_g, src_g),
        blend_color_burn_channel(bd_b, src_b),
      )
    HardLight =>
      (
        blend_overlay_channel(src_r, bd_r), // HardLight is Overlay with args swapped
        blend_overlay_channel(src_g, bd_g),
        blend_overlay_channel(src_b, bd_b),
      )
    SoftLight =>
      (
        blend_soft_light_channel(bd_r, src_r),
        blend_soft_light_channel(bd_g, src_g),
        blend_soft_light_channel(bd_b, src_b),
      )
    Difference =>
      ((bd_r - src_r).abs(), (bd_g - src_g).abs(), (bd_b - src_b).abs())
    Exclusion =>
      (
        bd_r + src_r - 2.0 * bd_r * src_r,
        bd_g + src_g - 2.0 * bd_g * src_g,
        bd_b + src_b - 2.0 * bd_b * src_b,
      )
    Hue => blend_hue(bd_r, bd_g, bd_b, src_r, src_g, src_b)
    Saturation => blend_saturation(bd_r, bd_g, bd_b, src_r, src_g, src_b)
    ColorMode => blend_color_mode(bd_r, bd_g, bd_b, src_r, src_g, src_b)
    Luminosity => blend_luminosity(bd_r, bd_g, bd_b, src_r, src_g, src_b)
  }
  // Porter-Duff compositing with source-over
  let out_a = src_a + bd_a * (1.0 - src_a)
  if out_a < 0.001 {
    return Color::transparent()
  }
  let out_r = (src_a * blended_r + bd_a * bd_r * (1.0 - src_a)) / out_a
  let out_g = (src_a * blended_g + bd_a * bd_g * (1.0 - src_a)) / out_a
  let out_b = (src_a * blended_b + bd_a * bd_b * (1.0 - src_a)) / out_a
  Color::rgba(
    clamp_int((out_r * 255.0).to_int(), 0, 255),
    clamp_int((out_g * 255.0).to_int(), 0, 255),
    clamp_int((out_b * 255.0).to_int(), 0, 255),
    clamp_int((out_a * 255.0).to_int(), 0, 255),
  )
}

///|
/// Overlay blend for a single channel
fn blend_overlay_channel(backdrop : Double, source : Double) -> Double {
  if backdrop < 0.5 {
    2.0 * backdrop * source
  } else {
    1.0 - 2.0 * (1.0 - backdrop) * (1.0 - source)
  }
}

///|
/// Color dodge blend for a single channel
fn blend_color_dodge_channel(backdrop : Double, source : Double) -> Double {
  if backdrop < 0.001 {
    0.0
  } else if source >= 0.999 {
    1.0
  } else {
    let result = backdrop / (1.0 - source)
    if result > 1.0 {
      1.0
    } else {
      result
    }
  }
}

///|
/// Color burn blend for a single channel
fn blend_color_burn_channel(backdrop : Double, source : Double) -> Double {
  if backdrop >= 0.999 {
    1.0
  } else if source < 0.001 {
    0.0
  } else {
    let result = 1.0 - (1.0 - backdrop) / source
    if result < 0.0 {
      0.0
    } else {
      result
    }
  }
}

///|
/// Soft light blend for a single channel
fn blend_soft_light_channel(backdrop : Double, source : Double) -> Double {
  if source <= 0.5 {
    backdrop - (1.0 - 2.0 * source) * backdrop * (1.0 - backdrop)
  } else {
    let d = if backdrop <= 0.25 {
      ((16.0 * backdrop - 12.0) * backdrop + 4.0) * backdrop
    } else {
      sqrt_approx(backdrop)
    }
    backdrop + (2.0 * source - 1.0) * (d - backdrop)
  }
}

///|
/// Approximate square root
fn sqrt_approx(x : Double) -> Double {
  if x < 0.0 {
    return 0.0
  }
  // Newton-Raphson iteration
  let mut guess = x / 2.0
  if guess < 0.001 {
    guess = 0.001
  }
  for _i = 0; _i < 10; _i = _i + 1 {
    guess = (guess + x / guess) / 2.0
  }
  guess
}

///|
/// Convert RGB to HSL
fn rgb_to_hsl(r : Double, g : Double, b : Double) -> (Double, Double, Double) {
  let max_val = if r > g {
    if r > b {
      r
    } else {
      b
    }
  } else if g > b {
    g
  } else {
    b
  }
  let min_val = if r < g {
    if r < b {
      r
    } else {
      b
    }
  } else if g < b {
    g
  } else {
    b
  }
  let l = (max_val + min_val) / 2.0
  if max_val - min_val < 0.001 {
    return (0.0, 0.0, l) // Achromatic
  }
  let d = max_val - min_val
  let s = if l > 0.5 {
    d / (2.0 - max_val - min_val)
  } else {
    d / (max_val + min_val)
  }
  let h = if max_val - r < 0.001 {
    let h_raw = (g - b) / d
    if g < b {
      h_raw + 6.0
    } else {
      h_raw
    }
  } else if max_val - g < 0.001 {
    (b - r) / d + 2.0
  } else {
    (r - g) / d + 4.0
  }
  (h / 6.0, s, l)
}

///|
/// Convert HSL to RGB
fn hsl_to_rgb(h : Double, s : Double, l : Double) -> (Double, Double, Double) {
  if s < 0.001 {
    return (l, l, l)
  }
  let q = if l < 0.5 { l * (1.0 + s) } else { l + s - l * s }
  let p = 2.0 * l - q
  (
    hue_to_rgb(p, q, h + 1.0 / 3.0),
    hue_to_rgb(p, q, h),
    hue_to_rgb(p, q, h - 1.0 / 3.0),
  )
}

///|
fn hue_to_rgb(p : Double, q : Double, t_raw : Double) -> Double {
  let mut t = t_raw
  if t < 0.0 {
    t = t + 1.0
  }
  if t > 1.0 {
    t = t - 1.0
  }
  if t < 1.0 / 6.0 {
    return p + (q - p) * 6.0 * t
  }
  if t < 0.5 {
    return q
  }
  if t < 2.0 / 3.0 {
    return p + (q - p) * (2.0 / 3.0 - t) * 6.0
  }
  p
}

///|
/// Get luminosity of RGB
fn get_luminosity(r : Double, g : Double, b : Double) -> Double {
  0.3 * r + 0.59 * g + 0.11 * b
}

///|
/// Set luminosity of RGB
fn set_luminosity(
  r : Double,
  g : Double,
  b : Double,
  target_lum : Double,
) -> (Double, Double, Double) {
  let current_lum = get_luminosity(r, g, b)
  let d = target_lum - current_lum
  clip_color(r + d, g + d, b + d)
}

///|
/// Clip color to valid range
fn clip_color(r : Double, g : Double, b : Double) -> (Double, Double, Double) {
  let lum = get_luminosity(r, g, b)
  let min_val = if r < g {
    if r < b {
      r
    } else {
      b
    }
  } else if g < b {
    g
  } else {
    b
  }
  let max_val = if r > g {
    if r > b {
      r
    } else {
      b
    }
  } else if g > b {
    g
  } else {
    b
  }
  let mut out_r = r
  let mut out_g = g
  let mut out_b = b
  if min_val < 0.0 && lum - min_val > 0.001 {
    let factor = lum / (lum - min_val)
    out_r = lum + (out_r - lum) * factor
    out_g = lum + (out_g - lum) * factor
    out_b = lum + (out_b - lum) * factor
  }
  if max_val > 1.0 && max_val - lum > 0.001 {
    let factor = (1.0 - lum) / (max_val - lum)
    out_r = lum + (out_r - lum) * factor
    out_g = lum + (out_g - lum) * factor
    out_b = lum + (out_b - lum) * factor
  }
  (out_r, out_g, out_b)
}

///|
/// Hue blend mode
fn blend_hue(
  bd_r : Double,
  bd_g : Double,
  bd_b : Double,
  src_r : Double,
  src_g : Double,
  src_b : Double,
) -> (Double, Double, Double) {
  let (src_h, _, _) = rgb_to_hsl(src_r, src_g, src_b)
  let (_, bd_s, bd_l) = rgb_to_hsl(bd_r, bd_g, bd_b)
  let (r, g, b) = hsl_to_rgb(src_h, bd_s, bd_l)
  set_luminosity(r, g, b, get_luminosity(bd_r, bd_g, bd_b))
}

///|
/// Saturation blend mode
fn blend_saturation(
  bd_r : Double,
  bd_g : Double,
  bd_b : Double,
  src_r : Double,
  src_g : Double,
  src_b : Double,
) -> (Double, Double, Double) {
  let (bd_h, _, bd_l) = rgb_to_hsl(bd_r, bd_g, bd_b)
  let (_, src_s, _) = rgb_to_hsl(src_r, src_g, src_b)
  let (r, g, b) = hsl_to_rgb(bd_h, src_s, bd_l)
  set_luminosity(r, g, b, get_luminosity(bd_r, bd_g, bd_b))
}

///|
/// Color blend mode
fn blend_color_mode(
  bd_r : Double,
  bd_g : Double,
  bd_b : Double,
  src_r : Double,
  src_g : Double,
  src_b : Double,
) -> (Double, Double, Double) {
  let (src_h, src_s, _) = rgb_to_hsl(src_r, src_g, src_b)
  let (_, _, bd_l) = rgb_to_hsl(bd_r, bd_g, bd_b)
  let (r, g, b) = hsl_to_rgb(src_h, src_s, bd_l)
  set_luminosity(r, g, b, get_luminosity(bd_r, bd_g, bd_b))
}

///|
/// Luminosity blend mode
fn blend_luminosity(
  bd_r : Double,
  bd_g : Double,
  bd_b : Double,
  src_r : Double,
  src_g : Double,
  src_b : Double,
) -> (Double, Double, Double) {
  set_luminosity(bd_r, bd_g, bd_b, get_luminosity(src_r, src_g, src_b))
}

///|
/// Blend two images using the specified blend mode
pub fn blend_images(
  backdrop : Image,
  source : Image,
  mode : BlendMode,
) -> Image {
  let width = if backdrop.width < source.width {
    backdrop.width
  } else {
    source.width
  }
  let height = if backdrop.height < source.height {
    backdrop.height
  } else {
    source.height
  }
  let result = Image::new(width, height)
  for y = 0; y < height; y = y + 1 {
    for x = 0; x < width; x = x + 1 {
      let bd_color = backdrop.get_pixel(x, y)
      let src_color = source.get_pixel(x, y)
      let blended = blend_with_mode(bd_color, src_color, mode)
      result.set_pixel(x, y, blended)
    }
  }
  result
}

// ============================================================================
// Filter Effects
// ============================================================================

///|
/// Filter types
pub(all) enum Filter {
  Blur(Double) // Blur radius
  DropShadow(Double, Double, Double, Color) // offsetX, offsetY, blur, color
  Brightness(Double) // Factor (1.0 = normal)
  Contrast(Double) // Factor (1.0 = normal)
  Grayscale(Double) // Amount (0.0-1.0)
  Sepia(Double) // Amount (0.0-1.0)
  HueRotate(Double) // Angle in degrees
  Invert(Double) // Amount (0.0-1.0)
  Saturate(Double) // Factor (1.0 = normal, 0.0 = grayscale, 2.0 = double)
  ColorMatrix(FixedArray[Double]) // 5x4 matrix (20 values) for feColorMatrix
}

///|
/// Apply blur filter to a region of pixels
pub fn apply_blur(
  pixels : Array[Array[Color]],
  radius : Int,
) -> Array[Array[Color]] {
  if radius <= 0 || pixels.is_empty() {
    return pixels
  }
  let height = pixels.length()
  let width = if height > 0 { pixels[0].length() } else { 0 }
  // Create output buffer
  let output : Array[Array[Color]] = []
  for i = 0; i < height; i = i + 1 {
    let row : Array[Color] = []
    for j = 0; j < width; j = j + 1 {
      row.push(Color::black())
    }
    output.push(row)
  }
  // Box blur (simplified)
  let kernel_size = radius * 2 + 1
  let div = kernel_size * kernel_size
  for y = 0; y < height; y = y + 1 {
    for x = 0; x < width; x = x + 1 {
      let mut r = 0
      let mut g = 0
      let mut b = 0
      let mut a = 0
      for ky = -radius; ky <= radius; ky = ky + 1 {
        for kx = -radius; kx <= radius; kx = kx + 1 {
          let sy = clamp_int(y + ky, 0, height - 1)
          let sx = clamp_int(x + kx, 0, width - 1)
          let c = pixels[sy][sx]
          r = r + c.r
          g = g + c.g
          b = b + c.b
          a = a + c.a
        }
      }
      output[y][x] = { r: r / div, g: g / div, b: b / div, a: a / div }
    }
  }
  output
}

///|
fn clamp_int(v : Int, min : Int, max : Int) -> Int {
  if v < min {
    min
  } else if v > max {
    max
  } else {
    v
  }
}

///|
/// Apply brightness filter to a color
pub fn apply_brightness(color : Color, factor : Double) -> Color {
  {
    r: clamp_int((color.r.to_double() * factor).to_int(), 0, 255),
    g: clamp_int((color.g.to_double() * factor).to_int(), 0, 255),
    b: clamp_int((color.b.to_double() * factor).to_int(), 0, 255),
    a: color.a,
  }
}

///|
/// Apply grayscale filter to a color
pub fn apply_grayscale(color : Color, amount : Double) -> Color {
  let gray = (color.r.to_double() * 0.299 +
  color.g.to_double() * 0.587 +
  color.b.to_double() * 0.114).to_int()
  {
    r: lerp(color.r.to_double(), gray.to_double(), amount).to_int(),
    g: lerp(color.g.to_double(), gray.to_double(), amount).to_int(),
    b: lerp(color.b.to_double(), gray.to_double(), amount).to_int(),
    a: color.a,
  }
}

///|
/// Apply contrast filter to a color
pub fn apply_contrast(color : Color, factor : Double) -> Color {
  // Contrast formula: ((value - 128) * factor) + 128
  let r = ((color.r.to_double() - 128.0) * factor + 128.0).to_int()
  let g = ((color.g.to_double() - 128.0) * factor + 128.0).to_int()
  let b = ((color.b.to_double() - 128.0) * factor + 128.0).to_int()
  {
    r: clamp_int(r, 0, 255),
    g: clamp_int(g, 0, 255),
    b: clamp_int(b, 0, 255),
    a: color.a,
  }
}

///|
/// Apply sepia filter to a color
pub fn apply_sepia(color : Color, amount : Double) -> Color {
  // Sepia matrix coefficients
  let r = color.r.to_double()
  let g = color.g.to_double()
  let b = color.b.to_double()
  // Sepia tone calculation
  let sepia_r = r * 0.393 + g * 0.769 + b * 0.189
  let sepia_g = r * 0.349 + g * 0.686 + b * 0.168
  let sepia_b = r * 0.272 + g * 0.534 + b * 0.131
  // Interpolate between original and sepia
  {
    r: clamp_int(lerp(r, sepia_r, amount).to_int(), 0, 255),
    g: clamp_int(lerp(g, sepia_g, amount).to_int(), 0, 255),
    b: clamp_int(lerp(b, sepia_b, amount).to_int(), 0, 255),
    a: color.a,
  }
}

///|
/// Apply hue rotation to a color
pub fn apply_hue_rotate(color : Color, angle_degrees : Double) -> Color {
  // Convert to radians
  let angle = angle_degrees * 3.14159265358979 / 180.0
  let cos_a = cos_approx(angle)
  let sin_a = sin_approx(angle)
  let r = color.r.to_double() / 255.0
  let g = color.g.to_double() / 255.0
  let b = color.b.to_double() / 255.0
  // Hue rotation matrix (based on SVG spec)
  let matrix_00 = 0.213 + cos_a * 0.787 - sin_a * 0.213
  let matrix_01 = 0.715 - cos_a * 0.715 - sin_a * 0.715
  let matrix_02 = 0.072 - cos_a * 0.072 + sin_a * 0.928
  let matrix_10 = 0.213 - cos_a * 0.213 + sin_a * 0.143
  let matrix_11 = 0.715 + cos_a * 0.285 + sin_a * 0.140
  let matrix_12 = 0.072 - cos_a * 0.072 - sin_a * 0.283
  let matrix_20 = 0.213 - cos_a * 0.213 - sin_a * 0.787
  let matrix_21 = 0.715 - cos_a * 0.715 + sin_a * 0.715
  let matrix_22 = 0.072 + cos_a * 0.928 + sin_a * 0.072
  let new_r = r * matrix_00 + g * matrix_01 + b * matrix_02
  let new_g = r * matrix_10 + g * matrix_11 + b * matrix_12
  let new_b = r * matrix_20 + g * matrix_21 + b * matrix_22
  {
    r: clamp_int((new_r * 255.0).to_int(), 0, 255),
    g: clamp_int((new_g * 255.0).to_int(), 0, 255),
    b: clamp_int((new_b * 255.0).to_int(), 0, 255),
    a: color.a,
  }
}

///|
/// Approximate cosine function
fn cos_approx(x : Double) -> Double {
  let pi = 3.14159265358979
  let pi2 = 6.28318530717959
  // Normalize to [0, 2π]
  let mut normalized = x
  while normalized < 0.0 {
    normalized = normalized + pi2
  }
  while normalized >= pi2 {
    normalized = normalized - pi2
  }
  // Reduce to [-π, π] for better Taylor accuracy
  if normalized > pi {
    normalized = normalized - pi2
  }
  // Taylor series approximation for cos (accurate near 0)
  let x2 = normalized * normalized
  let x4 = x2 * x2
  let x6 = x4 * x2
  let x8 = x4 * x4
  let x10 = x4 * x6
  1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0 + x8 / 40320.0 - x10 / 3628800.0
}

///|
/// Approximate sine function
fn sin_approx(x : Double) -> Double {
  let pi = 3.14159265358979
  let pi2 = 6.28318530717959
  // Normalize to [0, 2π]
  let mut normalized = x
  while normalized < 0.0 {
    normalized = normalized + pi2
  }
  while normalized >= pi2 {
    normalized = normalized - pi2
  }
  // Reduce to [-π, π]
  if normalized > pi {
    normalized = normalized - pi2
  }
  // Taylor series for sin: x - x³/6 + x⁵/120 - x⁷/5040 + x⁹/362880
  let x2 = normalized * normalized
  let x3 = normalized * x2
  let x5 = x3 * x2
  let x7 = x5 * x2
  let x9 = x7 * x2
  normalized - x3 / 6.0 + x5 / 120.0 - x7 / 5040.0 + x9 / 362880.0
}

///|
/// Apply invert filter to a color
pub fn apply_invert(color : Color, amount : Double) -> Color {
  let inv_r = 255 - color.r
  let inv_g = 255 - color.g
  let inv_b = 255 - color.b
  {
    r: lerp(color.r.to_double(), inv_r.to_double(), amount).to_int(),
    g: lerp(color.g.to_double(), inv_g.to_double(), amount).to_int(),
    b: lerp(color.b.to_double(), inv_b.to_double(), amount).to_int(),
    a: color.a,
  }
}

///|
/// Apply saturate filter to a color
pub fn apply_saturate(color : Color, factor : Double) -> Color {
  // Saturation matrix based on luminance
  let r = color.r.to_double() / 255.0
  let g = color.g.to_double() / 255.0
  let b = color.b.to_double() / 255.0
  // Luminance coefficients
  let lum_r = 0.2126
  let lum_g = 0.7152
  let lum_b = 0.0722
  // Saturation matrix
  let sr = (1.0 - factor) * lum_r + factor
  let sg = (1.0 - factor) * lum_g
  let sb = (1.0 - factor) * lum_b
  let new_r = r * sr + g * sg + b * sb
  let new_g = r * ((1.0 - factor) * lum_r) +
    g * ((1.0 - factor) * lum_g + factor) +
    b * ((1.0 - factor) * lum_b)
  let new_b = r * ((1.0 - factor) * lum_r) +
    g * ((1.0 - factor) * lum_g) +
    b * ((1.0 - factor) * lum_b + factor)
  {
    r: clamp_int((new_r * 255.0).to_int(), 0, 255),
    g: clamp_int((new_g * 255.0).to_int(), 0, 255),
    b: clamp_int((new_b * 255.0).to_int(), 0, 255),
    a: color.a,
  }
}

///|
/// Apply color matrix filter (feColorMatrix)
/// Matrix is 5x4 (20 values) in row-major order:
/// [R'] = [a00 a01 a02 a03 a04] [R]
/// [G'] = [a10 a11 a12 a13 a14] [G]
/// [B'] = [a20 a21 a22 a23 a24] [B]
/// [A'] = [a30 a31 a32 a33 a34] [A]
///                              [1]
pub fn apply_color_matrix(color : Color, matrix : FixedArray[Double]) -> Color {
  if matrix.length() != 20 {
    return color // Invalid matrix
  }
  let r = color.r.to_double() / 255.0
  let g = color.g.to_double() / 255.0
  let b = color.b.to_double() / 255.0
  let a = color.a.to_double() / 255.0
  let new_r = r * matrix[0] +
    g * matrix[1] +
    b * matrix[2] +
    a * matrix[3] +
    matrix[4]
  let new_g = r * matrix[5] +
    g * matrix[6] +
    b * matrix[7] +
    a * matrix[8] +
    matrix[9]
  let new_b = r * matrix[10] +
    g * matrix[11] +
    b * matrix[12] +
    a * matrix[13] +
    matrix[14]
  let new_a = r * matrix[15] +
    g * matrix[16] +
    b * matrix[17] +
    a * matrix[18] +
    matrix[19]
  {
    r: clamp_int((new_r * 255.0).to_int(), 0, 255),
    g: clamp_int((new_g * 255.0).to_int(), 0, 255),
    b: clamp_int((new_b * 255.0).to_int(), 0, 255),
    a: clamp_int((new_a * 255.0).to_int(), 0, 255),
  }
}

///|
/// Create identity color matrix
pub fn identity_matrix() -> FixedArray[Double] {
  [
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
  ]
}

///|
/// Create saturate color matrix
pub fn saturate_matrix(factor : Double) -> FixedArray[Double] {
  let s = factor
  let lum_r = 0.2126
  let lum_g = 0.7152
  let lum_b = 0.0722
  [
    (1.0 - s) * lum_r + s,
    (1.0 - s) * lum_g,
    (1.0 - s) * lum_b,
    0.0,
    0.0,
    (1.0 - s) * lum_r,
    (1.0 - s) * lum_g + s,
    (1.0 - s) * lum_b,
    0.0,
    0.0,
    (1.0 - s) * lum_r,
    (1.0 - s) * lum_g,
    (1.0 - s) * lum_b + s,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
  ]
}

///|
/// Create hue-rotate color matrix
pub fn hue_rotate_matrix(angle_degrees : Double) -> FixedArray[Double] {
  let angle = angle_degrees * 3.14159265358979 / 180.0
  let cos_a = cos_approx(angle)
  let sin_a = sin_approx(angle)
  [
    0.213 + cos_a * 0.787 - sin_a * 0.213,
    0.715 - cos_a * 0.715 - sin_a * 0.715,
    0.072 - cos_a * 0.072 + sin_a * 0.928,
    0.0,
    0.0,
    0.213 - cos_a * 0.213 + sin_a * 0.143,
    0.715 + cos_a * 0.285 + sin_a * 0.140,
    0.072 - cos_a * 0.072 - sin_a * 0.283,
    0.0,
    0.0,
    0.213 - cos_a * 0.213 - sin_a * 0.787,
    0.715 - cos_a * 0.715 + sin_a * 0.715,
    0.072 + cos_a * 0.928 + sin_a * 0.072,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
  ]
}

///|
/// Create luminance-to-alpha color matrix
pub fn luminance_to_alpha_matrix() -> FixedArray[Double] {
  [
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2126,
    0.7152, 0.0722, 0.0, 0.0,
  ]
}

///|
/// Apply drop shadow to an image and return new image with shadow
pub fn apply_drop_shadow(
  image : Image,
  offset_x : Int,
  offset_y : Int,
  blur_radius : Int,
  shadow_color : Color,
) -> Image {
  // Create output with extra space for shadow
  let max_offset = if offset_x.abs() > offset_y.abs() {
    offset_x.abs()
  } else {
    offset_y.abs()
  }
  let margin = blur_radius + max_offset
  let new_width = image.width + margin * 2
  let new_height = image.height + margin * 2
  let output = Image::new(new_width, new_height)
  // First, render the shadow (offset copy with color)
  for y = 0; y < image.height; y = y + 1 {
    for x = 0; x < image.width; x = x + 1 {
      let src_color = image.get_pixel(x, y)
      if src_color.a > 0 {
        let shadow_x = margin + x + offset_x
        let shadow_y = margin + y + offset_y
        if shadow_x >= 0 &&
          shadow_x < new_width &&
          shadow_y >= 0 &&
          shadow_y < new_height {
          // Use original alpha to modulate shadow
          let alpha = (shadow_color.a.to_double() *
          src_color.a.to_double() /
          255.0).to_int()
          output.set_pixel(shadow_x, shadow_y, { ..shadow_color, a: alpha })
        }
      }
    }
  }
  // Apply blur to shadow
  if blur_radius > 0 {
    output.apply_blur_in_place(blur_radius)
  }
  // Then overlay the original image on top
  for y = 0; y < image.height; y = y + 1 {
    for x = 0; x < image.width; x = x + 1 {
      let src_color = image.get_pixel(x, y)
      if src_color.a > 0 {
        let dst_x = margin + x
        let dst_y = margin + y
        // Alpha blend
        let bg = output.get_pixel(dst_x, dst_y)
        let blended = alpha_blend(src_color, bg)
        output.set_pixel(dst_x, dst_y, blended)
      }
    }
  }
  output
}

///|
/// Alpha blend foreground over background
fn alpha_blend(fg : Color, bg : Color) -> Color {
  let fg_a = fg.a.to_double() / 255.0
  let bg_a = bg.a.to_double() / 255.0
  let out_a = fg_a + bg_a * (1.0 - fg_a)
  if out_a < 0.001 {
    return Color::transparent()
  }
  let r = (fg.r.to_double() * fg_a + bg.r.to_double() * bg_a * (1.0 - fg_a)) /
    out_a
  let g = (fg.g.to_double() * fg_a + bg.g.to_double() * bg_a * (1.0 - fg_a)) /
    out_a
  let b = (fg.b.to_double() * fg_a + bg.b.to_double() * bg_a * (1.0 - fg_a)) /
    out_a
  Color::rgba(r.to_int(), g.to_int(), b.to_int(), (out_a * 255.0).to_int())
}

///|
/// Apply a filter to an image (returns new image)
pub fn apply_filter(image : Image, filter : Filter) -> Image {
  match filter {
    Blur(radius) => {
      let result = image.clone()
      result.apply_blur_in_place(radius.to_int())
      result
    }
    DropShadow(offset_x, offset_y, blur, color) =>
      apply_drop_shadow(
        image,
        offset_x.to_int(),
        offset_y.to_int(),
        blur.to_int(),
        color,
      )
    Brightness(factor) => {
      let result = image.clone()
      result.apply_brightness_in_place(factor)
      result
    }
    Contrast(factor) => {
      let result = image.clone()
      result.apply_contrast_in_place(factor)
      result
    }
    Grayscale(amount) => {
      let result = image.clone()
      result.apply_grayscale_in_place(amount)
      result
    }
    Sepia(amount) => {
      let result = image.clone()
      result.apply_sepia_in_place(amount)
      result
    }
    HueRotate(angle) => {
      let result = image.clone()
      result.apply_hue_rotate_in_place(angle)
      result
    }
    Invert(amount) => {
      let result = image.clone()
      result.apply_invert_in_place(amount)
      result
    }
    Saturate(factor) => {
      let result = image.clone()
      result.apply_saturate_in_place(factor)
      result
    }
    ColorMatrix(matrix) => {
      let result = image.clone()
      result.apply_color_matrix_in_place(matrix)
      result
    }
  }
}

// ============================================================================
// Image Support
// ============================================================================

///|
/// Image data (RGBA pixels)
pub(all) struct Image {
  width : Int
  height : Int
  pixels : Array[Color] // Row-major order
}

///|
/// Create a new image with specified dimensions
pub fn Image::new(width : Int, height : Int) -> Image {
  let pixels : Array[Color] = []
  let total = width * height
  for i = 0; i < total; i = i + 1 {
    pixels.push(Color::transparent())
  }
  { width, height, pixels }
}

///|
/// Create an image filled with a color
pub fn Image::filled(width : Int, height : Int, color : Color) -> Image {
  let pixels : Array[Color] = []
  let total = width * height
  for i = 0; i < total; i = i + 1 {
    pixels.push(color)
  }
  { width, height, pixels }
}

///|
/// Get pixel at coordinates
pub fn Image::get_pixel(self : Image, x : Int, y : Int) -> Color {
  if x < 0 || x >= self.width || y < 0 || y >= self.height {
    return Color::transparent()
  }
  self.pixels[y * self.width + x]
}

///|
/// Set pixel at coordinates
pub fn Image::set_pixel(self : Image, x : Int, y : Int, color : Color) -> Unit {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    self.pixels[y * self.width + x] = color
  }
}

///|
/// Fill a rectangle region
pub fn Image::fill_rect(
  self : Image,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : Color,
) -> Unit {
  for py = y; py < y + h; py = py + 1 {
    for px = x; px < x + w; px = px + 1 {
      self.set_pixel(px, py, color)
    }
  }
}

///|
/// Clear image to transparent
pub fn Image::clear(self : Image) -> Unit {
  let transparent = Color::transparent()
  for i = 0; i < self.pixels.length(); i = i + 1 {
    self.pixels[i] = transparent
  }
}

///|
/// Clone the image
pub fn Image::clone(self : Image) -> Image {
  let pixels : Array[Color] = []
  for i = 0; i < self.pixels.length(); i = i + 1 {
    pixels.push(self.pixels[i])
  }
  { width: self.width, height: self.height, pixels }
}

///|
/// Apply blur filter in place
pub fn Image::apply_blur_in_place(self : Image, radius : Int) -> Unit {
  if radius <= 0 {
    return
  }
  // Convert to 2D array for processing
  let rows : Array[Array[Color]] = []
  for y = 0; y < self.height; y = y + 1 {
    let row : Array[Color] = []
    for x = 0; x < self.width; x = x + 1 {
      row.push(self.get_pixel(x, y))
    }
    rows.push(row)
  }
  let blurred = apply_blur(rows, radius)
  // Copy back
  for y = 0; y < self.height; y = y + 1 {
    for x = 0; x < self.width; x = x + 1 {
      self.set_pixel(x, y, blurred[y][x])
    }
  }
}

///|
/// Apply brightness filter in place
pub fn Image::apply_brightness_in_place(self : Image, factor : Double) -> Unit {
  for i = 0; i < self.pixels.length(); i = i + 1 {
    self.pixels[i] = apply_brightness(self.pixels[i], factor)
  }
}

///|
/// Apply contrast filter in place
pub fn Image::apply_contrast_in_place(self : Image, factor : Double) -> Unit {
  for i = 0; i < self.pixels.length(); i = i + 1 {
    self.pixels[i] = apply_contrast(self.pixels[i], factor)
  }
}

///|
/// Apply grayscale filter in place
pub fn Image::apply_grayscale_in_place(self : Image, amount : Double) -> Unit {
  for i = 0; i < self.pixels.length(); i = i + 1 {
    self.pixels[i] = apply_grayscale(self.pixels[i], amount)
  }
}

///|
/// Apply sepia filter in place
pub fn Image::apply_sepia_in_place(self : Image, amount : Double) -> Unit {
  for i = 0; i < self.pixels.length(); i = i + 1 {
    self.pixels[i] = apply_sepia(self.pixels[i], amount)
  }
}

///|
/// Apply hue rotate filter in place
pub fn Image::apply_hue_rotate_in_place(
  self : Image,
  angle_degrees : Double,
) -> Unit {
  for i = 0; i < self.pixels.length(); i = i + 1 {
    self.pixels[i] = apply_hue_rotate(self.pixels[i], angle_degrees)
  }
}

///|
/// Apply invert filter in place
pub fn Image::apply_invert_in_place(self : Image, amount : Double) -> Unit {
  for i = 0; i < self.pixels.length(); i = i + 1 {
    self.pixels[i] = apply_invert(self.pixels[i], amount)
  }
}

///|
/// Apply saturate filter in place
pub fn Image::apply_saturate_in_place(self : Image, factor : Double) -> Unit {
  for i = 0; i < self.pixels.length(); i = i + 1 {
    self.pixels[i] = apply_saturate(self.pixels[i], factor)
  }
}

///|
/// Apply color matrix filter in place
pub fn Image::apply_color_matrix_in_place(
  self : Image,
  matrix : FixedArray[Double],
) -> Unit {
  for i = 0; i < self.pixels.length(); i = i + 1 {
    self.pixels[i] = apply_color_matrix(self.pixels[i], matrix)
  }
}

///|
/// Apply a filter and return a new image
pub fn Image::apply_filter(self : Image, filter : Filter) -> Image {
  apply_filter(self, filter)
}

///|
/// Sprite definition (sub-region of an image)
pub(all) struct Sprite {
  image : Image
  x : Int // Source x
  y : Int // Source y
  width : Int
  height : Int
}

///|
/// Create a sprite from an image region
pub fn Sprite::new(
  image : Image,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> Sprite {
  { image, x, y, width, height }
}

///|
/// Create a sprite from the entire image
pub fn Sprite::from_image(image : Image) -> Sprite {
  { image, x: 0, y: 0, width: image.width, height: image.height }
}

///|
/// Get pixel from sprite (local coordinates)
pub fn Sprite::get_pixel(self : Sprite, x : Int, y : Int) -> Color {
  if x < 0 || x >= self.width || y < 0 || y >= self.height {
    return Color::transparent()
  }
  self.image.get_pixel(self.x + x, self.y + y)
}

///|
/// Sprite sheet for animations
pub(all) struct SpriteSheet {
  image : Image
  tile_width : Int
  tile_height : Int
  columns : Int
  rows : Int
}

///|
/// Create a sprite sheet from an image
pub fn SpriteSheet::new(
  image : Image,
  tile_width : Int,
  tile_height : Int,
) -> SpriteSheet {
  let columns = image.width / tile_width
  let rows = image.height / tile_height
  { image, tile_width, tile_height, columns, rows }
}

///|
/// Get sprite at grid position
pub fn SpriteSheet::get_sprite(
  self : SpriteSheet,
  col : Int,
  row : Int,
) -> Sprite {
  Sprite::new(
    self.image,
    col * self.tile_width,
    row * self.tile_height,
    self.tile_width,
    self.tile_height,
  )
}

///|
/// Get sprite by index (left-to-right, top-to-bottom)
pub fn SpriteSheet::get_sprite_by_index(
  self : SpriteSheet,
  index : Int,
) -> Sprite {
  let col = index % self.columns
  let row = index / self.columns
  self.get_sprite(col, row)
}

///|
/// Total number of sprites in the sheet
pub fn SpriteSheet::sprite_count(self : SpriteSheet) -> Int {
  self.columns * self.rows
}

///|
/// Blit (copy) source image onto destination at position
pub fn blit(dest : Image, src : Image, dest_x : Int, dest_y : Int) -> Unit {
  for sy = 0; sy < src.height; sy = sy + 1 {
    for sx = 0; sx < src.width; sx = sx + 1 {
      let color = src.get_pixel(sx, sy)
      if color.a > 0 {
        let dx = dest_x + sx
        let dy = dest_y + sy
        if color.a == 255 {
          dest.set_pixel(dx, dy, color)
        } else {
          // Alpha blending
          let dst_color = dest.get_pixel(dx, dy)
          let blended = blend_colors(dst_color, color)
          dest.set_pixel(dx, dy, blended)
        }
      }
    }
  }
}

///|
/// Blit sprite onto image
pub fn blit_sprite(
  dest : Image,
  sprite : Sprite,
  dest_x : Int,
  dest_y : Int,
) -> Unit {
  for sy = 0; sy < sprite.height; sy = sy + 1 {
    for sx = 0; sx < sprite.width; sx = sx + 1 {
      let color = sprite.get_pixel(sx, sy)
      if color.a > 0 {
        let dx = dest_x + sx
        let dy = dest_y + sy
        if color.a == 255 {
          dest.set_pixel(dx, dy, color)
        } else {
          let dst_color = dest.get_pixel(dx, dy)
          let blended = blend_colors(dst_color, color)
          dest.set_pixel(dx, dy, blended)
        }
      }
    }
  }
}

///|
/// Blit with scaling
pub fn blit_scaled(
  dest : Image,
  src : Image,
  dest_x : Int,
  dest_y : Int,
  dest_w : Int,
  dest_h : Int,
) -> Unit {
  for dy = 0; dy < dest_h; dy = dy + 1 {
    for dx = 0; dx < dest_w; dx = dx + 1 {
      // Nearest-neighbor sampling
      let sx = dx * src.width / dest_w
      let sy = dy * src.height / dest_h
      let color = src.get_pixel(sx, sy)
      if color.a > 0 {
        dest.set_pixel(dest_x + dx, dest_y + dy, color)
      }
    }
  }
}

///|
/// Flip image horizontally
pub fn Image::flip_horizontal(self : Image) -> Image {
  let result = Image::new(self.width, self.height)
  for y = 0; y < self.height; y = y + 1 {
    for x = 0; x < self.width; x = x + 1 {
      let src_color = self.get_pixel(self.width - 1 - x, y)
      result.set_pixel(x, y, src_color)
    }
  }
  result
}

///|
/// Flip image vertically
pub fn Image::flip_vertical(self : Image) -> Image {
  let result = Image::new(self.width, self.height)
  for y = 0; y < self.height; y = y + 1 {
    for x = 0; x < self.width; x = x + 1 {
      let src_color = self.get_pixel(x, self.height - 1 - y)
      result.set_pixel(x, y, src_color)
    }
  }
  result
}

///|
/// Rotate image 90 degrees clockwise
pub fn Image::rotate_90_cw(self : Image) -> Image {
  let result = Image::new(self.height, self.width)
  for y = 0; y < self.height; y = y + 1 {
    for x = 0; x < self.width; x = x + 1 {
      let src_color = self.get_pixel(x, y)
      result.set_pixel(self.height - 1 - y, x, src_color)
    }
  }
  result
}

///|
/// Rotate image 90 degrees counter-clockwise
pub fn Image::rotate_90_ccw(self : Image) -> Image {
  let result = Image::new(self.height, self.width)
  for y = 0; y < self.height; y = y + 1 {
    for x = 0; x < self.width; x = x + 1 {
      let src_color = self.get_pixel(x, y)
      result.set_pixel(y, self.width - 1 - x, src_color)
    }
  }
  result
}

///|
/// Create a sub-image (crop)
pub fn Image::sub_image(
  self : Image,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Image {
  let result = Image::new(w, h)
  for py = 0; py < h; py = py + 1 {
    for px = 0; px < w; px = px + 1 {
      let color = self.get_pixel(x + px, y + py)
      result.set_pixel(px, py, color)
    }
  }
  result
}

///|
/// Alpha blend two colors
fn blend_colors(dst : Color, src : Color) -> Color {
  let sa = src.a.to_double() / 255.0
  let da = dst.a.to_double() / 255.0
  let out_a = sa + da * (1.0 - sa)
  if out_a == 0.0 {
    return Color::transparent()
  }
  let r = ((src.r.to_double() * sa + dst.r.to_double() * da * (1.0 - sa)) /
  out_a).to_int()
  let g = ((src.g.to_double() * sa + dst.g.to_double() * da * (1.0 - sa)) /
  out_a).to_int()
  let b = ((src.b.to_double() * sa + dst.b.to_double() * da * (1.0 - sa)) /
  out_a).to_int()
  { r, g, b, a: (out_a * 255.0).to_int() }
}

///|
/// Animated sprite helper
pub(all) struct AnimatedSprite {
  sheet : SpriteSheet
  frames : Array[Int] // Frame indices
  mut current_frame : Int
  frame_duration : Double // Seconds per frame
  mut elapsed : Double
  mut looping : Bool
  mut playing : Bool
}

///|
/// Create an animated sprite
pub fn AnimatedSprite::new(
  sheet : SpriteSheet,
  frames : Array[Int],
  frame_duration : Double,
) -> AnimatedSprite {
  {
    sheet,
    frames,
    current_frame: 0,
    frame_duration,
    elapsed: 0.0,
    looping: true,
    playing: true,
  }
}

///|
/// Create animation for a range of frames
pub fn AnimatedSprite::from_range(
  sheet : SpriteSheet,
  start : Int,
  end : Int,
  frame_duration : Double,
) -> AnimatedSprite {
  let frames : Array[Int] = []
  for i = start; i <= end; i = i + 1 {
    frames.push(i)
  }
  AnimatedSprite::new(sheet, frames, frame_duration)
}

///|
/// Update animation with delta time
pub fn AnimatedSprite::update(self : AnimatedSprite, dt : Double) -> Unit {
  if not(self.playing) || self.frames.is_empty() {
    return
  }
  self.elapsed = self.elapsed + dt
  while self.elapsed >= self.frame_duration {
    self.elapsed = self.elapsed - self.frame_duration
    self.current_frame = self.current_frame + 1
    if self.current_frame >= self.frames.length() {
      if self.looping {
        self.current_frame = 0
      } else {
        self.current_frame = self.frames.length() - 1
        self.playing = false
      }
    }
  }
}

///|
/// Get current sprite
pub fn AnimatedSprite::get_current_sprite(self : AnimatedSprite) -> Sprite {
  if self.frames.is_empty() {
    return Sprite::new(self.sheet.image, 0, 0, 0, 0)
  }
  let frame_index = self.frames[self.current_frame]
  self.sheet.get_sprite_by_index(frame_index)
}

///|
/// Play animation from beginning
pub fn AnimatedSprite::play(self : AnimatedSprite) -> Unit {
  self.playing = true
  self.current_frame = 0
  self.elapsed = 0.0
}

///|
/// Stop animation
pub fn AnimatedSprite::stop(self : AnimatedSprite) -> Unit {
  self.playing = false
}

///|
/// Pause animation
pub fn AnimatedSprite::pause(self : AnimatedSprite) -> Unit {
  self.playing = false
}

///|
/// Continue animation
pub fn AnimatedSprite::continue_playing(self : AnimatedSprite) -> Unit {
  self.playing = true
}

///|
/// Set looping
pub fn AnimatedSprite::set_looping(
  self : AnimatedSprite,
  looping : Bool,
) -> Unit {
  self.looping = looping
}

// ============================================================================
// ClipPath
// ============================================================================

///|
/// Clip path definition
pub(all) struct ClipPath {
  id : String
  shape : Shape // The clipping shape
  transform : Transform
  clip_rule : FillRule // nonzero or evenodd
}

///|
pub fn ClipPath::new(id : String, shape : Shape) -> ClipPath {
  { id, shape, transform: Transform::identity(), clip_rule: NonZero }
}

///|
pub fn ClipPath::with_transform(
  id : String,
  shape : Shape,
  transform : Transform,
) -> ClipPath {
  { id, shape, transform, clip_rule: NonZero }
}

///|
/// Check if a point is inside the clip path
pub fn ClipPath::contains(self : ClipPath, x : Double, y : Double) -> Bool {
  // Apply inverse transform to get point in clip space
  let inv = self.transform.inverse()
  let (cx, cy) = inv.apply(x, y)
  // Use hit test
  hit_test_shape(cx, cy, self.shape)
}

///|
/// Clip path registry for referencing by ID
pub(all) struct ClipPathRegistry {
  clips : Map[String, ClipPath]
}

///|
pub fn ClipPathRegistry::new() -> ClipPathRegistry {
  { clips: {} }
}

///|
pub fn ClipPathRegistry::add(self : ClipPathRegistry, clip : ClipPath) -> Unit {
  self.clips.set(clip.id, clip)
}

///|
pub fn ClipPathRegistry::get(self : ClipPathRegistry, id : String) -> ClipPath? {
  self.clips.get(id)
}

// ============================================================================
// Mask
// ============================================================================

///|
/// Mask content units
pub(all) enum MaskUnits {
  UserSpaceOnUse // Coordinates relative to current user space
  ObjectBoundingBox // Coordinates relative to bounding box (0-1)
} derive(Show, Eq)

///|
/// Mask type - how mask values are interpreted
pub(all) enum MaskType {
  Luminance // Use luminance (brightness) as mask value
  Alpha // Use alpha channel as mask value
} derive(Show, Eq)

///|
/// Mask definition for transparency masking
pub(all) struct Mask {
  id : String
  content : Array[SVGNode] // Mask content (rendered to get mask values)
  x : Double // Mask region x
  y : Double // Mask region y
  width : Double // Mask region width
  height : Double // Mask region height
  mask_units : MaskUnits
  mask_content_units : MaskUnits
  mask_type : MaskType
}

///|
pub fn Mask::new(id : String, content : Array[SVGNode]) -> Mask {
  {
    id,
    content,
    x: -0.1,
    y: -0.1,
    width: 1.2,
    height: 1.2,
    mask_units: ObjectBoundingBox,
    mask_content_units: UserSpaceOnUse,
    mask_type: Luminance,
  }
}

///|
pub fn Mask::with_bounds(
  id : String,
  content : Array[SVGNode],
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Mask {
  {
    id,
    content,
    x,
    y,
    width,
    height,
    mask_units: ObjectBoundingBox,
    mask_content_units: UserSpaceOnUse,
    mask_type: Luminance,
  }
}

///|
/// Compute mask value (0.0-1.0) at a point using luminance
pub fn compute_luminance(color : Color) -> Double {
  // Standard luminance formula (ITU-R BT.709)
  let r = color.r.to_double() / 255.0
  let g = color.g.to_double() / 255.0
  let b = color.b.to_double() / 255.0
  let a = color.a.to_double() / 255.0
  // Luminance weighted by alpha
  (0.2126 * r + 0.7152 * g + 0.0722 * b) * a
}

///|
/// Compute mask value using alpha channel
pub fn compute_alpha_mask(color : Color) -> Double {
  color.a.to_double() / 255.0
}

///|
/// Mask registry for referencing by ID
pub(all) struct MaskRegistry {
  masks : Map[String, Mask]
}

///|
pub fn MaskRegistry::new() -> MaskRegistry {
  { masks: {} }
}

///|
pub fn MaskRegistry::add(self : MaskRegistry, mask : Mask) -> Unit {
  self.masks.set(mask.id, mask)
}

///|
pub fn MaskRegistry::get(self : MaskRegistry, id : String) -> Mask? {
  self.masks.get(id)
}

///|
/// Get the mask region bounds for a given target bounds
pub fn Mask::get_mask_bounds(self : Mask, target : BoundingBox) -> BoundingBox {
  match self.mask_units {
    ObjectBoundingBox => {
      let tw = target.max_x - target.min_x
      let th = target.max_y - target.min_y
      {
        min_x: target.min_x + self.x * tw,
        min_y: target.min_y + self.y * th,
        max_x: target.min_x + (self.x + self.width) * tw,
        max_y: target.min_y + (self.y + self.height) * th,
      }
    }
    UserSpaceOnUse =>
      {
        min_x: self.x,
        min_y: self.y,
        max_x: self.x + self.width,
        max_y: self.y + self.height,
      }
  }
}

///|
/// Apply mask to an image using luminance or alpha
pub fn apply_mask_to_image(
  image : Image,
  mask_buffer : Image,
  mask_type : MaskType,
) -> Image {
  let result = Image::new(image.width, image.height)
  for y = 0; y < image.height; y = y + 1 {
    for x = 0; x < image.width; x = x + 1 {
      let src_color = image.get_pixel(x, y)
      // Get corresponding mask pixel (with bounds check)
      let mask_x = x * mask_buffer.width / image.width
      let mask_y = y * mask_buffer.height / image.height
      let mask_color = if mask_x >= 0 &&
        mask_x < mask_buffer.width &&
        mask_y >= 0 &&
        mask_y < mask_buffer.height {
        mask_buffer.get_pixel(mask_x, mask_y)
      } else {
        Color::transparent()
      }
      // Compute mask value
      let mask_value = match mask_type {
        Luminance => compute_luminance(mask_color)
        Alpha => compute_alpha_mask(mask_color)
      }
      // Apply mask to alpha
      let new_alpha = (src_color.a.to_double() * mask_value).to_int()
      result.set_pixel(
        x,
        y,
        Color::rgba(src_color.r, src_color.g, src_color.b, new_alpha),
      )
    }
  }
  result
}

// ============================================================================
// Pattern Fill
// ============================================================================

///|
/// Pattern definition for fills
pub(all) struct Pattern {
  id : String
  width : Double // Pattern tile width
  height : Double // Pattern tile height
  content : Array[SVGNode] // Pattern content
  pattern_units : PatternUnits
  pattern_content_units : PatternUnits
  transform : Transform
}

///|
pub(all) enum PatternUnits {
  UserSpaceOnUse // Coordinates relative to current user space
  ObjectBoundingBox // Coordinates relative to bounding box (0-1)
}

///|
pub fn Pattern::new(
  id : String,
  width : Double,
  height : Double,
  content : Array[SVGNode],
) -> Pattern {
  {
    id,
    width,
    height,
    content,
    pattern_units: ObjectBoundingBox,
    pattern_content_units: UserSpaceOnUse,
    transform: Transform::identity(),
  }
}

///|
/// Get pattern color at a point (simplified - returns first solid color found)
pub fn Pattern::get_color_at(
  self : Pattern,
  x : Double,
  y : Double,
  bbox : BoundingBox,
) -> Color? {
  // Calculate pattern space coordinates
  let (pw, ph) = match self.pattern_units {
    UserSpaceOnUse => (self.width, self.height)
    ObjectBoundingBox =>
      (self.width * bbox.width(), self.height * bbox.height())
  }
  if pw <= 0.0 || ph <= 0.0 {
    return None
  }
  // Get position within pattern tile (modulo)
  let px = x - (x / pw).floor() * pw
  let py = y - (y / ph).floor() * ph
  // Find which content element contains this point
  for node in self.content {
    if hit_test_shape(px, py, node.shape) {
      match node.fill {
        SolidColor(color) => return Some(color)
        _ => continue
      }
    }
  }
  None
}

///|
/// Pattern registry
pub(all) struct PatternRegistry {
  patterns : Map[String, Pattern]
}

///|
pub fn PatternRegistry::new() -> PatternRegistry {
  { patterns: {} }
}

///|
pub fn PatternRegistry::add(self : PatternRegistry, pattern : Pattern) -> Unit {
  self.patterns.set(pattern.id, pattern)
}

///|
pub fn PatternRegistry::get(self : PatternRegistry, id : String) -> Pattern? {
  self.patterns.get(id)
}

// ============================================================================
// Text Layout (SVG 2.0)
// ============================================================================

///|
/// Text anchor (horizontal alignment)
pub(all) enum TextAnchor {
  Start // Left aligned (default for LTR)
  Middle // Center aligned
  End // Right aligned
}

///|
/// Writing mode (SVG 2.0)
pub(all) enum WritingMode {
  HorizontalTB // Left to right, top to bottom (default)
  VerticalRL // Top to bottom, right to left (Japanese, Chinese)
  VerticalLR // Top to bottom, left to right
} derive(Show, Eq)

///|
/// Text orientation for vertical writing (SVG 2.0)
pub(all) enum TextOrientation {
  Mixed // Upright for CJK, rotated for others (default)
  Upright // All characters upright
  Sideways // All characters rotated 90°
} derive(Show, Eq)

///|
/// White space handling (SVG 2.0)
pub(all) enum WhiteSpace {
  Normal // Collapse whitespace, wrap at boundaries
  Pre // Preserve whitespace, no wrapping
  NoWrap // Collapse whitespace, no wrapping
  PreWrap // Preserve whitespace, wrap at boundaries
  PreLine // Collapse spaces, preserve newlines, wrap
  BreakSpaces // Like pre-wrap but break at any space
} derive(Show, Eq)

///|
/// Text overflow handling (SVG 2.0)
pub(all) enum TextOverflow {
  Clip // Clip at boundary
  Ellipsis // Show "..." at overflow
  Custom(String) // Custom overflow indicator
} derive(Show, Eq)

///|
/// Text decoration style (SVG 2.0)
pub(all) enum TextDecorationStyle {
  Solid
  Double
  Dotted
  Dashed
  Wavy
} derive(Show, Eq)

///|
/// Extended text decoration (SVG 2.0)
pub(all) struct TextDecorationFull {
  line : TextDecoration // underline, overline, line-through
  style : TextDecorationStyle
  color : Color? // None means use current color
  thickness : Double? // None means auto
}

///|
pub fn TextDecorationFull::default() -> TextDecorationFull {
  { line: NoDecoration, style: Solid, color: None, thickness: None }
}

///|
/// Paint order for text (SVG 2.0)
pub(all) enum PaintOrder {
  Normal // Fill first, then stroke (default)
  StrokeFirst // Stroke first, then fill
  FillOnly // Only fill, no stroke
  StrokeOnly // Only stroke, no fill
} derive(Show, Eq)

///|
/// Dominant baseline (vertical alignment)
pub(all) enum DominantBaseline {
  Auto // Default baseline
  TextTop // Top of em box
  Hanging // Hanging baseline
  Middle // Middle of em box
  Central // Central baseline
  TextBottom // Bottom of em box
  Alphabetic // Alphabetic baseline (default)
  Ideographic // Ideographic baseline
}

///|
/// Text decoration
pub(all) enum TextDecoration {
  NoDecoration
  Underline
  Overline
  LineThrough
} derive(Show, Eq)

///|
/// Font weight
pub(all) enum FontWeight {
  Normal // 400
  Bold // 700
  Lighter
  Bolder
  Weight(Int) // 100-900
}

///|
/// Font style
pub(all) enum FontStyle {
  NormalStyle
  Italic
  Oblique
}

///|
/// Complete text style (SVG 2.0 extended)
pub(all) struct TextStyle {
  font_family : String
  font_size : Double
  font_weight : FontWeight
  font_style : FontStyle
  text_anchor : TextAnchor
  dominant_baseline : DominantBaseline
  text_decoration : TextDecoration
  letter_spacing : Double
  word_spacing : Double
  line_height : Double // Multiplier of font_size
  // SVG 2.0 additions
  writing_mode : WritingMode
  text_orientation : TextOrientation
  white_space : WhiteSpace
  paint_order : PaintOrder
}

///|
pub fn TextStyle::default() -> TextStyle {
  {
    font_family: "sans-serif",
    font_size: 16.0,
    font_weight: Normal,
    font_style: NormalStyle,
    text_anchor: Start,
    dominant_baseline: Auto,
    text_decoration: NoDecoration,
    letter_spacing: 0.0,
    word_spacing: 0.0,
    line_height: 1.2,
    writing_mode: HorizontalTB,
    text_orientation: Mixed,
    white_space: Normal,
    paint_order: Normal,
  }
}

///|
/// Text span (styled portion of text)
pub(all) struct TextSpan {
  text : String
  x : Double? // Absolute position (overrides flow)
  y : Double?
  dx : Double // Relative offset
  dy : Double
  style : TextStyle?
}

///|
pub fn TextSpan::new(text : String) -> TextSpan {
  { text, x: None, y: None, dx: 0.0, dy: 0.0, style: None }
}

///|
pub fn TextSpan::with_offset(
  text : String,
  dx : Double,
  dy : Double,
) -> TextSpan {
  { text, x: None, y: None, dx, dy, style: None }
}

///|
/// Multi-line text block (SVG 2.0 extended)
pub(all) struct TextBlock {
  spans : Array[TextSpan]
  x : Double
  y : Double
  style : TextStyle
  // SVG 2.0 additions
  inline_size : Double? // Max width before wrapping (None = no limit)
  text_overflow : TextOverflow
}

///|
pub fn TextBlock::new(x : Double, y : Double, text : String) -> TextBlock {
  {
    spans: [TextSpan::new(text)],
    x,
    y,
    style: TextStyle::default(),
    inline_size: None,
    text_overflow: Clip,
  }
}

///|
pub fn TextBlock::with_style(
  x : Double,
  y : Double,
  text : String,
  style : TextStyle,
) -> TextBlock {
  {
    spans: [TextSpan::new(text)],
    x,
    y,
    style,
    inline_size: None,
    text_overflow: Clip,
  }
}

///|
/// Create a text block with wrapping
pub fn TextBlock::with_wrap(
  x : Double,
  y : Double,
  text : String,
  inline_size : Double,
) -> TextBlock {
  {
    spans: [TextSpan::new(text)],
    x,
    y,
    style: TextStyle::default(),
    inline_size: Some(inline_size),
    text_overflow: Clip,
  }
}

///|
pub fn TextBlock::add_span(self : TextBlock, span : TextSpan) -> Unit {
  self.spans.push(span)
}

///|
/// Calculate text width (simplified - assumes monospace)
pub fn TextBlock::get_width(self : TextBlock) -> Double {
  let mut total = 0.0
  for span in self.spans {
    let style = match span.style {
      Some(s) => s
      None => self.style
    }
    let cw = style.font_size * 0.6
    total = total + span.text.length().to_double() * cw
    total = total + style.letter_spacing * (span.text.length() - 1).to_double()
  }
  total
}

///|
/// Get text height
pub fn TextBlock::get_height(self : TextBlock) -> Double {
  self.style.font_size * self.style.line_height
}

///|
/// Get adjusted x position based on text-anchor
pub fn TextBlock::get_anchor_x(self : TextBlock) -> Double {
  match self.style.text_anchor {
    Start => self.x
    Middle => self.x - self.get_width() / 2.0
    End => self.x - self.get_width()
  }
}

///|
/// Get adjusted y position based on dominant-baseline
pub fn TextBlock::get_baseline_y(self : TextBlock) -> Double {
  let fs = self.style.font_size
  match self.style.dominant_baseline {
    Auto | Alphabetic => self.y
    TextTop | Hanging => self.y + fs * 0.8
    Middle | Central => self.y + fs * 0.35
    TextBottom | Ideographic => self.y - fs * 0.2
  }
}

///|
/// Wrap text to fit within inline_size, returns lines
pub fn TextBlock::wrap_text(self : TextBlock) -> Array[String] {
  let result : Array[String] = []
  // Collect all text from spans
  let mut full_text = ""
  for span in self.spans {
    full_text = full_text + span.text
  }
  // If no inline_size, return as single line
  match self.inline_size {
    None => {
      result.push(full_text)
      return result
    }
    Some(max_width) => {
      let char_width = self.style.font_size * 0.6
      // Handle white-space mode
      match self.style.white_space {
        Pre | NoWrap => {
          // No wrapping
          result.push(full_text)
          return result
        }
        _ => {
          // Wrap at word boundaries
          let words = split_words(full_text)
          let mut current_line = ""
          let mut current_width = 0.0
          for word in words {
            let word_width = word.length().to_double() * char_width +
              self.style.letter_spacing * (word.length() - 1).to_double()
            let space_width = char_width + self.style.word_spacing
            if current_line.length() == 0 {
              current_line = word
              current_width = word_width
            } else if current_width + space_width + word_width <= max_width {
              current_line = current_line + " " + word
              current_width = current_width + space_width + word_width
            } else {
              result.push(current_line)
              current_line = word
              current_width = word_width
            }
          }
          if current_line.length() > 0 {
            result.push(current_line)
          }
        }
      }
    }
  }
  result
}

///|
/// Get the number of lines when text is wrapped
pub fn TextBlock::get_line_count(self : TextBlock) -> Int {
  self.wrap_text().length()
}

///|
/// Get total height including all wrapped lines
pub fn TextBlock::get_total_height(self : TextBlock) -> Double {
  let line_count = self.get_line_count()
  self.style.font_size * self.style.line_height * line_count.to_double()
}

///|
/// Check if text is vertical (for writing-mode)
pub fn TextBlock::is_vertical(self : TextBlock) -> Bool {
  match self.style.writing_mode {
    HorizontalTB => false
    VerticalRL | VerticalLR => true
  }
}

///|
/// Split text into words (simplified)
fn split_words(text : String) -> Array[String] {
  let words : Array[String] = []
  let mut current = ""
  for c in text {
    if c == ' ' || c == '\t' || c == '\n' {
      if current.length() > 0 {
        words.push(current)
        current = ""
      }
    } else {
      current = current + c.to_string()
    }
  }
  if current.length() > 0 {
    words.push(current)
  }
  words
}

///|
/// Process white-space according to mode
pub fn process_white_space(text : String, mode : WhiteSpace) -> String {
  match mode {
    Pre | PreWrap | BreakSpaces =>
      // Preserve whitespace
      text
    PreLine => {
      // Collapse spaces but preserve newlines
      let mut result = ""
      let mut prev_space = false
      for c in text {
        if c == '\n' {
          result = result + "\n"
          prev_space = false
        } else if c == ' ' || c == '\t' {
          if not(prev_space) {
            result = result + " "
            prev_space = true
          }
        } else {
          result = result + c.to_string()
          prev_space = false
        }
      }
      result
    }
    Normal | NoWrap => {
      // Collapse all whitespace
      let mut result = ""
      let mut prev_space = false
      for c in text {
        if c == ' ' || c == '\t' || c == '\n' {
          if not(prev_space) {
            result = result + " "
            prev_space = true
          }
        } else {
          result = result + c.to_string()
          prev_space = false
        }
      }
      result
    }
  }
}

///|
/// Apply text-overflow to a line
pub fn apply_text_overflow(
  line : String,
  max_width : Double,
  char_width : Double,
  overflow : TextOverflow,
) -> String {
  let line_width = line.length().to_double() * char_width
  if line_width <= max_width {
    return line
  }
  let max_chars = (max_width / char_width).to_int()
  match overflow {
    Clip =>
      if max_chars > 0 && max_chars < line.length() {
        take_chars(line, max_chars)
      } else {
        line
      }
    Ellipsis =>
      if max_chars > 3 {
        take_chars(line, max_chars - 3) + "..."
      } else if max_chars > 0 {
        "..."
      } else {
        ""
      }
    Custom(indicator) => {
      let indicator_len = indicator.length()
      if max_chars > indicator_len {
        take_chars(line, max_chars - indicator_len) + indicator
      } else if max_chars > 0 {
        indicator
      } else {
        ""
      }
    }
  }
}

///|
/// Take first n characters from a string
fn take_chars(s : String, n : Int) -> String {
  let mut result = ""
  let mut count = 0
  for c in s {
    if count >= n {
      break
    }
    result = result + c.to_string()
    count = count + 1
  }
  result
}

// ============================================================================
// Use/Symbol (Reusable Elements)
// ============================================================================

///|
/// Symbol definition (reusable graphic)
pub(all) struct Symbol {
  id : String
  content : SVGNode
  view_box : ViewBox?
  preserve_aspect_ratio : PreserveAspectRatio
}

///|
pub fn Symbol::new(id : String, content : SVGNode) -> Symbol {
  {
    id,
    content,
    view_box: None,
    preserve_aspect_ratio: PreserveAspectRatio::default(),
  }
}

///|
pub fn Symbol::with_viewbox(
  id : String,
  content : SVGNode,
  view_box : ViewBox,
) -> Symbol {
  {
    id,
    content,
    view_box: Some(view_box),
    preserve_aspect_ratio: PreserveAspectRatio::default(),
  }
}

///|
/// Use element (instance of a symbol)
pub(all) struct UseElement {
  href : String // Reference to symbol ID (e.g., "#mySymbol")
  x : Double
  y : Double
  width : Double?
  height : Double?
  transform : Transform
}

///|
pub fn UseElement::new(href : String, x : Double, y : Double) -> UseElement {
  { href, x, y, width: None, height: None, transform: Transform::identity() }
}

///|
pub fn UseElement::with_size(
  href : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> UseElement {
  {
    href,
    x,
    y,
    width: Some(width),
    height: Some(height),
    transform: Transform::identity(),
  }
}

///|
/// Get the href ID (strips leading #)
pub fn UseElement::get_id(self : UseElement) -> String {
  if self.href.length() > 0 && self.href[0].unsafe_to_char() == '#' {
    let buf = StringBuilder::new()
    for i = 1; i < self.href.length(); i = i + 1 {
      buf.write_char(self.href[i].unsafe_to_char())
    }
    buf.to_string()
  } else {
    self.href
  }
}

///|
/// Symbol registry
pub(all) struct SymbolRegistry {
  symbols : Map[String, Symbol]
}

///|
pub fn SymbolRegistry::new() -> SymbolRegistry {
  { symbols: {} }
}

///|
pub fn SymbolRegistry::add(self : SymbolRegistry, symbol : Symbol) -> Unit {
  self.symbols.set(symbol.id, symbol)
}

///|
pub fn SymbolRegistry::get(self : SymbolRegistry, id : String) -> Symbol? {
  self.symbols.get(id)
}

///|
/// Instantiate a use element with the symbol registry
pub fn UseElement::instantiate(
  self : UseElement,
  registry : SymbolRegistry,
) -> SVGNode? {
  let id = self.get_id()
  match registry.get(id) {
    None => None
    Some(symbol) => {
      // Create a copy of the symbol content
      let node = symbol.content.clone()
      // Apply use element transform
      let translate = Transform::translate(self.x, self.y)
      node.transform = translate
        .multiply(self.transform)
        .multiply(node.transform)
      Some(node)
    }
  }
}

///|
/// Clone an SVGNode (shallow clone of children)
pub fn SVGNode::clone(self : SVGNode) -> SVGNode {
  let children : Array[SVGNode] = []
  for child in self.children {
    children.push(child.clone())
  }
  let filters : Array[Filter] = []
  for f in self.filters {
    filters.push(f)
  }
  {
    id: self.id,
    shape: self.shape,
    transform: self.transform,
    fill: self.fill,
    fill_rule: self.fill_rule,
    fill_opacity: self.fill_opacity,
    stroke: self.stroke,
    stroke_opacity: self.stroke_opacity,
    opacity: self.opacity,
    z_index: self.z_index,
    node_dirty: self.node_dirty,
    prev_bounds: self.prev_bounds,
    filters,
    mask_id: self.mask_id,
    clip_path_id: self.clip_path_id,
    children,
  }
}

// ============================================================================
// Marker
// ============================================================================

///|
/// Marker definition (for line endpoints)
pub(all) struct Marker {
  id : String
  content : SVGNode
  ref_x : Double // Reference point x
  ref_y : Double // Reference point y
  marker_width : Double
  marker_height : Double
  orient : MarkerOrient
  marker_units : MarkerUnits
  view_box : ViewBox?
}

///|
pub(all) enum MarkerOrient {
  Auto // Orient along path direction
  AutoStartReverse // Reverse at start
  Angle(Double) // Fixed angle in degrees
}

///|
pub(all) enum MarkerUnits {
  StrokeWidth // Marker size relative to stroke width
  UserSpaceOnUse_ // Marker size in user space (renamed to avoid conflict)
}

///|
pub fn Marker::new(id : String, content : SVGNode) -> Marker {
  {
    id,
    content,
    ref_x: 0.0,
    ref_y: 0.0,
    marker_width: 3.0,
    marker_height: 3.0,
    orient: Auto,
    marker_units: StrokeWidth,
    view_box: None,
  }
}

///|
pub fn Marker::arrow(id : String) -> Marker {
  // Create a simple arrow marker
  let arrow_path = Path(commands=[
    MoveTo(0.0, 0.0),
    LineTo(10.0, 5.0),
    LineTo(0.0, 10.0),
    ClosePath,
  ])
  let node = SVGNode::new(arrow_path)
  node.id = id + "_content"
  {
    id,
    content: node,
    ref_x: 10.0,
    ref_y: 5.0,
    marker_width: 10.0,
    marker_height: 10.0,
    orient: Auto,
    marker_units: StrokeWidth,
    view_box: Some({ min_x: 0.0, min_y: 0.0, width: 10.0, height: 10.0 }),
  }
}

///|
pub fn Marker::dot(id : String, radius : Double) -> Marker {
  let circle = Circle(cx=radius, cy=radius, r=radius)
  let node = SVGNode::new(circle)
  node.id = id + "_content"
  {
    id,
    content: node,
    ref_x: radius,
    ref_y: radius,
    marker_width: radius * 2.0,
    marker_height: radius * 2.0,
    orient: Auto,
    marker_units: StrokeWidth,
    view_box: Some({
      min_x: 0.0,
      min_y: 0.0,
      width: radius * 2.0,
      height: radius * 2.0,
    }),
  }
}

///|
/// Get transform for marker at a point with given angle
pub fn Marker::get_transform(
  self : Marker,
  x : Double,
  y : Double,
  angle : Double,
  stroke_width : Double,
) -> Transform {
  let scale = match self.marker_units {
    StrokeWidth => stroke_width
    UserSpaceOnUse_ => 1.0
  }
  let orient_angle = match self.orient {
    Auto => angle
    AutoStartReverse => angle + 3.14159265358979323846
    Angle(a) => degrees_to_radians(a)
  }
  // Translate to position, rotate, scale, then offset by ref point
  let t1 = Transform::translate(x, y)
  let r = Transform::rotate(orient_angle)
  let s = Transform::scale(scale, scale)
  let t2 = Transform::translate(-self.ref_x, -self.ref_y)
  t1.multiply(r).multiply(s).multiply(t2)
}

///|
/// Marker registry
pub(all) struct MarkerRegistry {
  markers : Map[String, Marker]
}

///|
pub fn MarkerRegistry::new() -> MarkerRegistry {
  { markers: {} }
}

///|
pub fn MarkerRegistry::add(self : MarkerRegistry, marker : Marker) -> Unit {
  self.markers.set(marker.id, marker)
}

///|
pub fn MarkerRegistry::get(self : MarkerRegistry, id : String) -> Marker? {
  self.markers.get(id)
}

///|
/// Line with markers
pub(all) struct MarkedLine {
  points : Array[(Double, Double)]
  marker_start : String? // Marker ID
  marker_mid : String?
  marker_end : String?
}

///|
pub fn MarkedLine::new(points : Array[(Double, Double)]) -> MarkedLine {
  { points, marker_start: None, marker_mid: None, marker_end: None }
}

///|
pub fn MarkedLine::with_markers(
  points : Array[(Double, Double)],
  start : String?,
  mid : String?,
  end : String?,
) -> MarkedLine {
  { points, marker_start: start, marker_mid: mid, marker_end: end }
}

///|
/// Get angle at a point on the line
pub fn MarkedLine::get_angle_at(self : MarkedLine, index : Int) -> Double {
  let len = self.points.length()
  if len < 2 {
    return 0.0
  }
  if index == 0 {
    // Start point - use angle to next point
    let dx = self.points[1].0 - self.points[0].0
    let dy = self.points[1].1 - self.points[0].1
    @math.atan2(dy, dx)
  } else if index >= len - 1 {
    // End point - use angle from previous point
    let dx = self.points[len - 1].0 - self.points[len - 2].0
    let dy = self.points[len - 1].1 - self.points[len - 2].1
    @math.atan2(dy, dx)
  } else {
    // Mid point - average of incoming and outgoing angles
    let dx1 = self.points[index].0 - self.points[index - 1].0
    let dy1 = self.points[index].1 - self.points[index - 1].1
    let dx2 = self.points[index + 1].0 - self.points[index].0
    let dy2 = self.points[index + 1].1 - self.points[index].1
    let a1 = @math.atan2(dy1, dx1)
    let a2 = @math.atan2(dy2, dx2)
    (a1 + a2) / 2.0
  }
}
