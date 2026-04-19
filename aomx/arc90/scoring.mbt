// =============================================================================
// Scoring
// =============================================================================

///|
fn score_content_block(
  node : @aom.AccessibilityNode,
  text_content : String,
  config : ExtractConfig,
  readability_scores : Map[String, Double],
) -> ContentBlock {
  let text_density = calculate_text_density(node, text_content)
  let visual_score = calculate_visual_score(node, config)
  let position_penalty = calculate_position_penalty(node, config)

  // Role bonus: semantic content elements score higher
  let role_bonus : Double = match node.role {
    @aom.Article => 2.0
    @aom.Main => 1.8
    @aom.Region => 1.2
    _ => 1.0
  }

  // Tag-based adjustment
  let tag_multiplier : Double = match node.tag_name {
    Some(tag) =>
      match tag {
        "article" => 1.5
        "main" => 1.5
        "section" => 1.1
        "header" | "footer" | "nav" | "aside" => 0.1
        _ => 1.0
      }
    None => 1.0
  }

  // Selector-based scoring (class/id patterns)
  let selector_score = calculate_selector_score(node)

  // Link density scoring (penalize high link density)
  let link_density_score = calculate_link_density_score(node, text_content)

  // Readability-style: paragraph count bonus
  // More paragraphs = likely main content
  let paragraph_bonus = calculate_paragraph_bonus(node)

  // Readability-style: punctuation bonus
  // More commas/periods = likely prose content (not navigation)
  let punctuation_bonus = calculate_punctuation_bonus(text_content)

  // Readability-style paragraph-level scoring bonus (propagated from paragraphs)
  let readability_score = get_readability_score(readability_scores, node)
  let readability_bonus = calculate_readability_bonus(readability_score)

  // Navigation-like text penalty
  let navigation_penalty = calculate_navigation_penalty(node, text_content)
  let repetition_penalty = calculate_repetition_penalty(text_content)
  let numeric_penalty = calculate_numeric_penalty(text_content)
  let table_penalty = calculate_table_penalty(node, text_content)
  let share_penalty = calculate_share_penalty(text_content)
  let caption_penalty = calculate_caption_penalty(text_content)
  let related_penalty = calculate_related_penalty(node, text_content)
  let heading_bonus = calculate_heading_bonus(node)
  let layout_bonus = calculate_layout_bonus(node, config)

  // Combined score
  let base_score = text_density * visual_score * (1.0 - position_penalty)
  let score = base_score *
    role_bonus *
    tag_multiplier *
    selector_score *
    link_density_score *
    paragraph_bonus *
    punctuation_bonus *
    readability_bonus *
    navigation_penalty *
    repetition_penalty *
    numeric_penalty *
    table_penalty *
    share_penalty *
    caption_penalty *
    related_penalty *
    heading_bonus *
    layout_bonus
  { node, score, text_density, visual_score, position_penalty }
}

///|
/// Text density = text length / bounding box area
fn calculate_text_density(
  node : @aom.AccessibilityNode,
  text_content : String,
) -> Double {
  match node.bounds {
    Some(bounds) => {
      let area = bounds.width * bounds.height
      if area > 0.0 {
        text_content.length().to_double() / area * 1000.0 // Normalize
      } else {
        0.0
      }
    }
    None => text_content.length().to_double() / 1000.0 // Fallback: just text length
  }
}

///|
/// Visual score based on size and proportion
fn calculate_visual_score(
  node : @aom.AccessibilityNode,
  config : ExtractConfig,
) -> Double {
  match node.bounds {
    Some(bounds) => {
      // Larger content areas score higher
      let area_ratio = bounds.width *
        bounds.height /
        (config.viewport_width * config.viewport_height)

      // Content should be reasonably wide (not sidebar)
      let width_ratio = bounds.width / config.viewport_width
      let width_score = if width_ratio > 0.5 {
        1.0
      } else if width_ratio > 0.3 {
        0.7
      } else {
        0.3
      }

      // Prefer taller content blocks
      let height_score = if bounds.height > 500.0 {
        1.0
      } else if bounds.height > 200.0 {
        0.7
      } else {
        0.4
      }
      (area_ratio * 10.0 + width_score + height_score) / 3.0
    }
    None => 0.5 // Neutral score without bounds
  }
}

///|
/// Position penalty for sidebar/header/footer positions
fn calculate_position_penalty(
  node : @aom.AccessibilityNode,
  config : ExtractConfig,
) -> Double {
  match node.bounds {
    Some(bounds) => {
      let mut penalty = 0.0

      // Top of page penalty (likely header)
      if bounds.y < 100.0 {
        penalty = penalty + 0.3
      }

      // Sidebar penalty (far left or right)
      let center_x = bounds.x + bounds.width / 2.0
      let center_ratio = center_x / config.viewport_width
      if center_ratio < 0.25 || center_ratio > 0.75 {
        penalty = penalty + 0.2
      }

      // Very bottom penalty (likely footer)
      if bounds.y > config.viewport_height * 0.9 {
        penalty = penalty + 0.3
      }
      if penalty > 0.8 {
        0.8
      } else {
        penalty
      } // Don't penalize more than 80%
    }
    None => 0.0
  }
}

