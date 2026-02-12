///|
/// Browser Shell - TUI browser application layer

///|
/// Link found in the page
priv struct Link {
  href : String
  text : String
}

///|
/// Browser output mode
pub(all) enum OutputMode {
  Sixel
  Text
  Json
  Aom
  Arc90
  ExtractMain
  Grounding
}

///|
/// Browser state
struct Browser {
  /// Current URL
  mut current_url : String
  /// Request sandbox policy
  mut request_sandbox : @http.RequestSandbox
  /// Viewport width in pixels
  viewport_width : Int
  /// Viewport height in pixels
  viewport_height : Int
  /// Current HTML content
  mut html_content : String
  /// Parsed document (cached to avoid re-parsing)
  mut parsed_doc : @html.Document?
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
  /// Selection mode (raw mode disabled for text copy)
  mut selection_mode : Bool
  /// Dark mode for display
  mut dark_mode : Bool
  /// Cached render node (for TUI text mode)
  mut render_node : @node.Node?
  /// Cached layout tree (for incremental layout)
  mut layout_tree : @layout.LayoutTree?
  /// Previous TUI buffer for diff rendering
  mut prev_buffer : @tui.CharBuffer?
  /// Last render key (for diff invalidation)
  mut last_render_key : String
  /// Last color scheme used to build render node
  mut last_color_scheme_dark : Bool
  /// DOM tree for JS execution
  mut dom_tree : @dom.DomTree?
  /// Task scheduler
  scheduler : @scheduler.Scheduler
  /// Script executor for JS execution
  mut script_executor : @js.ScriptExecutor?
  /// Whether JavaScript execution is enabled (requires --enable-js flag)
  mut enable_js : Bool
  /// Element scroll states (keyed by element id)
  /// For elements with overflow: auto/scroll that have scrollable content
  element_scroll_states : Map[String, @dom.ScrollState]
  /// Currently focused scrollable element id (for keyboard scrolling)
  focused_scrollable : Ref[String?]
  /// No-color mode (disable ANSI color codes)
  mut no_color : Bool
}

///|
/// Create a new browser instance
pub fn Browser::new(width : Int, height : Int) -> Browser {
  {
    current_url: "",
    request_sandbox: @http.RequestSandbox::Open,
    viewport_width: width,
    viewport_height: height,
    html_content: "",
    parsed_doc: None,
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
    selection_mode: false,
    dark_mode: false,
    render_node: None,
    layout_tree: None,
    prev_buffer: None,
    last_render_key: "",
    last_color_scheme_dark: false,
    dom_tree: None,
    scheduler: @scheduler.Scheduler::new(),
    script_executor: None,
    enable_js: false, // Disabled by default for security
    element_scroll_states: {},
    focused_scrollable: Ref::new(None),
    no_color: false,
  }
}

///|
/// Enable or disable JavaScript execution
/// JavaScript is disabled by default for security reasons.
/// Use --enable-js flag to enable it.
pub fn Browser::set_enable_js(self : Browser, enable : Bool) -> Unit {
  self.enable_js = enable
}

///|
/// Configure request sandbox policy
pub fn Browser::set_request_sandbox(
  self : Browser,
  sandbox : @http.RequestSandbox,
) -> Unit {
  self.request_sandbox = sandbox
}

///|
/// Get current URL
pub fn Browser::get_current_url(self : Browser) -> String {
  self.current_url
}

///|
/// Get viewport height in pixels
pub fn Browser::get_viewport_height(self : Browser) -> Int {
  self.viewport_height
}

///|
/// Get number of extracted links
pub fn Browser::get_link_count(self : Browser) -> Int {
  self.links.length()
}

///|
/// Get currently focused link index
pub fn Browser::get_focused_link_index(self : Browser) -> Int {
  self.focused_link
}

