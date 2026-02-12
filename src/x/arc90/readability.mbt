// =============================================================================
// Readability-style Scoring
// =============================================================================

///|
fn build_readability_scores(root : @aom.AccessibilityNode) -> ReadabilityScores {
  let scores : Map[String, Double] = {}
  let candidates : Array[@aom.AccessibilityNode] = []
  let seen : Map[String, Bool] = {}
  let ancestors : Array[@aom.AccessibilityNode] = []
  collect_readability_candidates(root, ancestors, scores, candidates, seen)
  adjust_readability_scores(candidates, scores)
  { scores, candidates }
}

///|
fn collect_readability_candidates(
  node : @aom.AccessibilityNode,
  ancestors : Array[@aom.AccessibilityNode],
  scores : Map[String, Double],
  candidates : Array[@aom.AccessibilityNode],
  seen : Map[String, Bool],
) -> Unit {
  if should_score_for_readability(node) {
    let text_content = get_text_content(node)
    if text_content.length() >= 25 {
      let content_score = calculate_readability_content_score(text_content)
      let depth = ancestors.length()
      let max_depth = if depth < 3 { depth } else { 3 }
      for i in 0..<max_depth {
        let ancestor = ancestors[depth - 1 - i]
        ensure_readability_initialized(scores, candidates, seen, ancestor)
        let divider = if i == 0 {
          1.0
        } else if i == 1 {
          2.0
        } else {
          i.to_double() * 3.0
        }
        add_readability_score(scores, ancestor, content_score / divider)
      }
    }
  }
  ancestors.push(node)
  for child in node.children {
    collect_readability_candidates(child, ancestors, scores, candidates, seen)
  }
  let _ = ancestors.pop()
}

///|
fn should_score_for_readability(node : @aom.AccessibilityNode) -> Bool {
  match node.tag_name {
    Some(tag) =>
      match tag {
        "section" | "h2" | "h3" | "h4" | "h5" | "h6" | "p" | "td" | "pre" =>
          true
        _ => node.role == @aom.Paragraph || node.role == @aom.Heading
      }
    None => node.role == @aom.Paragraph || node.role == @aom.Heading
  }
}

///|
fn calculate_readability_content_score(text_content : String) -> Double {
  let mut score = 1.0
  let comma_count = count_readability_commas(text_content)
  score = score + comma_count.to_double()
  let text_len = text_content.length()
  let length_bonus = if text_len / 100 > 3 { 3 } else { text_len / 100 }
  score = score + length_bonus.to_double()
  score
}

///|
fn count_readability_commas(text_content : String) -> Int {
  let mut count = 0
  for c in text_content {
    if c == ',' {
      count = count + 1
    }
  }
  count
}

///|
fn ensure_readability_initialized(
  scores : Map[String, Double],
  candidates : Array[@aom.AccessibilityNode],
  seen : Map[String, Bool],
  node : @aom.AccessibilityNode,
) -> Unit {
  match scores.get(node.id) {
    Some(_) => ()
    None => {
      scores[node.id] = initial_readability_score(node)
      match seen.get(node.id) {
        Some(_) => ()
        None => {
          seen[node.id] = true
          candidates.push(node)
        }
      }
    }
  }
}

///|
fn initial_readability_score(node : @aom.AccessibilityNode) -> Double {
  let tag_score = match node.tag_name {
    Some(tag) =>
      match tag {
        "article" | "main" => 10.0
        "div" => 5.0
        "pre" | "td" | "blockquote" => 3.0
        "address" | "ol" | "ul" | "dl" | "dd" | "dt" | "li" | "form" => -3.0
        "h1" | "h2" | "h3" | "h4" | "h5" | "h6" | "th" => -5.0
        _ => 0.0
      }
    None =>
      match node.role {
        @aom.Article | @aom.Main => 10.0
        @aom.Blockquote => 3.0
        @aom.Heading => -5.0
        _ => 0.0
      }
  }
  tag_score + calculate_readability_class_weight(node)
}

///|
fn calculate_readability_class_weight(node : @aom.AccessibilityNode) -> Double {
  let mut weight = 0.0
  let selector_lower = match node.selector {
    Some(selector_str) => selector_str.to_lower()
    None => ""
  }
  if selector_lower.length() > 0 {
    if contains_any(selector_lower, readability_negative_patterns()) {
      weight = weight - 25.0
    }
    if contains_any(selector_lower, readability_positive_patterns()) {
      weight = weight + 25.0
    }
  }
  if node.id.length() > 0 {
    let id_lower = node.id.to_lower()
    if contains_any(id_lower, readability_negative_patterns()) {
      weight = weight - 25.0
    }
    if contains_any(id_lower, readability_positive_patterns()) {
      weight = weight + 25.0
    }
  }
  weight
}

///|
fn readability_positive_patterns() -> FixedArray[String] {
  [
    "article", "body", "content", "entry", "hentry", "h-entry", "main", "page", "pagination",
    "post", "text", "blog", "story", "body-text", "bodytext", "articlebody", "article-body",
    "article__body", "entry-content", "post-content", "post-body", "story-body",
  ]
}