///|
/// Selector-based scoring using class/id name patterns (Readability-style)
fn calculate_selector_score(node : @aom.AccessibilityNode) -> Double {
  let mut score = 1.0

  // Check selector for class/id patterns
  // Selector format: "tag#id.class1.class2"
  match node.selector {
    Some(selector_str) => {
      let selector_lower = selector_str.to_lower()
      // Positive patterns (content indicators)
      if contains_any(selector_lower, [
          "article", "content", "post", "text", "body", "entry", "story", "main",
          "blog", "news", "body-text", "bodytext", "articlebody", "article-body",
          "article__body", "entry-content", "post-content", "post-body", "story-body",
        ]) {
        score = score * 1.5
      }
      // Negative patterns (non-content indicators)
      if contains_any(selector_lower, [
          "sidebar", "side-bar", "widget", "ad", "advertisement", "sponsor", "promo",
          "social", "share", "comment", "related", "recommend", "footer", "header",
          "nav", "menu", "breadcrumb", "pagination", "meta", "newsletter", "subscribe",
          "signup", "sign-up", "signin", "sign-in", "login", "privacy", "terms",
          "cookie", "policy", "legal",
        ]) {
        score = score * 0.3
      }
    }
    None => ()
  }

  // Check id for patterns (id is String, not Option)
  if node.id.length() > 0 {
    let id_lower = node.id.to_lower()
    if contains_any(id_lower, [
        "article", "content", "post", "main", "story", "entry", "body-text", "bodytext",
        "articlebody", "article-body", "article__body", "entry-content", "post-content",
        "post-body", "story-body",
      ]) {
      score = score * 1.5
    }
    if contains_any(id_lower, [
        "sidebar", "widget", "ad", "sponsor", "comment", "footer", "header", "nav",
        "newsletter", "subscribe", "signup", "sign-up", "signin", "sign-in", "login",
        "privacy", "terms", "cookie", "policy", "legal",
      ]) {
      score = score * 0.3
    }
  }
  score
}

///|
/// Check if string contains any of the patterns
fn contains_any(s : String, patterns : FixedArray[String]) -> Bool {
  for pattern in patterns {
    if string_contains(s, pattern) {
      return true
    }
  }
  false
}

///|
fn count_any_occurrences(s : String, patterns : FixedArray[String]) -> Int {
  let mut total = 0
  for pattern in patterns {
    total = total + count_occurrences(s, pattern)
  }
  total
}

///|
fn count_occurrences(haystack : String, needle : String) -> Int {
  if needle.length() == 0 || haystack.length() < needle.length() {
    return 0
  }
  let h_len = haystack.length()
  let n_len = needle.length()
  let mut count = 0
  for i in 0..<(h_len - n_len + 1) {
    let mut found = true
    for j in 0..<n_len {
      if haystack[i + j] != needle[j] {
        found = false
        break
      }
    }
    if found {
      count = count + 1
    }
  }
  count
}

///|
/// Simple string contains check
fn string_contains(haystack : String, needle : String) -> Bool {
  if needle.length() == 0 {
    return true
  }
  if haystack.length() < needle.length() {
    return false
  }
  let h_len = haystack.length()
  let n_len = needle.length()
  for i in 0..<(h_len - n_len + 1) {
    let mut found = true
    for j in 0..<n_len {
      if haystack[i + j] != needle[j] {
        found = false
        break
      }
    }
    if found {
      return true
    }
  }
  false
}

///|
/// Paragraph bonus - more paragraphs = likely main content
fn calculate_paragraph_bonus(node : @aom.AccessibilityNode) -> Double {
  let p_count = count_paragraph_elements(node)

  // Score based on paragraph count
  if p_count >= 5 {
    1.5 // Many paragraphs = strong content indicator
  } else if p_count >= 3 {
    1.3
  } else if p_count >= 1 {
    1.1
  } else {
    1.0 // No paragraphs = neutral
  }
}

///|
/// Count paragraph elements (p, pre, blockquote)
fn count_paragraph_elements(node : @aom.AccessibilityNode) -> Int {
  let mut count = 0

  // Check if this is a paragraph-like element
  match node.tag_name {
    Some(tag) =>
      match tag {
        "p" | "pre" | "blockquote" => count = count + 1
        _ => ()
      }
    None => ()
  }

  // Recurse into children
  for child in node.children {
    count = count + count_paragraph_elements(child)
  }
  count
}

