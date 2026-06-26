///|
fn make_render_context(
  viewport : @types.Size[Double],
) -> @renderer.RenderContext {
  {
    ..@renderer.RenderContext::default(),
    viewport_width: viewport.width,
    viewport_height: viewport.height,
  }
}

///|
fn paint_tree_from_node_layout(
  node : @layout.Node,
  layout : @layout_types.Layout,
  viewport : @types.Size[Double],
) -> @paint_model.PaintNode {
  match
    @paint_render.from_node_and_layout_with_viewport_rect(
      node,
      layout,
      0.0,
      0.0,
      viewport.width,
      viewport.height,
      0.0,
      0.0,
    ) {
    Some(paint_tree) => paint_tree
    None => @paint_render.from_node_and_layout(node, layout)
  }
}

///|
pub(all) struct PreparedVrtPage {
  doc : @html.Document
  viewport : @types.Size[Double]
  ctx : @renderer.RenderContext
  prepared : @renderer.PreparedRenderDocument
}

///|
pub fn prepare_external_css(
  external_css : Array[String],
) -> @renderer.PreparedExternalCss {
  @renderer.prepare_external_css(external_css)
}

///|
pub fn prepare_vrt_page(
  html : String,
  viewport : @types.Size[Double],
  external_css : Array[String],
) -> PreparedVrtPage {
  let doc = @html.parse_document(html)
  let ctx = make_render_context(viewport)
  {
    doc,
    viewport,
    ctx,
    prepared: @renderer.prepare_render_document(doc, ctx, external_css),
  }
}

///|
pub fn prepare_vrt_page_with_prepared_external_css(
  html : String,
  viewport : @types.Size[Double],
  external_css : @renderer.PreparedExternalCss,
) -> PreparedVrtPage {
  let doc = @html.parse_document(html)
  let ctx = make_render_context(viewport)
  {
    doc,
    viewport,
    ctx,
    prepared: @renderer.prepare_render_document_with_prepared_external_css(
      doc, ctx, external_css,
    ),
  }
}

///|
pub fn render_prepared_vrt_page_to_paint_tree(
  page : PreparedVrtPage,
) -> @paint_model.PaintNode {
  let node = @renderer.build_render_root_node(page.doc, page.ctx, page.prepared)
  let layout = @renderer.compute_layout_from_render_root(
    node,
    page.prepared,
    page.ctx,
  )
  paint_tree_from_node_layout(node, layout, page.viewport)
}

///|
pub fn render_prepared_vrt_page_to_paint_tree_json(
  page : PreparedVrtPage,
) -> String {
  render_prepared_vrt_page_to_paint_tree(page).to_json_string()
}

///|
pub fn render_html_to_paint_tree(
  html : String,
  viewport : @types.Size[Double],
) -> @paint_model.PaintNode {
  render_html_to_paint_tree_with_external_css(html, viewport, [])
}

///|
pub fn render_html_to_paint_tree_with_external_css(
  html : String,
  viewport : @types.Size[Double],
  external_css : Array[String],
) -> @paint_model.PaintNode {
  let (node, layout) = @renderer.render_to_node_and_layout_with_external_css(
    html,
    make_render_context(viewport),
    external_css,
  )
  paint_tree_from_node_layout(node, layout, viewport)
}

///|
pub fn render_html_to_paint_tree_with_prepared_external_css(
  html : String,
  viewport : @types.Size[Double],
  external_css : @renderer.PreparedExternalCss,
) -> @paint_model.PaintNode {
  let doc = @html.parse_document(html)
  let (node, layout) = @renderer.render_to_node_and_layout_with_prepared_external_css(
    doc,
    make_render_context(viewport),
    external_css,
  )
  paint_tree_from_node_layout(node, layout, viewport)
}

///|
pub fn render_html_to_paint_tree_json(
  html : String,
  viewport : @types.Size[Double],
) -> String {
  render_html_to_paint_tree(html, viewport).to_json_string()
}

