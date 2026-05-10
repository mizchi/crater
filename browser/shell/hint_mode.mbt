///|
/// Whether hint mode is active
pub fn Browser::is_hint_mode(self : Browser) -> Bool {
  self.hint_mode
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
    match self.get_link_href_for_region(region) {
      Some(link_href) => {
        let href = resolve_url(self.current_url, link_href)
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
      None => ()
    }
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
  if !has_prefix_match {
    self.exit_hint_mode()
  }
  None
}
