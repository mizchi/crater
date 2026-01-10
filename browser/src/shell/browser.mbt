///|
/// Browser Shell - TUI browser application layer

///|
/// Link found in the page
pub(all) struct Link {
  href : String
  text : String
}

///|
/// Browser state
pub struct Browser {
  /// Current URL
  mut current_url : String
  /// Viewport width in pixels
  viewport_width : Int
  /// Viewport height in pixels
  viewport_height : Int
  /// Current HTML content
  mut html_content : String
  /// External CSS content
  mut external_css : Array[String]
  /// Links found in current page
  mut links : Array[Link]
  /// Currently focused link index (legacy, kept for compatibility)
  mut focused_link : Int
  /// Scroll position (Y offset)
  mut scroll_y : Int
  /// Content height (for scroll limit)
  mut content_height : Int
  /// Link regions for click hit testing (updated on each render)
  mut link_regions : Array[@tui.LinkRegion]
  /// Hit-a-hint mode state
  mut hint_mode : Bool
  /// Current hints (generated when entering hint mode)
  mut hints : Array[@tui.HintData]
  /// Hint input buffer (for multi-char hints)
  mut hint_input : String
  /// Back history (stack of URLs for going back)
  back_history : Array[String]
  /// Forward history (stack of URLs for going forward)
  forward_history : Array[String]
  /// Focus manager for Tab/Shift+Tab navigation
  mut focus_manager : @aom.FocusManager?
  /// Current accessibility tree
  mut a11y_tree : @aom.AccessibilityTree?
}

///|
/// Create a new browser instance
pub fn Browser::new(width : Int, height : Int) -> Browser {
  {
    current_url: "",
    viewport_width: width,
    viewport_height: height,
    html_content: "",
    external_css: [],
    links: [],
    focused_link: 0,
    scroll_y: 0,
    content_height: 0,
    link_regions: [],
    hint_mode: false,
    hints: [],
    hint_input: "",
    back_history: [],
    forward_history: [],
    focus_manager: None,
    a11y_tree: None,
  }
}

///|
/// Resolve relative URL to absolute
fn resolve_url(base_url : String, href : String) -> String {
  // Skip empty, fragment-only, or javascript URLs
  if href.length() == 0 ||
    href.has_prefix("#") ||
    href.has_prefix("javascript:") ||
    href.has_prefix("mailto:") ||
    href.has_prefix("tel:") {
    return ""
  }
  // Already absolute
  if href.has_prefix("http://") || href.has_prefix("https://") {
    return href
  }
  // Protocol-relative
  if href.has_prefix("//") {
    let protocol = if base_url.has_prefix("https://") {
      "https:"
    } else {
      "http:"
    }
    return protocol + href
  }
  // Extract base from URL
  let protocol_end = match base_url.find("://") {
    Some(i) => i
    None => return href
  }
  let after_protocol = base_url[protocol_end + 3:].to_string() catch {
    _ => return href
  }
  let path_start = after_protocol.find("/")
  let origin = match path_start {
    Some(i) =>
      base_url[:protocol_end + 3 + i].to_string() catch {
        _ => base_url
      }
    None => base_url
  }
  // Root-relative
  if href.has_prefix("/") {
    return origin + href
  }
  // Relative - append to current path
  let last_slash = base_url.rev_find("/")
  match last_slash {
    Some(i) if i > protocol_end + 2 =>
      try base_url[:i + 1].to_string() + href catch {
        _ => origin + "/" + href
      }
    _ => origin + "/" + href
  }
}

///|
/// Fetch external stylesheets and return CSS array
async fn fetch_external_css(html : String, base_url : String) -> Array[String] {
  let doc = @html.parse_document(html)
  let link_count = doc.stylesheet_links.length()
  if link_count == 0 {
    return []
  }
  println("Found " + link_count.to_string() + " external stylesheets")
  // Fetch all external CSS
  let css_contents : Array[String] = []
  for link in doc.stylesheet_links {
    let css_url = resolve_url(base_url, link)
    println("Fetching CSS: " + css_url)
    // Try to fetch CSS, ignore errors
    try {
      let response = @http.fetch(css_url)
      css_contents.push(response.body)
      println("  -> OK (" + response.body.length().to_string() + " bytes)")
    } catch {
      err => println("  -> Error: " + err.to_string())
    }
  }
  println("Loaded " + css_contents.length().to_string() + " stylesheets")
  // Analyze CSS support
  analyze_css_support(css_contents)
  css_contents
}

