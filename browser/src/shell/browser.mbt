///|
/// Browser Shell - TUI browser application layer

///|
let default_image_cache_max_bytes : Int = 8 * 1024 * 1024

///|
/// Link found in the page
priv struct Link {
  href : String
  text : String
}

///|
priv struct ClickDispatchResult {
  handled : Bool
  allow_default : Bool
}

///|
priv enum SubmitDispatchResult {
  NotSubmittable
  Prevented
  Handled
  Navigate(String)
}

///|
priv enum FocusedKeyDispatchResult {
  NotHandled
  Handled
  Activate
  Submit
}

///|
priv struct HitTarget {
  source_id : String
  area : Double
}

///|
priv struct KittyPlacement {
  image_id : Int
  placement_id : Int
  col : Int
  row : Int
  width : Int
  height : Int
}

///|
priv struct KittyRenderSpec {
  region : @tui.ImageRegion
  cached_data : String
  placement : KittyPlacement
}

///|
/// Browser output mode
pub(all) enum OutputMode {
  Sixel
  Kitty
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
  /// Paint-order hit regions for generic click hit testing
  mut hit_regions : Array[@tui.HitRegion]
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
  /// Optional external JS runtime (e.g. V8 for native target)
  mut js_runtime_override : &@js.JsRuntime?
  /// Whether JavaScript execution is enabled (requires --enable-js flag)
  mut enable_js : Bool
  /// Element scroll states (keyed by element id)
  /// For elements with overflow: auto/scroll that have scrollable content
  element_scroll_states : Map[String, @dom.ScrollState]
  /// Currently focused scrollable element id (for keyboard scrolling)
  focused_scrollable : Ref[String?]
  /// Currently hovered source element id
  mut hovered_source_id : String?
  /// Source currently pressed by pointer
  mut pressed_source_id : String?
  /// Text-control selection anchor source id during pointer drag
  mut text_selection_anchor_source_id : String?
  /// Text-control selection anchor column during pointer drag
  mut text_selection_anchor_col : Int
  /// Text-control selection anchor row during pointer drag
  mut text_selection_anchor_row : Int
  /// Source currently in drag session
  mut dragging_source_id : String?
  /// Current drag-over target
  mut drag_over_source_id : String?
  /// Current drop-allowed target (set by canceled dragover)
  mut drop_allowed_source_id : String?
  /// No-color mode (disable ANSI color codes)
  mut no_color : Bool
  /// Terminal columns (for pixel-to-column scaling)
  terminal_cols : Int
  /// Image regions from last render (for kitty/sixel overlay)
  mut image_regions : Array[@tui.ImageRegion]
  /// Cached rendered image data (src URL -> kitty graphics commands)
  image_cache : Map[String, String]
  /// Image cache insertion order for oldest-first eviction
  image_cache_order : Array[String]
  /// Total cached image payload size in bytes (approximated by String length)
  mut image_cache_total_bytes : Int
  /// Max cached image payload size before eviction
  mut image_cache_max_bytes : Int
  /// Uploaded kitty image ids that can be re-placed without re-sending payloads
  kitty_uploaded_image_ids : Map[Int, Bool]
  /// Visible kitty placements from the previous text render
  mut kitty_visible_placements : Map[String, KittyPlacement]
  /// HTTP cache for static assets (CSS, images, scripts, fonts)
  http_cache : @http.MemoryCacheBackend
}

