///|
// Public renderer entrypoints and shared render orchestration wrappers.

///|
/// Render HTML string to Layout
pub fn render(html : String, ctx : RenderContext) -> @layout_types.Layout {
  render_with_external_css(html, ctx, [])
}

///|
/// Render HTML string to Layout with external CSS
pub fn render_with_external_css(
  html : String,
  ctx : RenderContext,
  external_css : Array[String],
) -> @layout_types.Layout {
  let t0 = perf_clock_us()
  let doc = @html.parse_document(html)
  let t1 = perf_clock_us()
  maybe_log_perf("[perf] html_parse=" + ((t1 - t0) / 1000L).to_string() + "ms")
  render_document_with_external_css(doc, ctx, external_css)
}

///|
/// Render a parsed HTML Document to Layout with external CSS
/// This is useful when you need to pre-process the document (e.g., add synthetic IDs)
pub fn render_document_with_external_css(
  doc : @html.Document,
  ctx : RenderContext,
  external_css : Array[String],
) -> @layout_types.Layout {
  let prepared = prepare_render_document(doc, ctx, external_css)
  let root = build_render_root_node(doc, ctx, prepared)
  compute_layout_from_render_root(root, prepared, ctx)
}

///|
/// Render a parsed HTML Document to Layout with a prepared external CSS handle.
pub fn render_document_with_prepared_external_css(
  doc : @html.Document,
  ctx : RenderContext,
  external_css : PreparedExternalCss,
) -> @layout_types.Layout {
  let prepared = prepare_render_document_with_prepared_external_css(
    doc, ctx, external_css,
  )
  let root = build_render_root_node(doc, ctx, prepared)
  compute_layout_from_render_root(root, prepared, ctx)
}

///|
/// Render HTML to Node tree (for testing/debugging)
pub fn render_to_node(html : String, ctx : RenderContext) -> @node.Node {
  render_to_node_with_external_css(html, ctx, [])
}

///|
/// Render HTML to Node tree with external CSS
pub fn render_to_node_with_external_css(
  html : String,
  ctx : RenderContext,
  external_css : Array[String],
) -> @node.Node {
  let doc = @html.parse_document(html)
  render_to_node_with_document(doc, ctx, external_css)
}

///|
/// Render HTML to Node tree and Layout in a shared pass.
pub fn render_to_node_and_layout(
  html : String,
  ctx : RenderContext,
) -> (@node.Node, @layout_types.Layout) {
  render_to_node_and_layout_with_external_css(html, ctx, [])
}

///|
/// Render the whole document without viewport skeleton culling.
pub fn render_to_node_and_layout_full_document(
  html : String,
  ctx : RenderContext,
) -> (@node.Node, @layout_types.Layout) {
  let previous = viewport_skeleton_enabled.val
  viewport_skeleton_enabled.val = false
  let result = render_to_node_and_layout(html, ctx)
  viewport_skeleton_enabled.val = previous
  result
}

///|
/// Render HTML to Node tree and Layout with external CSS in a shared pass.
pub fn render_to_node_and_layout_with_external_css(
  html : String,
  ctx : RenderContext,
  external_css : Array[String],
) -> (@node.Node, @layout_types.Layout) {
  let t0 = perf_clock_us()
  let doc = @html.parse_document(html)
  let t1 = perf_clock_us()
  maybe_log_perf("[perf] html_parse=" + ((t1 - t0) / 1000L).to_string() + "ms")
  render_to_node_and_layout_with_document(doc, ctx, external_css)
}

///|
/// Render a parsed HTML Document to Node tree with external CSS
/// This is useful when you need to use a pre-parsed document (e.g., from streaming parser)
pub fn render_to_node_with_document(
  doc : @html.Document,
  ctx : RenderContext,
  external_css : Array[String],
) -> @node.Node {
  let prepared = prepare_render_document(doc, ctx, external_css)
  build_render_root_node(doc, ctx, prepared)
}

///|
/// Render a parsed HTML Document to Node tree with a prepared external CSS handle.
pub fn render_to_node_with_prepared_external_css(
  doc : @html.Document,
  ctx : RenderContext,
  external_css : PreparedExternalCss,
) -> @node.Node {
  let prepared = prepare_render_document_with_prepared_external_css(
    doc, ctx, external_css,
  )
  build_render_root_node(doc, ctx, prepared)
}

///|
/// Render a parsed HTML Document to Node tree and Layout with external CSS
/// while sharing HTML/CSS preparation and node construction.
pub fn render_to_node_and_layout_with_document(
  doc : @html.Document,
  ctx : RenderContext,
  external_css : Array[String],
) -> (@node.Node, @layout_types.Layout) {
  let prepared = prepare_render_document(doc, ctx, external_css)
  let root = build_render_root_node(doc, ctx, prepared)
  let layout = compute_layout_from_render_root(root, prepared, ctx)
  (root, layout)
}

///|
/// Render a parsed HTML Document to Node tree and Layout with a prepared external CSS handle.
pub fn render_to_node_and_layout_with_prepared_external_css(
  doc : @html.Document,
  ctx : RenderContext,
  external_css : PreparedExternalCss,
) -> (@node.Node, @layout_types.Layout) {
  let prepared = prepare_render_document_with_prepared_external_css(
    doc, ctx, external_css,
  )
  let root = build_render_root_node(doc, ctx, prepared)
  let layout = compute_layout_from_render_root(root, prepared, ctx)
  (root, layout)
}
