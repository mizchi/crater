// =============================================================================
// Main Content Selection
// =============================================================================

///|
fn find_best_readability_candidate(
  candidates : Array[@aom.AccessibilityNode],
  scores : Map[String, Double],
) -> @aom.AccessibilityNode? {
  let mut best : @aom.AccessibilityNode? = None
  let mut best_score = 0.0
  for candidate in candidates {
    if not(is_readability_selection_candidate(candidate)) {
      continue
    }
    let score = get_readability_score(scores, candidate)
    if score > best_score {
      best_score = score
      best = Some(candidate)
    }
  }
  best
}

///|
fn is_readability_selection_candidate(node : @aom.AccessibilityNode) -> Bool {
  if node.role == @aom.Document {
    return false
  }
  match node.tag_name {
    Some(tag) => if tag == "html" || tag == "body" { false } else { true }
    None => true
  }
}

///|
fn find_best_readability_block(
  blocks : Array[ContentBlock],
  scores : Map[String, Double],
) -> ContentBlock? {
  let mut best : ContentBlock? = None
  let mut best_score = 0.0
  for block in blocks {
    let score = get_readability_score(scores, block.node)
    if score > best_score {
      best_score = score
      best = Some(block)
    }
  }
  best
}

///|
fn select_base_main_content(
  article_node : @aom.AccessibilityNode?,
  top_block : ContentBlock?,
  config : ExtractConfig,
  readability_scores : Map[String, Double],
) -> @aom.AccessibilityNode? {
  match article_node {
    Some(node) => {
      let article_text = get_text_content(node)
      let article_len = article_text.length()
      match top_block {
        Some(block) => {
          let block_text = get_text_content(block.node)
          let block_len = block_text.length()
          let article_readability = get_readability_score(
            readability_scores, node,
          )
          let block_readability = get_readability_score(
            readability_scores,
            block.node,
          )

          // Prefer high-readability candidate if article/main looks weak
          if block_readability > article_readability * 1.4 &&
            block_len >= config.min_text_length {
            return Some(block.node)
          }

          // Choose based on relative text lengths:
          // - If content_block is 20x+ larger, it's likely the real content
          // - Otherwise prefer semantic article/main
          if block_len > article_len * 20 {
            Some(block.node)
          } else if article_len >= config.min_text_length {
            Some(node)
          } else {
            Some(block.node)
          }
        }
        None =>
          if article_len >= config.min_text_length {
            Some(node)
          } else {
            None
          }
      }
    }
    None =>
      match top_block {
        Some(block) => Some(block.node)
        None => None
      }
  }
}

///|
fn refine_main_content(
  base_main : @aom.AccessibilityNode?,
  best_readability_block : ContentBlock?,
  best_readability_candidate : @aom.AccessibilityNode?,
  config : ExtractConfig,
  readability_scores : Map[String, Double],
) -> @aom.AccessibilityNode? {
  let readability_node = select_readability_node(
    best_readability_block, best_readability_candidate, readability_scores,
  )
  match (base_main, readability_node) {
    (None, Some(candidate)) => Some(candidate)
    (Some(main), Some(candidate)) => {
      let main_text = get_text_content(main)
      let main_len = main_text.length()
      let read_text = get_text_content(candidate)
      let read_len = read_text.length()
      if main.id == candidate.id {
        return Some(main)
      }
      let main_readability = get_readability_score(readability_scores, main)
      let read_readability = get_readability_score(
        readability_scores, candidate,
      )
      let main_nav_penalty = calculate_navigation_penalty(main, main_text)
      let read_nav_penalty = calculate_navigation_penalty(candidate, read_text)
      let main_share_penalty = calculate_share_penalty(main_text)
      let read_share_penalty = calculate_share_penalty(read_text)
      let main_caption_penalty = calculate_caption_penalty(main_text)
      let read_caption_penalty = calculate_caption_penalty(read_text)
      let main_related_penalty = calculate_related_penalty(main, main_text)
      let read_related_penalty = calculate_related_penalty(candidate, read_text)
      let main_layout_bonus = calculate_layout_bonus(main, config)
      let read_layout_bonus = calculate_layout_bonus(candidate, config)
      if read_len >= config.min_text_length {
        if main_len < config.min_text_length {
          return Some(candidate)
        }
        let main_probably = is_probably_content(main)
        let read_probably = is_probably_content(candidate)
        if read_probably &&
          is_descendant(main, candidate.id) &&
          should_prefer_descendant(main, candidate, main_text, read_text) {
          return Some(candidate)
        }
        if read_probably {
          if not(main_probably) {
            return Some(candidate)
          }
          if main_share_penalty <= 0.4 && read_share_penalty >= 0.8 {
            return Some(candidate)
          }
          if main_caption_penalty <= 0.4 && read_caption_penalty >= 0.8 {
            return Some(candidate)
          }
          if main_related_penalty <= 0.4 && read_related_penalty >= 0.8 {
            return Some(candidate)
          }
          if read_layout_bonus > main_layout_bonus * 1.2 &&
            read_layout_bonus >= 0.95 {
            return Some(candidate)
          }
          if main_nav_penalty < 0.6 && read_nav_penalty >= 0.9 {
            return Some(candidate)
          }
          if should_prefer_smaller_container(
              main_len, read_len, main_readability, read_readability,
            ) {
            return Some(candidate)
          }
          if read_readability > main_readability * 1.6 {
            return Some(candidate)
          }
        } else if not(main_probably) &&
          read_readability > main_readability * 1.8 {
          return Some(candidate)
        }
      }
      if should_promote_readability_candidate(
          main, candidate, main_text, read_text,
        ) {
        return Some(candidate)
      }
      Some(main)
    }
    (Some(main), None) => Some(main)
    (None, None) => None
  }
}