///|
/// Create a new browser instance
pub fn Browser::new(
  width : Int,
  height : Int,
  terminal_cols? : Int = 80,
) -> Browser {
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
    hit_regions: [],
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
    js_runtime_override: None,
    enable_js: false, // Disabled by default for security
    element_scroll_states: {},
    focused_scrollable: Ref::new(None),
    hovered_source_id: None,
    pressed_source_id: None,
    text_selection_anchor_source_id: None,
    text_selection_anchor_col: 0,
    text_selection_anchor_row: 0,
    dragging_source_id: None,
    drag_over_source_id: None,
    drop_allowed_source_id: None,
    no_color: false,
    terminal_cols,
    image_regions: [],
    image_cache: {},
    image_cache_order: [],
    image_cache_total_bytes: 0,
    image_cache_max_bytes: default_image_cache_max_bytes,
    kitty_uploaded_image_ids: {},
    kitty_visible_placements: {},
    http_cache: @http.MemoryCacheBackend::new(max_entries=1000),
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
pub fn Browser::set_image_cache_max_bytes(
  self : Browser,
  max_bytes : Int,
) -> Unit {
  self.image_cache_max_bytes = max_bytes.max(0)
  self.evict_image_cache_if_needed()
}

///|
/// Set a custom JS runtime for script execution (e.g. V8 for native).
/// Must be called before any script execution (before navigate/load_html).
pub fn Browser::set_js_runtime(
  self : Browser,
  runtime : &@js.JsRuntime,
) -> Unit {
  self.js_runtime_override = Some(runtime)
  self.enable_js = true
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
pub fn Browser::get_dom_tree(self : Browser) -> @dom.DomTree? {
  self.dom_tree
}

///|
/// Set HTML content directly (for testing or headless rendering).
pub fn Browser::set_html_content(self : Browser, html : String) -> Unit {
  self.html_content = html
  self.parsed_doc = None
  self.dom_tree = None
  self.script_executor = None
}

///|
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
  if href.has_prefix("data:") ||
    href.has_prefix("about:") ||
    href.has_prefix("blob:") ||
    href.has_prefix("file:") {
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
  let after_protocol = base_url.unsafe_substring(
    start=protocol_end + 3,
    end=base_url.length(),
  )
  let path_start = after_protocol.find("/")
  let origin = match path_start {
    Some(i) => base_url.unsafe_substring(start=0, end=protocol_end + 3 + i)
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
      base_url.unsafe_substring(start=0, end=i + 1) + href
    _ => origin + "/" + href
  }
}

///|
/// Wrapper to adapt @http.fetch (which has optional params) to the
/// async fetcher signature expected by cached_fetch_async.
async fn http_fetch_adapter(
  url : String,
  options : @http.FetchOptions,
) -> @http.HttpResponse raise @http.HttpError {
  @http.fetch(url, options~)
}

///|
/// Fetch external stylesheets and return CSS array
async fn fetch_external_css(
  html : String,
  base_url : String,
  sandbox : @http.RequestSandbox,
  cache : @http.MemoryCacheBackend,
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
    // Try to fetch CSS with cache, ignore errors
    try {
      let options = {
        ..@http.FetchOptions::default(),
        mode: @http.RequestMode::NoCors,
        origin: base_url,
        sandbox,
      }
      let response = @http.cached_fetch_async(
        url=css_url,
        options~,
        cache=cache,
        fetcher=http_fetch_adapter,
      )
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
  let t0 = perf_now()
  // Fetch the page
  let page_options = {
    ..@http.FetchOptions::default(),
    mode: @http.RequestMode::Navigate,
    origin: url,
    sandbox: self.request_sandbox,
  }
  let response = @http.fetch(url, options=page_options)
  self.html_content = response.body
  let t1 = perf_now()
  // Fetch external CSS using lightweight extraction (no full parsing)
  self.external_css = fetch_external_css(
    self.html_content,
    url,
    self.request_sandbox,
    self.http_cache,
  ) catch {
    _ => [] // Fallback to no external CSS on error
  }
  let t2 = perf_now()
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
  let t3 = perf_now()
  // Execute scripts including external (JS execution)
  let script_count = self.execute_scripts_async() catch { _ => 0 }
  if script_count > 0 {
    println(
      "Executed " + script_count.to_string() + " script(s) during page load",
    )
  }
  let t4 = perf_now()
  // Content height is computed lazily from the layout tree in render_text()
  // to avoid a duplicate full layout pass here.
  self.content_height = 0
  // Accessibility tree is built lazily on first focus navigation
  // to avoid a duplicate full layout pass here.
  self.a11y_tree = None
  self.focus_manager = None
  // Prefetch images for kitty graphics rendering
  self.prefetch_images() catch {
    _ => ()
  }
  let t5 = perf_now()
  perf_log(
    "[perf] fetch=\{(t1 - t0).to_int()}ms css=\{(t2 - t1).to_int()}ms parse=\{(t3 - t2).to_int()}ms scripts=\{(t4 - t3).to_int()}ms images=\{(t5 - t4).to_int()}ms total=\{(t5 - t0).to_int()}ms",
  )
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
    Kitty => self.render_kitty()
    Text => self.render_text()
    Json => self.render_json()
    Aom => self.render_aom()
    Arc90 => self.render_arc90()
    ExtractMain => self.render_extract_main()
    Grounding => self.render_grounding()
  }
}

///|
fn Browser::flush_js_logs(self : Browser) -> Unit {
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

///|
pub async fn[T : @io.Writer] Browser::write_output(
  self : Browser,
  mode : OutputMode,
  writer : T,
) -> Unit {
  match mode {
    Kitty => self.write_kitty_output(writer)
    _ => writer.write(self.render_output(mode)) catch { _ => () }
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
/// Render current content to Kitty graphics protocol
fn Browser::render_kitty(self : Browser) -> String {
  if self.html_content.length() == 0 {
    return ""
  }
  @renderer.render_to_kitty_with_css(
    self.html_content,
    self.viewport_width,
    self.viewport_height,
    self.scroll_y,
    self.external_css,
  )
}

///|
async fn[T : @io.Writer] Browser::write_kitty_output(
  self : Browser,
  writer : T,
) -> Unit {
  if self.html_content.length() == 0 {
    return
  }
  @renderer.write_kitty_with_css(
    writer,
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
  let rt0 = perf_now()
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
      let rn0 = perf_now()
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
      let rn1 = perf_now()
      let tree = @layout.LayoutTree::from_node(
        n,
        self.viewport_width.to_double(),
        self.viewport_height.to_double(),
      )
      let rn2 = perf_now()
      perf_log(
        "[perf:build] css_cascade+node=\{(rn1 - rn0).to_int()}ms layout_tree_init=\{(rn2 - rn1).to_int()}ms",
      )
      self.render_node = Some(n)
      self.layout_tree = Some(tree)
      n
    }
  }
  let rt1 = perf_now()
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
  let rt2 = perf_now()
  // Update content_height from layout result (avoids duplicate layout pass)
  if self.content_height == 0 {
    self.content_height = @tui.get_content_extent(layout).to_int()
  }
  // Convert pixel dimensions to character dimensions
  // Buffer width = viewport / 8 (wider than terminal for proper CSS layout)
  // Output is clipped to terminal_cols at ANSI rendering stage
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
  let rt3 = perf_now()
  // Store link regions for click hit testing
  self.link_regions = buffer_result.link_regions
  self.hit_regions = buffer_result.hit_regions
  self.image_regions = buffer_result.image_regions
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
  // Clip output to terminal_cols (buffer may be wider than terminal)
  let max_cols = self.terminal_cols
  let ansi = match self.prev_buffer {
    Some(prev) =>
      if force_full {
        if self.no_color {
          @tui.clear_screen() +
          @tui.buffer_to_plain_with_links(buffer_result.buffer, plain_links)
        } else {
          @tui.clear_screen() +
          @tui.buffer_to_ansi(buffer_result.buffer, max_cols~)
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
        @tui.buffer_diff_to_ansi_rects(
          buffer_result.buffer,
          prev,
          dirty_cells,
          max_cols~,
        )
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
        @tui.clear_screen() +
        @tui.buffer_to_ansi(buffer_result.buffer, max_cols~)
      }
  }
  // Append kitty graphics commands for image regions
  let kitty_overlay = self.build_kitty_image_overlay()
  let final_output = if kitty_overlay.length() > 0 {
    ansi + kitty_overlay
  } else {
    ansi
  }
  let rt4 = perf_now()
  self.prev_buffer = Some(buffer_result.buffer)
  self.last_render_key = render_key
  self.last_color_scheme_dark = self.dark_mode
  perf_log(
    "[perf:render] node+layout_build=\{(rt1 - rt0).to_int()}ms layout_compute=\{(rt2 - rt1).to_int()}ms tui_buffer=\{(rt3 - rt2).to_int()}ms ansi=\{(rt4 - rt3).to_int()}ms total=\{(rt4 - rt0).to_int()}ms",
  )
  final_output
}

///|
fn stable_kitty_id(seed : String) -> Int {
  let mut hash = 5381
  let modulus = 16777213
  for c in seed {
    hash = (hash * 131 + c.to_int()) % modulus
  }
  (hash + 1).max(1)
}

///|
fn kitty_image_id_for_src(src : String) -> Int {
  stable_kitty_id("image:" + src)
}

///|
fn kitty_placement_id_for_source(source_id : String) -> Int {
  stable_kitty_id("placement:" + source_id)
}

///|
fn current_kitty_placement(region : @tui.ImageRegion) -> KittyPlacement {
  let image_id = kitty_image_id_for_src(region.src)
  let placement_id = kitty_placement_id_for_source(region.source_id)
  {
    image_id,
    placement_id,
    col: region.col,
    row: region.row,
    width: region.width,
    height: region.height,
  }
}

///|
fn same_kitty_placement(lhs : KittyPlacement, rhs : KittyPlacement) -> Bool {
  lhs.image_id == rhs.image_id &&
  lhs.placement_id == rhs.placement_id &&
  lhs.col == rhs.col &&
  lhs.row == rhs.row &&
  lhs.width == rhs.width &&
  lhs.height == rhs.height
}

///|
/// Build kitty graphics overlay commands for image regions
fn Browser::build_kitty_image_overlay(self : Browser) -> String {
  let next_visible : Map[String, KittyPlacement] = {}
  let render_specs : Array[KittyRenderSpec] = []
  for region in self.image_regions {
    match self.image_cache.get(region.src) {
      Some(cached_data) => {
        let placement = current_kitty_placement(region)
        next_visible.set(region.source_id, placement)
        render_specs.push({ region, cached_data, placement })
      }
      None => ()
    }
  }
  if next_visible.is_empty() && self.kitty_visible_placements.is_empty() {
    return ""
  }
  let buf = StringBuilder::new()
  for source_id, previous in self.kitty_visible_placements {
    match next_visible.get(source_id) {
      Some(current) if current.image_id == previous.image_id => ()
      _ =>
        buf.write_string(
          write_kitty_delete_placement(previous.image_id, previous.placement_id),
        )
    }
  }
  for spec in render_specs {
    let placement_key = spec.region.source_id
    let uploaded = self.kitty_uploaded_image_ids.contains(
      spec.placement.image_id,
    )
    let previous = self.kitty_visible_placements.get(placement_key)
    let unchanged = match previous {
      Some(prev) => same_kitty_placement(prev, spec.placement)
      None => false
    }
    if uploaded && unchanged {
      continue
    }
    buf.write_string(
      "\u001b[" +
      (spec.region.row + 1).to_string() +
      ";" +
      (spec.region.col + 1).to_string() +
      "H",
    )
    let kitty_data = if uploaded {
      write_kitty_put_placement(
        spec.placement.image_id,
        spec.placement.placement_id,
        spec.placement.width,
        spec.placement.height,
      )
    } else {
      render_cached_kitty_image_with_placement(
        spec.cached_data,
        spec.region,
        spec.placement.image_id,
        spec.placement.placement_id,
      )
    }
    if kitty_data.length() > 0 {
      buf.write_string(kitty_data)
      self.kitty_uploaded_image_ids.set(spec.placement.image_id, true)
    }
  }
  self.kitty_visible_placements = next_visible
  buf.to_string()
}

///|
fn remove_image_cache_order_key(order : Array[String], src : String) -> Unit {
  let mut found_idx : Int? = None
  for i, key in order {
    if key == src {
      found_idx = Some(i)
      break
    }
  }
  match found_idx {
    Some(idx) => {
      let _ = order.remove(idx)
    }
    None => ()
  }
}

///|
fn Browser::evict_image_cache_if_needed(self : Browser) -> Unit {
  while self.image_cache_total_bytes > self.image_cache_max_bytes &&
        not(self.image_cache_order.is_empty()) {
    let evicted_src = self.image_cache_order.remove(0)
    match self.image_cache.get(evicted_src) {
      Some(cached_data) => {
        self.image_cache.remove(evicted_src)
        self.image_cache_total_bytes = (self.image_cache_total_bytes -
        cached_data.length()).max(0)
      }
      None => ()
    }
  }
}

///|
fn Browser::cache_image_data(
  self : Browser,
  src : String,
  data : String,
) -> Unit {
  if self.image_cache.contains(src) {
    match self.image_cache.get(src) {
      Some(existing) =>
        self.image_cache_total_bytes = (self.image_cache_total_bytes -
        existing.length()).max(0)
      None => ()
    }
    self.image_cache.remove(src)
    remove_image_cache_order_key(self.image_cache_order, src)
  }
  self.image_cache.set(src, data)
  self.image_cache_order.push(src)
  self.image_cache_total_bytes += data.length()
  self.evict_image_cache_if_needed()
}

///|
/// Prefetch images from HTML and cache rendered kitty graphics data
async fn Browser::prefetch_images(self : Browser) -> Unit {
  if self.html_content.length() == 0 {
    return
  }
  let srcs = extract_img_srcs(self.html_content)
  for src in srcs {
    if src.has_prefix("data:") || self.image_cache.contains(src) {
      continue
    }
    let abs_url = resolve_url(self.current_url, src)
    if abs_url.length() == 0 {
      continue
    }
    let body = try {
      let options = {
        ..@http.FetchOptions::default(),
        sandbox: self.request_sandbox,
      }
      let response = @http.cached_fetch_async(
        url=abs_url,
        options~,
        cache=self.http_cache,
        fetcher=http_fetch_adapter,
      )
      response.body
    } catch {
      _ => continue
    }
    if body.length() == 0 {
      continue
    }
    let is_svg = abs_url.to_lower().has_suffix(".svg") ||
      abs_url.to_lower().contains(".svg?")
    if is_svg {
      self.cache_image_data(src, "svg:" + body)
    } else if body.has_prefix("base64:") {
      let b64 = body.unsafe_substring(start=7, end=body.length())
      self.cache_image_data(src, prepare_raster_image_for_kitty_cache(b64))
    }
  }
}

///|
/// Extract img src attributes from HTML (lightweight, no full parsing)
fn extract_img_srcs(html : String) -> Array[String] {
  let srcs : Array[String] = []
  let chars = html.to_array()
  let len = chars.length()
  for i = 0; i < len - 10; i = i + 1 {
    // Look for <img
    if chars[i] == '<' &&
      (chars[i + 1] == 'i' || chars[i + 1] == 'I') &&
      (chars[i + 2] == 'm' || chars[i + 2] == 'M') &&
      (chars[i + 3] == 'g' || chars[i + 3] == 'G') &&
      (chars[i + 4] == ' ' || chars[i + 4] == '\t') {
      // Find src="..." within this tag
      for j = i + 4; j < len - 5; j = j + 1 {
        if chars[j] == '>' {
          break
        }
        if chars[j] == 's' &&
          chars[j + 1] == 'r' &&
          chars[j + 2] == 'c' &&
          chars[j + 3] == '=' {
          let quote = chars[j + 4]
          if quote == '"' || quote == '\'' {
            let start = j + 5
            for k = start; k < len; k = k + 1 {
              if chars[k] == quote {
                let buf = StringBuilder::new()
                for ci = start; ci < k; ci = ci + 1 {
                  buf.write_char(chars[ci])
                }
                srcs.push(buf.to_string())
                break
              }
            }
          }
          break
        }
      }
    }
  }
  srcs
}

///|
/// Render SVG to kitty graphics with cell-size display parameters (c=cols, r=rows)
fn render_svg_to_kitty_with_cells(
  svg_text : String,
  render_width : Int,
  render_height : Int,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  let svg_node = match @svg.parse_svg(svg_text) {
    Some(n) => n
    None => return ""
  }
  let scene = @svg.Scene::new(svg_node)
  let fb = @image.Framebuffer::new(render_width, render_height)
  let palette = @image.DynamicPalette::new()
  fb.fill_rect(0, 0, render_width, render_height, 0)
  let viewbox = extract_svg_viewbox(svg_text)
  let (vx, vy, vw, vh) = match viewbox {
    Some(v) => v
    None => {
      let bounds = scene.get_bounds()
      (0.0, 0.0, bounds.width(), bounds.height())
    }
  }
  if vw <= 0.0 || vh <= 0.0 {
    return ""
  }
  let camera = @svg.Camera::new(render_width, render_height)
  camera.set_position(vx + vw / 2.0, vy + vh / 2.0)
  let zoom = (render_width.to_double() / vw).min(render_height.to_double() / vh)
  camera.set_zoom(zoom)
  @image.render_svg_scene_with_camera(scene, fb, palette, camera)
  to_kitty_with_cells(
    fb,
    palette,
    display_cols,
    display_rows,
    image_id~,
    placement_id~,
  )
}

///|
/// Encode framebuffer to kitty graphics with c (columns) and r (rows) display size
fn to_kitty_with_cells(
  fb : @image.Framebuffer,
  palette : @image.DynamicPalette,
  cols : Int,
  rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  let buf = StringBuilder::new()
  let mut chunk = StringBuilder::new()
  let mut chunk_len = 0
  let mut first_chunk = true
  let pixel_count = fb.width * fb.height
  let chunk_size = 4096
  for pixel_index in 0..<pixel_count {
    if chunk_len + 4 > chunk_size {
      // Write chunk header
      if first_chunk {
        buf.write_string("\u001b_Ga=T,f=24,q=2,c=")
        buf.write_string(cols.to_string())
        buf.write_string(",r=")
        buf.write_string(rows.to_string())
        if image_id > 0 {
          buf.write_string(",i=")
          buf.write_string(image_id.to_string())
          if placement_id > 0 {
            buf.write_string(",p=")
            buf.write_string(placement_id.to_string())
          }
        }
        buf.write_string(",s=")
        buf.write_string(fb.width.to_string())
        buf.write_string(",v=")
        buf.write_string(fb.height.to_string())
        buf.write_string(",m=1;")
      } else {
        buf.write_string("\u001b_Gm=1;")
      }
      buf.write_string(chunk.to_string())
      buf.write_string("\u001b\\")
      chunk = StringBuilder::new()
      chunk_len = 0
      first_chunk = false
    }
    let color_idx = fb.pixels[pixel_index]
    let color = if color_idx >= 0 && color_idx < palette.colors.length() {
      palette.colors[color_idx]
    } else {
      @image.Color::white()
    }
    // Base64 encode RGB triplet
    let b0 = color.r
    let b1 = color.g
    let b2 = color.b
    let base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let c0 = (b0 >> 2) & 0x3F
    let c1 = ((b0 << 4) | (b1 >> 4)) & 0x3F
    let c2 = ((b1 << 2) | (b2 >> 6)) & 0x3F
    let c3 = b2 & 0x3F
    chunk.write_char(base64_chars[c0].unsafe_to_char())
    chunk.write_char(base64_chars[c1].unsafe_to_char())
    chunk.write_char(base64_chars[c2].unsafe_to_char())
    chunk.write_char(base64_chars[c3].unsafe_to_char())
    chunk_len = chunk_len + 4
  }
  // Final chunk
  if chunk_len > 0 {
    if first_chunk {
      buf.write_string("\u001b_Ga=T,f=24,q=2,c=")
      buf.write_string(cols.to_string())
      buf.write_string(",r=")
      buf.write_string(rows.to_string())
      if image_id > 0 {
        buf.write_string(",i=")
        buf.write_string(image_id.to_string())
        if placement_id > 0 {
          buf.write_string(",p=")
          buf.write_string(placement_id.to_string())
        }
      }
      buf.write_string(",s=")
      buf.write_string(fb.width.to_string())
      buf.write_string(",v=")
      buf.write_string(fb.height.to_string())
      buf.write_string(",m=0;")
    } else {
      buf.write_string("\u001b_Gm=0;")
    }
    buf.write_string(chunk.to_string())
    buf.write_string("\u001b\\")
  }
  buf.to_string()
}

///|
fn detect_raster_image_format_from_base64(b64_data : String) -> String {
  if b64_data.has_prefix("iVBORw0KGgo") {
    "png"
  } else if b64_data.has_prefix("/9j/") {
    "jpeg"
  } else if b64_data.has_prefix("R0lGOD") {
    "gif"
  } else {
    "unknown"
  }
}

///|
#cfg(target="js")
extern "js" fn js_decode_raster_image_to_rgba_base64(
  image_format : String,
  b64_data : String,
) -> String =
  #| (imageFormat, b64Data) => {
  #|   try {
  #|     if (typeof process === 'undefined' || process.platform !== 'darwin') {
  #|       return '';
  #|     }
  #|     const format = String(imageFormat || '').toLowerCase();
  #|     if (format !== 'jpeg' && format !== 'gif') {
  #|       return '';
  #|     }
  #|     const fs = require('node:fs');
  #|     const os = require('node:os');
  #|     const path = require('node:path');
  #|     const { execFileSync } = require('node:child_process');
  #|     const { PNG } = require('pngjs');
  #|     const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'crater-kitty-'));
  #|     const inputExt = format === 'jpeg' ? 'jpg' : 'gif';
  #|     const inputPath = path.join(dir, 'input.' + inputExt);
  #|     const outputPath = path.join(dir, 'output.png');
  #|     try {
  #|       fs.writeFileSync(inputPath, Buffer.from(String(b64Data || ''), 'base64'));
  #|       execFileSync(
  #|         'sips',
  #|         ['-s', 'format', 'png', inputPath, '--out', outputPath],
  #|         { stdio: 'pipe' },
  #|       );
  #|       const pngBuffer = fs.readFileSync(outputPath);
  #|       const decoded = PNG.sync.read(pngBuffer);
  #|       return (
  #|         String(decoded.width) +
  #|         ':' +
  #|         String(decoded.height) +
  #|         ':' +
  #|         Buffer.from(decoded.data).toString('base64')
  #|       );
  #|     } finally {
  #|       try {
  #|         fs.rmSync(dir, { recursive: true, force: true });
  #|       } catch (_) {}
  #|     }
  #|   } catch (_) {
  #|     return '';
  #|   }
  #| }

///|
#cfg(target="js")
fn decode_raster_image_to_rgba_base64(
  image_format : String,
  b64_data : String,
) -> String? {
  let decoded = js_decode_raster_image_to_rgba_base64(image_format, b64_data)
  if decoded.length() > 0 {
    Some(decoded)
  } else {
    None
  }
}

///|
#cfg(target="native")
fn decode_raster_image_to_rgba_base64(
  _image_format : String,
  _b64_data : String,
) -> String? {
  None
}

///|
#cfg(target="js")
extern "js" fn js_transcode_raster_image_to_png_base64(
  image_format : String,
  b64_data : String,
) -> String =
  #| (imageFormat, b64Data) => {
  #|   try {
  #|     if (typeof process === 'undefined' || process.platform !== 'darwin') {
  #|       return '';
  #|     }
  #|     const format = String(imageFormat || '').toLowerCase();
  #|     if (format !== 'jpeg' && format !== 'gif') {
  #|       return '';
  #|     }
  #|     const fs = require('node:fs');
  #|     const os = require('node:os');
  #|     const path = require('node:path');
  #|     const { execFileSync } = require('node:child_process');
  #|     const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'crater-kitty-'));
  #|     const inputExt = format === 'jpeg' ? 'jpg' : 'gif';
  #|     const inputPath = path.join(dir, 'input.' + inputExt);
  #|     const outputPath = path.join(dir, 'output.png');
  #|     try {
  #|       fs.writeFileSync(inputPath, Buffer.from(String(b64Data || ''), 'base64'));
  #|       execFileSync(
  #|         'sips',
  #|         ['-s', 'format', 'png', inputPath, '--out', outputPath],
  #|         { stdio: 'pipe' },
  #|       );
  #|       return fs.readFileSync(outputPath).toString('base64');
  #|     } finally {
  #|       try {
  #|         fs.rmSync(dir, { recursive: true, force: true });
  #|       } catch (_) {}
  #|     }
  #|   } catch (_) {
  #|     return '';
  #|   }
  #| }

///|
#cfg(target="js")
fn transcode_raster_image_to_png_base64(
  image_format : String,
  b64_data : String,
) -> String? {
  let transcoded = js_transcode_raster_image_to_png_base64(
    image_format, b64_data,
  )
  if transcoded.length() > 0 {
    Some(transcoded)
  } else {
    None
  }
}

///|
#cfg(target="native")
fn transcode_raster_image_to_png_base64(
  _image_format : String,
  _b64_data : String,
) -> String? {
  None
}

///|
fn normalize_raster_image_for_kitty(b64_data : String) -> String {
  let image_format = detect_raster_image_format_from_base64(b64_data)
  if image_format == "png" {
    return b64_data
  }
  match transcode_raster_image_to_png_base64(image_format, b64_data) {
    Some(transcoded) => transcoded
    None => b64_data
  }
}

///|
fn parse_int_ascii(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
  }
  result
}

///|
fn parse_kitty_rgba_cache_entry(entry : String) -> (Int, Int, String)? {
  match entry.find(":") {
    Some(width_end) => {
      let width_str = entry.unsafe_substring(start=0, end=width_end)
      let rest = entry.unsafe_substring(start=width_end + 1, end=entry.length())
      match rest.find(":") {
        Some(height_end) => {
          let height_str = rest.unsafe_substring(start=0, end=height_end)
          let rgba_b64 = rest.unsafe_substring(
            start=height_end + 1,
            end=rest.length(),
          )
          let width = parse_int_ascii(width_str)
          let height = parse_int_ascii(height_str)
          if width > 0 && height > 0 && rgba_b64.length() > 0 {
            Some((width, height, rgba_b64))
          } else {
            None
          }
        }
        None => None
      }
    }
    None => None
  }
}

///|
fn prepare_raster_image_for_kitty_cache(b64_data : String) -> String {
  let image_format = detect_raster_image_format_from_base64(b64_data)
  if image_format == "png" {
    return "img_png:" + b64_data
  }
  match decode_raster_image_to_rgba_base64(image_format, b64_data) {
    Some(decoded) => "img_rgba:" + decoded
    None => {
      let normalized = normalize_raster_image_for_kitty(b64_data)
      if detect_raster_image_format_from_base64(normalized) == "png" {
        "img_png:" + normalized
      } else {
        "img:" + b64_data
      }
    }
  }
}

///|
fn write_kitty_direct_image_data(
  b64_data : String,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  if b64_data.length() == 0 {
    return ""
  }
  let buf = StringBuilder::new()
  let chunk_size = 4096
  let total_len = b64_data.length()
  let b64_chars = b64_data.to_array()
  for offset = 0; offset < total_len; offset = offset + chunk_size {
    let end = (offset + chunk_size).min(total_len)
    let is_first = offset == 0
    let is_last = end >= total_len
    let m_val = if is_last { 0 } else { 1 }
    if is_first {
      buf.write_string("\u001b_Ga=T,f=100,q=2,c=")
      buf.write_string(display_cols.to_string())
      buf.write_string(",r=")
      buf.write_string(display_rows.to_string())
      if image_id > 0 {
        buf.write_string(",i=")
        buf.write_string(image_id.to_string())
        if placement_id > 0 {
          buf.write_string(",p=")
          buf.write_string(placement_id.to_string())
        }
      }
      buf.write_string(",m=")
      buf.write_string(m_val.to_string())
      buf.write_string(";")
    } else {
      buf.write_string("\u001b_Gm=")
      buf.write_string(m_val.to_string())
      buf.write_string(";")
    }
    for i = offset; i < end; i = i + 1 {
      buf.write_char(b64_chars[i])
    }
    buf.write_string("\u001b\\")
  }
  buf.to_string()
}

///|
fn write_kitty_rgba_image_data(
  b64_data : String,
  pixel_width : Int,
  pixel_height : Int,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  if b64_data.length() == 0 || pixel_width <= 0 || pixel_height <= 0 {
    return ""
  }
  let buf = StringBuilder::new()
  let chunk_size = 4096
  let total_len = b64_data.length()
  let b64_chars = b64_data.to_array()
  for offset = 0; offset < total_len; offset = offset + chunk_size {
    let end = (offset + chunk_size).min(total_len)
    let is_first = offset == 0
    let is_last = end >= total_len
    let m_val = if is_last { 0 } else { 1 }
    if is_first {
      buf.write_string("\u001b_Ga=T,f=32,q=2,c=")
      buf.write_string(display_cols.to_string())
      buf.write_string(",r=")
      buf.write_string(display_rows.to_string())
      if image_id > 0 {
        buf.write_string(",i=")
        buf.write_string(image_id.to_string())
        if placement_id > 0 {
          buf.write_string(",p=")
          buf.write_string(placement_id.to_string())
        }
      }
      buf.write_string(",s=")
      buf.write_string(pixel_width.to_string())
      buf.write_string(",v=")
      buf.write_string(pixel_height.to_string())
      buf.write_string(",m=")
      buf.write_string(m_val.to_string())
      buf.write_string(";")
    } else {
      buf.write_string("\u001b_Gm=")
      buf.write_string(m_val.to_string())
      buf.write_string(";")
    }
    for i = offset; i < end; i = i + 1 {
      buf.write_char(b64_chars[i])
    }
    buf.write_string("\u001b\\")
  }
  buf.to_string()
}

///|
fn write_kitty_put_placement(
  image_id : Int,
  placement_id : Int,
  display_cols : Int,
  display_rows : Int,
) -> String {
  if image_id <= 0 || placement_id <= 0 {
    return ""
  }
  "\u001b_Ga=p,q=2,i=" +
  image_id.to_string() +
  ",p=" +
  placement_id.to_string() +
  ",c=" +
  display_cols.to_string() +
  ",r=" +
  display_rows.to_string() +
  ";\u001b\\"
}

///|
fn write_kitty_delete_placement(image_id : Int, placement_id : Int) -> String {
  if image_id <= 0 || placement_id <= 0 {
    return ""
  }
  "\u001b_Ga=d,q=2,d=i,i=" +
  image_id.to_string() +
  ",p=" +
  placement_id.to_string() +
  ";\u001b\\"
}

///|
fn render_cached_kitty_image_with_placement(
  cached_data : String,
  region : @tui.ImageRegion,
  image_id : Int,
  placement_id : Int,
) -> String {
  if cached_data.has_prefix("svg:") {
    let svg_text = cached_data.unsafe_substring(
      start=4,
      end=cached_data.length(),
    )
    let render_w = region.width * 16
    let render_h = region.height * 32
    render_svg_to_kitty_with_cells(
      svg_text,
      render_w,
      render_h,
      region.width,
      region.height,
      image_id~,
      placement_id~,
    )
  } else if cached_data.has_prefix("img_png:") {
    let b64_data = cached_data.unsafe_substring(
      start=8,
      end=cached_data.length(),
    )
    write_kitty_direct_image_data(
      b64_data,
      region.width,
      region.height,
      image_id~,
      placement_id~,
    )
  } else if cached_data.has_prefix("img_rgba:") {
    let rgba_entry = cached_data.unsafe_substring(
      start=9,
      end=cached_data.length(),
    )
    match parse_kitty_rgba_cache_entry(rgba_entry) {
      Some((pixel_width, pixel_height, rgba_b64)) =>
        render_rgba_raster_to_kitty_with_cells(
          pixel_width,
          pixel_height,
          rgba_b64,
          region.width,
          region.height,
          image_id~,
          placement_id~,
        )
      None => ""
    }
  } else if cached_data.has_prefix("img:") {
    let b64_data = cached_data.unsafe_substring(
      start=4,
      end=cached_data.length(),
    )
    write_kitty_direct_image_data(
      normalize_raster_image_for_kitty(b64_data),
      region.width,
      region.height,
      image_id~,
      placement_id~,
    )
  } else {
    ""
  }
}

///|
fn render_rgba_raster_to_kitty_with_cells(
  pixel_width : Int,
  pixel_height : Int,
  rgba_b64_data : String,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  write_kitty_rgba_image_data(
    rgba_b64_data,
    pixel_width,
    pixel_height,
    display_cols,
    display_rows,
    image_id~,
    placement_id~,
  )
}

///|
/// Build a String from a slice of a Char array
fn chars_to_string(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
/// Extract viewBox from SVG root element
fn extract_svg_viewbox(svg_text : String) -> (Double, Double, Double, Double)? {
  let search = "viewBox=\""
  let chars = svg_text.to_array()
  let search_chars = search.to_array()
  let len = chars.length()
  let slen = search_chars.length()
  for i = 0; i < len - slen; i = i + 1 {
    let mut found = true
    for j = 0; j < slen; j = j + 1 {
      if chars[i + j] != search_chars[j] {
        found = false
        break
      }
    }
    if found {
      let start = i + slen
      let mut end = start
      while end < len && chars[end] != '"' {
        end = end + 1
      }
      let vb_str = chars_to_string(chars, start, end)
      // Parse "minX minY width height"
      let parts = split_whitespace(vb_str)
      if parts.length() == 4 {
        let vx = parse_double(parts[0])
        let vy = parse_double(parts[1])
        let vw = parse_double(parts[2])
        let vh = parse_double(parts[3])
        return Some((vx, vy, vw, vh))
      }
    }
  }
  None
}

///|
fn split_whitespace(s : String) -> Array[String] {
  let result : Array[String] = []
  let chars = s.to_array()
  let len = chars.length()
  let mut start = 0
  let mut in_word = false
  for i = 0; i < len; i = i + 1 {
    if chars[i] == ' ' || chars[i] == '\t' || chars[i] == '\n' {
      if in_word {
        result.push(chars_to_string(chars, start, i))
        in_word = false
      }
    } else if not(in_word) {
      start = i
      in_word = true
    }
  }
  if in_word {
    result.push(chars_to_string(chars, start, len))
  }
  result
}

///|
fn parse_double(s : String) -> Double {
  // Simple double parser for SVG attributes
  let chars = s.to_array()
  let len = chars.length()
  let mut result = 0.0
  let mut frac = 0.0
  let mut frac_div = 1.0
  let mut in_frac = false
  let mut negative = false
  let mut start = 0
  if len > 0 && chars[0] == '-' {
    negative = true
    start = 1
  }
  for i = start; i < len; i = i + 1 {
    if chars[i] == '.' {
      in_frac = true
    } else if chars[i] >= '0' && chars[i] <= '9' {
      let digit = (chars[i].to_int() - '0'.to_int()).to_double()
      if in_frac {
        frac_div = frac_div * 10.0
        frac = frac + digit / frac_div
      } else {
        result = result * 10.0 + digit
      }
    }
  }
  result = result + frac
  if negative {
    -result
  } else {
    result
  }
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
fn Browser::is_bounds_visible(self : Browser, bounds : @aom.Bounds?) -> Bool {
  match bounds {
    Some(b) => {
      let view_left = 0.0
      let view_right = self.viewport_width.to_double()
      let view_top = self.scroll_y.to_double()
      let view_bottom = view_top + self.viewport_height.to_double()
      b.x + b.width > view_left &&
      b.x < view_right &&
      b.y + b.height > view_top &&
      b.y < view_bottom
    }
    None => false
  }
}

///|
fn Browser::is_focus_node_visible(
  self : Browser,
  node : @aom.AccessibilityNode,
) -> Bool {
  self.is_bounds_visible(node.bounds)
}

///|
/// Focus next visible focusable element (Tab)
pub fn Browser::next_link(self : Browser) -> Unit {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) => {
      let count = fm.focusable_count()
      if count == 0 {
        return
      }
      let previous_source_id = match fm.current() {
        Some(node) => node.source_id
        None => None
      }
      for attempt = 0; attempt < count; attempt = attempt + 1 {
        let _ = fm.focus_next()
        match fm.current() {
          Some(node) =>
            if self.is_focus_node_visible(node) {
              self.dispatch_focus_transition(previous_source_id, node.source_id)
              return
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
pub fn Browser::prev_link(self : Browser) -> Unit {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) => {
      let count = fm.focusable_count()
      if count == 0 {
        return
      }
      let previous_source_id = match fm.current() {
        Some(node) => node.source_id
        None => None
      }
      for attempt = 0; attempt < count; attempt = attempt + 1 {
        let _ = fm.focus_prev()
        match fm.current() {
          Some(node) =>
            if self.is_focus_node_visible(node) {
              self.dispatch_focus_transition(previous_source_id, node.source_id)
              return
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
  let previous_focus_source_id = match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) => node.source_id
        None => None
      }
    None => None
  }
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
  match (self.focus_manager, previous_focus_source_id) {
    (Some(fm), Some(source_id)) => {
      let _ = fm.focus_by_source_id(source_id)
    }
    _ => ()
  }
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
fn Browser::get_focused_source_id(self : Browser) -> String? {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) => node.source_id
        None =>
          match self.a11y_tree {
            Some(tree) => {
              let mut link_index = 0
              for node in tree.find_focusable() {
                if node.role == @aom.Link {
                  if link_index == self.focused_link {
                    return node.source_id
                  }
                  link_index = link_index + 1
                }
              }
              None
            }
            None => None
          }
      }
    None =>
      match self.a11y_tree {
        Some(tree) => {
          let mut link_index = 0
          for node in tree.find_focusable() {
            if node.role == @aom.Link {
              if link_index == self.focused_link {
                return node.source_id
              }
              link_index = link_index + 1
            }
          }
          None
        }
        None => None
      }
  }
}

///|
fn Browser::get_link_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  match @tui.find_link_region_at(self.link_regions, col, row) {
    Some(region) => Some(region.source_id)
    None => None
  }
}

///|
fn Browser::is_clickable_source_id(self : Browser, source_id : String) -> Bool {
  match self.get_href_for_source_id(source_id) {
    Some(href) if href.length() > 0 => true
    _ => {
      if not(self.enable_js) {
        return false
      }
      let escaped = escape_js_string(source_id)
      let source = "(function(){const target=document.getElementById('" +
        escaped +
        "');if(!target){return false;}if(target.hasAttribute&&(target.hasAttribute('onclick')||target.hasAttribute('data-crater-listeners-click'))){return true;}const tag=(target.tagName||'').toLowerCase();if(tag==='button'||tag==='input'||tag==='select'||tag==='textarea'||tag==='summary'){return true;}const role=target.getAttribute?target.getAttribute('role'):null;return role==='button'||role==='link';})()"
      match self.execute_inline_js(source) {
        Some("true") => true
        _ => false
      }
    }
  }
}

///|
fn Browser::get_paint_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  if self.hit_regions.is_empty() {
    return None
  }
  let mut i = self.hit_regions.length() - 1
  while i >= 0 {
    let region = self.hit_regions[i]
    if region.contains(col, row) &&
      self.is_clickable_source_id(region.source_id) {
      return Some(region.source_id)
    }
    i = i - 1
  }
  None
}

///|
fn Browser::get_any_paint_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  match @tui.find_hit_region_at(self.hit_regions, col, row) {
    Some(region) => Some(region.source_id)
    None => None
  }
}

///|
fn bounds_contains_click(
  bounds : @aom.Bounds,
  px_x : Double,
  px_y : Double,
) -> Bool {
  px_x >= bounds.x &&
  px_x < bounds.x + bounds.width &&
  px_y >= bounds.y &&
  px_y < bounds.y + bounds.height
}

///|
fn find_smallest_a11y_hit_target(
  node : @aom.AccessibilityNode,
  px_x : Double,
  px_y : Double,
  current_best : HitTarget?,
) -> HitTarget? {
  let mut best = current_best
  match (node.source_id, node.bounds) {
    (Some(source_id), Some(bounds)) =>
      if bounds.width > 0.0 &&
        bounds.height > 0.0 &&
        bounds_contains_click(bounds, px_x, px_y) {
        let area = bounds.width * bounds.height
        match best {
          Some(existing) =>
            if area < existing.area {
              best = Some({ source_id, area })
            }
          None => best = Some({ source_id, area })
        }
      }
    _ => ()
  }
  for child in node.children {
    best = find_smallest_a11y_hit_target(child, px_x, px_y, best)
  }
  best
}

///|
fn Browser::get_a11y_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  if row <= 0 {
    return None
  }
  if self.a11y_tree is None {
    self.build_accessibility_tree()
  }
  let px_x = col.to_double() * 8.0 + 4.0
  let px_y = (row - 1 + self.scroll_y).to_double() * 16.0 + 8.0
  match self.a11y_tree {
    Some(tree) =>
      match find_smallest_a11y_hit_target(tree.root, px_x, px_y, None) {
        Some(target) => Some(target.source_id)
        None => None
      }
    None => None
  }
}

///|
fn Browser::get_source_id_at(self : Browser, col : Int, row : Int) -> String? {
  match self.get_link_source_id_at(col, row) {
    Some(source_id) => Some(source_id)
    None =>
      match self.get_paint_source_id_at(col, row) {
        Some(source_id) => Some(source_id)
        None => self.get_a11y_source_id_at(col, row)
      }
  }
}

///|
fn Browser::get_hover_source_id_at(
  self : Browser,
  col : Int,
  row : Int,
) -> String? {
  match self.get_link_source_id_at(col, row) {
    Some(source_id) => Some(source_id)
    None =>
      match self.get_any_paint_source_id_at(col, row) {
        Some(source_id) => Some(source_id)
        None => self.get_a11y_source_id_at(col, row)
      }
  }
}

///|
fn Browser::focus_source_id(self : Browser, source_id : String) -> Unit {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) => {
      let previous_source_id = match fm.current() {
        Some(node) => node.source_id
        None => None
      }
      let _ = fm.focus_by_source_id(source_id)
      self.dispatch_focus_transition(previous_source_id, Some(source_id))
    }
    None => ()
  }
}

///|
fn Browser::dispatch_focus_transition(
  self : Browser,
  previous_source_id : String?,
  next_source_id : String?,
) -> Unit {
  if not(self.enable_js) {
    return
  }
  if previous_source_id == next_source_id {
    return
  }
  let previous_js = match previous_source_id {
    Some(id) => "'" + escape_js_string(id) + "'"
    None => "null"
  }
  let next_js = match next_source_id {
    Some(id) => "'" + escape_js_string(id) + "'"
    None => "null"
  }
  let source = "(function(){const prevId=" +
    previous_js +
    ";const nextId=" +
    next_js +
    ";const prev=prevId?document.getElementById(prevId):null;const next=nextId?document.getElementById(nextId):null;function isChangeOnBlurTarget(target){if(!target){return false;}const tag=(target.tagName||'').toLowerCase();const type=(target.getAttribute?((target.getAttribute('type')||'').toLowerCase()):'');if(tag==='textarea'){return true;}if(tag!=='input'){return false;}return type===''||type==='text'||type==='search'||type==='url'||type==='tel'||type==='email'||type==='password'||type==='number';}function currentValue(target){if(!target){return '';}if(target.value!==undefined&&target.value!==null){return String(target.value);}if(target.getAttribute){return String(target.getAttribute('value')||'');}return '';}function maybeDispatchChangeOnBlur(target){if(!isChangeOnBlurTarget(target)||!target.getAttribute||!target.setAttribute){return;}const base=target.getAttribute('data-crater-change-base');if(base===null){return;}const current=currentValue(target);if(current!==String(base)){target.dispatchEvent(new Event('change',{bubbles:true}));}target.setAttribute('data-crater-change-base',current);}function markFocusBase(target){if(!isChangeOnBlurTarget(target)||!target.setAttribute){return;}target.setAttribute('data-crater-change-base',currentValue(target));}if(prev&&prev!==next){maybeDispatchChangeOnBlur(prev);prev.dispatchEvent(new Event('blur'));prev.dispatchEvent(new Event('focusout',{bubbles:true}));}if(next&&prev!==next){markFocusBase(next);next.dispatchEvent(new Event('focus'));next.dispatchEvent(new Event('focusin',{bubbles:true}));}return 'ok';})()"
  let _ = self.execute_inline_js(source)
  let _ = self.sync_render_state_from_dom_tree()
}

///|
fn Browser::dispatch_activation_default_to_source_id(
  self : Browser,
  source_id : String,
) -> Bool {
  if not(self.enable_js) {
    return false
  }
  let escaped = escape_js_string(source_id)
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'false';}const tag=(target.tagName||'').toLowerCase();const type=(target.getAttribute?((target.getAttribute('type')||'').toLowerCase()):'');function resetForm(form){function resetNode(node){if(!node||!node.childNodes){return;}for(let i=0;i<node.childNodes.length;i++){const child=node.childNodes[i];if(!child||child.nodeType!==1){continue;}const childTag=(child.tagName||'').toLowerCase();if(childTag==='input'){const childType=((child.getAttribute('type')||'').toLowerCase());if(childType==='checkbox'||childType==='radio'){const defaultChecked=child.getAttribute&&child.getAttribute('data-crater-default-checked');child.checked=defaultChecked==='true'||(defaultChecked===null&&child.hasAttribute&&child.hasAttribute('checked'));if(child.checked){child.setAttribute('checked','');}else if(child.removeAttribute){child.removeAttribute('checked');}}else if(childType!=='submit'&&childType!=='button'&&childType!=='image'&&childType!=='reset'&&childType!=='file'){const defaultValue=(child.getAttribute&&child.getAttribute('data-crater-default-value'));child.value=String(defaultValue===null?((child.getAttribute&&child.getAttribute('value'))||''):defaultValue);if(child.setAttribute){child.setAttribute('value',child.value);}}}else if(childTag==='textarea'){const defaultValue=(child.getAttribute&&child.getAttribute('data-crater-default-value'));const resetValue=String(defaultValue===null?((child.textContent!==undefined&&child.textContent!==null)?child.textContent:''):defaultValue);child.value=resetValue;}else if(childTag==='select'&&child.options!==undefined){let selectedIndex=-1;for(let j=0;j<child.options.length;j++){const option=child.options[j];const defaultSelected=option.getAttribute&&option.getAttribute('data-crater-default-selected');const selected=defaultSelected==='true'||(defaultSelected===null&&option.hasAttribute&&option.hasAttribute('selected'));option.selected=selected;if(selected&&selectedIndex<0){selectedIndex=j;}}if(selectedIndex<0&&child.options.length>0){child.options[0].selected=true;selectedIndex=0;}child.selectedIndex=selectedIndex;}resetNode(child);}}resetNode(form);}if(tag==='summary'){const details=target.closest?target.closest('details'):null;if(!details||!details.setAttribute){return 'false';}if(details.hasAttribute('open')){details.removeAttribute('open');}else{details.setAttribute('open','');}return 'true';}if((tag==='button'&&type==='reset')||(tag==='input'&&type==='reset')){const form=target.closest?target.closest('form'):null;if(!form){return 'false';}const resetEvent=new Event('reset',{bubbles:true,cancelable:true});if(!form.dispatchEvent(resetEvent)){return 'true';}resetForm(form);return 'true';}return 'false';})()"
  match self.execute_inline_js(source) {
    Some("true") => {
      let _ = self.sync_render_state_from_dom_tree()
      true
    }
    _ => false
  }
}

