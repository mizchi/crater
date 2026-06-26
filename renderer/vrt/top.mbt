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
  // External side effects observed while rendering the base — text measurements
  // and image intrinsic sizes. Stored so branches replay them (deterministic,
  // no font/image engine) and so the whole session can be serialized and
  // reproduced on a machine without those engines.
  measurements : Array[@renderer.RecordedMetric]
  images : Array[@renderer.RecordedImage]
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
/// Start recording all external render side effects (text + image).
fn session_start_recording() -> Unit {
  @renderer.start_text_metrics_recording()
  @renderer.start_image_intrinsic_recording()
}

///|
/// Replay all external render side effects (a miss falls back to live).
fn session_install_replay(
  measurements : Array[@renderer.RecordedMetric],
  images : Array[@renderer.RecordedImage],
) -> Unit {
  @renderer.install_text_metrics_replay(measurements)
  @renderer.install_image_intrinsic_replay(images)
}

///|
/// Disable record/replay for all external render side effects.
fn session_clear_record_replay() -> Unit {
  @renderer.clear_text_metrics_record_replay()
  @renderer.clear_image_intrinsic_record_replay()
}

///|
/// Parse + cascade + layout + paint the base document once, recording the
/// external text-measurement side effect so branches (and a restored session)
/// reproduce it without a font engine.
pub fn RenderSession::open(
  html : String,
  viewport : @types.Size[Double],
  external_css : Array[String],
) -> RenderSession {
  let doc = @html.parse_document(html)
  let ctx = make_render_context(viewport)
  session_start_recording()
  let prepared = @renderer.prepare_render_document(doc, ctx, external_css)
  let node = @renderer.build_render_root_node(doc, ctx, prepared)
  let layout = @renderer.compute_layout_from_render_root(node, prepared, ctx)
  let paint = paint_tree_from_node_layout(node, layout, viewport)
  let measurements = @renderer.take_text_metrics_recording()
  let images = @renderer.take_image_intrinsic_recording()
  {
    doc,
    viewport,
    ctx,
    base_node: node,
    base_layout: layout,
    base_paint: paint,
    measurements,
    images,
  }
}

///|
/// Restore a session from a previously recorded measurement set (e.g. one
/// serialized to disk). The base is rendered by replaying `measurements`, so no
/// font engine is required; branches then reuse the same recording. This is the
/// portable side of the snapshot: capture once with open(), persist
/// session.measurements, reproduce anywhere.
pub fn RenderSession::open_with_recording(
  html : String,
  viewport : @types.Size[Double],
  external_css : Array[String],
  measurements : Array[@renderer.RecordedMetric],
  images : Array[@renderer.RecordedImage],
) -> RenderSession {
  let doc = @html.parse_document(html)
  let ctx = make_render_context(viewport)
  session_install_replay(measurements, images)
  let prepared = @renderer.prepare_render_document(doc, ctx, external_css)
  let node = @renderer.build_render_root_node(doc, ctx, prepared)
  let layout = @renderer.compute_layout_from_render_root(node, prepared, ctx)
  let paint = paint_tree_from_node_layout(node, layout, viewport)
  session_clear_record_replay()
  {
    doc,
    viewport,
    ctx,
    base_node: node,
    base_layout: layout,
    base_paint: paint,
    measurements,
    images,
  }
}

///|
/// The recorded text measurements; serialize with
/// @renderer.serialize_text_metrics_recording.
pub fn RenderSession::recorded_measurements(
  self : RenderSession,
) -> Array[@renderer.RecordedMetric] {
  self.measurements
}

