///|
fn Browser::get_link_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  for i = self.link_regions.length() - 1; i >= 0; i = i - 1 {
    let region = self.link_regions[i]
    if region.contains(col, row) {
      return Some(region.source_id)
    }
  }
  None
}

///|
fn Browser::is_clickable_source_id(self : Browser, source_id : String) -> Bool {
  match self.get_href_for_source_id(source_id) {
    Some(href) if href.length() > 0 => true
    _ => {
      if !self.enable_js {
        return false
      }
      let escaped = escape_js_string(source_id)
      let source = "(function(){const target=document.getElementById('" +
        escaped +
        "');if(!target){return false;}if(target.hasAttribute&&(target.hasAttribute('onclick')||target.hasAttribute('data-crater-listeners-click'))){return true;}const tag=(target.tagName||'').toLowerCase();if(tag==='button'||tag==='input'||tag==='select'||tag==='textarea'||tag==='summary'){return true;}const role=target.getAttribute?target.getAttribute('role'):null;return role==='button'||role==='link';})()"
      match self.execute_inline_js(source) {
        Some("true") => true
        _ => false
      }
    }
  }
}

///|
fn Browser::get_paint_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  if self.hit_regions.is_empty() {
    return None
  }
  let mut i = self.hit_regions.length() - 1
  while i >= 0 {
    let region = self.hit_regions[i]
    if region.contains(col, row) &&
      self.is_clickable_source_id(region.source_id) {
      return Some(region.source_id)
    }
    i = i - 1
  }
  None
}

///|
fn Browser::get_any_paint_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  match @tui.find_hit_region_at(self.hit_regions, col, row) {
    Some(region) => Some(region.source_id)
    None => None
  }
}

///|
fn bounds_contains_click(
  bounds : @aom.Bounds,
  px_x : Double,
  px_y : Double,
) -> Bool {
  px_x >= bounds.x &&
  px_x < bounds.x + bounds.width &&
  px_y >= bounds.y &&
  px_y < bounds.y + bounds.height
}

///|
fn find_smallest_a11y_hit_target(
  node : @aom.AccessibilityNode,
  px_x : Double,
  px_y : Double,
  current_best : HitTarget?,
) -> HitTarget? {
  let mut best = current_best
  match (node.source_id, node.bounds) {
    (Some(source_id), Some(bounds)) =>
      if bounds.width > 0.0 &&
        bounds.height > 0.0 &&
        bounds_contains_click(bounds, px_x, px_y) {
        let area = bounds.width * bounds.height
        match best {
          Some(existing) =>
            if area < existing.area {
              best = Some({ source_id, area })
            }
          None => best = Some({ source_id, area })
        }
      }
    _ => ()
  }
  for child in node.children {
    best = find_smallest_a11y_hit_target(child, px_x, px_y, best)
  }
  best
}

///|
fn Browser::get_a11y_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  if row <= 0 {
    return None
  }
  if self.a11y_tree is None {
    self.build_accessibility_tree()
  }
  let px_x = col.to_double() * 8.0 + 4.0
  let px_y = (row - 1 + self.scroll_y).to_double() * 16.0 + 8.0
  match self.a11y_tree {
    Some(tree) =>
      match find_smallest_a11y_hit_target(tree.root, px_x, px_y, None) {
        Some(target) => Some(target.source_id)
        None => None
      }
    None => None
  }
}

///|
fn Browser::get_source_id_at(self : Browser, col : Int, row : Int) -> String? {
  match self.get_link_source_id_at(col, row) {
    Some(source_id) => Some(source_id)
    None =>
      match self.get_paint_source_id_at(col, row) {
        Some(source_id) => Some(source_id)
        None => self.get_a11y_source_id_at(col, row)
      }
  }
}

///|
fn Browser::get_hover_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  match self.get_link_source_id_at(col, row) {
    Some(source_id) => Some(source_id)
    None =>
      match self.get_any_paint_source_id_at(col, row) {
        Some(source_id) => Some(source_id)
        None => self.get_a11y_source_id_at(col, row)
      }
  }
}

///|
/// Find link URL at screen coordinates (for mouse click)
/// Returns the resolved absolute URL if a link is found
pub fn Browser::get_link_at(self : Browser, col : Int, row : Int) -> String? {
  match self.get_link_source_id_at(col, row) {
    Some(source_id) =>
      match self.get_link_href_for_source_id(source_id) {
        Some(href) => Some(href)
        None =>
          match @tui.find_link_at(self.link_regions, col, row) {
            Some(link_text) => {
              for link in self.links {
                if link.text == link_text {
                  return Some(link.href)
                }
              }
              None
            }
            None => None
          }
      }
    None => None
  }
}