///|
fn Browser::get_href_for_source_id(
  self : Browser,
  source_id : String,
) -> String? {
  let escaped = escape_js_string(source_id)
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target||typeof target.getAttribute!=='function'){return '';}const href=target.getAttribute('href');return typeof href==='string'?href:'';})()"
  match self.execute_inline_js(source) {
    Some(href) if href.length() > 0 => Some(href)
    _ => None
  }
}

///|
/// Get number of visible focusable elements currently on screen
fn Browser::get_visible_focusable_count(self : Browser) -> Int {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) => {
      let mut count = 0
      for item in fm.get_tab_order() {
        if self.is_focus_node_visible(item.node) {
          count += 1
        }
      }
      count
    }
    None => self.link_regions.length()
  }
}

///|
/// Get current focus index among visible focusable elements (-1 if not visible)
fn Browser::get_visible_focus_index(self : Browser) -> Int {
  if self.a11y_tree is None || self.focus_manager is None {
    self.build_accessibility_tree()
  }
  match self.focus_manager {
    Some(fm) =>
      match fm.current() {
        Some(node) => {
          let focused_source_id = node.source_id
          let mut visible_index = 0
          for item in fm.get_tab_order() {
            if self.is_focus_node_visible(item.node) {
              if item.node.source_id == focused_source_id {
                return visible_index
              }
              visible_index += 1
            }
          }
          -1
        }
        None => -1
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
fn escape_js_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '\\' => buf.write_string("\\\\")
      '\'' => buf.write_string("\\'")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn Browser::execute_inline_js(self : Browser, source : String) -> String? {
  if not(self.enable_js) {
    return None
  }
  if self.dom_tree is None {
    self.init_js_execution()
  }
  match self.script_executor {
    Some(executor) =>
      try {
        let result = executor.execute_source(source)
        self.flush_js_logs()
        Some(result.value)
      } catch {
        err => {
          println("[JS] Error: " + err.to_string())
          self.flush_js_logs()
          None
        }
      }
    None => None
  }
}

///|
fn cell_to_client_x(col : Int) -> Int {
  col * 8 + 4
}

///|
fn cell_to_client_y(row : Int) -> Int {
  let viewport_row = if row > 0 { row } else { 0 }
  viewport_row * 16 + 8
}

///|
fn Browser::get_client_coords_for_source_id(
  self : Browser,
  source_id : String,
) -> (Int, Int)? {
  if self.hit_regions.is_empty() {
    return None
  }
  let mut i = self.hit_regions.length() - 1
  while i >= 0 {
    let region = self.hit_regions[i]
    if region.source_id == source_id {
      let center_col = region.col + region.width / 2
      let center_row = region.row + region.height / 2
      return Some((cell_to_client_x(center_col), cell_to_client_y(center_row)))
    }
    i = i - 1
  }
  None
}

///|
fn Browser::get_hit_region_for_source_id(
  self : Browser,
  source_id : String,
) -> @tui.HitRegion? {
  if self.hit_regions.is_empty() {
    return None
  }
  let mut i = self.hit_regions.length() - 1
  while i >= 0 {
    let region = self.hit_regions[i]
    if region.source_id == source_id {
      return Some(region)
    }
    i = i - 1
  }
  None
}

///|
fn Browser::set_text_control_selection_from_cells(
  self : Browser,
  source_id : String,
  anchor_col : Int,
  anchor_row : Int,
  focus_col : Int,
  focus_row : Int,
) -> Bool {
  if not(self.enable_js) {
    return false
  }
  match self.get_hit_region_for_source_id(source_id) {
    Some(region) => {
      let anchor_local_col = if anchor_col <= region.col {
        0
      } else if anchor_col >= region.col + region.width {
        region.width
      } else {
        anchor_col - region.col
      }
      let anchor_local_row = if anchor_row <= region.row {
        0
      } else if anchor_row >= region.row + region.height {
        region.height - 1
      } else {
        anchor_row - region.row
      }
      let focus_local_col = if focus_col <= region.col {
        0
      } else if focus_col >= region.col + region.width {
        region.width
      } else {
        focus_col - region.col
      }
      let focus_local_row = if focus_row <= region.row {
        0
      } else if focus_row >= region.row + region.height {
        region.height - 1
      } else {
        focus_row - region.row
      }
      let escaped = escape_js_string(source_id)
      let source = "(function(){const target=document.getElementById('" +
        escaped +
        "');if(!target){return 'missing';}const tag=(target.tagName||'').toLowerCase();const type=(target.getAttribute?((target.getAttribute('type')||'').toLowerCase()):'');function isTextLikeInput(){if(tag!=='input'){return false;}return type===''||type==='text'||type==='search'||type==='url'||type==='tel'||type==='email'||type==='password'||type==='number';}function currentValue(el){if(!el){return '';}if(el.value!==undefined&&el.value!==null){return String(el.value);}if(el.getAttribute){return String(el.getAttribute('value')||'');}return '';}function setCaret(index){const value=currentValue(target);const clamped=Math.max(0,Math.min(value.length,Number(index)||0));if(typeof target.setSelectionRange==='function'){target.setSelectionRange(clamped,clamped);}else{target.selectionStart=clamped;target.selectionEnd=clamped;}return 'ok';}if(tag==='textarea'){const value=currentValue(target);const lines=value.split('\\n');const localRow=" +
        anchor_local_row.to_string() +
        ";const anchorCol=" +
        anchor_local_col.to_string() +
        ";const focusRow=" +
        focus_local_row.to_string() +
        ";const focusCol=" +
        focus_local_col.to_string() +
        ";const anchorRow=localRow;function indexForPosition(row,col){let offset=0;for(let i=0;i<lines.length;i++){const line=lines[i];if(i>=row||i===lines.length-1){return offset+Math.max(0,Math.min(line.length,col));}offset+=line.length+1;}return value.length;}const anchor=indexForPosition(anchorRow,anchorCol);const focus=indexForPosition(focusRow,focusCol);const start=Math.min(anchor,focus);const end=Math.max(anchor,focus);if(typeof target.setSelectionRange==='function'){target.setSelectionRange(start,end);}else{target.selectionStart=start;target.selectionEnd=end;}return 'ok';}if(isTextLikeInput()){const value=currentValue(target);const anchor=Math.max(0,Math.min(value.length," +
        anchor_local_col.to_string() +
        "));const focus=Math.max(0,Math.min(value.length," +
        focus_local_col.to_string() +
        "));const start=Math.min(anchor,focus);const end=Math.max(anchor,focus);if(typeof target.setSelectionRange==='function'){target.setSelectionRange(start,end);}else{target.selectionStart=start;target.selectionEnd=end;}return 'ok';}return 'none';})()"
      self.execute_inline_js(source) == Some("ok")
    }
    None => false
  }
}

///|
fn Browser::set_text_control_caret_from_cell(
  self : Browser,
  source_id : String,
  col : Int,
  row : Int,
) -> Bool {
  self.set_text_control_selection_from_cells(source_id, col, row, col, row)
}

///|
fn Browser::process_pending_script_tasks(self : Browser) -> Int {
  let ready_tasks = self.scheduler.poll_ready()
  let mut processed = 0
  for task in ready_tasks {
    match task.action {
      @scheduler.ExecuteScript(_) =>
        match self.script_executor {
          Some(executor) => {
            let result = executor.execute(task)
            let _ = self.scheduler.complete(task.id, result)
            processed = processed + 1
          }
          None => ()
        }
      _ => ()
    }
  }
  processed
}

///|
fn Browser::dispatch_click_to_source_id(
  self : Browser,
  source_id : String,
  client_x? : Int = 0,
  client_y? : Int = 0,
) -> ClickDispatchResult {
  let escaped = escape_js_string(source_id)
  let client_x_source = client_x.to_string()
  let client_y_source = client_y.to_string()
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'missing';}const clientX=" +
    client_x_source +
    ";const clientY=" +
    client_y_source +
    ";function dispatch(type, ctor){const event=new ctor(type,{bubbles:true,cancelable:true,clientX,clientY,pointerId:1,pointerType:'mouse',isPrimary:true});return target.dispatchEvent(event);}dispatch('pointerdown',PointerEvent);dispatch('mousedown',MouseEvent);dispatch('pointerup',PointerEvent);dispatch('mouseup',MouseEvent);return dispatch('click',MouseEvent)?'allow':'prevent';})()"
  let result = self.execute_inline_js(source)
  let _ = self.sync_render_state_from_dom_tree()
  match result {
    Some("prevent") => { handled: true, allow_default: false }
    Some("allow") => { handled: true, allow_default: true }
    Some(_) => { handled: false, allow_default: true }
    None => { handled: false, allow_default: true }
  }
}

///|
fn Browser::dispatch_pointer_mouse_event_to_source_id(
  self : Browser,
  source_id : String,
  pointer_type : String,
  mouse_type : String,
  client_x : Int,
  client_y : Int,
) -> Bool {
  let escaped = escape_js_string(source_id)
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'missing';}const clientX=" +
    client_x.to_string() +
    ";const clientY=" +
    client_y.to_string() +
    ";target.dispatchEvent(new PointerEvent('" +
    escape_js_string(pointer_type) +
    "',{bubbles:true,cancelable:true,clientX,clientY,pointerId:1,pointerType:'mouse',isPrimary:true}));target.dispatchEvent(new MouseEvent('" +
    escape_js_string(mouse_type) +
    "',{bubbles:true,cancelable:true,clientX,clientY}));return 'ok';})()"
  let result = self.execute_inline_js(source)
  let _ = self.sync_render_state_from_dom_tree()
  result == Some("ok")
}

///|
fn Browser::dispatch_click_only_to_source_id(
  self : Browser,
  source_id : String,
  client_x : Int,
  client_y : Int,
) -> ClickDispatchResult {
  let escaped = escape_js_string(source_id)
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'missing';}const clientX=" +
    client_x.to_string() +
    ";const clientY=" +
    client_y.to_string() +
    ";return target.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,clientX,clientY}))?'allow':'prevent';})()"
  let result = self.execute_inline_js(source)
  let _ = self.sync_render_state_from_dom_tree()
  match result {
    Some("prevent") => { handled: true, allow_default: false }
    Some("allow") => { handled: true, allow_default: true }
    Some(_) => { handled: false, allow_default: true }
    None => { handled: false, allow_default: true }
  }
}

