///|
/// HTML/CSS Renderer
/// Converts HTML elements with inline styles to layout

///|
/// Convert HTML Element to Node tree for layout computation
pub fn element_to_node(
  elem : @html.Element,
  parent_style : @style.Style?,
) -> @node.Node {
  // Compute style from inline style attribute with parent for inheritance
  let ctx = match parent_style {
    Some(ps) => @css.ComputeContext::with_parent(ps)
    None => @css.ComputeContext::new()
  }
  let style = match elem.style {
    Some(css) => @css.compute_inline_style(css, ctx)
    None =>
      // When no inline style, inherit from parent if available
      match parent_style {
        Some(ps) => {
          let inherited = @style.Style::default()
          // Copy inherited properties from parent
          inherited.writing_mode = ps.writing_mode
          inherited.direction = ps.direction
          inherited.color = ps.color
          inherited.pointer_events = ps.pointer_events
          inherited
        }
        None => @style.Style::default()
      }
  }

  // Convert children
  let children : Array[@node.Node] = []
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        let child_node = element_to_node(child_elem, Some(style))
        children.push(child_node)
      }
      @html.Node::Text(_text) =>
        // For now, we ignore text nodes in layout
        // In a real implementation, we'd create inline boxes
        ()
    }
  }

  // Create node ID from tag and id/class
  let node_id = match elem.id {
    Some(id) => elem.tag + "#" + id
    None =>
      if elem.classes.length() > 0 {
        elem.tag + "." + elem.classes[0]
      } else {
        elem.tag
      }
  }
  if children.is_empty() {
    @node.Node::leaf(node_id, style)
  } else {
    @node.Node::new(node_id, style, children)
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
) -> @types.Layout {
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
  let layout_ctx : @types.LayoutContext = {
    available_width,
    available_height: root_available_height,
    sizing_mode: @types.SizingMode::Definite,
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
  {
    id: scaled_layout.id,
    x: x_offset,
    y: root_margin.top,
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

///|
/// Render HTML string to Layout
pub fn render(html : String, ctx : RenderContext) -> @types.Layout {
  render_with_external_css(html, ctx, [])
}

///|
/// Render HTML string to Layout with external CSS
pub fn render_with_external_css(
  html : String,
  ctx : RenderContext,
  external_css : Array[String],
) -> @types.Layout {
  let doc = @html.parse_document(html)
  render_document_with_external_css(doc, ctx, external_css)
}

///|
/// Render a parsed HTML Document to Layout with external CSS
/// This is useful when you need to pre-process the document (e.g., add synthetic IDs)
pub fn render_document_with_external_css(
  doc : @html.Document,
  ctx : RenderContext,
  external_css : Array[String],
) -> @types.Layout {
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
) -> @types.Layout {
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
) -> (@node.Node, @types.Layout) {
  render_to_node_and_layout_with_external_css(html, ctx, [])
}

///|
/// Render the whole document without viewport skeleton culling.
pub fn render_to_node_and_layout_full_document(
  html : String,
  ctx : RenderContext,
) -> (@node.Node, @types.Layout) {
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
) -> (@node.Node, @types.Layout) {
  let doc = @html.parse_document(html)
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
) -> (@node.Node, @types.Layout) {
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
) -> (@node.Node, @types.Layout) {
  let prepared = prepare_render_document_with_prepared_external_css(
    doc, ctx, external_css,
  )
  let root = build_render_root_node(doc, ctx, prepared)
  let layout = compute_layout_from_render_root(root, prepared, ctx)
  (root, layout)
}

///|
/// Remove suffix of given length from string
fn remove_suffix(s : String, len : Int) -> String {
  let end = s.length() - len
  if end <= 0 {
    return ""
  }
  let buf = StringBuilder::new()
  for i = 0; i < end; i = i + 1 {
    buf.write_char(s[i].to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
/// Check if element should be skipped during rendering
fn should_skip_element(tag : String) -> Bool {
  match tag {
    // Script and style elements
    "script"
    | "noscript"
    | "style"
    // Metadata elements (shouldn't appear in body, but handle invalid HTML)
    | "head"
    | "meta"
    | "link"
    | "title"
    | "base"
    // Template and embedded content
    | "template"
    | "applet"
    | "track"
    | "param"
    // math is not yet supported
    | "math"
    // Other non-visual elements
    | "map"
    | "area" => true
    _ => false
  }
}

///|
/// Convert HTML Element to Node tree with stylesheet styles applied
fn element_to_node_with_styles(
  elem : @html.Element,
  parent : @css.Element?,
  ctx : RenderContext,
  stylesheets : Array[@css.Stylesheet],
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  css_vars : Map[String, String],
  incoming_counters : Map[String, CounterEntry],
  owner_id : String,
) -> @node.Node {
  let below_viewport = should_use_viewport_skeleton()
  // Convert HTML element to selector element for matching
  let effective_sheets = if below_viewport {
    empty_indexed_stylesheets.val
  } else {
    indexed_stylesheets
  }
  let selector_elem = if effective_sheets.length() == 0 {
    html_to_selector_element_minimal(elem, parent)
  } else {
    html_to_selector_element(elem, parent)
  }

  // Get style - skip full cascade for below-viewport elements
  let computed_style = compute_element_style_indexed(
    selector_elem,
    elem.style,
    effective_sheets,
    parent is None,
    ctx,
    None, // Root element has no parent style
    css_vars,
  )
  viewport_full_node_count.val += 1

  let cell_tag = elem.tag.to_lower()
  let parent_is_svg = selector_parent_is_svg(selector_elem)
  let computed_style = normalize_svg_display_contents(
    cell_tag, computed_style, parent_is_svg,
  )
  // Handle table attributes that affect table formatting context.
  let style = if cell_tag == "table" {
    let border_spacing = match elem.attributes.get("cellspacing") {
      Some(val) => {
        let n = @string.parse_double(val) catch {
          _ => computed_style.border_spacing
        }
        if n >= 0.0 {
          n
        } else {
          computed_style.border_spacing
        }
      }
      None => computed_style.border_spacing
    }
    // Track cellpadding for descendant <td>/<th> elements
    match elem.attributes.get("cellpadding") {
      Some(val) => {
        let n = @string.parse_double(val) catch { _ => -1.0 }
        if n >= 0.0 {
          current_cellpadding.val = n
        }
      }
      None => ()
    }
    // cellspacing sets both horizontal and vertical border-spacing
    let border_spacing_vertical = match elem.attributes.get("cellspacing") {
      Some(_) => border_spacing
      None => computed_style.border_spacing_vertical
    }
    { ..computed_style, border_spacing, border_spacing_vertical }
  } else {
    computed_style
  }
  // Handle table cell rowspan/colspan attributes + cellpadding
  let style = if cell_tag == "td" || cell_tag == "th" {
    let rowspan = match elem.attributes.get("rowspan") {
      Some(val) => {
        let n = @string.parse_int(val) catch { _ => 1 }
        if n > 0 {
          n
        } else {
          1
        }
      }
      None => 1
    }
    let colspan = match elem.attributes.get("colspan") {
      Some(val) => {
        let n = @string.parse_int(val) catch { _ => 1 }
        if n > 0 {
          n
        } else {
          1
        }
      }
      None => 1
    }
    // Apply cellpadding from ancestor table (only if CSS didn't set padding)
    let mut s = { ..style, rowspan, colspan }
    let cp = current_cellpadding.val
    if cp >= 0.0 {
      let default_pad = @types.Dimension::Length(0.0)
      let has_css_padding = s.padding.top != @types.Dimension::Auto &&
        s.padding.top != default_pad
      if !has_css_padding {
        s = {
          ..s,
          padding: {
            top: @types.Dimension::Length(cp),
            right: @types.Dimension::Length(cp),
            bottom: @types.Dimension::Length(cp),
            left: @types.Dimension::Length(cp),
          },
        }
      }
    }
    s
  } else {
    style
  }
  let element_css_vars = compute_element_css_vars_indexed(
    selector_elem,
    elem.style,
    effective_sheets,
    ctx,
    css_vars,
  )
  let own_counters = if stylesheets.length() == 0 {
    incoming_counters
  } else {
    compute_element_own_counters(
      incoming_counters, selector_elem, style, stylesheets, ctx, owner_id,
    )
  }
  // Skip pseudo resolution for below-viewport elements (major perf win)
  let before_pseudo = if below_viewport || stylesheets.length() == 0 {
    None
  } else {
    resolve_pseudo_spec_fast(
      selector_elem,
      style,
      ctx,
      Before,
      own_counters,
      element_css_vars,
      elem.attributes,
    )
  }
  let after_pseudo = if below_viewport || stylesheets.length() == 0 {
    None
  } else {
    resolve_pseudo_spec_fast(
      selector_elem,
      style,
      ctx,
      After,
      own_counters,
      element_css_vars,
      elem.attributes,
    )
  }
  let style = match after_pseudo {
    Some(spec) if spec.position_relative && spec.left_offset != 0.0 =>
      {
        ..style,
        position: @types.Relative,
        inset: { ..style.inset, left: @types.Length(spec.left_offset) },
      }
    _ =>
      match before_pseudo {
        Some(spec) if spec.position_relative && spec.left_offset != 0.0 =>
          {
            ..style,
            position: @types.Relative,
            inset: { ..style.inset, left: @types.Length(spec.left_offset) },
          }
        _ => style
      }
  }

  // Convert children - first collect inline content (text + br)
  // Pass stylesheets to detect CSS display values (e.g., display: inline-block)
  let children : Array[@node.Node] = []
  let preserve_inline_elements = match style.display {
    @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid => true
    _ => should_preserve_inline_children_for_text_overflow(style)
  }
  let (inline_text, remaining_children) = if is_svg_element(cell_tag) {
    ("", elem.children)
  } else {
    collect_inline_content(
      elem.children,
      stylesheets,
      ctx,
      preserve_inline_elements,
      selector_elem,
    )
  }

  match before_pseudo {
    Some(spec) => children.push(create_generated_pseudo_node(spec, Before))
    None => ()
  }

  // Add combined text node if there's inline content
  if !inline_text.trim().is_empty() {
    let text_node = create_text_node(inline_text, style)
    children.push(text_node)
  }

  let child_seed_counters = if stylesheets.length() == 0 {
    own_counters
  } else if establishes_style_containment_scope(style) {
    filter_counter_state_for_style_containment(own_counters, owner_id)
  } else {
    own_counters
  }
  let include_selector_match_data = indexed_stylesheets.length() > 0
  let mut prev_sibling_counters : Map[String, CounterEntry]? = None
  let mut prev_selector_sibling : @css.Element? = None
  let mut element_child_index = 0
  let mut element_child_count = 0
  if include_selector_match_data {
    for child in remaining_children {
      match child {
        @html.Node::Element(_) => element_child_count = element_child_count + 1
        _ => ()
      }
    }
  }
  // Process remaining children (elements and synthetic text nodes)
  for i, child in remaining_children {
    match child {
      @html.Node::Element(child_elem) => {
        // Skip non-rendered elements
        if should_skip_element(child_elem.tag) {
          continue
        }
        element_child_index += 1
        let child_owner_id = if stylesheets.length() == 0 {
          owner_id
        } else {
          owner_id + "/" + element_child_index.to_string()
        }
        let child_incoming_counters = if stylesheets.length() == 0 {
          child_seed_counters
        } else {
          match prev_sibling_counters {
            Some(counters) => copy_counter_state(counters)
            None => copy_counter_state(child_seed_counters)
          }
        }
        // Update sibling info on selector element for child processing
        let child_selector = if include_selector_match_data {
          html_to_selector_element_with_parent(
            child_elem, selector_elem, element_child_index, element_child_count,
            prev_selector_sibling,
          )
        } else {
          html_to_selector_element_minimal(child_elem, Some(selector_elem))
        }
        if stylesheets.length() > 0 {
          let child_style_for_counter = compute_element_style_indexed(
            child_selector,
            child_elem.style,
            indexed_stylesheets,
            false,
            ctx,
            Some(style),
            element_css_vars,
          )
          let child_own_counters = compute_element_own_counters(
            child_incoming_counters, child_selector, child_style_for_counter, stylesheets,
            ctx, child_owner_id,
          )
          prev_sibling_counters = Some(child_own_counters)
        }
        if include_selector_match_data {
          prev_selector_sibling = Some(child_selector)
        }
        let child_node = element_to_node_with_styles_internal(
          child_elem,
          child_selector,
          ctx,
          stylesheets,
          indexed_stylesheets,
          Some(style),
          element_css_vars,
          child_incoming_counters,
          child_owner_id,
        )
        children.push(child_node)
      }
      @html.Node::Text(text) =>
        // Process synthetic text nodes created by collect_inline_content
        // to preserve DOM order when elements are interleaved with text.
        if !text.is_empty() {
          let normalized_text = trim_boundary_collapsible_whitespace_for_inline_context(
            remaining_children, i, selector_elem, style, indexed_stylesheets, ctx,
            element_css_vars,
          )
          if normalized_text.is_empty() {
            continue
          }
          let text_is_ws = is_whitespace_only_text(normalized_text)
          let preserve_ws = text_is_ws &&
            should_preserve_inter_element_whitespace(
              remaining_children, i, selector_elem, style, indexed_stylesheets, ctx,
              element_css_vars,
            ) &&
            !style.writing_mode.is_vertical() &&
            !style.suppresses_intrinsic_width()
          if text_is_ws && !preserve_ws {
            continue
          }
          let text_parent_style = if preserve_ws {
            { ..style, display: @types.Inline }
          } else {
            style
          }
          let text_node = create_text_node(normalized_text, text_parent_style)
          children.push(text_node)
        }
    }
  }
  match after_pseudo {
    Some(spec) => children.push(create_generated_pseudo_node(spec, After))
    None => ()
  }

  // Create node ID
  let node_id = make_node_id(elem)
  if children.is_empty() {
    @node.Node::leaf(node_id, style)
  } else {
    @node.Node::new(node_id, style, children)
  }
}

///|
/// Internal element conversion with pre-computed selector element
fn element_to_node_with_styles_internal(
  elem : @html.Element,
  selector_elem : @css.Element,
  ctx : RenderContext,
  stylesheets : Array[@css.Stylesheet],
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  parent_style : @style.Style?,
  css_vars : Map[String, String],
  incoming_counters : Map[String, CounterEntry],
  owner_id : String,
) -> @node.Node {
  // Viewport culling: skeleton mode for below-fold elements
  let below_viewport = should_use_viewport_skeleton()
  if below_viewport {
    viewport_skeleton_count.val += 1
    // Fast path: create minimal skeleton node with inherited style
    let skeleton_style = match parent_style {
      Some(ps) => {
        let s = @style.Style::default()
        s.font_size = ps.font_size
        s.line_height = ps.line_height
        s.color = ps.color
        s
      }
      None => @style.Style::default()
    }
    let allow_size_hints = skeleton_parent_allows_explicit_size_hints(
      parent_style,
    )
    let skeleton_style = match elem.style {
      Some(inline_css) =>
        if allow_size_hints {
          apply_skeleton_inline_style_hints(skeleton_style, inline_css)
        } else {
          apply_skeleton_inline_display_hint(skeleton_style, inline_css)
        }
      None => skeleton_style
    }
    // Check hidden/dialog (important for correct scroll height)
    if elem.attributes.contains("hidden") {
      skeleton_style.display = @types.Display::None
    }
    let tag_lower = elem.tag.to_lower()
    if tag_lower == "dialog" && !elem.attributes.contains("open") {
      skeleton_style.display = @types.Display::None
    }
    if skeleton_style.display == @types.Display::None {
      return @node.Node::leaf(make_node_id(elem), skeleton_style)
    }
    // Estimate height for scroll
    if should_advance_viewport_estimate(skeleton_style) {
      viewport_estimated_y.val += viewport_skeleton_advance(skeleton_style)
    }
    if allow_size_hints &&
      should_collapse_viewport_skeleton_subtree(skeleton_style) {
      return @node.Node::leaf(make_node_id(elem), skeleton_style)
    }
    // Process children in skeleton mode (recursive)
    let children : Array[@node.Node] = []
    for child in elem.children {
      match child {
        @html.Node::Element(child_elem) => {
          if should_skip_element(child_elem.tag) {
            continue
          }
          let child_selector = html_to_selector_element_minimal(
            child_elem,
            Some(selector_elem),
          )
          let child_node = element_to_node_with_styles_internal(
            child_elem,
            child_selector,
            ctx,
            stylesheets,
            indexed_stylesheets,
            Some(skeleton_style),
            css_vars,
            incoming_counters,
            owner_id,
          )
          children.push(child_node)
        }
        @html.Node::Text(text) =>
          if !text.is_empty() {
            children.push(create_text_node(text, skeleton_style))
          }
      }
    }
    return @node.Node::new(make_node_id(elem), skeleton_style, children)
  }
  // Full path: below viewport check passed
  let computed_style = compute_element_style_indexed(
    selector_elem,
    elem.style,
    indexed_stylesheets,
    false,
    ctx,
    parent_style,
    css_vars,
  )
  viewport_full_node_count.val += 1
  // HTML hidden attribute → display: none (UA default per spec)
  if elem.attributes.contains("hidden") {
    computed_style.display = @types.Display::None
  }
  // Cache tag name lowercase (avoid repeated to_lower() calls)
  let tag_lower = elem.tag.to_lower()
  // <dialog> without open attribute → display: none
  if tag_lower == "dialog" && !elem.attributes.contains("open") {
    computed_style.display = @types.Display::None
  }
  // Early return for display:none - skip all child processing
  if computed_style.display == @types.Display::None {
    return @node.Node::leaf(make_node_id(elem), computed_style)
  }
  // Viewport culling: estimate Y position for block elements
  if should_advance_viewport_estimate(computed_style) {
    viewport_estimated_y.val += computed_style.line_height
  }
  // Keep contain flags on <rt> so ruby-specific fallback logic can distinguish
  // contain:size/paint test fixtures. Other inline elements still strip contain.
  let preserve_inline_contain = tag_lower == "rt"
  let computed_style = if computed_style.display == @types.Inline &&
    !preserve_inline_contain &&
    !is_replaced_element(tag_lower) &&
    (
      computed_style.contain.layout ||
      computed_style.contain.paint ||
      computed_style.contain.size ||
      computed_style.contain.inline_size
    ) {
    {
      ..computed_style,
      contain: {
        ..computed_style.contain,
        layout: false,
        paint: false,
        size: false,
        inline_size: false,
      },
    }
  } else {
    computed_style
  }
  let parent_is_svg = selector_parent_is_svg(selector_elem)
  let computed_style = normalize_svg_display_contents(
    tag_lower, computed_style, parent_is_svg,
  )

  let is_ruby_internal = tag_lower == "ruby" ||
    tag_lower == "rb" ||
    tag_lower == "rbc" ||
    tag_lower == "rt" ||
    tag_lower == "rtc" ||
    tag_lower == "rp"

  // Skip expensive pre-checks for below-viewport elements
  let inline_has_block_child = if below_viewport {
    false
  } else {
    computed_style.display == @types.Inline &&
    !is_ruby_internal &&
    computed_style.position == @types.Static &&
    contains_block_child(elem, stylesheets, ctx) &&
    !(has_direct_display_contents_child(
      elem, selector_elem, computed_style, indexed_stylesheets, ctx, css_vars,
    ) ||
    has_direct_contents_class_child(elem))
  }

  // If this is an inline element containing replaced elements (like <a><img></a>),
  // treat it as inline-block so it gets proper sizing from its content
  // Also, if inline element contains block children (like <code><span class="line">),
  // treat it as block so children can be properly laid out
  let style = if inline_has_block_child {
    // Inline element with block children should become block
    // This handles cases like <code><span class="line" style="display:block">
    { ..computed_style, display: @types.Block }
  } else if computed_style.display == @types.Inline &&
    tag_lower != "picture" &&
    contains_replaced_element(elem) {
    { ..computed_style, display: @types.InlineBlock }
  } else {
    computed_style
  }

  // Handle table attributes that affect table formatting context.
  let cell_tag = tag_lower
  let style = if cell_tag == "table" {
    let border_spacing = match elem.attributes.get("cellspacing") {
      Some(val) => {
        let n = @string.parse_double(val) catch { _ => style.border_spacing }
        if n >= 0.0 {
          n
        } else {
          style.border_spacing
        }
      }
      None => style.border_spacing
    }
    // Track cellpadding for descendant <td>/<th> elements
    match elem.attributes.get("cellpadding") {
      Some(val) => {
        let n = @string.parse_double(val) catch { _ => -1.0 }
        if n >= 0.0 {
          current_cellpadding.val = n
        }
      }
      None => ()
    }
    // cellspacing sets both horizontal and vertical border-spacing
    let border_spacing_vertical = match elem.attributes.get("cellspacing") {
      Some(_) => border_spacing
      None => style.border_spacing_vertical
    }
    { ..style, border_spacing, border_spacing_vertical }
  } else {
    style
  }
  // Handle table cell rowspan/colspan attributes + cellpadding
  let style = if cell_tag == "td" || cell_tag == "th" {
    let rowspan = match elem.attributes.get("rowspan") {
      Some(val) => {
        let n = @string.parse_int(val) catch { _ => 1 }
        if n > 0 {
          n
        } else {
          1
        }
      }
      None => 1
    }
    let colspan = match elem.attributes.get("colspan") {
      Some(val) => {
        let n = @string.parse_int(val) catch { _ => 1 }
        if n > 0 {
          n
        } else {
          1
        }
      }
      None => 1
    }
    // Apply cellpadding from ancestor table (only if CSS didn't set padding)
    let mut s = { ..style, rowspan, colspan }
    let cp = current_cellpadding.val
    if cp >= 0.0 {
      let default_pad = @types.Dimension::Length(0.0)
      let has_css_padding = s.padding.top != @types.Dimension::Auto &&
        s.padding.top != default_pad
      if !has_css_padding {
        s = {
          ..s,
          padding: {
            top: @types.Dimension::Length(cp),
            right: @types.Dimension::Length(cp),
            bottom: @types.Dimension::Length(cp),
            left: @types.Dimension::Length(cp),
          },
        }
      }
    }
    s
  } else {
    style
  }

  // Handle SVG element size from attributes
  let style = if is_svg_element(cell_tag) {
    apply_svg_attributes_to_style(style, elem.attributes, cell_tag)
  } else {
    style
  }

  let style = apply_svg_intrinsic_size(style, cell_tag)
  let element_css_vars = compute_element_css_vars_indexed(
    selector_elem,
    elem.style,
    indexed_stylesheets,
    ctx,
    css_vars,
  )
  let own_counters = if stylesheets.length() == 0 {
    incoming_counters
  } else {
    compute_element_own_counters(
      incoming_counters, selector_elem, style, stylesheets, ctx, owner_id,
    )
  }
  // Skip pseudo resolution for below-viewport elements (major perf win)
  let before_pseudo = if below_viewport || stylesheets.length() == 0 {
    None
  } else {
    resolve_pseudo_spec_fast(
      selector_elem,
      style,
      ctx,
      Before,
      own_counters,
      element_css_vars,
      elem.attributes,
    )
  }
  let after_pseudo = if below_viewport || stylesheets.length() == 0 {
    None
  } else {
    resolve_pseudo_spec_fast(
      selector_elem,
      style,
      ctx,
      After,
      own_counters,
      element_css_vars,
      elem.attributes,
    )
  }
  let style = match after_pseudo {
    Some(spec) if spec.position_relative && spec.left_offset != 0.0 =>
      {
        ..style,
        position: @types.Relative,
        inset: { ..style.inset, left: @types.Length(spec.left_offset) },
      }
    _ =>
      match before_pseudo {
        Some(spec) if spec.position_relative && spec.left_offset != 0.0 =>
          {
            ..style,
            position: @types.Relative,
            inset: { ..style.inset, left: @types.Length(spec.left_offset) },
          }
        _ => style
      }
  }
  // Convert children - first collect inline content (text + br)
  // Pass stylesheets to detect CSS display values (e.g., display: inline-block)
  let children : Array[@node.Node] = []
  let preserve_inline_elements = match style.display {
    @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid => true
    _ => should_preserve_inline_children_for_text_overflow(style)
  }
  let (inline_text, remaining_children) = if is_svg_element(tag_lower) {
    ("", elem.children)
  } else {
    collect_inline_content(
      elem.children,
      stylesheets,
      ctx,
      preserve_inline_elements,
      selector_elem,
    )
  }

  match before_pseudo {
    Some(spec) => children.push(create_generated_pseudo_node(spec, Before))
    None => ()
  }

  // Add combined text node if there's inline content
  if !inline_text.trim().is_empty() {
    let text_node = create_text_node(inline_text, style)
    children.push(text_node)
  }

  let child_seed_counters = if stylesheets.length() == 0 {
    own_counters
  } else if establishes_style_containment_scope(style) {
    filter_counter_state_for_style_containment(own_counters, owner_id)
  } else {
    own_counters
  }
  let include_selector_match_data = indexed_stylesheets.length() > 0
  let mut prev_sibling_counters : Map[String, CounterEntry]? = None
  let mut prev_selector_sibling : @css.Element? = None
  let mut element_child_index = 0
  let mut element_child_count = 0
  if include_selector_match_data {
    for child in remaining_children {
      match child {
        @html.Node::Element(_) => element_child_count = element_child_count + 1
        _ => ()
      }
    }
  }
  // Process remaining children (elements and synthetic text nodes)
  for i, child in remaining_children {
    match child {
      @html.Node::Element(child_elem) => {
        // Skip non-rendered elements
        if should_skip_element(child_elem.tag) {
          continue
        }
        element_child_index += 1
        let child_owner_id = if stylesheets.length() == 0 {
          owner_id
        } else {
          owner_id + "/" + element_child_index.to_string()
        }
        let child_incoming_counters = if stylesheets.length() == 0 {
          child_seed_counters
        } else {
          match prev_sibling_counters {
            Some(counters) => copy_counter_state(counters)
            None => copy_counter_state(child_seed_counters)
          }
        }
        let child_selector = if include_selector_match_data {
          html_to_selector_element_with_parent(
            child_elem, selector_elem, element_child_index, element_child_count,
            prev_selector_sibling,
          )
        } else {
          html_to_selector_element_minimal(child_elem, Some(selector_elem))
        }
        if stylesheets.length() > 0 {
          let child_style_for_counter = compute_element_style_indexed(
            child_selector,
            child_elem.style,
            indexed_stylesheets,
            false,
            ctx,
            Some(style),
            element_css_vars,
          )
          let child_own_counters = compute_element_own_counters(
            child_incoming_counters, child_selector, child_style_for_counter, stylesheets,
            ctx, child_owner_id,
          )
          prev_sibling_counters = Some(child_own_counters)
        }
        if include_selector_match_data {
          prev_selector_sibling = Some(child_selector)
        }
        let child_node = element_to_node_with_styles_internal(
          child_elem,
          child_selector,
          ctx,
          stylesheets,
          indexed_stylesheets,
          Some(style),
          element_css_vars,
          child_incoming_counters,
          child_owner_id,
        )
        children.push(child_node)
      }
      @html.Node::Text(text) =>
        // Process synthetic text nodes created by collect_inline_content
        // to preserve DOM order when elements are interleaved with text.
        if !text.is_empty() {
          let normalized_text = trim_boundary_collapsible_whitespace_for_inline_context(
            remaining_children, i, selector_elem, style, indexed_stylesheets, ctx,
            element_css_vars,
          )
          if normalized_text.is_empty() {
            continue
          }
          let text_is_ws = is_whitespace_only_text(normalized_text)
          let preserve_ws = text_is_ws &&
            should_preserve_inter_element_whitespace(
              remaining_children, i, selector_elem, style, indexed_stylesheets, ctx,
              element_css_vars,
            ) &&
            !style.writing_mode.is_vertical() &&
            !style.suppresses_intrinsic_width()
          if text_is_ws && !preserve_ws {
            continue
          }
          let text_parent_style = if preserve_ws {
            { ..style, display: @types.Inline }
          } else {
            style
          }
          let text_node = create_text_node(normalized_text, text_parent_style)
          children.push(text_node)
        }
    }
  }
  match after_pseudo {
    Some(spec) => children.push(create_generated_pseudo_node(spec, After))
    None => ()
  }
  let children = if tag_lower == "details" && !elem.attributes.contains("open") {
    prune_closed_details_children(children)
  } else {
    children
  }
  let node_id = make_node_id(elem)

  // Handle replaced elements (img, input, etc.) with intrinsic sizing
  if tag_lower == "input" && children.is_empty() {
    // Get input type (default is "text")
    let input_type = match elem.attributes.get("type") {
      Some(t) => t.to_lower()
      None => "text"
    }
    let control_font_size = if style.font_size > 0.0 {
      style.font_size
    } else {
      16.0
    }
    let control_line_height = if style.line_height > 0.0 {
      style.line_height
    } else {
      control_font_size * 1.15
    }
    let char_width = resolve_control_char_width(
      control_font_size,
      control_line_height,
      style.writing_mode,
    )
    // Get intrinsic dimensions based on input type
    // These are approximate browser defaults
    let (intrinsic_width, intrinsic_height) : (Double, Double) = match
      input_type {
      "radio" | "checkbox" => (13.0, 13.0)
      "button" | "submit" | "reset" => {
        let label = match elem.attributes.get("value") {
          Some(v) if !v.is_empty() => v
          _ =>
            match input_type {
              "submit" => "Submit"
              "reset" => "Reset"
              _ => ""
            }
        }
        let mut label_cols = 0
        for c in label.iter() {
          label_cols = label_cols + char_display_width(c)
        }
        let label_width = label_cols.to_double() * char_width
        let min_width = control_font_size * 1.75
        let intrinsic_w = @types.max(
          min_width,
          label_width + control_font_size * 0.72,
        )
        (intrinsic_w, 21.0)
      }
      "range" => (129.0, 21.0)
      "color" => (44.0, 23.0)
      "file" => (238.0, 21.0)
      "text" | "password" | "search" | "email" | "url" | "tel" | "number" => {
        let size_chars = match elem.attributes.get("size") {
          Some(size_attr) =>
            match parse_html_dimension(size_attr) {
              Some(v) if v > 0.0 => v
              _ => 20.0
            }
          None => 20.0
        }
        let padding_h = resolve_dimension_to_px(style.padding.left) +
          resolve_dimension_to_px(style.padding.right)
        let padding_v = resolve_dimension_to_px(style.padding.top) +
          resolve_dimension_to_px(style.padding.bottom)
        let border_h = resolve_dimension_to_px(style.border.left) +
          resolve_dimension_to_px(style.border.right)
        let border_v = resolve_dimension_to_px(style.border.top) +
          resolve_dimension_to_px(style.border.bottom)
        let control_extra_width = if control_font_size <= 13.0 {
          control_font_size
        } else {
          control_font_size * 0.75
        }
        let control_extra_height = if control_font_size <= 13.0 {
          4.5
        } else {
          control_font_size * 0.35
        }
        let input_extra_width = if padding_h > 0.0 {
          padding_h + border_h
        } else {
          control_extra_width
        }
        let input_extra_height = if padding_v > 0.0 {
          padding_v + border_v
        } else {
          control_extra_height
        }
        (
          size_chars * char_width + input_extra_width,
          control_line_height + input_extra_height,
        )
      }
      // text, password, email, url, tel, search, number, date, etc.
      _ => (150.0, 21.0)
    }
    let measure = create_input_measure(intrinsic_width, intrinsic_height)
    let preserve_auto_width = should_preserve_auto_replaced_width(style)
    let preserve_auto_height = should_preserve_auto_replaced_height(style)
    let input_text = resolve_input_paint_text(input_type, elem.attributes)
    let placeholder_text = input_uses_placeholder_text(
      input_type,
      elem.attributes,
    )
    let input_style : @style.Style = {
      ..style,
      color: if placeholder_text {
        @types.Color::rgb(117, 117, 117)
      } else {
        style.color
      },
      width: if style.width == @types.Auto && !preserve_auto_width {
        @types.Length(intrinsic_width)
      } else {
        style.width
      },
      height: if style.height == @types.Auto && !preserve_auto_height {
        @types.Length(intrinsic_height)
      } else {
        style.height
      },
    }
    match input_text {
      Some(text) =>
        return @node.Node::with_measure(node_id, input_style, measure, text~)
      None => return @node.Node::with_measure(node_id, input_style, measure)
    }
  }
  let style = if tag_lower == "button" &&
    !style.contain.size &&
    !style.writing_mode.is_vertical() {
    fn is_zero_padding(dim : @types.Dimension) -> Bool {
      match dim {
        @types.Length(v) => v == 0.0
        _ => false
      }
    }
    let has_zero_padding = is_zero_padding(style.padding.top) &&
      is_zero_padding(style.padding.right) &&
      is_zero_padding(style.padding.bottom) &&
      is_zero_padding(style.padding.left)
    if has_zero_padding {
      {
        ..style,
        padding: {
          top: @types.Length(0.7),
          right: @types.Length(4.75),
          bottom: @types.Length(0.7),
          left: @types.Length(4.75),
        },
      }
    } else {
      style
    }
  } else {
    style
  }
  if tag_lower == "textarea" {
    let font_size = if style.font_size > 0.0 { style.font_size } else { 16.0 }
    // Browser default textarea intrinsic row-height is tighter than generic
    // line-height: normal; approximate as font-size + 1px per row.
    let control_line_height = font_size + 1.0
    // Browsers include textarea chrome around the rows even under border-box.
    // Keep this narrow so form-control regressions stay localized to textarea.
    let control_extra_height = 6.0
    let char_width = resolve_control_char_width(
      font_size,
      control_line_height,
      style.writing_mode,
    )
    let cols = match elem.attributes.get("cols") {
      Some(cols_attr) =>
        match parse_html_dimension(cols_attr) {
          Some(v) if v > 0.0 => v
          _ => 20.0
        }
      None => 20.0
    }
    let rows = match elem.attributes.get("rows") {
      Some(rows_attr) =>
        match parse_html_dimension(rows_attr) {
          Some(v) if v > 0.0 => v
          _ => 2.0
        }
      None => 2.0
    }
    let intrinsic_width = cols * char_width + font_size * 1.1
    let intrinsic_height = rows * control_line_height + control_extra_height
    let measure = create_input_measure(intrinsic_width, intrinsic_height)
    let preserve_auto_width = should_preserve_auto_replaced_width(style)
    let preserve_auto_height = should_preserve_auto_replaced_height(style)
    let textarea_style : @style.Style = {
      ..style,
      width: if style.width == @types.Auto && !preserve_auto_width {
        @types.Length(intrinsic_width)
      } else {
        style.width
      },
      height: if style.height == @types.Auto && !preserve_auto_height {
        @types.Length(intrinsic_height)
      } else {
        style.height
      },
    }
    return @node.Node::with_measure(node_id, textarea_style, measure)
  }
  if tag_lower == "select" {
    fn border_is_zero_length(dim : @types.Dimension) -> Bool {
      match dim {
        @types.Length(v) => v == 0.0
        _ => false
      }
    }
    let has_ua_border = !(border_is_zero_length(style.border.top) &&
      border_is_zero_length(style.border.right) &&
      border_is_zero_length(style.border.bottom) &&
      border_is_zero_length(style.border.left))
    let select_size = match elem.attributes.get("size") {
      Some(size_attr) =>
        match parse_html_dimension(size_attr) {
          Some(v) if v > 0.0 => v.to_int()
          _ => 0
        }
      None => 0
    }
    let has_multiple = elem.attributes.contains("multiple")
    let is_listbox = has_multiple || select_size > 1
    let visible_rows = if select_size > 0 {
      select_size
    } else if is_listbox {
      4
    } else {
      1
    }
    let font_size = if style.font_size > 0.0 { style.font_size } else { 16.0 }
    let default_line_height = if style.line_height > 0.0 {
      style.line_height
    } else {
      font_size * 1.2
    }
    let char_width = resolve_control_char_width(
      font_size,
      default_line_height,
      style.writing_mode,
    )
    let suppress_intrinsic_width = style.suppresses_intrinsic_width()
    fn collect_html_text(node : @html.Node) -> String {
      match node {
        @html.Node::Text(text) => text
        @html.Node::Element(child_elem) => {
          let mut text = ""
          for grand_child in child_elem.children {
            text = text + collect_html_text(grand_child)
          }
          text
        }
      }
    }
    let mut max_option_cols = 0
    if !suppress_intrinsic_width {
      for child in elem.children {
        match child {
          @html.Node::Element(child_elem) =>
            if child_elem.tag.to_lower() == "option" {
              let mut option_text = ""
              for option_child in child_elem.children {
                option_text = option_text + collect_html_text(option_child)
              }
              let mut cols = 0
              for c in option_text.iter() {
                cols = cols + char_display_width(c)
              }
              if cols > max_option_cols {
                max_option_cols = cols
              }
            }
          _ => ()
        }
      }
    }
    let content_based_width = if max_option_cols > 0 {
      max_option_cols.to_double() * char_width + font_size * 0.375
    } else {
      0.0
    }
    let single_default_width = @types.max(22.0, content_based_width)
    let listbox_default_width = if suppress_intrinsic_width {
      2.0
    } else if max_option_cols > 0 {
      @types.max(2.0, content_based_width)
    } else {
      2.0
    }
    let default_width = if is_listbox {
      listbox_default_width
    } else if suppress_intrinsic_width {
      22.0
    } else {
      single_default_width
    }
    let default_height = if is_listbox {
      if visible_rows <= 1 {
        17.5
      } else if visible_rows == 4 {
        if font_size <= 12.0 {
          48.0
        } else {
          64.0
        }
      } else {
        let row_height = if font_size <= 12.0 { 11.5 } else { 15.5 }
        2.0 + visible_rows.to_double() * row_height
      }
    } else {
      19.0
    }
    let default_border : @types.Rect[@types.Dimension] = @types.Rect::new(
      @types.Length(1.0),
      @types.Length(1.0),
      @types.Length(1.0),
      @types.Length(1.0),
    )
    let zero_dim_rect : @types.Rect[@types.Dimension] = @types.Rect::new(
      @types.Length(0.0),
      @types.Length(0.0),
      @types.Length(0.0),
      @types.Length(0.0),
    )

    let normalized_children : Array[@node.Node] = []
    let mut option_index = 0
    for child in children {
      let is_option = node_id_is_tag(child.id, "option")
      if is_option {
        let option_style = if is_listbox {
          let option_font_size = if child.style.font_size > 0.0 {
            child.style.font_size
          } else {
            font_size
          }
          let option_row_height = option_font_size * 1.15 + 1.0
          {
            ..child.style,
            display: @types.Block,
            height: @types.Length(option_row_height),
          }
        } else {
          let top_offset = if option_index == 0 {
            -default_line_height
          } else {
            0.0
          }
          {
            ..child.style,
            display: @types.Block,
            width: @types.Length(0.0),
            height: @types.Length(0.0),
            margin: @types.Rect::new(
              @types.Length(top_offset),
              @types.Length(0.0),
              @types.Length(0.0),
              @types.Length(0.0),
            ),
            padding: zero_dim_rect,
            border: zero_dim_rect,
          }
        }
        let option_children = if is_listbox { child.children } else { [] }
        normalized_children.push(
          @node.Node::with_uid_and_measure(
            child.id,
            child.uid,
            option_style,
            option_children,
            child.measure,
            child.text,
          ),
        )
        option_index = option_index + 1
      } else {
        normalized_children.push(child)
      }
    }
    let preserve_auto_width = should_preserve_auto_replaced_width(style)
    let preserve_auto_height = should_preserve_auto_replaced_height(style)
    let select_style : @style.Style = {
      ..style,
      border: if has_ua_border {
        style.border
      } else {
        default_border
      },
      width: if style.width == @types.Auto && !preserve_auto_width {
        @types.Length(default_width)
      } else {
        style.width
      },
      height: if style.height == @types.Auto && !preserve_auto_height {
        @types.Length(default_height)
      } else {
        style.height
      },
    }
    return @node.Node::new(node_id, select_style, normalized_children)
  }
  if tag_lower == "svg" && children.is_empty() {
    // Root SVG behaves as a replaced element with default object size 300x150.
    // Keep CSS width/height auto semantics and expose intrinsic size via MeasureFunc.
    let attr_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(0.0)
      None => 0.0
    }
    let attr_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(0.0)
      None => 0.0
    }
    let intrinsic_width = if attr_width > 0.0 { attr_width } else { 300.0 }
    let intrinsic_height = if attr_height > 0.0 { attr_height } else { 150.0 }
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, style, measure)
  }
  if tag_lower == "img" && children.is_empty() {
    // HTML width/height attributes are presentational hints (used as CSS defaults),
    // while decoded image size is intrinsic data used for MeasureFunc/aspect-ratio.
    let attr_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(0.0)
      None => 0.0
    }
    let attr_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(0.0)
      None => 0.0
    }
    let mut intrinsic_width = attr_width
    let mut intrinsic_height = attr_height
    let mut uses_svg_fallback_object_size = false
    let mut uses_alt_fallback_size = false
    let mut uses_alt_text_overflow_box = false
    // Fill missing intrinsic dimensions from src data when available.
    if intrinsic_width == 0.0 || intrinsic_height == 0.0 {
      match elem.attributes.get("src") {
        Some(src) =>
          match get_image_intrinsic_size(src) {
            Some((w, h)) => {
              if intrinsic_width == 0.0 {
                intrinsic_width = w
              }
              if intrinsic_height == 0.0 {
                intrinsic_height = h
              }
            }
            None => ()
          }
        None => ()
      }
    }
    // Data-SVG without intrinsic dimensions falls back to 300x150.
    let has_svg_data_src = match elem.attributes.get("src") {
      Some(src) => src.to_lower().has_prefix("data:image/svg+xml")
      None => false
    }
    if intrinsic_width == 0.0 && intrinsic_height == 0.0 && has_svg_data_src {
      intrinsic_width = 300.0
      intrinsic_height = 150.0
      uses_svg_fallback_object_size = true
    }
    let alt_text = elem.attributes.get("alt")
    let has_non_data_src = match elem.attributes.get("src") {
      Some(src) => !src.to_lower().has_prefix("data:")
      None => false
    }
    // Chromium-style broken image fallback in our WPT setup: when external
    // image loading is unavailable and alt text exists, keep a visible fallback box.
    if intrinsic_width == 0.0 &&
      intrinsic_height == 0.0 &&
      has_non_data_src &&
      !style.suppresses_intrinsic_width() &&
      !style.suppresses_intrinsic_height() {
      match alt_text {
        Some(alt) =>
          if alt.length() > 0 {
            if broken_img_alt_uses_non_replaced_overflow_box(style) {
              uses_alt_text_overflow_box = true
            } else {
              intrinsic_width = 64.0
              intrinsic_height = if style.display == @types.Block {
                let fallback_line_height = if style.line_height > 0.0 {
                  style.line_height
                } else {
                  style.font_size
                }
                96.0 + fallback_line_height
              } else {
                96.0
              }
              uses_alt_fallback_size = true
            }
          }
        None => ()
      }
    }

    // Check if CSS dimensions are percentages - we need to handle these specially
    // even if intrinsic dimensions are 0
    let height_is_percent = match style.height {
      @types.Percent(_) => true
      _ => false
    }
    let width_is_percent = match style.width {
      @types.Percent(_) => true
      _ => false
    }
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    // Always treat <img> as replaced; unknown intrinsic size remains 0x0,
    // but CSS sizing keywords/percentages still need replaced-element behavior.
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    // Calculate intrinsic aspect ratio (width / height)
    let intrinsic_aspect_ratio = if intrinsic_height > 0.0 &&
      intrinsic_width > 0.0 &&
      !uses_svg_fallback_object_size &&
      !uses_alt_fallback_size {
      Some(intrinsic_width / intrinsic_height)
    } else {
      None
    }

    // Build img style similar to canvas:
    // - Use HTML attribute dimension as default when CSS is Auto
    // - CSS dimensions (%, px, etc.) override HTML attributes
    // - Set aspect ratio from intrinsic dimensions if not already set
    // - If height is %, keep width as Auto so aspect_ratio can compute it
    let resolved_width : @types.Dimension = if style.width == @types.Auto {
      if suppress_auto_inline_size {
        @types.Auto
        // If height is %, keep width Auto to let aspect_ratio compute it
      } else if height_is_percent {
        @types.Auto
      } else if attr_width > 0.0 {
        @types.Length(attr_width)
      } else {
        style.width
      }
    } else {
      style.width
    }
    let resolved_height : @types.Dimension = if style.height == @types.Auto {
      if suppress_auto_block_size {
        @types.Auto
        // If width is %, keep height Auto to let aspect_ratio compute it
      } else if width_is_percent {
        @types.Auto
      } else if style.width != @types.Auto {
        @types.Auto
      } else if attr_height > 0.0 {
        @types.Length(attr_height)
      } else {
        style.height
      }
    } else {
      style.height
    }
    let keep_intrinsic_ratio = should_apply_intrinsic_replaced_aspect_ratio(
      resolved_width, resolved_height,
    )
    let img_style : @style.Style = {
      ..style,
      width: resolved_width,
      height: resolved_height,
      // Set aspect ratio from intrinsic dimensions (for % sizing)
      aspect_ratio: match style.aspect_ratio {
        Some(_) => style.aspect_ratio // Keep CSS-specified ratio
        None => if keep_intrinsic_ratio { intrinsic_aspect_ratio } else { None }
      },
    }
    let src_attr = elem.attributes.get("src")
    return match alt_text {
      Some(alt) =>
        if uses_alt_text_overflow_box {
          @node.Node::new(node_id, { ..img_style, aspect_ratio: None }, [
            create_text_node(alt, img_style),
          ])
        } else {
          @node.Node::with_measure(
            node_id,
            img_style,
            measure,
            text=alt,
            src=src_attr,
          )
        }
      None =>
        @node.Node::with_measure(node_id, img_style, measure, src=src_attr)
    }
  }
  // Handle canvas element with intrinsic sizing
  if tag_lower == "canvas" && children.is_empty() {
    // Canvas has default intrinsic size of 300x150 (HTML spec)
    let default_width = 300.0
    let default_height = 150.0

    // Get dimensions from HTML attributes (override defaults)
    let intrinsic_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(default_width)
      None => default_width
    }
    let intrinsic_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(default_height)
      None => default_height
    }

    // Calculate intrinsic aspect ratio (width / height)
    let intrinsic_aspect_ratio = if intrinsic_height > 0.0 {
      Some(intrinsic_width / intrinsic_height)
    } else {
      None
    }

    // Build canvas style:
    // - Keep CSS auto dimensions as auto; intrinsic size still comes from MeasureFunc
    // - CSS dimensions (%, px, etc.) override the intrinsic defaults
    // - Set aspect ratio from intrinsic dimensions if not already set
    // - If one axis is percentage-sized, keep the opposite axis auto so aspect-ratio can compute it
    let height_is_percent = match style.height {
      @types.Percent(_) => true
      _ => false
    }
    let width_is_percent = match style.width {
      @types.Percent(_) => true
      _ => false
    }
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    let resolved_width : @types.Dimension = if style.width == @types.Auto {
      if suppress_auto_inline_size {
        @types.Auto
        // If height is %, keep width Auto to let aspect_ratio compute it
      } else if height_is_percent {
        @types.Auto
      } else {
        @types.Auto
      }
    } else {
      style.width
    }
    let resolved_height : @types.Dimension = if style.height == @types.Auto {
      if suppress_auto_block_size {
        @types.Auto
        // If width is %, keep height Auto to let aspect_ratio compute it
      } else if width_is_percent {
        @types.Auto
      } else {
        @types.Auto
      }
    } else {
      style.height
    }
    let keep_intrinsic_ratio = should_apply_intrinsic_replaced_aspect_ratio(
      resolved_width, resolved_height,
    )
    let canvas_style : @style.Style = {
      ..style,
      width: resolved_width,
      height: resolved_height,
      // Set aspect ratio from intrinsic dimensions (for % sizing)
      aspect_ratio: match style.aspect_ratio {
        Some(_) => style.aspect_ratio // Keep CSS-specified ratio
        None =>
          if style.contain.size || !keep_intrinsic_ratio {
            None
          } else {
            intrinsic_aspect_ratio
          }
      },
    }

    // Always use MeasureFunc to provide intrinsic size
    // The layout algorithm will use CSS dimensions if specified
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, canvas_style, measure)
  }

  // Handle iframe/object/embed as replaced elements with default intrinsic sizing
  if (tag_lower == "iframe" || tag_lower == "object" || tag_lower == "embed") &&
    children.is_empty() {
    if tag_lower == "embed" {
      let has_src = match elem.attributes.get("src") {
        Some(src) => src.trim().length() > 0
        None => false
      }
      if !has_src {
        return @node.Node::leaf(node_id, {
          ..style,
          display: @types.Display::None,
        })
      }
    }
    // HTML replaced elements default intrinsic size is 300x150
    let default_width = 300.0
    let default_height = 150.0
    let intrinsic_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(default_width)
      None => default_width
    }
    let intrinsic_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(default_height)
      None => default_height
    }
    let intrinsic_aspect_ratio = if intrinsic_height > 0.0 {
      Some(intrinsic_width / intrinsic_height)
    } else {
      None
    }
    let height_is_percent = match style.height {
      @types.Percent(_) => true
      _ => false
    }
    let width_is_percent = match style.width {
      @types.Percent(_) => true
      _ => false
    }
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    let resolved_width : @types.Dimension = if style.width == @types.Auto {
      if suppress_auto_inline_size {
        @types.Auto
      } else if height_is_percent {
        @types.Auto
      } else {
        @types.Length(intrinsic_width)
      }
    } else {
      style.width
    }
    let resolved_height : @types.Dimension = if style.height == @types.Auto {
      if suppress_auto_block_size {
        @types.Auto
      } else if width_is_percent {
        @types.Auto
      } else {
        @types.Length(intrinsic_height)
      }
    } else {
      style.height
    }
    let keep_intrinsic_ratio = should_apply_intrinsic_replaced_aspect_ratio(
      resolved_width, resolved_height,
    )
    let replaced_style : @style.Style = {
      ..style,
      width: resolved_width,
      height: resolved_height,
      aspect_ratio: match style.aspect_ratio {
        Some(_) => style.aspect_ratio
        None =>
          if style.contain.size || !keep_intrinsic_ratio {
            None
          } else {
            intrinsic_aspect_ratio
          }
      },
    }
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, replaced_style, measure)
  }

  // Handle video/audio as replaced elements with fallback intrinsic size.
  // These fallback sizes should not imply a concrete intrinsic aspect ratio,
  // and source/track/fallback descendants do not affect the outer replaced box.
  if tag_lower == "video" || tag_lower == "audio" {
    let default_width = 300.0
    let default_height = 150.0
    let intrinsic_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(default_width)
      None => default_width
    }
    let intrinsic_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(default_height)
      None => default_height
    }
    let height_is_percent = match style.height {
      @types.Percent(_) => true
      _ => false
    }
    let width_is_percent = match style.width {
      @types.Percent(_) => true
      _ => false
    }
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    let media_style : @style.Style = {
      ..style,
      width: if style.width == @types.Auto {
        if suppress_auto_inline_size {
          @types.Auto
        } else if height_is_percent {
          @types.Auto
        } else {
          @types.Length(intrinsic_width)
        }
      } else {
        style.width
      },
      height: if style.height == @types.Auto {
        if suppress_auto_block_size {
          @types.Auto
        } else if width_is_percent {
          @types.Auto
        } else {
          @types.Length(intrinsic_height)
        }
      } else {
        style.height
      },
      aspect_ratio: match style.aspect_ratio {
        Some(_) => style.aspect_ratio
        None => None
      },
    }
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, media_style, measure)
  }

  // Handle br element with line-height for height
  if tag_lower == "br" {
    // br elements have zero width but take up line-height vertically
    // line_height is already computed as absolute pixel value
    let measure = create_br_measure(
      style.line_height,
      style.font_size,
      style.writing_mode,
    )
    return @node.Node::with_measure(node_id, style, measure)
  }
  if children.is_empty() {
    @node.Node::leaf(node_id, style)
  } else {
    @node.Node::new(node_id, style, children)
  }
}