///|
/// Analyze CSS support and print diagnostics
fn analyze_css_support(css_list : Array[String]) -> Unit {
  // Aggregate summaries from all stylesheets
  let mut total = 0
  let mut supported = 0
  let mut partial = 0
  let mut unsupported_layout = 0
  let mut unsupported_visual = 0
  let mut deprecated = 0
  let mut unknown = 0
  let all_diagnostics : Array[@diagnostics.Diagnostic] = []
  let seen : Map[String, Bool] = {}
  // Parse all CSS with diagnostics
  for css in css_list {
    let result = @parser.parse_stylesheet_with_diagnostics(css)
    let summary = result.diagnostics.get_summary()
    // Aggregate counts
    total += summary.total_properties
    supported += summary.supported
    partial += summary.partial
    unsupported_layout += summary.unsupported_layout
    unsupported_visual += summary.unsupported_visual
    deprecated += summary.deprecated
    unknown += summary.unknown
    // Collect unique diagnostics (non-supported only)
    for diag in result.diagnostics.get_diagnostics() {
      let key = diag.property + ":" + diag.value
      if not(seen.contains(key)) {
        seen.set(key, true)
        all_diagnostics.push(diag)
      }
    }
  }
  // Print compact summary
  let buf = StringBuilder::new()
  buf.write_string("\nCSS: ")
  buf.write_string(supported.to_string())
  buf.write_string(" ok")
  if partial > 0 {
    buf.write_string(", ")
    buf.write_string(partial.to_string())
    buf.write_string(" partial")
  }
  if unsupported_visual > 0 {
    buf.write_string(", ")
    buf.write_string(unsupported_visual.to_string())
    buf.write_string(" visual-only")
  }
  if unsupported_layout > 0 {
    buf.write_string(", ")
    buf.write_string(unsupported_layout.to_string())
    buf.write_string(" layout!")
  }
  if unknown > 0 {
    buf.write_string(", ")
    buf.write_string(unknown.to_string())
    buf.write_string(" unknown!")
  }
  println(buf.to_string())
  // Print detailed report if there are issues
  if unsupported_layout > 0 || unknown > 0 {
    println("=== CSS Support Report ===")
    println("Total properties: " + total.to_string())
    println("  Supported: " + supported.to_string())
    if partial > 0 {
      println("  Partial: " + partial.to_string())
    }
    if unsupported_visual > 0 {
      println("  Unsupported (visual): " + unsupported_visual.to_string())
    }
    if unsupported_layout > 0 {
      println(
        "  Unsupported (layout): " +
        unsupported_layout.to_string() +
        " [WARNING]",
      )
    }
    if unknown > 0 {
      println("  Unknown: " + unknown.to_string() + " [ERROR]")
    }
    // Print first few layout-affecting issues
    let layout_issues : Array[@diagnostics.Diagnostic] = []
    for diag in all_diagnostics {
      if @diagnostics.affects_layout(diag.level) {
        layout_issues.push(diag)
      }
    }
    if layout_issues.length() > 0 {
      println("\n--- Layout-affecting issues ---")
      let count = if layout_issues.length() > 10 {
        10
      } else {
        layout_issues.length()
      }
      for i = 0; i < count; i = i + 1 {
        let diag = layout_issues[i]
        println("  " + diag.property + ": " + diag.value)
      }
      if layout_issues.length() > 10 {
        println(
          "  ... and " + (layout_issues.length() - 10).to_string() + " more",
        )
      }
    }
    // Print first few unknown properties
    let unknown_props : Array[@diagnostics.Diagnostic] = []
    for diag in all_diagnostics {
      match diag.level {
        @diagnostics.Unknown => unknown_props.push(diag)
        _ => ()
      }
    }
    if unknown_props.length() > 0 {
      println("\n--- Unknown properties ---")
      let count = if unknown_props.length() > 10 {
        10
      } else {
        unknown_props.length()
      }
      for i = 0; i < count; i = i + 1 {
        let diag = unknown_props[i]
        println("  " + diag.property + ": " + diag.value)
      }
      if unknown_props.length() > 10 {
        println(
          "  ... and " + (unknown_props.length() - 10).to_string() + " more",
        )
      }
    }
  }
}

