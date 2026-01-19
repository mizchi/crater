///|
/// Largest Contentful Paint (LCP) Detection
/// https://web.dev/lcp/
///
/// LCP measures when the largest content element in the viewport
/// becomes visible. Used to determine when main content has loaded.

// =============================================================================
// LCP Element Types
// =============================================================================

///|
/// Types of elements that can be LCP candidates
/// Per spec: <img>, <image> inside <svg>, <video> poster,
/// element with background-image, text block elements
pub(all) enum LCPElementType {
  Image(src~ : String)
  BackgroundImage(url~ : String)
  Video(poster~ : String?)
  TextBlock
} derive(Show, Eq)

// =============================================================================
// LCP Candidate
// =============================================================================

///|
/// A candidate element for Largest Contentful Paint
pub(all) struct LCPCandidate {
  /// Element identifier (from HTML id or generated)
  element_id : String
  /// Type of LCP element
  element_type : LCPElementType
  /// Size in viewport (width * height in CSS pixels)
  size : Double
  /// Position in viewport
  x : Double
  y : Double
  width : Double
  height : Double
  /// Resource load state (for images/video)
  mut resource_loaded : Bool
  /// Render time (when element became visible)
  mut render_time : Double?
  /// Load time (when resource finished loading, for images)
  mut load_time : Double?
}

