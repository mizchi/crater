///|
/// Debug: print layout tree
pub fn Browser::debug_layout(self : Browser) -> Unit {
  if self.html_content.length() == 0 {
    println("No content loaded")
    return
  }
  let ctx = @browser_helpers.create_render_context(
    self.viewport_width,
    self.viewport_height,
    false,
  )
  let layout = match self.parsed_doc {
    Some(doc) => self.render_node_and_layout_from_document(doc, ctx, false).1
    None =>
      @renderer.render_with_external_css(
        self.html_content,
        ctx,
        self.external_css,
      )
  }
  println("=== Layout Tree ===")
  @renderer.print_layout_tree_with_options(layout, 0, true)
  println("===================")
  println("Total content height: " + layout.height.to_string())
}

///|
/// Render accessibility tree as JSON (for AI scraping)
fn Browser::render_json(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) => tree.to_aria_json()
    None => "{}"
  }
}

///|
/// Render accessibility tree as YAML (Playwright-compatible)
fn Browser::render_aom(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) => tree.to_aria_snapshot()
    None => ""
  }
}

///|
/// Run Arc90 content extraction and return result
fn Browser::render_arc90(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) =>
      @browser_helpers.render_arc90_summary(
        tree,
        self.viewport_width,
        self.viewport_height,
      )
    None => "No accessibility tree available."
  }
}

///|
/// Extract main content text using Arc90 algorithm
fn Browser::render_extract_main(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) =>
      @browser_helpers.extract_main_text(
        tree,
        self.viewport_width,
        self.viewport_height,
      )
    None => "No accessibility tree available."
  }
}

///|
/// Run visual grounding demo and return results
fn Browser::render_grounding(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) =>
      @browser_helpers.render_grounding_demo(
        tree,
        self.viewport_width,
        self.viewport_height,
      )
    None => "No accessibility tree available."
  }
}