///|
fn Browser::is_draggable_source_id(self : Browser, source_id : String) -> Bool {
  if not(self.enable_js) {
    return false
  }
  let escaped = escape_js_string(source_id)
  match
    self.execute_inline_js(
      "(function(){const target=document.getElementById('" +
      escaped +
      "');return target&&target.draggable===true?'true':'false';})()",
    ) {
    Some("true") => true
    _ => false
  }
}

///|
fn Browser::dispatch_drag_event_status_to_source_id(
  self : Browser,
  source_id : String,
  event_type : String,
  client_x : Int,
  client_y : Int,
  related_source_id? : String? = None,
) -> (Bool, Bool) {
  let escaped = escape_js_string(source_id)
  let related_js = match related_source_id {
    Some(id) => "document.getElementById('" + escape_js_string(id) + "')"
    None => "null"
  }
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'missing';}const clientX=" +
    client_x.to_string() +
    ";const clientY=" +
    client_y.to_string() +
    ";const relatedTarget=" +
    related_js +
    ";let dataTransfer=globalThis.__craterDragDataTransfer||null;if('" +
    escape_js_string(event_type) +
    "'==='dragstart'){dataTransfer=new DataTransfer();globalThis.__craterDragDataTransfer=dataTransfer;}const dispatched=target.dispatchEvent(new DragEvent('" +
    escape_js_string(event_type) +
    "',{bubbles:true,cancelable:true,clientX,clientY,relatedTarget,dataTransfer}));if('" +
    escape_js_string(event_type) +
    "'==='dragend'){globalThis.__craterDragDataTransfer=null;}return dispatched?'ok':'canceled';})()"
  let result = self.execute_inline_js(source)
  let _ = self.sync_render_state_from_dom_tree()
  match result {
    Some("ok") => (true, false)
    Some("canceled") => (true, true)
    _ => (false, false)
  }
}