///|
/// Punctuation bonus - more commas/periods = likely prose content
fn calculate_punctuation_bonus(text_content : String) -> Double {
  let punct_density = get_punctuation_density(text_content)
  if punct_density <= 0.0 {
    return 1.0
  }

  // Score based on punctuation density
  // Normal prose has ~2-4% punctuation
  if punct_density > 2.0 && punct_density < 5.0 {
    1.3 // Good prose density
  } else if punct_density > 1.0 && punct_density < 6.0 {
    1.1 // Acceptable density
  } else if punct_density > 6.0 {
    0.9 // Too much punctuation (might be lists/code)
  } else {
    1.0 // Low punctuation = neutral
  }
}

///|
/// Penalize numeric-heavy text blocks (tables/pricing)
fn calculate_numeric_penalty(text_content : String) -> Double {
  let text_len = text_content.length()
  if text_len < 80 {
    return 1.0
  }
  let mut digit_count = 0
  let mut currency_count = 0
  for c in text_content {
    if c is ('0'..<'9') {
      digit_count = digit_count + 1
    } else if c == '$' || c == '€' || c == '£' || c == '¥' {
      currency_count = currency_count + 1
    }
  }
  let digit_pct = digit_count.to_double() / text_len.to_double() * 100.0
  let commerce_hits = count_any_occurrences(text_content.to_lower(), [
    "price", "save", "promo", "discount", "deal", "coupon", "cart", "buy",
  ])
  if currency_count >= 2 || commerce_hits >= 2 {
    if digit_pct >= 12.0 {
      0.3
    } else if digit_pct >= 6.0 {
      0.6
    } else {
      1.0
    }
  } else if digit_pct >= 30.0 {
    0.6
  } else {
    1.0
  }
}

///|
fn count_tag_occurrences(
  node : @aom.AccessibilityNode,
  tags : FixedArray[String],
) -> Int {
  let mut count = 0
  match node.tag_name {
    Some(tag) => {
      let tag_lower = tag.to_lower().to_string()
      for t in tags {
        if tag_lower == t {
          count = count + 1
          break
        }
      }
    }
    None => ()
  }
  for child in node.children {
    count = count + count_tag_occurrences(child, tags)
  }
  count
}

///|
/// Penalize table-heavy containers when paragraph content is scarce
fn calculate_table_penalty(
  node : @aom.AccessibilityNode,
  text_content : String,
) -> Double {
  let table_count = count_tag_occurrences(node, ["table", "tr", "td", "th"])
  let paragraph_count = count_tag_occurrences(node, ["p", "pre", "blockquote"])
  let text_lower = text_content.to_lower()
  let commerce_hits = count_any_occurrences(text_lower, [
    "price", "save", "promo", "discount", "deal", "coupon", "cart", "buy",
  ])
  let currency_hits = count_any_occurrences(text_lower, ["$", "€", "£", "¥"])
  if commerce_hits == 0 && currency_hits == 0 {
    return 1.0
  }
  if table_count >= 12 && paragraph_count <= 1 {
    0.3
  } else if table_count >= 6 && paragraph_count <= 2 {
    0.5
  } else {
    1.0
  }
}

///|
/// Penalize share/related blocks with repeated social labels
fn calculate_share_penalty(text_content : String) -> Double {
  let text_lower = text_content.to_lower()
  let patterns : FixedArray[String] = [
    "share", "facebook", "twitter", "whatsapp", "pinterest", "linkedin", "instagram",
    "telegram", "email", "compartilhar", "compartilhe", "enviar", "pint", "baixar",
    "download", "you may like", "you might also like", "voce pode gostar",
  ]
  let hits = count_any_occurrences(text_lower, patterns)
  let text_len = text_content.length()
  if hits == 0 || text_len == 0 {
    return 1.0
  }
  let per_200 = hits.to_double() / (text_len.to_double() / 200.0)
  if per_200 < 0.6 {
    1.0
  } else if per_200 < 1.2 {
    0.8
  } else if per_200 < 2.5 {
    0.6
  } else {
    0.3
  }
}

///|
/// Penalize short caption/credit blocks
fn calculate_caption_penalty(text_content : String) -> Double {
  let text_len = text_content.length()
  if text_len == 0 || text_len > 400 {
    return 1.0
  }
  let lower = text_content.to_lower()
  let patterns : FixedArray[String] = [
    "getty images", "shutterstock", "ap photo", "reuters", "photo by", "image by",
    "photo:", "image:", "source:", "caption", "credit:",
  ]
  let hits = count_any_occurrences(lower, patterns)
  if hits == 0 {
    1.0
  } else if hits >= 2 {
    0.2
  } else {
    0.4
  }
}