///|
/// The recorded image intrinsic sizes; serialize with
/// @renderer.serialize_image_intrinsic_recording.
pub fn RenderSession::recorded_images(
  self : RenderSession,
) -> Array[@renderer.RecordedImage] {
  self.images
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
  // Replay the recorded side effects (a delta that introduces new text/sizes
  // or images falls back to the live resolver for those misses).
  session_install_replay(self.measurements, self.images)
  let prepared = @renderer.prepare_render_document(self.doc, self.ctx, external)
  let node = @renderer.build_render_root_node(self.doc, self.ctx, prepared)
  let layout = @renderer.compute_layout_from_render_root(
    node,
    prepared,
    self.ctx,
  )
  let paint = paint_tree_from_node_layout(node, layout, self.viewport)
  session_clear_record_replay()
  paint
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
  // A paint-only delta keeps the same text/sizes/images, so the recording is
  // complete and no live resolution happens.
  session_install_replay(self.measurements, self.images)
  let prepared = @renderer.prepare_render_document(self.doc, self.ctx, external)
  let node = @renderer.build_render_root_node(self.doc, self.ctx, prepared)
  let paint = paint_tree_from_node_layout(node, self.base_layout, self.viewport)
  session_clear_record_replay()
  paint
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

///|
/// Whether this mutation only affects paint (color/background/opacity/…), not
/// box geometry — i.e. whether a branch carrying only such mutations can reuse
/// the base layout.
pub fn CssMutation::is_paint_only(self : CssMutation) -> Bool {
  not(@dom.is_layout_property(self.property.to_lower()))
}

///|
/// Branch with automatic strategy: if every mutation is paint-only the base
/// layout is reused (fast path); otherwise a full re-layout is performed. This
/// is the convenient default — correct for any delta, fast for recolor/theme
/// variants (the common VRT case).
pub fn RenderSession::branch(
  self : RenderSession,
  mutations : Array[CssMutation],
) -> @paint_model.PaintNode {
  let all_paint_only = mutations.iter().all(fn(m) { m.is_paint_only() })
  if all_paint_only {
    self.branch_reusing_layout(mutations)
  } else {
    self.branch_full(mutations)
  }
}

///|
/// Paint-tree diff of an auto-strategy branch against the base.
pub fn RenderSession::branch_diff(
  self : RenderSession,
  mutations : Array[CssMutation],
) -> @paint_diff.PaintTreeDiff {
  @paint_diff.diff_trees(self.base_paint, self.branch(mutations))
}

///|
/// Absolute geometry of one laid-out box, in the form page JS needs for
/// `getBoundingClientRect()` / `offsetWidth` / `offsetHeight`. `index` is the
/// pre-order (document-order) position in the layout tree — a stable key a JS
/// DOM built in the same order can match. The crater layout tree already stores
/// absolute viewport coordinates, so x/y are left/top directly.
pub(all) struct LayoutBox {
  id : String
  index : Int
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Show)

///|
fn collect_layout_boxes_into(
  layout : @layout_types.Layout,
  next_index : Ref[Int],
  out : Array[LayoutBox],
) -> Unit {
  let index = next_index.val
  next_index.val = index + 1
  out.push({
    id: layout.id,
    index,
    x: layout.x,
    y: layout.y,
    width: layout.width,
    height: layout.height,
  })
  for child in layout.children {
    collect_layout_boxes_into(child, next_index, out)
  }
}

///|
/// Flatten a layout tree into per-box absolute geometry in document order. This
/// is the data layer that connects crater's layout engine to page JS box
/// measurement (the bridge would inject these and have getBoundingClientRect /
/// offsetWidth / offsetHeight read them, keyed by `index`, instead of the
/// inline-style heuristic the runtime uses today).
pub fn collect_layout_boxes(layout : @layout_types.Layout) -> Array[LayoutBox] {
  let out : Array[LayoutBox] = []
  collect_layout_boxes_into(layout, { val: 0 }, out)
  out
}

///|
/// The first box whose layout id contains `id_fragment` (e.g. an element id like
/// "main#content" or "#sidebar"), for getElementById-style measurement.
pub fn layout_box_by_id(
  layout : @layout_types.Layout,
  id_fragment : String,
) -> LayoutBox? {
  let boxes = collect_layout_boxes(layout)
  for b in boxes {
    if b.id.contains(id_fragment) {
      return Some(b)
    }
  }
  None
}

///|
/// Per-box geometry of the session's base render — the geometry page JS would
/// observe via getBoundingClientRect on the initial layout.
pub fn RenderSession::element_boxes(self : RenderSession) -> Array[LayoutBox] {
  collect_layout_boxes(self.base_layout)
}

///|
/// CSS string for a computed `display`, in the form `getComputedStyle` returns.
fn display_to_css(d : @types.Display) -> String {
  match d {
    @types.Display::Block => "block"
    @types.Display::Inline => "inline"
    @types.Display::InlineBlock => "inline-block"
    @types.Display::Flex => "flex"
    @types.Display::InlineFlex => "inline-flex"
    @types.Display::Grid => "grid"
    @types.Display::InlineGrid => "inline-grid"
    @types.Display::Table => "table"
    @types.Display::InlineTable => "inline-table"
    @types.Display::TableRow => "table-row"
    @types.Display::TableCell => "table-cell"
    @types.Display::TableCaption => "table-caption"
    @types.Display::TableRowGroup => "table-row-group"
    @types.Display::TableHeaderGroup => "table-header-group"
    @types.Display::TableFooterGroup => "table-footer-group"
    @types.Display::TableColumn => "table-column"
    @types.Display::TableColumnGroup => "table-column-group"
    @types.Display::None => "none"
    @types.Display::Contents => "contents"
    @types.Display::FlowRoot => "flow-root"
  }
}

///|
/// CSS string for a computed `position`.
fn position_to_css(p : @types.Position) -> String {
  match p {
    @types.Position::Static => "static"
    @types.Position::Relative => "relative"
    @types.Position::Absolute => "absolute"
    @types.Position::Fixed => "fixed"
  }
}

///|
/// CSS string for a computed `visibility`.
fn visibility_to_css(v : @style.Visibility) -> String {
  match v {
    @style.Visibility::Visible => "visible"
    @style.Visibility::Hidden => "hidden"
    @style.Visibility::Collapse => "collapse"
  }
}

///|
/// CSS string for a computed `z-index` (`auto` or an integer).
fn z_index_to_css(z : @style.ZIndex) -> String {
  match z {
    @style.ZIndex::Auto => "auto"
    @style.ZIndex::Value(n) => n.to_string()
  }
}

///|
/// Format a Double as a CSS pixel length, dropping a trailing `.0` so an
/// integral 20.0 serializes as `20px` (matching getComputedStyle), not `20.0px`.
fn css_px(v : Double) -> String {
  let i = v.to_int()
  if i.to_double() == v {
    "\{i}px"
  } else {
    "\{v}px"
  }
}

///|
/// Format a unitless Double (e.g. opacity), dropping a trailing `.0`.
fn css_number(v : Double) -> String {
  let i = v.to_int()
  if i.to_double() == v {
    "\{i}"
  } else {
    "\{v}"
  }
}

///|
/// Resolved computed style of one element, in the form page JS `getComputedStyle`
/// reads. `index` is the pre-order (document-order) position in the render node
/// tree — the same key `collect_layout_boxes` assigns to the parallel layout
/// tree, so a JS DOM built in the same order can join geometry and computed
/// style by index. Values are serialized as CSS strings (display `"flex"`, color
/// `"rgb(255, 0, 0)"`, font-size `"20px"`). This is the node-tree analogue of
/// `collect_layout_boxes`: the data layer a getComputedStyle bridge would inject.
pub(all) struct ComputedStyleEntry {
  id : String
  index : Int
  display : String
  position : String
  visibility : String
  font_size : String
  font_family : String
  opacity : String
  z_index : String
  color : String
  background_color : String
} derive(Eq, Show)

///|
fn collect_computed_styles_into(
  node : @layout.Node,
  next_index : Ref[Int],
  out : Array[ComputedStyleEntry],
) -> Unit {
  let index = next_index.val
  next_index.val = index + 1
  let s = node.style
  out.push({
    id: node.id,
    index,
    display: display_to_css(s.display),
    position: position_to_css(s.position),
    visibility: visibility_to_css(s.visibility),
    font_size: css_px(s.font_size),
    font_family: s.font_family,
    opacity: css_number(s.opacity),
    z_index: z_index_to_css(s.z_index),
    color: s.color.to_rgba_string(),
    background_color: s.background_color.to_rgba_string(),
  })
  for child in node.children {
    collect_computed_styles_into(child, next_index, out)
  }
}

///|
/// Flatten a render node tree into per-element computed style in document order.
/// This is the parallel of `collect_layout_boxes` for the page-JS
/// `getComputedStyle` bridge: the node tree carries the resolved `@style.Style`
/// per element, and the indexes line up with the layout-box indexes so the two
/// can be joined element-for-element.
pub fn collect_computed_styles(
  node : @layout.Node,
) -> Array[ComputedStyleEntry] {
  let out : Array[ComputedStyleEntry] = []
  collect_computed_styles_into(node, { val: 0 }, out)
  out
}

///|
/// The first element whose node id contains `id_fragment`, for
/// getComputedStyle-by-element lookup.
pub fn computed_style_by_id(
  node : @layout.Node,
  id_fragment : String,
) -> ComputedStyleEntry? {
  let entries = collect_computed_styles(node)
  for e in entries {
    if e.id.contains(id_fragment) {
      return Some(e)
    }
  }
  None
}

///|
/// Per-element computed style of the session's base render — what page JS would
/// observe via getComputedStyle on the initial render.
pub fn RenderSession::element_computed_styles(
  self : RenderSession,
) -> Array[ComputedStyleEntry] {
  collect_computed_styles(self.base_node)
}
