///|
/// Initialize DOM tree and script executor
fn Browser::init_js_execution(self : Browser) -> Unit {
  // Build from parsed_doc/html_content when available so scripts can mutate
  // existing DOM and those mutations can be reflected back to rendering.
  let shadow_source_html = if html_source_requires_runtime_rebuild(
      self.source_html,
    ) {
    self.source_html
  } else if html_source_requires_runtime_rebuild(self.dom_snapshot_html) {
    self.dom_snapshot_html
  } else if html_source_requires_runtime_rebuild(self.html_content) {
    self.html_content
  } else {
    ""
  }
  let dom = if shadow_source_html.length() > 0 {
    match build_dom_tree_from_source_html(shadow_source_html) {
      Some(dom) => dom
      None =>
        match self.parsed_doc {
          Some(doc) => build_dom_tree_from_document(doc)
          None =>
            if self.html_content.length() > 0 {
              let doc = @html.assign_synthetic_ids(
                @html.parse_document(self.html_content),
              )
              self.parsed_doc = Some(doc)
              build_dom_tree_from_document(doc)
            } else {
              create_empty_html_dom_tree()
            }
        }
    }
  } else {
    match self.parsed_doc {
      Some(doc) => build_dom_tree_from_document(doc)
      None =>
        if self.html_content.length() > 0 {
          let doc = @html.assign_synthetic_ids(
            @html.parse_document(self.html_content),
          )
          self.parsed_doc = Some(doc)
          build_dom_tree_from_document(doc)
        } else {
          create_empty_html_dom_tree()
        }
    }
  }
  self.dom_tree = Some(dom)
  self.script_executor = Some(
    match self.js_runtime_override {
      Some(runtime) => @js.ScriptExecutor::new_with_runtime(dom, runtime)
      None => @js.ScriptExecutor::new_deferred(dom)
    },
  )
  match self.script_executor {
    Some(executor) =>
      ignore(executor.execute_source(browser_form_submit_bridge_source())) catch {
        err => println("[JS] Error: " + err.to_string())
      }
    None => ()
  }
}

///|
/// Apply JS-mutated DomTree back to renderer inputs and invalidate caches
fn Browser::sync_render_state_from_dom_tree(self : Browser) -> Bool {
  match self.dom_tree {
    Some(dom) => {
      let next_html = @js.serialize_dom_to_html(dom)
      let next_snapshot_html = @js.serialize_dom_to_snapshot_html(dom)
      if next_html.length() == 0 {
        return false
      }
      let render_changed = next_html != self.html_content
      let snapshot_changed = next_snapshot_html != self.dom_snapshot_html
      if !render_changed && !snapshot_changed {
        return false
      }
      self.dom_snapshot_html = next_snapshot_html
      self.source_html = next_snapshot_html
      if !render_changed {
        return false
      }
      self.html_content = next_html
      self.html_has_declarative_shadow_dom = html_source_has_declarative_shadow_dom(
        self.html_content,
      )
      let next_doc = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(next_doc)
      self.refresh_links_from_render_source()
      if self.links.length() == 0 {
        self.focused_link = 0
      } else if self.focused_link >= self.links.length() {
        self.focused_link = self.links.length() - 1
      }
      self.clear_render_cache()
      self.content_height = @renderer.get_content_height_with_document(
        next_doc,
        self.viewport_width,
        self.viewport_height,
        self.external_css,
      )
      self.build_accessibility_tree()
      true
    }
    None => false
  }
}
