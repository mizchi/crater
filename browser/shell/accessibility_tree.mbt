///|
fn Browser::ensure_declarative_shadow_dom_normalized(self : Browser) -> Unit {
  match self.dom_tree {
    Some(_) => return
    None => ()
  }
  if !self.html_has_declarative_shadow_dom {
    return
  }
  match build_dom_tree_from_source_html(self.html_content) {
    Some(dom) => {
      self.dom_tree = Some(dom)
      let _ = self.sync_render_state_from_dom_tree()
    }
    None => ()
  }
}

///|
/// Build accessibility tree from current HTML content
fn Browser::build_accessibility_tree(self : Browser) -> Unit {
  self.ensure_declarative_shadow_dom_normalized()
  let previous_focus_source_id = match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) => node.source_id
        None => None
      }
    None => None
  }
  // Use cached parsed document if available
  let doc = match self.parsed_doc {
    Some(d) => d
    None => {
      if self.html_content.length() == 0 {
        self.a11y_tree = None
        self.focus_manager = None
        return
      }
      // Fallback: parse if not cached (shouldn't happen in normal flow)
      let d = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(d)
      d
    }
  }
  // Use the renderer's layout which applies CSS properly
  let ctx = @browser_contract.create_render_context(
    self.viewport_width,
    self.viewport_height,
    false,
  )
  // Render with CSS to get proper layout bounds
  // Use the document with synthetic IDs for consistent ID matching
  let (_, layout) = self.render_node_and_layout_from_document(doc, ctx, false)
  // Build accessibility tree with renderer's layout bounds
  let tree = @aom.build_accessibility_tree_with_node_layout(doc, layout)
  self.a11y_tree = Some(tree)
  // Create focus manager
  self.focus_manager = Some(@aom.FocusManager::new(tree))
  match (self.focus_manager, previous_focus_source_id) {
    (Some(fm), Some(source_id)) => {
      let _ = fm.focus_by_source_id(source_id)
    }
    _ => ()
  }
}

///|
/// Build lightweight accessibility tree (no CSS cascade, no layout)
/// Used for --json and --aom modes to reduce memory usage
fn Browser::build_accessibility_tree_lightweight(self : Browser) -> Unit {
  self.ensure_declarative_shadow_dom_normalized()
  // Use cached parsed document if available
  let doc = match self.parsed_doc {
    Some(d) => d
    None => {
      if self.html_content.length() == 0 {
        self.a11y_tree = None
        self.focus_manager = None
        return
      }
      // Parse with regular parser
      let d = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(d)
      d
    }
  }
  // Build lightweight accessibility tree (skips CSS cascade and layout)
  let tree = @aom.build_accessibility_tree_lightweight(doc)
  self.a11y_tree = Some(tree)
  // No focus manager needed for JSON/AOM output
  self.focus_manager = None
}
