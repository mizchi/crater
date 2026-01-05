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
  /// Links found in current page
  mut links : Array[Link]
  /// Currently focused link index
  mut focused_link : Int
  /// Scroll position (Y offset)
  mut scroll_y : Int
}

///|
/// Create a new browser instance
pub fn Browser::new(width : Int, height : Int) -> Browser {
  {
    current_url: "",
    viewport_width: width,
    viewport_height: height,
    html_content: "",
    links: [],
    focused_link: 0,
    scroll_y: 0,
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
  // Extract links from HTML
  self.links = extract_links(self.html_content)
  self.focused_link = 0
  self.scroll_y = 0
  // Render to Sixel
  self.render()
}

///|
/// Render current content to Sixel
pub fn Browser::render(self : Browser) -> String {
  if self.html_content.length() == 0 {
    return ""
  }
  @renderer.render_to_sixel_with_styles(
    self.html_content,
    self.viewport_width,
    self.viewport_height,
  )
}

///|
/// Scroll down
pub fn Browser::scroll_down(self : Browser, amount : Int) -> Unit {
  self.scroll_y = self.scroll_y + amount
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