///|
pub fn diff_rendered_paint_trees(
  baseline_html : String,
  current_html : String,
  viewport : @types.Size[Double],
) -> @paint_diff.PaintTreeDiff {
  let baseline = render_html_to_paint_tree(baseline_html, viewport)
  let current = render_html_to_paint_tree(current_html, viewport)
  @paint_diff.diff_trees(baseline, current)
}

///|
pub(all) struct CssMutation {
  selector : String
  property : String
  action : CssMutationAction
} derive(Eq, Debug)

///|
pub(all) enum CssMutationAction {
  Remove
  Override(String)
} derive(Eq, Debug)

///|
pub(all) struct RenderVariant {
  id : String
  mutations : Array[CssMutation]
} derive(Eq, Debug)

///|
pub(all) struct RenderVariantResult {
  id : String
  paint_tree : @paint_model.PaintNode
}

///|
pub impl Show for CssMutation with fn output(self, logger) {
  logger.write_string("{selector: ")
  logger.write_string("\"")
  logger.write_string(self.selector)
  logger.write_string("\"")
  logger.write_string(", property: ")
  logger.write_string("\"")
  logger.write_string(self.property)
  logger.write_string("\"")
  logger.write_string(", action: \{self.action}}")
}

///|
pub impl Show for CssMutationAction with fn output(self, logger) {
  match self {
    Remove => logger.write_string("Remove")
    Override(value) => {
      logger.write_string("Override(")
      logger.write_string("\"")
      logger.write_string(value)
      logger.write_string("\"")
      logger.write_string(")")
    }
  }
}

///|
pub impl Show for RenderVariant with fn output(self, logger) {
  logger.write_string("{id: ")
  logger.write_string("\"")
  logger.write_string(self.id)
  logger.write_string("\"")
  logger.write_string(", mutations: ")
  logger.write_object(to_repr(self.mutations))
  logger.write_string("}")
}

///|
pub impl Show for RenderVariantResult with fn output(self, logger) {
  logger.write_string("{id: ")
  logger.write_string("\"")
  logger.write_string(self.id)
  logger.write_string("\"")
  logger.write_string(", paint_tree: \{self.paint_tree}}")
}

///|
pub fn render_html_batch_variants(
  html : String,
  viewport : @types.Size[Double],
  variants : Array[RenderVariant],
) -> Array[RenderVariantResult] {
  let doc = @html.parse_document(html)
  let ctx = make_render_context(viewport)
  let results : Array[RenderVariantResult] = []
  for variant in variants {
    let override_css = mutations_to_css(variant.mutations)
    let external_css : Array[String] = if override_css.is_empty() {
      []
    } else {
      [override_css]
    }
    let (node, layout) = @renderer.render_to_node_and_layout_with_document(
      doc, ctx, external_css,
    )
    let paint_tree = paint_tree_from_node_layout(node, layout, viewport)
    results.push({ id: variant.id, paint_tree })
  }
  results
}

///|
fn mutations_to_css(mutations : Array[CssMutation]) -> String {
  if mutations.is_empty() {
    return ""
  }
  let by_selector : Map[String, Array[(String, String)]] = {}
  for mutation in mutations {
    let value = match mutation.action {
      CssMutationAction::Remove => "unset"
      CssMutationAction::Override(v) => v
    }
    match by_selector.get(mutation.selector) {
      Some(props) => props.push((mutation.property, value))
      None => by_selector.set(mutation.selector, [(mutation.property, value)])
    }
  }
  let buf = StringBuilder::new()
  by_selector.each(fn(selector, props) {
    buf.write_string(selector)
    buf.write_string(" { ")
    for item in props {
      buf.write_string(item.0)
      buf.write_string(": ")
      buf.write_string(item.1)
      buf.write_string(" !important; ")
    }
    buf.write_string("} ")
  })
  buf.to_string()
}