///|
/// Convert HTML Element to Selector Element
fn html_to_selector_element(
  elem : @html.Element,
  parent : @css.Element?,
) -> @css.Element {
  let mut sel_elem = @css.Element::new(elem.tag)

  // Set ID
  match elem.id {
    Some(id) => sel_elem = sel_elem.set_id(id)
    None => ()
  }

  // Set classes
  for cls in elem.classes {
    sel_elem = sel_elem.add_class(cls)
  }

  // Set attributes
  elem.attributes.each(fn(name, value) {
    sel_elem = sel_elem.set_attribute(name, value)
  })

  // Set parent
  match parent {
    Some(p) => sel_elem = sel_elem.set_parent(p)
    None => ()
  }
  sel_elem
}

///|
fn html_to_selector_element_minimal(
  elem : @html.Element,
  parent : @css.Element?,
) -> @css.Element {
  let mut sel_elem = @css.Element::new(elem.tag)
  match elem.id {
    Some(id) => sel_elem = sel_elem.set_id(id)
    None => ()
  }
  for cls in elem.classes {
    sel_elem = sel_elem.add_class(cls)
  }
  // Copy presentational HTML attributes needed for UA styling
  elem.attributes.each(fn(name, value) {
    sel_elem = sel_elem.set_attribute(name, value)
  })
  match parent {
    Some(p) => sel_elem = sel_elem.set_parent(p)
    None => ()
  }
  sel_elem
}

