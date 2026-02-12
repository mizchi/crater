///|
/// HTML/CSS Renderer
/// Converts HTML elements with inline styles to layout

///|
/// Text measurement constants (monospace font simulation)
/// Character width ratio for monospace fonts (width / font-size)
/// Typical monospace fonts have width:height ratio around 0.5-0.55
let char_width_ratio : Double = 0.5 // Conservative ratio for text fitting

///|
let chars_per_line : Int = 80 // Default wrap width in characters (single-width)

///|
/// Check if a character is East Asian Wide (CJK characters that take 2 columns)
fn is_wide_char(c : Char) -> Bool {
  let cp = c.to_int()
  // CJK Unified Ideographs (U+4E00–U+9FFF)
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  // CJK Extension A (U+3400–U+4DBF)
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  // Hiragana (U+3040–U+309F)
  (cp >= 0x3040 && cp <= 0x309F) ||
  // Katakana (U+30A0–U+30FF)
  (cp >= 0x30A0 && cp <= 0x30FF) ||
  // Hangul Syllables (U+AC00–U+D7AF)
  (cp >= 0xAC00 && cp <= 0xD7AF) ||
  // Fullwidth Forms (U+FF00–U+FFEF)
  (cp >= 0xFF00 && cp <= 0xFFEF) ||
  // CJK Symbols and Punctuation (U+3000–U+303F)
  (cp >= 0x3000 && cp <= 0x303F)
}

///|
/// Calculate display width of a character (1 for narrow, 2 for wide)
fn char_display_width(c : Char) -> Int {
  if is_wide_char(c) {
    2
  } else {
    1
  }
}

///|
/// Place a word into wrapped lines.
/// Returns (updated_lines, updated_line_width).
fn place_word_with_wrap(
  lines : Int,
  line_width : Int,
  word_width : Int,
  cols_available : Int,
  needs_space : Bool,
) -> (Int, Int) {
  if cols_available <= 0 {
    return (lines, line_width)
  }
  let mut new_lines = lines
  let mut new_line_width = line_width
  let mut space_width = 0
  if needs_space && new_line_width > 0 {
    space_width = 1
  }

  // Fits current line
  if new_line_width > 0 &&
    new_line_width + space_width + word_width <= cols_available {
    new_line_width = new_line_width + space_width + word_width
    return (new_lines, new_line_width)
  }

  // Move to next line if current line already has content.
  if new_line_width > 0 {
    new_lines = new_lines + 1
    new_line_width = 0
  }

  // Fits a fresh line.
  if word_width <= cols_available {
    return (new_lines, word_width)
  }

  // Long word fallback: hard-wrap by available columns.
  let full_lines = word_width / cols_available
  let remainder = word_width % cols_available
  if remainder == 0 {
    if full_lines > 0 {
      new_lines = new_lines + full_lines - 1
      new_line_width = cols_available
    } else {
      new_line_width = 0
    }
  } else {
    new_lines = new_lines + full_lines
    new_line_width = remainder
  }
  (new_lines, new_line_width)
}

///|
/// Render context with viewport dimensions
pub(all) struct RenderContext {
  viewport_width : Double
  viewport_height : Double
  root_font_size : Double
  color_scheme : @media.ColorScheme
}

