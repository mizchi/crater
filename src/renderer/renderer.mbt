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
  let trimmed = text.trim()
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
      let mut total_lines = 0
      let mut current_line_width = 0
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
          not(will_have_non_inline_display(child_elem, stylesheets, ctx)) {
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
          // Insert newline for <br>
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
          if contains_replaced_element(elem) {
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
  if trimmed.is_empty() {
    // Return a zero-size node for whitespace-only text
    @node.Node::leaf("#text", @style.Style::default())
  } else {
    // Use parent's font_size and line_height for text measurement
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
    (ctx.viewport_width - layout.width) / 2.0
  } else if margin_left_is_auto {
    // Push to right
    ctx.viewport_width - layout.width - root_margin.right
  } else {
    // Use left margin
    root_margin.left
  }
  {
    id: layout.id,
    x: x_offset,
    y: root_margin.top,
    width: layout.width,
    height: layout.height,
    margin: layout.margin,
    padding: layout.padding,
    border: layout.border,
    overflow_x: layout.overflow_x,
    overflow_y: layout.overflow_y,
    scroll_width: layout.scroll_width,
    scroll_height: layout.scroll_height,
    children: layout.children,
    text: layout.text,
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
    (ctx.viewport_width - layout.width) / 2.0
  } else if margin_left_is_auto {
    // Push to right
    ctx.viewport_width - layout.width - root_margin.right
  } else {
    // Use left margin
    root_margin.left
  }
  {
    id: layout.id,
    x: x_offset,
    y: root_margin.top,
    width: layout.width,
    height: layout.height,
    margin: layout.margin,
    padding: layout.padding,
    border: layout.border,
    overflow_x: layout.overflow_x,
    overflow_y: layout.overflow_y,
    scroll_width: layout.scroll_width,
    scroll_height: layout.scroll_height,
    children: layout.children,
    text: layout.text,
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
  element_to_node_with_styles(
    render_root,
    None,
    ctx,
    stylesheets,
    indexed_stylesheets,
    css_vars,
  )
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
  element_to_node_with_styles(
    render_root,
    None,
    ctx,
    stylesheets,
    indexed_stylesheets,
    css_vars,
  )
}

///|
/// Check if tag is an SVG element
fn is_svg_element(tag : String) -> Bool {
  match tag {
    "svg" | "g" | "rect" | "circle" | "ellipse" | "line" | "polyline" | "polygon"
    | "path" | "text" | "tspan" | "defs" | "use" | "symbol" | "clipPath" | "mask"
    | "pattern" | "linearGradient" | "radialGradient" | "stop" | "image"
    | "foreignObject" | "switch" | "a" => true
    // Note: "a" in SVG context is an SVG element, but we can't distinguish here
    // It will be handled by context in the future
    _ => false
  }
}

///|
/// Apply SVG attributes (width, height) to style
fn apply_svg_attributes_to_style(
  style : @style.Style,
  attrs : Map[String, String]
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

  result
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
    trimmed.substring(end=trimmed.length() - 2)
  } else if trimmed.has_suffix("pt") {
    trimmed.substring(end=trimmed.length() - 2)
  } else if trimmed.has_suffix("em") || trimmed.has_suffix("ex") {
    // em/ex are relative units, treat as pixels for now
    trimmed.substring(end=trimmed.length() - 2)
  } else if trimmed.has_suffix("%") {
    // Percentage - return 0 to skip (handled by CSS)
    return 0.0
  } else {
    trimmed
  }

  @strconv.parse_double(num_str) catch { _ => 0.0 }
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
        // to preserve DOM order when elements are interleaved with text
        if not(text.trim().is_empty()) {
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
        // to preserve DOM order when elements are interleaved with text
        if not(text.trim().is_empty()) {
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

    // Handle img with intrinsic dimensions OR CSS percentage dimensions
    if intrinsic_width > 0.0 ||
      intrinsic_height > 0.0 ||
      height_is_percent ||
      width_is_percent {
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
    "img" | "video" | "audio" | "canvas" | "iframe" | "object" | "embed" | "svg" =>
      { ..default_style, display: @types.Inline }
    // SVG child elements - inline-block to fit content
    "g" | "rect" | "circle" | "ellipse" | "line" | "polyline" | "polygon" | "path"
    | "text" | "tspan" | "defs" | "use" | "symbol" | "clipPath" | "mask" | "pattern"
    | "linearGradient" | "radialGradient" | "stop" | "image" | "foreignObject" =>
      { ..default_style, display: @types.InlineBlock }
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