///|
fn should_prefer_descendant(
  main : @aom.AccessibilityNode,
  candidate : @aom.AccessibilityNode,
  main_text : String,
  candidate_text : String,
) -> Bool {
  let main_len = main_text.length()
  let candidate_len = candidate_text.length()
  if candidate_len == 0 || main_len == 0 {
    return false
  }
  if main_len < candidate_len * 2 {
    return false
  }
  let main_density = calculate_readability_text_density(main)
  let cand_density = calculate_readability_text_density(candidate)
  let main_link_density = calculate_link_density(main, main_text)
  let cand_link_density = calculate_link_density(candidate, candidate_text)
  let main_punct = get_punctuation_density(main_text)
  let cand_punct = get_punctuation_density(candidate_text)
  let main_rep = calculate_repetition_penalty(main_text)
  let cand_rep = calculate_repetition_penalty(candidate_text)
  let density_better = cand_density >= main_density * 1.2
  let link_better = cand_link_density <= main_link_density * 0.85
  let punct_better = cand_punct >= 1.0 && cand_punct >= main_punct * 1.2
  let repetition_better = cand_rep >= main_rep + 0.2
  if density_better && link_better {
    return true
  }
  if main_link_density > 0.3 && cand_link_density < 0.2 {
    return true
  }
  if punct_better && (density_better || link_better || repetition_better) {
    return true
  }
  if repetition_better && (cand_punct >= main_punct || density_better) {
    return true
  }
  if main_rep < 0.4 && cand_rep >= 0.6 {
    return true
  }
  if main_punct < 0.8 && cand_punct >= 1.2 && cand_link_density < 0.25 {
    return true
  }
  if main_len >= candidate_len * 3 &&
    candidate_len >= 800 &&
    cand_punct >= 1.0 &&
    cand_link_density <= 0.4 &&
    cand_rep >= main_rep {
    return true
  }
  false
}

///|
fn should_promote_readability_candidate(
  main : @aom.AccessibilityNode,
  candidate : @aom.AccessibilityNode,
  main_text : String,
  candidate_text : String,
) -> Bool {
  let main_len = main_text.length()
  let candidate_len = candidate_text.length()
  if candidate_len == 0 || main_len == 0 {
    return false
  }
  if candidate_len < main_len * 3 {
    return false
  }
  let candidate_link_density = calculate_link_density(candidate, candidate_text)
  if candidate_link_density > 0.4 {
    return false
  }
  let candidate_nav_penalty = calculate_navigation_penalty(
    candidate, candidate_text,
  )
  if candidate_nav_penalty < 0.7 {
    return false
  }
  let candidate_rep = calculate_repetition_penalty(candidate_text)
  if candidate_rep < 0.35 {
    return false
  }
  let candidate_numeric = calculate_numeric_penalty(candidate_text)
  if candidate_numeric < 0.4 {
    return false
  }
  let main_nav_penalty = calculate_navigation_penalty(main, main_text)
  let main_link_density = calculate_link_density(main, main_text)
  let main_rep = calculate_repetition_penalty(main_text)
  if main_nav_penalty < 0.6 || main_link_density > 0.35 || main_rep < 0.4 {
    return true
  }
  false
}

///|
fn is_descendant(root : @aom.AccessibilityNode, target_id : String) -> Bool {
  if root.id == target_id {
    return true
  }
  for child in root.children {
    if is_descendant(child, target_id) {
      return true
    }
  }
  false
}

///|
fn select_readability_node(
  best_readability_block : ContentBlock?,
  best_readability_candidate : @aom.AccessibilityNode?,
  scores : Map[String, Double],
) -> @aom.AccessibilityNode? {
  match (best_readability_block, best_readability_candidate) {
    (None, None) => None
    (Some(block), None) => Some(block.node)
    (None, Some(candidate)) => Some(candidate)
    (Some(block), Some(candidate)) => {
      if block.node.id == candidate.id {
        return Some(candidate)
      }
      let block_score = get_readability_score(scores, block.node)
      let cand_score = get_readability_score(scores, candidate)
      if block_score > cand_score * 1.05 {
        Some(block.node)
      } else if cand_score > block_score * 1.05 {
        Some(candidate)
      } else {
        let block_len = get_text_content(block.node).length()
        let cand_len = get_text_content(candidate).length()
        if cand_len <= block_len {
          Some(candidate)
        } else {
          Some(block.node)
        }
      }
    }
  }
}

///|
fn should_prefer_smaller_container(
  main_len : Int,
  candidate_len : Int,
  main_readability : Double,
  candidate_readability : Double,
) -> Bool {
  if candidate_len == 0 {
    return false
  }
  let ratio = main_len.to_double() / candidate_len.to_double()
  if candidate_len < 600 &&
    ratio >= 6.0 &&
    candidate_readability >= main_readability {
    true
  } else if candidate_len < 1200 &&
    ratio >= 7.0 &&
    candidate_readability >= main_readability * 0.9 {
    true
  } else {
    false
  }
}