///|
/// Navigate to a URL and render (adds to back history, clears forward history)
pub async fn Browser::navigate(
  self : Browser,
  url : String,
) -> String raise @http.HttpError {
  // Save current URL to back history before navigating (if not empty)
  if self.current_url.length() > 0 {
    self.back_history.push(self.current_url)
  }
  // Clear forward history on new navigation
  self.forward_history.clear()
  self.load_url(url)
}

///|
/// Load a URL without adding to history (internal use)
async fn Browser::load_url(
  self : Browser,
  url : String,
) -> String raise @http.HttpError {
  self.current_url = url
  // Fetch the page
  let response = @http.fetch(url)
  self.html_content = response.body
  // Fetch external CSS
  self.external_css = fetch_external_css(self.html_content, url) catch {
    _ => [] // Fallback to no external CSS on error
  }
  // Extract links from HTML
  self.links = extract_links(self.html_content)
  self.focused_link = 0
  self.scroll_y = 0
  // Calculate content height
  self.content_height = @renderer.get_content_height_with_css(
    self.html_content,
    self.viewport_width,
    self.viewport_height,
    self.external_css,
  )
  // Build accessibility tree for focus navigation
  self.build_accessibility_tree()
  // Render to Sixel
  self.render()
}

///|
/// Go back to previous page in history and load it
pub async fn Browser::go_back(self : Browser) -> String? raise @http.HttpError {
  if self.back_history.length() == 0 {
    return None
  }
  // Save current URL to forward history
  if self.current_url.length() > 0 {
    self.forward_history.push(self.current_url)
  }
  let url = self.back_history.pop().unwrap()
  let _ = self.load_url(url)
  Some(url)
}

///|
/// Go forward to next page in history and load it
pub async fn Browser::go_forward(
  self : Browser,
) -> String? raise @http.HttpError {
  if self.forward_history.length() == 0 {
    return None
  }
  // Save current URL to back history
  if self.current_url.length() > 0 {
    self.back_history.push(self.current_url)
  }
  let url = self.forward_history.pop().unwrap()
  let _ = self.load_url(url)
  Some(url)
}

///|
/// Render current content to Sixel
pub fn Browser::render(self : Browser) -> String {
  if self.html_content.length() == 0 {
    return ""
  }
  @renderer.render_to_sixel_with_css(
    self.html_content,
    self.viewport_width,
    self.viewport_height,
    self.scroll_y,
    self.external_css,
  )
}

///|
/// Render current content to ANSI text (TUI mode)
pub fn Browser::render_text(self : Browser) -> String {
  if self.html_content.length() == 0 {
    return ""
  }
  let ctx : @renderer.RenderContext = {
    viewport_width: self.viewport_width.to_double(),
    viewport_height: self.viewport_height.to_double(),
    root_font_size: 16.0,
  }
  let node = @renderer.render_to_node_with_external_css(
    self.html_content,
    ctx,
    self.external_css,
  )
  let layout = @renderer.render_with_external_css(
    self.html_content,
    ctx,
    self.external_css,
  )
  // Convert pixel dimensions to character dimensions
  let char_width = self.viewport_width / 8
  let char_height = self.viewport_height / 16
  let char_scroll_y = self.scroll_y / 16
  // Get focused element name for :focus styling
  let focused_element_name = self.get_focused_element_name()
  // Get focused link URL for status bar
  let focused_link_url = self.get_focused_link_url()
  // Use hint mode rendering if in hint mode
  let result = if self.hint_mode {
    @tui.render_to_ansi_with_hints(
      node,
      layout,
      char_width,
      char_height,
      char_scroll_y,
      self.hints,
      self.hint_input,
      focused_element_name~,
    )
  } else {
    @tui.render_to_ansi_with_status(
      node,
      layout,
      char_width,
      char_height,
      char_scroll_y,
      self.current_url,
      self.get_visible_focusable_count(),
      self.get_visible_focus_index(),
      focused_element_name~,
      focused_link_url~,
    )
  }
  // Store link regions for click hit testing
  self.link_regions = result.link_regions
  result.ansi
}