///|
fn Browser::dispatch_drag_event_to_source_id(
  self : Browser,
  source_id : String,
  event_type : String,
  client_x : Int,
  client_y : Int,
  related_source_id? : String? = None,
) -> Bool {
  let (handled, _) = self.dispatch_drag_event_status_to_source_id(
    source_id,
    event_type,
    client_x,
    client_y,
    related_source_id~,
  )
  handled
}

///|
fn Browser::is_current_drop_allowed(self : Browser) -> Bool {
  match
    self.execute_inline_js(
      "(function(){const dt=globalThis.__craterDragDataTransfer||null;if(!dt){return 'none/none';}const allowed=String(dt.effectAllowed||'all').toLowerCase();let drop=String(dt.dropEffect||'none').toLowerCase();function fallbackDropEffect(v){switch(v){case 'copy':case 'copylink':case 'copymove':return 'copy';case 'link':case 'linkmove':return 'link';case 'move':return 'move';case 'all':case 'uninitialized':return 'copy';default:return 'none';}}if(drop==='none'){const fallback=fallbackDropEffect(allowed);if(fallback!=='none'){dt.dropEffect=fallback;drop=fallback;}}return allowed + '/' + drop;})()",
    ) {
    Some("none/none") => false
    Some(state) => {
      let slash = state.find("/")
      match slash {
        Some(idx) => {
          let effect_allowed = state
            .unsafe_substring(start=0, end=idx)
            .to_lower()
          let drop_effect = state
            .unsafe_substring(start=idx + 1, end=state.length())
            .to_lower()
          @interaction_policy.is_drop_effect_compatible(
            effect_allowed, drop_effect,
          )
        }
        None => false
      }
    }
    None => false
  }
}

