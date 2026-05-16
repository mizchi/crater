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
  Pattern::from_msvg(@msvg.Pattern::new(id, width, height, []), content)
}

///|
/// Get pattern color at a point (simplified - returns first solid color found)
pub fn Pattern::get_color_at(
  self : Pattern,
  x : Double,
  y : Double,
  bbox : BoundingBox,
) -> Color? {
  Color::from_msvg_option(
    self.to_msvg().get_color_at(x, y, bbox.to_msvg()),
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

///|
fn Pattern::from_msvg(
  pattern : @msvg.Pattern,
  content : Array[SVGNode],
) -> Pattern {
  {
    id: pattern.id,
    width: pattern.width,
    height: pattern.height,
    content,
    pattern_units: PatternUnits::from_msvg(pattern.pattern_units),
    pattern_content_units: PatternUnits::from_msvg(
      pattern.pattern_content_units,
    ),
    transform: Transform::from_msvg(pattern.transform),
  }
}

///|
fn Pattern::to_msvg(self : Pattern) -> @msvg.Pattern {
  @msvg.Pattern::{
    id: self.id,
    width: self.width,
    height: self.height,
    content: self.content.map(fn(n) { n.to_msvg() }),
    pattern_units: self.pattern_units.to_msvg(),
    pattern_content_units: self.pattern_content_units.to_msvg(),
    transform: self.transform.to_msvg(),
    view_box: None,
    preserve_aspect_ratio: @msvg.PreserveAspectRatio::default(),
  }
}

///|
fn PatternUnits::from_msvg(units : @msvg.PatternUnits) -> PatternUnits {
  match units {
    UserSpaceOnUse => UserSpaceOnUse
    ObjectBoundingBox => ObjectBoundingBox
  }
}

///|
fn PatternUnits::to_msvg(self : PatternUnits) -> @msvg.PatternUnits {
  match self {
    UserSpaceOnUse => @msvg.PatternUnits::UserSpaceOnUse
    ObjectBoundingBox => @msvg.PatternUnits::ObjectBoundingBox
  }
}
