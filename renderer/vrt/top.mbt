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
  match
    @paint_render.from_node_and_layout_with_viewport(
      node,
      layout,
      0.0,
      viewport.height,
      0.0,
    ) {
    Some(paint_tree) => paint_tree
    None => @paint_render.from_node_and_layout(node, layout)
  }
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
pub impl Show for CssMutation with output(self, logger) {
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
pub impl Show for CssMutationAction with output(self, logger) {
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
pub impl Show for RenderVariant with output(self, logger) {
  logger.write_string("{id: ")
  logger.write_string("\"")
  logger.write_string(self.id)
  logger.write_string("\"")
  logger.write_string(", mutations: \{self.mutations}}")
}

///|
pub impl Show for RenderVariantResult with output(self, logger) {
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
    let paint_tree = match
      @paint_render.from_node_and_layout_with_viewport(
        node,
        layout,
        0.0,
        viewport.height,
        0.0,
      ) {
      Some(pt) => pt
      None => @paint_render.from_node_and_layout(node, layout)
    }
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