///|
fn Browser::dispatch_hover_transition(
  self : Browser,
  previous_source_id : String?,
  next_source_id : String?,
  client_x : Int,
  client_y : Int,
) -> Bool {
  if not(self.enable_js) {
    return false
  }
  match (previous_source_id, next_source_id) {
    (None, None) => return false
    _ => ()
  }
  let previous_js = match previous_source_id {
    Some(id) => "document.getElementById('" + escape_js_string(id) + "')"
    None => "null"
  }
  let next_js = match next_source_id {
    Some(id) => "document.getElementById('" + escape_js_string(id) + "')"
    None => "null"
  }
  let source = "(function(){const previous=" +
    previous_js +
    ";const next=" +
    next_js +
    ";const clientX=" +
    client_x.to_string() +
    ";const clientY=" +
    client_y.to_string() +
    ";function dispatch(target,type,ctor,related,bubbles){if(!target){return;}const event=new ctor(type,{bubbles:bubbles,cancelable:false,clientX,clientY,pointerId:1,pointerType:'mouse',isPrimary:true,relatedTarget:related});target.dispatchEvent(event);}if(previous&&previous!==next){dispatch(previous,'pointerout',PointerEvent,next,true);dispatch(previous,'mouseout',MouseEvent,next,true);dispatch(previous,'pointerleave',PointerEvent,next,false);dispatch(previous,'mouseleave',MouseEvent,next,false);}if(next&&previous!==next){dispatch(next,'pointerover',PointerEvent,previous,true);dispatch(next,'mouseover',MouseEvent,previous,true);dispatch(next,'pointerenter',PointerEvent,previous,false);dispatch(next,'mouseenter',MouseEvent,previous,false);}if(next){dispatch(next,'pointermove',PointerEvent,previous,true);dispatch(next,'mousemove',MouseEvent,previous,true);}return 'ok';})()"
  let _ = self.execute_inline_js(source)
  self.sync_render_state_from_dom_tree()
}

///|
fn Browser::dispatch_submit_to_source_id(
  self : Browser,
  source_id : String,
) -> SubmitDispatchResult {
  if not(self.enable_js) {
    return NotSubmittable
  }
  let escaped = escape_js_string(source_id)
  let source = "(function(){const target=document.getElementById('" +
    escaped +
    "');if(!target){return 'none';}const tag=(target.tagName||'').toLowerCase();const type=(target.getAttribute?((target.getAttribute('type')||'').toLowerCase()):'');let form=null;let submitter=null;if(tag==='form'){form=target;}else{if(tag==='button'){if(type!==''&&type!=='submit'){return 'none';}submitter=target;}else if(tag==='input'){if(type==='submit'||type==='image'){submitter=target;}else if(type==='button'||type==='reset'||type==='checkbox'||type==='radio'||type==='file'){return 'none';}}else if(tag==='textarea'||tag==='select'){return 'none';}form=target.closest?target.closest('form'):null;}if(!form){return 'none';}const submitEvent=new Event('submit',{bubbles:true,cancelable:true});if(!form.dispatchEvent(submitEvent)){return 'prevent';}const method=((form.getAttribute&&form.getAttribute('method'))||'get').toLowerCase();let action=((form.getAttribute&&form.getAttribute('action'))||'');if(!action){action=(document&&document.URL)||((window&&window.location&&window.location.href)||'');}if(method!=='get'||!action){return 'handled';}const pairs=[];function pushField(el){if(!el||!el.getAttribute){return;}const name=el.getAttribute('name');if(!name){return;}const elTag=(el.tagName||'').toLowerCase();const elType=((el.getAttribute('type')||'').toLowerCase());if((elTag==='input')&&(elType==='submit'||elType==='button'||elType==='image'||elType==='reset'||elType==='file')){return;}if((elType==='checkbox'||elType==='radio')&&!el.checked){return;}const value=(el.value!==undefined&&el.value!==null)?String(el.value):String(el.getAttribute('value')||'');pairs.push(encodeURIComponent(name)+'='+encodeURIComponent(value));}function walk(node){if(!node||!node.childNodes){return;}for(let i=0;i<node.childNodes.length;i++){const child=node.childNodes[i];if(!child||child.nodeType!==1){continue;}const childTag=(child.tagName||'').toLowerCase();if(childTag==='input'||childTag==='select'||childTag==='textarea'){pushField(child);}walk(child);}}walk(form);if(submitter&&submitter.getAttribute){const submitName=submitter.getAttribute('name');if(submitName){const submitValue=(submitter.value!==undefined&&submitter.value!==null)?String(submitter.value):String(submitter.getAttribute('value')||'');pairs.push(encodeURIComponent(submitName)+'='+encodeURIComponent(submitValue));}}if(pairs.length>0){action += (action.indexOf('?')>=0 ? '&' : '?') + pairs.join('&');}return 'navigate:' + action;})()"
  match self.execute_inline_js(source) {
    Some(result) => {
      let _ = self.sync_render_state_from_dom_tree()
      if result == "none" {
        NotSubmittable
      } else if result == "prevent" {
        Prevented
      } else if result == "handled" {
        Handled
      } else if result.has_prefix("navigate:") {
        Navigate(result.unsafe_substring(start=9, end=result.length()))
      } else {
        NotSubmittable
      }
    }
    None => NotSubmittable
  }
}

