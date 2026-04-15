///|
pub using @vrt {
  type CssMutation,
  type CssMutationAction,
  type RenderVariant,
  type RenderVariantResult,
}

///|
pub fn render_html_batch_variants(
  html : String,
  viewport : @types.Size[Double],
  variants : Array[RenderVariant],
) -> Array[RenderVariantResult] {
  @vrt.render_html_batch_variants(html, viewport, variants)
}
