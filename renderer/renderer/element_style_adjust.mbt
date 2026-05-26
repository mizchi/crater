///|
// Element-specific style adjustments used by nested render paths.

///|
fn apply_element_visibility_attributes(
  style : @style.Style,
  attributes : Map[String, String],
  tag_lower : String,
) -> @style.Style {
  if attributes.contains("hidden") {
    style.display = @types.Display::None
  }
  if tag_lower == "dialog" && !attributes.contains("open") {
    style.display = @types.Display::None
  }
  style
}

///|
fn is_ruby_internal_tag(tag_lower : String) -> Bool {
  tag_lower == "ruby" ||
  tag_lower == "rb" ||
  tag_lower == "rbc" ||
  tag_lower == "rt" ||
  tag_lower == "rtc" ||
  tag_lower == "rp"
}

///|
fn clear_inline_containment_for_normal_inline(
  style : @style.Style,
  tag_lower : String,
) -> @style.Style {
  let preserve_inline_contain = tag_lower == "rt"
  if style.display == @types.Inline &&
    !preserve_inline_contain &&
    !is_replaced_element(tag_lower) &&
    (
      style.contain.layout ||
      style.contain.paint ||
      style.contain.size ||
      style.contain.inline_size
    ) {
    {
      ..style,
      contain: {
        ..style.contain,
        layout: false,
        paint: false,
        size: false,
        inline_size: false,
      },
    }
  } else {
    style
  }
}

///|
fn inline_style_has_block_child_for_adjustment(
  elem : @html.Element,
  selector_elem : @css.Element,
  style : @style.Style,
  tag_lower : String,
  stylesheets : Array[@css.Stylesheet],
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  ctx : RenderContext,
  css_vars : Map[String, String],
) -> Bool {
  // SVG root participates in HTML inline flow as a replaced inline-block
  // element. Its children (rect, circle, path, …) are SVG-internal
  // primitives, not HTML block-level boxes, so the generic
  // "inline-with-block-child becomes block" rule does not apply. Without
  // this guard, `<h1><svg><rect/></svg>Dashboard</h1>` flips the svg to
  // display:block and forces the trailing text onto a new line, breaking
  // inline replaced semantics (paint-vrt svg-intrinsic-inline-replaced).
  if tag_lower == "svg" {
    return false
  }
  style.display == @types.Inline &&
  !is_ruby_internal_tag(tag_lower) &&
  style.position == @types.Static &&
  contains_block_child(elem, stylesheets, ctx) &&
  !(has_direct_display_contents_child(
    elem, selector_elem, style, indexed_stylesheets, ctx, css_vars,
  ) ||
  has_direct_contents_class_child(elem))
}

///|
fn adjust_inline_element_display_for_children(
  elem : @html.Element,
  selector_elem : @css.Element,
  style : @style.Style,
  tag_lower : String,
  stylesheets : Array[@css.Stylesheet],
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  ctx : RenderContext,
  css_vars : Map[String, String],
) -> @style.Style {
  if inline_style_has_block_child_for_adjustment(
      elem, selector_elem, style, tag_lower, stylesheets, indexed_stylesheets, ctx,
      css_vars,
    ) {
    { ..style, display: @types.Block }
  } else if style.display == @types.Inline &&
    tag_lower != "picture" &&
    contains_replaced_element(elem) {
    { ..style, display: @types.InlineBlock }
  } else {
    style
  }
}

///|
fn adjust_nested_element_style(
  elem : @html.Element,
  selector_elem : @css.Element,
  tag_lower : String,
  computed_style : @style.Style,
  stylesheets : Array[@css.Stylesheet],
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  ctx : RenderContext,
  css_vars : Map[String, String],
) -> @style.Style {
  let style = clear_inline_containment_for_normal_inline(
    computed_style, tag_lower,
  )
  let parent_is_svg = selector_parent_is_svg(selector_elem)
  let style = normalize_svg_display_contents(tag_lower, style, parent_is_svg)
  let style = adjust_inline_element_display_for_children(
    elem, selector_elem, style, tag_lower, stylesheets, indexed_stylesheets, ctx,
    css_vars,
  )
  let style = apply_table_attributes(elem, tag_lower, style)
  let style = if is_svg_element(tag_lower) {
    apply_svg_attributes_to_style(style, elem.attributes, tag_lower)
  } else {
    style
  }
  apply_svg_intrinsic_size(style, tag_lower)
}
