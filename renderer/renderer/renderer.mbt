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
  finalize_special_element_node(elem, tag_lower, style, children)
}
