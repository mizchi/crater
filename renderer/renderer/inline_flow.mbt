///|
/// Inline formatting context helpers.

///|
/// Check if an element is an inline-level element by tag name
fn is_inline_element_by_tag(tag : String) -> Bool {
  // HTML inline elements - includes HTML5 semantic inline elements
  let inline_tags = [
    // Traditional inline elements
    "a", "abbr", "acronym", "b", "bdo", "big", "br", "cite", "code", "dfn", "em",
    "font", "i", "img", "input", "kbd", "label", "picture", "q", "s", "samp", "select",
    "video", "audio", "canvas", "svg", "iframe", "object", "embed", "small", "span",
    "strike", "strong", "sub", "sup", "textarea", "tt", "u", "var",
    // HTML5 semantic inline elements
     "time", "data", "mark", "bdi", "wbr", "ruby", "rb", "rbc", "rt", "rtc", "rp",
    "meter", "progress", "output", "ins", "del",
  ]
  inline_tags.contains(tag.to_lower())
}

///|
/// Check if an element has block display in its inline style
fn has_block_display_in_style(elem : @html.Element) -> Bool {
  match elem.style {
    Some(style_str) => {
      let style_lower = style_str.to_lower()
      if !(style_lower.contains("display:") || style_lower.contains("display :")) {
        return false
      }
      // Parse the inline style to check display property
      let parsed = @css.parse_inline_style(style_str)
      match parsed.display {
        @types.Block | @types.Flex | @types.Grid => true
        _ => false
      }
    }
    None => false
  }
}

///|
/// Check if element has a class that indicates it's visually hidden (accessibility pattern)
fn is_visually_hidden_class(elem : @html.Element) -> Bool {
  // Common accessibility hiding class names
  let hidden_classes = [
    "mw-jump-link", // MediaWiki/Wikipedia
     "visually-hidden", // Bootstrap
     "sr-only", // Screen reader only (Bootstrap)
     "screen-reader-text", // WordPress
     "skip-link", // Skip navigation links
     "skip-to-content",
  ]
  for cls in elem.classes {
    let cls_lower = cls.to_lower()
    for hidden in hidden_classes {
      if cls_lower.contains(hidden) {
        return true
      }
    }
  }
  false
}

///|
/// Check if an element should be treated as inline
fn is_inline_element(elem : @html.Element) -> Bool {
  // If element has block display in inline style, treat as block
  if has_block_display_in_style(elem) {
    return false
  }
  // WORKAROUND: Skip visually hidden accessibility elements
  // These typically have display:block from external CSS but we detect them by class
  if is_visually_hidden_class(elem) {
    return false
  }
  // Otherwise, check tag name
  is_inline_element_by_tag(elem.tag)
}

///|
/// Check if an element will have non-inline display (inline-block, block, flex, etc.) based on CSS rules
/// This is used to prevent text merging for elements that might be styled differently
fn will_have_non_inline_display(
  elem : @html.Element,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  // Check inline style first
  match elem.style {
    Some(style) => {
      let style_lower = style.to_lower()
      if style_lower.contains("display:") || style_lower.contains("display :") {
        // Has display in inline style - check if it's non-inline
        if style_lower.contains("inline-block") ||
          style_lower.contains("block") ||
          style_lower.contains("flex") ||
          style_lower.contains("grid") {
          return true
        }
      }
    }
    None => ()
  }
  // Check CSS stylesheets for matching rules
  if stylesheets.length() > 0 {
    // Create selector element for CSS matching
    let mut selector_elem = @css.Element::new(elem.tag.to_lower())
    match elem.id {
      Some(id) => selector_elem = selector_elem.set_id(id)
      None => ()
    }
    for cls in elem.classes {
      selector_elem = selector_elem.add_class(cls)
    }
    for attr in elem.attributes {
      let (name, value) = attr
      selector_elem = selector_elem.set_attribute(name, value)
    }
    let media_env = @css.MediaEnvironment::with_color_scheme(
      ctx.viewport_width,
      ctx.viewport_height,
      ctx.color_scheme,
    )
    let cascaded = @css.cascade_element_with_media(
      selector_elem,
      stylesheets,
      [],
      Some(media_env),
    )
    // Check if display property is set to non-inline value
    match cascaded.get_value("display") {
      Some(value) => {
        let value_lower = value.to_lower()
        // inline-block, block, flex, grid, etc. should not be merged
        if value_lower.contains("inline-block") ||
          (value_lower.contains("block") && !value_lower.contains("inline")) ||
          value_lower.contains("flex") ||
          value_lower.contains("grid") {
          return true
        }
      }
      None => ()
    }
  }
  false
}