///|
/// Get maximum scroll position
fn Browser::max_scroll(self : Browser) -> Int {
  (self.content_height - self.viewport_height).max(0)
}

///|
/// Scroll down
pub fn Browser::scroll_down(self : Browser, amount : Int) -> Unit {
  self.scroll_y = (self.scroll_y + amount).min(self.max_scroll())
}

///|
/// Scroll up
pub fn Browser::scroll_up(self : Browser, amount : Int) -> Unit {
  self.scroll_y = (self.scroll_y - amount).max(0)
}

///|
/// Check if a link is currently visible on screen
/// A link is visible if its text appears in the link_regions array
fn Browser::is_link_visible(self : Browser, link_name : String) -> Bool {
  for region in self.link_regions {
    if region.text == link_name {
      return true
    }
  }
  false
}

///|
/// Focus next visible focusable element (Tab)
/// Skips elements that are not currently visible on screen
pub fn Browser::next_link(self : Browser) -> Unit {
  match self.focus_manager {
    Some(fm) => {
      // Try to find next visible focusable element
      let count = fm.focusable_count()
      if count == 0 {
        return
      }
      // Try up to count times to find a visible element
      for attempt = 0; attempt < count; attempt = attempt + 1 {
        let _ = fm.focus_next()
        match fm.current() {
          Some(node) =>
            match node.name {
              Some(name) => if self.is_link_visible(name) { return }
              None => ()
            }
          None => return
        }
      }
    }
    None =>
      // Fallback to legacy link navigation
      if self.links.length() > 0 {
        self.focused_link = (self.focused_link + 1) % self.links.length()
      }
  }
}

///|
/// Focus previous visible focusable element (Shift+Tab)
/// Skips elements that are not currently visible on screen
pub fn Browser::prev_link(self : Browser) -> Unit {
  match self.focus_manager {
    Some(fm) => {
      // Try to find previous visible focusable element
      let count = fm.focusable_count()
      if count == 0 {
        return
      }
      // Try up to count times to find a visible element
      for attempt = 0; attempt < count; attempt = attempt + 1 {
        let _ = fm.focus_prev()
        match fm.current() {
          Some(node) =>
            match node.name {
              Some(name) => if self.is_link_visible(name) { return }
              None => ()
            }
          None => return
        }
      }
    }
    None =>
      // Fallback to legacy link navigation
      if self.links.length() > 0 {
        self.focused_link = (self.focused_link - 1 + self.links.length()) %
          self.links.length()
      }
  }
}

///|
/// Build accessibility tree from current HTML content
fn Browser::build_accessibility_tree(self : Browser) -> Unit {
  if self.html_content.length() == 0 {
    self.a11y_tree = None
    self.focus_manager = None
    return
  }
  // Parse HTML document
  let doc = @html.parse_document(self.html_content)
  // Build layout tree and calculate layout to get bounds
  let layout_tree = @tree.LayoutTree::from_html_document(
    doc,
    self.viewport_width.to_double(),
    self.viewport_height.to_double(),
  )
  let _ = layout_tree.calculate_layout(
    self.viewport_width.to_double(),
    self.viewport_height.to_double(),
  )
  // Build accessibility tree with layout bounds
  let tree = @aom.build_accessibility_tree_with_layout(doc, layout_tree)
  self.a11y_tree = Some(tree)
  // Create focus manager
  self.focus_manager = Some(@aom.FocusManager::new(tree))
}

///|
/// Get currently focused element ID from FocusManager
pub fn Browser::get_focused_element_id(self : Browser) -> String? {
  match self.focus_manager {
    Some(fm) => fm.current_id()
    None => None
  }
}

///|
/// Get focus info for rendering (element id and role)
pub fn Browser::get_focus_info(self : Browser) -> (String?, @aom.Role?) {
  match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) => (Some(node.id), Some(node.role))
        None => (None, None)
      }
    None => (None, None)
  }
}

///|
/// Get the accessible name of the currently focused element
/// Used for :focus styling in TUI rendering
pub fn Browser::get_focused_element_name(self : Browser) -> String? {
  match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) => node.name
        None => None
      }
    None => None
  }
}

