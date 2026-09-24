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
  // Incremental (scoped) cascade — Phase 1, off by default. Only when the
  // stylesheet is reuse-safe do we run a reuse pass; prior styles are reused
  // only when the CSS signature is unchanged (a CSS edit resets the maps).
  if self.enable_cascade_reuse {
    let css_texts = self.cascade_reuse_css_texts()
    if css_texts.length() > 0 && @renderer.css_allows_cascade_reuse(css_texts) {
      let css_sig = css_texts.join("\u{01}")
      let use_prior = self.cascade_reuse_prev_css_sig == Some(css_sig)
      @renderer.cascade_reuse_begin(
        if use_prior {
          self.cascade_reuse_prior_styles
        } else {
          {}
        },
        if use_prior {
          self.cascade_reuse_prior_sigs
        } else {
          {}
        },
        uses_sibling=@renderer.css_uses_sibling_combinator(css_texts),
        uses_child_structure=@renderer.css_uses_child_structure(css_texts),
      )
      let node = @renderer.build_render_root_node(doc, ctx, prepared)
      let (styles, sigs, reused) = @renderer.cascade_reuse_end()
      self.cascade_reuse_prior_styles = styles
      self.cascade_reuse_prior_sigs = sigs
      self.cascade_reuse_prev_css_sig = Some(css_sig)
      self.cascade_reuse_last_count = reused
      return node
    }
  }
  @renderer.build_render_root_node(doc, ctx, prepared)
}

///|
/// The CSS texts that drive the cascade: external stylesheets plus any inline
/// `<style>` blocks in the current document. Used both to gate cascade reuse
/// (reuse-safe selectors only) and to signature the stylesheet so a CSS edit
/// invalidates the reused styles. Body text is deliberately excluded so a
/// text-only mutation keeps the same signature.
fn Browser::cascade_reuse_css_texts(self : Browser) -> Array[String] {
  let texts : Array[String] = []
  for css in self.external_css {
    texts.push(css)
  }
  extract_style_blocks(self.html_content, texts)
  texts
}

///|
/// Append the inner text of each `<style>…</style>` block in `html` to `out`.
/// A simple scan, case-insensitive on the tag name and tolerant of attributes
/// on the open tag. Anything unparsed just means no reuse (conservative).
fn extract_style_blocks(html : String, out : Array[String]) -> Unit {
  let lower = html.to_lower()
  let n = lower.length()
  let mut base = 0
  while base < n {
    match lower[base:].find("<style") {
      Some(rel_open) => {
        let open = base + rel_open
        match lower[open:].find(">") {
          Some(rel_gt) => {
            let gt = open + rel_gt
            match lower[gt:].find("</style") {
              Some(rel_close) => {
                let close = gt + rel_close
                out.push(html[gt + 1:close].to_owned())
                base = close + 1
              }
              None => break
            }
          }
          None => break
        }
      }
      None => break
    }
  }
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