///|
pub fn LCPCandidate::new(
  element_id : String,
  element_type : LCPElementType,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> LCPCandidate {
  {
    element_id,
    element_type,
    size: width * height,
    x,
    y,
    width,
    height,
    resource_loaded: false,
    render_time: None,
    load_time: None,
  }
}

///|
pub fn LCPCandidate::with_resource_loaded(
  self : LCPCandidate,
  loaded : Bool,
) -> LCPCandidate {
  { ..self, resource_loaded: loaded }
}

///|
pub fn LCPCandidate::with_render_time(
  self : LCPCandidate,
  time : Double,
) -> LCPCandidate {
  { ..self, render_time: Some(time) }
}

///|
pub fn LCPCandidate::with_load_time(
  self : LCPCandidate,
  time : Double,
) -> LCPCandidate {
  { ..self, load_time: Some(time) }
}

///|
/// Check if this candidate is fully rendered (resource loaded if applicable)
pub fn LCPCandidate::is_rendered(self : LCPCandidate) -> Bool {
  match self.element_type {
    TextBlock => self.render_time is Some(_)
    Image(_) | BackgroundImage(_) | Video(_) =>
      self.resource_loaded && self.render_time is Some(_)
  }
}

///|
/// Get the LCP time (load_time for images, render_time for text)
pub fn LCPCandidate::get_lcp_time(self : LCPCandidate) -> Double? {
  match self.element_type {
    TextBlock => self.render_time
    Image(_) | BackgroundImage(_) | Video(_) =>
      // LCP time is max(render_time, load_time) for images
      match (self.render_time, self.load_time) {
        (Some(r), Some(l)) => Some(if r > l { r } else { l })
        (Some(r), None) => Some(r)
        (None, Some(l)) => Some(l)
        (None, None) => None
      }
  }
}

// =============================================================================
// LCP Tracker
// =============================================================================

///|
/// Tracks LCP candidates and determines the final LCP element
pub(all) struct LCPTracker {
  /// All candidates discovered so far
  candidates : Array[LCPCandidate]
  /// Current LCP (largest rendered candidate)
  mut current_lcp : LCPCandidate?
  /// Whether LCP is finalized (user input occurred)
  mut finalized : Bool
  /// Viewport dimensions for size calculation
  viewport_width : Double
  viewport_height : Double
}

///|
pub fn LCPTracker::new(
  viewport_width : Double,
  viewport_height : Double,
) -> LCPTracker {
  {
    candidates: [],
    current_lcp: None,
    finalized: false,
    viewport_width,
    viewport_height,
  }
}

///|
/// Add a new LCP candidate
pub fn LCPTracker::add_candidate(
  self : LCPTracker,
  candidate : LCPCandidate,
) -> Unit {
  if self.finalized {
    return // No more candidates after user input
  }

  // Only consider elements in viewport
  if not(self.is_in_viewport(candidate)) {
    return
  }
  self.candidates.push(candidate)
  self.update_current_lcp()
}

///|
/// Update resource load status for an element
pub fn LCPTracker::on_resource_loaded(
  self : LCPTracker,
  element_id : String,
  load_time : Double,
) -> Unit {
  if self.finalized {
    return
  }
  for candidate in self.candidates {
    if candidate.element_id == element_id {
      candidate.resource_loaded = true
      candidate.load_time = Some(load_time)
    }
  }
  self.update_current_lcp()
}

///|
/// Update render time for an element
pub fn LCPTracker::on_element_rendered(
  self : LCPTracker,
  element_id : String,
  render_time : Double,
) -> Unit {
  if self.finalized {
    return
  }
  for candidate in self.candidates {
    if candidate.element_id == element_id {
      candidate.render_time = Some(render_time)
    }
  }
  self.update_current_lcp()
}

///|
/// Finalize LCP (called on first user input)
pub fn LCPTracker::finalize(self : LCPTracker) -> Unit {
  self.finalized = true
}

///|
/// Get the current LCP candidate
pub fn LCPTracker::get_lcp(self : LCPTracker) -> LCPCandidate? {
  self.current_lcp
}

///|
/// Get LCP time in milliseconds
pub fn LCPTracker::get_lcp_time(self : LCPTracker) -> Double? {
  match self.current_lcp {
    Some(candidate) => candidate.get_lcp_time()
    None => None
  }
}

///|
/// Check if LCP is ready (largest element fully rendered)
pub fn LCPTracker::is_lcp_ready(self : LCPTracker) -> Bool {
  match self.current_lcp {
    Some(candidate) => candidate.is_rendered()
    None => false
  }
}

///|
/// Check if LCP is finalized
pub fn LCPTracker::is_finalized(self : LCPTracker) -> Bool {
  self.finalized
}

///|
fn LCPTracker::is_in_viewport(
  self : LCPTracker,
  candidate : LCPCandidate,
) -> Bool {
  // Check if any part of the element is in viewport
  candidate.x < self.viewport_width &&
  candidate.y < self.viewport_height &&
  candidate.x + candidate.width > 0.0 &&
  candidate.y + candidate.height > 0.0
}

///|
fn LCPTracker::update_current_lcp(self : LCPTracker) -> Unit {
  let mut largest : LCPCandidate? = None
  let mut largest_size = 0.0
  for candidate in self.candidates {
    // Only consider rendered candidates
    if candidate.is_rendered() && candidate.size > largest_size {
      largest_size = candidate.size
      largest = Some(candidate)
    }
  }

  // Also consider unrendered candidates if no rendered ones yet
  if largest is None {
    for candidate in self.candidates {
      if candidate.size > largest_size {
        largest_size = candidate.size
        largest = Some(candidate)
      }
    }
  }
  self.current_lcp = largest
}

// =============================================================================
// LCP Candidate Detection from Layout
// =============================================================================

///|
/// Extract LCP candidates from a LayoutTree
pub fn extract_lcp_candidates(
  layout : @tree.LayoutTree,
  viewport_width : Double,
  viewport_height : Double,
) -> Array[LCPCandidate] {
  let candidates : Array[LCPCandidate] = []
  extract_candidates_recursive(
    layout.root,
    candidates,
    viewport_width,
    viewport_height,
  )
  candidates
}

///|
fn extract_candidates_recursive(
  node : @tree.LayoutNode,
  candidates : Array[LCPCandidate],
  viewport_width : Double,
  viewport_height : Double,
) -> Unit {
  let x = node.computed_x
  let y = node.computed_y
  let width = node.computed_width
  let height = node.computed_height

  // Skip if completely outside viewport
  if x >= viewport_width ||
    y >= viewport_height ||
    x + width <= 0.0 ||
    y + height <= 0.0 {
    // Still check children as they might be positioned differently
    for child in node.children {
      extract_candidates_recursive(
        child, candidates, viewport_width, viewport_height,
      )
    }
    return
  }

  // Check if this node is an LCP candidate
  match classify_lcp_element(node) {
    Some(element_type) => {
      let candidate = LCPCandidate::new(
        node.uid.to_string(),
        element_type,
        x,
        y,
        width,
        height,
      )
      // Text blocks are immediately "loaded"
      let candidate = match element_type {
        TextBlock => candidate.with_resource_loaded(true)
        _ => candidate
      }
      candidates.push(candidate)
    }
    None => ()
  }

  // Recurse into children
  for child in node.children {
    extract_candidates_recursive(
      child, candidates, viewport_width, viewport_height,
    )
  }
}

///|
/// Classify a layout node as an LCP element type (if applicable)
fn classify_lcp_element(node : @tree.LayoutNode) -> LCPElementType? {
  // Check for image elements (nodes with intrinsic state)
  match node.intrinsic_state {
    Some(state) =>
      match state {
        @tree.Pending(_) | @tree.Resolved(_) =>
          // This is an image/resource node
          return Some(Image(src=node.uid.to_string()))
        @tree.Error => return None
      }
    None => ()
  }

  // Check node type for text blocks
  // Large text blocks (paragraphs, headings) are LCP candidates
  // Minimum size threshold: 10x10 pixels
  let width = node.computed_width
  let height = node.computed_height
  if width >= 10.0 && height >= 10.0 {
    // If it has no children and has text content, it's likely a text node
    if node.children.is_empty() && node.text is Some(_) {
      return Some(TextBlock)
    }
  }
  None
}

// =============================================================================
// Content Readiness
// =============================================================================

///|
/// Overall content readiness state
pub(all) struct ContentReadiness {
  /// LCP element is fully rendered
  lcp_ready : Bool
  /// LCP time in milliseconds (if available)
  lcp_time : Double?
  /// All critical resources loaded
  critical_resources_loaded : Bool
  /// Accessibility tree is built
  a11y_ready : Bool
}

///|
pub fn ContentReadiness::new() -> ContentReadiness {
  {
    lcp_ready: false,
    lcp_time: None,
    critical_resources_loaded: false,
    a11y_ready: false,
  }
}

///|
/// Check if content is ready for interaction
pub fn ContentReadiness::is_interaction_ready(self : ContentReadiness) -> Bool {
  self.lcp_ready && self.a11y_ready
}

///|
/// Create readiness state from LCP tracker
pub fn ContentReadiness::from_lcp_tracker(
  tracker : LCPTracker,
  a11y_ready : Bool,
) -> ContentReadiness {
  {
    lcp_ready: tracker.is_lcp_ready(),
    lcp_time: tracker.get_lcp_time(),
    critical_resources_loaded: tracker.is_lcp_ready(),
    a11y_ready,
  }
}
