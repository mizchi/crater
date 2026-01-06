///|
/// TUI Browser state and core functionality

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
  /// Currently focused link index
  mut focused_link : Int
  /// Scroll position (Y offset)
  mut scroll_y : Int
  /// Content height (for scroll limit)
  mut content_height : Int
  /// Link regions for click hit testing (updated on each render)
  mut link_regions : Array[@tui.LinkRegion]
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
  }
}

///|
/// Resolve relative URL to absolute
fn resolve_url(base_url : String, href : String) -> String {
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
/// Navigate to a URL and render
pub async fn Browser::navigate(
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
  // Render to Sixel
  self.render()
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
  let result = @tui.render_to_ansi_with_status(
    node,
    layout,
    char_width,
    char_height,
    char_scroll_y,
    self.current_url,
    self.links.length(),
    self.focused_link,
  )
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
/// Focus next link
pub fn Browser::next_link(self : Browser) -> Unit {
  if self.links.length() > 0 {
    self.focused_link = (self.focused_link + 1) % self.links.length()
  }
}

///|
/// Focus previous link
pub fn Browser::prev_link(self : Browser) -> Unit {
  if self.links.length() > 0 {
    self.focused_link = (self.focused_link - 1 + self.links.length()) %
      self.links.length()
  }
}

///|
/// Get currently focused link URL
pub fn Browser::get_focused_link_url(self : Browser) -> String? {
  if self.links.length() > 0 && self.focused_link < self.links.length() {
    Some(self.links[self.focused_link].href)
  } else {
    None
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
            href = chars[j + 6:k].to_string()
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
        let text = chars[text_start:text_end].to_string().trim().to_string()
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
