///|
let default_image_cache_max_bytes : Int = 8 * 1024 * 1024

///|
/// Link found in the page
priv struct Link {
  href : String
  text : String
  source_id : String
}

///|
priv struct ClickDispatchResult {
  handled : Bool
  allow_default : Bool
}

///|
priv struct NavigationRequest {
  url : String
  http_method : String
  content_type : String
  body : String
}

///|
priv enum SubmitDispatchResult {
  NotSubmittable
  Prevented
  Handled
  Navigate(NavigationRequest)
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
  /// Last navigation request metadata
  mut last_navigation_request : NavigationRequest?
  /// Request sandbox policy
  mut request_sandbox : @http.RequestSandbox
  /// Viewport width in pixels
  viewport_width : Int
  /// Viewport height in pixels
  viewport_height : Int
  /// Current HTML content
  mut html_content : String
  /// Last raw HTML source before render-time normalization
  mut source_html : String
  /// DOM snapshot HTML that preserves serializable shadow roots
  mut dom_snapshot_html : String
  /// Parsed document (cached to avoid re-parsing)
  mut parsed_doc : @html.Document?
  /// Whether current render HTML may contain declarative shadow DOM templates
  mut html_has_declarative_shadow_dom : Bool
  /// External CSS content
  mut external_css : Array[String]
  /// Prepared external CSS content
  mut prepared_external_css : @renderer.PreparedExternalCss?
  /// Prepared document/style state for the current HTML/CSS/render context
  mut prepared_render_document : @renderer.PreparedRenderDocument?
  /// Color-scheme flag used by prepared_render_document
  mut prepared_render_document_dark : Bool
  /// Cached render node for graphics output modes
  mut graphics_render_node : @layout.Node?
  /// Cached layout for graphics output modes
  mut graphics_layout : @types.Layout?
  /// Color-scheme flag used by graphics render cache
  mut graphics_render_dark : Bool
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
  mut render_node : @layout.Node?
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
  /// Cookie jar (disabled by default for security)
  mut cookie_jar : @http.CookieJar
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
    last_navigation_request: None,
    request_sandbox: @http.RequestSandbox::Open,
    viewport_width: width,
    viewport_height: height,
    html_content: "",
    source_html: "",
    dom_snapshot_html: "",
    parsed_doc: None,
    html_has_declarative_shadow_dom: false,
    external_css: [],
    prepared_external_css: None,
    prepared_render_document: None,
    prepared_render_document_dark: false,
    graphics_render_node: None,
    graphics_layout: None,
    graphics_render_dark: false,
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
    cookie_jar: @http.CookieJar::new(), // disabled by default
  }
}