///|
fn Browser::dispatch_focused_key_to_source_id(
  self : Browser,
  source_id : String,
  key : String,
) -> FocusedKeyDispatchResult {
  if not(self.enable_js) {
    return NotHandled
  }
  let escaped_id = escape_js_string(source_id)
  let escaped_key = escape_js_string(key)
  let source = "(function(){const target=document.getElementById('" +
    escaped_id +
    "');const key='" +
    escaped_key +
    "';if(!target){return 'none';}const tag=(target.tagName||'').toLowerCase();const type=(target.getAttribute?((target.getAttribute('type')||'').toLowerCase()):'');function dispatchKeyboard(typeName,cancelable){const ev=new KeyboardEvent(typeName,{bubbles:true,cancelable,key:key});return target.dispatchEvent(ev);}function finishHandled(){dispatchKeyboard('keyup',false);return 'handled';}function finish(result){dispatchKeyboard('keyup',false);return result;}function dispatchBeforeInput(inputType,data){let event;if(typeof InputEvent==='function'){event=new InputEvent('beforeinput',{bubbles:true,cancelable:true,data,inputType});}else{event=new Event('beforeinput',{bubbles:true,cancelable:true});event.data=data;event.inputType=inputType;}return target.dispatchEvent(event);}function dispatchInput(){target.dispatchEvent(new Event('input',{bubbles:true}));}function dispatchChange(){target.dispatchEvent(new Event('change',{bubbles:true}));markChangeBase(target);}function currentValue(el){if(!el){return '';}if(el.value!==undefined&&el.value!==null){return String(el.value);}if(el.getAttribute){return String(el.getAttribute('value')||'');}return '';}function markChangeBase(el){if(!el||!el.setAttribute){return;}el.setAttribute('data-crater-change-base',currentValue(el));}function ensureDefaultValue(el){if(!el||!el.getAttribute||!el.setAttribute){return;}if(el.getAttribute('data-crater-default-value')!==null){return;}el.setAttribute('data-crater-default-value',currentValue(el));}function ensureDefaultChecked(el){if(!el||!el.getAttribute||!el.setAttribute){return;}if(el.getAttribute('data-crater-default-checked')!==null){return;}el.setAttribute('data-crater-default-checked',el.checked?'true':'false');}function syncValueAttr(el){if(el&&el.setAttribute){el.setAttribute('value',currentValue(el));}}function syncCheckedAttr(el){if(!el||!el.setAttribute){return;}if(el.checked){el.setAttribute('checked','');}else if(el.removeAttribute){el.removeAttribute('checked');}}function currentSelection(){const value=currentValue(target);const length=value.length;let start=target.selectionStart;let end=target.selectionEnd;if(start===undefined||start===null){start=length;}if(end===undefined||end===null){end=start;}start=Math.max(0,Math.min(length,Number(start)||0));end=Math.max(0,Math.min(length,Number(end)||0));if(end<start){end=start;}return {value,length,start,end};}function setSelection(start,end){const sel=currentSelection();const nextStart=Math.max(0,Math.min(sel.length,Number(start)||0));let nextEnd=end===undefined||end===null?nextStart:Number(end)||0;nextEnd=Math.max(0,Math.min(sel.length,nextEnd));if(nextEnd<nextStart){nextEnd=nextStart;}if(typeof target.setSelectionRange==='function'){target.setSelectionRange(nextStart,nextEnd);}else{target.selectionStart=nextStart;target.selectionEnd=nextEnd;}}function replaceSelection(insertText,inputType){const sel=currentSelection();if(!dispatchBeforeInput(inputType,insertText)){return true;}ensureDefaultValue(target);target.value=sel.value.slice(0,sel.start)+insertText+sel.value.slice(sel.end);syncValueAttr(target);const caret=sel.start+insertText.length;setSelection(caret,caret);dispatchInput();return true;}function deleteBackward(){const sel=currentSelection();if(sel.start===0&&sel.end===0){return true;}if(!dispatchBeforeInput('deleteContentBackward',null)){return true;}ensureDefaultValue(target);let start=sel.start;const end=sel.end;if(start===end){start=Math.max(0,start-1);}target.value=sel.value.slice(0,start)+sel.value.slice(end);syncValueAttr(target);setSelection(start,start);dispatchInput();return true;}function deleteForward(){const sel=currentSelection();if(sel.start===sel.length&&sel.end===sel.length){return true;}if(!dispatchBeforeInput('deleteContentForward',null)){return true;}ensureDefaultValue(target);const start=sel.start;let end=sel.end;if(start===end){end=Math.min(sel.length,end+1);}target.value=sel.value.slice(0,start)+sel.value.slice(end);syncValueAttr(target);setSelection(start,start);dispatchInput();return true;}function moveCaret(delta){const sel=currentSelection();let caret=sel.start===sel.end?sel.start+delta:(delta<0?sel.start:sel.end);caret=Math.max(0,Math.min(sel.length,caret));setSelection(caret,caret);return true;}function moveCaretTo(edge){const sel=currentSelection();const caret=edge==='start'?0:sel.length;setSelection(caret,caret);return true;}function isTextLikeInput(){if(tag!=='input'){return false;}return type===''||type==='text'||type==='search'||type==='url'||type==='tel'||type==='email'||type==='password'||type==='number';}function toggleRadio(el){if(el.checked){return false;}const name=el.getAttribute?el.getAttribute('name'):null;const form=el.closest?el.closest('form'):null;const root=form||document;function walk(node){if(!node||!node.childNodes){return;}for(let i=0;i<node.childNodes.length;i++){const child=node.childNodes[i];if(!child||child.nodeType!==1){continue;}const childTag=(child.tagName||'').toLowerCase();if(childTag==='input'){const childType=((child.getAttribute('type')||'').toLowerCase());if(childType==='radio'&&child!==el&&(child.getAttribute('name')||'')===(name||'')){ensureDefaultChecked(child);child.checked=false;syncCheckedAttr(child);}}walk(child);}}walk(root);ensureDefaultChecked(el);el.checked=true;syncCheckedAttr(el);return true;}function stepSelect(el,delta){if(el.selectedIndex===undefined||el.options===undefined){return false;}const len=el.options.length||0;if(len<=0){return false;}let next=el.selectedIndex;if(next<0){next=0;}else{next=Math.max(0,Math.min(len-1,next+delta));}if(next===el.selectedIndex){return false;}for(let i=0;i<el.options.length;i++){const option=el.options[i];if(option&&option.getAttribute&&option.setAttribute&&option.getAttribute('data-crater-default-selected')===null){option.setAttribute('data-crater-default-selected',option.selected?'true':'false');}}el.selectedIndex=next;return true;}if(tag==='a'){if(key!=='Enter'){return 'none';}if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}return finish('activate');}if(tag==='button'||(tag==='input'&&(type==='submit'||type==='button'||type==='image'||type==='reset'))||tag==='summary'){if(key!=='Enter'&&key!==' '){return 'none';}if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}return finish('activate');}if(tag==='input'&&(type==='checkbox'||type==='radio')){if(key!=='Enter'&&key!==' '){return 'none';}if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}const clickEvent=new MouseEvent('click',{bubbles:true,cancelable:true});const allowClick=target.dispatchEvent(clickEvent);if(allowClick){let changed=false;if(type==='checkbox'){ensureDefaultChecked(target);target.checked=!target.checked;syncCheckedAttr(target);changed=true;}else{changed=toggleRadio(target);}if(changed){dispatchInput();dispatchChange();}}return finish('handled');}if(tag==='textarea'){if(key==='ArrowLeft'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaret(-1);return finish('handled');}if(key==='ArrowRight'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaret(1);return finish('handled');}if(key==='Home'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaretTo('start');return finish('handled');}if(key==='End'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaretTo('end');return finish('handled');}if(key==='Delete'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}deleteForward();return finish('handled');}if(key==='Enter'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}replaceSelection('\\n','insertLineBreak');return finish('handled');}if(key==='Backspace'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}deleteBackward();return finish('handled');}if(key.length===1){if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}replaceSelection(key,'insertText');return finish('handled');}return 'none';}if(isTextLikeInput()){if(key==='ArrowLeft'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaret(-1);return finish('handled');}if(key==='ArrowRight'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaret(1);return finish('handled');}if(key==='Home'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaretTo('start');return finish('handled');}if(key==='End'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}moveCaretTo('end');return finish('handled');}if(key==='Delete'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}deleteForward();return finish('handled');}if(key==='Enter'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}dispatchChange();if(target.closest&&target.closest('form')){return finish('submit');}return finish('handled');}if(key==='Backspace'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}deleteBackward();return finish('handled');}if(key.length===1){if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}replaceSelection(key,'insertText');return finish('handled');}return 'none';}if(tag==='select'){if(key==='ArrowDown'||key==='ArrowUp'){if(!dispatchKeyboard('keydown',true)){return finish('handled');}const changed=stepSelect(target,key==='ArrowDown'?1:-1);if(changed){dispatchInput();dispatchChange();}return finish('handled');}if(key!=='Enter'&&key!==' '){return 'none';}if(!dispatchKeyboard('keydown',true)){return finish('handled');}if(!dispatchKeyboard('keypress',true)){return finish('handled');}return finish('handled');}return 'none';})()"
  match self.execute_inline_js(source) {
    Some(result) => {
      let _ = self.sync_render_state_from_dom_tree()
      match result {
        "handled" => Handled
        "activate" => Activate
        "submit" => Submit
        _ => NotHandled
      }
    }
    None => NotHandled
  }
}

///|

///|
pub fn Browser::tick_js(self : Browser) -> Bool {
  if not(self.enable_js) {
    return false
  }
  if self.dom_tree is None {
    self.init_js_execution()
  }
  let processed = self.process_pending_script_tasks()
  if processed > 0 {
    self.flush_js_logs()
    return self.sync_render_state_from_dom_tree()
  }
  let ticked = match self.script_executor {
    Some(executor) =>
      executor.tick() catch {
        err => {
          println("[JS] Error: " + err.to_string())
          false
        }
      }
    None => false
  }
  if not(ticked) {
    return false
  }
  self.flush_js_logs()
  self.sync_render_state_from_dom_tree()
}