///|
/// Convert HTML Element to Selector Element with parent and sibling info
fn html_to_selector_element_with_parent(
  elem : @html.Element,
  parent : @css.Element,
  sibling_index : Int,
  sibling_count : Int,
  prev_sibling : @css.Element?,
) -> @css.Element {
  let mut sel_elem = @css.Element::new(elem.tag)

  // Set ID
  match elem.id {
    Some(id) => sel_elem = sel_elem.set_id(id)
    None => ()
  }

  // Set classes
  for cls in elem.classes {
    sel_elem = sel_elem.add_class(cls)
  }

  // Set attributes
  elem.attributes.each(fn(name, value) {
    sel_elem = sel_elem.set_attribute(name, value)
  })

  // Set parent and sibling info
  sel_elem = sel_elem.set_parent(parent)
  sel_elem = sel_elem.set_sibling_info(sibling_index, sibling_count)
  sel_elem = { ..sel_elem, prev_sibling, }
  sel_elem
}

///|
/// Check if a tag name is a table-related element
fn is_table_element(tag : String) -> Bool {
  match tag.to_lower() {
    "table"
    | "tr"
    | "td"
    | "th"
    | "thead"
    | "tbody"
    | "tfoot"
    | "caption"
    | "colgroup"
    | "col" => true
    _ => false
  }
}

