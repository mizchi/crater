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
  let node = svg_node_to_msvg(self)
  node.add_filter(filter_to_msvg(filter))
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Clear all filters from the node
pub fn SVGNode::clear_filters(self : SVGNode) -> Unit {
  let node = svg_node_to_msvg(self)
  node.clear_filters()
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Set mask reference by ID
pub fn SVGNode::set_mask(self : SVGNode, mask_id : String) -> Unit {
  let node = svg_node_to_msvg(self)
  node.set_mask(mask_id)
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Clear mask reference
pub fn SVGNode::clear_mask(self : SVGNode) -> Unit {
  let node = svg_node_to_msvg(self)
  node.clear_mask()
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Set clip path reference by ID
pub fn SVGNode::set_clip_path(self : SVGNode, clip_path_id : String) -> Unit {
  let node = svg_node_to_msvg(self)
  node.set_clip_path(clip_path_id)
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Clear clip path reference
pub fn SVGNode::clear_clip_path(self : SVGNode) -> Unit {
  let node = svg_node_to_msvg(self)
  node.clear_clip_path()
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Mark a node as dirty (needs re-render)
pub fn SVGNode::mark_dirty(self : SVGNode) -> Unit {
  let node = svg_node_to_msvg(self)
  node.mark_dirty()
  copy_svg_node_effect_state_from_msvg(self, node)
}

///|
/// Clear the dirty flag
pub fn SVGNode::clear_dirty(self : SVGNode) -> Unit {
  let node = svg_node_to_msvg(self)
  node.clear_dirty()
  copy_svg_node_effect_state_from_msvg(self, node)
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
  text_decoration_full_from_msvg(@msvg.TextDecorationFull::default())
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
  text_style_from_msvg(@msvg.TextStyle::default())
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
  text_span_from_msvg(@msvg.TextSpan::new(text))
}

///|
pub fn TextSpan::with_offset(
  text : String,
  dx : Double,
  dy : Double,
) -> TextSpan {
  text_span_from_msvg(@msvg.TextSpan::with_offset(text, dx, dy))
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
  text_block_from_msvg(@msvg.TextBlock::new(x, y, text))
}

///|
pub fn TextBlock::with_style(
  x : Double,
  y : Double,
  text : String,
  style : TextStyle,
) -> TextBlock {
  text_block_from_msvg(
    @msvg.TextBlock::with_style(x, y, text, text_style_to_msvg(style)),
  )
}

///|
/// Create a text block with wrapping
pub fn TextBlock::with_wrap(
  x : Double,
  y : Double,
  text : String,
  inline_size : Double,
) -> TextBlock {
  text_block_from_msvg(@msvg.TextBlock::with_wrap(x, y, text, inline_size))
}

///|
pub fn TextBlock::add_span(self : TextBlock, span : TextSpan) -> Unit {
  self.spans.push(span)
}

///|
/// Calculate text width (simplified - assumes monospace)
pub fn TextBlock::get_width(self : TextBlock) -> Double {
  text_block_to_msvg(self).get_width()
}

///|
/// Get text height
pub fn TextBlock::get_height(self : TextBlock) -> Double {
  text_block_to_msvg(self).get_height()
}

///|
/// Get adjusted x position based on text-anchor
pub fn TextBlock::get_anchor_x(self : TextBlock) -> Double {
  text_block_to_msvg(self).get_anchor_x()
}

///|
/// Get adjusted y position based on dominant-baseline
pub fn TextBlock::get_baseline_y(self : TextBlock) -> Double {
  text_block_to_msvg(self).get_baseline_y()
}

///|
/// Wrap text to fit within inline_size, returns lines
pub fn TextBlock::wrap_text(self : TextBlock) -> Array[String] {
  text_block_to_msvg(self).wrap_text()
}

///|
/// Get the number of lines when text is wrapped
pub fn TextBlock::get_line_count(self : TextBlock) -> Int {
  text_block_to_msvg(self).get_line_count()
}

///|
/// Get total height including all wrapped lines
pub fn TextBlock::get_total_height(self : TextBlock) -> Double {
  text_block_to_msvg(self).get_total_height()
}

///|
/// Check if text is vertical (for writing-mode)
pub fn TextBlock::is_vertical(self : TextBlock) -> Bool {
  text_block_to_msvg(self).is_vertical()
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
  match
    use_element_to_msvg(self).instantiate(symbol_registry_to_msvg(registry)) {
    Some(node) => Some(svg_node_from_msvg(node))
    None => None
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
  marked_line_from_msvg(@msvg.MarkedLine::new(points))
}

///|
pub fn MarkedLine::with_markers(
  points : Array[(Double, Double)],
  start : String?,
  mid : String?,
  end : String?,
) -> MarkedLine {
  marked_line_from_msvg(@msvg.MarkedLine::with_markers(points, start, mid, end))
}

///|
/// Get angle at a point on the line
pub fn MarkedLine::get_angle_at(self : MarkedLine, index : Int) -> Double {
  marked_line_to_msvg(self).get_angle_at(index)
}
