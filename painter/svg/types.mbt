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
  color_from_msvg(@msvg.Color::rgb(r, g, b))
}

///|
pub fn Color::rgba(r : Int, g : Int, b : Int, a : Int) -> Color {
  color_from_msvg(@msvg.Color::rgba(r, g, b, a))
}

///|
pub fn Color::transparent() -> Color {
  color_from_msvg(@msvg.Color::transparent())
}

///|
pub fn Color::black() -> Color {
  color_from_msvg(@msvg.Color::black())
}

///|
pub fn Color::white() -> Color {
  color_from_msvg(@msvg.Color::white())
}

///|
pub fn Color::is_transparent(self : Color) -> Bool {
  color_to_msvg(self).is_transparent()
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
} derive(Eq, Debug)

///|
/// preserveAspectRatio meet/slice
pub(all) enum MeetOrSlice {
  Meet // Scale to fit entirely (default)
  Slice // Scale to cover entirely
} derive(Eq, Debug)

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
pub impl Show for Align with output(self, logger) {
  let name = match self {
    None => "None"
    XMinYMin => "XMinYMin"
    XMidYMin => "XMidYMin"
    XMaxYMin => "XMaxYMin"
    XMinYMid => "XMinYMid"
    XMidYMid => "XMidYMid"
    XMaxYMid => "XMaxYMid"
    XMinYMax => "XMinYMax"
    XMidYMax => "XMidYMax"
    XMaxYMax => "XMaxYMax"
  }
  logger.write_string(name)
}

///|
pub impl Show for MeetOrSlice with output(self, logger) {
  let name = match self {
    Meet => "Meet"
    Slice => "Slice"
  }
  logger.write_string(name)
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
  let transform = @msvg.ViewBox::{
    min_x: self.min_x,
    min_y: self.min_y,
    width: self.width,
    height: self.height,
  }.get_transform(
    viewport_width,
    viewport_height,
    preserve_aspect_ratio.to_msvg(),
  )
  Transform::{
    a: transform.a,
    b: transform.b,
    c: transform.c,
    d: transform.d,
    e: transform.e,
    f: transform.f,
  }
}

///|
fn Align::to_msvg(self : Align) -> @msvg.Align {
  match self {
    None => @msvg.Align::None
    XMinYMin => @msvg.Align::XMinYMin
    XMidYMin => @msvg.Align::XMidYMin
    XMaxYMin => @msvg.Align::XMaxYMin
    XMinYMid => @msvg.Align::XMinYMid
    XMidYMid => @msvg.Align::XMidYMid
    XMaxYMid => @msvg.Align::XMaxYMid
    XMinYMax => @msvg.Align::XMinYMax
    XMidYMax => @msvg.Align::XMidYMax
    XMaxYMax => @msvg.Align::XMaxYMax
  }
}

///|
fn MeetOrSlice::to_msvg(self : MeetOrSlice) -> @msvg.MeetOrSlice {
  match self {
    Meet => @msvg.MeetOrSlice::Meet
    Slice => @msvg.MeetOrSlice::Slice
  }
}

///|
fn PreserveAspectRatio::to_msvg(
  self : PreserveAspectRatio,
) -> @msvg.PreserveAspectRatio {
  @msvg.PreserveAspectRatio::{
    align: self.align.to_msvg(),
    meet_or_slice: self.meet_or_slice.to_msvg(),
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
} derive(Debug)

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
} derive(Debug)

///|
pub impl Show for PathCommand with output(self, logger) {
  match self {
    MoveTo(x, y) => logger.write_string("MoveTo(\{x}, \{y})")
    LineTo(x, y) => logger.write_string("LineTo(\{x}, \{y})")
    HorizontalLineTo(x) => logger.write_string("HorizontalLineTo(\{x})")
    VerticalLineTo(y) => logger.write_string("VerticalLineTo(\{y})")
    CurveTo(x1, y1, x2, y2, x, y) =>
      logger.write_string("CurveTo(\{x1}, \{y1}, \{x2}, \{y2}, \{x}, \{y})")
    SmoothCurveTo(x2, y2, x, y) =>
      logger.write_string("SmoothCurveTo(\{x2}, \{y2}, \{x}, \{y})")
    QuadraticCurveTo(x1, y1, x, y) =>
      logger.write_string("QuadraticCurveTo(\{x1}, \{y1}, \{x}, \{y})")
    SmoothQuadraticCurveTo(x, y) =>
      logger.write_string("SmoothQuadraticCurveTo(\{x}, \{y})")
    ArcTo(rx, ry, rotation, large_arc, sweep, x, y) =>
      logger.write_string(
        "ArcTo(\{rx}, \{ry}, \{rotation}, \{large_arc}, \{sweep}, \{x}, \{y})",
      )
    ClosePath => logger.write_string("ClosePath")
    MoveToRel(dx, dy) => logger.write_string("MoveToRel(\{dx}, \{dy})")
    LineToRel(dx, dy) => logger.write_string("LineToRel(\{dx}, \{dy})")
    HorizontalLineToRel(dx) => logger.write_string("HorizontalLineToRel(\{dx})")
    VerticalLineToRel(dy) => logger.write_string("VerticalLineToRel(\{dy})")
    CurveToRel(dx1, dy1, dx2, dy2, dx, dy) =>
      logger.write_string(
        "CurveToRel(\{dx1}, \{dy1}, \{dx2}, \{dy2}, \{dx}, \{dy})",
      )
    SmoothCurveToRel(dx2, dy2, dx, dy) =>
      logger.write_string("SmoothCurveToRel(\{dx2}, \{dy2}, \{dx}, \{dy})")
    QuadraticCurveToRel(dx1, dy1, dx, dy) =>
      logger.write_string("QuadraticCurveToRel(\{dx1}, \{dy1}, \{dx}, \{dy})")
    SmoothQuadraticCurveToRel(dx, dy) =>
      logger.write_string("SmoothQuadraticCurveToRel(\{dx}, \{dy})")
    ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy) =>
      logger.write_string(
        "ArcToRel(\{rx}, \{ry}, \{rotation}, \{large_arc}, \{sweep}, \{dx}, \{dy})",
      )
  }
}

