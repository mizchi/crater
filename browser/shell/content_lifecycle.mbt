///|
fn Browser::apply_html_source(
  self : Browser,
  html : String,
  parse_fallback : Bool,
) -> Unit {
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
      self.parsed_doc = if parse_fallback {
        Some(
          @html.assign_synthetic_ids(@html.parse_document(self.html_content)),
        )
      } else {
        None
      }
      self.html_has_declarative_shadow_dom = has_declarative_shadow_dom
    }
  }
}

///|
fn Browser::ensure_parsed_content_document(self : Browser) -> Unit {
  match self.parsed_doc {
    Some(_) => ()
    None => {
      let doc = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(doc)
    }
  }
}

///|
fn Browser::reset_content_view_position(self : Browser) -> Unit {
  self.focused_link = 0
  self.scroll_y = 0
  self.clear_element_scroll_states()
}

///|
fn Browser::reset_content_derived_state(self : Browser) -> Unit {
  self.clear_render_cache()
  self.reset_content_measurement_state()
}

///|
fn Browser::reset_content_measurement_state(self : Browser) -> Unit {
  self.content_height = 0
  self.a11y_tree = None
  self.focus_manager = None
}

///|
/// Set HTML content directly (for testing or headless rendering).
pub fn Browser::set_html_content(self : Browser, html : String) -> Unit {
  self.apply_html_source(html, true)
  self.refresh_links_from_render_source()
  self.reset_content_view_position()
  self.reset_content_derived_state()
  self.dom_tree = None
  self.script_executor = None
}
