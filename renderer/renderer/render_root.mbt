///|
// Render root selection and root layout adjustment helpers.

///|
/// Find the deepest body element in HTML tree
/// If there are nested body elements (invalid HTML), find the innermost one
fn find_body(elem : @html.Element) -> @html.Element? {
  if elem.tag == "body" {
    // Check if there's a nested body inside this one
    match find_body_in_children(elem) {
      Some(inner_body) => Some(inner_body)
      None => Some(elem)
    }
  } else {
    find_body_in_children(elem)
  }
}

///|
/// Helper to find body in children
fn find_body_in_children(elem : @html.Element) -> @html.Element? {
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) =>
        match find_body(child_elem) {
          Some(body) => return Some(body)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
/// Resolve zoom on the document root (html element).
/// We render from body in most paths, so root zoom needs to be propagated.
fn resolve_document_root_zoom(
  doc_root : @html.Element,
  ctx : RenderContext,
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  css_vars : Map[String, String],
) -> Double {
  if doc_root.tag.to_lower() != "html" {
    return 1.0
  }
  let root_selector = if indexed_stylesheets.length() == 0 {
    html_to_selector_element_minimal(doc_root, None)
  } else {
    html_to_selector_element(doc_root, None)
  }
  let root_style = compute_element_style_indexed(
    root_selector,
    doc_root.style,
    indexed_stylesheets,
    true,
    ctx,
    None,
    css_vars,
  )
  root_style.zoom
}

///|
/// We render from <body> in most paths. When <html> establishes multicol
/// formatting, mirror it onto body root unless body already establishes one.
fn propagate_document_root_multicol_to_body(
  body_style : @style.Style,
  doc_root_style : @style.Style,
) -> @style.Style {
  if body_style.has_multicol() || !doc_root_style.has_multicol() {
    return body_style
  }
  {
    ..body_style,
    column_count: doc_root_style.column_count,
    column_width: doc_root_style.column_width,
    column_gap: doc_root_style.column_gap,
    column_gap_is_normal: doc_root_style.column_gap_is_normal,
    column_fill: doc_root_style.column_fill,
  }
}

///|
fn should_layout_document_root(
  doc_root : @html.Element,
  doc_root_style : @style.Style,
) -> Bool {
  if doc_root.tag.to_lower() != "html" {
    return false
  }
  doc_root_style.position == @types.Absolute ||
  doc_root_style.position == @types.Fixed
}

///|
fn select_render_root(
  doc_root : @html.Element,
  doc_root_style : @style.Style,
) -> @html.Element {
  if should_layout_document_root(doc_root, doc_root_style) {
    return doc_root
  }
  match find_body(doc_root) {
    Some(body) => body
    None => doc_root
  }
}

///|
fn resolve_root_available_width(
  viewport_width : Double,
  _root_margin : @types.Rect[Double],
  doc_root_style : @style.Style?,
) -> Double {
  // The available width is the root's containing block (the initial containing
  // block = the viewport). The root element's own margin is subtracted once by
  // its block layout, so it must NOT be subtracted here as well, or a body with
  // the UA default 8px margin ends up 2x16px narrower than the viewport.
  let base = viewport_width
  let base = if base > 0.0 { base } else { 0.0 }
  match doc_root_style {
    None => base
    Some(style) => {
      let mut doc_width = match style.width {
        @types.Length(v) => v
        @types.Percent(p) => viewport_width * p
        @types.Calc(px, pct) => viewport_width * pct + px
        @types.MathFn(__mop, __mterms) =>
          @types.apply_math_op(
            __mop,
            __mterms.map(fn(__t) { viewport_width * __t.1 + __t.0 }),
          )
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => viewport_width
      }
      let min_width = match style.min_width {
        @types.Length(v) => v
        @types.Percent(p) => viewport_width * p
        @types.Calc(px, pct) => viewport_width * pct + px
        @types.MathFn(__mop, __mterms) =>
          @types.apply_math_op(
            __mop,
            __mterms.map(fn(__t) { viewport_width * __t.1 + __t.0 }),
          )
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 0.0
      }
      let max_width = match style.max_width {
        @types.Length(v) => v
        @types.Percent(p) => viewport_width * p
        @types.Calc(px, pct) => viewport_width * pct + px
        @types.MathFn(__mop, __mterms) =>
          @types.apply_math_op(
            __mop,
            __mterms.map(fn(__t) { viewport_width * __t.1 + __t.0 }),
          )
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 1.0e10
      }
      if doc_width > max_width {
        doc_width = max_width
      }
      if doc_width < min_width {
        doc_width = min_width
      }
      // Margin is subtracted by the root's block layout (see note above), not
      // here.
      let constrained = if doc_width > 0.0 { doc_width } else { 0.0 }
      if constrained < base {
        constrained
      } else {
        base
      }
    }
  }
}

///|
fn node_with_style(node : @node.Node, style : @style.Style) -> @node.Node {
  @node.Node::with_uid_and_measure(
    node.id,
    node.uid,
    style,
    node.children,
    node.measure,
    node.text,
  )
}

///|
/// Clamp body height only when author explicitly requests viewport-relative
/// percentage sizing.
fn should_clamp_body_to_viewport(root : @node.Node) -> Bool {
  if root.id != "body" {
    return false
  }
  let has_viewport_height_request = match root.style.height {
    @types.Percent(p) => p >= 1.0
    _ =>
      match root.style.min_height {
        @types.Percent(p) => p >= 1.0
        _ => false
      }
  }
  has_viewport_height_request
}

///|
fn adjust_root_height_for_viewport(
  layout : @layout_types.Layout,
  root : @node.Node,
  render_root_tag : String,
  viewport_height : Double,
) -> @layout_types.Layout {
  let content_extent = calculate_content_extent(layout)
  if should_clamp_body_to_viewport(root) {
    let min_viewport_height = if layout.height < viewport_height {
      viewport_height
    } else {
      layout.height
    }
    let final_height = if content_extent > min_viewport_height {
      content_extent
    } else {
      min_viewport_height
    }
    return { ..layout, height: final_height }
  }
  let keeps_empty_viewport_height = (
      render_root_tag == "body" || render_root_tag == "html"
    ) &&
    root.style.display != @types.Display::Contents &&
    root.style.position != @types.Absolute &&
    root.style.position != @types.Fixed &&
    layout.height <= 0.0 &&
    content_extent <= 0.0
  if keeps_empty_viewport_height {
    return { ..layout, height: viewport_height }
  }
  layout
}

///|
fn stretch_single_frameset_child_to_root(
  layout : @layout_types.Layout,
) -> @layout_types.Layout {
  if layout.children.length() != 1 {
    return layout
  }
  let child = layout.children[0]
  let is_frameset = child.id == "frameset" ||
    child.id.has_prefix("frameset#") ||
    child.id.has_prefix("frameset.")
  if !is_frameset || child.height > 0.0 {
    return layout
  }
  let adjusted_children : Array[@layout_types.Layout] = []
  adjusted_children.push({
    ..child,
    width: if child.width > 0.0 {
      child.width
    } else {
      layout.width
    },
    height: layout.height,
  })
  { ..layout, children: adjusted_children }
}

///|
/// Create a recursive zero-sized layout for nodes that don't generate a box
/// (e.g. display:none on root/body).
fn create_zero_layout_from_node(node : @node.Node) -> @layout_types.Layout {
  let children : Array[@layout_types.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    children.push(create_zero_layout_from_node(node.children[i]))
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    margin: @types.Rect::zero(),
    padding: @types.Rect::zero(),
    border: @types.Rect::zero(),
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children,
    text: node.text,
  }
}

///|
let active_before_index : Ref[PseudoRuleIndex] = {
  val: { rules: [], by_id: {}, by_class: {}, by_tag: {}, universal: [] },
}

///|
let active_after_index : Ref[PseudoRuleIndex] = {
  val: { rules: [], by_id: {}, by_class: {}, by_tag: {}, universal: [] },
}

///|
pub fn build_render_root_node(
  doc : @html.Document,
  ctx : RenderContext,
  prepared : PreparedRenderDocument,
) -> @node.Node {
  active_before_index.val = prepared.before_index
  active_after_index.val = prepared.after_index
  current_cellpadding.val = -1.0 // Reset cellpadding for new render
  // Viewport culling: skip expensive processing for below-fold elements
  viewport_estimated_y.val = 0.0
  // Keep several screens of full cascade, then switch long pages to skeleton
  // nodes. Real-world VRT captures only the viewport, and large docs pages can
  // otherwise spend minutes styling content far below the fold.
  let conservative_cutoff = ctx.viewport_height * 4.0
  viewport_cutoff.val = if conservative_cutoff > 4096.0 {
    conservative_cutoff
  } else {
    4096.0
  }
  viewport_skeleton_count.val = 0
  viewport_full_node_count.val = 0
  let root = if prepared.body_uses_document_root_style {
    let body_selector = if prepared.indexed_stylesheets.length() == 0 {
      html_to_selector_element_minimal(
        prepared.render_root,
        Some(prepared.doc_root_selector),
      )
    } else {
      html_to_selector_element(
        prepared.render_root,
        Some(prepared.doc_root_selector),
      )
    }
    element_to_node_with_styles_internal(
      prepared.render_root,
      body_selector,
      ctx,
      prepared.stylesheets,
      prepared.indexed_stylesheets,
      Some(prepared.doc_root_style),
      prepared.css_vars,
      {},
      "root",
    )
  } else {
    element_to_node_with_styles(
      prepared.render_root,
      None,
      ctx,
      prepared.stylesheets,
      prepared.indexed_stylesheets,
      prepared.css_vars,
      {},
      "root",
    )
  }
  let root = if prepared.body_uses_document_root_style {
    node_with_style(
      root,
      propagate_document_root_multicol_to_body(
        root.style,
        prepared.doc_root_style,
      ),
    )
  } else {
    root
  }
  if prepared.render_root_tag == "body" {
    let root_zoom = resolve_document_root_zoom(
      doc.root,
      ctx,
      prepared.indexed_stylesheets,
      prepared.css_vars,
    )
    if root_zoom != 1.0 {
      root.style.zoom = root.style.zoom * root_zoom
    }
  }
  maybe_log_perf(
    "[perf] viewport_culling: estimated_y=" +
    viewport_estimated_y.val.to_int().to_string() +
    " cutoff=" +
    viewport_cutoff.val.to_int().to_string() +
    " skeleton=" +
    viewport_skeleton_count.val.to_string() +
    " full_nodes=" +
    viewport_full_node_count.val.to_string(),
  )
  root
}

///|
pub fn compute_layout_from_render_root(
  root : @node.Node,
  prepared : PreparedRenderDocument,
  ctx : RenderContext,
) -> @layout_types.Layout {
  if prepared.doc_root_style.display == @types.Display::None ||
    root.style.display == @types.Display::None {
    return create_zero_layout_from_node(root)
  }

  let root_margin = @types.resolve_rect(root.style.margin, ctx.viewport_width)
  let available_width = resolve_root_available_width(
    ctx.viewport_width,
    root_margin,
    if prepared.body_uses_document_root_style {
      Some(prepared.doc_root_style)
    } else {
      None
    },
  )
  let root_available_height : Double? = if prepared.render_root_tag == "body" {
    match root.style.height {
      @types.Length(_) | @types.Percent(_) => Some(ctx.viewport_height)
      _ =>
        if root.style.writing_mode.is_vertical() {
          Some(ctx.viewport_height)
        } else {
          None
        }
    }
  } else if prepared.render_root_tag == "html" &&
    root.style.position != @types.Absolute &&
    root.style.position != @types.Fixed {
    Some(ctx.viewport_height)
  } else {
    match root.style.height {
      @types.Length(_) | @types.Percent(_) => Some(ctx.viewport_height)
      _ => None
    }
  }
  let layout_ctx : @layout_types.LayoutContext = {
    available_width,
    available_height: root_available_height,
    sizing_mode: @layout_types.SizingMode::Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }

  @node.setup()

  let layout = @node.compute_layout_in_context(root, layout_ctx)
  let scaled_layout = apply_zoom_and_scale(
    layout,
    root,
    1.0,
    1.0,
    1.0,
    0.0,
    0.0,
    false,
    0.0,
    0.0,
    ctx.viewport_width,
    ctx.viewport_height,
  )
  let scaled_layout = adjust_root_height_for_viewport(
    scaled_layout,
    root,
    prepared.render_root_tag,
    ctx.viewport_height,
  )
  let scaled_layout = stretch_single_frameset_child_to_root(scaled_layout)

  let margin_left_is_auto = match root.style.margin.left {
    @types.Dimension::Auto => true
    _ => false
  }
  let margin_right_is_auto = match root.style.margin.right {
    @types.Dimension::Auto => true
    _ => false
  }
  let x_offset = if margin_left_is_auto && margin_right_is_auto {
    (ctx.viewport_width - scaled_layout.width) / 2.0
  } else if margin_left_is_auto {
    ctx.viewport_width - scaled_layout.width - root_margin.right
  } else {
    root_margin.left
  }
  let y_offset = if prepared.suppress_quirks_body_ua_top_margin {
    root_margin.top
  } else {
    root_margin.top + scaled_layout.y
  }
  {
    id: scaled_layout.id,
    x: x_offset,
    y: y_offset,
    width: scaled_layout.width,
    height: scaled_layout.height,
    margin: scaled_layout.margin,
    padding: scaled_layout.padding,
    border: scaled_layout.border,
    overflow_x: scaled_layout.overflow_x,
    overflow_y: scaled_layout.overflow_y,
    scroll_width: scaled_layout.scroll_width,
    scroll_height: scaled_layout.scroll_height,
    children: scaled_layout.children,
    text: scaled_layout.text,
  }
}
