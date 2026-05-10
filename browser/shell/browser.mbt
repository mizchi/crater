///|
/// Browser Shell - TUI browser application layer

///|
/// Set HTML content directly (for testing or headless rendering).
pub fn Browser::set_html_content(self : Browser, html : String) -> Unit {
  self.source_html = html
  let has_declarative_shadow_dom = html_source_has_declarative_shadow_dom(html)
  match
    normalize_declarative_shadow_source_html_with_hint(
      html, has_declarative_shadow_dom,
    ) {
    Some(normalized) => {
      self.html_content = normalized.render_html
      self.dom_snapshot_html = normalized.snapshot_html
      self.parsed_doc = Some(normalized.parsed_doc)
      self.html_has_declarative_shadow_dom = false
    }
    None => {
      self.html_content = html
      self.dom_snapshot_html = html
      self.parsed_doc = Some(
        @html.assign_synthetic_ids(@html.parse_document(self.html_content)),
      )
      self.html_has_declarative_shadow_dom = has_declarative_shadow_dom
    }
  }
  self.refresh_links_from_render_source()
  self.focused_link = 0
  self.scroll_y = 0
  self.clear_element_scroll_states()
  self.clear_render_cache()
  self.content_height = 0
  self.a11y_tree = None
  self.focus_manager = None
  self.dom_tree = None
  self.script_executor = None
}
