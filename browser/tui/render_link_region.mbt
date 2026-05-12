///|
/// TUI link hit-test region helpers.

///|
/// A clickable link region on screen.
pub(all) struct LinkRegion {
  col : Int // Start column
  row : Int // Start row
  width : Int // Width in characters
  height : Int // Height in characters
  text : String // Link text (used to match with Browser.links for href)
  source_id : String // Source element id for DOM event dispatch
}

///|
/// Check if a point is inside this link region.
pub fn LinkRegion::contains(self : LinkRegion, col : Int, row : Int) -> Bool {
  col >= self.col &&
  col < self.col + self.width &&
  row >= self.row &&
  row < self.row + self.height
}

///|
/// Find link at given screen coordinates.
pub fn find_link_at(
  regions : Array[LinkRegion],
  col : Int,
  row : Int,
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
  col : Int,
  row : Int,
) -> LinkRegion? {
  for region in regions {
    if region.contains(col, row) {
      return Some(region)
    }
  }
  None
}