///|
/// Get currently focused link URL
pub fn Browser::get_focused_link_url(self : Browser) -> String? {
  // Try to get URL from FocusManager first
  match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) =>
          // Check if it's a link and has a name (which may contain href info)
          // For now, we need to look up the link by matching text
          match node.role {
            @aom.Link =>
              // Find matching link by accessible name
              match node.name {
                Some(name) => {
                  for link in self.links {
                    if link.text == name {
                      return Some(resolve_url(self.current_url, link.href))
                    }
                  }
                  None
                }
                None => None
              }
            _ => None
          }
        None => None
      }
    None =>
      // Fallback to legacy
      if self.links.length() > 0 && self.focused_link < self.links.length() {
        Some(self.links[self.focused_link].href)
      } else {
        None
      }
  }
}

///|
/// Get number of focusable elements
pub fn Browser::focusable_count(self : Browser) -> Int {
  match self.focus_manager {
    Some(fm) => fm.focusable_count()
    None => self.links.length()
  }
}

///|
/// Get current focus index (0-based, -1 if no focus)
pub fn Browser::get_focus_index(self : Browser) -> Int {
  match self.focus_manager {
    Some(fm) =>
      if fm.has_focus() {
        // Find current index by matching current id in tab order
        let current_id = fm.current_id()
        let tab_order = fm.get_tab_order()
        for i, item in tab_order {
          if Some(item.node.id) == current_id {
            return i
          }
        }
        -1
      } else {
        -1
      }
    None => self.focused_link
  }
}

///|
/// Get number of visible focusable elements (links visible on screen)
pub fn Browser::get_visible_focusable_count(self : Browser) -> Int {
  self.link_regions.length()
}

///|
/// Get current focus index among visible elements (-1 if no focus or not visible)
pub fn Browser::get_visible_focus_index(self : Browser) -> Int {
  let focused_name = self.get_focused_element_name()
  match focused_name {
    Some(name) => {
      for i, region in self.link_regions {
        if region.text == name {
          return i
        }
      }
      -1
    }
    None => -1
  }
}

///|
/// Find link URL at screen coordinates (for mouse click)
/// Returns the resolved absolute URL if a link is found
pub fn Browser::get_link_at(self : Browser, col : Int, row : Int) -> String? {
  // Find link region at the click position
  match @tui.find_link_at(self.link_regions, col, row) {
    Some(link_text) => {
      // Find matching link in our links array by text
      for link in self.links {
        if link.text == link_text {
          return Some(link.href)
        }
      }
      // No exact match found
      None
    }
    None => None
  }
}

///|
/// Debug: print layout tree
pub fn Browser::debug_layout(self : Browser) -> Unit {
  if self.html_content.length() == 0 {
    println("No content loaded")
    return
  }
  let ctx : @renderer.RenderContext = {
    viewport_width: self.viewport_width.to_double(),
    viewport_height: self.viewport_height.to_double(),
    root_font_size: 16.0,
  }
  let layout = @renderer.render_with_external_css(
    self.html_content,
    ctx,
    self.external_css,
  )
  println("=== Layout Tree ===")
  @renderer.print_layout_tree_with_options(layout, 0, true)
  println("===================")
  println("Total content height: " + layout.height.to_string())
}

///|
/// Render accessibility tree as JSON (for AI scraping)
pub fn Browser::render_json(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) => tree.to_aria_json()
    None => "{}"
  }
}

///|
/// Render accessibility tree as YAML (Playwright-compatible)
pub fn Browser::render_aom(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) => tree.to_aria_snapshot()
    None => ""
  }
}

///|
/// Run Arc90 content extraction and return result
pub fn Browser::render_arc90(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) => {
      let config : @arc90.ExtractConfig = {
        min_text_length: 50,
        viewport_width: self.viewport_width.to_double(),
        viewport_height: self.viewport_height.to_double(),
        ad_sizes: [
          (300.0, 250.0),
          (728.0, 90.0),
          (160.0, 600.0),
          (300.0, 600.0),
          (320.0, 50.0),
          (320.0, 100.0),
        ],
      }
      let result = @arc90.extract_content(tree, config)
      result.to_summary()
    }
    None => "No accessibility tree available."
  }
}

