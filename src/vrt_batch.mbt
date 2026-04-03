///|
/// Batch multi-variant rendering for VRT benchmark acceleration.
/// Renders multiple CSS mutation variants from the same base HTML,
/// parsing HTML only once.

///|
pub(all) struct CssMutation {
  selector : String
  property : String
  action : CssMutationAction
} derive(Eq, Show)

///|
pub(all) enum CssMutationAction {
  Remove
  Override(String)
} derive(Eq, Show)

///|
pub(all) struct RenderVariant {
  id : String
  mutations : Array[CssMutation]
} derive(Eq, Show)

///|
pub(all) struct RenderVariantResult {
  id : String
  paint_tree : @paint.PaintNode
} derive(Show)

///|
/// Render multiple CSS mutation variants from the same base HTML.
/// HTML is parsed once and reused across all variants.
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
      @paint.from_node_and_layout_with_viewport(
        node,
        layout,
        0.0,
        viewport.height,
        0.0,
      ) {
      Some(pt) => pt
      None => @paint.from_node_and_layout(node, layout)
    }
    results.push({ id: variant.id, paint_tree })
  }
  results
}

///|
/// Convert a list of CSS mutations into a CSS override string.
/// Remove mutations use a property value that effectively disables the property.
/// Override mutations set the property to the specified value.
fn mutations_to_css(mutations : Array[CssMutation]) -> String {
  if mutations.is_empty() {
    return ""
  }
  // Group mutations by selector
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
