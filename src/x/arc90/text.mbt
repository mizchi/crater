// =============================================================================
// Text Extraction
// =============================================================================

///|
fn get_text_content(node : @aom.AccessibilityNode) -> String {
  // Use aggregated text if available
  match node.text {
    Some(text) => {
      if should_defer_to_children_text(node, text) {
        let buf = StringBuilder::new()
        for child in node.children {
          collect_text(child, buf)
        }
        let collected = buf.to_string()
        if collected.length() > text.length() {
          return collected
        }
      }
      text
    }
    None => {
      // Otherwise collect from children
      let buf = StringBuilder::new()
      collect_text(node, buf)
      buf.to_string()
    }
  }
}

///|
fn should_defer_to_children_text(
  node : @aom.AccessibilityNode,
  text : String,
) -> Bool {
  if node.children.length() == 0 {
    return false
  }
  let text_len = text.length()
  if text_len == 0 {
    return true
  }
  if text_len > 800 {
    return false
  }
  let share_penalty = calculate_share_penalty(text)
  let nav_penalty = calculate_navigation_penalty(node, text)
  let caption_penalty = calculate_caption_penalty(text)
  if share_penalty <= 0.4 || nav_penalty <= 0.4 || caption_penalty <= 0.4 {
    return true
  }
  false
}

///|
fn collect_text(node : @aom.AccessibilityNode, buf : StringBuilder) -> Unit {
  if is_navigation(node) {
    return
  }
  match node.text {
    Some(text) if not(text.is_empty()) => {
      if should_skip_navigation_text(node, text) {
        return
      }
      buf.write_string(text)
      buf.write_string(" ")
      return
    }
    _ => ()
  }
  match node.name {
    Some(name) if not(name.is_empty()) => {
      if should_skip_navigation_text(node, name) {
        return
      }
      buf.write_string(name)
      buf.write_string(" ")
    }
    _ => ()
  }
  for child in node.children {
    collect_text(child, buf)
  }
}

///|
fn navigation_label_patterns() -> FixedArray[String] {
  [
    "previous post", "next post", "older", "newer", "read more", "continue reading",
    "next", "previous", "newsletter", "subscribe", "sign in", "sign-in", "signin",
    "login", "privacy", "terms", "policy", "cookie", "share", "facebook", "twitter",
    "whatsapp", "pinterest", "linkedin", "instagram", "telegram", "email", "compartilhar",
    "compartilhe", "enviar", "pint", "baixar", "download", "filed under", "comments",
    "comment", "replies", "reply", "você pode gostar", "voce pode gostar",
  ]
}

///|
fn should_skip_navigation_text(
  node : @aom.AccessibilityNode,
  text : String,
) -> Bool {
  let trimmed = text.trim()
  if trimmed.is_empty() {
    return false
  }
  if trimmed.length() > 40 {
    return false
  }
  let lower = trimmed.to_lower().to_string()
  if not(contains_any(lower, navigation_label_patterns())) {
    return false
  }
  match node.role {
    @aom.Link
    | @aom.ListItem
    | @aom.List
    | @aom.Button
    | @aom.Generic
    | @aom.Group => true
    _ => false
  }
}
