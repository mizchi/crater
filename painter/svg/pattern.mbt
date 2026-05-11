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