///|
/// Whether hint mode is active
pub fn Browser::is_hint_mode(self : Browser) -> Bool {
  self.hint_mode
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
async fn fetch_external_css(
  html : String,
  base_url : String,
  sandbox : @http.RequestSandbox,
) -> Array[String] {
  // Use lightweight extraction instead of full DOM parsing
  let stylesheet_links = @html.extract_stylesheet_links(html)
  let link_count = stylesheet_links.length()
  if link_count == 0 {
    return []
  }
  println("Found " + link_count.to_string() + " external stylesheets")
  // Fetch all external CSS
  let css_contents : Array[String] = []
  for link in stylesheet_links {
    let css_url = resolve_url(base_url, link)
    println("Fetching CSS: " + css_url)
    // Try to fetch CSS, ignore errors
    try {
      let options = {
        ..@http.FetchOptions::default(),
        mode: @http.RequestMode::NoCors,
        origin: base_url,
        sandbox,
      }
      let response = @http.fetch(css_url, options~)
      css_contents.push(response.body)
      println("  -> OK (" + response.body.length().to_string() + " bytes)")
    } catch {
      err => println("  -> Error: " + err.to_string())
    }
  }
  println("Loaded " + css_contents.length().to_string() + " stylesheets")
  // Analyze CSS support
  @browser_contract.report_css_support(css_contents)
  css_contents
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
/// Navigate to URL in lightweight mode (for --json, --aom modes)
/// Skips CSS cascade and layout calculation to reduce memory usage
pub async fn Browser::navigate_lightweight(
  self : Browser,
  url : String,
) -> String raise @http.HttpError {
  self.load_url_lightweight(url)
}

///|
/// Load a URL without adding to history (internal use)
async fn Browser::load_url(
  self : Browser,
  url : String,
) -> String raise @http.HttpError {
  self.current_url = url
  // Fetch the page
  let page_options = {
    ..@http.FetchOptions::default(),
    mode: @http.RequestMode::Navigate,
    origin: url,
    sandbox: self.request_sandbox,
  }
  let response = @http.fetch(url, options=page_options)
  self.html_content = response.body
  // Fetch external CSS using lightweight extraction (no full parsing)
  self.external_css = fetch_external_css(
    self.html_content,
    url,
    self.request_sandbox,
  ) catch {
    _ => [] // Fallback to no external CSS on error
  }
  // Extract links from HTML (lightweight, no full parsing)
  self.links = extract_links(self.html_content)
  self.focused_link = 0
  self.scroll_y = 0
  // Clear element scroll states on navigation
  self.clear_element_scroll_states()
  // Parse HTML using regular parser (streaming parser under investigation)
  let doc = @html.assign_synthetic_ids(@html.parse_document(self.html_content))
  self.parsed_doc = Some(doc)
  self.render_node = None
  self.layout_tree = None
  self.prev_buffer = None
  self.last_render_key = ""
  // Execute scripts including external (JS execution)
  let script_count = self.execute_scripts_async() catch { _ => 0 }
  if script_count > 0 {
    println(
      "Executed " + script_count.to_string() + " script(s) during page load",
    )
  }
  // Calculate content height from latest parsed document
  let content_doc = match self.parsed_doc {
    Some(d) => d
    None => doc
  }
  self.content_height = @renderer.get_content_height_with_document(
    content_doc,
    self.viewport_width,
    self.viewport_height,
    self.external_css,
  )
  // Build accessibility tree for focus navigation (uses cached doc)
  self.build_accessibility_tree()
  // Render to Sixel
  self.render()
}

///|
/// Load a URL in lightweight mode (for --json, --aom modes)
/// Skips CSS cascade and layout calculation to reduce memory usage
async fn Browser::load_url_lightweight(
  self : Browser,
  url : String,
) -> String raise @http.HttpError {
  self.current_url = url
  // Fetch the page
  let page_options = {
    ..@http.FetchOptions::default(),
    mode: @http.RequestMode::Navigate,
    origin: url,
    sandbox: self.request_sandbox,
  }
  let response = @http.fetch(url, options=page_options)
  self.html_content = response.body
  // Skip external CSS fetching in lightweight mode
  self.external_css = []
  // Skip link extraction (not needed for JSON/AOM output)
  self.links = []
  self.focused_link = 0
  self.scroll_y = 0
  // Clear element scroll states on navigation
  self.clear_element_scroll_states()
  // Parse HTML using regular parser (streaming parser under investigation)
  let doc = @html.assign_synthetic_ids(@html.parse_document(self.html_content))
  self.parsed_doc = Some(doc)
  self.render_node = None
  self.layout_tree = None
  self.prev_buffer = None
  self.last_render_key = ""
  // Skip content height calculation in lightweight mode
  self.content_height = 0
  // Build lightweight accessibility tree (no CSS cascade, no layout)
  self.build_accessibility_tree_lightweight()
  // Return empty string (no rendering in lightweight mode)
  ""
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
/// Render current content in selected output mode
pub fn Browser::render_output(self : Browser, mode : OutputMode) -> String {
  match mode {
    Sixel => self.render()
    Text => self.render_text()
    Json => self.render_json()
    Aom => self.render_aom()
    Arc90 => self.render_arc90()
    ExtractMain => self.render_extract_main()
    Grounding => self.render_grounding()
  }
}

///|
/// Render current content to Sixel
fn Browser::render(self : Browser) -> String {
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
fn Browser::render_text(self : Browser) -> String {
  if self.html_content.length() == 0 {
    return ""
  }
  let ctx = @browser_contract.create_render_context(
    self.viewport_width,
    self.viewport_height,
    self.dark_mode,
  )
  if self.last_color_scheme_dark != self.dark_mode {
    self.render_node = None
    self.layout_tree = None
    self.prev_buffer = None
    self.last_render_key = ""
  }
  let mut force_full = false
  // Build or reuse cached render node + layout tree
  let render_node = match (self.render_node, self.layout_tree) {
    (Some(node), Some(_tree)) => node
    _ => {
      force_full = true
      let n = match self.parsed_doc {
        Some(doc) =>
          @renderer.render_to_node_with_document(doc, ctx, self.external_css)
        None =>
          @renderer.render_to_node_with_external_css(
            self.html_content,
            ctx,
            self.external_css,
          )
      }
      let tree = @layout.LayoutTree::from_node(
        n,
        self.viewport_width.to_double(),
        self.viewport_height.to_double(),
      )
      self.render_node = Some(n)
      self.layout_tree = Some(tree)
      n
    }
  }
  let (layout, dirty_rects) = match self.layout_tree {
    Some(tree) => {
      let l = tree.compute_incremental()
      let rects = tree.collect_dirty_rects()
      tree.mark_all_layouts_seen()
      self.layout_tree = Some(tree)
      (l, rects)
    }
    None => {
      force_full = true
      let tree = @layout.LayoutTree::from_node(
        render_node,
        self.viewport_width.to_double(),
        self.viewport_height.to_double(),
      )
      let l = tree.compute_incremental()
      let rects = tree.collect_dirty_rects()
      tree.mark_all_layouts_seen()
      self.layout_tree = Some(tree)
      (l, rects)
    }
  }
  // Convert pixel dimensions to character dimensions
  let char_width = self.viewport_width / 8
  let char_height = self.viewport_height / 16
  let char_scroll_y = self.scroll_y / 16
  // Get focused element name for :focus styling
  let focused_element_name = self.get_focused_element_name()
  // Get focused link URL for status bar
  let focused_link_url = self.get_focused_link_url()
  let render_key = self.current_url +
    "|" +
    self.scroll_y.to_string() +
    "|" +
    self.focused_link.to_string() +
    "|" +
    focused_element_name.unwrap_or("") +
    "|" +
    focused_link_url.unwrap_or("") +
    "|" +
    self.hint_mode.to_string() +
    "|" +
    self.hint_input +
    "|" +
    self.selection_mode.to_string() +
    "|" +
    self.dark_mode.to_string() +
    "|" +
    self.viewport_width.to_string() +
    "|" +
    self.viewport_height.to_string()
  if render_key != self.last_render_key {
    force_full = true
  }
  // Use hint mode rendering if in hint mode
  let buffer_result = if self.hint_mode {
    @tui.render_to_buffer_with_hints(
      render_node,
      layout,
      char_width,
      char_height,
      char_scroll_y,
      self.hints,
      self.hint_input,
      focused_element_name~,
    )
  } else {
    @tui.render_to_buffer_with_status(
      render_node,
      layout,
      char_width,
      char_height,
      char_scroll_y,
      self.current_url,
      self.get_visible_focusable_count(),
      self.get_visible_focus_index(),
      focused_element_name~,
      focused_link_url~,
      selection_mode=self.selection_mode,
      dark_mode=self.dark_mode,
      total_content_height=self.content_height,
      show_scrollbar=true,
      element_scroll_positions=self.get_element_scroll_positions(),
    )
  }
  // Store link regions for click hit testing
  self.link_regions = buffer_result.link_regions
  // Initialize scroll states for scrollable elements
  self.init_scrollable_elements(buffer_result.scrollable_elements)
  // Build plain links array for no_color mode with clickable hyperlinks
  let plain_links : Array[@tui.PlainLink] = []
  if self.no_color {
    for region in buffer_result.link_regions {
      // Find matching link URL from extracted links
      for link in self.links {
        if region.text == link.text {
          let url = resolve_url(self.current_url, link.href)
          if url.length() > 0 {
            plain_links.push({
              col: region.col,
              row: region.row,
              width: region.width,
              url,
            })
          }
          break
        }
      }
    }
  }
  // Choose buffer-to-output based on no_color mode
  let ansi = match self.prev_buffer {
    Some(prev) =>
      if force_full {
        if self.no_color {
          @tui.clear_screen() +
          @tui.buffer_to_plain_with_links(buffer_result.buffer, plain_links)
        } else {
          @tui.clear_screen() + @tui.buffer_to_ansi(buffer_result.buffer)
        }
      } else if dirty_rects.length() > 0 && not(self.no_color) {
        // Diff rendering only for color mode (plain mode always does full redraw)
        let content_height = if self.hint_mode {
          char_height - 1
        } else {
          char_height - 1
        }
        let row_offset = if self.hint_mode { 0 } else { 1 }
        let dirty_cells = @tui.dirty_rects_to_cells(
          dirty_rects,
          self.scroll_y,
          char_width,
          content_height,
          row_offset,
        )
        @tui.buffer_diff_to_ansi_rects(buffer_result.buffer, prev, dirty_cells)
      } else if self.no_color {
        @tui.clear_screen() +
        @tui.buffer_to_plain_with_links(buffer_result.buffer, plain_links)
      } else {
        ""
      }
    None =>
      if self.no_color {
        @tui.clear_screen() +
        @tui.buffer_to_plain_with_links(buffer_result.buffer, plain_links)
      } else {
        @tui.clear_screen() + @tui.buffer_to_ansi(buffer_result.buffer)
      }
  }
  self.prev_buffer = Some(buffer_result.buffer)
  self.last_render_key = render_key
  self.last_color_scheme_dark = self.dark_mode
  ansi
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
/// Initialize scroll state for an element
/// Call this when a scrollable element is detected
fn Browser::init_element_scroll(
  self : Browser,
  element_id : String,
  scroll_width : Double,
  scroll_height : Double,
  client_width : Double,
  client_height : Double,
) -> Unit {
  let state = @dom.ScrollState::new(
    scroll_width, scroll_height, client_width, client_height,
  )
  self.element_scroll_states.set(element_id, state)
}

///|
/// Clear all element scroll states (call on page navigation)
fn Browser::clear_element_scroll_states(self : Browser) -> Unit {
  self.element_scroll_states.clear()
  self.focused_scrollable.val = None
}

///|
/// Initialize scroll states from detected scrollable elements
/// Called during render to set up scroll states for elements with overflow
fn Browser::init_scrollable_elements(
  self : Browser,
  elements : Array[@paint.ScrollableElement],
) -> Unit {
  for elem in elements {
    // Only initialize if not already tracked (preserve scroll position)
    if not(self.element_scroll_states.contains(elem.id)) {
      self.init_element_scroll(
        elem.id,
        elem.scroll_width,
        elem.scroll_height,
        elem.client_width,
        elem.client_height,
      )
    }
  }
}

///|
/// Convert element scroll states to TUI format for rendering
fn Browser::get_element_scroll_positions(
  self : Browser,
) -> Map[String, @tui.ElementScrollPos] {
  let result : Map[String, @tui.ElementScrollPos] = {}
  self.element_scroll_states.each(fn(id, state) {
    result.set(id, {
      scroll_top: state.scroll_top,
      scroll_height: state.scroll_height,
      client_height: state.client_height,
    })
  })
  result
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
  // Use cached parsed document if available
  let doc = match self.parsed_doc {
    Some(d) => d
    None => {
      if self.html_content.length() == 0 {
        self.a11y_tree = None
        self.focus_manager = None
        return
      }
      // Fallback: parse if not cached (shouldn't happen in normal flow)
      let d = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(d)
      d
    }
  }
  // Use the renderer's layout which applies CSS properly
  let ctx = @browser_contract.create_render_context(
    self.viewport_width,
    self.viewport_height,
    false,
  )
  // Render with CSS to get proper layout bounds
  // Use the document with synthetic IDs for consistent ID matching
  let layout = @renderer.render_document_with_external_css(
    doc,
    ctx,
    self.external_css,
  )
  // Build accessibility tree with renderer's layout bounds
  let tree = @aom.build_accessibility_tree_with_node_layout(doc, layout)
  self.a11y_tree = Some(tree)
  // Create focus manager
  self.focus_manager = Some(@aom.FocusManager::new(tree))
}

///|
/// Build lightweight accessibility tree (no CSS cascade, no layout)
/// Used for --json and --aom modes to reduce memory usage
fn Browser::build_accessibility_tree_lightweight(self : Browser) -> Unit {
  // Use cached parsed document if available
  let doc = match self.parsed_doc {
    Some(d) => d
    None => {
      if self.html_content.length() == 0 {
        self.a11y_tree = None
        self.focus_manager = None
        return
      }
      // Parse with regular parser
      let d = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(d)
      d
    }
  }
  // Build lightweight accessibility tree (skips CSS cascade and layout)
  let tree = @aom.build_accessibility_tree_lightweight(doc)
  self.a11y_tree = Some(tree)
  // No focus manager needed for JSON/AOM output
  self.focus_manager = None
}

///|
/// Get the accessible name of the currently focused element
/// Used for :focus styling in TUI rendering
fn Browser::get_focused_element_name(self : Browser) -> String? {
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
/// Get number of visible focusable elements (links visible on screen)
fn Browser::get_visible_focusable_count(self : Browser) -> Int {
  self.link_regions.length()
}

///|
/// Get current focus index among visible elements (-1 if no focus or not visible)
fn Browser::get_visible_focus_index(self : Browser) -> Int {
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
  let ctx = @browser_contract.create_render_context(
    self.viewport_width,
    self.viewport_height,
    false,
  )
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
fn Browser::render_json(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) => tree.to_aria_json()
    None => "{}"
  }
}

///|
/// Render accessibility tree as YAML (Playwright-compatible)
fn Browser::render_aom(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) => tree.to_aria_snapshot()
    None => ""
  }
}

///|
/// Run Arc90 content extraction and return result
fn Browser::render_arc90(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) =>
      @browser_contract.render_arc90_summary(
        tree,
        self.viewport_width,
        self.viewport_height,
      )
    None => "No accessibility tree available."
  }
}

///|
/// Extract main content text using Arc90 algorithm
fn Browser::render_extract_main(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) =>
      @browser_contract.extract_main_text(
        tree,
        self.viewport_width,
        self.viewport_height,
      )
    None => "No accessibility tree available."
  }
}