///|
pub fn RenderContext::default() -> RenderContext {
  {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
}

///|
/// Create a MeasureFunc for text content with font metrics
/// Calculates text dimensions based on monospace character width
/// Accounts for East Asian Wide characters (CJK) which take 2 columns
/// Handles explicit line breaks (from <br> elements converted to \n)
/// Supports writing-mode for vertical text layout
fn create_text_measure(
  text : String,
  font_size : Double,
  text_line_height : Double,
  white_space : @style.WhiteSpace,
  writing_mode : @style.WritingMode,
) -> @types.MeasureFunc {
  let raw_trimmed = text.trim()
  let trimmed = if raw_trimmed.is_empty() && not(text.is_empty()) {
    " "
  } else {
    raw_trimmed.to_string()
  }
  let char_width = font_size * char_width_ratio

  // Split by explicit line breaks and calculate per-line metrics
  let mut explicit_lines = 1
  let mut max_line_width = 0
  let mut current_line_width = 0
  let mut max_word_width = 0
  let mut current_word_width = 0
  for c in trimmed.iter() {
    if c == '\n' {
      // Explicit line break (from <br>)
      explicit_lines = explicit_lines + 1
      if current_line_width > max_line_width {
        max_line_width = current_line_width
      }
      if current_word_width > max_word_width {
        max_word_width = current_word_width
      }
      current_line_width = 0
      current_word_width = 0
    } else if c == ' ' || c == '\t' {
      if current_word_width > max_word_width {
        max_word_width = current_word_width
      }
      current_word_width = 0
      current_line_width = current_line_width + 1 // Space width
    } else {
      let cw = char_display_width(c)
      current_line_width = current_line_width + cw
      current_word_width = current_word_width + cw
    }
  }
  // Handle last line/word
  if current_line_width > max_line_width {
    max_line_width = current_line_width
  }
  if current_word_width > max_word_width {
    max_word_width = current_word_width
  }

  // Check if vertical writing mode
  let is_vertical = writing_mode.is_vertical()

  // max_width is the widest line (for intrinsic sizing)
  let text_max_width = max_line_width.to_double() * char_width
  // min_width is the longest word
  let text_min_width = max_word_width.to_double() * char_width
  // min_height accounts for explicit line breaks
  let min_lines = explicit_lines
  {
    func: fn(
      available_width : Double,
      available_height : Double,
    ) -> @types.IntrinsicSize {
      // For white-space: nowrap, don't wrap text
      let no_wrap = match white_space {
        @style.WhiteSpace::Nowrap => true
        _ => false
      }

      // In vertical mode, the inline axis is vertical (height constrains)
      // In horizontal mode, the inline axis is horizontal (width constrains)
      let (available_inline, line_size) = if is_vertical {
        (available_height, text_line_height)
      } else {
        (available_width, char_width)
      }

      // Calculate how many single-width columns fit in available inline space
      // For nowrap, use a very large number to prevent wrapping
      let cols_available = if no_wrap {
        1000000 // Large number to prevent wrapping
      } else if available_inline > 0.0 {
        (available_inline / line_size).to_int()
      } else {
        chars_per_line
      }
      // Calculate total lines needed (considering both wrapping and explicit breaks)
      // For each explicit line, calculate how many visual lines it needs
      let use_word_wrap = match white_space {
        @style.WhiteSpace::Normal | @style.WhiteSpace::PreLine => true
        _ => false
      }
      let mut total_lines = 1
      if use_word_wrap && not(no_wrap) {
        // Greedy word wrapping with long-word hard-wrap fallback.
        let mut current_line_width = 0
        let mut current_word_width = 0
        let mut has_pending_space = false
        for c in trimmed.iter() {
          if c == '\n' {
            if current_word_width > 0 {
              let (l, w) = place_word_with_wrap(
                total_lines, current_line_width, current_word_width, cols_available,
                has_pending_space,
              )
              total_lines = l
              current_line_width = w
              current_word_width = 0
            }
            // Explicit line break always starts a new visual line.
            total_lines = total_lines + 1
            current_line_width = 0
            has_pending_space = false
          } else if c == ' ' || c == '\t' {
            if current_word_width > 0 {
              let (l, w) = place_word_with_wrap(
                total_lines, current_line_width, current_word_width, cols_available,
                has_pending_space,
              )
              total_lines = l
              current_line_width = w
              current_word_width = 0
            }
            has_pending_space = true
          } else {
            current_word_width = current_word_width + char_display_width(c)
          }
        }
        if current_word_width > 0 {
          let (l, _w) = place_word_with_wrap(
            total_lines, current_line_width, current_word_width, cols_available,
            has_pending_space,
          )
          total_lines = l
        }
      } else {
        // Character-based wrapping for nowrap/pre/pre-wrap behavior.
        let mut current_line_width = 0
        total_lines = 0
        for c in trimmed.iter() {
          if c == '\n' {
            // End of explicit line
            let line_visual_lines = if cols_available > 0 &&
              current_line_width > 0 {
              (current_line_width + cols_available - 1) / cols_available
            } else {
              1
            }
            total_lines = total_lines + line_visual_lines
            current_line_width = 0
          } else if c == ' ' || c == '\t' {
            current_line_width = current_line_width + 1
          } else {
            current_line_width = current_line_width + char_display_width(c)
          }
        }
        // Handle last line
        let last_line_visual = if cols_available > 0 && current_line_width > 0 {
          (current_line_width + cols_available - 1) / cols_available
        } else {
          1
        }
        total_lines = total_lines + last_line_visual
      }

      // In vertical mode, swap width/height concepts
      // - Width = number of lines (block dimension)
      // - Height = characters per line (inline dimension)
      if is_vertical {
        let width = total_lines.to_double() * text_line_height
        let min_width = min_lines.to_double() * text_line_height
        {
          min_width,
          max_width: width,
          min_height: text_min_width, // word length becomes height
          max_height: text_max_width, // line length becomes height
        }
      } else {
        let height = total_lines.to_double() * text_line_height
        let min_height = min_lines.to_double() * text_line_height
        {
          min_width: text_min_width,
          max_width: text_max_width,
          min_height,
          max_height: height,
        }
      }
    },
  }
}

///|
/// Check if an element is an inline-level element by tag name
fn is_inline_element_by_tag(tag : String) -> Bool {
  // HTML inline elements - includes HTML5 semantic inline elements
  let inline_tags = [
    // Traditional inline elements
    "a", "abbr", "acronym", "b", "bdo", "big", "br", "cite", "code", "dfn", "em",
    "font", "i", "img", "input", "kbd", "label", "q", "s", "samp", "select", "small",
    "span", "strike", "strong", "sub", "sup", "textarea", "tt", "u", "var",
    // HTML5 semantic inline elements
     "time", "data", "mark", "bdi", "wbr", "ruby", "rb", "rt", "rtc", "rp", "meter",
    "progress", "output", "ins", "del",
  ]
  inline_tags.contains(tag.to_lower())
}

///|
/// Check if an element has block display in its inline style
fn has_block_display_in_style(elem : @html.Element) -> Bool {
  match elem.style {
    Some(style_str) => {
      // Parse the inline style to check display property
      let parsed = @parser.parse_inline_style(style_str)
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
  stylesheets : Array[@cascade.Stylesheet],
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
    let mut selector_elem = @selector.Element::new(elem.tag.to_lower())
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
    let media_env = @media.MediaEnvironment::with_color_scheme(
      ctx.viewport_width,
      ctx.viewport_height,
      ctx.color_scheme,
    )
    let cascaded = @cascade.cascade_element_with_media(
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
          (value_lower.contains("block") && not(value_lower.contains("inline"))) ||
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
/// Check whether an inline element must be preserved as a node
/// (instead of being merged into surrounding text).
/// This is needed for containing-block / positioning behaviors.
fn should_preserve_inline_element(
  elem : @html.Element,
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  // Check inline style first
  match elem.style {
    Some(style) => {
      let style_lower = style.to_lower()
      let has_position = style_lower.contains("position:")
      let is_static_position = style_lower.contains("position: static")
      if has_position && not(is_static_position) {
        return true
      }
      let has_filter = style_lower.contains("filter:")
      let filter_none = style_lower.contains("filter: none")
      if has_filter && not(filter_none) {
        return true
      }
      let has_transform = style_lower.contains("transform:")
      let transform_none = style_lower.contains("transform: none")
      if has_transform && not(transform_none) {
        return true
      }
      let has_perspective = style_lower.contains("perspective:")
      let perspective_none = style_lower.contains("perspective: none")
      if has_perspective && not(perspective_none) {
        return true
      }
    }
    None => ()
  }

  // Check stylesheet rules
  if stylesheets.length() > 0 {
    let mut selector_elem = @selector.Element::new(elem.tag.to_lower())
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
    let media_env = @media.MediaEnvironment::with_color_scheme(
      ctx.viewport_width,
      ctx.viewport_height,
      ctx.color_scheme,
    )
    let cascaded = @cascade.cascade_element_with_media(
      selector_elem,
      stylesheets,
      [],
      Some(media_env),
    )
    match cascaded.get_value("position") {
      Some(value) => if value.to_lower().trim() != "static" { return true }
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
/// Check recursively whether an element contains any inline descendants
/// that should be preserved for layout semantics.
fn contains_preserved_inline_descendant(
  elem : @html.Element,
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
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
  stylesheets : Array[@cascade.Stylesheet],
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
          not(will_have_non_inline_display(child_elem, stylesheets, ctx)) &&
          not(should_preserve_inline_element(child_elem, stylesheets, ctx)) {
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
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        // Check if child has non-inline display
        if will_have_non_inline_display(child_elem, stylesheets, ctx) {
          return true
        }
        // Also check if child is a block-level element by default
        let tag_lower = child_elem.tag.to_lower()
        if not(is_inline_element(child_elem)) &&
          not(is_replaced_element(tag_lower)) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
/// Check if element is a replaced element (img, input, video, etc.)
/// Replaced elements have intrinsic dimensions and don't contain text
fn is_replaced_element(tag : String) -> Bool {
  match tag.to_lower() {
    "img"
    | "input"
    | "video"
    | "audio"
    | "canvas"
    | "iframe"
    | "object"
    | "embed" => true
    _ => false
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
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
) -> (String, Array[@html.Node]) {
  let text_builder = StringBuilder::new()
  let remaining : Array[@html.Node] = []
  let mut has_inline_content = false

  // Helper to flush accumulated text as a synthetic text node
  fn flush_text(builder : StringBuilder, out : Array[@html.Node]) -> Unit {
    let text = builder.to_string()
    if not(text.is_empty()) {
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
        let tag_lower = elem.tag.to_lower()
        if tag_lower == "br" {
          // Flush accumulated text first
          flush_text(text_builder, remaining)
          // Keep <br> as a separate node for layout comparison
          remaining.push(child)
          // Also add newline for text rendering
          text_builder.write_string("\n")
          has_inline_content = true
        } else if is_replaced_element(tag_lower) {
          // Flush any accumulated text first to preserve order
          flush_text(text_builder, remaining)
          // Replaced elements (img, input, etc.) are kept as separate nodes
          remaining.push(child)
        } else if is_inline_element(elem) &&
          not(will_have_non_inline_display(elem, stylesheets, ctx)) {
          // Check if this inline element contains replaced elements (like <a><img></a>)
          if should_preserve_inline_element(elem, stylesheets, ctx) ||
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

///|
/// Create a node for text content with inherited font properties
fn create_text_node(text : String, parent_style : @style.Style) -> @node.Node {
  let trimmed = text.trim()
  let font_size = parent_style.font_size
  let text_line_height = parent_style.line_height
  let white_space = parent_style.white_space
  let writing_mode = parent_style.writing_mode
  // Create text style with inherited font properties and color for rendering
  // Text nodes should be inline-level to flow with other inline content
  let text_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Inline,
    font_size,
    line_height: text_line_height,
    white_space,
    writing_mode,
    color: parent_style.color,
  }
  if trimmed.is_empty() {
    // Preserve collapsible whitespace as a single space so inline-block gaps match browser layout.
    if text.is_empty() {
      @node.Node::leaf("#text", @style.Style::default())
    } else {
      let collapsed = " "
      @node.Node::text(
        "#text",
        text_style,
        create_text_measure(
          collapsed, font_size, text_line_height, white_space, writing_mode,
        ),
        collapsed,
      )
    }
  } else {
    // Use Node::text to store the text content for rendering
    @node.Node::text(
      "#text",
      text_style,
      create_text_measure(
        text, font_size, text_line_height, white_space, writing_mode,
      ),
      trimmed.to_string(),
    )
  }
}

///|
/// Create a MeasureFunc for image with intrinsic dimensions
fn create_image_measure(
  intrinsic_width : Double,
  intrinsic_height : Double,
) -> @types.MeasureFunc {
  {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @types.IntrinsicSize {
      // If intrinsic size is specified, use it
      // Otherwise default to 0
      let width = if intrinsic_width > 0.0 { intrinsic_width } else { 0.0 }
      let height = if intrinsic_height > 0.0 { intrinsic_height } else { 0.0 }

      // For images with intrinsic dimensions, min and max are the same
      {
        min_width: width,
        max_width: width,
        min_height: height,
        max_height: height,
      }
    },
  }
}

///|
/// Create a MeasureFunc for input elements with intrinsic dimensions
fn create_input_measure(
  intrinsic_width : Double,
  intrinsic_height : Double,
) -> @types.MeasureFunc {
  {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @types.IntrinsicSize {
      // Input elements have fixed intrinsic dimensions based on type
      {
        min_width: intrinsic_width,
        max_width: intrinsic_width,
        min_height: intrinsic_height,
        max_height: intrinsic_height,
      }
    },
  }
}

///|
/// Create a MeasureFunc for br elements
/// br elements have zero width and line-height for height
fn create_br_measure(line_height : Double) -> @types.MeasureFunc {
  {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @types.IntrinsicSize {
      // br elements have zero width but take up line-height vertically
      {
        min_width: 0.0,
        max_width: 0.0,
        min_height: line_height,
        max_height: line_height,
      }
    },
  }
}

///|
/// Parse dimension from HTML attribute (e.g., "300" or "300px")
fn parse_html_dimension(value : String) -> Double? {
  let trimmed = value.trim().to_string()
  if trimmed.is_empty() {
    return None
  }
  // Remove "px" suffix if present
  let num_str = if trimmed.has_suffix("px") {
    trimmed[:trimmed.length() - 2].to_string() catch {
      _ => trimmed
    }
  } else {
    trimmed
  }
  Some(
    // Parse as double
    @strconv.parse_double(num_str),
  ) catch {
    _ => None
  }
}

///|
/// Simple URL decode for common SVG data URI characters
fn url_decode(s : String) -> String {
  let result = StringBuilder::new()
  let mut i = 0
  while i < s.length() {
    let c = s[i].to_int().unsafe_to_char()
    if c == '%' && i + 2 < s.length() {
      // Parse hex value
      let hex1 = s[i + 1].to_int().unsafe_to_char()
      let hex2 = s[i + 2].to_int().unsafe_to_char()
      fn hex_digit(c : Char) -> Int {
        if c >= '0' && c <= '9' {
          c.to_int() - '0'.to_int()
        } else if c >= 'a' && c <= 'f' {
          c.to_int() - 'a'.to_int() + 10
        } else if c >= 'A' && c <= 'F' {
          c.to_int() - 'A'.to_int() + 10
        } else {
          0
        }
      }

      let value = hex_digit(hex1) * 16 + hex_digit(hex2)
      result.write_char(value.unsafe_to_char())
      i = i + 3
    } else {
      result.write_char(c)
      i = i + 1
    }
  }
  result.to_string()
}

///|
/// Find index of pattern in string, returns -1 if not found
fn find_string_index(s : String, pattern : String) -> Int {
  if pattern.length() == 0 || pattern.length() > s.length() {
    return -1
  }
  for i = 0; i <= s.length() - pattern.length(); i = i + 1 {
    let mut found = true
    for j = 0; j < pattern.length(); j = j + 1 {
      if s[i + j].to_int() != pattern[j].to_int() {
        found = false
        break
      }
    }
    if found {
      return i
    }
  }
  -1
}

///|
/// Extract a simple attribute value from SVG string
fn extract_svg_attribute(svg : String, attr_name : String) -> String? {
  // Look for attr='value' or attr="value"
  let patterns = [attr_name + "='", attr_name + "=\""]
  for pattern in patterns {
    let idx = find_string_index(svg, pattern)
    if idx >= 0 {
      let start = idx + pattern.length()
      let quote_char = if pattern.has_suffix("'") { '\'' } else { '"' }
      // Find closing quote
      for end = start; end < svg.length(); end = end + 1 {
        if svg[end].to_int().unsafe_to_char() == quote_char {
          let result = svg[start:end].to_string() catch { _ => "" }
          if result.length() > 0 {
            return Some(result)
          }
        }
      }
    }
  }
  None
}

///|
/// Parse viewBox attribute (format: "minX minY width height")
fn parse_viewbox(viewbox : String) -> (Double, Double)? {
  // Split by spaces
  let parts : Array[String] = []
  let mut current = StringBuilder::new()
  for i = 0; i < viewbox.length(); i = i + 1 {
    let c = viewbox[i].to_int().unsafe_to_char()
    if c == ' ' {
      if current.to_string().length() > 0 {
        parts.push(current.to_string())
        current = StringBuilder::new()
      }
    } else {
      current.write_char(c)
    }
  }
  if current.to_string().length() > 0 {
    parts.push(current.to_string())
  }
  if parts.length() >= 4 {
    let width = @strconv.parse_double(parts[2]) catch { _ => return None }
    let height = @strconv.parse_double(parts[3]) catch { _ => return None }
    if width > 0.0 && height > 0.0 {
      Some((width, height))
    } else {
      None
    }
  } else {
    None
  }
}

///|
/// Extract intrinsic size from SVG data URI
fn parse_svg_data_uri(src : String) -> (Double, Double)? {
  // Check if it's an SVG data URI
  if not(src.has_prefix("data:image/svg+xml")) {
    return None
  }
  // Check for base64 encoding (not supported yet)
  if src.contains(";base64,") {
    return None
  }
  // Find the comma that starts the data
  let mut comma_idx = -1
  for i = 0; i < src.length(); i = i + 1 {
    if src[i].to_int().unsafe_to_char() == ',' {
      comma_idx = i
      break
    }
  }
  if comma_idx < 0 {
    return None
  }
  // URL decode the SVG content
  let svg_encoded = src[comma_idx + 1:].to_string() catch { _ => return None }
  let svg = url_decode(svg_encoded)
  // Extract width, height, and viewBox
  let width_attr = extract_svg_attribute(svg, "width")
  let height_attr = extract_svg_attribute(svg, "height")
  let viewbox_attr = extract_svg_attribute(svg, "viewBox")
  // Parse width and height
  let parsed_width : Double? = match width_attr {
    Some(w) => parse_html_dimension(w)
    None => None
  }
  let parsed_height : Double? = match height_attr {
    Some(h) => parse_html_dimension(h)
    None => None
  }
  // Get aspect ratio from viewBox
  let viewbox_size : (Double, Double)? = match viewbox_attr {
    Some(vb) => parse_viewbox(vb)
    None => None
  }
  // Calculate final dimensions
  match (parsed_width, parsed_height, viewbox_size) {
    // Both width and height specified
    (Some(w), Some(h), _) => Some((w, h))
    // Only width specified, use viewBox aspect ratio
    (Some(w), None, Some((vb_w, vb_h))) => {
      let aspect = vb_w / vb_h
      Some((w, w / aspect))
    }
    // Only height specified, use viewBox aspect ratio
    (None, Some(h), Some((vb_w, vb_h))) => {
      let aspect = vb_w / vb_h
      Some((h * aspect, h))
    }
    // No width/height but viewBox exists
    (None, None, Some((vb_w, vb_h))) => Some((vb_w, vb_h))
    // Width only, no aspect ratio
    (Some(w), None, None) => Some((w, w))
    // Height only, no aspect ratio
    (None, Some(h), None) => Some((h, h))
    _ => None
  }
}

///|
/// Get intrinsic size from image src attribute
fn get_image_intrinsic_size(src : String) -> (Double, Double)? {
  // Only SVG data URI is supported - filename patterns are too unreliable
  // and can cause issues with tests that expect 0 intrinsic size
  parse_svg_data_uri(src)
}

///|
/// Convert HTML Element to Node tree for layout computation
pub fn element_to_node(
  elem : @html.Element,
  parent_style : @style.Style?,
) -> @node.Node {
  // Compute style from inline style attribute with parent for inheritance
  let ctx = match parent_style {
    Some(ps) => @computed.ComputeContext::with_parent(ps)
    None => @computed.ComputeContext::new()
  }
  let style = match elem.style {
    Some(css) => @computed.compute_inline(css, ctx)
    None =>
      // When no inline style, inherit from parent if available
      match parent_style {
        Some(ps) => {
          let inherited = @style.Style::default()
          // Copy inherited properties from parent
          inherited.writing_mode = ps.writing_mode
          inherited.color = ps.color
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
  indexed_stylesheets : Array[@cascade.IndexedStylesheet],
  css_vars : Map[String, String],
) -> Double {
  if doc_root.tag.to_lower() != "html" {
    return 1.0
  }
  let root_selector = html_to_selector_element(doc_root, None)
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
  // Parse HTML document (includes stylesheet extraction)
  let doc = @html.parse_document(html)

  // Parse stylesheets from <style> tags and external CSS
  let stylesheets : Array[@cascade.Stylesheet] = []
  // First add external CSS (lower priority)
  for css in external_css {
    let stylesheet = @parser.parse_stylesheet(css)
    stylesheets.push(stylesheet)
  }
  // Then add inline styles (higher priority)
  for css in doc.stylesheets {
    let stylesheet = @parser.parse_stylesheet(css)
    stylesheets.push(stylesheet)
  }

  // Build indexed stylesheets for faster selector matching
  let indexed_stylesheets : Array[@cascade.IndexedStylesheet] = []
  for stylesheet in stylesheets {
    indexed_stylesheets.push(@cascade.IndexedStylesheet::new(stylesheet))
  }

  // Collect CSS custom properties from :root rules
  let css_vars = collect_root_css_variables(stylesheets, ctx)

  // Find body element, or use root if not found
  let render_root = match find_body(doc.root) {
    Some(body) => body
    None => doc.root
  }

  // Convert to node tree with stylesheet styles applied
  let root = element_to_node_with_styles(
    render_root,
    None,
    ctx,
    stylesheets,
    indexed_stylesheets,
    css_vars,
  )
  if render_root.tag.to_lower() == "body" {
    let root_zoom = resolve_document_root_zoom(
      doc.root,
      ctx,
      indexed_stylesheets,
      css_vars,
    )
    if root_zoom != 1.0 {
      root.style.zoom = root.style.zoom * root_zoom
    }
  }

  // Create layout context - subtract root margin from available space
  let root_margin = @types.resolve_rect(root.style.margin, ctx.viewport_width)
  let available_width = ctx.viewport_width -
    root_margin.left -
    root_margin.right
  // Use None for available_height to allow content to grow naturally (scrollable)
  // If we pass Some(viewport_height), the layout might constrain to viewport
  let layout_ctx : @types.LayoutContext = {
    available_width,
    available_height: None,
    sizing_mode: @types.SizingMode::Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }

  // Initialize the layout dispatcher for cross-layout-type support
  @dispatch.setup()

  // Compute layout using dispatcher (handles display type switching)
  let layout = @dispatch.compute_layout(root, layout_ctx)

  // Apply zoom and transform scale to layout
  let scaled_layout = apply_zoom_and_scale(
    layout, root, 1.0, 1.0, 1.0, 0.0, 0.0,
  )

  let scaled_layout = if root.id == "body" &&
    scaled_layout.height < ctx.viewport_height {
    { ..scaled_layout, height: ctx.viewport_height }
  } else {
    scaled_layout
  }

  // Apply root margin as position offset
  // For margin:auto, center horizontally
  let margin_left_is_auto = match root.style.margin.left {
    @types.Dimension::Auto => true
    _ => false
  }
  let margin_right_is_auto = match root.style.margin.right {
    @types.Dimension::Auto => true
    _ => false
  }
  let x_offset = if margin_left_is_auto && margin_right_is_auto {
    // Center horizontally
    (ctx.viewport_width - scaled_layout.width) / 2.0
  } else if margin_left_is_auto {
    // Push to right
    ctx.viewport_width - scaled_layout.width - root_margin.right
  } else {
    // Use left margin
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
/// Render a parsed HTML Document to Layout with external CSS
/// This is useful when you need to pre-process the document (e.g., add synthetic IDs)
pub fn render_document_with_external_css(
  doc : @html.Document,
  ctx : RenderContext,
  external_css : Array[String],
) -> @types.Layout {
  // Parse stylesheets from <style> tags and external CSS
  let stylesheets : Array[@cascade.Stylesheet] = []
  // First add external CSS (lower priority)
  for css in external_css {
    let stylesheet = @parser.parse_stylesheet(css)
    stylesheets.push(stylesheet)
  }
  // Then add inline styles (higher priority)
  for css in doc.stylesheets {
    let stylesheet = @parser.parse_stylesheet(css)
    stylesheets.push(stylesheet)
  }

  // Build indexed stylesheets for faster selector matching
  let indexed_stylesheets : Array[@cascade.IndexedStylesheet] = []
  for stylesheet in stylesheets {
    indexed_stylesheets.push(@cascade.IndexedStylesheet::new(stylesheet))
  }

  // Collect CSS custom properties from :root rules
  let css_vars = collect_root_css_variables(stylesheets, ctx)

  // Find body element, or use root if not found
  let render_root = match find_body(doc.root) {
    Some(body) => body
    None => doc.root
  }

  // Convert to node tree with stylesheet styles applied
  let root = element_to_node_with_styles(
    render_root,
    None,
    ctx,
    stylesheets,
    indexed_stylesheets,
    css_vars,
  )
  if render_root.tag.to_lower() == "body" {
    let root_zoom = resolve_document_root_zoom(
      doc.root,
      ctx,
      indexed_stylesheets,
      css_vars,
    )
    if root_zoom != 1.0 {
      root.style.zoom = root.style.zoom * root_zoom
    }
  }

  // Create layout context - subtract root margin from available space
  let root_margin = @types.resolve_rect(root.style.margin, ctx.viewport_width)
  let available_width = ctx.viewport_width -
    root_margin.left -
    root_margin.right
  // Use None for available_height to allow content to grow naturally (scrollable)
  // If we pass Some(viewport_height), the layout might constrain to viewport
  let layout_ctx : @types.LayoutContext = {
    available_width,
    available_height: None,
    sizing_mode: @types.SizingMode::Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }

  // Initialize the layout dispatcher for cross-layout-type support
  @dispatch.setup()

  // Compute layout
  let layout = @dispatch.compute_layout(root, layout_ctx)

  // Apply zoom and transform scale to layout
  let scaled_layout = apply_zoom_and_scale(
    layout, root, 1.0, 1.0, 1.0, 0.0, 0.0,
  )

  let scaled_layout = if root.id == "body" &&
    scaled_layout.height < ctx.viewport_height {
    { ..scaled_layout, height: ctx.viewport_height }
  } else {
    scaled_layout
  }

  // Apply root margin offset to final layout
  let margin_left_is_auto = match root.style.margin.left {
    @types.Dimension::Auto => true
    _ => false
  }
  let margin_right_is_auto = match root.style.margin.right {
    @types.Dimension::Auto => true
    _ => false
  }
  let x_offset = if margin_left_is_auto && margin_right_is_auto {
    // Center horizontally
    (ctx.viewport_width - scaled_layout.width) / 2.0
  } else if margin_left_is_auto {
    // Push to right
    ctx.viewport_width - scaled_layout.width - root_margin.right
  } else {
    // Use left margin
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
/// Check if a compound selector is the :root pseudo-class
fn is_root_selector(selector : @selector.CompoundSelector) -> Bool {
  for sub in selector.subclasses {
    match sub {
      @selector.SimpleSelector::PseudoClass(@selector.PseudoClass::Root) =>
        return true
      _ => ()
    }
  }
  false
}

///|
/// Check if a complex selector matches :root (simple :root without combinators)
fn is_root_only_selector(selector : @selector.ComplexSelector) -> Bool {
  // :root should be a simple selector without combinators
  if selector.tail.length() > 0 {
    return false
  }
  is_root_selector(selector.head)
}

///|
/// Collect CSS custom properties from :root rules in stylesheets
/// Evaluates media queries to correctly apply dark mode variables
fn collect_root_css_variables(
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
) -> Map[String, String] {
  let vars : Map[String, String] = {}
  // Create media environment for evaluating @media queries
  let media_env = @media.MediaEnvironment::with_color_scheme(
    ctx.viewport_width,
    ctx.viewport_height,
    ctx.color_scheme,
  )
  for stylesheet in stylesheets {
    for rule in stylesheet.rules {
      // Check media query if present
      let media_matches = match rule.media_query {
        Some(mq) => mq.evaluate(media_env)
        None => true
      }
      if not(media_matches) {
        continue
      }
      // Check if this rule targets :root
      if is_root_only_selector(rule.selector) {
        // Collect custom properties (--*) from declarations
        for decl in rule.declarations {
          if decl.property.has_prefix("--") {
            match decl.value {
              @cascade.PropertyValue::Value(v) => vars[decl.property] = v
              _ => ()
            }
          }
        }
      }
    }
  }
  vars
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
  let stylesheets : Array[@cascade.Stylesheet] = []
  // First add external CSS (lower priority)
  for css in external_css {
    let stylesheet = @parser.parse_stylesheet(css)
    stylesheets.push(stylesheet)
  }
  // Then add inline styles (higher priority)
  for css in doc.stylesheets {
    let stylesheet = @parser.parse_stylesheet(css)
    stylesheets.push(stylesheet)
  }
  // Build indexed stylesheets for faster selector matching
  let indexed_stylesheets : Array[@cascade.IndexedStylesheet] = []
  for stylesheet in stylesheets {
    indexed_stylesheets.push(@cascade.IndexedStylesheet::new(stylesheet))
  }
  // Collect CSS custom properties from :root rules
  let css_vars = collect_root_css_variables(stylesheets, ctx)
  let render_root = match find_body(doc.root) {
    Some(body) => body
    None => doc.root
  }
  let root = element_to_node_with_styles(
    render_root,
    None,
    ctx,
    stylesheets,
    indexed_stylesheets,
    css_vars,
  )
  if render_root.tag.to_lower() == "body" {
    let root_zoom = resolve_document_root_zoom(
      doc.root,
      ctx,
      indexed_stylesheets,
      css_vars,
    )
    if root_zoom != 1.0 {
      root.style.zoom = root.style.zoom * root_zoom
    }
  }
  root
}

///|
/// Render a parsed HTML Document to Node tree with external CSS
/// This is useful when you need to use a pre-parsed document (e.g., from streaming parser)
pub fn render_to_node_with_document(
  doc : @html.Document,
  ctx : RenderContext,
  external_css : Array[String],
) -> @node.Node {
  let stylesheets : Array[@cascade.Stylesheet] = []
  // First add external CSS (lower priority)
  for css in external_css {
    let stylesheet = @parser.parse_stylesheet(css)
    stylesheets.push(stylesheet)
  }
  // Then add inline styles (higher priority)
  for css in doc.stylesheets {
    let stylesheet = @parser.parse_stylesheet(css)
    stylesheets.push(stylesheet)
  }
  // Build indexed stylesheets for faster selector matching
  let indexed_stylesheets : Array[@cascade.IndexedStylesheet] = []
  for stylesheet in stylesheets {
    indexed_stylesheets.push(@cascade.IndexedStylesheet::new(stylesheet))
  }
  // Collect CSS custom properties from :root rules
  let css_vars = collect_root_css_variables(stylesheets, ctx)
  let render_root = match find_body(doc.root) {
    Some(body) => body
    None => doc.root
  }
  let root = element_to_node_with_styles(
    render_root,
    None,
    ctx,
    stylesheets,
    indexed_stylesheets,
    css_vars,
  )
  if render_root.tag.to_lower() == "body" {
    let root_zoom = resolve_document_root_zoom(
      doc.root,
      ctx,
      indexed_stylesheets,
      css_vars,
    )
    if root_zoom != 1.0 {
      root.style.zoom = root.style.zoom * root_zoom
    }
  }
  root
}

///|
/// Check if tag is an SVG element
fn is_svg_element(tag : String) -> Bool {
  match tag {
    "svg"
    | "g"
    | "rect"
    | "circle"
    | "ellipse"
    | "line"
    | "polyline"
    | "polygon"
    | "path"
    | "text"
    | "tspan"
    | "defs"
    | "use"
    | "symbol"
    | "clipPath"
    | "mask"
    | "pattern"
    | "linearGradient"
    | "radialGradient"
    | "stop"
    | "image"
    | "foreignObject"
    | "switch"
    | "a" => true
    // Note: "a" in SVG context is an SVG element, but we can't distinguish here
    // It will be handled by context in the future
    _ => false
  }
}

///|
/// Apply SVG attributes (width, height, x, y, line coords, circle/ellipse) to style
fn apply_svg_attributes_to_style(
  style : @style.Style,
  attrs : Map[String, String],
) -> @style.Style {
  let mut result = style

  // Get width from attribute
  match attrs.get("width") {
    Some(w) => {
      let width = parse_svg_length(w)
      if width > 0.0 {
        result = { ..result, width: @types.Length(width) }
      }
    }
    None => ()
  }

  // Get height from attribute
  match attrs.get("height") {
    Some(h) => {
      let height = parse_svg_length(h)
      if height > 0.0 {
        result = { ..result, height: @types.Length(height) }
      }
    }
    None => ()
  }

  // Handle SVG x/y position attributes for rect, text, etc.
  let has_x = attrs.contains("x")
  let has_y = attrs.contains("y")
  if has_x || has_y {
    let svg_x = match attrs.get("x") {
      Some(x_str) => parse_svg_length(x_str)
      None => 0.0
    }
    let svg_y = match attrs.get("y") {
      Some(y_str) => parse_svg_length(y_str)
      None => 0.0
    }
    result = {
      ..result,
      position: @types.Absolute,
      inset: {
        left: @types.Length(svg_x),
        right: result.inset.right,
        top: @types.Length(svg_y),
        bottom: result.inset.bottom,
      },
    }
  }

  // Handle SVG line elements (x1, y1, x2, y2) - compute bounding box
  let has_x1 = attrs.contains("x1")
  let has_y1 = attrs.contains("y1")
  let has_x2 = attrs.contains("x2")
  let has_y2 = attrs.contains("y2")
  if has_x1 || has_y1 || has_x2 || has_y2 {
    let x1 = match attrs.get("x1") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let y1 = match attrs.get("y1") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let x2 = match attrs.get("x2") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let y2 = match attrs.get("y2") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let min_x = if x1 < x2 { x1 } else { x2 }
    let min_y = if y1 < y2 { y1 } else { y2 }
    let width = if x1 > x2 { x1 - x2 } else { x2 - x1 }
    let height = if y1 > y2 { y1 - y2 } else { y2 - y1 }
    result = {
      ..result,
      position: @types.Absolute,
      width: @types.Length(width),
      height: @types.Length(height),
      inset: {
        left: @types.Length(min_x),
        right: result.inset.right,
        top: @types.Length(min_y),
        bottom: result.inset.bottom,
      },
    }
  }

  // Handle SVG circle elements (cx, cy, r) - compute bounding box
  let has_r = attrs.contains("r")
  if has_r {
    let cx = match attrs.get("cx") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let cy = match attrs.get("cy") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let r = match attrs.get("r") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    result = {
      ..result,
      position: @types.Absolute,
      width: @types.Length(r * 2.0),
      height: @types.Length(r * 2.0),
      inset: {
        left: @types.Length(cx - r),
        right: result.inset.right,
        top: @types.Length(cy - r),
        bottom: result.inset.bottom,
      },
    }
  }

  // Handle SVG ellipse elements (cx, cy, rx, ry) - compute bounding box
  let has_rx = attrs.contains("rx")
  let has_ry = attrs.contains("ry")
  if (has_rx || has_ry) && not(has_r) {
    let cx = match attrs.get("cx") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let cy = match attrs.get("cy") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let rx = match attrs.get("rx") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    let ry = match attrs.get("ry") {
      Some(v) => parse_svg_length(v)
      None => 0.0
    }
    result = {
      ..result,
      position: @types.Absolute,
      width: @types.Length(rx * 2.0),
      height: @types.Length(ry * 2.0),
      inset: {
        left: @types.Length(cx - rx),
        right: result.inset.right,
        top: @types.Length(cy - ry),
        bottom: result.inset.bottom,
      },
    }
  }
  result
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
/// Parse SVG length value (e.g., "100", "100px", "50%")
fn parse_svg_length(value : String) -> Double {
  let trimmed = value.trim().to_string()
  if trimmed.is_empty() {
    return 0.0
  }

  // Remove common units
  let num_str = if trimmed.has_suffix("px") {
    remove_suffix(trimmed, 2)
  } else if trimmed.has_suffix("pt") {
    remove_suffix(trimmed, 2)
  } else if trimmed.has_suffix("em") || trimmed.has_suffix("ex") {
    // em/ex are relative units, treat as pixels for now
    remove_suffix(trimmed, 2)
  } else if trimmed.has_suffix("%") {
    // Percentage - return 0 to skip (handled by CSS)
    return 0.0
  } else {
    trimmed
  }
  @strconv.parse_double(num_str) catch {
    _ => 0.0
  }
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
    | "iframe"
    | "object"
    | "embed"
    | "applet"
    // Media elements (not yet supported)
    | "video"
    | "audio"
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
  parent : @selector.Element?,
  ctx : RenderContext,
  stylesheets : Array[@cascade.Stylesheet],
  indexed_stylesheets : Array[@cascade.IndexedStylesheet],
  css_vars : Map[String, String],
) -> @node.Node {
  // Convert HTML element to selector element for matching
  let selector_elem = html_to_selector_element(elem, parent)

  // Get style from stylesheet matching + inline style (using indexed for performance)
  let computed_style = compute_element_style_indexed(
    selector_elem,
    elem.style,
    indexed_stylesheets,
    parent is None,
    ctx,
    None, // Root element has no parent style
    css_vars,
  )

  // Handle table cell rowspan/colspan attributes
  let cell_tag = elem.tag.to_lower()
  let style = if cell_tag == "td" || cell_tag == "th" {
    let rowspan = match elem.attributes.get("rowspan") {
      Some(val) => {
        let n = @strconv.parse_int(val) catch { _ => 1 }
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
        let n = @strconv.parse_int(val) catch { _ => 1 }
        if n > 0 {
          n
        } else {
          1
        }
      }
      None => 1
    }
    { ..computed_style, rowspan, colspan }
  } else {
    computed_style
  }

  // Convert children - first collect inline content (text + br)
  // Pass stylesheets to detect CSS display values (e.g., display: inline-block)
  let children : Array[@node.Node] = []
  let (inline_text, remaining_children) = collect_inline_content(
    elem.children,
    stylesheets,
    ctx,
  )

  // Add combined text node if there's inline content
  if not(inline_text.trim().is_empty()) {
    let text_node = create_text_node(inline_text, style)
    children.push(text_node)
  }

  // Process remaining children (elements and synthetic text nodes)
  for i, child in remaining_children {
    match child {
      @html.Node::Element(child_elem) => {
        // Skip non-rendered elements
        if should_skip_element(child_elem.tag) {
          continue
        }
        // Update sibling info on selector element for child processing
        let child_selector = html_to_selector_element_with_parent(
          child_elem,
          selector_elem,
          i + 1,
          remaining_children.length(),
        )
        let child_node = element_to_node_with_styles_internal(
          child_elem,
          child_selector,
          ctx,
          stylesheets,
          indexed_stylesheets,
          Some(style),
          css_vars,
        )
        children.push(child_node)
      }
      @html.Node::Text(text) =>
        // Process synthetic text nodes created by collect_inline_content
        // to preserve DOM order when elements are interleaved with text.
        if not(text.is_empty()) {
          let text_node = create_text_node(text, style)
          children.push(text_node)
        }
    }
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
  selector_elem : @selector.Element,
  ctx : RenderContext,
  stylesheets : Array[@cascade.Stylesheet],
  indexed_stylesheets : Array[@cascade.IndexedStylesheet],
  parent_style : @style.Style?,
  css_vars : Map[String, String],
) -> @node.Node {
  // Get style from stylesheet matching + inline style (using indexed for performance)
  let computed_style = compute_element_style_indexed(
    selector_elem,
    elem.style,
    indexed_stylesheets,
    false,
    ctx,
    parent_style,
    css_vars,
  )

  // If this is an inline element containing replaced elements (like <a><img></a>),
  // treat it as inline-block so it gets proper sizing from its content
  // Also, if inline element contains block children (like <code><span class="line">),
  // treat it as block so children can be properly laid out
  let style = if computed_style.display == @types.Inline &&
    contains_replaced_element(elem) {
    { ..computed_style, display: @types.InlineBlock }
  } else if computed_style.display == @types.Inline &&
    contains_block_child(elem, stylesheets, ctx) {
    // Inline element with block children should become block
    // This handles cases like <code><span class="line" style="display:block">
    { ..computed_style, display: @types.Block }
  } else {
    computed_style
  }

  // Handle table cell rowspan/colspan attributes
  let cell_tag = elem.tag.to_lower()
  let style = if cell_tag == "td" || cell_tag == "th" {
    let rowspan = match elem.attributes.get("rowspan") {
      Some(val) => {
        let n = @strconv.parse_int(val) catch { _ => 1 }
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
        let n = @strconv.parse_int(val) catch { _ => 1 }
        if n > 0 {
          n
        } else {
          1
        }
      }
      None => 1
    }
    { ..style, rowspan, colspan }
  } else {
    style
  }

  // Handle SVG element size from attributes
  let style = if is_svg_element(cell_tag) {
    apply_svg_attributes_to_style(style, elem.attributes)
  } else {
    style
  }

  // Convert children - first collect inline content (text + br)
  // Pass stylesheets to detect CSS display values (e.g., display: inline-block)
  let children : Array[@node.Node] = []
  let (inline_text, remaining_children) = collect_inline_content(
    elem.children,
    stylesheets,
    ctx,
  )

  // Add combined text node if there's inline content
  if not(inline_text.trim().is_empty()) {
    let text_node = create_text_node(inline_text, style)
    children.push(text_node)
  }

  // Process remaining children (elements and synthetic text nodes)
  for i, child in remaining_children {
    match child {
      @html.Node::Element(child_elem) => {
        // Skip non-rendered elements
        if should_skip_element(child_elem.tag) {
          continue
        }
        let child_selector = html_to_selector_element_with_parent(
          child_elem,
          selector_elem,
          i + 1,
          remaining_children.length(),
        )
        let child_node = element_to_node_with_styles_internal(
          child_elem,
          child_selector,
          ctx,
          stylesheets,
          indexed_stylesheets,
          Some(style),
          css_vars,
        )
        children.push(child_node)
      }
      @html.Node::Text(text) =>
        // Process synthetic text nodes created by collect_inline_content
        // to preserve DOM order when elements are interleaved with text.
        if not(text.is_empty()) {
          let text_node = create_text_node(text, style)
          children.push(text_node)
        }
    }
  }
  let node_id = make_node_id(elem)

  // Handle replaced elements (img, input, etc.) with intrinsic sizing
  let tag_lower = elem.tag.to_lower()
  if tag_lower == "input" && children.is_empty() {
    // Get input type (default is "text")
    let input_type = match elem.attributes.get("type") {
      Some(t) => t.to_lower()
      None => "text"
    }
    // Get intrinsic dimensions based on input type
    // These are approximate browser defaults
    let (intrinsic_width, intrinsic_height) : (Double, Double) = match
      input_type {
      "radio" | "checkbox" => (13.0, 13.0)
      "button" | "submit" | "reset" => (80.0, 21.0)
      "range" => (129.0, 21.0)
      "color" => (44.0, 23.0)
      "file" => (238.0, 21.0)
      // text, password, email, url, tel, search, number, date, etc.
      _ => (150.0, 21.0)
    }
    let measure = create_input_measure(intrinsic_width, intrinsic_height)
    let input_style : @style.Style = {
      ..style,
      width: if style.width == @types.Auto {
        @types.Length(intrinsic_width)
      } else {
        style.width
      },
      height: if style.height == @types.Auto {
        @types.Length(intrinsic_height)
      } else {
        style.height
      },
    }
    return @node.Node::with_measure(node_id, input_style, measure)
  }
  if tag_lower == "img" && children.is_empty() {
    // Get intrinsic dimensions from HTML attributes first
    let mut intrinsic_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(0.0)
      None => 0.0
    }
    let mut intrinsic_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(0.0)
      None => 0.0
    }
    // If no HTML attributes, try to get from src attribute
    if intrinsic_width == 0.0 && intrinsic_height == 0.0 {
      match elem.attributes.get("src") {
        Some(src) =>
          match get_image_intrinsic_size(src) {
            Some((w, h)) => {
              intrinsic_width = w
              intrinsic_height = h
            }
            None => ()
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
    let max_height_is_percent = match style.max_height {
      @types.Percent(_) => true
      _ => false
    }
    let max_width_is_percent = match style.max_width {
      @types.Percent(_) => true
      _ => false
    }

    // Handle img with intrinsic dimensions OR CSS percentage dimensions
    if intrinsic_width > 0.0 ||
      intrinsic_height > 0.0 ||
      height_is_percent ||
      width_is_percent ||
      max_height_is_percent ||
      max_width_is_percent {
      let measure = create_image_measure(intrinsic_width, intrinsic_height)
      // Get alt text for accessibility/placeholder display
      let alt_text = elem.attributes.get("alt")

      // Calculate intrinsic aspect ratio (width / height)
      let intrinsic_aspect_ratio = if intrinsic_height > 0.0 &&
        intrinsic_width > 0.0 {
        Some(intrinsic_width / intrinsic_height)
      } else {
        None
      }

      // Build img style similar to canvas:
      // - Use HTML attribute dimension as default when CSS is Auto
      // - CSS dimensions (%, px, etc.) override HTML attributes
      // - Set aspect ratio from intrinsic dimensions if not already set
      // - If height is %, keep width as Auto so aspect_ratio can compute it
      let img_style : @style.Style = {
        ..style,
        width: if style.width == @types.Auto {
          // If height is %, keep width Auto to let aspect_ratio compute it
          if height_is_percent {
            @types.Auto
          } else if intrinsic_width > 0.0 {
            @types.Length(intrinsic_width)
          } else {
            style.width
          }
        } else {
          style.width
        },
        height: if style.height == @types.Auto {
          // If width is %, keep height Auto to let aspect_ratio compute it
          if width_is_percent {
            @types.Auto
          } else if intrinsic_height > 0.0 {
            @types.Length(intrinsic_height)
          } else {
            style.height
          }
        } else {
          style.height
        },
        // Set aspect ratio from intrinsic dimensions (for % sizing)
        aspect_ratio: match style.aspect_ratio {
          Some(_) => style.aspect_ratio // Keep CSS-specified ratio
          None => intrinsic_aspect_ratio // Use intrinsic ratio
        },
      }
      return match alt_text {
        Some(alt) =>
          @node.Node::with_measure(node_id, img_style, measure, text=alt)
        None => @node.Node::with_measure(node_id, img_style, measure)
      }
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
    // - Use HTML attribute dimension as default when CSS is Auto
    // - CSS dimensions (%, px, etc.) override HTML attributes
    // - Set aspect ratio from intrinsic dimensions if not already set
    // - If height is %, keep width as Auto so aspect_ratio can compute it
    let height_is_percent = match style.height {
      @types.Percent(_) => true
      _ => false
    }
    let width_is_percent = match style.width {
      @types.Percent(_) => true
      _ => false
    }
    let canvas_style : @style.Style = {
      ..style,
      width: if style.width == @types.Auto {
        // If height is %, keep width Auto to let aspect_ratio compute it
        if height_is_percent {
          @types.Auto
        } else {
          @types.Length(intrinsic_width)
        }
      } else {
        style.width
      },
      height: if style.height == @types.Auto {
        // If width is %, keep height Auto to let aspect_ratio compute it
        if width_is_percent {
          @types.Auto
        } else {
          @types.Length(intrinsic_height)
        }
      } else {
        style.height
      },
      // Set aspect ratio from intrinsic dimensions (for % sizing)
      aspect_ratio: match style.aspect_ratio {
        Some(_) => style.aspect_ratio // Keep CSS-specified ratio
        None => intrinsic_aspect_ratio // Use intrinsic ratio
      },
    }

    // Always use MeasureFunc to provide intrinsic size
    // The layout algorithm will use CSS dimensions if specified
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, canvas_style, measure)
  }

  // Handle br element with line-height for height
  if tag_lower == "br" {
    // br elements have zero width but take up line-height vertically
    // line_height is already computed as absolute pixel value
    let measure = create_br_measure(style.line_height)
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
  parent : @selector.Element?,
) -> @selector.Element {
  let mut sel_elem = @selector.Element::new(elem.tag)

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
/// Convert HTML Element to Selector Element with parent and sibling info
fn html_to_selector_element_with_parent(
  elem : @html.Element,
  parent : @selector.Element,
  sibling_index : Int,
  sibling_count : Int,
) -> @selector.Element {
  let mut sel_elem = @selector.Element::new(elem.tag)

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
/// Get user-agent default style for an element tag
fn get_ua_default_style(tag : String) -> @style.Style {
  let default_style = @style.Style::default()

  // Default margins for block elements (based on typical browser defaults)
  // Values are in em units, converted to px assuming 16px base font
  match tag.to_lower() {
    "p" =>
      {
        // p has 1em margin-top and margin-bottom
        ..default_style,
        margin: @types.Rect::new(
          @types.Length(16.0),
          @types.Auto,
          @types.Length(16.0),
          @types.Auto,
        ),
      }
    "h1" =>
      {
        // h1 has 0.67em margin
        ..default_style,
        margin: @types.Rect::new(
          @types.Length(10.7),
          @types.Auto,
          @types.Length(10.7),
          @types.Auto,
        ),
      }
    "h2" =>
      {
        // h2 has 0.83em margin
        ..default_style,
        margin: @types.Rect::new(
          @types.Length(13.3),
          @types.Auto,
          @types.Length(13.3),
          @types.Auto,
        ),
      }
    "h3" =>
      {
        // h3 has 1em margin
        ..default_style,
        margin: @types.Rect::new(
          @types.Length(16.0),
          @types.Auto,
          @types.Length(16.0),
          @types.Auto,
        ),
      }
    "h4" | "h5" | "h6" =>
      {
        // h4-h6 have 1.33em margin
        ..default_style,
        margin: @types.Rect::new(
          @types.Length(21.3),
          @types.Auto,
          @types.Length(21.3),
          @types.Auto,
        ),
      }
    "ul" | "ol" => {
      // Lists have 1em margin and 40px padding-left
      let mut s = default_style
      s = {
        ..s,
        margin: @types.Rect::new(
          @types.Length(16.0),
          @types.Auto,
          @types.Length(16.0),
          @types.Auto,
        ),
      }
      {
        ..s,
        padding: @types.Rect::new(
          @types.Length(0.0),
          @types.Length(0.0),
          @types.Length(0.0),
          @types.Length(40.0),
        ),
      }
    }
    "blockquote" =>
      {
        // blockquote has 1em margin and 40px horizontal margins
        ..default_style,
        margin: @types.Rect::new(
          @types.Length(16.0),
          @types.Length(40.0),
          @types.Length(16.0),
          @types.Length(40.0),
        ),
      }
    // Pre element - preserve formatting, prevent wrapping
    "pre" =>
      {
        // pre has margin like p, and overflow hidden to prevent wrap issues
        ..default_style,
        display: @types.Block,
        overflow_x: @types.Hidden,
        margin: @types.Rect::new(
          @types.Length(16.0),
          @types.Auto,
          @types.Length(16.0),
          @types.Auto,
        ),
      }
    // Link element - blue color (standard browser UA style)
    "a" =>
      {
        ..default_style,
        display: @types.Inline,
        // Standard link blue: #0000EE (rgb(0, 0, 238))
        color: @types.Color::rgb(0, 0, 238),
      }
    // Inline elements - HTML default display: inline
    "span"
    | "em"
    | "strong"
    | "i"
    | "b"
    | "u"
    | "s"
    | "code"
    | "abbr"
    | "cite"
    | "dfn"
    | "kbd"
    | "samp"
    | "var"
    | "sub"
    | "sup"
    | "small"
    | "mark"
    | "del"
    | "ins"
    | "q"
    | "time"
    | "data"
    | "ruby"
    | "rt"
    | "rp"
    | "bdi"
    | "bdo"
    | "wbr" => { ..default_style, display: @types.Inline }
    // Replaced inline elements - inline by default
    // SVG has intrinsic size of 300x150 when no width/height specified
    "img"
    | "video"
    | "audio"
    | "canvas"
    | "iframe"
    | "object"
    | "embed"
    | "svg" => { ..default_style, display: @types.Inline }
    // SVG child elements - inline-block to fit content
    "g"
    | "rect"
    | "circle"
    | "ellipse"
    | "line"
    | "polyline"
    | "polygon"
    | "path"
    | "text"
    | "tspan"
    | "defs"
    | "use"
    | "symbol"
    | "clipPath"
    | "mask"
    | "pattern"
    | "linearGradient"
    | "radialGradient"
    | "stop"
    | "image"
    | "foreignObject" => { ..default_style, display: @types.InlineBlock }
    // Form elements - inline-block by default
    "input" | "button" | "select" | "textarea" =>
      { ..default_style, display: @types.InlineBlock }
    "label" => { ..default_style, display: @types.Inline }
    // br is inline with no width
    "br" => { ..default_style, display: @types.Inline }
    // Table elements
    "table" => { ..default_style, display: @types.Table }
    "tr" => { ..default_style, display: @types.TableRow }
    "td" | "th" => { ..default_style, display: @types.TableCell }
    "thead" => { ..default_style, display: @types.TableHeaderGroup }
    "tbody" => { ..default_style, display: @types.TableRowGroup }
    "tfoot" => { ..default_style, display: @types.TableFooterGroup }
    "caption" => { ..default_style, display: @types.TableCaption }
    "col" => { ..default_style, display: @types.TableColumn }
    "colgroup" => { ..default_style, display: @types.TableColumnGroup }
    // Hidden elements - display: none by default
    "template" | "script" | "style" | "head" | "meta" | "link" | "title" =>
      { ..default_style, display: @types.Display::None }
    _ => default_style
  }
}

///|
/// Compute element style using indexed stylesheets for better performance
fn compute_element_style_indexed(
  selector_elem : @selector.Element,
  inline_css : String?,
  indexed_stylesheets : Array[@cascade.IndexedStylesheet],
  is_root : Bool,
  ctx : RenderContext,
  parent_style : @style.Style?,
  css_vars : Map[String, String],
) -> @style.Style {
  // Create media environment for media query evaluation
  let media_env = @media.MediaEnvironment::with_color_scheme(
    ctx.viewport_width,
    ctx.viewport_height,
    ctx.color_scheme,
  )
  // Match stylesheets using index and get cascaded values
  let cascaded = @cascade.cascade_element_indexed(
    selector_elem,
    indexed_stylesheets,
    [],
    Some(media_env),
  )

  // Start with default style
  let mut style = @style.Style::default()

  // Inherit properties from parent first
  match parent_style {
    Some(ps) => {
      let lh_ratio = if ps.font_size > 0.0 {
        ps.line_height / ps.font_size
      } else {
        1.2
      }
      style = {
        ..style,
        color: ps.color,
        font_size: ps.font_size,
        line_height: ps.font_size * lh_ratio,
        writing_mode: ps.writing_mode,
      }
    }
    None => ()
  }

  // Apply user-agent default style
  let ua_style = get_ua_default_style(selector_elem.tag_name)
  if ua_style.color != @types.Color::black() {
    style = { ..style, color: ua_style.color }
  }
  style = { ..style, display: ua_style.display }
  style = { ..style, margin: ua_style.margin, padding: ua_style.padding }

  // Apply cascaded values
  for prop in cascaded.properties() {
    match cascaded.get_value(prop) {
      Some(value) =>
        style = apply_css_property_with_viewport(
          style,
          prop,
          value,
          ctx.viewport_width,
          ctx.viewport_height,
          css_vars,
        )
      None => ()
    }
  }

  // Preserve table layout
  let tag = selector_elem.tag_name
  if is_table_element(tag) {
    if not(is_table_display(style.display)) {
      style = { ..style, display: ua_style.display }
    }
  }

  // Apply inline styles
  match inline_css {
    Some(css) =>
      style = apply_inline_css_with_vars(
        style,
        css,
        css_vars,
        ctx.viewport_width,
        ctx.viewport_height,
      )
    None => ()
  }

  // Effects that establish a containing block for positioned descendants:
  // filter and backdrop-filter (non-none values).
  let mut establishes_effect_cb = false
  match cascaded.get_value("filter") {
    Some(value) =>
      if value.to_lower().trim() != "none" {
        establishes_effect_cb = true
      }
    None => ()
  }
  match cascaded.get_value("backdrop-filter") {
    Some(value) =>
      if value.to_lower().trim() != "none" {
        establishes_effect_cb = true
      }
    None => ()
  }
  match inline_css {
    Some(css) => {
      let lowered = css.to_lower()
      let has_filter = lowered.contains("filter:")
      let filter_none = lowered.contains("filter: none")
      if has_filter && not(filter_none) {
        establishes_effect_cb = true
      }
      let has_backdrop_filter = lowered.contains("backdrop-filter:")
      let backdrop_filter_none = lowered.contains("backdrop-filter: none")
      if has_backdrop_filter && not(backdrop_filter_none) {
        establishes_effect_cb = true
      }
    }
    None => ()
  }
  if establishes_effect_cb {
    style = { ..style, contain: { ..style.contain, paint: true } }
  }

  // Apply viewport dimensions if root
  if is_root {
    match style.width {
      @types.Dimension::Auto =>
        style = { ..style, width: @types.Dimension::Length(ctx.viewport_width) }
      _ => ()
    }
  }
  adjust_for_box_sizing(style)
}

///|
/// Apply a CSS property value to a style (internal)
/// Uses default viewport (1920x1080) for vh/vw resolution
fn apply_css_property(
  style : @style.Style,
  property : String,
  value : String,
) -> @style.Style {
  // Use direct property application to avoid string parsing overhead
  @computed.apply_property_direct(
    style,
    property,
    value,
    @computed.ComputeContext::new(),
  )
}

///|
/// Apply a CSS property value to a style with custom viewport and CSS variables
fn apply_css_property_with_viewport(
  style : @style.Style,
  property : String,
  value : String,
  viewport_width : Double,
  viewport_height : Double,
  css_vars : Map[String, String],
) -> @style.Style {
  // Use direct property application to avoid string parsing overhead
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width,
    viewport_height,
    custom_properties: css_vars,
  }
  @computed.apply_property_direct(style, property, value, ctx)
}

///|
/// Apply a CSS property value to a style (public for testing)
pub fn apply_css_property_debug(
  style : @style.Style,
  property : String,
  value : String,
) -> @style.Style {
  apply_css_property(style, property, value)
}

///|
/// Parse inline CSS and apply properties to style with CSS variables
fn apply_inline_css_with_vars(
  target : @style.Style,
  inline_css : String,
  css_vars : Map[String, String],
  viewport_width : Double,
  viewport_height : Double,
) -> @style.Style {
  // Parse the inline CSS to get property/value pairs
  // Format: "property1: value1; property2: value2"
  let mut result = target
  let decls = inline_css.split(";")
  for decl in decls {
    let decl_str = decl.trim()
    if decl_str.length() == 0 {
      continue
    }
    // Find the colon
    let mut colon_idx = -1
    for i = 0; i < decl_str.length(); i = i + 1 {
      if decl_str[i] == ':' {
        colon_idx = i
        break
      }
    }
    if colon_idx > 0 {
      try {
        let prop = decl_str[0:colon_idx].trim().to_string()
        let value = decl_str[colon_idx + 1:].trim().to_string()
        if prop.length() > 0 && value.length() > 0 {
          // Use viewport-aware property application with CSS variables
          result = apply_css_property_with_viewport(
            result, prop, value, viewport_width, viewport_height, css_vars,
          )
        }
      } catch {
        _ => ()
      }
    }
  }
  // Convert content-box dimensions to border-box dimensions
  // The layout engine always works with outer (border-box) dimensions
  adjust_for_box_sizing(result)
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
/// Adjust dimensions for box-sizing: content-box
/// When box-sizing is content-box (default), specified width/height are content dimensions.
/// The layout engine expects outer dimensions (border-box), so we adjust here.
fn adjust_for_box_sizing(style : @style.Style) -> @style.Style {
  match style.box_sizing {
    @types.BorderBox => style // No adjustment needed
    @types.ContentBox => {
      // Calculate padding and border sums
      let padding_h = resolve_dimension_to_px(style.padding.left) +
        resolve_dimension_to_px(style.padding.right)
      let padding_v = resolve_dimension_to_px(style.padding.top) +
        resolve_dimension_to_px(style.padding.bottom)
      let border_h = resolve_dimension_to_px(style.border.left) +
        resolve_dimension_to_px(style.border.right)
      let border_v = resolve_dimension_to_px(style.border.top) +
        resolve_dimension_to_px(style.border.bottom)

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
/// Create node ID from element
fn make_node_id(elem : @html.Element) -> String {
  match elem.id {
    Some(id) => elem.tag + "#" + id
    None =>
      if elem.classes.length() > 0 {
        elem.tag + "." + elem.classes[0]
      } else {
        elem.tag
      }
  }
}

///|
/// Render HTML to Sixel string (legacy, depth-based colors)
pub fn render_to_sixel(html : String, width : Int, height : Int) -> String {
  let ctx : RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = render(html, ctx)
  @sixel.render_layout(layout, width, height)
}

///|
/// Render HTML to Sixel string with actual CSS colors
pub fn render_to_sixel_with_styles(
  html : String,
  width : Int,
  height : Int,
) -> String {
  render_to_sixel_with_scroll(html, width, height, 0)
}

///|
/// Render HTML to Sixel string with actual CSS colors and scroll offset
pub fn render_to_sixel_with_scroll(
  html : String,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> String {
  render_to_sixel_with_css(html, width, height, scroll_y, [])
}

///|
/// Render HTML to Sixel with external CSS and scroll offset
pub fn render_to_sixel_with_css(
  html : String,
  width : Int,
  height : Int,
  scroll_y : Int,
  external_css : Array[String],
) -> String {
  let ctx : RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  // Get both Node tree (for styles) and Layout (for positions)
  let node = render_to_node_with_external_css(html, ctx, external_css)
  let layout = render_with_external_css(html, ctx, external_css)
  @sixel.render_with_styles_scrolled(node, layout, width, height, scroll_y)
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
    color_scheme: @media.ColorScheme::Light,
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
    color_scheme: @media.ColorScheme::Light,
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
    color_scheme: @media.ColorScheme::Light,
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

///|
/// Sanitize a number for JSON output (handle Infinity and NaN)
fn safe_number(n : Double) -> Double {
  // Check for Infinity or very large numbers (>= 1e10 is likely a placeholder infinity)
  if n >= 1.0e10 || n <= -1.0e10 {
    return 0.0
  }
  // Check for NaN (NaN != NaN)
  if n != n {
    return 0.0
  }
  n
}

///|
fn is_svg_container_id(id : String) -> Bool {
  let mut end = id.length()
  for i = 0; i < id.length(); i = i + 1 {
    let c = id[i]
    if c == '#' || c == '.' {
      end = i
      break
    }
  }
  let tag = if end < id.length() {
    id[:end].to_string() catch {
      _ => id
    }
  } else {
    id
  }
  match tag {
    "svg"
    | "g"
    | "defs"
    | "clipPath"
    | "mask"
    | "pattern"
    | "symbol"
    | "foreignObject" => true
    _ => false
  }
}

///|
fn establishes_absolute_containing_block(node : @node.Node) -> Bool {
  let style = node.style
  let positioned = match style.position {
    @types.Static => false
    _ => true
  }
  positioned ||
  style.contain.paint ||
  style.contain.layout ||
  not(style.transform.is_none()) ||
  is_svg_container_id(node.id)
}

///|
/// Apply zoom and transform scale to a layout tree
/// This modifies the layout dimensions to reflect the visual bounding box
/// as reported by getBoundingClientRect() in browsers
///
/// Note: While CSS zoom is inherited, transform scale is not. However, for
/// getBoundingClientRect() calculations, parent transform affects children's
/// visual bounding boxes. So we pass both zoom and parent_scale to children.
fn apply_zoom_and_scale(
  layout : @types.Layout,
  node : @node.Node,
  parent_zoom : Double,
  parent_scale_x : Double,
  parent_scale_y : Double,
  parent_global_x : Double,
  parent_global_y : Double,
) -> @types.Layout {
  // Calculate effective zoom (parent zoom * node zoom)
  let effective_zoom = parent_zoom * node.style.zoom

  // Calculate effective scale from transform (node's own scale)
  let node_scale_x = node.style.transform.scale_x
  let node_scale_y = node.style.transform.scale_y

  // Total scale = parent_scale * zoom * node_scale
  let total_scale_x = parent_scale_x * effective_zoom * node_scale_x
  let total_scale_y = parent_scale_y * effective_zoom * node_scale_y

  // Scale for children includes this node's transform (since parent transform affects children visually)
  let child_parent_scale_x = total_scale_x / effective_zoom // Remove node zoom, will be re-applied
  let child_parent_scale_y = total_scale_y / effective_zoom

  // Scale the layout dimensions
  let scaled_width = layout.width * total_scale_x
  let scaled_height = layout.height * total_scale_y

  // Compute translate offset (uses original layout dimensions before scaling)
  let translate_x = node.style.transform.compute_translate_x(layout.width)
  let translate_y = node.style.transform.compute_translate_y(layout.height)

  // Scale position (x, y are relative to parent, scaled by parent's total scale)
  // Add translate offset (translate is applied in local coordinates, then scaled)
  // CSS transforms scale around the element center by default (transform-origin: 50% 50%).
  let origin_adjust_x = (1.0 - node_scale_x) *
    layout.width /
    2.0 *
    parent_scale_x *
    effective_zoom
  let origin_adjust_y = (1.0 - node_scale_y) *
    layout.height /
    2.0 *
    parent_scale_y *
    effective_zoom
  let scaled_x = layout.x * parent_scale_x * effective_zoom +
    translate_x * parent_scale_x * effective_zoom +
    origin_adjust_x
  let scaled_y = layout.y * parent_scale_y * effective_zoom +
    translate_y * parent_scale_y * effective_zoom +
    origin_adjust_y
  let global_x = parent_global_x + scaled_x
  let global_y = parent_global_y + scaled_y

  // Process children with updated parent zoom and scale
  let scaled_children : Array[@types.Layout] = []
  let min_len = if layout.children.length() < node.children.length() {
    layout.children.length()
  } else {
    node.children.length()
  }
  for i = 0; i < min_len; i = i + 1 {
    let child_layout = layout.children[i]
    let child_node = node.children[i]
    let scaled_child = apply_zoom_and_scale(
      child_layout, child_node, effective_zoom, child_parent_scale_x, child_parent_scale_y,
      global_x, global_y,
    )
    if child_node.style.position == @types.Absolute &&
      not(establishes_absolute_containing_block(node)) {
      // Absolute descendants without a containing block are viewport-relative.
      scaled_children.push({
        ..scaled_child,
        x: scaled_child.x - global_x,
        y: scaled_child.y - global_y,
      })
    } else {
      scaled_children.push(scaled_child)
    }
  }
  // Add any remaining layout children without scaling (shouldn't happen in practice)
  for i = min_len; i < layout.children.length(); i = i + 1 {
    scaled_children.push(layout.children[i])
  }

  // Scale margin, padding, border
  let scaled_margin : @types.Rect[Double] = {
    left: layout.margin.left * total_scale_x,
    right: layout.margin.right * total_scale_x,
    top: layout.margin.top * total_scale_y,
    bottom: layout.margin.bottom * total_scale_y,
  }
  let scaled_padding : @types.Rect[Double] = {
    left: layout.padding.left * total_scale_x,
    right: layout.padding.right * total_scale_x,
    top: layout.padding.top * total_scale_y,
    bottom: layout.padding.bottom * total_scale_y,
  }
  let scaled_border : @types.Rect[Double] = {
    left: layout.border.left * total_scale_x,
    right: layout.border.right * total_scale_x,
    top: layout.border.top * total_scale_y,
    bottom: layout.border.bottom * total_scale_y,
  }
  {
    id: layout.id,
    x: scaled_x,
    y: scaled_y,
    width: scaled_width,
    height: scaled_height,
    margin: scaled_margin,
    padding: scaled_padding,
    border: scaled_border,
    overflow_x: layout.overflow_x,
    overflow_y: layout.overflow_y,
    scroll_width: layout.scroll_width * total_scale_x,
    scroll_height: layout.scroll_height * total_scale_y,
    children: scaled_children,
    text: layout.text,
  }
}

///|
/// Convert a number to JSON string safely
fn number_to_json(n : Double) -> String {
  safe_number(n).to_string()
}

///|
/// Convert Rect to JSON string
fn rect_to_json(rect : @types.Rect[Double]) -> String {
  "{\"top\":" +
  number_to_json(rect.top) +
  ",\"right\":" +
  number_to_json(rect.right) +
  ",\"bottom\":" +
  number_to_json(rect.bottom) +
  ",\"left\":" +
  number_to_json(rect.left) +
  "}"
}

///|
/// Convert layout to JSON string (with Box Model)
pub fn layout_to_json(layout : @types.Layout) -> String {
  let buf = StringBuilder::new()
  layout_to_json_impl(layout, buf)
  buf.to_string()
}

///|
fn layout_to_json_impl(layout : @types.Layout, buf : StringBuilder) -> Unit {
  buf.write_string("{\"id\":\"")
  buf.write_string(escape_json_string(layout.id))
  buf.write_string("\",\"x\":")
  buf.write_string(number_to_json(layout.x))
  buf.write_string(",\"y\":")
  buf.write_string(number_to_json(layout.y))
  buf.write_string(",\"width\":")
  buf.write_string(number_to_json(layout.width))
  buf.write_string(",\"height\":")
  buf.write_string(number_to_json(layout.height))
  buf.write_string(",\"margin\":")
  buf.write_string(rect_to_json(layout.margin))
  buf.write_string(",\"padding\":")
  buf.write_string(rect_to_json(layout.padding))
  buf.write_string(",\"border\":")
  buf.write_string(rect_to_json(layout.border))
  buf.write_string(",\"children\":[")
  for i, child in layout.children {
    if i > 0 {
      buf.write_string(",")
    }
    layout_to_json_impl(child, buf)
  }
  buf.write_string("]}")
}

///|
/// Escape special characters in JSON string
fn escape_json_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}
