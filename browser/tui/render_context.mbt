///|
/// TUI render context types shared by render entrypoints and node renderers.

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