///|
/// A reusable render "snapshot" for VRT branching. `open` parses + cascades +
/// lays out + paints the base document once; each branch applies a CSS-mutation
/// delta. A branch can either re-layout fully (branch_full, for geometry-
/// affecting changes) or reuse the base layout (branch_reusing_layout, valid
/// when the delta is paint-only) — the latter skips the dominant layout cost.
pub(all) struct RenderSession {
  doc : @html.Document
  viewport : @types.Size[Double]
  ctx : @renderer.RenderContext
  base_node : @layout.Node
  base_layout : @layout_types.Layout
  base_paint : @paint_model.PaintNode
}

///|
fn render_session_external_css(mutations : Array[CssMutation]) -> Array[String] {
  let override_css = mutations_to_css(mutations)
  if override_css.is_empty() {
    []
  } else {
    [override_css]
  }
}

///|
/// Parse + cascade + layout + paint the base document once.
pub fn RenderSession::open(
  html : String,
  viewport : @types.Size[Double],
  external_css : Array[String],
) -> RenderSession {
  let doc = @html.parse_document(html)
  let ctx = make_render_context(viewport)
  let prepared = @renderer.prepare_render_document(doc, ctx, external_css)
  let node = @renderer.build_render_root_node(doc, ctx, prepared)
  let layout = @renderer.compute_layout_from_render_root(node, prepared, ctx)
  let paint = paint_tree_from_node_layout(node, layout, viewport)
  {
    doc,
    viewport,
    ctx,
    base_node: node,
    base_layout: layout,
    base_paint: paint,
  }
}

///|
/// The base (unmutated) paint tree captured at open().
pub fn RenderSession::base_paint_tree(
  self : RenderSession,
) -> @paint_model.PaintNode {
  self.base_paint
}

///|
/// Branch with a full re-layout (correct for any mutation, including ones that
/// change box geometry). Re-cascades + re-lays-out + paints from scratch,
/// reusing only the parsed document.
pub fn RenderSession::branch_full(
  self : RenderSession,
  mutations : Array[CssMutation],
) -> @paint_model.PaintNode {
  let external = render_session_external_css(mutations)
  let prepared = @renderer.prepare_render_document(self.doc, self.ctx, external)
  let node = @renderer.build_render_root_node(self.doc, self.ctx, prepared)
  let layout = @renderer.compute_layout_from_render_root(
    node,
    prepared,
    self.ctx,
  )
  paint_tree_from_node_layout(node, layout, self.viewport)
}

///|
/// Branch reusing the base layout: re-cascade the mutated document but paint it
/// against the base layout, skipping re-layout. Valid only when the mutation is
/// paint-only (it changes paint properties — color, background, opacity, … —
/// not box geometry); for such a delta the layout is identical, so the painted
/// result equals branch_full at a fraction of the cost.
pub fn RenderSession::branch_reusing_layout(
  self : RenderSession,
  mutations : Array[CssMutation],
) -> @paint_model.PaintNode {
  let external = render_session_external_css(mutations)
  let prepared = @renderer.prepare_render_document(self.doc, self.ctx, external)
  let node = @renderer.build_render_root_node(self.doc, self.ctx, prepared)
  paint_tree_from_node_layout(node, self.base_layout, self.viewport)
}

///|
/// Paint-tree diff of a full-relayout branch against the base.
pub fn RenderSession::branch_full_diff(
  self : RenderSession,
  mutations : Array[CssMutation],
) -> @paint_diff.PaintTreeDiff {
  @paint_diff.diff_trees(self.base_paint, self.branch_full(mutations))
}

///|
/// Paint-tree diff of a layout-reusing (paint-only) branch against the base.
pub fn RenderSession::branch_reusing_layout_diff(
  self : RenderSession,
  mutations : Array[CssMutation],
) -> @paint_diff.PaintTreeDiff {
  @paint_diff.diff_trees(self.base_paint, self.branch_reusing_layout(mutations))
}