///|
fn readability_negative_patterns() -> FixedArray[String] {
  [
    "-ad-", "hidden", " hid ", "banner", "combx", "comment", "com-", "contact", "footer",
    "gdpr", "masthead", "media", "meta", "outbrain", "promo", "related", "scroll",
    "share", "shoutbox", "sidebar", "skyscraper", "sponsor", "shopping", "tags",
    "widget", "newsletter", "subscribe", "signup", "sign-up", "signin", "sign-in",
    "login", "privacy", "terms", "cookie", "policy", "legal",
  ]
}

///|
fn readability_unlikely_patterns() -> FixedArray[String] {
  [
    "-ad-", "ai2html", "banner", "breadcrumbs", "combx", "comment", "community",
    "cover-wrap", "disqus", "extra", "footer", "gdpr", "header", "legends", "menu",
    "related", "remark", "replies", "rss", "shoutbox", "sidebar", "skyscraper", "social",
    "sponsor", "supplemental", "ad-break", "agegate", "pagination", "pager", "popup",
    "yom-remote", "newsletter", "subscribe", "signup", "sign-up", "signin", "sign-in",
    "login", "privacy", "terms", "cookie", "policy", "legal",
  ]
}

///|
fn readability_ok_patterns() -> FixedArray[String] {
  ["and", "article", "body", "column", "content", "main", "shadow"]
}

///|
fn adjust_readability_scores(
  candidates : Array[@aom.AccessibilityNode],
  scores : Map[String, Double],
) -> Unit {
  for candidate in candidates {
    let base_score = get_readability_score(scores, candidate)
    let text_content = get_text_content(candidate)
    let link_density = calculate_link_density(candidate, text_content)
    let mut score = base_score * (1.0 - link_density)
    let text_density = calculate_readability_text_density(candidate)
    if text_density > 0.0 {
      let density_bonus = text_density / 10.0
      let bonus = if density_bonus > 0.1 { 0.1 } else { density_bonus }
      score = score * (1.0 + bonus)
    }
    let repetition_penalty = calculate_repetition_penalty(text_content)
    score = score * repetition_penalty
    let navigation_penalty = calculate_navigation_penalty(
      candidate, text_content,
    )
    score = score * navigation_penalty
    let numeric_penalty = calculate_numeric_penalty(text_content)
    score = score * numeric_penalty
    let table_penalty = calculate_table_penalty(candidate, text_content)
    score = score * table_penalty
    let share_penalty = calculate_share_penalty(text_content)
    score = score * share_penalty
    let caption_penalty = calculate_caption_penalty(text_content)
    score = score * caption_penalty
    let related_penalty = calculate_related_penalty(candidate, text_content)
    score = score * related_penalty
    let heading_bonus = calculate_heading_bonus(candidate)
    score = score * heading_bonus
    let paragraph_factor = calculate_readability_paragraph_factor(candidate)
    score = score * paragraph_factor
    let punctuation_factor = calculate_readability_punctuation_factor(
      text_content,
    )
    score = score * punctuation_factor
    let length_penalty = calculate_readability_length_penalty(
      text_content.length(),
    )
    score = score * length_penalty
    scores[candidate.id] = score
  }
}

///|
fn calculate_readability_punctuation_factor(text_content : String) -> Double {
  let density = get_punctuation_density(text_content)
  if density <= 0.5 {
    0.6
  } else if density <= 1.0 {
    0.8
  } else if density <= 2.0 {
    1.1
  } else if density <= 5.0 {
    1.25
  } else if density <= 8.0 {
    1.05
  } else {
    0.9
  }
}

///|
fn calculate_readability_paragraph_factor(
  node : @aom.AccessibilityNode,
) -> Double {
  let count = count_paragraph_elements(node)
  if count >= 6 {
    1.3
  } else if count >= 4 {
    1.2
  } else if count >= 2 {
    1.1
  } else if count == 1 {
    1.0
  } else {
    0.8
  }
}

///|
fn calculate_readability_length_penalty(text_len : Int) -> Double {
  if text_len < 120 {
    0.4
  } else if text_len < 200 {
    0.6
  } else if text_len < 300 {
    0.8
  } else if text_len <= 2000 {
    1.0
  } else if text_len <= 4000 {
    0.95
  } else if text_len <= 8000 {
    0.9
  } else if text_len <= 16000 {
    0.7
  } else if text_len <= 32000 {
    0.5
  } else {
    0.3
  }
}

///|
fn calculate_readability_text_density(node : @aom.AccessibilityNode) -> Double {
  let text_len = get_text_content(node).length()
  if text_len == 0 {
    return 0.0
  }
  let child_count = node.children.length()
  let denom = if child_count > 0 { child_count.to_double() } else { 1.0 }
  text_len.to_double() / denom
}