///|
pub impl Show for Shape with output(self, logger) {
  match self {
    Rect(x~, y~, width~, height~, rx~, ry~) =>
      logger.write_string(
        "Rect(x=\{x}, y=\{y}, width=\{width}, height=\{height}, rx=\{rx}, ry=\{ry})",
      )
    Circle(cx~, cy~, r~) =>
      logger.write_string("Circle(cx=\{cx}, cy=\{cy}, r=\{r})")
    Ellipse(cx~, cy~, rx~, ry~) =>
      logger.write_string("Ellipse(cx=\{cx}, cy=\{cy}, rx=\{rx}, ry=\{ry})")
    Line(x1~, y1~, x2~, y2~) =>
      logger.write_string("Line(x1=\{x1}, y1=\{y1}, x2=\{x2}, y2=\{y2})")
    Polyline(points~) => logger.write_string("Polyline(points=\{points})")
    Polygon(points~) => logger.write_string("Polygon(points=\{points})")
    Path(commands~) => logger.write_string("Path(commands=\{commands})")
    Text(x~, y~, text~, font_size~) => {
      logger.write_string("Text(x=\{x}, y=\{y}, text=")
      logger.write_string("\"")
      logger.write_string(text)
      logger.write_string("\"")
      logger.write_string(", font_size=\{font_size})")
    }
    Group => logger.write_string("Group")
  }
}

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
  linear_gradient_from_msvg(
    @msvg.LinearGradient::new(x1, y1, x2, y2, stops.map(gradient_stop_to_msvg)),
  )
}

///|
/// Simple horizontal gradient (left to right)
pub fn LinearGradient::horizontal(
  start_color : Color,
  end_color : Color,
) -> LinearGradient {
  linear_gradient_from_msvg(
    @msvg.LinearGradient::horizontal(
      color_to_msvg(start_color),
      color_to_msvg(end_color),
    ),
  )
}

///|
/// Simple vertical gradient (top to bottom)
pub fn LinearGradient::vertical(
  start_color : Color,
  end_color : Color,
) -> LinearGradient {
  linear_gradient_from_msvg(
    @msvg.LinearGradient::vertical(
      color_to_msvg(start_color),
      color_to_msvg(end_color),
    ),
  )
}

///|
/// Interpolate color at position t (0.0-1.0)
pub fn LinearGradient::color_at(self : LinearGradient, t : Double) -> Color {
  color_from_msvg(linear_gradient_to_msvg(self).color_at(t))
}

///|
/// How gradient extends beyond its bounds
pub(all) enum SpreadMethod {
  Pad // Extend with end colors (default)
  Repeat // Repeat pattern
  Reflect // Mirror pattern
} derive(Eq, Debug)

///|
pub impl Show for SpreadMethod with output(self, logger) {
  let name = match self {
    Pad => "Pad"
    Repeat => "Repeat"
    Reflect => "Reflect"
  }
  logger.write_string(name)
}

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
  stroke_style_from_msvg(@msvg.StrokeStyle::default(), None)
}

///|
pub(all) enum LineCap {
  Butt
  Round
  Square
} derive(Eq, Debug)

///|
pub(all) enum LineJoin {
  Miter
  Round
  Bevel
} derive(Eq, Debug)

///|
/// Fill rule for paths and polygons
pub(all) enum FillRule {
  NonZero // Default
  EvenOdd
} derive(Eq, Debug)

///|
pub impl Show for LineCap with output(self, logger) {
  let name = match self {
    Butt => "Butt"
    Round => "Round"
    Square => "Square"
  }
  logger.write_string(name)
}

///|
pub impl Show for LineJoin with output(self, logger) {
  let name = match self {
    Miter => "Miter"
    Round => "Round"
    Bevel => "Bevel"
  }
  logger.write_string(name)
}

///|
pub impl Show for FillRule with output(self, logger) {
  let name = match self {
    NonZero => "NonZero"
    EvenOdd => "EvenOdd"
  }
  logger.write_string(name)
}

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
/// Bounding box for a shape
pub(all) struct BoundingBox {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
}

///|
pub fn BoundingBox::empty() -> BoundingBox {
  bounding_box_from_msvg(@msvg.BoundingBox::empty())
}

///|
pub fn BoundingBox::from_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> BoundingBox {
  bounding_box_from_msvg(@msvg.BoundingBox::from_rect(x, y, w, h))
}

