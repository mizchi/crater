///|
/// Public TUI render result types.

///|
/// Render result containing ANSI string and link regions.
pub(all) struct RenderResult {
  ansi : String
  link_regions : Array[LinkRegion]
  hit_regions : Array[HitRegion]
}

///|
/// Region where an image should be rendered via graphics protocol.
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
/// Render result with raw buffer for diff rendering.
pub(all) struct BufferRenderResult {
  buffer : CharBuffer
  link_regions : Array[LinkRegion]
  hit_regions : Array[HitRegion]
  scrollable_elements : Array[@tui_paint_runtime.ScrollableElement]
  image_regions : Array[ImageRegion]
}