///|
/// Run visual grounding demo and return results
fn Browser::render_grounding(self : Browser) -> String {
  match self.a11y_tree {
    Some(tree) =>
      @browser_contract.render_grounding_demo(
        tree,
        self.viewport_width,
        self.viewport_height,
      )
    None => "No accessibility tree available."
  }
}

///|
/// Get character at index from string (returns '\0' if out of bounds)
fn char_at(s : String, i : Int) -> Char {
  if i < 0 || i >= s.length() {
    '\u0000'
  } else {
    s[i].to_int().unsafe_to_char()
  }
}

///|
/// Extract links from HTML content (memory-efficient version)
fn extract_links(html : String) -> Array[Link] {
  let links : Array[Link] = []
  let len = html.length()
  let mut i = 0
  while i < len {
    // Look for <a
    if i + 2 < len &&
      char_at(html, i) == '<' &&
      (char_at(html, i + 1) == 'a' || char_at(html, i + 1) == 'A') &&
      (char_at(html, i + 2) == ' ' || char_at(html, i + 2) == '\t') {
      // Find href="
      let mut j = i + 2
      let mut href = ""
      while j < len && char_at(html, j) != '>' {
        if j + 6 < len &&
          (char_at(html, j) == 'h' || char_at(html, j) == 'H') &&
          (char_at(html, j + 1) == 'r' || char_at(html, j + 1) == 'R') &&
          (char_at(html, j + 2) == 'e' || char_at(html, j + 2) == 'E') &&
          (char_at(html, j + 3) == 'f' || char_at(html, j + 3) == 'F') &&
          char_at(html, j + 4) == '=' {
          let quote = char_at(html, j + 5)
          if quote == '"' || quote == '\'' {
            let mut k = j + 6
            while k < len && char_at(html, k) != quote {
              k = k + 1
            }
            href = html.unsafe_substring(start=j + 6, end=k)
          }
        }
        j = j + 1
      }
      // Find link text (between > and </a>)
      if j < len && char_at(html, j) == '>' {
        let text_start = j + 1
        let mut text_end = text_start
        while text_end + 3 < len {
          if char_at(html, text_end) == '<' &&
            char_at(html, text_end + 1) == '/' &&
            (
              char_at(html, text_end + 2) == 'a' ||
              char_at(html, text_end + 2) == 'A'
            ) {
            break
          }
          text_end = text_end + 1
        }
        let text = html
          .unsafe_substring(start=text_start, end=text_end)
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
/// Toggle selection mode (for text copy with mouse)
/// Returns true if selection mode is now enabled, false if disabled
pub fn Browser::toggle_selection_mode(self : Browser) -> Bool {
  self.selection_mode = not(self.selection_mode)
  self.selection_mode
}

///|
/// Toggle dark mode
pub fn Browser::toggle_dark_mode(self : Browser) -> Unit {
  self.dark_mode = not(self.dark_mode)
}

///|
/// Set dark mode explicitly
pub fn Browser::set_dark_mode(self : Browser, enabled : Bool) -> Unit {
  self.dark_mode = enabled
}

///|
/// Set no-color mode (disable ANSI color codes)
pub fn Browser::set_no_color(self : Browser, enabled : Bool) -> Unit {
  self.no_color = enabled
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

///|
/// Script info extracted from HTML
priv struct ScriptInfo {
  /// Inline script source (empty if external)
  source : String
  /// External script URL (empty if inline)
  src : String
  /// Whether script is async
  is_async : Bool
  /// Whether script is deferred
  is_defer : Bool
  /// Script type attribute (empty for default JavaScript)
  script_type : String
}

///|
/// Check if a script type is executable as JavaScript
fn is_executable_script_type(script_type : String) -> Bool {
  // Empty type or module/javascript types are executable
  if script_type.length() == 0 {
    return true
  }
  let lower = script_type.to_lower()
  // Standard JavaScript MIME types
  lower == "text/javascript" ||
  lower == "application/javascript" ||
  lower == "module"
}

///|
/// Extract script tags from HTML
fn extract_scripts(html : String) -> Array[ScriptInfo] {
  let scripts : Array[ScriptInfo] = []
  let len = html.length()
  let mut i = 0
  while i < len {
    // Look for <script
    if i + 7 < len &&
      char_at(html, i) == '<' &&
      (char_at(html, i + 1) == 's' || char_at(html, i + 1) == 'S') &&
      (char_at(html, i + 2) == 'c' || char_at(html, i + 2) == 'C') &&
      (char_at(html, i + 3) == 'r' || char_at(html, i + 3) == 'R') &&
      (char_at(html, i + 4) == 'i' || char_at(html, i + 4) == 'I') &&
      (char_at(html, i + 5) == 'p' || char_at(html, i + 5) == 'P') &&
      (char_at(html, i + 6) == 't' || char_at(html, i + 6) == 'T') &&
      (
        char_at(html, i + 7) == ' ' ||
        char_at(html, i + 7) == '>' ||
        char_at(html, i + 7) == '\t' ||
        char_at(html, i + 7) == '\n'
      ) {
      // Parse script tag attributes
      let mut j = i + 7
      let mut src = ""
      let mut script_type = ""
      let mut is_async = false
      let mut is_defer = false
      // Find end of opening tag
      while j < len && char_at(html, j) != '>' {
        // Check for src="..."
        if j + 5 < len &&
          (char_at(html, j) == 's' || char_at(html, j) == 'S') &&
          (char_at(html, j + 1) == 'r' || char_at(html, j + 1) == 'R') &&
          (char_at(html, j + 2) == 'c' || char_at(html, j + 2) == 'C') &&
          char_at(html, j + 3) == '=' {
          let quote = char_at(html, j + 4)
          if quote == '"' || quote == '\'' {
            let mut k = j + 5
            while k < len && char_at(html, k) != quote {
              k = k + 1
            }
            src = html.unsafe_substring(start=j + 5, end=k)
            j = k
          }
        }
        // Check for type="..."
        if j + 6 < len &&
          (char_at(html, j) == 't' || char_at(html, j) == 'T') &&
          (char_at(html, j + 1) == 'y' || char_at(html, j + 1) == 'Y') &&
          (char_at(html, j + 2) == 'p' || char_at(html, j + 2) == 'P') &&
          (char_at(html, j + 3) == 'e' || char_at(html, j + 3) == 'E') &&
          char_at(html, j + 4) == '=' {
          let quote = char_at(html, j + 5)
          if quote == '"' || quote == '\'' {
            let mut k = j + 6
            while k < len && char_at(html, k) != quote {
              k = k + 1
            }
            script_type = html.unsafe_substring(start=j + 6, end=k)
            j = k
          }
        }
        // Check for async
        if j + 5 < len &&
          (char_at(html, j) == 'a' || char_at(html, j) == 'A') &&
          (char_at(html, j + 1) == 's' || char_at(html, j + 1) == 'S') &&
          (char_at(html, j + 2) == 'y' || char_at(html, j + 2) == 'Y') &&
          (char_at(html, j + 3) == 'n' || char_at(html, j + 3) == 'N') &&
          (char_at(html, j + 4) == 'c' || char_at(html, j + 4) == 'C') {
          is_async = true
        }
        // Check for defer
        if j + 5 < len &&
          (char_at(html, j) == 'd' || char_at(html, j) == 'D') &&
          (char_at(html, j + 1) == 'e' || char_at(html, j + 1) == 'E') &&
          (char_at(html, j + 2) == 'f' || char_at(html, j + 2) == 'F') &&
          (char_at(html, j + 3) == 'e' || char_at(html, j + 3) == 'E') &&
          (char_at(html, j + 4) == 'r' || char_at(html, j + 4) == 'R') {
          is_defer = true
        }
        j = j + 1
      }
      // Extract inline script content if no src
      let mut source = ""
      if src.length() == 0 && j < len && char_at(html, j) == '>' {
        let content_start = j + 1
        // Find </script>
        let mut content_end = content_start
        while content_end + 8 < len {
          if char_at(html, content_end) == '<' &&
            char_at(html, content_end + 1) == '/' &&
            (
              char_at(html, content_end + 2) == 's' ||
              char_at(html, content_end + 2) == 'S'
            ) &&
            (
              char_at(html, content_end + 3) == 'c' ||
              char_at(html, content_end + 3) == 'C'
            ) &&
            (
              char_at(html, content_end + 4) == 'r' ||
              char_at(html, content_end + 4) == 'R'
            ) &&
            (
              char_at(html, content_end + 5) == 'i' ||
              char_at(html, content_end + 5) == 'I'
            ) &&
            (
              char_at(html, content_end + 6) == 'p' ||
              char_at(html, content_end + 6) == 'P'
            ) &&
            (
              char_at(html, content_end + 7) == 't' ||
              char_at(html, content_end + 7) == 'T'
            ) {
            break
          }
          content_end = content_end + 1
        }
        source = html
          .unsafe_substring(start=content_start, end=content_end)
          .trim()
          .to_string()
        i = content_end
      }
      // Add script info if we have source or src
      if source.length() > 0 || src.length() > 0 {
        scripts.push({ source, src, is_async, is_defer, script_type })
      }
    }
    i = i + 1
  }
  scripts
}

///|
/// Initialize DOM tree and script executor
fn Browser::init_js_execution(self : Browser) -> Unit {
  // Build from parsed_doc/html_content when available so scripts can mutate
  // existing DOM and those mutations can be reflected back to rendering.
  let dom = match self.parsed_doc {
    Some(doc) => build_dom_tree_from_document(doc)
    None =>
      if self.html_content.length() > 0 {
        let doc = @html.assign_synthetic_ids(
          @html.parse_document(self.html_content),
        )
        self.parsed_doc = Some(doc)
        build_dom_tree_from_document(doc)
      } else {
        let d = @dom.DomTree::new()
        let html = d.create_element("html")
        let head = d.create_element("head")
        let body = d.create_element("body")
        let doc_id = d.get_document()
        let _ = d.append_child(doc_id, html)
        let _ = d.append_child(html, head)
        let _ = d.append_child(html, body)
        d
      }
  }
  self.dom_tree = Some(dom)
  self.script_executor = Some(@js.ScriptExecutor::new(dom))
}

///|
/// Execute scripts from the page (inline only, sync version)
/// Requires enable_js to be set to true (use --enable-js flag)
fn Browser::execute_scripts(self : Browser) -> Int {
  // Check if JS execution is enabled
  if not(self.enable_js) {
    return 0
  }
  // Ensure JS execution is initialized
  if self.dom_tree is None {
    self.init_js_execution()
  }
  // Extract scripts from HTML
  let scripts = extract_scripts(self.html_content)
  if scripts.length() == 0 {
    return 0
  }
  println("Found " + scripts.length().to_string() + " script(s)")
  let mut executed = 0
  for script in scripts {
    // Skip external scripts (use execute_scripts_async for external)
    if script.src.length() > 0 {
      println("  [SKIP] External script: " + script.src)
      continue
    }
    // Queue script for execution
    let blocking = not(script.is_async) && not(script.is_defer)
    let task_id = @js.enqueue_script(self.scheduler, script.source, blocking)
    println(
      "  [QUEUED] Inline script (task " +
      task_id.to_string() +
      ", blocking=" +
      blocking.to_string() +
      ")",
    )
  }
  // Process queued scripts
  match self.dom_tree {
    Some(dom) => {
      executed = @js.process_script_tasks(self.scheduler, dom)
      if executed > 0 {
        self.sync_render_state_from_dom_tree()
      }
      // Print JS logs
      match self.script_executor {
        Some(executor) => {
          for log in executor.get_logs() {
            println("[JS] " + log)
          }
          executor.clear_logs()
        }
        None => ()
      }
    }
    None => ()
  }
  println("Executed " + executed.to_string() + " script(s)")
  executed
}

///|
/// Execute scripts from the page (including external scripts, async version)
/// Requires enable_js to be set to true (use --enable-js flag)
async fn Browser::execute_scripts_async(self : Browser) -> Int {
  // Check if JS execution is enabled
  if not(self.enable_js) {
    return 0
  }
  // Ensure JS execution is initialized
  if self.dom_tree is None {
    self.init_js_execution()
  }
  // Extract scripts from HTML
  let scripts = extract_scripts(self.html_content)
  if scripts.length() == 0 {
    return 0
  }
  println("Found " + scripts.length().to_string() + " script(s)")
  let mut executed = 0
  for script in scripts {
    // Skip non-JavaScript scripts (e.g., type="application/json")
    if not(is_executable_script_type(script.script_type)) {
      println("  [SKIP] Non-JS script type: " + script.script_type)
      continue
    }
    // Determine script source
    let mut source = ""
    let mut script_kind = "Inline"
    if script.src.length() > 0 {
      // Fetch external script
      let script_url = resolve_url(self.current_url, script.src)
      if script_url.length() == 0 {
        println("  [SKIP] Invalid script URL: " + script.src)
        continue
      }
      println("  [FETCH] External script: " + script_url)
      try {
        let script_options = {
          ..@http.FetchOptions::default(),
          mode: @http.RequestMode::NoCors,
          origin: self.current_url,
          sandbox: self.request_sandbox,
        }
        let response = @http.fetch(script_url, options=script_options)
        println("    -> OK (" + response.body.length().to_string() + " bytes)")
        source = response.body
        script_kind = "External"
      } catch {
        err => {
          println("    -> Error: " + err.to_string())
          continue
        }
      }
    } else {
      source = script.source
    }
    // Skip empty scripts
    if source.length() == 0 {
      continue
    }
    // Queue script for execution
    let blocking = not(script.is_async) && not(script.is_defer)
    let task_id = @js.enqueue_script(self.scheduler, source, blocking)
    println(
      "  [QUEUED] " +
      script_kind +
      " script (task " +
      task_id.to_string() +
      ", blocking=" +
      blocking.to_string() +
      ")",
    )
  }
  // Process queued scripts
  match self.dom_tree {
    Some(dom) => {
      executed = @js.process_script_tasks(self.scheduler, dom)
      if executed > 0 {
        self.sync_render_state_from_dom_tree()
      }
      // Print JS logs
      match self.script_executor {
        Some(executor) => {
          for log in executor.get_logs() {
            println("[JS] " + log)
          }
          executor.clear_logs()
        }
        None => ()
      }
    }
    None => ()
  }
  println("Executed " + executed.to_string() + " script(s)")
  executed
}

///|
/// Apply JS-mutated DomTree back to renderer inputs and invalidate caches
fn Browser::sync_render_state_from_dom_tree(self : Browser) -> Unit {
  match self.dom_tree {
    Some(dom) => {
      let next_html = @js.serialize_dom_to_html(dom)
      if next_html.length() == 0 {
        return
      }
      self.html_content = next_html
      self.links = extract_links(self.html_content)
      if self.links.length() == 0 {
        self.focused_link = 0
      } else if self.focused_link >= self.links.length() {
        self.focused_link = self.links.length() - 1
      }
      let next_doc = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(next_doc)
      self.render_node = None
      self.layout_tree = None
      self.prev_buffer = None
      self.last_render_key = ""
      self.content_height = @renderer.get_content_height_with_document(
        next_doc,
        self.viewport_width,
        self.viewport_height,
        self.external_css,
      )
      self.build_accessibility_tree()
    }
    None => ()
  }
}

///|
fn build_dom_tree_from_document(doc : @html.Document) -> @dom.DomTree {
  let dom = @dom.DomTree::new()
  let doc_id = dom.get_document()
  let root_id = build_dom_element(dom, doc.root)
  let _ = dom.append_child(doc_id, root_id)
  dom
}

///|
fn build_dom_element(dom : @dom.DomTree, elem : @html.Element) -> @dom.NodeId {
  let node_id = dom.create_element(elem.tag)
  for name, value in elem.attributes {
    let _ = dom.set_attribute(node_id, name, value)
  }
  for child in elem.children {
    match child {
      @html.Node::Element(child_elem) => {
        let child_id = build_dom_element(dom, child_elem)
        let _ = dom.append_child(node_id, child_id)
      }
      @html.Node::Text(text) =>
        if text.length() > 0 {
          let text_id = dom.create_text(text)
          let _ = dom.append_child(node_id, text_id)
        }
    }
  }
  node_id
}
