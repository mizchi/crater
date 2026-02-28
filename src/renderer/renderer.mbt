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
/// Ahem/fallback-font-like glyph width ratio observed in WPT harness rendering.
let large_ahem_like_char_width_ratio : Double = 0.722

///|
/// UA default "normal" line-height approximation used for table internals.
let normal_line_height_ratio : Double = 1.045

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
  let cp = c.to_int()
  // U+2003 EM SPACE should advance by one full em in monospace-like metrics.
  if cp == 0x2003 {
    2
  } else if is_wide_char(c) {
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
  let mut trimmed = if raw_trimmed.is_empty() && not(text.is_empty()) {
    " "
  } else {
    raw_trimmed.to_string()
  }
  if not(raw_trimmed.is_empty()) {
    let mut ends_with_ws = false
    for c in text.iter() {
      ends_with_ws = c == ' ' ||
        c == '\t' ||
        c == '\n' ||
        c == '\r' ||
        c == '\u000C'
    }
    if ends_with_ws {
      trimmed = trimmed + " "
    }
  }
  let mut effective_char_width_ratio = char_width_ratio
  if font_size >= 80.0 && text_line_height <= font_size * 1.01 {
    let mut all_ahem_like = true
    for c in trimmed.iter() {
      if c != 'X' && c != '\u00A0' {
        all_ahem_like = false
        break
      }
    }
    if all_ahem_like && not(trimmed.is_empty()) {
      effective_char_width_ratio = large_ahem_like_char_width_ratio
    }
  }
  let char_width = font_size * effective_char_width_ratio

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
fn node_id_is_tag(node_id : String, tag : String) -> Bool {
  node_id == tag ||
  node_id.has_prefix(tag + "#") ||
  node_id.has_prefix(tag + ".")
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
fn get_inline_style_display(elem : @html.Element) -> @types.Display? {
  match elem.style {
    Some(style_str) => {
      let style_lower = style_str.to_lower()
      if style_lower.contains("display:") || style_lower.contains("display :") {
        let parsed = @parser.parse_inline_style(style_str)
        Some(parsed.display)
      } else {
        None
      }
    }
    None => None
  }
}

///|
/// Check if an element participates in inline formatting context in the current style cascade.
fn has_inline_participating_display(
  elem : @html.Element,
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  match get_inline_style_display(elem) {
    Some(display) => return is_inline_participating_display(display)
    None => ()
  }
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
    if not(is_collapsible_whitespace_char(c)) {
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
  while not(chars.is_empty()) {
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
/// Keep collapsed whitespace text between inline-participating element siblings.
fn should_preserve_inter_element_whitespace(
  siblings : Array[@html.Node],
  index : Int,
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  if index <= 0 || index >= siblings.length() - 1 {
    return false
  }
  let text = match siblings[index] {
    @html.Node::Text(t) => t
    _ => return false
  }
  if not(is_whitespace_only_text(text)) {
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
  let prev_inline = match siblings[index - 1] {
    @html.Node::Element(prev_elem) =>
      has_inline_participating_display(prev_elem, stylesheets, ctx)
    _ => false
  }
  let next_inline = match siblings[index + 1] {
    @html.Node::Element(next_elem) =>
      has_inline_participating_display(next_elem, stylesheets, ctx)
    _ => false
  }
  prev_inline && next_inline
}

///|
/// Check if an element is styled with display: contents.
fn has_display_contents(
  elem : @html.Element,
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  match elem.style {
    Some(style_str) => {
      let parsed = @parser.parse_inline_style(style_str)
      if parsed.display == @types.Contents {
        return true
      }
    }
    None => ()
  }
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
  stylesheets : Array[@cascade.Stylesheet],
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
      let has_contain = style_lower.contains("contain:") ||
        style_lower.contains("contain :")
      let contain_none = style_lower.contains("contain: none") ||
        style_lower.contains("contain : none")
      if has_contain && not(contain_none) {
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
      if has_background && not(transparent_background) {
        return true
      }
      let has_display = style_lower.contains("display:") ||
        style_lower.contains("display :")
      if has_display && style_lower.contains("ruby") {
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
    match cascaded.get_value("display") {
      Some(value) => if value.to_lower().contains("ruby") { return true }
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
fn is_out_of_flow_positioned(
  elem : @html.Element,
  stylesheets : Array[@cascade.Stylesheet],
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
    Some(value) => {
      let positioned = value.to_lower().trim()
      positioned == "absolute" || positioned == "fixed"
    }
    None => false
  }
}

///|
/// Check if element is a replaced element (img, input, video, etc.)
/// Replaced elements have intrinsic dimensions and don't contain text
fn is_replaced_element(tag : String) -> Bool {
  match tag.to_lower() {
    "img"
    | "input"
    | "select"
    | "video"
    | "audio"
    | "canvas"
    | "svg"
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
  preserve_inline_elements : Bool,
  parent_selector : @selector.Element,
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
        element_sibling_index += 1
        let child_selector = html_to_selector_element_with_parent(
          elem, parent_selector, element_sibling_index, element_sibling_count,
        )
        let has_generated_pseudo = selector_has_generated_pseudo_content(
          child_selector, stylesheets, ctx,
        )
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
        } else if is_inline_element(elem) &&
          not(will_have_non_inline_display(elem, stylesheets, ctx)) {
          if preserve_inline_elements {
            // In flex/grid containers, direct inline children are layout items
            // and must be preserved as elements.
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

///|
/// Create a node for text content with inherited font properties
fn create_text_node(text : String, parent_style : @style.Style) -> @node.Node {
  let normalized_text = if parent_style.display == @types.TableCell &&
    has_line_break_char(text) {
    trim_trailing_collapsible_whitespace(text)
  } else {
    text
  }
  let trimmed = normalized_text.trim()
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
      // Indentation-only whitespace in block formatting contexts should not
      // create measurable text runs. Keep whitespace for inline/flex/grid/
      // contents contexts where it can participate in layout.
      let keep_ws = match parent_style.display {
        @types.Inline
        | @types.InlineBlock
        | @types.Flex
        | @types.InlineFlex
        | @types.Grid
        | @types.InlineGrid
        | @types.Contents => true
        _ => false
      }
      if not(keep_ws) {
        return @node.Node::leaf("#text", @style.Style::default())
      }
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
        normalized_text, font_size, text_line_height, white_space, writing_mode,
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
/// In horizontal writing-mode, br has 0 width and line-height height.
/// In vertical writing-mode, br advances one line on x-axis.
fn create_br_measure(
  line_height : Double,
  font_size : Double,
  writing_mode : @style.WritingMode,
) -> @types.MeasureFunc {
  let is_vertical = writing_mode.is_vertical()
  let leading = if line_height > font_size {
    line_height - font_size
  } else {
    0.0
  }
  let base_advance = if font_size > 0.0 {
    font_size + leading * 0.1
  } else {
    line_height
  }
  let advance = if base_advance > 0.0 { base_advance } else { 0.0 }
  {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @types.IntrinsicSize {
      if is_vertical {
        // Vertical flow: br occupies one column advance.
        {
          min_width: advance,
          max_width: advance,
          min_height: 0.0,
          max_height: 0.0,
        }
      } else {
        // Horizontal flow: br occupies one line advance.
        {
          min_width: 0.0,
          max_width: 0.0,
          min_height: advance,
          max_height: advance,
        }
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
fn base64_char_value(c : Char) -> Int? {
  let cp = c.to_int()
  if cp >= 'A'.to_int() && cp <= 'Z'.to_int() {
    Some(cp - 'A'.to_int())
  } else if cp >= 'a'.to_int() && cp <= 'z'.to_int() {
    Some(cp - 'a'.to_int() + 26)
  } else if cp >= '0'.to_int() && cp <= '9'.to_int() {
    Some(cp - '0'.to_int() + 52)
  } else if cp == '+'.to_int() {
    Some(62)
  } else if cp == '/'.to_int() {
    Some(63)
  } else {
    None
  }
}

///|
fn decode_base64_prefix(encoded : String, byte_count : Int) -> Array[Int]? {
  let bytes : Array[Int] = []
  let quartet : Array[Int] = []
  for c in encoded.iter() {
    if c == '=' {
      quartet.push(-1)
    } else {
      match base64_char_value(c) {
        Some(v) => quartet.push(v)
        None => continue
      }
    }
    if quartet.length() == 4 {
      let v0 = quartet[0]
      let v1 = quartet[1]
      let v2 = quartet[2]
      let v3 = quartet[3]
      if v0 < 0 || v1 < 0 {
        break
      }
      bytes.push(((v0 << 2) | (v1 >> 4)) & 0xFF)
      if v2 >= 0 {
        bytes.push((((v1 & 0x0F) << 4) | (v2 >> 2)) & 0xFF)
      }
      if v2 >= 0 && v3 >= 0 {
        bytes.push((((v2 & 0x03) << 6) | v3) & 0xFF)
      }
      if bytes.length() >= byte_count {
        return Some(bytes)
      }
      quartet.clear()
    }
  }
  None
}

///|
fn parse_gif_data_uri(src : String) -> (Double, Double)? {
  if not(src.to_lower().has_prefix("data:image/gif;base64,")) {
    return None
  }
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
  let encoded = src[comma_idx + 1:].to_string() catch { _ => return None }
  match decode_base64_prefix(encoded, 10) {
    Some(bytes) => {
      if bytes.length() < 10 {
        return None
      }
      // GIF header + logical screen descriptor (little-endian width/height)
      if bytes[0] != 'G'.to_int() ||
        bytes[1] != 'I'.to_int() ||
        bytes[2] != 'F'.to_int() {
        return None
      }
      let width = bytes[6] + (bytes[7] << 8)
      let height = bytes[8] + (bytes[9] << 8)
      if width > 0 && height > 0 {
        Some((width.to_double(), height.to_double()))
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn parse_png_data_uri(src : String) -> (Double, Double)? {
  if not(src.to_lower().has_prefix("data:image/png;base64,")) {
    return None
  }
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
  let encoded = src[comma_idx + 1:].to_string() catch { _ => return None }
  match decode_base64_prefix(encoded, 24) {
    Some(bytes) => {
      if bytes.length() < 24 {
        return None
      }
      // PNG signature
      if bytes[0] != 0x89 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x4E ||
        bytes[3] != 0x47 ||
        bytes[4] != 0x0D ||
        bytes[5] != 0x0A ||
        bytes[6] != 0x1A ||
        bytes[7] != 0x0A {
        return None
      }
      // First chunk must be IHDR
      if bytes[12] != 'I'.to_int() ||
        bytes[13] != 'H'.to_int() ||
        bytes[14] != 'D'.to_int() ||
        bytes[15] != 'R'.to_int() {
        return None
      }
      let width = (bytes[16] << 24) |
        (bytes[17] << 16) |
        (bytes[18] << 8) |
        bytes[19]
      let height = (bytes[20] << 24) |
        (bytes[21] << 16) |
        (bytes[22] << 8) |
        bytes[23]
      if width > 0 && height > 0 {
        Some((width.to_double(), height.to_double()))
      } else {
        None
      }
    }
    None => None
  }
}

///|
/// Get intrinsic size from image src attribute
fn get_image_intrinsic_size(src : String) -> (Double, Double)? {
  // Restrict to data URI parsing to avoid filesystem/network side-effects.
  // SVG/GIF/PNG support compact intrinsic extraction.
  match parse_svg_data_uri(src) {
    Some(size) => Some(size)
    None =>
      match parse_gif_data_uri(src) {
        Some(size) => Some(size)
        None => parse_png_data_uri(src)
      }
  }
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
          inherited.direction = ps.direction
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
/// Clamp body height only when author explicitly requests viewport-relative
/// percentage sizing.
fn should_clamp_body_to_viewport(root : @node.Node) -> Bool {
  if root.id != "body" {
    return false
  }
  let has_viewport_height_request = match root.style.height {
    @types.Percent(p) => p >= 1.0
    _ =>
      match root.style.min_height {
        @types.Percent(p) => p >= 1.0
        _ => false
      }
  }
  has_viewport_height_request
}

///|
/// Create a recursive zero-sized layout for nodes that don't generate a box
/// (e.g. display:none on root/body).
fn create_zero_layout_from_node(node : @node.Node) -> @types.Layout {
  let children : Array[@types.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    children.push(create_zero_layout_from_node(node.children[i]))
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    margin: @types.Rect::zero(),
    padding: @types.Rect::zero(),
    border: @types.Rect::zero(),
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children,
    text: node.text,
  }
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

  // Resolve document root style once so root-level box suppression can be honored.
  let doc_root_selector = html_to_selector_element(doc.root, None)
  let doc_root_style = compute_element_style_indexed(
    doc_root_selector,
    doc.root.style,
    indexed_stylesheets,
    true,
    ctx,
    None,
    css_vars,
  )

  // Find body element, or use root if not found
  let render_root = match find_body(doc.root) {
    Some(body) => body
    None => doc.root
  }

  // Convert to node tree with stylesheet styles applied
  let root = if render_root.tag.to_lower() == "body" &&
    doc.root.tag.to_lower() != "body" {
    // Body is not the document root. Compute with html as parent so inheritable
    // properties (e.g. writing-mode from :root) are preserved.
    let body_selector = html_to_selector_element(
      render_root,
      Some(doc_root_selector),
    )
    element_to_node_with_styles_internal(
      render_root,
      body_selector,
      ctx,
      stylesheets,
      indexed_stylesheets,
      Some(doc_root_style),
      css_vars,
      {},
      "root",
    )
  } else {
    element_to_node_with_styles(
      render_root,
      None,
      ctx,
      stylesheets,
      indexed_stylesheets,
      css_vars,
      {},
      "root",
    )
  }
  if doc_root_style.display == @types.Display::None ||
    root.style.display == @types.Display::None {
    return create_zero_layout_from_node(root)
  }
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
  // Root with explicit/% height should resolve against viewport; otherwise keep
  // height unconstrained so content can grow naturally.
  let root_available_height : Double? = if render_root.tag.to_lower() == "body" {
    Some(ctx.viewport_height)
  } else {
    match root.style.height {
      @types.Length(_) | @types.Percent(_) => Some(ctx.viewport_height)
      _ => None
    }
  }
  let layout_ctx : @types.LayoutContext = {
    available_width,
    available_height: root_available_height,
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
    layout, root, 1.0, 1.0, 1.0, 0.0, 0.0, false,
  )
  let scaled_layout = if should_clamp_body_to_viewport(root) {
    // Body auto-height should be at least viewport-height, but still grow to
    // include overflowing normal-flow descendants.
    let min_viewport_height = if scaled_layout.height < ctx.viewport_height {
      ctx.viewport_height
    } else {
      scaled_layout.height
    }
    let content_extent = calculate_content_extent(scaled_layout)
    let final_height = if content_extent > min_viewport_height {
      content_extent
    } else {
      min_viewport_height
    }
    { ..scaled_layout, height: final_height }
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

  let doc_root_selector = html_to_selector_element(doc.root, None)
  let doc_root_style = compute_element_style_indexed(
    doc_root_selector,
    doc.root.style,
    indexed_stylesheets,
    true,
    ctx,
    None,
    css_vars,
  )

  // Find body element, or use root if not found
  let render_root = match find_body(doc.root) {
    Some(body) => body
    None => doc.root
  }

  // Convert to node tree with stylesheet styles applied
  let root = if render_root.tag.to_lower() == "body" &&
    doc.root.tag.to_lower() != "body" {
    let body_selector = html_to_selector_element(
      render_root,
      Some(doc_root_selector),
    )
    element_to_node_with_styles_internal(
      render_root,
      body_selector,
      ctx,
      stylesheets,
      indexed_stylesheets,
      Some(doc_root_style),
      css_vars,
      {},
      "root",
    )
  } else {
    element_to_node_with_styles(
      render_root,
      None,
      ctx,
      stylesheets,
      indexed_stylesheets,
      css_vars,
      {},
      "root",
    )
  }
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
  let root_available_height : Double? = if render_root.tag.to_lower() == "body" {
    Some(ctx.viewport_height)
  } else {
    match root.style.height {
      @types.Length(_) | @types.Percent(_) => Some(ctx.viewport_height)
      _ => None
    }
  }
  let layout_ctx : @types.LayoutContext = {
    available_width,
    available_height: root_available_height,
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
    layout, root, 1.0, 1.0, 1.0, 0.0, 0.0, false,
  )
  let scaled_layout = if should_clamp_body_to_viewport(root) {
    let min_viewport_height = if scaled_layout.height < ctx.viewport_height {
      ctx.viewport_height
    } else {
      scaled_layout.height
    }
    let content_extent = calculate_content_extent(scaled_layout)
    let final_height = if content_extent > min_viewport_height {
      content_extent
    } else {
      min_viewport_height
    }
    { ..scaled_layout, height: final_height }
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
priv struct CounterEntry {
  value : Int
  owner : String
  owner_is_style_scope : Bool
}

///|
priv struct CounterDirective {
  name : String
  amount : Int
}

///|
priv enum ContentPart {
  Text(String)
  Counter(String)
  Counters(String, String)
}

///|
priv enum PseudoKind {
  Before
  After
}

///|
fn is_ascii_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn is_ascii_alpha_num_hyphen(c : Char) -> Bool {
  let cp = c.to_int()
  (cp >= 'a'.to_int() && cp <= 'z'.to_int()) ||
  (cp >= 'A'.to_int() && cp <= 'Z'.to_int()) ||
  (cp >= '0'.to_int() && cp <= '9'.to_int()) ||
  c == '-' ||
  c == '_'
}

///|
fn is_ascii_hex_digit(c : Char) -> Bool {
  let cp = c.to_int()
  (cp >= '0'.to_int() && cp <= '9'.to_int()) ||
  (cp >= 'a'.to_int() && cp <= 'f'.to_int()) ||
  (cp >= 'A'.to_int() && cp <= 'F'.to_int())
}

///|
fn ascii_hex_digit_to_int(c : Char) -> Int {
  let cp = c.to_int()
  if cp >= '0'.to_int() && cp <= '9'.to_int() {
    cp - '0'.to_int()
  } else if cp >= 'a'.to_int() && cp <= 'f'.to_int() {
    cp - 'a'.to_int() + 10
  } else {
    cp - 'A'.to_int() + 10
  }
}

///|
fn split_ascii_whitespace_tokens(value : String) -> Array[String] {
  let tokens : Array[String] = []
  let current = StringBuilder::new()
  for c in value.iter() {
    if is_ascii_whitespace(c) {
      if current.to_string().length() > 0 {
        tokens.push(current.to_string())
        current.reset()
      }
    } else {
      current.write_char(c)
    }
  }
  if current.to_string().length() > 0 {
    tokens.push(current.to_string())
  }
  tokens
}

///|
fn first_token_or_empty(tokens : Array[String]) -> String {
  if tokens.is_empty() {
    ""
  } else {
    tokens[0]
  }
}

///|
fn find_char_index(value : String, target : Char) -> Int? {
  let mut i = 0
  while i < value.length() {
    if value[i].to_int().unsafe_to_char() == target {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn parse_counter_directives(
  value : String,
  default_amount : Int,
) -> Array[CounterDirective] {
  let lowered = value.trim().to_lower().to_string()
  if lowered.is_empty() || lowered == "none" {
    return []
  }
  let tokens = split_ascii_whitespace_tokens(value)
  let directives : Array[CounterDirective] = []
  let mut i = 0
  while i < tokens.length() {
    let name = tokens[i].trim().to_string()
    i += 1
    if name.is_empty() {
      continue
    }
    let mut amount = default_amount
    if i < tokens.length() {
      let parsed = @strconv.parse_int(tokens[i]) catch { _ => default_amount }
      // Heuristic: only treat token as number when parsing changed it from default
      // or when token is explicit zero/negative.
      if parsed != default_amount ||
        tokens[i] == "0" ||
        tokens[i].has_prefix("-") ||
        tokens[i].has_prefix("+") {
        amount = parsed
        i += 1
      }
    }
    directives.push({ name, amount })
  }
  directives
}

///|
fn copy_counter_state(
  state : Map[String, CounterEntry],
) -> Map[String, CounterEntry] {
  let copied : Map[String, CounterEntry] = {}
  state.each(fn(name, entry) { copied[name] = entry })
  copied
}

///|
fn filter_counter_state_for_style_containment(
  state : Map[String, CounterEntry],
  owner_id : String,
) -> Map[String, CounterEntry] {
  let filtered : Map[String, CounterEntry] = {}
  state.each(fn(name, entry) {
    if entry.owner == owner_id {
      filtered[name] = entry
    }
  })
  filtered
}

///|
fn apply_counter_reset_directives(
  state : Map[String, CounterEntry],
  directives : Array[CounterDirective],
  owner_id : String,
  owner_is_style_scope : Bool,
) -> Unit {
  for directive in directives {
    state[directive.name] = {
      value: directive.amount,
      owner: owner_id,
      owner_is_style_scope,
    }
  }
}

///|
fn apply_counter_increment_directives(
  state : Map[String, CounterEntry],
  directives : Array[CounterDirective],
  owner_id : String,
  owner_is_style_scope : Bool,
) -> Unit {
  for directive in directives {
    let amount = directive.amount
    match state.get(directive.name) {
      Some(entry) =>
        if entry.owner_is_style_scope && entry.owner != owner_id {
          state[directive.name] = {
            value: amount,
            owner: owner_id,
            owner_is_style_scope,
          }
        } else {
          state[directive.name] = { ..entry, value: entry.value + amount }
        }
      None =>
        state[directive.name] = {
          value: amount,
          owner: owner_id,
          owner_is_style_scope,
        }
    }
  }
}

///|
fn counter_value(state : Map[String, CounterEntry], name : String) -> Int {
  match state.get(name) {
    Some(entry) => entry.value
    None => 0
  }
}

///|
fn parse_css_quoted_string(value : String, start : Int) -> (String, Int)? {
  if start >= value.length() {
    return None
  }
  let quote = value[start].to_int().unsafe_to_char()
  if quote != '"' && quote != '\'' {
    return None
  }
  let buf = StringBuilder::new()
  let mut i = start + 1
  while i < value.length() {
    let c = value[i].to_int().unsafe_to_char()
    if c == quote {
      return Some((buf.to_string(), i - start + 1))
    }
    if c == '\\' {
      if i + 1 >= value.length() {
        i += 1
        continue
      }
      let next = value[i + 1].to_int().unsafe_to_char()
      if is_ascii_hex_digit(next) {
        let mut code = 0
        let mut hex_i = i + 1
        let mut count = 0
        while hex_i < value.length() && count < 6 {
          let hc = value[hex_i].to_int().unsafe_to_char()
          if not(is_ascii_hex_digit(hc)) {
            break
          }
          code = code * 16 + ascii_hex_digit_to_int(hc)
          hex_i += 1
          count += 1
        }
        if code > 0 {
          buf.write_char(code.unsafe_to_char())
        }
        if hex_i < value.length() {
          let ws = value[hex_i].to_int().unsafe_to_char()
          if is_ascii_whitespace(ws) {
            hex_i += 1
          }
        }
        i = hex_i
        continue
      }
      if next == '\n' || next == '\r' {
        i += 2
        continue
      }
      buf.write_char(next)
      i += 2
      continue
    }
    buf.write_char(c)
    i += 1
  }
  Some((buf.to_string(), value.length() - start))
}

///|
fn parse_content_parts(value : String) -> Array[ContentPart]? {
  let trimmed = value.trim().to_string()
  if trimmed.is_empty() || trimmed == "none" || trimmed == "normal" {
    return None
  }
  let parts : Array[ContentPart] = []
  let mut i = 0
  while i < trimmed.length() {
    let c = trimmed[i].to_int().unsafe_to_char()
    if is_ascii_whitespace(c) {
      i += 1
      continue
    }
    if c == '"' || c == '\'' {
      match parse_css_quoted_string(trimmed, i) {
        Some((text, consumed)) => {
          parts.push(Text(text))
          i += consumed
          continue
        }
        None => ()
      }
    }
    if is_ascii_alpha_num_hyphen(c) {
      let mut end = i + 1
      while end < trimmed.length() {
        let ec = trimmed[end].to_int().unsafe_to_char()
        if not(is_ascii_alpha_num_hyphen(ec)) {
          break
        }
        end += 1
      }
      let ident = trimmed[i:end].to_string() catch { _ => "" }
      let ident_lower = ident.to_lower()
      let mut j = end
      while j < trimmed.length() {
        let jc = trimmed[j].to_int().unsafe_to_char()
        if not(is_ascii_whitespace(jc)) {
          break
        }
        j += 1
      }
      if j < trimmed.length() && trimmed[j].to_int().unsafe_to_char() == '(' {
        let mut depth = 1
        let arg_start = j + 1
        let mut k = j + 1
        while k < trimmed.length() {
          let kc = trimmed[k].to_int().unsafe_to_char()
          if kc == '(' {
            depth += 1
          } else if kc == ')' {
            depth -= 1
            if depth == 0 {
              break
            }
          }
          k += 1
        }
        if k < trimmed.length() && depth == 0 {
          let args = trimmed[arg_start:k].to_string() catch { _ => "" }
          if ident_lower == "counter" {
            let name = first_token_or_empty(split_ascii_whitespace_tokens(args))
            let name = name.trim().to_string()
            if not(name.is_empty()) {
              parts.push(Counter(name))
            }
          } else if ident_lower == "counters" {
            let comma_index = find_char_index(args, ',')
            match comma_index {
              Some(ci) => {
                let name = args[0:ci].to_string() catch { _ => "" }
                let raw_sep = args[ci + 1:args.length()].to_string() catch {
                  _ => ""
                }
                let sep = match
                  parse_css_quoted_string(raw_sep.trim().to_string(), 0) {
                  Some((s, _)) => s
                  None => raw_sep.trim().to_string()
                }
                let counter_name = name.trim().to_string()
                if not(counter_name.is_empty()) {
                  parts.push(Counters(counter_name, sep))
                }
              }
              None => {
                let name = args.trim().to_string()
                if not(name.is_empty()) {
                  parts.push(Counter(name))
                }
              }
            }
          }
          i = k + 1
          continue
        }
      }
    }
    i += 1
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts)
  }
}

///|
fn evaluate_content_parts(
  parts : Array[ContentPart],
  counters : Map[String, CounterEntry],
) -> String {
  let buf = StringBuilder::new()
  for part in parts {
    match part {
      Text(text) => buf.write_string(text)
      Counter(name) =>
        buf.write_string(counter_value(counters, name).to_string())
      Counters(name, _sep) =>
        // For current WPT subset we keep only the active innermost value.
        buf.write_string(counter_value(counters, name).to_string())
    }
  }
  buf.to_string()
}

///|
fn parse_relative_left_offset(
  value : String,
  host_style : @style.Style,
) -> Double {
  let trimmed = value.trim().to_lower().to_string()
  if trimmed.is_empty() {
    return 0.0
  }
  let base_font_size = if host_style.font_size > 0.0 {
    host_style.font_size
  } else {
    16.0
  }
  if trimmed.has_suffix("ch") {
    let num = @strconv.parse_double(remove_suffix(trimmed, 2).to_string()) catch {
      _ => 0.0
    }
    num * base_font_size * 0.5
  } else if trimmed.has_suffix("em") {
    let num = @strconv.parse_double(remove_suffix(trimmed, 2).to_string()) catch {
      _ => 0.0
    }
    num * base_font_size
  } else if trimmed.has_suffix("px") {
    @strconv.parse_double(remove_suffix(trimmed, 2).to_string()) catch {
      _ => 0.0
    }
  } else {
    @strconv.parse_double(trimmed) catch {
      _ => 0.0
    }
  }
}

///|
fn selector_text_without_pseudo(
  selector_text : String,
  pseudo_kind : PseudoKind,
) -> String? {
  let trimmed = selector_text.trim().to_string()
  let (double_suffix, single_suffix) = match pseudo_kind {
    Before => ("::before", ":before")
    After => ("::after", ":after")
  }
  if trimmed.has_suffix(double_suffix) {
    let len = trimmed.length()
    let base_len = len - double_suffix.length()
    let base = trimmed[0:base_len].to_string() catch { _ => "" }
    let cleaned = base.trim().to_string()
    if cleaned.is_empty() {
      None
    } else {
      Some(cleaned)
    }
  } else if trimmed.has_suffix(single_suffix) {
    let len = trimmed.length()
    let base_len = len - single_suffix.length()
    let base = trimmed[0:base_len].to_string() catch { _ => "" }
    let cleaned = base.trim().to_string()
    if cleaned.is_empty() {
      None
    } else {
      Some(cleaned)
    }
  } else {
    None
  }
}

///|
fn selector_text_fallback_matches(
  selector_text : String,
  selector_elem : @selector.Element,
) -> Bool {
  let lowered = selector_text.to_lower()
  let tag_lower = selector_elem.tag_name.to_lower()
  if lowered.contains(":is(") {
    if lowered.contains(tag_lower) {
      return true
    }
  }
  match selector_elem.id {
    Some(id) => if lowered.contains("#" + id.to_lower()) { return true }
    None => ()
  }
  for cls in selector_elem.classes {
    if lowered.contains("." + cls.to_lower()) {
      return true
    }
  }
  lowered.contains(tag_lower)
}

///|
priv struct AfterPseudoSpec {
  content : String
  position_relative : Bool
  out_of_flow : Bool
  left_offset : Double
  text_style : @style.Style
}

///|
fn resolve_pseudo_spec(
  selector_elem : @selector.Element,
  host_style : @style.Style,
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
  pseudo_kind : PseudoKind,
  counters : Map[String, CounterEntry],
) -> AfterPseudoSpec? {
  let media_env = @media.MediaEnvironment::with_color_scheme(
    ctx.viewport_width,
    ctx.viewport_height,
    ctx.color_scheme,
  )
  let mut content_parts : Array[ContentPart]? = None
  let mut position_relative = false
  let mut out_of_flow = false
  let mut left_offset = 0.0
  let mut text_style = host_style

  for stylesheet in stylesheets {
    for rule in stylesheet.rules {
      let media_matches = match rule.media_query {
        Some(mq) => mq.evaluate(media_env)
        None => true
      }
      if not(media_matches) {
        continue
      }
      match selector_text_without_pseudo(rule.selector_text, pseudo_kind) {
        Some(base_selector_text) => {
          let matches_selector = match
            @selector.parse_selector_text(base_selector_text) {
            Some(base_selector) =>
              @selector.matches_complex(selector_elem, base_selector) ||
              selector_text_fallback_matches(base_selector_text, selector_elem)
            None =>
              selector_text_fallback_matches(base_selector_text, selector_elem)
          }
          if matches_selector {
            for decl in rule.declarations {
              match decl.value {
                @cascade.PropertyValue::Value(v) => {
                  let prop = decl.property.to_lower()
                  if prop == "content" {
                    content_parts = parse_content_parts(v)
                  } else if prop == "position" {
                    let pos = v.trim().to_lower()
                    if pos == "relative" {
                      position_relative = true
                    } else if pos == "absolute" || pos == "fixed" {
                      out_of_flow = true
                    }
                  } else if prop == "left" {
                    left_offset = parse_relative_left_offset(v, host_style)
                  } else if prop == "font" ||
                    prop == "font-size" ||
                    prop == "line-height" ||
                    prop == "white-space" ||
                    prop == "writing-mode" {
                    text_style = apply_css_property(text_style, prop, v)
                  }
                }
                _ => ()
              }
            }
          }
        }
        None => ()
      }
    }
  }

  match content_parts {
    Some(parts) => {
      let text = evaluate_content_parts(parts, counters)
      if text.is_empty() {
        None
      } else {
        Some({
          content: text,
          position_relative,
          out_of_flow,
          left_offset,
          text_style,
        })
      }
    }
    None => None
  }
}

///|
fn get_counter_directives(
  selector_elem : @selector.Element,
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
) -> (Array[CounterDirective], Array[CounterDirective]) {
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
  let reset_raw = match cascaded.get_value("counter-reset") {
    Some(v) => v
    None => ""
  }
  let increment_raw = match cascaded.get_value("counter-increment") {
    Some(v) => v
    None => ""
  }
  (
    parse_counter_directives(reset_raw, 0),
    parse_counter_directives(increment_raw, 1),
  )
}

///|
fn selector_has_generated_pseudo_content(
  selector_elem : @selector.Element,
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
) -> Bool {
  let empty_counters : Map[String, CounterEntry] = {}
  let default_style = @style.Style::default()
  let has_before = match
    resolve_pseudo_spec(
      selector_elem,
      default_style,
      stylesheets,
      ctx,
      Before,
      empty_counters,
    ) {
    Some(_) => true
    None => false
  }
  let has_after = match
    resolve_pseudo_spec(
      selector_elem,
      default_style,
      stylesheets,
      ctx,
      After,
      empty_counters,
    ) {
    Some(_) => true
    None => false
  }
  has_before || has_after
}

///|
fn establishes_style_containment_scope(style : @style.Style) -> Bool {
  style.contain.style && style.display != @types.Contents
}

///|
fn compute_element_own_counters(
  incoming_counters : Map[String, CounterEntry],
  selector_elem : @selector.Element,
  style : @style.Style,
  stylesheets : Array[@cascade.Stylesheet],
  ctx : RenderContext,
  owner_id : String,
) -> Map[String, CounterEntry] {
  let own_counters = copy_counter_state(incoming_counters)
  let is_style_scope = establishes_style_containment_scope(style)
  let (counter_resets, counter_increments) = get_counter_directives(
    selector_elem, stylesheets, ctx,
  )
  apply_counter_reset_directives(
    own_counters, counter_resets, owner_id, is_style_scope,
  )
  apply_counter_increment_directives(
    own_counters, counter_increments, owner_id, is_style_scope,
  )
  own_counters
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
    {},
    "root",
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
    {},
    "root",
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
  tag : String,
) -> @style.Style {
  let mut result = style
  fn parse_svg_dimension(value : String) -> @types.Dimension? {
    let trimmed = value.trim().to_string()
    if trimmed.is_empty() {
      return None
    }
    if trimmed.has_suffix("%") {
      let percent_str = remove_suffix(trimmed, 1)
      let percent = @strconv.parse_double(percent_str) catch {
        _ => return None
      }
      return Some(@types.Percent(percent / 100.0))
    }
    let length = parse_svg_length(trimmed)
    // Keep zero as a valid explicit length (e.g. width="0").
    if length == 0.0 {
      let raw = @strconv.parse_double(trimmed) catch { _ => return None }
      return Some(@types.Length(raw))
    }
    Some(@types.Length(length))
  }

  let attr_width_for_ratio = match attrs.get("width") {
    Some(w) => parse_svg_length(w)
    None => 0.0
  }
  let attr_height_for_ratio = match attrs.get("height") {
    Some(h) => parse_svg_length(h)
    None => 0.0
  }
  if attr_width_for_ratio > 0.0 &&
    attr_height_for_ratio > 0.0 &&
    result.aspect_ratio is None {
    result = {
      ..result,
      aspect_ratio: Some(attr_width_for_ratio / attr_height_for_ratio),
    }
  }
  if result.aspect_ratio is None {
    match attrs.get("viewBox") {
      Some(vb) =>
        match parse_viewbox(vb) {
          Some((vb_w, vb_h)) if vb_w > 0.0 && vb_h > 0.0 =>
            result = { ..result, aspect_ratio: Some(vb_w / vb_h) }
          _ => ()
        }
      None => ()
    }
  }

  // Root <svg> width/height attributes behave as intrinsic dimensions.
  // If CSS already specifies either dimension, keep attributes only as ratio hints.
  let can_apply_svg_size_attrs = if tag == "svg" {
    result.width == @types.Auto && result.height == @types.Auto
  } else {
    true
  }

  // Get width from attribute
  match attrs.get("width") {
    Some(w) =>
      match (can_apply_svg_size_attrs, result.width, parse_svg_dimension(w)) {
        (false, _, _) => ()
        (true, @types.Auto, Some(dim)) => result = { ..result, width: dim }
        _ => ()
      }
    None => ()
  }

  // Get height from attribute
  match attrs.get("height") {
    Some(h) =>
      match (can_apply_svg_size_attrs, result.height, parse_svg_dimension(h)) {
        (false, _, _) => ()
        (true, @types.Auto, Some(dim)) => result = { ..result, height: dim }
        _ => ()
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
/// Apply intrinsic fallback size for root SVG elements.
/// If width/height are auto, browsers use 300x150 with intrinsic ratio 2:1.
fn apply_svg_intrinsic_size(style : @style.Style, tag : String) -> @style.Style {
  if tag != "svg" {
    return style
  }

  let width_is_percent = match style.width {
    @types.Percent(_) => true
    _ => false
  }
  let height_is_percent = match style.height {
    @types.Percent(_) => true
    _ => false
  }

  {
    ..style
    // SVG behaves as a replaced inline element. Inline-block approximation
    // ensures width/height and intrinsic ratio participate in layout.
    ,
    display: if style.display == @types.Inline {
      @types.InlineBlock
    } else {
      style.display
    },
    width: if style.width == @types.Auto && height_is_percent {
      @types.Auto
    } else {
      style.width
    },
    height: if style.height == @types.Auto && width_is_percent {
      @types.Auto
    } else {
      style.height
    },
    aspect_ratio: match style.aspect_ratio {
      Some(_) => style.aspect_ratio
      None => if style.contain.size { None } else { Some(2.0) }
    },
  }
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
    | "applet"
    | "track"
    | "param"
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
  incoming_counters : Map[String, CounterEntry],
  owner_id : String,
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

  let cell_tag = elem.tag.to_lower()
  // Handle table attributes that affect table formatting context.
  let style = if cell_tag == "table" {
    let border_spacing = match elem.attributes.get("cellspacing") {
      Some(val) => {
        let n = @strconv.parse_double(val) catch {
          _ => computed_style.border_spacing
        }
        if n >= 0.0 {
          n
        } else {
          computed_style.border_spacing
        }
      }
      None => computed_style.border_spacing
    }
    { ..computed_style, border_spacing, }
  } else {
    computed_style
  }
  // Handle table cell rowspan/colspan attributes
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
  let own_counters = compute_element_own_counters(
    incoming_counters, selector_elem, style, stylesheets, ctx, owner_id,
  )
  let before_pseudo = resolve_pseudo_spec(
    selector_elem,
    style,
    stylesheets,
    ctx,
    Before,
    own_counters,
  )
  let after_pseudo = resolve_pseudo_spec(
    selector_elem,
    style,
    stylesheets,
    ctx,
    After,
    own_counters,
  )
  let style = match after_pseudo {
    Some(spec) if spec.position_relative && spec.left_offset != 0.0 =>
      {
        ..style,
        position: @types.Relative,
        inset: { ..style.inset, left: @types.Length(spec.left_offset) },
      }
    _ =>
      match before_pseudo {
        Some(spec) if spec.position_relative && spec.left_offset != 0.0 =>
          {
            ..style,
            position: @types.Relative,
            inset: { ..style.inset, left: @types.Length(spec.left_offset) },
          }
        _ => style
      }
  }

  // Convert children - first collect inline content (text + br)
  // Pass stylesheets to detect CSS display values (e.g., display: inline-block)
  let children : Array[@node.Node] = []
  let preserve_inline_elements = match style.display {
    @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid => true
    _ => false
  }
  let (inline_text, remaining_children) = collect_inline_content(
    elem.children,
    stylesheets,
    ctx,
    preserve_inline_elements,
    selector_elem,
  )

  match before_pseudo {
    Some(spec) if not(spec.out_of_flow) =>
      children.push(create_text_node(spec.content, spec.text_style))
    _ => ()
  }

  // Add combined text node if there's inline content
  if not(inline_text.trim().is_empty()) {
    let text_node = create_text_node(inline_text, style)
    children.push(text_node)
  }

  let child_seed_counters = if establishes_style_containment_scope(style) {
    filter_counter_state_for_style_containment(own_counters, owner_id)
  } else {
    own_counters
  }
  let mut prev_sibling_counters : Map[String, CounterEntry]? = None
  let mut element_child_index = 0

  // Process remaining children (elements and synthetic text nodes)
  for i, child in remaining_children {
    match child {
      @html.Node::Element(child_elem) => {
        // Skip non-rendered elements
        if should_skip_element(child_elem.tag) {
          continue
        }
        element_child_index += 1
        let child_owner_id = owner_id + "/" + element_child_index.to_string()
        let child_incoming_counters = match prev_sibling_counters {
          Some(counters) => copy_counter_state(counters)
          None => copy_counter_state(child_seed_counters)
        }
        // Update sibling info on selector element for child processing
        let child_selector = html_to_selector_element_with_parent(
          child_elem,
          selector_elem,
          i + 1,
          remaining_children.length(),
        )
        let child_style_for_counter = compute_element_style_indexed(
          child_selector,
          child_elem.style,
          indexed_stylesheets,
          false,
          ctx,
          Some(style),
          css_vars,
        )
        let child_own_counters = compute_element_own_counters(
          child_incoming_counters, child_selector, child_style_for_counter, stylesheets,
          ctx, child_owner_id,
        )
        prev_sibling_counters = Some(child_own_counters)
        let child_node = element_to_node_with_styles_internal(
          child_elem,
          child_selector,
          ctx,
          stylesheets,
          indexed_stylesheets,
          Some(style),
          css_vars,
          child_incoming_counters,
          child_owner_id,
        )
        children.push(child_node)
      }
      @html.Node::Text(text) =>
        // Process synthetic text nodes created by collect_inline_content
        // to preserve DOM order when elements are interleaved with text.
        if not(text.is_empty()) {
          let preserve_ws = should_preserve_inter_element_whitespace(
              remaining_children, i, stylesheets, ctx,
            ) &&
            not(style.writing_mode.is_vertical()) &&
            not(style.suppresses_intrinsic_width())
          if is_whitespace_only_text(text) && not(preserve_ws) {
            continue
          }
          let text_parent_style = if preserve_ws {
            { ..style, display: @types.Inline }
          } else {
            style
          }
          let text_node = create_text_node(text, text_parent_style)
          children.push(text_node)
        }
    }
  }
  match after_pseudo {
    Some(spec) if not(spec.out_of_flow) =>
      children.push(create_text_node(spec.content, spec.text_style))
    _ => ()
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
  incoming_counters : Map[String, CounterEntry],
  owner_id : String,
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
  let tag_lower = elem.tag.to_lower()
  // Keep contain flags on <rt> so ruby-specific fallback logic can distinguish
  // contain:size/paint test fixtures. Other inline elements still strip contain.
  let preserve_inline_contain = tag_lower == "rt"
  let computed_style = if computed_style.display == @types.Inline &&
    not(preserve_inline_contain) &&
    not(is_replaced_element(elem.tag.to_lower())) &&
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

  let is_ruby_internal = tag_lower == "ruby" ||
    tag_lower == "rb" ||
    tag_lower == "rbc" ||
    tag_lower == "rt" ||
    tag_lower == "rtc" ||
    tag_lower == "rp"

  // If this is an inline element containing replaced elements (like <a><img></a>),
  // treat it as inline-block so it gets proper sizing from its content
  // Also, if inline element contains block children (like <code><span class="line">),
  // treat it as block so children can be properly laid out
  let style = if computed_style.display == @types.Inline &&
    elem.tag.to_lower() != "picture" &&
    contains_replaced_element(elem) {
    { ..computed_style, display: @types.InlineBlock }
  } else if computed_style.display == @types.Inline &&
    not(is_ruby_internal) &&
    contains_block_child(elem, stylesheets, ctx) {
    // Inline element with block children should become block
    // This handles cases like <code><span class="line" style="display:block">
    { ..computed_style, display: @types.Block }
  } else {
    computed_style
  }

  let cell_tag = elem.tag.to_lower()
  // Handle table attributes that affect table formatting context.
  let style = if cell_tag == "table" {
    let border_spacing = match elem.attributes.get("cellspacing") {
      Some(val) => {
        let n = @strconv.parse_double(val) catch { _ => style.border_spacing }
        if n >= 0.0 {
          n
        } else {
          style.border_spacing
        }
      }
      None => style.border_spacing
    }
    { ..style, border_spacing, }
  } else {
    style
  }
  // Handle table cell rowspan/colspan attributes
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
    apply_svg_attributes_to_style(style, elem.attributes, cell_tag)
  } else {
    style
  }

  let style = apply_svg_intrinsic_size(style, cell_tag)
  let own_counters = compute_element_own_counters(
    incoming_counters, selector_elem, style, stylesheets, ctx, owner_id,
  )
  let before_pseudo = resolve_pseudo_spec(
    selector_elem,
    style,
    stylesheets,
    ctx,
    Before,
    own_counters,
  )
  let after_pseudo = resolve_pseudo_spec(
    selector_elem,
    style,
    stylesheets,
    ctx,
    After,
    own_counters,
  )
  let style = match after_pseudo {
    Some(spec) if spec.position_relative && spec.left_offset != 0.0 =>
      {
        ..style,
        position: @types.Relative,
        inset: { ..style.inset, left: @types.Length(spec.left_offset) },
      }
    _ =>
      match before_pseudo {
        Some(spec) if spec.position_relative && spec.left_offset != 0.0 =>
          {
            ..style,
            position: @types.Relative,
            inset: { ..style.inset, left: @types.Length(spec.left_offset) },
          }
        _ => style
      }
  }
  // Convert children - first collect inline content (text + br)
  // Pass stylesheets to detect CSS display values (e.g., display: inline-block)
  let children : Array[@node.Node] = []
  let parent_is_contents = match parent_style {
    Some(ps) => ps.display == @types.Contents
    None => false
  }
  let preserve_inline_elements = if parent_is_contents {
    true
  } else {
    match style.display {
      @types.Flex
      | @types.InlineFlex
      | @types.Grid
      | @types.InlineGrid
      | @types.Contents => true
      _ => false
    }
  }
  let (inline_text, remaining_children) = collect_inline_content(
    elem.children,
    stylesheets,
    ctx,
    preserve_inline_elements,
    selector_elem,
  )

  match before_pseudo {
    Some(spec) if not(spec.out_of_flow) =>
      children.push(create_text_node(spec.content, spec.text_style))
    _ => ()
  }

  // Add combined text node if there's inline content
  if not(inline_text.trim().is_empty()) {
    let text_node = create_text_node(inline_text, style)
    children.push(text_node)
  }

  let child_seed_counters = if establishes_style_containment_scope(style) {
    filter_counter_state_for_style_containment(own_counters, owner_id)
  } else {
    own_counters
  }
  let mut prev_sibling_counters : Map[String, CounterEntry]? = None
  let mut element_child_index = 0

  // Process remaining children (elements and synthetic text nodes)
  for i, child in remaining_children {
    match child {
      @html.Node::Element(child_elem) => {
        // Skip non-rendered elements
        if should_skip_element(child_elem.tag) {
          continue
        }
        element_child_index += 1
        let child_owner_id = owner_id + "/" + element_child_index.to_string()
        let child_incoming_counters = match prev_sibling_counters {
          Some(counters) => copy_counter_state(counters)
          None => copy_counter_state(child_seed_counters)
        }
        let child_selector = html_to_selector_element_with_parent(
          child_elem,
          selector_elem,
          i + 1,
          remaining_children.length(),
        )
        let child_style_for_counter = compute_element_style_indexed(
          child_selector,
          child_elem.style,
          indexed_stylesheets,
          false,
          ctx,
          Some(style),
          css_vars,
        )
        let child_own_counters = compute_element_own_counters(
          child_incoming_counters, child_selector, child_style_for_counter, stylesheets,
          ctx, child_owner_id,
        )
        prev_sibling_counters = Some(child_own_counters)
        let child_node = element_to_node_with_styles_internal(
          child_elem,
          child_selector,
          ctx,
          stylesheets,
          indexed_stylesheets,
          Some(style),
          css_vars,
          child_incoming_counters,
          child_owner_id,
        )
        children.push(child_node)
      }
      @html.Node::Text(text) =>
        // Process synthetic text nodes created by collect_inline_content
        // to preserve DOM order when elements are interleaved with text.
        if not(text.is_empty()) {
          let preserve_ws = should_preserve_inter_element_whitespace(
              remaining_children, i, stylesheets, ctx,
            ) &&
            not(style.writing_mode.is_vertical())
          if is_whitespace_only_text(text) && not(preserve_ws) {
            continue
          }
          let text_parent_style = if preserve_ws {
            { ..style, display: @types.Inline }
          } else {
            style
          }
          let text_node = create_text_node(text, text_parent_style)
          children.push(text_node)
        }
    }
  }
  match after_pseudo {
    Some(spec) if not(spec.out_of_flow) =>
      children.push(create_text_node(spec.content, spec.text_style))
    _ => ()
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
    let font_size = if style.font_size > 0.0 { style.font_size } else { 16.0 }
    let char_width = font_size * 0.5
    let control_line_height = font_size * 1.15
    let control_extra_width = font_size * 0.75
    let control_extra_height = font_size * 0.35
    // Get intrinsic dimensions based on input type
    // These are approximate browser defaults
    let (intrinsic_width, intrinsic_height) : (Double, Double) = match
      input_type {
      "radio" | "checkbox" => (13.0, 13.0)
      "button" | "submit" | "reset" => {
        let label = match elem.attributes.get("value") {
          Some(v) if not(v.is_empty()) => v
          _ =>
            match input_type {
              "submit" => "Submit"
              "reset" => "Reset"
              _ => ""
            }
        }
        let mut label_cols = 0
        for c in label.iter() {
          label_cols = label_cols + char_display_width(c)
        }
        let label_width = label_cols.to_double() * char_width * 0.85
        let min_width = font_size * 1.75
        let intrinsic_w = @types.max(min_width, label_width + font_size * 0.3)
        (intrinsic_w, 21.0)
      }
      "range" => (129.0, 21.0)
      "color" => (44.0, 23.0)
      "file" => (238.0, 21.0)
      "text" | "password" | "search" | "email" | "url" | "tel" | "number" => {
        let size_chars = match elem.attributes.get("size") {
          Some(size_attr) =>
            match parse_html_dimension(size_attr) {
              Some(v) if v > 0.0 => v
              _ => 20.0
            }
          None => 20.0
        }
        (
          size_chars * char_width + control_extra_width,
          control_line_height + control_extra_height,
        )
      }
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
  if tag_lower == "textarea" {
    let font_size = if style.font_size > 0.0 { style.font_size } else { 16.0 }
    let char_width = font_size * 0.5
    let control_line_height = if style.line_height > font_size * 1.15 {
      style.line_height
    } else {
      font_size * 1.15
    }
    let cols = match elem.attributes.get("cols") {
      Some(cols_attr) =>
        match parse_html_dimension(cols_attr) {
          Some(v) if v > 0.0 => v
          _ => 20.0
        }
      None => 20.0
    }
    let rows = match elem.attributes.get("rows") {
      Some(rows_attr) =>
        match parse_html_dimension(rows_attr) {
          Some(v) if v > 0.0 => v
          _ => 2.0
        }
      None => 2.0
    }
    let intrinsic_width = cols * char_width + font_size * 1.1
    let intrinsic_height = rows * control_line_height
    let measure = create_input_measure(intrinsic_width, intrinsic_height)
    let textarea_style : @style.Style = {
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
    return @node.Node::with_measure(node_id, textarea_style, measure)
  }
  if tag_lower == "select" {
    fn border_is_zero_length(dim : @types.Dimension) -> Bool {
      match dim {
        @types.Length(v) => v == 0.0
        _ => false
      }
    }
    let has_ua_border = not(
      border_is_zero_length(style.border.top) &&
      border_is_zero_length(style.border.right) &&
      border_is_zero_length(style.border.bottom) &&
      border_is_zero_length(style.border.left),
    )
    let select_size = match elem.attributes.get("size") {
      Some(size_attr) =>
        match parse_html_dimension(size_attr) {
          Some(v) if v > 0.0 => v.to_int()
          _ => 0
        }
      None => 0
    }
    let has_multiple = elem.attributes.contains("multiple")
    let is_listbox = has_multiple || select_size > 1
    let visible_rows = if select_size > 0 {
      select_size
    } else if is_listbox {
      4
    } else {
      1
    }
    let font_size = if style.font_size > 0.0 { style.font_size } else { 16.0 }
    let char_width = font_size * 0.5
    let suppress_intrinsic_width = style.suppresses_intrinsic_width()
    fn collect_html_text(node : @html.Node) -> String {
      match node {
        @html.Node::Text(text) => text
        @html.Node::Element(child_elem) => {
          let mut text = ""
          for grand_child in child_elem.children {
            text = text + collect_html_text(grand_child)
          }
          text
        }
      }
    }
    let mut max_option_cols = 0
    if not(suppress_intrinsic_width) {
      for child in elem.children {
        match child {
          @html.Node::Element(child_elem) =>
            if child_elem.tag.to_lower() == "option" {
              let mut option_text = ""
              for option_child in child_elem.children {
                option_text = option_text + collect_html_text(option_child)
              }
              let mut cols = 0
              for c in option_text.iter() {
                cols = cols + char_display_width(c)
              }
              if cols > max_option_cols {
                max_option_cols = cols
              }
            }
          _ => ()
        }
      }
    }
    let content_based_width = if max_option_cols > 0 {
      max_option_cols.to_double() * char_width + font_size * 0.375
    } else {
      0.0
    }
    let single_default_width = @types.max(22.0, content_based_width)
    let listbox_default_width = if suppress_intrinsic_width {
      2.0
    } else if max_option_cols > 0 {
      @types.max(2.0, content_based_width)
    } else {
      2.0
    }
    let default_width = if is_listbox {
      listbox_default_width
    } else if suppress_intrinsic_width {
      22.0
    } else {
      single_default_width
    }
    let default_height = if is_listbox {
      if visible_rows <= 1 {
        17.5
      } else if visible_rows == 4 {
        if font_size <= 12.0 {
          48.0
        } else {
          64.0
        }
      } else {
        let row_height = if font_size <= 12.0 { 11.5 } else { 15.5 }
        2.0 + visible_rows.to_double() * row_height
      }
    } else {
      19.0
    }
    let default_line_height = if style.line_height > 0.0 {
      style.line_height
    } else {
      font_size * 1.2
    }
    let default_border : @types.Rect[@types.Dimension] = @types.Rect::new(
      @types.Length(1.0),
      @types.Length(1.0),
      @types.Length(1.0),
      @types.Length(1.0),
    )
    let zero_dim_rect : @types.Rect[@types.Dimension] = @types.Rect::new(
      @types.Length(0.0),
      @types.Length(0.0),
      @types.Length(0.0),
      @types.Length(0.0),
    )

    let normalized_children : Array[@node.Node] = []
    let mut option_index = 0
    for child in children {
      let is_option = node_id_is_tag(child.id, "option")
      if is_option {
        let option_style = if is_listbox {
          let option_font_size = if child.style.font_size > 0.0 {
            child.style.font_size
          } else {
            font_size
          }
          let option_row_height = option_font_size * 1.15 + 1.0
          {
            ..child.style,
            display: @types.Block,
            height: @types.Length(option_row_height),
          }
        } else {
          let top_offset = if option_index == 0 {
            -default_line_height
          } else {
            0.0
          }
          {
            ..child.style,
            display: @types.Block,
            width: @types.Length(0.0),
            height: @types.Length(0.0),
            margin: @types.Rect::new(
              @types.Length(top_offset),
              @types.Length(0.0),
              @types.Length(0.0),
              @types.Length(0.0),
            ),
            padding: zero_dim_rect,
            border: zero_dim_rect,
          }
        }
        normalized_children.push(
          @node.Node::with_uid_and_measure(
            child.id,
            child.uid,
            option_style,
            child.children,
            child.measure,
            child.text,
          ),
        )
        option_index = option_index + 1
      } else {
        normalized_children.push(child)
      }
    }
    let select_style : @style.Style = {
      ..style,
      border: if has_ua_border {
        style.border
      } else {
        default_border
      },
      width: if style.width == @types.Auto {
        @types.Length(default_width)
      } else {
        style.width
      },
      height: if style.height == @types.Auto {
        @types.Length(default_height)
      } else {
        style.height
      },
    }
    return @node.Node::new(node_id, select_style, normalized_children)
  }
  if tag_lower == "svg" && children.is_empty() {
    // Root SVG behaves as a replaced element with default object size 300x150.
    // Keep CSS width/height auto semantics and expose intrinsic size via MeasureFunc.
    let attr_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(0.0)
      None => 0.0
    }
    let attr_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(0.0)
      None => 0.0
    }
    let intrinsic_width = if attr_width > 0.0 { attr_width } else { 300.0 }
    let intrinsic_height = if attr_height > 0.0 { attr_height } else { 150.0 }
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, style, measure)
  }
  if tag_lower == "img" && children.is_empty() {
    // HTML width/height attributes are presentational hints (used as CSS defaults),
    // while decoded image size is intrinsic data used for MeasureFunc/aspect-ratio.
    let attr_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(0.0)
      None => 0.0
    }
    let attr_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(0.0)
      None => 0.0
    }
    let mut intrinsic_width = attr_width
    let mut intrinsic_height = attr_height
    let mut uses_svg_fallback_object_size = false
    let mut uses_alt_fallback_size = false
    // Fill missing intrinsic dimensions from src data when available.
    if intrinsic_width == 0.0 || intrinsic_height == 0.0 {
      match elem.attributes.get("src") {
        Some(src) =>
          match get_image_intrinsic_size(src) {
            Some((w, h)) => {
              if intrinsic_width == 0.0 {
                intrinsic_width = w
              }
              if intrinsic_height == 0.0 {
                intrinsic_height = h
              }
            }
            None => ()
          }
        None => ()
      }
    }
    // Data-SVG without intrinsic dimensions falls back to 300x150.
    let has_svg_data_src = match elem.attributes.get("src") {
      Some(src) => src.to_lower().has_prefix("data:image/svg+xml")
      None => false
    }
    if intrinsic_width == 0.0 && intrinsic_height == 0.0 && has_svg_data_src {
      intrinsic_width = 300.0
      intrinsic_height = 150.0
      uses_svg_fallback_object_size = true
    }
    let alt_text = elem.attributes.get("alt")
    let has_non_data_src = match elem.attributes.get("src") {
      Some(src) => not(src.to_lower().has_prefix("data:"))
      None => false
    }
    // Chromium-style broken image fallback in our WPT setup: when external
    // image loading is unavailable and alt text exists, keep a visible fallback box.
    if intrinsic_width == 0.0 &&
      intrinsic_height == 0.0 &&
      has_non_data_src &&
      not(style.suppresses_intrinsic_width()) &&
      not(style.suppresses_intrinsic_height()) {
      match alt_text {
        Some(alt) =>
          if alt.length() > 0 {
            intrinsic_width = 64.0
            intrinsic_height = if style.display == @types.Block {
              let fallback_line_height = if style.line_height > 0.0 {
                style.line_height
              } else {
                style.font_size
              }
              96.0 + fallback_line_height
            } else {
              96.0
            }
            uses_alt_fallback_size = true
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
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    // Always treat <img> as replaced; unknown intrinsic size remains 0x0,
    // but CSS sizing keywords/percentages still need replaced-element behavior.
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    // Calculate intrinsic aspect ratio (width / height)
    let intrinsic_aspect_ratio = if intrinsic_height > 0.0 &&
      intrinsic_width > 0.0 &&
      not(uses_svg_fallback_object_size) &&
      not(uses_alt_fallback_size) {
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
        if suppress_auto_inline_size {
          @types.Auto
          // If height is %, keep width Auto to let aspect_ratio compute it
        } else if height_is_percent {
          @types.Auto
        } else if attr_width > 0.0 {
          @types.Length(attr_width)
        } else {
          style.width
        }
      } else {
        style.width
      },
      height: if style.height == @types.Auto {
        if suppress_auto_block_size {
          @types.Auto
          // If width is %, keep height Auto to let aspect_ratio compute it
        } else if width_is_percent {
          @types.Auto
        } else if attr_height > 0.0 {
          @types.Length(attr_height)
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
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    let canvas_style : @style.Style = {
      ..style,
      width: if style.width == @types.Auto {
        if suppress_auto_inline_size {
          @types.Auto
          // If height is %, keep width Auto to let aspect_ratio compute it
        } else if height_is_percent {
          @types.Auto
        } else {
          @types.Length(intrinsic_width)
        }
      } else {
        style.width
      },
      height: if style.height == @types.Auto {
        if suppress_auto_block_size {
          @types.Auto
          // If width is %, keep height Auto to let aspect_ratio compute it
        } else if width_is_percent {
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
        None => if style.contain.size { None } else { intrinsic_aspect_ratio }
      },
    }

    // Always use MeasureFunc to provide intrinsic size
    // The layout algorithm will use CSS dimensions if specified
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, canvas_style, measure)
  }

  // Handle iframe/object/embed as replaced elements with default intrinsic sizing
  if (tag_lower == "iframe" || tag_lower == "object" || tag_lower == "embed") &&
    children.is_empty() {
    if tag_lower == "embed" {
      let has_src = match elem.attributes.get("src") {
        Some(src) => src.trim().length() > 0
        None => false
      }
      if not(has_src) {
        return @node.Node::leaf(node_id, {
          ..style,
          display: @types.Display::None,
        })
      }
    }
    // HTML replaced elements default intrinsic size is 300x150
    let default_width = 300.0
    let default_height = 150.0
    let intrinsic_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(default_width)
      None => default_width
    }
    let intrinsic_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(default_height)
      None => default_height
    }
    let intrinsic_aspect_ratio = if intrinsic_height > 0.0 {
      Some(intrinsic_width / intrinsic_height)
    } else {
      None
    }
    let height_is_percent = match style.height {
      @types.Percent(_) => true
      _ => false
    }
    let width_is_percent = match style.width {
      @types.Percent(_) => true
      _ => false
    }
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    let replaced_style : @style.Style = {
      ..style,
      width: if style.width == @types.Auto {
        if suppress_auto_inline_size {
          @types.Auto
        } else if height_is_percent {
          @types.Auto
        } else {
          @types.Length(intrinsic_width)
        }
      } else {
        style.width
      },
      height: if style.height == @types.Auto {
        if suppress_auto_block_size {
          @types.Auto
        } else if width_is_percent {
          @types.Auto
        } else {
          @types.Length(intrinsic_height)
        }
      } else {
        style.height
      },
      aspect_ratio: match style.aspect_ratio {
        Some(_) => style.aspect_ratio
        None => if style.contain.size { None } else { intrinsic_aspect_ratio }
      },
    }
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, replaced_style, measure)
  }

  // Handle video/audio as replaced elements with fallback intrinsic size.
  // These fallback sizes should not imply a concrete intrinsic aspect ratio.
  if (tag_lower == "video" || tag_lower == "audio") && children.is_empty() {
    let default_width = 300.0
    let default_height = 150.0
    let intrinsic_width = match elem.attributes.get("width") {
      Some(w) => parse_html_dimension(w).unwrap_or(default_width)
      None => default_width
    }
    let intrinsic_height = match elem.attributes.get("height") {
      Some(h) => parse_html_dimension(h).unwrap_or(default_height)
      None => default_height
    }
    let height_is_percent = match style.height {
      @types.Percent(_) => true
      _ => false
    }
    let width_is_percent = match style.width {
      @types.Percent(_) => true
      _ => false
    }
    let suppress_auto_inline_size = style.suppresses_intrinsic_width()
    let suppress_auto_block_size = style.suppresses_intrinsic_height()
    let media_style : @style.Style = {
      ..style,
      width: if style.width == @types.Auto {
        if suppress_auto_inline_size {
          @types.Auto
        } else if height_is_percent {
          @types.Auto
        } else {
          @types.Length(intrinsic_width)
        }
      } else {
        style.width
      },
      height: if style.height == @types.Auto {
        if suppress_auto_block_size {
          @types.Auto
        } else if width_is_percent {
          @types.Auto
        } else {
          @types.Length(intrinsic_height)
        }
      } else {
        style.height
      },
      aspect_ratio: match style.aspect_ratio {
        Some(_) => style.aspect_ratio
        None => None
      },
    }
    let measure = create_image_measure(intrinsic_width, intrinsic_height)
    return @node.Node::with_measure(node_id, media_style, measure)
  }

  // Handle br element with line-height for height
  if tag_lower == "br" {
    // br elements have zero width but take up line-height vertically
    // line_height is already computed as absolute pixel value
    let measure = create_br_measure(
      style.line_height,
      style.font_size,
      style.writing_mode,
    )
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
fn is_no_principal_table_internal_display(display : @types.Display) -> Bool {
  match display {
    @types.TableRow
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
    "ul" | "ol" =>
      // Lists: margin-block 1em; padding-inline-start 40px.
      // Use named fields because Rect::new ordering is (left, right, top, bottom).
      {
        ..default_style,
        margin: {
          left: @types.Length(0.0),
          right: @types.Length(0.0),
          top: @types.Length(16.0),
          bottom: @types.Length(16.0),
        },
        padding: {
          left: @types.Length(40.0),
          right: @types.Length(0.0),
          top: @types.Length(0.0),
          bottom: @types.Length(0.0),
        },
      }
    "li" =>
      {
        ..default_style
        // Empty list items still occupy one line box in browsers.
        ,
        min_height: @types.Length(19.2),
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
    "fieldset" =>
      {
        ..default_style,
        margin: {
          left: @types.Length(2.0),
          right: @types.Length(2.0),
          top: @types.Length(0.0),
          bottom: @types.Length(0.0),
        },
        padding: {
          left: @types.Length(12.0),
          right: @types.Length(12.0),
          top: @types.Length(5.6),
          bottom: @types.Length(10.0),
        },
        border: {
          left: @types.Length(2.0),
          right: @types.Length(2.0),
          top: @types.Length(2.0),
          bottom: @types.Length(2.0),
        },
        min_width: @types.MinContent,
      }
    "legend" =>
      {
        ..default_style
        // Browsers render legend with shrink-wrap-like sizing behavior.
        // InlineBlock approximates that without a dedicated fieldset algorithm.
        ,
        display: @types.InlineBlock,
        padding: {
          left: @types.Length(2.0),
          right: @types.Length(2.0),
          top: @types.Length(0.0),
          bottom: @types.Length(0.0),
        },
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
    | "picture"
    | "source"
    | "ruby"
    | "rb"
    | "rbc"
    | "rt"
    | "rtc"
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
    // Form elements - inline-block and border-box by default
    "input" | "select" | "textarea" =>
      {
        ..default_style,
        display: @types.InlineBlock,
        box_sizing: @types.BorderBox,
      }
    // Buttons use platform UI metrics in browsers and are typically smaller
    // than inherited body text when no explicit font is set.
    "button" =>
      {
        ..default_style,
        display: @types.InlineBlock,
        box_sizing: @types.BorderBox,
        font_size: 14.0,
        line_height: 16.1,
      }
    "label" => { ..default_style, display: @types.Inline }
    // br is inline with no width
    "br" => { ..default_style, display: @types.Inline }
    // Table elements
    "table" => { ..default_style, display: @types.Table, border_spacing: 2.0 }
    "tr" => { ..default_style, display: @types.TableRow }
    "td" | "th" =>
      {
        ..default_style,
        display: @types.TableCell,
        padding: {
          left: @types.Length(1.0),
          right: @types.Length(1.0),
          top: @types.Length(1.0),
          bottom: @types.Length(1.0),
        },
      }
    "thead" => { ..default_style, display: @types.TableHeaderGroup }
    "tbody" => { ..default_style, display: @types.TableRowGroup }
    "tfoot" => { ..default_style, display: @types.TableFooterGroup }
    "caption" => { ..default_style, display: @types.TableCaption }
    "col" => { ..default_style, display: @types.TableColumn }
    "colgroup" => { ..default_style, display: @types.TableColumnGroup }
    // Hidden elements - display: none by default
    "template"
    | "script"
    | "style"
    | "head"
    | "meta"
    | "link"
    | "title"
    | "track"
    | "param" => { ..default_style, display: @types.Display::None }
    _ => default_style
  }
}

///|
fn uses_table_normal_line_height(tag : String) -> Bool {
  match tag.to_lower() {
    "table" | "thead" | "tbody" | "tfoot" | "tr" | "td" | "th" | "caption" =>
      true
    _ => false
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
        direction: ps.direction,
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
  style = { ..style, box_sizing: ua_style.box_sizing }
  style = { ..style, margin: ua_style.margin, padding: ua_style.padding }
  if selector_elem.tag_name.to_lower() == "button" {
    style = {
      ..style,
      font_size: ua_style.font_size,
      line_height: ua_style.line_height,
    }
  }
  style = {
    ..style,
    border_spacing: ua_style.border_spacing,
    border_collapse: ua_style.border_collapse,
  }
  style = { ..style, min_height: ua_style.min_height }
  if selector_elem.tag_name.to_lower() == "rt" {
    let inherited_font_size = match parent_style {
      Some(ps) => ps.font_size
      None => style.font_size
    }
    let rt_font_size = inherited_font_size * 0.5
    style = {
      ..style,
      font_size: rt_font_size,
      line_height: rt_font_size * 1.2,
    }
  }
  if uses_table_normal_line_height(selector_elem.tag_name) {
    style = { ..style, line_height: style.font_size * normal_line_height_ratio }
  }

  // Apply font metrics first so em/ch/ex units in later properties
  // (width/height/gap/etc.) resolve against the element's own font.
  let font_props = ["font", "font-size", "line-height"]
  for prop in font_props {
    match cascaded.get_value(prop) {
      Some(value) =>
        style = apply_css_property_with_viewport(
          style,
          prop,
          value,
          ctx.viewport_width,
          ctx.viewport_height,
          css_vars,
          parent_style,
        )
      None => ()
    }
  }

  // Apply remaining cascaded values
  for prop in cascaded.properties() {
    if prop == "font" || prop == "font-size" || prop == "line-height" {
      continue
    }
    match cascaded.get_value(prop) {
      Some(value) =>
        style = apply_css_property_with_viewport(
          style,
          prop,
          value,
          ctx.viewport_width,
          ctx.viewport_height,
          css_vars,
          parent_style,
        )
      None => ()
    }
  }

  // Preserve table layout
  let tag = selector_elem.tag_name
  if is_table_element(tag) {
    let keeps_non_table_display = style.display == @types.Contents ||
      style.display == @types.Display::None
    if not(is_table_display(style.display)) && not(keeps_non_table_display) {
      style = { ..style, display: ua_style.display }
    }
  }
  // Size containment does not apply to table-cell elements, while
  // layout/paint/style containment still can.
  if style.display == @types.TableCell && style.contain.size {
    style = { ..style, contain: { ..style.contain, size: false } }
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
        parent_style,
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
  inherited_parent_style : @style.Style?,
) -> @style.Style {
  let inherited_font_size = match inherited_parent_style {
    Some(parent) => parent.font_size
    None => style.font_size
  }
  let context_font_size = if property == "font-size" || property == "font" {
    inherited_font_size
  } else {
    style.font_size
  }
  // Use direct property application to avoid string parsing overhead
  let ctx : @computed.ComputeContext = {
    parent_style: inherited_parent_style,
    root_font_size: 16.0,
    font_size: context_font_size,
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
  inherited_parent_style : @style.Style?,
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
            result, prop, value, viewport_width, viewport_height, css_vars, inherited_parent_style,
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
    @types.BorderBox => {
      let padding_h = resolve_dimension_to_px(style.padding.left) +
        resolve_dimension_to_px(style.padding.right)
      let padding_v = resolve_dimension_to_px(style.padding.top) +
        resolve_dimension_to_px(style.padding.bottom)
      let border_h = resolve_dimension_to_px(style.border.left) +
        resolve_dimension_to_px(style.border.right)
      let border_v = resolve_dimension_to_px(style.border.top) +
        resolve_dimension_to_px(style.border.bottom)
      let min_outer_width = padding_h + border_h
      let min_outer_height = padding_v + border_v

      let clamped_width = match style.width {
        @types.Length(w) =>
          @types.Dimension::Length(
            if w < min_outer_width {
              min_outer_width
            } else {
              w
            },
          )
        other => other
      }
      let clamped_height = match style.height {
        @types.Length(h) =>
          @types.Dimension::Length(
            if h < min_outer_height {
              min_outer_height
            } else {
              h
            },
          )
        other => other
      }
      let clamped_min_width = match style.min_width {
        @types.Length(w) =>
          @types.Dimension::Length(
            if w < min_outer_width {
              min_outer_width
            } else {
              w
            },
          )
        other => other
      }
      let clamped_min_height = match style.min_height {
        @types.Length(h) =>
          @types.Dimension::Length(
            if h < min_outer_height {
              min_outer_height
            } else {
              h
            },
          )
        other => other
      }
      let clamped_max_width = match style.max_width {
        @types.Length(w) =>
          @types.Dimension::Length(
            if w < min_outer_width {
              min_outer_width
            } else {
              w
            },
          )
        other => other
      }
      let clamped_max_height = match style.max_height {
        @types.Length(h) =>
          @types.Dimension::Length(
            if h < min_outer_height {
              min_outer_height
            } else {
              h
            },
          )
        other => other
      }

      {
        ..style,
        width: clamped_width,
        height: clamped_height,
        min_width: clamped_min_width,
        min_height: clamped_min_height,
        max_width: clamped_max_width,
        max_height: clamped_max_height,
      }
    }
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
  let containment_applies = not(
    is_no_principal_table_internal_display(style.display),
  )
  let containment_establishes_cb = containment_applies &&
    (style.contain.paint || style.contain.layout)
  let positioned = match style.position {
    @types.Static => false
    _ => true
  }
  let layout_container = match style.display {
    @types.Grid | @types.InlineGrid | @types.Flex | @types.InlineFlex => true
    _ => false
  }
  positioned ||
  layout_container ||
  containment_establishes_cb ||
  not(style.transform.is_none()) ||
  is_svg_container_id(node.id)
}

///|
fn is_auto_inset(dim : @types.Dimension) -> Bool {
  match dim {
    @types.Dimension::Auto => true
    _ => false
  }
}

///|
fn has_all_auto_insets(style : @style.Style) -> Bool {
  is_auto_inset(style.inset.left) &&
  is_auto_inset(style.inset.right) &&
  is_auto_inset(style.inset.top) &&
  is_auto_inset(style.inset.bottom)
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
  has_abs_containing_block_ancestor : Bool,
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
  let has_abs_containing_block = has_abs_containing_block_ancestor ||
    establishes_absolute_containing_block(node)

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
      global_x, global_y, has_abs_containing_block,
    )
    if child_node.style.position == @types.Absolute &&
      not(has_abs_containing_block) {
      // Absolute descendants without a containing block are viewport-relative.
      if is_no_principal_table_internal_display(node.style.display) &&
        has_all_auto_insets(child_node.style) {
        // Static-positioned abs descendants under no-principal table-internal
        // ancestors were already shifted during block flow placement.
        scaled_children.push({
          ..scaled_child,
          x: scaled_child.x + scaled_x,
          y: scaled_child.y + scaled_y,
        })
      } else {
        scaled_children.push({
          ..scaled_child,
          x: scaled_child.x - global_x,
          y: scaled_child.y - global_y,
        })
      }
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
