///|
fn Browser::set_external_css(
  self : Browser,
  external_css : Array[String],
) -> Unit {
  self.external_css = external_css
  self.prepared_external_css = Some(
    @renderer.prepare_external_css(external_css),
  )
  self.prepared_render_document = None
}

///|
fn Browser::external_css_handle(
  self : Browser,
) -> @renderer.PreparedExternalCss {
  match self.prepared_external_css {
    Some(prepared) => prepared
    None => {
      let prepared = @renderer.prepare_external_css(self.external_css)
      self.prepared_external_css = Some(prepared)
      prepared
    }
  }
}

///|
fn Browser::clear_render_cache(self : Browser) -> Unit {
  self.render_node = None
  self.layout_tree = None
  self.graphics_render_node = None
  self.graphics_layout = None
  self.prev_buffer = None
  self.last_render_key = ""
  self.prepared_render_document = None
}

///|
fn Browser::prepare_render_document_for_context(
  self : Browser,
  doc : @html.Document,
  ctx : @renderer.RenderContext,
  dark : Bool,
) -> @renderer.PreparedRenderDocument {
  match self.prepared_render_document {
    Some(prepared) if self.prepared_render_document_dark == dark => prepared
    _ => {
      let prepared = @renderer.prepare_render_document_with_prepared_external_css(
        doc,
        ctx,
        self.external_css_handle(),
      )
      self.prepared_render_document = Some(prepared)
      self.prepared_render_document_dark = dark
      prepared
    }
  }
}

///|
fn Browser::render_node_from_document(
  self : Browser,
  doc : @html.Document,
  ctx : @renderer.RenderContext,
  dark : Bool,
) -> @layout.Node {
  let prepared = self.prepare_render_document_for_context(doc, ctx, dark)
  @renderer.build_render_root_node(doc, ctx, prepared)
}

///|
fn Browser::render_node_and_layout_from_document(
  self : Browser,
  doc : @html.Document,
  ctx : @renderer.RenderContext,
  dark : Bool,
) -> (@layout.Node, @layout_types.Layout) {
  let prepared = self.prepare_render_document_for_context(doc, ctx, dark)
  let node = @renderer.build_render_root_node(doc, ctx, prepared)
  let layout = @renderer.compute_layout_from_render_root(node, prepared, ctx)
  (node, layout)
}

///|
fn Browser::render_graphics_node_and_layout(
  self : Browser,
  ctx : @renderer.RenderContext,
  dark : Bool,
) -> (@layout.Node, @layout_types.Layout) {
  match (self.graphics_render_node, self.graphics_layout) {
    (Some(node), Some(layout)) if self.graphics_render_dark == dark =>
      (node, layout)
    _ => {
      let (node, layout) = match self.parsed_doc {
        Some(doc) => self.render_node_and_layout_from_document(doc, ctx, dark)
        None =>
          @renderer.render_to_node_and_layout_with_external_css(
            self.html_content,
            ctx,
            self.external_css,
          )
      }
      self.graphics_render_node = Some(node)
      self.graphics_layout = Some(layout)
      self.graphics_render_dark = dark
      (node, layout)
    }
  }
}
