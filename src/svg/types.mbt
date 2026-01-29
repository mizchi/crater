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
  Group // Container for children
} derive(Show)

///|
/// Paint style (fill or stroke)
pub(all) enum Paint {
  None
  SolidColor(Color)
  // Future: Gradient, Pattern
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
    children: [],
  }
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