///|
pub fn BoundingBox::width(self : BoundingBox) -> Double {
  bounding_box_to_msvg(self).width()
}

///|
pub fn BoundingBox::height(self : BoundingBox) -> Double {
  bounding_box_to_msvg(self).height()
}

///|
pub fn BoundingBox::is_empty(self : BoundingBox) -> Bool {
  bounding_box_to_msvg(self).is_empty()
}

///|
pub fn BoundingBox::union(
  self : BoundingBox,
  other : BoundingBox,
) -> BoundingBox {
  bounding_box_from_msvg(
    bounding_box_to_msvg(self).union(bounding_box_to_msvg(other)),
  )
}

///|
pub fn BoundingBox::expand_by_point(
  self : BoundingBox,
  x : Double,
  y : Double,
) -> BoundingBox {
  bounding_box_from_msvg(bounding_box_to_msvg(self).expand_by_point(x, y))
}

///|
/// Check if two bounding boxes intersect
pub fn BoundingBox::intersects(self : BoundingBox, other : BoundingBox) -> Bool {
  bounding_box_to_msvg(self).intersects(bounding_box_to_msvg(other))
}

///|
/// Check if this bounding box contains a point
pub fn BoundingBox::contains_point(
  self : BoundingBox,
  x : Double,
  y : Double,
) -> Bool {
  bounding_box_to_msvg(self).contains_point(x, y)
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
  clip_rect_from_msvg(@msvg.ClipRect::new(x, y, width, height))
}

///|
pub fn ClipRect::from_size(width : Int, height : Int) -> ClipRect {
  clip_rect_from_msvg(@msvg.ClipRect::from_size(width, height))
}

///|
/// Check if a point is inside the clip rect
pub fn ClipRect::contains(self : ClipRect, x : Int, y : Int) -> Bool {
  clip_rect_to_msvg(self).contains(x, y)
}

///|
/// Convert to BoundingBox
pub fn ClipRect::to_bbox(self : ClipRect) -> BoundingBox {
  bounding_box_from_msvg(clip_rect_to_msvg(self).to_bbox())
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
  camera_from_msvg(@msvg.Camera::new(viewport_width, viewport_height))
}

///|
/// Move camera by delta
pub fn Camera::pan(self : Camera, dx : Double, dy : Double) -> Unit {
  let camera = camera_to_msvg(self)
  camera.pan(dx, dy)
  copy_camera_from_msvg(self, camera)
}

///|
/// Set camera position
pub fn Camera::set_position(self : Camera, x : Double, y : Double) -> Unit {
  let camera = camera_to_msvg(self)
  camera.set_position(x, y)
  copy_camera_from_msvg(self, camera)
}

///|
/// Set zoom level
pub fn Camera::set_zoom(self : Camera, zoom : Double) -> Unit {
  let camera = camera_to_msvg(self)
  camera.set_zoom(zoom)
  copy_camera_from_msvg(self, camera)
}

///|
/// Zoom by factor (multiply current zoom)
pub fn Camera::zoom_by(self : Camera, factor : Double) -> Unit {
  let camera = camera_to_msvg(self)
  camera.zoom_by(factor)
  copy_camera_from_msvg(self, camera)
}

///|
/// Get the world-space bounding box visible through this camera
pub fn Camera::get_visible_bounds(self : Camera) -> BoundingBox {
  bounding_box_from_msvg(camera_to_msvg(self).get_visible_bounds())
}

///|
/// Convert world coordinates to screen coordinates
pub fn Camera::world_to_screen(
  self : Camera,
  wx : Double,
  wy : Double,
) -> (Int, Int) {
  camera_to_msvg(self).world_to_screen(wx, wy)
}

///|
/// Convert screen coordinates to world coordinates
pub fn Camera::screen_to_world(
  self : Camera,
  sx : Int,
  sy : Int,
) -> (Double, Double) {
  camera_to_msvg(self).screen_to_world(sx, sy)
}

///|
/// Get transform matrix for this camera
pub fn Camera::get_transform(self : Camera) -> Transform {
  transform_from_msvg(camera_to_msvg(self).get_transform())
}

// ============================================================================
// Hit Testing
// ============================================================================

///|
/// Hit test a shape (without transform)
pub fn hit_test_shape(px : Double, py : Double, shape : Shape) -> Bool {
  @msvg.hit_test_shape(px, py, shape_to_msvg(shape))
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
} derive(Eq, Debug)

///|
pub impl Show for Easing with output(self, logger) {
  let name = match self {
    Linear => "Linear"
    EaseIn => "EaseIn"
    EaseOut => "EaseOut"
    EaseInOut => "EaseInOut"
    EaseInCubic => "EaseInCubic"
    EaseOutCubic => "EaseOutCubic"
    EaseInOutCubic => "EaseInOutCubic"
  }
  logger.write_string(name)
}

///|
/// Apply easing function to a normalized time (0.0 to 1.0)
pub fn Easing::apply(self : Easing, t : Double) -> Double {
  easing_to_msvg(self).apply(t)
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
  tween_from_msvg(
    @msvg.Tween::new(
      target_id,
      anim_property_to_msvg(property),
      duration,
      easing_to_msvg(easing),
    ),
  )
}