///|
/// Check if a display value is table-related
fn is_table_display(display : @types.Display) -> Bool {
  match display {
    @types.Table
    | @types.InlineTable
    | @types.TableRow
    | @types.TableCell
    | @types.TableCaption
    | @types.TableRowGroup
    | @types.TableHeaderGroup
    | @types.TableFooterGroup
    | @types.TableColumn
    | @types.TableColumnGroup => true
    _ => false
  }
}

///|
fn is_no_principal_table_internal_display(display : @types.Display) -> Bool {
  match display {
    @types.TableRow
    | @types.TableRowGroup
    | @types.TableHeaderGroup
    | @types.TableFooterGroup
    | @types.TableColumn
    | @types.TableColumnGroup => true
    _ => false
  }
}

///|
/// Helper to resolve a dimension to pixels (for padding/border calculation)
fn resolve_dimension_to_px(dim : @types.Dimension) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(_) => 0.0 // Percentages are resolved later
    @types.Auto => 0.0
    @types.MinContent => 0.0 // Intrinsic sizing resolved during layout
    @types.MaxContent => 0.0
    @types.FitContent(_) => 0.0
  }
}

///|
fn resolve_dimension_with_percent_basis(
  dim : @types.Dimension,
  percent_basis : Double,
) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(p) =>
      if percent_basis > 0.0 {
        percent_basis * p
      } else {
        0.0
      }
    @types.Auto => 0.0
    @types.MinContent => 0.0
    @types.MaxContent => 0.0
    @types.FitContent(_) => 0.0
  }
}

