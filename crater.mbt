///|
/// 2D size with width and height
pub struct Size[T] {
  width : T
  height : T
}

///|
pub fn[T] Size::new(width : T, height : T) -> Size[T] {
  { width, height }
}

///|
pub impl[T : Show] Show for Size[T] with output(self, logger) {
  logger.write_string("Size { width: ")
  self.width.output(logger)
  logger.write_string(", height: ")
  self.height.output(logger)
  logger.write_string(" }")
}

///|
pub fn Size::zero() -> Size[Double] {
  { width: 0.0, height: 0.0 }
}

///|
pub fn[T, U] Size::map(self : Size[T], f : (T) -> U) -> Size[U] {
  { width: f(self.width), height: f(self.height) }
}

///|
/// 2D point with x and y coordinates
pub struct Point[T] {
  x : T
  y : T
}

///|
pub fn[T] Point::new(x : T, y : T) -> Point[T] {
  { x, y }
}

///|
pub impl[T : Show] Show for Point[T] with output(self, logger) {
  logger.write_string("Point { x: ")
  self.x.output(logger)
  logger.write_string(", y: ")
  self.y.output(logger)
  logger.write_string(" }")
}

///|
pub fn Point::zero() -> Point[Double] {
  { x: 0.0, y: 0.0 }
}

///|
pub fn[T, U] Point::map(self : Point[T], f : (T) -> U) -> Point[U] {
  { x: f(self.x), y: f(self.y) }
}

///|
/// Rectangle with left, right, top, bottom edges
/// Used for margin, padding, border, inset
pub(all) struct Rect[T] {
  left : T
  right : T
  top : T
  bottom : T
}

///|
pub fn[T] Rect::new(left : T, right : T, top : T, bottom : T) -> Rect[T] {
  { left, right, top, bottom }
}

///|
pub impl[T : Show] Show for Rect[T] with output(self, logger) {
  logger.write_string("Rect { left: ")
  self.left.output(logger)
  logger.write_string(", right: ")
  self.right.output(logger)
  logger.write_string(", top: ")
  self.top.output(logger)
  logger.write_string(", bottom: ")
  self.bottom.output(logger)
  logger.write_string(" }")
}

///|
pub fn Rect::zero() -> Rect[Double] {
  { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 }
}

///|
pub fn[T, U] Rect::map(self : Rect[T], f : (T) -> U) -> Rect[U] {
  {
    left: f(self.left),
    right: f(self.right),
    top: f(self.top),
    bottom: f(self.bottom),
  }
}

///|
/// Sum of left and right (horizontal axis)
pub fn Rect::horizontal_sum(self : Rect[Double]) -> Double {
  self.left + self.right
}

///|
/// Sum of top and bottom (vertical axis)
pub fn Rect::vertical_sum(self : Rect[Double]) -> Double {
  self.top + self.bottom
}

///|
/// A line segment with start and end points
pub struct Line[T] {
  start : T
  end : T
}

///|
pub fn[T] Line::new(start : T, end : T) -> Line[T] {
  { start, end }
}

///|
pub impl[T : Show] Show for Line[T] with output(self, logger) {
  logger.write_string("Line { start: ")
  self.start.output(logger)
  logger.write_string(", end: ")
  self.end.output(logger)
  logger.write_string(" }")
}

///|
/// CSS dimension value: length, percentage, or auto
pub(all) enum Dimension {
  Length(Double)
  Percent(Double) // 0.0 to 1.0
  Auto
}

///|
pub impl Show for Dimension with output(self, logger) {
  match self {
    Length(v) => {
      logger.write_string("Length(")
      v.output(logger)
      logger.write_string(")")
    }
    Percent(v) => {
      logger.write_string("Percent(")
      v.output(logger)
      logger.write_string(")")
    }
    Auto => logger.write_string("Auto")
  }
}

///|
/// Resolve dimension to concrete value
/// context: parent size for percentage calculation
pub fn Dimension::resolve(self : Dimension, context : Double) -> Double? {
  match self {
    Length(v) => Some(v)
    Percent(v) => Some(context * v)
    Auto => None
  }
}

