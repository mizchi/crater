///|
// Nested element node construction with pre-computed selector context.

///|
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
  let below_viewport = should_use_viewport_skeleton()
  if below_viewport {
    return build_viewport_skeleton_node(
      elem, selector_elem, ctx, stylesheets, indexed_stylesheets, parent_style, css_vars,
      incoming_counters, owner_id,
    )
  }
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