///|
/// Penalize related-post collections
fn calculate_related_penalty(
  node : @aom.AccessibilityNode,
  text_content : String,
) -> Double {
  let article_count = count_tag_occurrences(node, ["article"])
  let h1_count = count_tag_occurrences(node, ["h1"])
  if article_count < 2 {
    return 1.0
  }
  let lower = text_content.to_lower()
  let related_hits = count_any_occurrences(lower, [
    "related", "related posts", "related articles", "you may like", "you might also like",
    "voce pode gostar", "você pode gostar",
  ])
  if related_hits >= 1 && article_count >= 3 {
    0.2
  } else if related_hits >= 1 {
    0.4
  } else if h1_count == 0 && article_count >= 2 {
    0.3
  } else if article_count >= 4 && calculate_share_penalty(text_content) <= 0.4 {
    0.4
  } else {
    1.0
  }
}

///|
fn calculate_heading_bonus(node : @aom.AccessibilityNode) -> Double {
  let h1_count = count_tag_occurrences(node, ["h1"])
  let h2_count = count_tag_occurrences(node, ["h2", "h3"])
  let paragraph_count = count_tag_occurrences(node, ["p", "pre", "blockquote"])
  if h1_count >= 1 && paragraph_count >= 1 {
    1.4
  } else if h2_count >= 1 && paragraph_count >= 1 {
    1.2
  } else {
    1.0
  }
}

///|
/// Layout-based bonus using bounds as a weak signal
fn calculate_layout_bonus(
  node : @aom.AccessibilityNode,
  config : ExtractConfig,
) -> Double {
  match node.bounds {
    Some(bounds) => {
      let width_ratio = bounds.width / config.viewport_width
      let height_ratio = bounds.height / config.viewport_height
      let denom = if bounds.height > 0.0 { bounds.height } else { 1.0 }
      let aspect = bounds.width / denom
      let mut bonus = 1.0
      // Favor reasonable content widths (avoid full-bleed wrappers)
      if width_ratio >= 0.35 && width_ratio <= 0.9 {
        bonus = bonus * 1.1
      } else if width_ratio > 0.95 {
        bonus = bonus * 0.85
      } else if width_ratio < 0.2 {
        bonus = bonus * 0.7
      }
      // Penalize extremely tall + narrow elements
      if bounds.height > config.viewport_height * 3.0 && width_ratio < 0.25 {
        bonus = bonus * 0.6
      }
      // Penalize extreme aspect ratios (very thin columns)
      if aspect < 0.12 {
        bonus = bonus * 0.6
      } else if aspect < 0.2 {
        bonus = bonus * 0.8
      }
      // Slightly down-weight near full-page wrappers
      if width_ratio > 0.9 && height_ratio > 0.9 {
        bonus = bonus * 0.9
      }
      bonus
    }
    None => 1.0
  }
}

///|
fn get_punctuation_density(text_content : String) -> Double {
  let text_len = text_content.length()
  if text_len < 40 {
    return 0.0
  }
  let mut punct_count = 0
  for c in text_content {
    match c {
      ',' | '.' | ';' | '!' | '?' => punct_count = punct_count + 1
      _ => ()
    }
  }
  punct_count.to_double() / text_len.to_double() * 100.0
}

///|
/// Link density scoring - penalize elements with high ratio of link text
fn calculate_link_density_score(
  node : @aom.AccessibilityNode,
  text_content : String,
) -> Double {
  let link_density = calculate_link_density(node, text_content)

  // High link density = likely navigation, not content
  if link_density > 0.5 {
    0.2 // Heavy penalty
  } else if link_density > 0.3 {
    0.5
  } else if link_density > 0.1 {
    0.8
  } else {
    1.0 // Low link density = good content
  }
}

///|
/// Calculate link density ratio (0.0 - 1.0)
fn calculate_link_density(
  node : @aom.AccessibilityNode,
  text_content : String,
) -> Double {
  let total_length = text_content.length()
  if total_length == 0 {
    return 0.0
  }
  let link_length = count_link_text_length(node)
  link_length / total_length.to_double()
}

///|
/// Count the total length of text within link elements
fn count_link_text_length(node : @aom.AccessibilityNode) -> Double {
  let mut length = 0.0

  // Check if this node is a link
  match node.role {
    @aom.Link => {
      let coefficient = match node.href {
        Some(href) =>
          if href.length() > 0 && href[0] == '#' {
            0.3
          } else {
            1.0
          }
        None => 1.0
      }
      let mut text_len = 0
      match node.name {
        Some(name) => text_len = text_len + name.length()
        None => ()
      }
      match node.text {
        Some(text) => text_len = text_len + text.length()
        None => ()
      }
      length = length + text_len.to_double() * coefficient
    }
    _ => ()
  }

  // Recurse into children
  for child in node.children {
    length = length + count_link_text_length(child)
  }
  length
}
