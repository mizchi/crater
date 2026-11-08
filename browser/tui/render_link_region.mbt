///|
/// TUI link hit-test region helpers.

///|
/// A clickable link region on screen.
pub(all) struct LinkRegion {
  col : Int32 // Start column
  row : Int32 // Start row
  width : Int32 // Width in characters
  height : Int32 // Height in characters
  text : String // Link text (used to match with Browser.links for href)
  source_id : String // Source element id for DOM event dispatch
}

///|
/// Check if a point is inside this link region.
pub fn LinkRegion::contains(
  self : LinkRegion,
  col : Int32,
  row : Int32,
) -> Bool {
  col >= self.col &&
  col < self.col + self.width &&
  row >= self.row &&
  row < self.row + self.height
}

///|
/// Find link at given screen coordinates.
pub fn find_link_at(
  regions : Array[LinkRegion],
  col : Int32,
  row : Int32,
) -> String? {
  match find_link_region_at(regions, col, row) {
    Some(region) => Some(region.text)
    None => None
  }
}

///|
/// Find link region at given screen coordinates.
pub fn find_link_region_at(
  regions : Array[LinkRegion],
  col : Int32,
  row : Int32,
) -> LinkRegion? {
  for region in regions {
    if region.contains(col, row) {
      return Some(region)
    }
  }
  None
}