///|
fn is_zero_dimension_value(dim : @types.Dimension) -> Bool {
  match dim {
    @types.Length(v) => v == 0.0
    @types.Percent(v) => v == 0.0
    _ => false
  }
}

///|
fn has_zero_box_offsets(style : @style.Style) -> Bool {
  is_zero_dimension_value(style.padding.left) &&
  is_zero_dimension_value(style.padding.right) &&
  is_zero_dimension_value(style.padding.top) &&
  is_zero_dimension_value(style.padding.bottom) &&
  is_zero_dimension_value(style.border.left) &&
  is_zero_dimension_value(style.border.right) &&
  is_zero_dimension_value(style.border.top) &&
  is_zero_dimension_value(style.border.bottom)
}

///|
/// Adjust dimensions for box-sizing: content-box
/// When box-sizing is content-box (default), specified width/height are content dimensions.
/// The layout engine expects outer dimensions (border-box), so we adjust here.
fn adjust_for_box_sizing(style : @style.Style) -> @style.Style {
  match style.box_sizing {
    @types.BorderBox => {
      let padding_h = resolve_dimension_to_px(style.padding.left) +
        resolve_dimension_to_px(style.padding.right)
      let padding_v = resolve_dimension_to_px(style.padding.top) +
        resolve_dimension_to_px(style.padding.bottom)
      let border_h = resolve_dimension_to_px(style.border.left) +
        resolve_dimension_to_px(style.border.right)
      let border_v = resolve_dimension_to_px(style.border.top) +
        resolve_dimension_to_px(style.border.bottom)
      let min_outer_width = padding_h + border_h
      let min_outer_height = padding_v + border_v

      let clamped_width = match style.width {
        @types.Length(w) =>
          @types.Dimension::Length(
            if w < min_outer_width {
              min_outer_width
            } else {
              w
            },
          )
        other => other
      }
      let clamped_height = match style.height {
        @types.Length(h) =>
          @types.Dimension::Length(
            if h < min_outer_height {
              min_outer_height
            } else {
              h
            },
          )
        other => other
      }
      let clamped_min_width = match style.min_width {
        @types.Length(w) =>
          @types.Dimension::Length(
            if w < min_outer_width {
              min_outer_width
            } else {
              w
            },
          )
        other => other
      }
      let clamped_min_height = match style.min_height {
        @types.Length(h) =>
          @types.Dimension::Length(
            if h < min_outer_height {
              min_outer_height
            } else {
              h
            },
          )
        other => other
      }
      let clamped_max_width = match style.max_width {
        @types.Length(w) =>
          @types.Dimension::Length(
            if w < min_outer_width {
              min_outer_width
            } else {
              w
            },
          )
        other => other
      }
      let clamped_max_height = match style.max_height {
        @types.Length(h) =>
          @types.Dimension::Length(
            if h < min_outer_height {
              min_outer_height
            } else {
              h
            },
          )
        other => other
      }

      {
        ..style,
        width: clamped_width,
        height: clamped_height,
        min_width: clamped_min_width,
        min_height: clamped_min_height,
        max_width: clamped_max_width,
        max_height: clamped_max_height,
      }
    }
    @types.ContentBox => {
      if has_zero_box_offsets(style) {
        return { ..style, box_sizing: @types.BorderBox }
      }
      let percent_basis = match style.width {
        @types.Length(w) =>
          if w > 0.0 {
            w +
            resolve_dimension_to_px(style.padding.left) +
            resolve_dimension_to_px(style.padding.right) +
            resolve_dimension_to_px(style.border.left) +
            resolve_dimension_to_px(style.border.right)
          } else {
            0.0
          }
        _ => 0.0
      }
      // Calculate padding and border sums
      let padding_h = resolve_dimension_with_percent_basis(
          style.padding.left,
          percent_basis,
        ) +
        resolve_dimension_with_percent_basis(style.padding.right, percent_basis)
      let padding_v = resolve_dimension_with_percent_basis(
          style.padding.top,
          percent_basis,
        ) +
        resolve_dimension_with_percent_basis(
          style.padding.bottom,
          percent_basis,
        )
      let border_h = resolve_dimension_with_percent_basis(
          style.border.left,
          percent_basis,
        ) +
        resolve_dimension_with_percent_basis(style.border.right, percent_basis)
      let border_v = resolve_dimension_with_percent_basis(
          style.border.top,
          percent_basis,
        ) +
        resolve_dimension_with_percent_basis(style.border.bottom, percent_basis)

      // Adjust width and height to include padding+border
      let adjusted_width = match style.width {
        @types.Length(w) => @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_height = match style.height {
        @types.Length(h) => @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      // Adjust min/max constraints too
      let adjusted_min_width = match style.min_width {
        @types.Length(w) => @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_min_height = match style.min_height {
        @types.Length(h) => @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      let adjusted_max_width = match style.max_width {
        @types.Length(w) => @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_max_height = match style.max_height {
        @types.Length(h) => @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      {
        ..style,
        width: adjusted_width,
        height: adjusted_height,
        min_width: adjusted_min_width,
        min_height: adjusted_min_height,
        max_width: adjusted_max_width,
        max_height: adjusted_max_height,
        // Mark as adjusted (now using border-box semantics internally)
        box_sizing: @types.BorderBox,
      }
    }
  }
}

///|
/// Get content height with external CSS
pub fn get_content_height_with_css(
  html : String,
  width : Int,
  height : Int,
  external_css : Array[String],
) -> Int {
  let ctx : RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = render_with_external_css(html, ctx, external_css)
  layout.height.to_int()
}

///|
/// Get content height from HTML
pub fn get_content_height(html : String, width : Int, height : Int) -> Int {
  let ctx : RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = render(html, ctx)
  layout.height.to_int()
}

///|
/// Calculate the actual content extent (maximum y + height of all elements)
/// This handles cases where parent has height: 100% but children extend beyond
fn calculate_content_extent(layout : @types.Layout) -> Double {
  // Start with this element's bottom edge
  let mut max_extent = layout.y + layout.height
  // Check all children recursively
  for child in layout.children {
    let child_extent = calculate_content_extent(child)
    if child_extent > max_extent {
      max_extent = child_extent
    }
  }
  max_extent
}

///|
/// Get content height from a parsed Document with external CSS
pub fn get_content_height_with_document(
  doc : @html.Document,
  width : Int,
  height : Int,
  external_css : Array[String],
) -> Int {
  let ctx : RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = render_document_with_external_css(doc, ctx, external_css)
  // Use actual content extent instead of just layout.height
  // This handles height: 100% on body where children extend beyond
  let content_extent = calculate_content_extent(layout)
  content_extent.to_int().max(layout.height.to_int())
}

///|
/// Print layout tree for debugging
pub fn print_layout_tree(layout : @types.Layout, indent : Int) -> Unit {
  print_layout_tree_with_options(layout, indent, false)
}

///|
/// Print layout tree with optional detailed box model info
pub fn print_layout_tree_with_options(
  layout : @types.Layout,
  indent : Int,
  show_box_model : Bool,
) -> Unit {
  let prefix = "  ".repeat(indent)
  let basic_info = prefix +
    layout.id +
    " (" +
    layout.x.to_string() +
    ", " +
    layout.y.to_string() +
    ") " +
    layout.width.to_string() +
    "x" +
    layout.height.to_string()
  if show_box_model {
    let m = layout.margin
    let p = layout.padding
    let b = layout.border
    let margin_info = if m.top != 0.0 ||
      m.right != 0.0 ||
      m.bottom != 0.0 ||
      m.left != 0.0 {
      " m[" +
      m.top.to_string() +
      "," +
      m.right.to_string() +
      "," +
      m.bottom.to_string() +
      "," +
      m.left.to_string() +
      "]"
    } else {
      ""
    }
    let padding_info = if p.top != 0.0 ||
      p.right != 0.0 ||
      p.bottom != 0.0 ||
      p.left != 0.0 {
      " p[" +
      p.top.to_string() +
      "," +
      p.right.to_string() +
      "," +
      p.bottom.to_string() +
      "," +
      p.left.to_string() +
      "]"
    } else {
      ""
    }
    let border_info = if b.top != 0.0 ||
      b.right != 0.0 ||
      b.bottom != 0.0 ||
      b.left != 0.0 {
      " b[" +
      b.top.to_string() +
      "," +
      b.right.to_string() +
      "," +
      b.bottom.to_string() +
      "," +
      b.left.to_string() +
      "]"
    } else {
      ""
    }
    println(basic_info + margin_info + padding_info + border_info)
  } else {
    println(basic_info)
  }
  for child in layout.children {
    print_layout_tree_with_options(child, indent + 1, show_box_model)
  }
}
