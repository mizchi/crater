// =============================================================================
// Content Block Collection
// =============================================================================

///|
fn collect_content_blocks(
  node : @aom.AccessibilityNode,
  config : ExtractConfig,
  blocks : Array[ContentBlock],
  ads : Array[@aom.AccessibilityNode],
  nav : Array[@aom.AccessibilityNode],
  readability_scores : Map[String, Double],
  within_unlikely : Bool,
  within_nav : Bool,
) -> Unit {
  let is_unlikely = within_unlikely || is_unlikely_candidate(node)
  let nav_container = is_navigation_container(node)
  if nav_container {
    nav.push(node)
    // Check if this looks like an ad
  } else if is_likely_ad(node, config) {
    ads.push(node)
    return
  }
  let text_content = get_text_content(node)
  if not(nav_container) {
    let nav_detected = is_navigation_detected(
      node, within_nav, nav_container, text_content,
    )
    if nav_detected {
      nav.push(node)
    }
  }
  let next_within_nav = within_nav || nav_container

  // Score content-bearing nodes
  if not(next_within_nav) && not(is_unlikely) && is_content_container(node) {
    if text_content.length() >= config.min_text_length &&
      not(should_prune_content_block(node, text_content)) {
      let block = score_content_block(
        node, text_content, config, readability_scores,
      )
      blocks.push(block)
    }
  }

  // Recurse into children
  for child in node.children {
    collect_content_blocks(
      child, config, blocks, ads, nav, readability_scores, is_unlikely, next_within_nav,
    )
  }
}

///|
fn is_navigation_container(node : @aom.AccessibilityNode) -> Bool {
  // Check by role
  match node.role {
    @aom.Navigation | @aom.Banner | @aom.ContentInfo | @aom.Complementary =>
      return true
    _ => ()
  }

  // Check by tag name
  match node.tag_name {
    Some(tag) =>
      match tag {
        "header" | "footer" | "nav" | "aside" => return true
        _ => ()
      }
    None => ()
  }
  false
}

///|
fn is_navigation(node : @aom.AccessibilityNode) -> Bool {
  is_navigation_container(node)
}

///|
fn is_navigation_detected(
  node : @aom.AccessibilityNode,
  within_nav : Bool,
  nav_container : Bool,
  text_content : String,
) -> Bool {
  if nav_container {
    return true
  }
  let list_like = is_list_like(node)
  if within_nav && list_like {
    return true
  }
  let nav_hint = has_navigation_hint(node)
  let link_density = calculate_link_density(node, text_content)
  let text_len = text_content.length()
  let is_link_node = match node.role {
    @aom.Link => true
    _ => false
  }
  let (link_count, total_count) = count_links_and_nodes(node)
  let link_ratio = if total_count == 0 {
    0.0
  } else {
    link_count.to_double() / total_count.to_double()
  }
  let ratio_threshold = if list_like { 0.15 } else { 0.2 }
  let nav_by_structure = link_count >= 2 && link_ratio >= ratio_threshold
  let menu_by_links = not(is_link_node) &&
    link_density >= 0.25 &&
    text_len <= 2000
  nav_hint || nav_by_structure || menu_by_links
}

///|
fn is_list_like(node : @aom.AccessibilityNode) -> Bool {
  match node.role {
    @aom.List | @aom.ListItem => true
    _ =>
      match node.tag_name {
        Some(tag) =>
          match tag {
            "ul" | "ol" | "menu" | "li" => true
            _ => false
          }
        None => false
      }
  }
}

///|
fn has_navigation_hint(node : @aom.AccessibilityNode) -> Bool {
  let patterns = navigation_hint_patterns()
  match node.selector {
    Some(selector) =>
      if contains_any(selector.to_lower().to_string(), patterns) {
        return true
      }
    None => ()
  }
  match node.name {
    Some(name) =>
      if contains_any(name.to_lower().to_string(), patterns) {
        return true
      }
    None => ()
  }
  false
}

///|
fn navigation_hint_patterns() -> FixedArray[String] {
  [
    "nav", "menu", "navbar", "topbar", "footer", "header", "sidebar", "breadcrumb",
    "masthead", "site-nav", "site-navs", "site_header", "site-footer", "siteheader",
    "sitefooter",
  ]
}

///|
fn count_links_and_nodes(node : @aom.AccessibilityNode) -> (Int, Int) {
  let mut link_count = 0
  let mut total_count = 1
  match node.role {
    @aom.Link => link_count = link_count + 1
    _ => ()
  }
  for child in node.children {
    let (child_links, child_total) = count_links_and_nodes(child)
    link_count = link_count + child_links
    total_count = total_count + child_total
  }
  (link_count, total_count)
}

///|
fn is_content_container(node : @aom.AccessibilityNode) -> Bool {
  match node.role {
    @aom.Article | @aom.Main | @aom.Region | @aom.Document => true
    @aom.Generic | @aom.Group =>
      // Generic containers might be content if they have substantial text
      true
    _ => false
  }
}

///|
fn is_likely_ad(node : @aom.AccessibilityNode, config : ExtractConfig) -> Bool {
  match node.bounds {
    Some(bounds) => {
      // Check for common ad sizes
      for ad_size in config.ad_sizes {
        let (ad_w, ad_h) = ad_size
        if is_approx(bounds.width, ad_w, 5.0) &&
          is_approx(bounds.height, ad_h, 5.0) {
          return true
        }
      }

      // Fixed position elements at edges are often ads
      let is_edge_fixed = bounds.x < 10.0 ||
        bounds.x + bounds.width > config.viewport_width - 10.0

      // Very small height with full width = banner ad
      if bounds.height < 100.0 && bounds.width > config.viewport_width * 0.8 {
        return true
      }

      // Sidebar position with common ad dimensions
      if is_edge_fixed && bounds.width < 350.0 && bounds.height > 200.0 {
        return true
      }
      false
    }
    None => false
  }
}

///|
fn is_approx(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() < tolerance
}

///|
fn should_prune_content_block(
  node : @aom.AccessibilityNode,
  text_content : String,
) -> Bool {
  let text_len = text_content.length()
  if text_len < 80 {
    return false
  }
  let link_density = calculate_link_density(node, text_content)
  if link_density > 0.75 && text_len < 400 {
    return true
  }
  let numeric_penalty = calculate_numeric_penalty(text_content)
  let table_penalty = calculate_table_penalty(node, text_content)
  if numeric_penalty <= 0.2 && table_penalty <= 0.3 {
    return true
  }
  false
}