///|
/// Check if the tween is complete
pub fn Tween::is_complete(self : Tween) -> Bool {
  tween_to_msvg(self).is_complete()
}

///|
/// Update the tween with delta time
/// Returns true if still running, false if complete
pub fn Tween::update(self : Tween, dt : Double, node : SVGNode) -> Bool {
  let tween = tween_to_msvg(self)
  let msvg_node = svg_node_to_msvg(node)
  let running = tween.update(dt, msvg_node)
  copy_tween_state_from_msvg(self, tween)
  copy_svg_node_animation_state_from_msvg(node, msvg_node)
  running
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
  pointer_event_from_msvg(@msvg.PointerEvent::new(x, y, button, target))
}

///|
/// Stop event propagation (prevent bubbling)
pub fn PointerEvent::stop_propagation(self : PointerEvent) -> Unit {
  let event = pointer_event_to_msvg(self)
  event.stop_propagation()
  copy_pointer_event_state_from_msvg(self, event)
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
} derive(Eq, Debug)

///|
pub impl Show for EventType with output(self, logger) {
  let name = match self {
    Click => "Click"
    MouseDown => "MouseDown"
    MouseUp => "MouseUp"
    MouseMove => "MouseMove"
    MouseEnter => "MouseEnter"
    MouseLeave => "MouseLeave"
    DragStart => "DragStart"
    DragMove => "DragMove"
    DragEnd => "DragEnd"
  }
  logger.write_string(name)
}

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
    if !event.propagation_stopped {
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
  @msvg.collide_circle_circle(cx1, cy1, r1, cx2, cy2, r2)
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
  @msvg.collide_rect_rect(x1, y1, w1, h1, x2, y2, w2, h2)
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
  @msvg.collide_circle_rect(cx, cy, r, rx, ry, rw, rh)
}

///|
/// Check collision between two shapes
pub fn collide_shapes(shape1 : Shape, shape2 : Shape) -> Bool {
  @msvg.collide_shapes(shape_to_msvg(shape1), shape_to_msvg(shape2))
}

///|
/// Check collision between two SVGNodes (considering transforms)
pub fn SVGNode::collides_with(self : SVGNode, other : SVGNode) -> Bool {
  svg_node_to_msvg(self).collides_with(svg_node_to_msvg(other))
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
  object_pool_from_msvg(@msvg.ObjectPool::new(factory, reset, initial_size))
}

///|
/// Acquire an object from the pool
pub fn[T] ObjectPool::acquire(self : ObjectPool[T]) -> T {
  object_pool_to_msvg(self).acquire()
}

///|
/// Release an object back to the pool
pub fn[T] ObjectPool::release(self : ObjectPool[T], obj : T) -> Unit {
  object_pool_to_msvg(self).release(obj)
}

///|
/// Get the number of available objects
pub fn[T] ObjectPool::available_count(self : ObjectPool[T]) -> Int {
  object_pool_to_msvg(self).available_count()
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
  radial_gradient_from_msvg(
    @msvg.RadialGradient::new(cx, cy, r, stops.map(gradient_stop_to_msvg)),
  )
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
  color_from_msvg(radial_gradient_to_msvg(self).color_at(px, py, width, height))
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
  particle_from_msvg(@msvg.Particle::new())
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
  emitter_config_from_msvg(@msvg.EmitterConfig::default())
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
  particle_emitter_from_msvg(
    @msvg.ParticleEmitter::new(
      x,
      y,
      emitter_config_to_msvg(config),
      max_particles,
    ),
  )
}

///|
/// Update particles with delta time
pub fn ParticleEmitter::update(self : ParticleEmitter, dt : Double) -> Unit {
  let emitter = particle_emitter_to_msvg(self)
  emitter.update(dt)
  copy_particle_emitter_state_from_msvg(self, emitter)
}

///|
/// Simple pseudo-random number generator
pub(all) struct SimpleRNG {
  mut state : Int
}

///|
pub fn SimpleRNG::new(seed : Int) -> SimpleRNG {
  simple_rng_from_msvg(@msvg.SimpleRNG::new(seed))
}

///|
pub fn SimpleRNG::next(self : SimpleRNG) -> Double {
  let rng = simple_rng_to_msvg(self)
  let value = rng.next()
  self.state = rng.state
  value
}

///|
pub fn SimpleRNG::range(self : SimpleRNG, min : Double, max : Double) -> Double {
  let rng = simple_rng_to_msvg(self)
  let value = rng.range(min, max)
  self.state = rng.state
  value
}

///|
/// Get active particle count
pub fn ParticleEmitter::active_count(self : ParticleEmitter) -> Int {
  particle_emitter_to_msvg(self).active_count()
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
  path_follower_from_msvg(@msvg.PathFollower::new(path_data))
}

///|
/// Get position at current progress
pub fn PathFollower::get_position(self : PathFollower) -> (Double, Double) {
  path_follower_to_msvg(self).get_position()
}

///|
/// Update progress with delta time and speed
pub fn PathFollower::update(
  self : PathFollower,
  dt : Double,
  speed : Double,
) -> Bool {
  let follower = path_follower_to_msvg(self)
  let active = follower.update(dt, speed)
  copy_path_follower_state_from_msvg(self, follower)
  active
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
} derive(Eq, Debug)