///|
fn is_inline_participating_display(display : @types.Display) -> Bool {
  match display {
    @types.Inline
    | @types.InlineBlock
    | @types.InlineFlex
    | @types.InlineGrid
    | @types.InlineTable
    | @types.Contents => true
    _ => false
  }
}

///|
fn string_map_is_empty(map : Map[String, String]) -> Bool {
  for _k, _v in map {
    return false
  }
  true
}

///|
fn has_default_inherited_inline_context(parent_style : @style.Style?) -> Bool {
  match parent_style {
    None => true
    Some(ps) =>
      ps.color == @types.Color::black() &&
      ps.font_size == 16.0 &&
      ps.line_height == 16.0 &&
      ps.white_space == @style.WhiteSpace::Normal &&
      ps.writing_mode == @style.WritingMode::HorizontalTb &&
      ps.direction == @style.Direction::Ltr &&
      ps.pointer_events == @style.PointerEvents::Auto
  }
}

///|
fn make_inline_only_style_cache_variant_key(
  tag : String,
  is_root : Bool,
  viewport_width : Double,
  viewport_height : Double,
) -> String {
  @renderer_style.make_inline_only_style_cache_variant_key(
    tag, is_root, viewport_width, viewport_height,
  )
}

///|
fn parse_inline_declarations_cached(
  inline_css : String,
) -> Array[(String, String)] {
  @renderer_style.parse_inline_declarations_cached(inline_css)
}

///|
fn get_cached_inline_style_display(style_str : String) -> @types.Display? {
  @renderer_style.get_cached_inline_style_display(style_str)
}

///|
fn get_inline_style_display(elem : @html.Element) -> @types.Display? {
  match elem.style {
    Some(style_str) => get_cached_inline_style_display(style_str)
    None => None
  }
}

///|
fn inline_css_establishes_effect_containing_block(inline_css : String) -> Bool {
  let declarations = parse_inline_declarations_cached(inline_css)
  for i = 0; i < declarations.length(); i = i + 1 {
    let (prop, value) = declarations[i]
    if prop == "filter" || prop == "backdrop-filter" {
      if value.to_lower().trim() != "none" {
        return true
      }
    }
  }
  false
}

///|
/// Check if an element participates in inline formatting context in the current style cascade.
fn has_inline_participating_display(
  elem : @html.Element,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  match get_inline_style_display(elem) {
    Some(display) => return is_inline_participating_display(display)
    None => ()
  }
  if stylesheets.length() > 0 {
    let mut selector_elem = @css.Element::new(elem.tag.to_lower())
    match elem.id {
      Some(id) => selector_elem = selector_elem.set_id(id)
      None => ()
    }
    for cls in elem.classes {
      selector_elem = selector_elem.add_class(cls)
    }
    for attr in elem.attributes {
      let (name, value) = attr
      selector_elem = selector_elem.set_attribute(name, value)
    }
    let media_env = @css.MediaEnvironment::with_color_scheme(
      ctx.viewport_width,
      ctx.viewport_height,
      ctx.color_scheme,
    )
    let cascaded = @css.cascade_element_with_media(
      selector_elem,
      stylesheets,
      [],
      Some(media_env),
    )
    match cascaded.get_value("display") {
      Some(value) => {
        let value_lower = value.to_lower().trim()
        if value_lower == "contents" || value_lower.has_prefix("inline") {
          return true
        }
        return false
      }
      None => ()
    }
  }
  is_inline_element(elem)
}

