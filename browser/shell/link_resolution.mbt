///|
fn Browser::get_extracted_link_href_for_source_id(
  self : Browser,
  source_id : String,
) -> String? {
  for link in self.links {
    if link.source_id == source_id {
      return Some(link.href)
    }
  }
  None
}

///|
fn Browser::get_a11y_link_href_for_source_id(
  self : Browser,
  source_id : String,
) -> String? {
  if self.a11y_tree is None {
    self.build_accessibility_tree()
  }
  match self.a11y_tree {
    Some(tree) =>
      match tree.find_by_source_id(source_id) {
        Some(node) => node.href
        None => None
      }
    None => None
  }
}

///|
fn Browser::get_link_href_for_source_id(
  self : Browser,
  source_id : String,
) -> String? {
  match self.get_href_for_source_id(source_id) {
    Some(href) => Some(href)
    None =>
      match self.get_a11y_link_href_for_source_id(source_id) {
        Some(href) => Some(href)
        None => self.get_extracted_link_href_for_source_id(source_id)
      }
  }
}

///|
fn Browser::get_link_href_for_region(
  self : Browser,
  region : @tui.LinkRegion,
) -> String? {
  match self.get_link_href_for_source_id(region.source_id) {
    Some(href) => Some(href)
    None => {
      for link in self.links {
        if region.text == link.text {
          return Some(link.href)
        }
      }
      None
    }
  }
}

///|
fn Browser::get_href_for_source_id(
  self : Browser,
  source_id : String,
) -> String? {
  let escaped = escape_js_string(source_id)
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target||typeof target.getAttribute!=='function'){return '';}const href=target.getAttribute('href');return typeof href==='string'?href:'';})()"
  match self.execute_inline_js(source) {
    Some(href) if href.length() > 0 => Some(href)
    _ => None
  }
}
