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
fn create_text_measure(
  text : String,
  font_size : Double,
  text_line_height : Double,
) -> @node.MeasureFunc {
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

  // max_width is the widest line (for intrinsic sizing)
  let text_max_width = max_line_width.to_double() * char_width
  // min_width is the longest word
  let text_min_width = max_word_width.to_double() * char_width
  // min_height accounts for explicit line breaks
  let min_lines = explicit_lines
  {
    func: fn(
      available_width : Double,
      _available_height : Double,
    ) -> @node.IntrinsicSize {
      // Calculate how many single-width columns fit in available width
      let cols_available = if available_width > 0.0 {
        (available_width / char_width).to_int()
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
      let height = total_lines.to_double() * text_line_height
      let min_height = min_lines.to_double() * text_line_height
      {
        min_width: text_min_width,
        max_width: text_max_width,
        min_height,
        max_height: height,
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
        @style.Block | @style.Flex | @style.Grid => true
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
fn collect_inline_content(
  children : Array[@html.Node],
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
) -> (String, Array[@html.Node]) {
  let text_builder = StringBuilder::new()
  let remaining : Array[@html.Node] = []
  let mut has_inline_content = false
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
          // Replaced elements (img, input, etc.) are kept as separate nodes
          // They have intrinsic dimensions and shouldn't be merged into text
          remaining.push(child)
        } else if is_inline_element(elem) &&
          not(will_have_non_inline_display(elem, stylesheets, ctx)) {
          // Check if this inline element contains replaced elements (like <a><img></a>)
          if contains_replaced_element(elem) {
            // Keep as separate node to preserve replaced element children
            remaining.push(child)
          } else if tag_lower == "a" {
            // Keep <a> elements as separate nodes to preserve link styling (blue color)
            remaining.push(child)
          } else {
            // Recursively collect text from inline elements (span, em, etc.)
            // Only if CSS doesn't set display: inline-block or other non-inline value
            collect_text_from_inline(elem, text_builder, stylesheets, ctx)
            has_inline_content = true
          }
        } else {
          // Block-level elements (or elements with CSS non-inline display) go to remaining
          remaining.push(child)
        }
      }
    }
  }
  if has_inline_content {
    (text_builder.to_string(), remaining)
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
    // Create text style with inherited font properties and color for rendering
    // Text nodes should be inline-level to flow with other inline content
    let text_style : @style.Style = {
      ..@style.Style::default(),
      display: @style.Inline,
      font_size,
      line_height: text_line_height,
      color: parent_style.color,
    }
    // Use Node::text to store the text content for rendering
    @node.Node::text(
      "#text",
      text_style,
      create_text_measure(text, font_size, text_line_height),
      trimmed.to_string(),
    )
  }
}

///|
/// Create a MeasureFunc for image with intrinsic dimensions
fn create_image_measure(
  intrinsic_width : Double,
  intrinsic_height : Double,
) -> @node.MeasureFunc {
  {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @node.IntrinsicSize {
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
) -> @node.MeasureFunc {
  {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @node.IntrinsicSize {
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
  _parent_style : @style.Style?,
) -> @node.Node {
  // Compute style from inline style attribute
  let ctx = @computed.ComputeContext::new()
  let style = match elem.style {
    Some(css) => @computed.compute_inline(css, ctx)
    None => @style.Style::default()
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
pub fn render(html : String, ctx : RenderContext) -> @node.Layout {
  render_with_external_css(html, ctx, [])
}

///|
/// Render HTML string to Layout with external CSS
pub fn render_with_external_css(
  html : String,
  ctx : RenderContext,
  external_css : Array[String],
) -> @node.Layout {
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
    css_vars,
  )

  // Create layout context - subtract root margin from available space
  let root_margin = @types.resolve_rect(root.style.margin, ctx.viewport_width)
  let available_width = ctx.viewport_width -
    root_margin.left -
    root_margin.right
  // Use None for available_height to allow content to grow naturally (scrollable)
  // If we pass Some(viewport_height), the layout might constrain to viewport
  let layout_ctx : @node.LayoutContext = {
    available_width,
    available_height: None,
    sizing_mode: @node.SizingMode::Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }

  // Initialize the layout dispatcher for cross-layout-type support
  @dispatch.setup()

  // Compute layout using dispatcher (handles display type switching)
  let layout = @dispatch.compute(root, layout_ctx)

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
) -> @node.Layout {
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
    css_vars,
  )

  // Create layout context - subtract root margin from available space
  let root_margin = @types.resolve_rect(root.style.margin, ctx.viewport_width)
  let available_width = ctx.viewport_width -
    root_margin.left -
    root_margin.right
  // Use None for available_height to allow content to grow naturally (scrollable)
  // If we pass Some(viewport_height), the layout might constrain to viewport
  let layout_ctx : @node.LayoutContext = {
    available_width,
    available_height: None,
    sizing_mode: @node.SizingMode::Definite,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }

  // Initialize the layout dispatcher for cross-layout-type support
  @dispatch.setup()

  // Compute layout
  let layout = @dispatch.compute(root, layout_ctx)

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
  // Collect CSS custom properties from :root rules
  let css_vars = collect_root_css_variables(stylesheets, ctx)
  let render_root = match find_body(doc.root) {
    Some(body) => body
    None => doc.root
  }
  element_to_node_with_styles(render_root, None, ctx, stylesheets, css_vars)
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
  // Collect CSS custom properties from :root rules
  let css_vars = collect_root_css_variables(stylesheets, ctx)
  let render_root = match find_body(doc.root) {
    Some(body) => body
    None => doc.root
  }
  element_to_node_with_styles(render_root, None, ctx, stylesheets, css_vars)
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
    | "canvas"
    | "svg"
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
  css_vars : Map[String, String],
) -> @node.Node {
  // Convert HTML element to selector element for matching
  let selector_elem = html_to_selector_element(elem, parent)

  // Get style from stylesheet matching + inline style
  let computed_style = compute_element_style(
    selector_elem,
    elem.style,
    stylesheets,
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

  // Process remaining block-level children
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
          Some(style),
          css_vars,
        )
        children.push(child_node)
      }
      @html.Node::Text(_text) =>
        // Text should have been collected by collect_inline_content
        ()
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
  parent_style : @style.Style?,
  css_vars : Map[String, String],
) -> @node.Node {
  // Get style from stylesheet matching + inline style
  let computed_style = compute_element_style(
    selector_elem,
    elem.style,
    stylesheets,
    false,
    ctx,
    parent_style,
    css_vars,
  )

  // If this is an inline element containing replaced elements (like <a><img></a>),
  // treat it as inline-block so it gets proper sizing from its content
  let style = if computed_style.display == @style.Inline &&
    contains_replaced_element(elem) {
    { ..computed_style, display: @style.InlineBlock }
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

  // Process remaining block-level children
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
          Some(style),
          css_vars,
        )
        children.push(child_node)
      }
      @html.Node::Text(_text) =>
        // Text should have been collected by collect_inline_content
        // This shouldn't happen, but handle it just in case
        ()
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
    // If intrinsic dimensions are specified, create a node with explicit dimensions
    // Setting explicit width/height in style prevents flex stretch from overriding
    if intrinsic_width > 0.0 || intrinsic_height > 0.0 {
      let measure = create_image_measure(intrinsic_width, intrinsic_height)
      // Get alt text for accessibility/placeholder display
      let alt_text = elem.attributes.get("alt")
      // Create a new style with explicit width/height to prevent flex stretch
      let img_style : @style.Style = {
        ..style,
        width: if intrinsic_width > 0.0 {
          @types.Length(intrinsic_width)
        } else {
          style.width
        },
        height: if intrinsic_height > 0.0 {
          @types.Length(intrinsic_height)
        } else {
          style.height
        },
      }
      return match alt_text {
        Some(alt) =>
          @node.Node::with_measure(node_id, img_style, measure, text=alt)
        None => @node.Node::with_measure(node_id, img_style, measure)
      }
    }
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
fn is_table_display(display : @style.Display) -> Bool {
  match display {
    @style.Table
    | @style.InlineTable
    | @style.TableRow
    | @style.TableCell
    | @style.TableCaption
    | @style.TableRowGroup
    | @style.TableHeaderGroup
    | @style.TableFooterGroup
    | @style.TableColumn
    | @style.TableColumnGroup => true
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
        display: @style.Block,
        overflow_x: @style.Hidden,
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
        display: @style.Inline,
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
    | "wbr" => { ..default_style, display: @style.Inline }
    // Replaced inline elements - inline by default
    "img" | "video" | "audio" | "canvas" | "iframe" | "object" | "embed" =>
      { ..default_style, display: @style.Inline }
    // Form elements - inline-block by default
    "input" | "button" | "select" | "textarea" =>
      { ..default_style, display: @style.InlineBlock }
    "label" => { ..default_style, display: @style.Inline }
    // br is inline with no width
    "br" => { ..default_style, display: @style.Inline }
    // Table elements
    "table" => { ..default_style, display: @style.Table }
    "tr" => { ..default_style, display: @style.TableRow }
    "td" | "th" => { ..default_style, display: @style.TableCell }
    "thead" => { ..default_style, display: @style.TableHeaderGroup }
    "tbody" => { ..default_style, display: @style.TableRowGroup }
    "tfoot" => { ..default_style, display: @style.TableFooterGroup }
    "caption" => { ..default_style, display: @style.TableCaption }
    "col" => { ..default_style, display: @style.TableColumn }
    "colgroup" => { ..default_style, display: @style.TableColumnGroup }
    // Hidden elements - display: none by default
    "template" | "script" | "style" | "head" | "meta" | "link" | "title" =>
      { ..default_style, display: @style.None }
    _ => default_style
  }
}

///|
/// Compute element style from stylesheet matches and inline style
fn compute_element_style(
  selector_elem : @selector.Element,
  inline_css : String?,
  stylesheets : Array[@cascade.Stylesheet],
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
  // Match stylesheets and get cascaded values with media query evaluation
  let cascaded = @cascade.cascade_element_with_media(
    selector_elem,
    stylesheets,
    [],
    Some(media_env),
  )

  // Start with default style
  let mut style = @style.Style::default()

  // Inherit properties from parent first
  // CSS inherited properties: color, font-size, line-height, visibility, etc.
  match parent_style {
    Some(ps) => {
      // Calculate line-height ratio from parent
      let lh_ratio = if ps.font_size > 0.0 {
        ps.line_height / ps.font_size
      } else {
        1.2 // Default ratio
      }
      // Apply inherited properties (color and font properties)
      style = {
        ..style,
        color: ps.color, // CSS color is inherited
        font_size: ps.font_size,
        line_height: ps.font_size * lh_ratio,
      }
    }
    None => ()
  }

  // Apply user-agent default style (UA styles override inherited values)
  let ua_style = get_ua_default_style(selector_elem.tag_name)
  // Only apply UA color if it's explicitly set (not default black)
  // This allows UA stylesheet to set link color to blue
  if ua_style.color != @types.Color::black() {
    style = { ..style, color: ua_style.color }
  }
  // Apply display from UA style
  style = { ..style, display: ua_style.display }
  // Apply margin/padding from UA style if set
  style = { ..style, margin: ua_style.margin, padding: ua_style.padding }

  // Apply cascaded values with correct viewport and CSS variables
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

  // Preserve table layout for table elements even if CSS overrides display
  // This handles cases where generic classes (like .code-line) set display: block
  // on table elements, breaking table layout. We preserve the UA default display
  // for table-related HTML elements to ensure proper table rendering.
  let tag = selector_elem.tag_name
  if is_table_element(tag) {
    // If CSS changed display to a non-table value, restore the UA default
    if not(is_table_display(style.display)) {
      style = { ..style, display: ua_style.display }
    }
  }

  // Apply inline styles (override stylesheet styles)
  // Parse inline CSS properties and apply them one by one
  match inline_css {
    Some(css) => style = apply_inline_css_with_vars(style, css, css_vars)
    None => ()
  }

  // Apply viewport dimensions if this is the root element
  if is_root {
    match style.width {
      @types.Dimension::Auto =>
        style = { ..style, width: @types.Dimension::Length(ctx.viewport_width) }
      _ => ()
    }
    // height: auto - let block layout calculate from content
  }

  // Adjust dimensions for box-sizing: content-box
  // This handles both stylesheet and inline styles
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
  // Use the inline parser's logic to parse and apply the value
  // Use compute_inline_raw to avoid premature box-sizing adjustment
  // The caller (apply_inline_css) will handle box-sizing adjustment after all properties are applied
  let css = property + ": " + value
  let parsed = @computed.compute_inline_raw(
    css,
    @computed.ComputeContext::new(),
  )

  // Merge the parsed property into the style
  merge_style_property(style, parsed, property)
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
  // Use the inline parser's logic to parse and apply the value
  // Use compute_inline_raw to avoid premature box-sizing adjustment
  // The caller will handle box-sizing adjustment after all properties are applied
  let css = property + ": " + value
  // Create context with CSS custom properties for var() resolution
  let ctx : @computed.ComputeContext = {
    parent_style: None,
    root_font_size: 16.0,
    font_size: 16.0,
    viewport_width,
    viewport_height,
    custom_properties: css_vars,
  }
  let parsed = @computed.compute_inline_raw(css, ctx)

  // Merge the parsed property into the style
  merge_style_property(style, parsed, property)
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
            result, prop, value, 1920.0, 1080.0, css_vars,
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
    @style.BorderBox => style // No adjustment needed
    @style.ContentBox => {
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
        @types.Length(w) => @types.Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_height = match style.height {
        @types.Length(h) => @types.Length(h + padding_v + border_v)
        other => other
      }
      // Adjust min/max constraints too
      let adjusted_min_width = match style.min_width {
        @types.Length(w) => @types.Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_min_height = match style.min_height {
        @types.Length(h) => @types.Length(h + padding_v + border_v)
        other => other
      }
      let adjusted_max_width = match style.max_width {
        @types.Length(w) => @types.Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_max_height = match style.max_height {
        @types.Length(h) => @types.Length(h + padding_v + border_v)
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
        box_sizing: @style.BorderBox,
      }
    }
  }
}

///|
/// Merge a single property from source style to target
fn merge_style_property(
  target : @style.Style,
  source : @style.Style,
  property : String,
) -> @style.Style {
  // Apply the specific property from source to target
  if property == "display" {
    return { ..target, display: source.display }
  }
  if property == "box-sizing" {
    return { ..target, box_sizing: source.box_sizing }
  }
  if property == "width" {
    return { ..target, width: source.width }
  }
  if property == "height" {
    return { ..target, height: source.height }
  }
  if property == "min-width" {
    return { ..target, min_width: source.min_width }
  }
  if property == "min-height" {
    return { ..target, min_height: source.min_height }
  }
  if property == "max-width" {
    return { ..target, max_width: source.max_width }
  }
  if property == "max-height" {
    return { ..target, max_height: source.max_height }
  }
  // Logical properties (horizontal-tb writing mode only)
  if property == "inline-size" {
    return { ..target, width: source.width }
  }
  if property == "block-size" {
    return { ..target, height: source.height }
  }
  if property == "min-inline-size" {
    return { ..target, min_width: source.min_width }
  }
  if property == "min-block-size" {
    return { ..target, min_height: source.min_height }
  }
  if property == "max-inline-size" {
    return { ..target, max_width: source.max_width }
  }
  if property == "max-block-size" {
    return { ..target, max_height: source.max_height }
  }
  if property == "flex-direction" {
    return { ..target, flex_direction: source.flex_direction }
  }
  if property == "flex-wrap" {
    return { ..target, flex_wrap: source.flex_wrap }
  }
  if property == "flex-grow" {
    return { ..target, flex_grow: source.flex_grow }
  }
  if property == "flex-shrink" {
    return { ..target, flex_shrink: source.flex_shrink }
  }
  if property == "flex-basis" {
    return { ..target, flex_basis: source.flex_basis }
  }
  if property == "flex" {
    return {
      ..target,
      flex_grow: source.flex_grow,
      flex_shrink: source.flex_shrink,
      flex_basis: source.flex_basis,
    }
  }
  if property == "flex-flow" {
    return {
      ..target,
      flex_direction: source.flex_direction,
      flex_wrap: source.flex_wrap,
    }
  }
  if property == "order" {
    return { ..target, order: source.order }
  }
  if property == "gap" {
    return { ..target, row_gap: source.row_gap, column_gap: source.column_gap }
  }
  if property == "margin" {
    return { ..target, margin: source.margin }
  }
  if property == "margin-top" {
    return { ..target, margin: { ..target.margin, top: source.margin.top } }
  }
  if property == "margin-bottom" {
    return {
      ..target,
      margin: { ..target.margin, bottom: source.margin.bottom },
    }
  }
  if property == "margin-left" {
    return { ..target, margin: { ..target.margin, left: source.margin.left } }
  }
  if property == "margin-right" {
    return { ..target, margin: { ..target.margin, right: source.margin.right } }
  }
  if property == "padding" {
    return { ..target, padding: source.padding }
  }
  if property == "padding-top" {
    return { ..target, padding: { ..target.padding, top: source.padding.top } }
  }
  if property == "padding-bottom" {
    return {
      ..target,
      padding: { ..target.padding, bottom: source.padding.bottom },
    }
  }
  if property == "padding-left" {
    return {
      ..target,
      padding: { ..target.padding, left: source.padding.left },
    }
  }
  if property == "padding-right" {
    return {
      ..target,
      padding: { ..target.padding, right: source.padding.right },
    }
  }
  // Border properties
  if property == "border" {
    return { ..target, border: source.border }
  }
  if property == "border-width" {
    return { ..target, border: source.border }
  }
  if property == "border-top" || property == "border-top-width" {
    return { ..target, border: { ..target.border, top: source.border.top } }
  }
  if property == "border-bottom" || property == "border-bottom-width" {
    return {
      ..target,
      border: { ..target.border, bottom: source.border.bottom },
    }
  }
  if property == "border-left" || property == "border-left-width" {
    return { ..target, border: { ..target.border, left: source.border.left } }
  }
  if property == "border-right" || property == "border-right-width" {
    return { ..target, border: { ..target.border, right: source.border.right } }
  }
  // Table properties
  if property == "border-spacing" {
    return { ..target, border_spacing: source.border_spacing }
  }
  if property == "border-collapse" {
    return { ..target, border_collapse: source.border_collapse }
  }
  if property == "table-layout" {
    return { ..target, table_layout: source.table_layout }
  }
  // Flexbox alignment properties
  if property == "justify-content" {
    return { ..target, justify_content: source.justify_content }
  }
  if property == "align-items" {
    return { ..target, align_items: source.align_items }
  }
  if property == "align-content" {
    return { ..target, align_content: source.align_content }
  }
  if property == "align-self" {
    return { ..target, align_self: source.align_self }
  }
  // Float properties
  if property == "float" {
    return { ..target, float: source.float }
  }
  if property == "clear" {
    return { ..target, clear: source.clear }
  }
  // Grid properties
  if property == "grid-template-columns" {
    return { ..target, grid_template_columns: source.grid_template_columns }
  }
  if property == "grid-template-rows" {
    return { ..target, grid_template_rows: source.grid_template_rows }
  }
  if property == "grid-auto-flow" {
    return { ..target, grid_auto_flow: source.grid_auto_flow }
  }
  // Grid placement properties
  if property == "grid-column" {
    return { ..target, grid_column: source.grid_column }
  }
  if property == "grid-column-start" {
    return {
      ..target,
      grid_column: { ..target.grid_column, start: source.grid_column.start },
    }
  }
  if property == "grid-column-end" {
    return {
      ..target,
      grid_column: { ..target.grid_column, end: source.grid_column.end },
    }
  }
  if property == "grid-row" {
    return { ..target, grid_row: source.grid_row }
  }
  if property == "grid-row-start" {
    return {
      ..target,
      grid_row: { ..target.grid_row, start: source.grid_row.start },
    }
  }
  if property == "grid-row-end" {
    return {
      ..target,
      grid_row: { ..target.grid_row, end: source.grid_row.end },
    }
  }
  // Font properties (for baseline calculation)
  if property == "font-size" {
    // When font-size changes, update line-height proportionally
    // to maintain the same ratio (typically "normal" = 1.0-1.2)
    let old_fs = target.font_size
    let new_fs = source.font_size
    let lh_ratio = if old_fs > 0.0 {
      target.line_height / old_fs
    } else {
      1.0 // Default to 1.0 ratio for "normal"
    }
    return { ..target, font_size: new_fs, line_height: new_fs * lh_ratio }
  }
  if property == "line-height" {
    return { ..target, line_height: source.line_height }
  }
  // Font shorthand - applies both font-size and line-height
  if property == "font" {
    return {
      ..target,
      font_size: source.font_size,
      line_height: source.line_height,
    }
  }
  // Logical border properties (block/inline)
  if property == "border-block" || property == "border-block-width" {
    return {
      ..target,
      border: {
        ..target.border,
        top: source.border.top,
        bottom: source.border.bottom,
      },
    }
  }
  if property == "border-inline" || property == "border-inline-width" {
    return {
      ..target,
      border: {
        ..target.border,
        left: source.border.left,
        right: source.border.right,
      },
    }
  }
  // Logical padding properties (block/inline)
  if property == "padding-block" {
    return {
      ..target,
      padding: {
        ..target.padding,
        top: source.padding.top,
        bottom: source.padding.bottom,
      },
    }
  }
  if property == "padding-inline" {
    return {
      ..target,
      padding: {
        ..target.padding,
        left: source.padding.left,
        right: source.padding.right,
      },
    }
  }
  // Aspect ratio
  if property == "aspect-ratio" {
    return { ..target, aspect_ratio: source.aspect_ratio }
  }
  // Position properties
  if property == "position" {
    return { ..target, position: source.position }
  }
  // Inset properties (top, right, bottom, left)
  if property == "top" {
    return { ..target, inset: { ..target.inset, top: source.inset.top } }
  }
  if property == "right" {
    return { ..target, inset: { ..target.inset, right: source.inset.right } }
  }
  if property == "bottom" {
    return { ..target, inset: { ..target.inset, bottom: source.inset.bottom } }
  }
  if property == "left" {
    return { ..target, inset: { ..target.inset, left: source.inset.left } }
  }
  if property == "inset" {
    return { ..target, inset: source.inset }
  }
  // CSS Containment
  if property == "contain" {
    return { ..target, contain: source.contain }
  }
  // Color properties
  if property == "background-color" || property == "background" {
    return { ..target, background_color: source.background_color }
  }
  if property == "color" {
    return { ..target, color: source.color }
  }
  // Overflow properties
  if property == "overflow" {
    return {
      ..target,
      overflow_x: source.overflow_x,
      overflow_y: source.overflow_y,
    }
  }
  if property == "overflow-x" {
    return { ..target, overflow_x: source.overflow_x }
  }
  if property == "overflow-y" {
    return { ..target, overflow_y: source.overflow_y }
  }
  // Clip property (legacy, for accessibility patterns)
  if property == "clip" {
    return { ..target, clip: source.clip }
  }
  target
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
fn calculate_content_extent(layout : @node.Layout) -> Double {
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
pub fn print_layout_tree(layout : @node.Layout, indent : Int) -> Unit {
  print_layout_tree_with_options(layout, indent, false)
}

///|
/// Print layout tree with optional detailed box model info
pub fn print_layout_tree_with_options(
  layout : @node.Layout,
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
  // Check for Infinity or very large numbers (> 1e10 is likely a placeholder infinity)
  if n > 1.0e10 || n < -1.0e10 {
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
pub fn layout_to_json(layout : @node.Layout) -> String {
  let buf = StringBuilder::new()
  layout_to_json_impl(layout, buf)
  buf.to_string()
}

///|
fn layout_to_json_impl(layout : @node.Layout, buf : StringBuilder) -> Unit {
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
