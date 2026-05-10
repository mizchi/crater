///|
/// HTML/CSS Renderer
/// Converts HTML elements with inline styles to layout

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
  let style = apply_table_attributes(elem, cell_tag, computed_style)
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
  let style = apply_generated_pseudo_host_style_offsets(
    style, before_pseudo, after_pseudo,
  )

  let children = build_styled_element_children(
    elem, selector_elem, cell_tag, style, ctx, stylesheets, indexed_stylesheets,
    element_css_vars, own_counters, owner_id, before_pseudo, after_pseudo,
  )

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
    return build_viewport_skeleton_node(
      elem, selector_elem, ctx, stylesheets, indexed_stylesheets, parent_style, css_vars,
      incoming_counters, owner_id,
    )
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

  let cell_tag = tag_lower
  let style = apply_table_attributes(elem, cell_tag, style)

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
  let style = apply_generated_pseudo_host_style_offsets(
    style, before_pseudo, after_pseudo,
  )
  let children = build_styled_element_children(
    elem, selector_elem, tag_lower, style, ctx, stylesheets, indexed_stylesheets,
    element_css_vars, own_counters, owner_id, before_pseudo, after_pseudo,
  )

  let children = if tag_lower == "details" && !elem.attributes.contains("open") {
    prune_closed_details_children(children)
  } else {
    children
  }
  finalize_special_element_node(elem, tag_lower, style, children)
}
