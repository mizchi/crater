///|
fn center_of_hit_source_id(browser : Browser, source_id : String) -> (Int, Int) {
  for region in browser.hit_regions {
    if region.source_id == source_id {
      return (region.col + region.width / 2, region.row + region.height / 2)
    }
  }
  panic()
}