///|
fn add_readability_score(
  scores : Map[String, Double],
  node : @aom.AccessibilityNode,
  delta : Double,
) -> Unit {
  let current = match scores.get(node.id) {
    Some(v) => v
    None => 0.0
  }
  scores[node.id] = current + delta
}

///|
fn get_readability_score(
  scores : Map[String, Double],
  node : @aom.AccessibilityNode,
) -> Double {
  match scores.get(node.id) {
    Some(v) => v
    None => 0.0
  }
}

///|
fn is_probably_content(node : @aom.AccessibilityNode) -> Bool {
  if not(node.visible) {
    return false
  }
  if is_unlikely_candidate(node) {
    return false
  }
  let text_content = get_text_content(node)
  if text_content.length() < 140 {
    return false
  }
  let link_density = calculate_link_density(node, text_content)
  if link_density > 0.5 {
    return false
  }
  let text_density = calculate_readability_text_density(node)
  if text_density < 0.1 {
    return false
  }
  true
}

///|
fn is_unlikely_candidate(node : @aom.AccessibilityNode) -> Bool {
  let selector_lower = match node.selector {
    Some(selector_str) => selector_str.to_lower()
    None => ""
  }
  let id_lower = node.id.to_lower()
  let match_string = if selector_lower.is_empty() {
    id_lower
  } else {
    selector_lower + " " + id_lower
  }
  if contains_any(match_string, readability_unlikely_patterns()) &&
    not(contains_any(match_string, readability_ok_patterns())) {
    true
  } else {
    false
  }
}

///|
fn calculate_readability_bonus(readability_score : Double) -> Double {
  if readability_score <= 0.0 {
    1.0
  } else {
    let bonus = 1.0 + readability_score / 8.0
    if bonus > 3.0 {
      3.0
    } else {
      bonus
    }
  }
}

///|
fn calculate_navigation_penalty(
  node : @aom.AccessibilityNode,
  text_content : String,
) -> Double {
  let text_len = text_content.length()
  if text_len == 0 {
    return 1.0
  }
  let text_lower = text_content.to_lower()
  let patterns : FixedArray[String] = [
    "read more", "continue reading", "next", "previous", "next post", "previous post",
    "older", "newer", "related", "recommended", "see also", "more stories", "newsletter",
    "subscribe", "sign in", "sign-in", "signin", "login", "privacy policy", "terms of use",
    "all rights reserved", "copyright", "cookie policy", "terms", "privacy", "you may like",
    "you might also like", "you may also like", "related posts", "related articles",
    "more like this", "você pode gostar", "voce pode gostar", "talvez voce goste",
    "share", "facebook", "twitter", "whatsapp", "pinterest", "linkedin", "instagram",
    "telegram", "email", "compartilhar", "compartilhe", "enviar", "filed under",
    "comments", "comment", "replies", "reply", "securedrop", "secure drop", "signal",
  ]
  let nav_hits = count_any_occurrences(text_lower, patterns)
  if nav_hits == 0 {
    return 1.0
  }
  let social_hits = count_any_occurrences(text_lower, [
    "share", "facebook", "twitter", "whatsapp", "pinterest", "linkedin", "instagram",
    "telegram", "email", "compartilhar", "compartilhe", "enviar", "pint", "baixar",
    "download", "you may like", "you might also like", "voce pode gostar", "você pode gostar",
  ])
  let link_density = calculate_link_density(node, text_content)
  let mut penalty = if nav_hits >= 6 {
    0.4
  } else if nav_hits >= 3 {
    0.6
  } else {
    0.8
  }
  if nav_hits >= 12 && text_len > 3000 {
    penalty = 0.2
  } else if nav_hits >= 6 && text_len > 1000 && penalty > 0.3 {
    penalty = 0.3
  }
  if text_len < 200 {
    if penalty > 0.3 {
      penalty = 0.3
    }
  } else if text_len < 400 && link_density > 0.2 {
    if penalty > 0.5 {
      penalty = 0.5
    }
  } else if link_density > 0.5 {
    if penalty > 0.6 {
      penalty = 0.6
    }
  }
  if social_hits >= 10 {
    penalty = 0.2
  } else if social_hits >= 6 && penalty > 0.3 {
    penalty = 0.3
  }
  penalty
}

///|
fn calculate_repetition_penalty(text_content : String) -> Double {
  let parts = text_content.to_lower().split(" ")
  let mut total = 0
  let mut unique = 0
  let seen : Map[String, Bool] = {}
  for part in parts {
    let word = part.trim().to_string()
    if word.length() < 3 {
      continue
    }
    total = total + 1
    match seen.get(word) {
      Some(_) => ()
      None => {
        seen[word] = true
        unique = unique + 1
      }
    }
  }
  if total < 12 {
    return 1.0
  }
  let ratio = unique.to_double() / total.to_double()
  if ratio < 0.15 {
    0.2
  } else if ratio < 0.25 {
    0.3
  } else if ratio < 0.35 {
    0.5
  } else if ratio < 0.45 {
    0.8
  } else {
    1.0
  }
}
