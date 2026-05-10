///|
// Styled child node construction shared by root and nested element rendering.

///|
fn build_styled_element_children(
  elem : @html.Element,
  selector_elem : @css.Element,
  tag_lower : String,
  style : @style.Style,
  ctx : RenderContext,
  stylesheets : Array[@css.Stylesheet],
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  element_css_vars : Map[String, String],
  own_counters : Map[String, CounterEntry],
  owner_id : String,
  before_pseudo : AfterPseudoSpec?,
  after_pseudo : AfterPseudoSpec?,
) -> Array[@node.Node] {
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

  if !inline_text.trim().is_empty() {
    children.push(create_text_node(inline_text, style))
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

  for i, child in remaining_children {
    match child {
      @html.Node::Element(child_elem) => {
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
          children.push(create_text_node(normalized_text, text_parent_style))
        }
    }
  }
  match after_pseudo {
    Some(spec) => children.push(create_generated_pseudo_node(spec, After))
    None => ()
  }
  children
}