///|
pub impl Show for BlendMode with output(self, logger) {
  let name = match self {
    Normal => "Normal"
    Multiply => "Multiply"
    Screen => "Screen"
    Overlay => "Overlay"
    Darken => "Darken"
    Lighten => "Lighten"
    ColorDodge => "ColorDodge"
    ColorBurn => "ColorBurn"
    HardLight => "HardLight"
    SoftLight => "SoftLight"
    Difference => "Difference"
    Exclusion => "Exclusion"
    Hue => "Hue"
    Saturation => "Saturation"
    ColorMode => "ColorMode"
    Luminosity => "Luminosity"
  }
  logger.write_string(name)
}

///|
/// CSS isolation values
pub(all) enum Isolation {
  Auto
  Isolate
} derive(Eq, Debug)

///|
pub impl Show for Isolation with output(self, logger) {
  let name = match self {
    Auto => "Auto"
    Isolate => "Isolate"
  }
  logger.write_string(name)
}

///|
/// Blend two colors using the specified blend mode
pub fn blend_with_mode(
  backdrop : Color,
  source : Color,
  mode : BlendMode,
) -> Color {
  color_from_msvg(
    @msvg.blend_with_mode(
      color_to_msvg(backdrop),
      color_to_msvg(source),
      blend_mode_to_msvg(mode),
    ),
  )
}

///|
/// Blend two images using the specified blend mode
pub fn blend_images(
  backdrop : Image,
  source : Image,
  mode : BlendMode,
) -> Image {
  image_from_msvg(
    @msvg.blend_images(
      image_to_msvg(backdrop),
      image_to_msvg(source),
      blend_mode_to_msvg(mode),
    ),
  )
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
  image_rows_from_msvg(@msvg.apply_blur(image_rows_to_msvg(pixels), radius))
}

///|
/// Apply brightness filter to a color
pub fn apply_brightness(color : Color, factor : Double) -> Color {
  color_from_msvg(@msvg.apply_brightness(color_to_msvg(color), factor))
}

///|
/// Apply grayscale filter to a color
pub fn apply_grayscale(color : Color, amount : Double) -> Color {
  color_from_msvg(@msvg.apply_grayscale(color_to_msvg(color), amount))
}

///|
/// Apply contrast filter to a color
pub fn apply_contrast(color : Color, factor : Double) -> Color {
  color_from_msvg(@msvg.apply_contrast(color_to_msvg(color), factor))
}

///|
/// Apply sepia filter to a color
pub fn apply_sepia(color : Color, amount : Double) -> Color {
  color_from_msvg(@msvg.apply_sepia(color_to_msvg(color), amount))
}

///|
/// Apply hue rotation to a color
pub fn apply_hue_rotate(color : Color, angle_degrees : Double) -> Color {
  color_from_msvg(@msvg.apply_hue_rotate(color_to_msvg(color), angle_degrees))
}

///|
/// Apply invert filter to a color
pub fn apply_invert(color : Color, amount : Double) -> Color {
  color_from_msvg(@msvg.apply_invert(color_to_msvg(color), amount))
}

///|
/// Apply saturate filter to a color
pub fn apply_saturate(color : Color, factor : Double) -> Color {
  color_from_msvg(@msvg.apply_saturate(color_to_msvg(color), factor))
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
  color_from_msvg(@msvg.apply_color_matrix(color_to_msvg(color), matrix))
}

///|
/// Create identity color matrix
pub fn identity_matrix() -> FixedArray[Double] {
  @msvg.identity_matrix()
}

///|
/// Create saturate color matrix
pub fn saturate_matrix(factor : Double) -> FixedArray[Double] {
  @msvg.saturate_matrix(factor)
}

///|
/// Create hue-rotate color matrix
pub fn hue_rotate_matrix(angle_degrees : Double) -> FixedArray[Double] {
  @msvg.hue_rotate_matrix(angle_degrees)
}

///|
/// Create luminance-to-alpha color matrix
pub fn luminance_to_alpha_matrix() -> FixedArray[Double] {
  @msvg.luminance_to_alpha_matrix()
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
  image_from_msvg(
    @msvg.apply_drop_shadow(
      image_to_msvg(image),
      offset_x,
      offset_y,
      blur_radius,
      color_to_msvg(shadow_color),
    ),
  )
}

///|
/// Apply a filter to an image (returns new image)
pub fn apply_filter(image : Image, filter : Filter) -> Image {
  image_from_msvg(
    @msvg.apply_filter(image_to_msvg(image), filter_to_msvg(filter)),
  )
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
  image_from_msvg(@msvg.Image::new(width, height))
}

///|
/// Create an image filled with a color
pub fn Image::filled(width : Int, height : Int, color : Color) -> Image {
  image_from_msvg(@msvg.Image::filled(width, height, color_to_msvg(color)))
}

///|
/// Get pixel at coordinates
pub fn Image::get_pixel(self : Image, x : Int, y : Int) -> Color {
  color_from_msvg(image_to_msvg(self).get_pixel(x, y))
}