///|
pub async fn Browser::handle_focused_key(
  self : Browser,
  key : String,
) -> Bool raise @http.HttpError {
  let source_id = self.get_focused_source_id()
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      match self.dispatch_focused_key_to_source_id(id, key) {
        Handled => true
        Activate => self.activate_focused_link()
        Submit =>
          match self.dispatch_submit_to_source_id(id) {
            Prevented => true
            Handled => true
            Navigate(url) => {
              let _ = self.navigate(resolve_url(self.current_url, url))
              true
            }
            NotSubmittable => true
          }
        NotHandled => false
      }
    }
    None => false
  }
}

///|
pub async fn Browser::activate_focused_link(
  self : Browser,
) -> Bool raise @http.HttpError {
  let source_id = self.get_focused_source_id()
  let href = self.get_focused_link_url()
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      let (client_x, client_y) = match
        self.get_client_coords_for_source_id(id) {
        Some(coords) => coords
        None => (0, 0)
      }
      let dispatch = self.dispatch_click_to_source_id(id, client_x~, client_y~)
      if not(dispatch.allow_default) {
        return true
      }
      if self.dispatch_activation_default_to_source_id(id) {
        return true
      }
      match self.dispatch_submit_to_source_id(id) {
        Prevented => return true
        Handled => return true
        Navigate(url) => {
          let _ = self.navigate(resolve_url(self.current_url, url))
          return true
        }
        NotSubmittable => ()
      }
      if href is None && dispatch.handled {
        return true
      }
    }
    None => ()
  }
  match href {
    Some(url) if url.length() > 0 => {
      let _ = self.navigate(url)
      true
    }
    _ => false
  }
}

///|
pub fn Browser::hover_at(self : Browser, col : Int, row : Int) -> Bool {
  let next_source_id = self.get_hover_source_id_at(col, row)
  let changed = self.dispatch_hover_transition(
    self.hovered_source_id,
    next_source_id,
    cell_to_client_x(col),
    cell_to_client_y(row),
  )
  self.hovered_source_id = next_source_id
  changed
}

///|
pub fn Browser::pointer_down_at(self : Browser, col : Int, row : Int) -> Bool {
  let source_id = self.get_hover_source_id_at(col, row)
  self.hovered_source_id = source_id
  self.dragging_source_id = None
  self.drag_over_source_id = None
  self.drop_allowed_source_id = None
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      if self.set_text_control_caret_from_cell(id, col, row) {
        self.text_selection_anchor_source_id = Some(id)
        self.text_selection_anchor_col = col
        self.text_selection_anchor_row = row
      } else {
        self.text_selection_anchor_source_id = None
      }
      self.pressed_source_id = Some(id)
      self.dispatch_pointer_mouse_event_to_source_id(
        id,
        "pointerdown",
        "mousedown",
        cell_to_client_x(col),
        cell_to_client_y(row),
      )
    }
    None => {
      self.pressed_source_id = None
      self.text_selection_anchor_source_id = None
      false
    }
  }
}

///|
pub fn Browser::pointer_move_at(self : Browser, col : Int, row : Int) -> Bool {
  let client_x = cell_to_client_x(col)
  let client_y = cell_to_client_y(row)
  let mut changed = self.hover_at(col, row)
  match self.pressed_source_id {
    Some(pressed_id) => {
      match self.text_selection_anchor_source_id {
        Some(anchor_source_id) if anchor_source_id == pressed_id &&
          self.dragging_source_id is None =>
          if self.set_text_control_selection_from_cells(
              pressed_id,
              self.text_selection_anchor_col,
              self.text_selection_anchor_row,
              col,
              row,
            ) {
            changed = true
          }
        _ => ()
      }
      if self.dragging_source_id is None &&
        self.is_draggable_source_id(pressed_id) {
        if self.dispatch_drag_event_to_source_id(
            pressed_id,
            "dragstart",
            client_x,
            client_y,
            related_source_id=None,
          ) {
          self.dragging_source_id = Some(pressed_id)
          changed = true
        }
      }
      match self.dragging_source_id {
        Some(drag_id) => {
          let plan = @interaction_policy.drag_move_target_plan(
            drag_id,
            self.drag_over_source_id.unwrap_or(""),
            self.get_hover_source_id_at(col, row).unwrap_or(""),
          )
          let next_target = if plan.over_target != "" {
            Some(plan.over_target)
          } else {
            None
          }
          if self.dispatch_drag_event_to_source_id(
              drag_id,
              "drag",
              client_x,
              client_y,
              related_source_id=next_target,
            ) {
            changed = true
          }
          if self.drag_over_source_id != next_target {
            self.drop_allowed_source_id = None
            match self.drag_over_source_id {
              Some(previous_target) if plan.emit_dragleave =>
                if self.dispatch_drag_event_to_source_id(
                    previous_target,
                    "dragleave",
                    client_x,
                    client_y,
                    related_source_id=next_target,
                  ) {
                  changed = true
                }
              _ => ()
            }
            match next_target {
              Some(next_id) if plan.emit_dragenter =>
                if self.dispatch_drag_event_to_source_id(
                    next_id,
                    "dragenter",
                    client_x,
                    client_y,
                    related_source_id=self.drag_over_source_id,
                  ) {
                  changed = true
                }
              _ => ()
            }
            self.drag_over_source_id = next_target
          }
          match self.drag_over_source_id {
            Some(target_id) if plan.emit_dragover => {
              let (handled_drag_over, canceled_drag_over) = self.dispatch_drag_event_status_to_source_id(
                target_id,
                "dragover",
                client_x,
                client_y,
                related_source_id=Some(drag_id),
              )
              if handled_drag_over {
                changed = true
              }
              let accepted_target = @interaction_policy.drag_accept_target(
                drag_id, target_id, canceled_drag_over,
              )
              self.drop_allowed_source_id = if accepted_target != "" {
                Some(accepted_target)
              } else {
                None
              }
            }
            _ => ()
          }
        }
        None => ()
      }
      changed
    }
    None => changed
  }
}

///|
pub async fn Browser::pointer_up_at(
  self : Browser,
  col : Int,
  row : Int,
) -> Bool raise @http.HttpError {
  let client_x = cell_to_client_x(col)
  let client_y = cell_to_client_y(row)
  let up_source_id = self.get_hover_source_id_at(col, row)
  let pressed_source_id = self.pressed_source_id
  let dragging_source_id = self.dragging_source_id
  let drag_over_source_id = self.drag_over_source_id
  let drop_allowed_source_id = self.drop_allowed_source_id
  let mut handled = false
  match up_source_id {
    Some(id) =>
      if self.dispatch_pointer_mouse_event_to_source_id(
          id, "pointerup", "mouseup", client_x, client_y,
        ) {
        handled = true
      }
    None => ()
  }
  self.pressed_source_id = None
  self.text_selection_anchor_source_id = None
  self.dragging_source_id = None
  self.drag_over_source_id = None
  self.drop_allowed_source_id = None
  match dragging_source_id {
    Some(drag_id) => {
      let drop_target = @interaction_policy.drag_drop_target(
        drag_id,
        drag_over_source_id.unwrap_or(""),
        drop_allowed_source_id.unwrap_or(""),
      )
      match drag_over_source_id {
        Some(target_id) if drop_target == target_id &&
          self.is_current_drop_allowed() =>
          if self.dispatch_drag_event_to_source_id(
              target_id,
              "drop",
              client_x,
              client_y,
              related_source_id=Some(drag_id),
            ) {
            handled = true
          }
        _ => ()
      }
      if self.dispatch_drag_event_to_source_id(
          drag_id,
          "dragend",
          client_x,
          client_y,
          related_source_id=drag_over_source_id,
        ) {
        handled = true
      }
      return handled
    }
    None => ()
  }
  match (pressed_source_id, up_source_id) {
    (Some(down_id), Some(up_id)) if down_id == up_id => {
      let dispatch = self.dispatch_click_only_to_source_id(
        down_id, client_x, client_y,
      )
      if not(dispatch.allow_default) {
        return true
      }
      if self.dispatch_activation_default_to_source_id(down_id) {
        return true
      }
      match self.dispatch_submit_to_source_id(down_id) {
        Prevented => return true
        Handled => return true
        Navigate(url) => {
          let _ = self.navigate(resolve_url(self.current_url, url))
          return true
        }
        NotSubmittable => ()
      }
      match self.get_href_for_source_id(down_id) {
        Some(url) if url.length() > 0 => {
          let _ = self.navigate(resolve_url(self.current_url, url))
          true
        }
        _ => handled || dispatch.handled
      }
    }
    _ => handled
  }
}

///|
pub async fn Browser::activate_at(
  self : Browser,
  col : Int,
  row : Int,
) -> Bool raise @http.HttpError {
  let source_id = self.get_source_id_at(col, row)
  let href = match self.get_link_at(col, row) {
    Some(url) => Some(resolve_url(self.current_url, url))
    None =>
      match source_id {
        Some(id) => self.get_href_for_source_id(id)
        None => None
      }
  }
  match source_id {
    Some(id) => {
      self.focus_source_id(id)
      let _ = self.set_text_control_caret_from_cell(id, col, row)
      let dispatch = self.dispatch_click_to_source_id(
        id,
        client_x=cell_to_client_x(col),
        client_y=cell_to_client_y(row),
      )
      if not(dispatch.allow_default) {
        return true
      }
      if self.dispatch_activation_default_to_source_id(id) {
        return true
      }
      match self.dispatch_submit_to_source_id(id) {
        Prevented => return true
        Handled => return true
        Navigate(url) => {
          let _ = self.navigate(resolve_url(self.current_url, url))
          return true
        }
        NotSubmittable => ()
      }
      match href {
        Some(url) if url.length() > 0 => {
          let _ = self.navigate(url)
          true
        }
        _ => dispatch.handled
      }
    }
    None =>
      match href {
        Some(url) if url.length() > 0 => {
          let _ = self.navigate(url)
          true
        }
        _ => false
      }
  }
}

///|
pub async fn Browser::activate_link_at(
  self : Browser,
  col : Int,
  row : Int,
) -> Bool raise @http.HttpError {
  self.activate_at(col, row)
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
  self.script_executor = Some(
    match self.js_runtime_override {
      Some(runtime) => @js.ScriptExecutor::new_with_runtime(dom, runtime)
      None => @js.ScriptExecutor::new_deferred(dom)
    },
  )
}

///|
/// Execute scripts from the page (inline only, sync version)
/// Requires enable_js to be set to true (use --enable-js flag)
pub fn Browser::execute_scripts(self : Browser) -> Int {
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
  executed = self.process_pending_script_tasks()
  if executed > 0 {
    let _ = self.sync_render_state_from_dom_tree()
  }
  self.flush_js_logs()
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
        let response = @http.cached_fetch_async(
          url=script_url,
          options=script_options,
          cache=self.http_cache,
          fetcher=http_fetch_adapter,
        )
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
  executed = self.process_pending_script_tasks()
  if executed > 0 {
    let _ = self.sync_render_state_from_dom_tree()
  }
  self.flush_js_logs()
  println("Executed " + executed.to_string() + " script(s)")
  executed
}

///|
/// Apply JS-mutated DomTree back to renderer inputs and invalidate caches
fn Browser::sync_render_state_from_dom_tree(self : Browser) -> Bool {
  match self.dom_tree {
    Some(dom) => {
      let next_html = @js.serialize_dom_to_html(dom)
      if next_html.length() == 0 {
        return false
      }
      if next_html == self.html_content {
        return false
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
      true
    }
    None => false
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
  match elem.id {
    Some(id) => {
      let _ = dom.set_attribute(node_id, "id", id)
    }
    None => ()
  }
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