///|
/// Extract links from HTML content
fn extract_links(html : String) -> Array[Link] {
  let links : Array[Link] = []
  // Simple regex-like extraction for <a href="...">...</a>
  let mut i = 0
  let chars = html.to_array()
  let len = chars.length()
  while i < len {
    // Look for <a
    if i + 2 < len &&
      chars[i] == '<' &&
      (chars[i + 1] == 'a' || chars[i + 1] == 'A') &&
      (chars[i + 2] == ' ' || chars[i + 2] == '\t') {
      // Find href="
      let mut j = i + 2
      let mut href = ""
      while j < len && chars[j] != '>' {
        if j + 6 < len &&
          (chars[j] == 'h' || chars[j] == 'H') &&
          (chars[j + 1] == 'r' || chars[j + 1] == 'R') &&
          (chars[j + 2] == 'e' || chars[j + 2] == 'E') &&
          (chars[j + 3] == 'f' || chars[j + 3] == 'F') &&
          chars[j + 4] == '=' {
          let quote = chars[j + 5]
          if quote == '"' || quote == '\'' {
            let mut k = j + 6
            while k < len && chars[k] != quote {
              k = k + 1
            }
            href = chars_to_string(chars[j + 6:k])
          }
        }
        j = j + 1
      }
      // Find link text (between > and </a>)
      if j < len && chars[j] == '>' {
        let text_start = j + 1
        let mut text_end = text_start
        while text_end + 3 < len {
          if chars[text_end] == '<' &&
            chars[text_end + 1] == '/' &&
            (chars[text_end + 2] == 'a' || chars[text_end + 2] == 'A') {
            break
          }
          text_end = text_end + 1
        }
        let text = chars_to_string(chars[text_start:text_end])
          .trim()
          .to_string()
        if href.length() > 0 {
          links.push({ href, text })
        }
        i = text_end
      }
    }
    i = i + 1
  }
  links
}

///|
/// Convert char array/slice to string
fn chars_to_string(chars : ArrayView[Char]) -> String {
  let sb = StringBuilder::new()
  for c in chars {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
/// Enter hint mode - generate hints for visible links only
pub fn Browser::enter_hint_mode(self : Browser) -> Unit {
  if self.link_regions.length() == 0 {
    return // No visible links to hint
  }
  self.hint_mode = true
  self.hint_input = ""
  // Generate hints from visible link regions only
  self.hints = []
  let mut label_idx = 0
  for region in self.link_regions {
    // Find corresponding link href from extracted links
    let mut href = ""
    for link in self.links {
      if region.text == link.text {
        href = resolve_url(self.current_url, link.href)
        break
      }
    }
    // Skip if no href found or resolved URL is empty
    if href.length() == 0 {
      continue
    }
    self.hints.push({
      label: generate_single_label(label_idx),
      href,
      text: region.text,
      col: region.col,
      row: region.row,
    })
    label_idx = label_idx + 1
  }
}

///|
/// Generate a single hint label for index
fn generate_single_label(idx : Int) -> String {
  if idx < 26 {
    // a-z
    (97 + idx).unsafe_to_char().to_string()
  } else {
    // aa, ab, ac, ...
    let first = 97 + idx / 26
    let second = 97 + idx % 26
    first.unsafe_to_char().to_string() + second.unsafe_to_char().to_string()
  }
}

///|
/// Exit hint mode
pub fn Browser::exit_hint_mode(self : Browser) -> Unit {
  self.hint_mode = false
  self.hints = []
  self.hint_input = ""
}

///|
/// Process hint character input
/// Returns Some(url) if a hint is matched, None otherwise
pub fn Browser::process_hint_char(self : Browser, char : String) -> String? {
  self.hint_input = self.hint_input + char
  // Check for exact match
  for hint in self.hints {
    if hint.label == self.hint_input {
      let href = hint.href
      self.exit_hint_mode()
      return Some(href)
    }
  }
  // Check if any hints start with current input
  let mut has_prefix_match = false
  for hint in self.hints {
    if hint.label.has_prefix(self.hint_input) {
      has_prefix_match = true
      break
    }
  }
  // If no prefix matches, exit hint mode
  if not(has_prefix_match) {
    self.exit_hint_mode()
  }
  None
}