///|
/// Set pixel at coordinates
pub fn Image::set_pixel(self : Image, x : Int, y : Int, color : Color) -> Unit {
  let image = image_to_msvg(self)
  image.set_pixel(x, y, color_to_msvg(color))
  copy_image_pixels_from_msvg(self, image)
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
  let image = image_to_msvg(self)
  image.fill_rect(x, y, w, h, color_to_msvg(color))
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Clear image to transparent
pub fn Image::clear(self : Image) -> Unit {
  let image = image_to_msvg(self)
  image.clear()
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Clone the image
pub fn Image::clone(self : Image) -> Image {
  image_from_msvg(image_to_msvg(self).clone())
}

///|
/// Apply blur filter in place
pub fn Image::apply_blur_in_place(self : Image, radius : Int) -> Unit {
  let image = image_to_msvg(self)
  image.apply_blur_in_place(radius)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply brightness filter in place
pub fn Image::apply_brightness_in_place(self : Image, factor : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_brightness_in_place(factor)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply contrast filter in place
pub fn Image::apply_contrast_in_place(self : Image, factor : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_contrast_in_place(factor)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply grayscale filter in place
pub fn Image::apply_grayscale_in_place(self : Image, amount : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_grayscale_in_place(amount)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply sepia filter in place
pub fn Image::apply_sepia_in_place(self : Image, amount : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_sepia_in_place(amount)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply hue rotate filter in place
pub fn Image::apply_hue_rotate_in_place(
  self : Image,
  angle_degrees : Double,
) -> Unit {
  let image = image_to_msvg(self)
  image.apply_hue_rotate_in_place(angle_degrees)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply invert filter in place
pub fn Image::apply_invert_in_place(self : Image, amount : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_invert_in_place(amount)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply saturate filter in place
pub fn Image::apply_saturate_in_place(self : Image, factor : Double) -> Unit {
  let image = image_to_msvg(self)
  image.apply_saturate_in_place(factor)
  copy_image_pixels_from_msvg(self, image)
}

///|
/// Apply color matrix filter in place
pub fn Image::apply_color_matrix_in_place(
  self : Image,
  matrix : FixedArray[Double],
) -> Unit {
  let image = image_to_msvg(self)
  image.apply_color_matrix_in_place(matrix)
  copy_image_pixels_from_msvg(self, image)
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
  sprite_from_msvg(@msvg.Sprite::new(image_to_msvg(image), x, y, width, height))
}

///|
/// Create a sprite from the entire image
pub fn Sprite::from_image(image : Image) -> Sprite {
  sprite_from_msvg(@msvg.Sprite::from_image(image_to_msvg(image)))
}

///|
/// Get pixel from sprite (local coordinates)
pub fn Sprite::get_pixel(self : Sprite, x : Int, y : Int) -> Color {
  color_from_msvg(sprite_to_msvg(self).get_pixel(x, y))
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
  sprite_sheet_from_msvg(
    @msvg.SpriteSheet::new(image_to_msvg(image), tile_width, tile_height),
  )
}

///|
/// Get sprite at grid position
pub fn SpriteSheet::get_sprite(
  self : SpriteSheet,
  col : Int,
  row : Int,
) -> Sprite {
  sprite_from_msvg(sprite_sheet_to_msvg(self).get_sprite(col, row))
}

///|
/// Get sprite by index (left-to-right, top-to-bottom)
pub fn SpriteSheet::get_sprite_by_index(
  self : SpriteSheet,
  index : Int,
) -> Sprite {
  sprite_from_msvg(sprite_sheet_to_msvg(self).get_sprite_by_index(index))
}

///|
/// Total number of sprites in the sheet
pub fn SpriteSheet::sprite_count(self : SpriteSheet) -> Int {
  sprite_sheet_to_msvg(self).sprite_count()
}

///|
/// Blit (copy) source image onto destination at position
pub fn blit(dest : Image, src : Image, dest_x : Int, dest_y : Int) -> Unit {
  let output = image_to_msvg(dest)
  @msvg.blit(output, image_to_msvg(src), dest_x, dest_y)
  copy_image_pixels_from_msvg(dest, output)
}

///|
/// Blit sprite onto image
pub fn blit_sprite(
  dest : Image,
  sprite : Sprite,
  dest_x : Int,
  dest_y : Int,
) -> Unit {
  let output = image_to_msvg(dest)
  @msvg.blit_sprite(output, sprite_to_msvg(sprite), dest_x, dest_y)
  copy_image_pixels_from_msvg(dest, output)
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
  let output = image_to_msvg(dest)
  @msvg.blit_scaled(output, image_to_msvg(src), dest_x, dest_y, dest_w, dest_h)
  copy_image_pixels_from_msvg(dest, output)
}

///|
/// Flip image horizontally
pub fn Image::flip_horizontal(self : Image) -> Image {
  image_from_msvg(image_to_msvg(self).flip_horizontal())
}

///|
/// Flip image vertically
pub fn Image::flip_vertical(self : Image) -> Image {
  image_from_msvg(image_to_msvg(self).flip_vertical())
}

///|
/// Rotate image 90 degrees clockwise
pub fn Image::rotate_90_cw(self : Image) -> Image {
  image_from_msvg(image_to_msvg(self).rotate_90_cw())
}

///|
/// Rotate image 90 degrees counter-clockwise
pub fn Image::rotate_90_ccw(self : Image) -> Image {
  image_from_msvg(image_to_msvg(self).rotate_90_ccw())
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
  image_from_msvg(image_to_msvg(self).sub_image(x, y, w, h))
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
  animated_sprite_from_msvg(
    @msvg.AnimatedSprite::new(
      sprite_sheet_to_msvg(sheet),
      frames,
      frame_duration,
    ),
  )
}

///|
/// Create animation for a range of frames
pub fn AnimatedSprite::from_range(
  sheet : SpriteSheet,
  start : Int,
  end : Int,
  frame_duration : Double,
) -> AnimatedSprite {
  animated_sprite_from_msvg(
    @msvg.AnimatedSprite::from_range(
      sprite_sheet_to_msvg(sheet),
      start,
      end,
      frame_duration,
    ),
  )
}

///|
/// Update animation with delta time
pub fn AnimatedSprite::update(self : AnimatedSprite, dt : Double) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.update(dt)
  copy_animated_sprite_state_from_msvg(self, sprite)
}

///|
/// Get current sprite
pub fn AnimatedSprite::get_current_sprite(self : AnimatedSprite) -> Sprite {
  sprite_from_msvg(animated_sprite_to_msvg(self).get_current_sprite())
}

///|
/// Play animation from beginning
pub fn AnimatedSprite::play(self : AnimatedSprite) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.play()
  copy_animated_sprite_state_from_msvg(self, sprite)
}

///|
/// Stop animation
pub fn AnimatedSprite::stop(self : AnimatedSprite) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.stop()
  copy_animated_sprite_state_from_msvg(self, sprite)
}

///|
/// Pause animation
pub fn AnimatedSprite::pause(self : AnimatedSprite) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.pause()
  copy_animated_sprite_state_from_msvg(self, sprite)
}

///|
/// Continue animation
pub fn AnimatedSprite::continue_playing(self : AnimatedSprite) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.continue_playing()
  copy_animated_sprite_state_from_msvg(self, sprite)
}

///|
/// Set looping
pub fn AnimatedSprite::set_looping(
  self : AnimatedSprite,
  looping : Bool,
) -> Unit {
  let sprite = animated_sprite_to_msvg(self)
  sprite.set_looping(looping)
  copy_animated_sprite_state_from_msvg(self, sprite)
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
  clip_path_from_msvg(@msvg.ClipPath::new(id, shape_to_msvg(shape)))
}

///|
pub fn ClipPath::with_transform(
  id : String,
  shape : Shape,
  transform : Transform,
) -> ClipPath {
  clip_path_from_msvg(
    @msvg.ClipPath::with_transform(
      id,
      shape_to_msvg(shape),
      transform.to_msvg(),
    ),
  )
}

///|
/// Check if a point is inside the clip path
pub fn ClipPath::contains(self : ClipPath, x : Double, y : Double) -> Bool {
  clip_path_to_msvg(self).contains(x, y)
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
} derive(Eq, Debug)

///|
pub impl Show for MaskUnits with output(self, logger) {
  let name = match self {
    UserSpaceOnUse => "UserSpaceOnUse"
    ObjectBoundingBox => "ObjectBoundingBox"
  }
  logger.write_string(name)
}

///|
/// Mask type - how mask values are interpreted
pub(all) enum MaskType {
  Luminance // Use luminance (brightness) as mask value
  Alpha // Use alpha channel as mask value
} derive(Eq, Debug)

///|
pub impl Show for MaskType with output(self, logger) {
  let name = match self {
    Luminance => "Luminance"
    Alpha => "Alpha"
  }
  logger.write_string(name)
}

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
  mask_from_msvg(@msvg.Mask::new(id, []), content)
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
  mask_from_msvg(@msvg.Mask::with_bounds(id, [], x, y, width, height), content)
}

///|
/// Compute mask value (0.0-1.0) at a point using luminance
pub fn compute_luminance(color : Color) -> Double {
  @msvg.compute_luminance(color_to_msvg(color))
}

///|
/// Compute mask value using alpha channel
pub fn compute_alpha_mask(color : Color) -> Double {
  @msvg.compute_alpha_mask(color_to_msvg(color))
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
  bounding_box_from_msvg(
    mask_to_msvg(self).get_mask_bounds(bounding_box_to_msvg(target)),
  )
}

///|
/// Apply mask to an image using luminance or alpha
pub fn apply_mask_to_image(
  image : Image,
  mask_buffer : Image,
  mask_type : MaskType,
) -> Image {
  image_from_msvg(
    @msvg.apply_mask_to_image(
      image_to_msvg(image),
      image_to_msvg(mask_buffer),
      mask_type_to_msvg(mask_type),
    ),
  )
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
  pattern_from_msvg(@msvg.Pattern::new(id, width, height, []), content)
}

///|
/// Get pattern color at a point (simplified - returns first solid color found)
pub fn Pattern::get_color_at(
  self : Pattern,
  x : Double,
  y : Double,
  bbox : BoundingBox,
) -> Color? {
  color_from_msvg_option(
    pattern_to_msvg(self).get_color_at(x, y, bounding_box_to_msvg(bbox)),
  )
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
} derive(Eq, Debug)

///|
pub impl Show for WritingMode with output(self, logger) {
  let name = match self {
    HorizontalTB => "HorizontalTB"
    VerticalRL => "VerticalRL"
    VerticalLR => "VerticalLR"
  }
  logger.write_string(name)
}

///|
/// Text orientation for vertical writing (SVG 2.0)
pub(all) enum TextOrientation {
  Mixed // Upright for CJK, rotated for others (default)
  Upright // All characters upright
  Sideways // All characters rotated 90°
} derive(Eq, Debug)

///|
pub impl Show for TextOrientation with output(self, logger) {
  let name = match self {
    Mixed => "Mixed"
    Upright => "Upright"
    Sideways => "Sideways"
  }
  logger.write_string(name)
}

///|
/// White space handling (SVG 2.0)
pub(all) enum WhiteSpace {
  Normal // Collapse whitespace, wrap at boundaries
  Pre // Preserve whitespace, no wrapping
  NoWrap // Collapse whitespace, no wrapping
  PreWrap // Preserve whitespace, wrap at boundaries
  PreLine // Collapse spaces, preserve newlines, wrap
  BreakSpaces // Like pre-wrap but break at any space
} derive(Eq, Debug)

///|
pub impl Show for WhiteSpace with output(self, logger) {
  let name = match self {
    Normal => "Normal"
    Pre => "Pre"
    NoWrap => "NoWrap"
    PreWrap => "PreWrap"
    PreLine => "PreLine"
    BreakSpaces => "BreakSpaces"
  }
  logger.write_string(name)
}

///|
/// Text overflow handling (SVG 2.0)
pub(all) enum TextOverflow {
  Clip // Clip at boundary
  Ellipsis // Show "..." at overflow
  Custom(String) // Custom overflow indicator
} derive(Eq, Debug)

///|
pub impl Show for TextOverflow with output(self, logger) {
  match self {
    Clip => logger.write_string("Clip")
    Ellipsis => logger.write_string("Ellipsis")
    Custom(value) => {
      logger.write_string("Custom(")
      logger.write_string("\"")
      logger.write_string(value)
      logger.write_string("\"")
      logger.write_string(")")
    }
  }
}

///|
/// Text decoration style (SVG 2.0)
pub(all) enum TextDecorationStyle {
  Solid
  Double
  Dotted
  Dashed
  Wavy
} derive(Eq, Debug)

///|
pub impl Show for TextDecorationStyle with output(self, logger) {
  let name = match self {
    Solid => "Solid"
    Double => "Double"
    Dotted => "Dotted"
    Dashed => "Dashed"
    Wavy => "Wavy"
  }
  logger.write_string(name)
}

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
} derive(Eq, Debug)

///|
pub impl Show for PaintOrder with output(self, logger) {
  let name = match self {
    Normal => "Normal"
    StrokeFirst => "StrokeFirst"
    FillOnly => "FillOnly"
    StrokeOnly => "StrokeOnly"
  }
  logger.write_string(name)
}

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
} derive(Eq, Debug)

///|
pub impl Show for TextDecoration with output(self, logger) {
  let name = match self {
    NoDecoration => "NoDecoration"
    Underline => "Underline"
    Overline => "Overline"
    LineThrough => "LineThrough"
  }
  logger.write_string(name)
}

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
  @msvg.process_white_space(text, white_space_to_msvg(mode))
}

