///|
/// HTML/CSS Renderer
/// Converts HTML elements with inline styles to layout

///|
/// Text measurement constants (monospace font simulation)
/// These approximate a typical monospace font at 16px
let char_width : Double = 9.6 // Average character width at 16px (single-width)

///|
let line_height : Double = 20.0 // Line height at 16px

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
/// Calculate total display width of a string (accounting for wide characters)
fn string_display_width(s : StringView) -> Int {
  let mut width = 0
  for c in s.iter() {
    width = width + char_display_width(c)
  }
  width
}

///|
/// Render context with viewport dimensions
pub(all) struct RenderContext {
  viewport_width : Double
  viewport_height : Double
  root_font_size : Double
}

///|
pub fn RenderContext::default() -> RenderContext {
  { viewport_width: 800.0, viewport_height: 600.0, root_font_size: 16.0 }
}

///|
/// Create a MeasureFunc for text content
/// Calculates text dimensions based on monospace character width
/// Accounts for East Asian Wide characters (CJK) which take 2 columns
fn create_text_measure(text : String) -> @node.MeasureFunc {
  // Count display width (accounting for wide characters like CJK)
  let trimmed = text.trim()
  let display_width = string_display_width(trimmed)

  // Calculate intrinsic width (single line, no wrapping)
  let text_max_width = display_width.to_double() * char_width

  // For min-width, use the longest word (accounting for wide chars)
  let mut max_word_width = 0
  let mut current_word_width = 0
  for c in trimmed.iter() {
    if c == ' ' || c == '\n' || c == '\t' {
      if current_word_width > max_word_width {
        max_word_width = current_word_width
      }
      current_word_width = 0
    } else {
      current_word_width = current_word_width + char_display_width(c)
    }
  }
  if current_word_width > max_word_width {
    max_word_width = current_word_width
  }
  let text_min_width = max_word_width.to_double() * char_width
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
      // Calculate how many lines we need
      let lines = if cols_available > 0 && display_width > 0 {
        (display_width + cols_available - 1) / cols_available
      } else {
        1
      }
      let height = lines.to_double() * line_height
      {
        min_width: text_min_width,
        max_width: text_max_width,
        min_height: line_height,
        max_height: height,
      }
    },
  }
}

