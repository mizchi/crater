///|
/// Lightweight JS export for WPT runner.
/// Avoids linking the full JS surface that currently hits compiler ICE.
pub fn renderHtmlToJsonForWpt(
  html : String,
  width : Int,
  height : Int,
) -> String {
  install_wpt_external_measurement_providers()
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  // Render the full document with viewport-skeleton culling disabled. The
  // skeleton optimization replaces below-the-fold content with lightweight
  // placeholder nodes once the node count or estimated Y exceeds a threshold —
  // valid for live viewport rendering, but the WPT runner compares the whole
  // layout tree against a browser that lays out the entire document, so
  // skeletonized nodes (collapsed to height 0) produce spurious mismatches on
  // large fixtures (e.g. css-overflow/overflow-alignment-* has 126 scroll cells
  // × a 9-box float grid, well over the 2000-node cutoff).
  let (_, layout) = @renderer.render_to_node_and_layout_full_document(html, ctx)
  @renderer.layout_to_json(layout)
}