///|
fn is_whitespace_only_text(text : String) -> Bool {
  if text.is_empty() {
    return false
  }
  for c in text.iter() {
    if !is_collapsible_whitespace_char(c) {
      return false
    }
  }
  true
}

///|
fn is_collapsible_whitespace_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn trim_collapsible_whitespace_edges(text : String) -> String {
  let chars : Array[Char] = []
  for c in text.iter() {
    chars.push(c)
  }
  let mut start = 0
  while start < chars.length() && is_collapsible_whitespace_char(chars[start]) {
    start = start + 1
  }
  let mut end = chars.length()
  while end > start && is_collapsible_whitespace_char(chars[end - 1]) {
    end = end - 1
  }
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn has_line_break_char(text : String) -> Bool {
  for c in text.iter() {
    if c == '\n' || c == '\r' {
      return true
    }
  }
  false
}

///|
fn trim_trailing_collapsible_whitespace(text : String) -> String {
  let chars : Array[Char] = []
  for c in text.iter() {
    chars.push(c)
  }
  while !chars.is_empty() {
    let last = chars[chars.length() - 1]
    if is_collapsible_whitespace_char(last) {
      let _ = chars.pop()
    } else {
      break
    }
  }
  let buf = StringBuilder::new()
  for c in chars {
    buf.write_char(c)
  }
  buf.to_string()
}

///|
fn trim_leading_collapsible_whitespace(text : String) -> String {
  let chars : Array[Char] = []
  for c in text.iter() {
    chars.push(c)
  }
  let mut start = 0
  while start < chars.length() && is_collapsible_whitespace_char(chars[start]) {
    start = start + 1
  }
  let buf = StringBuilder::new()
  for i = start; i < chars.length(); i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn sibling_participates_inline_flow(
  siblings : Array[@html.Node],
  sibling_index : Int,
  parent_selector : @css.Element,
  parent_style : @style.Style,
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  ctx : RenderContext,
  css_vars : Map[String, String],
) -> Bool {
  match siblings[sibling_index] {
    @html.Node::Element(elem) => {
      if indexed_stylesheets.length() == 0 {
        if is_out_of_flow_positioned(elem, [], ctx) {
          return false
        }
        match get_inline_style_display(elem) {
          Some(display) => return is_inline_participating_display(display)
          None => return is_inline_element(elem)
        }
      }
      let selector_elem = html_to_selector_element_with_parent(
        elem,
        parent_selector,
        sibling_index + 1,
        siblings.length(),
        None,
      )
      let computed = compute_element_style_indexed(
        selector_elem,
        elem.style,
        indexed_stylesheets,
        false,
        ctx,
        Some(parent_style),
        css_vars,
      )
      if computed.position == @types.Absolute ||
        computed.position == @types.Fixed {
        return false
      }
      is_inline_participating_display(computed.display)
    }
    @html.Node::Text(text) => !is_whitespace_only_text(text)
  }
}

///|
fn trim_boundary_collapsible_whitespace_for_inline_context(
  siblings : Array[@html.Node],
  index : Int,
  parent_selector : @css.Element,
  parent_style : @style.Style,
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  ctx : RenderContext,
  css_vars : Map[String, String],
) -> String {
  let text = match siblings[index] {
    @html.Node::Text(t) => t
    _ => return ""
  }
  if text.is_empty() || is_whitespace_only_text(text) {
    return text
  }
  let prev_is_br = match index > 0 {
    true =>
      match siblings[index - 1] {
        @html.Node::Element(prev_elem) => prev_elem.tag.to_lower() == "br"
        _ => false
      }
    false => false
  }
  let next_is_br = match index < siblings.length() - 1 {
    true =>
      match siblings[index + 1] {
        @html.Node::Element(next_elem) => next_elem.tag.to_lower() == "br"
        _ => false
      }
    false => false
  }
  let keep_leading = index > 0 &&
    !prev_is_br &&
    sibling_participates_inline_flow(
      siblings,
      index - 1,
      parent_selector,
      parent_style,
      indexed_stylesheets,
      ctx,
      css_vars,
    )
  let keep_trailing = index < siblings.length() - 1 &&
    !next_is_br &&
    sibling_participates_inline_flow(
      siblings,
      index + 1,
      parent_selector,
      parent_style,
      indexed_stylesheets,
      ctx,
      css_vars,
    )
  let trimmed_leading = if keep_leading {
    text
  } else {
    trim_leading_collapsible_whitespace(text)
  }
  if keep_trailing {
    trimmed_leading
  } else {
    trim_trailing_collapsible_whitespace(trimmed_leading)
  }
}

///|
/// Keep collapsed whitespace text between inline-participating element siblings.
fn should_preserve_inter_element_whitespace(
  siblings : Array[@html.Node],
  index : Int,
  parent_selector : @css.Element,
  parent_style : @style.Style,
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  ctx : RenderContext,
  css_vars : Map[String, String],
) -> Bool {
  if index <= 0 || index >= siblings.length() - 1 {
    return false
  }
  let text = match siblings[index] {
    @html.Node::Text(t) => t
    _ => return false
  }
  if !is_whitespace_only_text(text) {
    return false
  }
  let prev_is_br = match siblings[index - 1] {
    @html.Node::Element(prev_elem) => prev_elem.tag.to_lower() == "br"
    _ => false
  }
  let next_is_br = match siblings[index + 1] {
    @html.Node::Element(next_elem) => next_elem.tag.to_lower() == "br"
    _ => false
  }
  if prev_is_br || next_is_br {
    return false
  }
  let prev_inline = sibling_participates_inline_flow(
    siblings,
    index - 1,
    parent_selector,
    parent_style,
    indexed_stylesheets,
    ctx,
    css_vars,
  )
  let next_inline = sibling_participates_inline_flow(
    siblings,
    index + 1,
    parent_selector,
    parent_style,
    indexed_stylesheets,
    ctx,
    css_vars,
  )
  prev_inline && next_inline
}

///|
/// Check if an element is styled with display: contents.
fn has_display_contents(
  elem : @html.Element,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  if is_display_contents_suppressed_html_element(elem.tag) {
    return false
  }
  match get_inline_style_display(elem) {
    Some(display) => if display == @types.Contents { return true }
    None => ()
  }
  if stylesheets.length() > 0 {
    let mut selector_elem = @css.Element::new(elem.tag.to_lower())
    match elem.id {
      Some(id) => selector_elem = selector_elem.set_id(id)
      None => ()
    }
    for cls in elem.classes {
      selector_elem = selector_elem.add_class(cls)
    }
    for attr in elem.attributes {
      let (name, value) = attr
      selector_elem = selector_elem.set_attribute(name, value)
    }
    let media_env = @css.MediaEnvironment::with_color_scheme(
      ctx.viewport_width,
      ctx.viewport_height,
      ctx.color_scheme,
    )
    let cascaded = @css.cascade_element_with_media(
      selector_elem,
      stylesheets,
      [],
      Some(media_env),
    )
    match cascaded.get_value("display") {
      Some(value) => if value.to_lower().trim() == "contents" { return true }
      None => ()
    }
  }
  false
}

///|
/// Check whether an inline element must be preserved as a node
/// (instead of being merged into surrounding text).
/// This is needed for containing-block / positioning behaviors.
fn should_preserve_inline_element(
  elem : @html.Element,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  let tag_lower = elem.tag.to_lower()
  match elem.id {
    Some(_) => return true
    None => ()
  }
  if elem.classes.length() > 0 {
    return true
  }
  if tag_lower == "ruby" ||
    tag_lower == "rb" ||
    tag_lower == "rbc" ||
    tag_lower == "rtc" ||
    tag_lower == "rt" ||
    tag_lower == "rp" {
    return true
  }
  let ua_style = get_ua_default_style(tag_lower)
  if ua_style.font_weight != 400.0 {
    return true
  }
  if ua_style.text_decoration_underline ||
    ua_style.text_decoration_line_through ||
    ua_style.text_decoration_overline {
    return true
  }

  // Check inline style first
  match elem.style {
    Some(style) => {
      let style_lower = style.to_lower()
      let has_position = style_lower.contains("position:")
      let is_static_position = style_lower.contains("position: static")
      if has_position && !is_static_position {
        return true
      }
      let has_filter = style_lower.contains("filter:")
      let filter_none = style_lower.contains("filter: none")
      if has_filter && !filter_none {
        return true
      }
      let has_transform = style_lower.contains("transform:")
      let transform_none = style_lower.contains("transform: none")
      if has_transform && !transform_none {
        return true
      }
      let has_perspective = style_lower.contains("perspective:")
      let perspective_none = style_lower.contains("perspective: none")
      if has_perspective && !perspective_none {
        return true
      }
      let has_contain = style_lower.contains("contain:") ||
        style_lower.contains("contain :")
      let contain_none = style_lower.contains("contain: none") ||
        style_lower.contains("contain : none")
      if has_contain && !contain_none {
        return true
      }
      let has_background = style_lower.contains("background:") ||
        style_lower.contains("background :") ||
        style_lower.contains("background-color:") ||
        style_lower.contains("background-color :")
      let transparent_background = style_lower.contains(
          "background: transparent",
        ) ||
        style_lower.contains("background : transparent") ||
        style_lower.contains("background-color: transparent") ||
        style_lower.contains("background-color : transparent")
      if has_background && !transparent_background {
        return true
      }
      let has_visibility = style_lower.contains("visibility:") ||
        style_lower.contains("visibility :")
      if has_visibility {
        return true
      }
      let has_display = style_lower.contains("display:") ||
        style_lower.contains("display :")
      if has_display && style_lower.contains("ruby") {
        return true
      }
      let has_text_decoration = style_lower.contains("text-decoration:") ||
        style_lower.contains("text-decoration :") ||
        style_lower.contains("text-decoration-line:") ||
        style_lower.contains("text-decoration-line :")
      let text_decoration_none = style_lower.contains("text-decoration: none") ||
        style_lower.contains("text-decoration : none") ||
        style_lower.contains("text-decoration-line: none") ||
        style_lower.contains("text-decoration-line : none")
      if has_text_decoration && !text_decoration_none {
        return true
      }
      let affects_inline_typography = style_lower.contains("font-size:") ||
        style_lower.contains("font-size :") ||
        style_lower.contains("font-weight:") ||
        style_lower.contains("font-weight :") ||
        style_lower.contains("font:") ||
        style_lower.contains("font :") ||
        style_lower.contains("line-height:") ||
        style_lower.contains("line-height :") ||
        style_lower.contains("vertical-align:") ||
        style_lower.contains("vertical-align :")
      if affects_inline_typography {
        return true
      }
    }
    None => ()
  }

  // Check stylesheet rules
  if stylesheets.length() > 0 {
    let mut selector_elem = @css.Element::new(elem.tag.to_lower())
    match elem.id {
      Some(id) => selector_elem = selector_elem.set_id(id)
      None => ()
    }
    for cls in elem.classes {
      selector_elem = selector_elem.add_class(cls)
    }
    for attr in elem.attributes {
      let (name, value) = attr
      selector_elem = selector_elem.set_attribute(name, value)
    }
    let media_env = @css.MediaEnvironment::with_color_scheme(
      ctx.viewport_width,
      ctx.viewport_height,
      ctx.color_scheme,
    )
    let cascaded = @css.cascade_element_with_media(
      selector_elem,
      stylesheets,
      [],
      Some(media_env),
    )
    match cascaded.get_value("position") {
      Some(value) => if value.to_lower().trim() != "static" { return true }
      None => ()
    }
    match cascaded.get_value("contain") {
      Some(value) => {
        let lowered = value.to_lower().trim()
        if lowered != "none" && lowered != "" {
          return true
        }
      }
      None => ()
    }
    match cascaded.get_value("background-color") {
      Some(value) => if has_nontrivial_background_value(value) { return true }
      None => ()
    }
    match cascaded.get_value("background") {
      Some(value) => if has_nontrivial_background_value(value) { return true }
      None => ()
    }
    match cascaded.get_value("visibility") {
      Some(_) => return true
      None => ()
    }
    match cascaded.get_value("display") {
      Some(value) => if value.to_lower().contains("ruby") { return true }
      None => ()
    }
    match cascaded.get_value("text-decoration") {
      Some(value) => {
        let lowered = value.to_lower().trim()
        if lowered != "" && lowered != "none" {
          return true
        }
      }
      None => ()
    }
    match cascaded.get_value("text-decoration-line") {
      Some(value) => {
        let lowered = value.to_lower().trim()
        if lowered != "" && lowered != "none" {
          return true
        }
      }
      None => ()
    }
    match cascaded.get_value("font-weight") {
      Some(_) => return true
      None => ()
    }
    match cascaded.get_value("font") {
      Some(_) => return true
      None => ()
    }
    match cascaded.get_value("filter") {
      Some(value) => if value.to_lower().trim() != "none" { return true }
      None => ()
    }
    match cascaded.get_value("backdrop-filter") {
      Some(value) => if value.to_lower().trim() != "none" { return true }
      None => ()
    }
    match cascaded.get_value("transform") {
      Some(value) => if value.to_lower().trim() != "none" { return true }
      None => ()
    }
    match cascaded.get_value("perspective") {
      Some(value) => {
        let lowered = value.to_lower().trim()
        if lowered != "none" && lowered != "0" && lowered != "0px" {
          return true
        }
      }
      None => ()
    }
  }
  false
}

///|
fn has_nontrivial_background_value(value : String) -> Bool {
  let lowered = value.to_lower().trim()
  lowered != "" &&
  lowered != "none" &&
  lowered != "transparent" &&
  lowered != "rgba(0,0,0,0)" &&
  lowered != "rgba(0, 0, 0, 0)"
}

///|
fn should_preserve_inline_children_for_text_overflow(
  style : @style.Style,
) -> Bool {
  style.text_overflow == @style.TextOverflow::Ellipsis &&
  style.white_space == @style.WhiteSpace::Nowrap &&
  (style.overflow_x != @types.Visible || style.overflow_y != @types.Visible)
}

///|
/// Check recursively whether an element contains any inline descendants
/// that should be preserved for layout semantics.
fn contains_preserved_inline_descendant(
  elem : @html.Element,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        if has_display_contents(child_elem, stylesheets, ctx) {
          return true
        }
        if should_preserve_inline_element(child_elem, stylesheets, ctx) {
          return true
        }
        if contains_preserved_inline_descendant(child_elem, stylesheets, ctx) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
/// Recursively collect text from inline elements
fn collect_text_from_inline(
  elem : @html.Element,
  buf : StringBuilder,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
) -> Unit {
  for child in elem.children {
    match child {
      @html.Node::Text(text) => buf.write_string(text)
      @html.Node::Element(child_elem) => {
        let tag_lower = child_elem.tag.to_lower()
        if tag_lower == "br" {
          buf.write_string("\n")
        } else if is_replaced_element(tag_lower) {
          // Skip replaced elements - they'll be handled separately
          continue
        } else if is_inline_element(child_elem) &&
          !will_have_non_inline_display(child_elem, stylesheets, ctx) &&
          !should_preserve_inline_element(child_elem, stylesheets, ctx) {
          // Recursively collect text from nested inline elements
          // Only if CSS doesn't override to non-inline display
          collect_text_from_inline(child_elem, buf, stylesheets, ctx)
        }
      }
    }
  }
}

///|
/// Check if element contains any replaced elements (img, input, etc.)
fn contains_replaced_element(elem : @html.Element) -> Bool {
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        if is_replaced_element(child_elem.tag.to_lower()) {
          return true
        }
        // Recursively check children
        if contains_replaced_element(child_elem) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
/// Check if element contains any block-level children (display: block, etc.)
/// This is used to detect inline elements like <code> that contain block children
fn contains_block_child(
  elem : @html.Element,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        let tag_lower = child_elem.tag.to_lower()
        // source/track/param are non-rendered by default and should not force
        // inline parents to become block containers.
        if tag_lower == "source" || tag_lower == "track" || tag_lower == "param" {
          continue
        }
        if should_skip_element(tag_lower) {
          continue
        }
        // Out-of-flow positioned descendants do not force inline parents to
        // become block containers.
        if is_out_of_flow_positioned(child_elem, stylesheets, ctx) {
          continue
        }
        // display: contents is a transparent wrapper and should not by itself
        // force inline parents to become block containers.
        if has_display_contents(child_elem, stylesheets, ctx) {
          if contains_block_child(child_elem, stylesheets, ctx) {
            return true
          }
          continue
        }
        // Check if child has non-inline display
        if will_have_non_inline_display(child_elem, stylesheets, ctx) {
          return true
        }
        // Also check if child is a block-level element by default
        if !is_inline_element(child_elem) && !is_replaced_element(tag_lower) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn has_direct_display_contents_child(
  elem : @html.Element,
  parent_selector : @css.Element,
  parent_style : @style.Style,
  indexed_stylesheets : Array[@css.IndexedStylesheet],
  ctx : RenderContext,
  css_vars : Map[String, String],
) -> Bool {
  let mut element_child_count = 0
  if indexed_stylesheets.length() > 0 {
    for child in elem.children {
      match child {
        @html.Node::Element(_) => element_child_count = element_child_count + 1
        _ => ()
      }
    }
  }
  let mut element_child_index = 0
  let mut prev_selector_sibling : @css.Element? = None
  let include_selector_match_data = indexed_stylesheets.length() > 0
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        element_child_index = element_child_index + 1
        let child_selector = if include_selector_match_data {
          html_to_selector_element_with_parent(
            child_elem, parent_selector, element_child_index, element_child_count,
            prev_selector_sibling,
          )
        } else {
          html_to_selector_element_minimal(child_elem, Some(parent_selector))
        }
        let child_style = compute_element_style_indexed(
          child_selector,
          child_elem.style,
          indexed_stylesheets,
          false,
          ctx,
          Some(parent_style),
          css_vars,
        )
        if include_selector_match_data {
          prev_selector_sibling = Some(child_selector)
        }
        if child_style.display == @types.Contents {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn has_direct_contents_class_child(elem : @html.Element) -> Bool {
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) =>
        for cls in child_elem.classes {
          if cls.to_lower() == "contents" {
            return true
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn is_out_of_flow_positioned(
  elem : @html.Element,
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  match elem.style {
    Some(style) => {
      let lowered = style.to_lower()
      if lowered.contains("position:absolute") ||
        lowered.contains("position: absolute") ||
        lowered.contains("position:fixed") ||
        lowered.contains("position: fixed") {
        return true
      }
    }
    None => ()
  }
  if stylesheets.length() == 0 {
    return false
  }
  let mut selector_elem = @css.Element::new(elem.tag.to_lower())
  match elem.id {
    Some(id) => selector_elem = selector_elem.set_id(id)
    None => ()
  }
  for cls in elem.classes {
    selector_elem = selector_elem.add_class(cls)
  }
  for attr in elem.attributes {
    let (name, value) = attr
    selector_elem = selector_elem.set_attribute(name, value)
  }
  let media_env = @css.MediaEnvironment::with_color_scheme(
    ctx.viewport_width,
    ctx.viewport_height,
    ctx.color_scheme,
  )
  let cascaded = @css.cascade_element_with_media(
    selector_elem,
    stylesheets,
    [],
    Some(media_env),
  )
  match cascaded.get_value("position") {
    Some(value) => {
      let positioned = value.to_lower().trim()
      positioned == "absolute" || positioned == "fixed"
    }
    None => false
  }
}

///|
/// Collect inline content from HTML children, combining text and <br> elements
/// Returns collected text (with \n for br) and remaining block-level children
/// Respects CSS display values to avoid merging text from inline-block elements
/// IMPORTANT: When elements are kept separate (like <a>), we flush accumulated text
/// first to preserve DOM order.
fn collect_inline_content(
  children : Array[@html.Node],
  stylesheets : Array[@css.Stylesheet],
  ctx : RenderContext,
  preserve_inline_elements : Bool,
  parent_selector : @css.Element,
) -> (String, Array[@html.Node]) {
  let text_builder = StringBuilder::new()
  let remaining : Array[@html.Node] = []
  let mut has_inline_content = false
  let mut element_sibling_count = 0
  for child in children {
    match child {
      @html.Node::Element(_) => element_sibling_count += 1
      _ => ()
    }
  }
  let mut element_sibling_index = 0

  // Helper to flush accumulated text as a synthetic text node
  fn flush_text(builder : StringBuilder, out : Array[@html.Node]) -> Unit {
    let text = builder.to_string()
    if !text.is_empty() {
      // Create a synthetic HTML text node for accumulated content
      out.push(@html.Node::Text(text))
      builder.reset()
    }
  }

  for child in children {
    match child {
      @html.Node::Text(text) => {
        text_builder.write_string(text)
        has_inline_content = true
      }
      @html.Node::Element(elem) => {
        element_sibling_index += 1
        let has_generated_pseudo = if stylesheets.length() == 0 {
          false
        } else {
          let child_selector = html_to_selector_element_with_parent(
            elem,
            parent_selector,
            element_sibling_index,
            element_sibling_count,
            None,
          )
          selector_has_generated_pseudo_content(
            child_selector, stylesheets, ctx,
          )
        }
        let tag_lower = elem.tag.to_lower()
        if tag_lower == "br" {
          // Flush accumulated text first
          flush_text(text_builder, remaining)
          // Keep <br> as a separate node for layout comparison
          remaining.push(child)
          has_inline_content = true
        } else if is_replaced_element(tag_lower) {
          // Flush any accumulated text first to preserve order
          flush_text(text_builder, remaining)
          // Replaced elements (img, input, etc.) are kept as separate nodes
          remaining.push(child)
        } else if has_display_contents(elem, stylesheets, ctx) ||
          has_inline_participating_display(elem, stylesheets, ctx) {
          if preserve_inline_elements {
            // In flex/grid containers, direct inline children are layout items
            // and must be preserved as elements.
            flush_text(text_builder, remaining)
            remaining.push(child)
            has_inline_content = true
          } else if will_have_non_inline_display(elem, stylesheets, ctx) {
            // inline-block/inline-flex/inline-grid and other non-inline values
            // must remain as elements; flattening drops intrinsic boxes.
            flush_text(text_builder, remaining)
            remaining.push(child)
            has_inline_content = true
            // Check if this inline element contains replaced elements (like <a><img></a>)
          } else if has_generated_pseudo {
            // Pseudo-elements require the inline host element to remain addressable.
            flush_text(text_builder, remaining)
            remaining.push(child)
            has_inline_content = true
          } else if should_preserve_inline_element(elem, stylesheets, ctx) ||
            contains_preserved_inline_descendant(elem, stylesheets, ctx) {
            // Keep inline elements that participate in containing-block / positioning behavior
            flush_text(text_builder, remaining)
            remaining.push(child)
          } else if contains_replaced_element(elem) {
            // Flush text first, then keep as separate node
            flush_text(text_builder, remaining)
            remaining.push(child)
          } else if tag_lower == "a" {
            // Flush text first, then keep <a> as separate node for link styling
            flush_text(text_builder, remaining)
            remaining.push(child)
          } else if contains_block_child(elem, stylesheets, ctx) {
            // Flush text first, then keep inline elements with block children
            flush_text(text_builder, remaining)
            remaining.push(child)
          } else {
            // Recursively collect text from inline elements (span, em, etc.)
            // Only if CSS doesn't set display: inline-block or other non-inline value
            collect_text_from_inline(elem, text_builder, stylesheets, ctx)
            has_inline_content = true
          }
        } else {
          // Flush text first, then add block-level element
          flush_text(text_builder, remaining)
          remaining.push(child)
        }
      }
    }
  }

  // Flush any trailing text to remaining to preserve complete order
  flush_text(text_builder, remaining)

  // Return empty string for inline_text since all text is now in remaining
  if has_inline_content || remaining.length() > 0 {
    ("", remaining)
  } else {
    ("", children)
  }
}