///|
/// Apply text-overflow to a line
pub fn apply_text_overflow(
  line : String,
  max_width : Double,
  char_width : Double,
  overflow : TextOverflow,
) -> String {
  @msvg.apply_text_overflow(
    line,
    max_width,
    char_width,
    text_overflow_to_msvg(overflow),
  )
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
  symbol_from_msvg(@msvg.Symbol::new(id, svg_node_to_msvg(content)))
}

///|
pub fn Symbol::with_viewbox(
  id : String,
  content : SVGNode,
  view_box : ViewBox,
) -> Symbol {
  symbol_from_msvg(
    @msvg.Symbol::with_viewbox(
      id,
      svg_node_to_msvg(content),
      view_box_to_msvg(view_box),
    ),
  )
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
  use_element_from_msvg(@msvg.UseElement::new(href, x, y))
}

///|
pub fn UseElement::with_size(
  href : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> UseElement {
  use_element_from_msvg(@msvg.UseElement::with_size(href, x, y, width, height))
}

///|
/// Get the href ID (strips leading #)
pub fn UseElement::get_id(self : UseElement) -> String {
  use_element_to_msvg(self).get_id()
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
/// Clone an SVGNode
pub fn SVGNode::clone(self : SVGNode) -> SVGNode {
  svg_node_from_msvg(svg_node_to_msvg(self).clone())
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
  let marker = marker_from_msvg(
    @msvg.Marker::new(id, svg_node_to_msvg(content)),
  )
  {
    id: marker.id,
    content,
    ref_x: marker.ref_x,
    ref_y: marker.ref_y,
    marker_width: marker.marker_width,
    marker_height: marker.marker_height,
    orient: Auto,
    marker_units: marker.marker_units,
    view_box: marker.view_box,
  }
}

///|
pub fn Marker::arrow(id : String) -> Marker {
  marker_from_msvg(@msvg.Marker::arrow(id))
}

///|
pub fn Marker::dot(id : String, radius : Double) -> Marker {
  marker_from_msvg(@msvg.Marker::dot(id, radius))
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
  transform_from_msvg(
    marker_to_msvg(self).get_transform(x, y, angle, stroke_width),
  )
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
