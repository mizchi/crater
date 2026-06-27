///|
// Root element node construction with full document-level selector context.

///|
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

  let computed_style = compute_element_style_indexed(
    selector_elem,
    elem.style,
    effective_sheets,
    parent is None,
    ctx,
    None,
    css_vars,
  )
  viewport_full_node_count.val += 1

  let tag_lower = elem.tag.to_lower()
  let parent_is_svg = selector_parent_is_svg(selector_elem)
  let computed_style = normalize_svg_display_contents(
    tag_lower, computed_style, parent_is_svg,
  )
  let style = apply_table_attributes(elem, tag_lower, computed_style)
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
    elem, selector_elem, tag_lower, style, ctx, stylesheets, indexed_stylesheets,
    element_css_vars, own_counters, owner_id, before_pseudo, after_pseudo,
  )

  let node_id = make_node_id(elem)
  let node = if children.is_empty() {
    @node.Node::leaf(node_id, style)
  } else {
    @node.Node::new(node_id, style, children)
  }
  attach_dom_id(node, elem)
}