///|
/// Create a node for text content
fn create_text_node(text : String) -> @node.Node {
  let trimmed = text.trim()
  if trimmed.is_empty() {
    // Return a zero-size node for whitespace-only text
    @node.Node::leaf("#text", @style.Style::default())
  } else {
    @node.Node::with_measure(
      "#text",
      @style.Style::default(),
      create_text_measure(text),
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
/// Find body element in HTML tree
fn find_body(elem : @html.Element) -> @html.Element? {
  if elem.tag == "body" {
    return Some(elem)
  }
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
  // Parse HTML document (includes stylesheet extraction)
  let doc = @html.parse_document(html)

  // Parse stylesheets from <style> tags
  let stylesheets : Array[@cascade.Stylesheet] = []
  for css in doc.stylesheets {
    let stylesheet = @parser.parse_stylesheet(css)
    stylesheets.push(stylesheet)
  }

  // Find body element, or use root if not found
  let render_root = match find_body(doc.root) {
    Some(body) => body
    None => doc.root
  }

  // Convert to node tree with stylesheet styles applied
  let root = element_to_node_with_styles(render_root, None, ctx, stylesheets)

  // Create layout context - subtract root margin from available space
  let root_margin = @types.resolve_rect(root.style.margin, ctx.viewport_width)
  let available_width = ctx.viewport_width -
    root_margin.left -
    root_margin.right
  let available_height = ctx.viewport_height -
    root_margin.top -
    root_margin.bottom
  let layout_ctx : @node.LayoutContext = {
    available_width,
    available_height: Some(available_height),
    sizing_mode: @node.SizingMode::Definite,
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
    children: layout.children,
  }
}

///|
/// Convert HTML Element to Node tree with stylesheet styles applied
fn element_to_node_with_styles(
  elem : @html.Element,
  parent : @selector.Element?,
  ctx : RenderContext,
  stylesheets : Array[@cascade.Stylesheet],
) -> @node.Node {
  // Convert HTML element to selector element for matching
  let selector_elem = html_to_selector_element(elem, parent)

  // Get style from stylesheet matching + inline style
  let style = compute_element_style(
    selector_elem,
    elem.style,
    stylesheets,
    parent is None,
    ctx,
  )

  // Convert children
  let children : Array[@node.Node] = []
  for i, child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        // Update sibling info on selector element for child processing
        let child_selector = html_to_selector_element_with_parent(
          child_elem,
          selector_elem,
          i + 1,
          elem.children.length(),
        )
        let child_node = element_to_node_with_styles_internal(
          child_elem, child_selector, ctx, stylesheets,
        )
        children.push(child_node)
      }
      @html.Node::Text(text) => {
        let text_node = create_text_node(text)
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
) -> @node.Node {
  // Get style from stylesheet matching + inline style
  let style = compute_element_style(
    selector_elem,
    elem.style,
    stylesheets,
    false,
    ctx,
  )

  // Convert children
  let children : Array[@node.Node] = []
  for i, child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        let child_selector = html_to_selector_element_with_parent(
          child_elem,
          selector_elem,
          i + 1,
          elem.children.length(),
        )
        let child_node = element_to_node_with_styles_internal(
          child_elem, child_selector, ctx, stylesheets,
        )
        children.push(child_node)
      }
      @html.Node::Text(text) => {
        let text_node = create_text_node(text)
        children.push(text_node)
      }
    }
  }
  let node_id = make_node_id(elem)

  // Handle replaced elements (img, etc.) with intrinsic sizing
  if elem.tag.to_lower() == "img" && children.is_empty() {
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
    // If intrinsic dimensions are specified, create a node with measure function
    if intrinsic_width > 0.0 || intrinsic_height > 0.0 {
      let measure = create_image_measure(intrinsic_width, intrinsic_height)
      return @node.Node::with_measure(node_id, style, measure)
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
) -> @style.Style {
  // Match stylesheets and get cascaded values
  let cascaded = @cascade.cascade_element(selector_elem, stylesheets, [])

  // Start with user-agent default style based on tag
  let mut style = get_ua_default_style(selector_elem.tag_name)

  // Apply cascaded values with correct viewport
  for prop in cascaded.properties() {
    match cascaded.get_value(prop) {
      Some(value) =>
        style = apply_css_property_with_viewport(
          style,
          prop,
          value,
          ctx.viewport_width,
          ctx.viewport_height,
        )
      None => ()
    }
  }

  // Apply inline styles (override stylesheet styles)
  // Parse inline CSS properties and apply them one by one
  match inline_css {
    Some(css) => style = apply_inline_css(style, css)
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
  style
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
  let css = property + ": " + value
  let parsed = @computed.compute_inline(css, @computed.ComputeContext::new())

  // Merge the parsed property into the style
  merge_style_property(style, parsed, property)
}

///|
/// Apply a CSS property value to a style with custom viewport
fn apply_css_property_with_viewport(
  style : @style.Style,
  property : String,
  value : String,
  viewport_width : Double,
  viewport_height : Double,
) -> @style.Style {
  // Use the inline parser's logic to parse and apply the value
  let css = property + ": " + value
  let ctx = @computed.ComputeContext::with_viewport(
    viewport_width, viewport_height,
  )
  let parsed = @computed.compute_inline(css, ctx)

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
/// Parse inline CSS and apply properties to style
fn apply_inline_css(target : @style.Style, inline_css : String) -> @style.Style {
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
          result = apply_css_property(result, prop, value)
        }
      } catch {
        _ => ()
      }
    }
  }
  result
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
/// Render HTML to Sixel string
pub fn render_to_sixel(html : String, width : Int, height : Int) -> String {
  let ctx : RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
  }
  let layout = render(html, ctx)
  @sixel.render_layout(layout, width, height)
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