///|
/// Resolve with fallback value for Auto
pub fn Dimension::resolve_or(
  self : Dimension,
  context : Double,
  fallback : Double,
) -> Double {
  match self.resolve(context) {
    Some(v) => v
    None => fallback
  }
}

///|
/// BoundingRect - the output of layout computation
/// Matches browser's getBoundingClientRect()
pub struct BoundingRect {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub fn BoundingRect::new(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> BoundingRect {
  { x, y, width, height }
}

///|
pub impl Show for BoundingRect with output(self, logger) {
  logger.write_string("BoundingRect { x: ")
  self.x.output(logger)
  logger.write_string(", y: ")
  self.y.output(logger)
  logger.write_string(", width: ")
  self.width.output(logger)
  logger.write_string(", height: ")
  self.height.output(logger)
  logger.write_string(" }")
}

///|
pub fn BoundingRect::zero() -> BoundingRect {
  { x: 0.0, y: 0.0, width: 0.0, height: 0.0 }
}

///|
/// Get the right edge (x + width)
pub fn BoundingRect::right(self : BoundingRect) -> Double {
  self.x + self.width
}

///|
/// Get the bottom edge (y + height)
pub fn BoundingRect::bottom(self : BoundingRect) -> Double {
  self.y + self.height
}

///|
/// Calculate the area of the bounding rect
pub fn BoundingRect::area(self : BoundingRect) -> Double {
  self.width * self.height
}

///|
/// Calculate union of two bounding rects
pub fn BoundingRect::union(
  self : BoundingRect,
  other : BoundingRect,
) -> BoundingRect {
  let x = @cmp.minimum(self.x, other.x)
  let y = @cmp.minimum(self.y, other.y)
  let right = @cmp.maximum(self.right(), other.right())
  let bottom = @cmp.maximum(self.bottom(), other.bottom())
  { x, y, width: right - x, height: bottom - y }
}

// =============================================================================
// CSS Display and Position
// =============================================================================

///|
/// CSS display property
pub(all) enum Display {
  Block
  Flex
  Grid
  None
}

///|
pub impl Show for Display with output(self, logger) {
  match self {
    Block => logger.write_string("Block")
    Flex => logger.write_string("Flex")
    Grid => logger.write_string("Grid")
    None => logger.write_string("None")
  }
}

///|
/// CSS position property
pub(all) enum Position {
  Relative
  Absolute
}

///|
pub impl Show for Position with output(self, logger) {
  match self {
    Relative => logger.write_string("Relative")
    Absolute => logger.write_string("Absolute")
  }
}

///|
/// Flex direction
pub(all) enum FlexDirection {
  Row
  RowReverse
  Column
  ColumnReverse
}

///|
pub impl Show for FlexDirection with output(self, logger) {
  match self {
    Row => logger.write_string("Row")
    RowReverse => logger.write_string("RowReverse")
    Column => logger.write_string("Column")
    ColumnReverse => logger.write_string("ColumnReverse")
  }
}

///|
/// Alignment for justify-content, align-items, etc.
pub(all) enum Alignment {
  Start
  End
  Center
  SpaceBetween
  SpaceAround
  SpaceEvenly
  Stretch
}

///|
pub impl Show for Alignment with output(self, logger) {
  match self {
    Start => logger.write_string("Start")
    End => logger.write_string("End")
    Center => logger.write_string("Center")
    SpaceBetween => logger.write_string("SpaceBetween")
    SpaceAround => logger.write_string("SpaceAround")
    SpaceEvenly => logger.write_string("SpaceEvenly")
    Stretch => logger.write_string("Stretch")
  }
}

// =============================================================================
// Style
// =============================================================================

///|
/// CSS Style definition for layout computation
pub(all) struct Style {
  display : Display
  position : Position
  // Sizing
  width : Dimension
  height : Dimension
  min_width : Dimension
  min_height : Dimension
  max_width : Dimension
  max_height : Dimension
  // Box model
  margin : Rect[Dimension]
  padding : Rect[Dimension]
  border : Rect[Dimension]
  // Flexbox
  flex_direction : FlexDirection
  justify_content : Alignment
  align_items : Alignment
  flex_grow : Double
  flex_shrink : Double
}

///|
pub fn Style::default() -> Style {
  {
    display: Block,
    position: Relative,
    width: Auto,
    height: Auto,
    min_width: Auto,
    min_height: Auto,
    max_width: Auto,
    max_height: Auto,
    margin: {
      left: Length(0.0),
      right: Length(0.0),
      top: Length(0.0),
      bottom: Length(0.0),
    },
    padding: {
      left: Length(0.0),
      right: Length(0.0),
      top: Length(0.0),
      bottom: Length(0.0),
    },
    border: {
      left: Length(0.0),
      right: Length(0.0),
      top: Length(0.0),
      bottom: Length(0.0),
    },
    flex_direction: Row,
    justify_content: Start,
    align_items: Stretch,
    flex_grow: 0.0,
    flex_shrink: 1.0,
  }
}

// =============================================================================
// Layout Node
// =============================================================================

///|
/// A node in the layout tree
pub struct Node {
  id : String
  style : Style
  children : Array[Node]
}

///|
pub fn Node::new(id : String, style : Style, children : Array[Node]) -> Node {
  { id, style, children }
}

///|
pub fn Node::leaf(id : String, style : Style) -> Node {
  { id, style, children: [] }
}

// =============================================================================
// Layout Result
// =============================================================================

///|
/// Complete layout result for a node
pub struct Layout {
  x : Double
  y : Double
  width : Double
  height : Double
  // Box model resolved values
  margin : Rect[Double]
  padding : Rect[Double]
  border : Rect[Double]
  // Children layouts
  children : Array[Layout]
}

///|
pub fn Layout::to_bounding_rect(self : Layout) -> BoundingRect {
  { x: self.x, y: self.y, width: self.width, height: self.height }
}

// =============================================================================
// CLS (Cumulative Layout Shift) Calculation
// =============================================================================

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
  before : BoundingRect,
  after : BoundingRect,
  viewport : Size[Double],
) -> LayoutShift {
  let viewport_area = viewport.width * viewport.height

  // Impact fraction: union of before and after areas / viewport area
  let union_rect = before.union(after)
  let impact_fraction = union_rect.area() / viewport_area

  // Distance fraction: max movement / max viewport dimension
  let dx = (after.x - before.x).abs()
  let dy = (after.y - before.y).abs()
  let max_distance = @cmp.maximum(dx, dy)
  let max_viewport_dim = @cmp.maximum(viewport.width, viewport.height)
  let distance_fraction = max_distance / max_viewport_dim
  let score = impact_fraction * distance_fraction
  { impact_fraction, distance_fraction, score }
}

///|
/// Calculate total CLS score for multiple elements
pub fn compute_total_cls(
  before : Array[BoundingRect],
  after : Array[BoundingRect],
  viewport : Size[Double],
) -> Double {
  let len = @cmp.minimum(before.length(), after.length())
  let mut total = 0.0
  for i = 0; i < len; i = i + 1 {
    let shift = compute_element_shift(before[i], after[i], viewport)
    total = total + shift.score
  }
  total
}

// =============================================================================
// Block Layout Algorithm
// =============================================================================

///|
/// Context for layout computation
pub struct LayoutContext {
  /// Available width from parent
  available_width : Double
  /// Available height from parent (may be undefined)
  available_height : Double?
}

///|
/// Resolve a Rect[Dimension] (margin/padding/border) to Rect[Double]
/// CSS spec: percentage values are ALWAYS relative to parent's WIDTH
/// (even for top/bottom margin/padding)
fn resolve_rect(rect : Rect[Dimension], parent_width : Double) -> Rect[Double] {
  {
    left: rect.left.resolve_or(parent_width, 0.0),
    right: rect.right.resolve_or(parent_width, 0.0),
    top: rect.top.resolve_or(parent_width, 0.0),
    bottom: rect.bottom.resolve_or(parent_width, 0.0),
  }
}

///|
/// Compute block layout for a node and its children
pub fn compute_block_layout(node : Node, ctx : LayoutContext) -> Layout {
  let style = node.style

  // Resolve box model
  // CSS spec: percentage margins/padding are always relative to parent's WIDTH
  let parent_width = ctx.available_width
  let parent_height = ctx.available_height.unwrap_or(0.0)
  let margin = resolve_rect(style.margin, parent_width)
  let padding = resolve_rect(style.padding, parent_width)
  let border = resolve_rect(style.border, parent_width)

  // Box width (border-box model, like CSS box-sizing: border-box)
  // This is the total width including padding and border
  let mut box_width = match style.width {
    Length(w) => w
    Percent(p) => parent_width * p
    Auto => parent_width - margin.horizontal_sum()
  }

  // Apply min/max width constraints
  match style.min_width {
    Length(min_w) => if box_width < min_w { box_width = min_w }
    Percent(p) => {
      let min_w = parent_width * p
      if box_width < min_w {
        box_width = min_w
      }
    }
    Auto => ()
  }
  match style.max_width {
    Length(max_w) => if box_width > max_w { box_width = max_w }
    Percent(p) => {
      let max_w = parent_width * p
      if box_width > max_w {
        box_width = max_w
      }
    }
    Auto => ()
  }

  // Available width for children (content area)
  let child_available_width = box_width -
    padding.horizontal_sum() -
    border.horizontal_sum()

  // Calculate available height for children based on parent's specified height
  let child_available_height : Double? = match style.height {
    Length(h) => Some(h - padding.vertical_sum() - border.vertical_sum())
    Percent(p) => Some(parent_height * p - padding.vertical_sum() - border.vertical_sum())
    Auto => None
  }

  // Layout children with margin collapsing
  let child_layouts : Array[Layout] = []
  let mut current_y = 0.0
  let mut prev_margin_bottom = 0.0
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    let child_ctx : LayoutContext = {
      available_width: child_available_width,
      available_height: child_available_height,
    }
    let child_layout = compute_block_layout(child, child_ctx)

    // Calculate collapsed margin between siblings
    // Adjacent vertical margins collapse to the maximum of the two
    let collapsed_margin = if i == 0 {
      child_layout.margin.top
    } else {
      @cmp.maximum(prev_margin_bottom, child_layout.margin.top)
    }

    // Position child relative to content area
    let positioned_layout : Layout = {
      x: child_layout.margin.left + padding.left + border.left,
      y: current_y + collapsed_margin + padding.top + border.top,
      width: child_layout.width,
      height: child_layout.height,
      margin: child_layout.margin,
      padding: child_layout.padding,
      border: child_layout.border,
      children: child_layout.children,
    }
    child_layouts.push(positioned_layout)
    current_y = current_y + collapsed_margin + child_layout.height
    prev_margin_bottom = child_layout.margin.bottom
  }

  // Add final margin to content height
  current_y = current_y + prev_margin_bottom

  // Box height (border-box model)
  let mut box_height = match style.height {
    Length(h) => h
    Percent(p) => parent_height * p
    Auto => current_y + padding.vertical_sum() + border.vertical_sum()
  }

  // Apply min/max height constraints
  match style.min_height {
    Length(min_h) => if box_height < min_h { box_height = min_h }
    Percent(p) => {
      let min_h = parent_height * p
      if box_height < min_h {
        box_height = min_h
      }
    }
    Auto => ()
  }
  match style.max_height {
    Length(max_h) => if box_height > max_h { box_height = max_h }
    Percent(p) => {
      let max_h = parent_height * p
      if box_height > max_h {
        box_height = max_h
      }
    }
    Auto => ()
  }

  {
    x: 0.0,
    y: 0.0,
    width: box_width,
    height: box_height,
    margin,
    padding,
    border,
    children: child_layouts,
  }
}

///|
/// Compute layout for a node tree with given viewport
pub fn compute_layout(node : Node, viewport : Size[Double]) -> Layout {
  let ctx : LayoutContext = {
    available_width: viewport.width,
    available_height: Some(viewport.height),
  }
  compute_block_layout(node, ctx)
}
