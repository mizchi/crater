///|
fn center_of_hit_source_id(browser : Browser, source_id : String) -> (Int, Int) {
  for region in browser.hit_regions {
    if region.source_id == source_id {
      return (region.col + region.width / 2, region.row + region.height / 2)
    }
  }
  panic()
}

///|
fn hit_region_of_source_id(
  browser : Browser,
  source_id : String,
) -> @tui.HitRegion {
  for region in browser.hit_regions {
    if region.source_id == source_id {
      return region
    }
  }
  panic()
}

///|
fn first_shared_hit_cell(a : @tui.HitRegion, b : @tui.HitRegion) -> (Int, Int) {
  let left = a.col.max(b.col)
  let top = a.row.max(b.row)
  let right = (a.col + a.width).min(b.col + b.width)
  let bottom = (a.row + a.height).min(b.row + b.height)
  if right <= left || bottom <= top {
    panic()
  }
  for row in top..<bottom {
    for col in left..<right {
      if a.contains(col, row) && b.contains(col, row) {
        return (col, row)
      }
    }
  }
  panic()
}

///|
fn link_region_of_source_id(
  browser : Browser,
  source_id : String,
) -> @tui.LinkRegion {
  for region in browser.link_regions {
    if region.source_id == source_id {
      return region
    }
  }
  panic()
}
