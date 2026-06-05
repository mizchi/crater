///|
pub using @vrt {
  type CssMutation,
  type PreparedVrtPage,
  type CssMutationAction,
  type RenderVariant,
  type RenderVariantResult,
}

///|
pub using @renderer_core {type PreparedExternalCss}

///|
pub fn prepare_external_css(
  external_css : Array[String],
) -> PreparedExternalCss {
  @renderer_core.prepare_external_css(external_css)
}

///|
pub fn prepare_vrt_page(
  html : String,
  viewport : @types.Size[Double],
  external_css : Array[String],
) -> PreparedVrtPage {
  @vrt.prepare_vrt_page(html, viewport, external_css)
}

///|
pub fn prepare_vrt_page_with_prepared_external_css(
  html : String,
  viewport : @types.Size[Double],
  external_css : PreparedExternalCss,
) -> PreparedVrtPage {
  @vrt.prepare_vrt_page_with_prepared_external_css(html, viewport, external_css)
}

///|
pub fn render_prepared_vrt_page_to_paint_tree(
  page : PreparedVrtPage,
) -> @paint_model.PaintNode {
  @vrt.render_prepared_vrt_page_to_paint_tree(page)
}

///|
pub fn render_prepared_vrt_page_to_paint_tree_json(
  page : PreparedVrtPage,
) -> String {
  @vrt.render_prepared_vrt_page_to_paint_tree_json(page)
}

///|
pub fn render_html_to_paint_tree(
  html : String,
  viewport : @types.Size[Double],
) -> @paint_model.PaintNode {
  @vrt.render_html_to_paint_tree(html, viewport)
}

///|
pub fn render_html_to_paint_tree_with_external_css(
  html : String,
  viewport : @types.Size[Double],
  external_css : Array[String],
) -> @paint_model.PaintNode {
  @vrt.render_html_to_paint_tree_with_external_css(html, viewport, external_css)
}

///|
pub fn render_html_to_paint_tree_with_prepared_external_css(
  html : String,
  viewport : @types.Size[Double],
  external_css : PreparedExternalCss,
) -> @paint_model.PaintNode {
  @vrt.render_html_to_paint_tree_with_prepared_external_css(
    html, viewport, external_css,
  )
}

///|
pub fn render_html_to_paint_tree_json(
  html : String,
  viewport : @types.Size[Double],
) -> String {
  @vrt.render_html_to_paint_tree_json(html, viewport)
}

///|
pub fn diff_rendered_paint_trees(
  baseline_html : String,
  current_html : String,
  viewport : @types.Size[Double],
) -> @paint_diff.PaintTreeDiff {
  @vrt.diff_rendered_paint_trees(baseline_html, current_html, viewport)
}

///|
pub fn render_html_batch_variants(
  html : String,
  viewport : @types.Size[Double],
  variants : Array[RenderVariant],
) -> Array[RenderVariantResult] {
  @vrt.render_html_batch_variants(html, viewport, variants)
}

///|
pub using @gfx_vrt {type RenderedImage}

///|
/// Render an HTML document to an RGBA image at `viewport` via the gfx
/// software backend (image VRT). Companion to `render_html_to_paint_tree`,
/// which compares geometry; this compares pixels.
pub fn render_html_to_image(
  html : String,
  viewport : @types.Size[Double],
) -> RenderedImage {
  @gfx_vrt.render_html_to_image(html, viewport)
}

///|
/// Render a paint tree to an RGBA image of the given size via the gfx
/// software backend.
pub fn render_paint_tree_to_image(
  root : @paint_model.PaintNode,
  width : Int,
  height : Int,
) -> RenderedImage {
  @gfx_vrt.render_paint_tree_to_image(root, width, height)
}
