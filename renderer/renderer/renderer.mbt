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
  let (own_counters, before_pseudo, after_pseudo, style) = resolve_element_counter_pseudos(
    incoming_counters,
    selector_elem,
    style,
    stylesheets,
    ctx,
    owner_id,
    below_viewport,
    element_css_vars,
    elem.attributes,
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
  let tag_lower = elem.tag.to_lower()
  let computed_style = apply_element_visibility_attributes(
    computed_style,
    elem.attributes,
    tag_lower,
  )
  if computed_style.display == @types.Display::None {
    return @node.Node::leaf(make_node_id(elem), computed_style)
  }
  if should_advance_viewport_estimate(computed_style) {
    viewport_estimated_y.val += computed_style.line_height
  }
  let style = adjust_nested_element_style(
    elem, selector_elem, tag_lower, computed_style, stylesheets, indexed_stylesheets,
    ctx, css_vars,
  )

  let element_css_vars = compute_element_css_vars_indexed(
    selector_elem,
    elem.style,
    indexed_stylesheets,
    ctx,
    css_vars,
  )
  let (own_counters, before_pseudo, after_pseudo, style) = resolve_element_counter_pseudos(
    incoming_counters,
    selector_elem,
    style,
    stylesheets,
    ctx,
    owner_id,
    below_viewport,
    element_css_vars,
    elem.attributes,
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
