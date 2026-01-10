///|
/// Visual Grounding for AI Agents
/// Translates spatial references to elements using layout coordinates

// =============================================================================
// Types
// =============================================================================

///|
/// Spatial region on the viewport
pub(all) enum SpatialRegion {
  TopLeft
  TopCenter
  TopRight
  MiddleLeft
  Center
  MiddleRight
  BottomLeft
  BottomCenter
  BottomRight
}

///|
/// Spatial relation between elements
pub(all) enum SpatialRelation {
  Above
  Below
  LeftOf
  RightOf
  Inside
  Near
}

///|
/// Query for finding elements by spatial description
pub(all) enum SpatialQuery {
  /// Find elements in a specific region (e.g., "top right")
  InRegion(SpatialRegion)
  /// Find elements relative to another element (e.g., "below the form")
  RelativeTo(SpatialRelation, String) // relation, ref_id or role
  /// Find the nearest element to a point
  NearestTo(Double, Double)
  /// Find elements by role in a region
  RoleInRegion(@aom.Role, SpatialRegion)
}

///|
/// Result of a grounding query
pub(all) struct GroundingResult {
  node : @aom.AccessibilityNode
  /// Distance from query target (lower is better)
  distance : Double
  /// Click coordinates (center of element)
  click_x : Double
  click_y : Double
}

///|
/// Viewport configuration
pub(all) struct Viewport {
  width : Double
  height : Double
}

///|
pub fn Viewport::default() -> Viewport {
  { width: 1280.0, height: 800.0 }
}

// =============================================================================
// Main API
// =============================================================================

///|
/// Find elements matching a spatial query
pub fn find_by_spatial(
  tree : @aom.AccessibilityTree,
  query : SpatialQuery,
  viewport : Viewport,
) -> Array[GroundingResult] {
  match query {
    InRegion(region) => find_in_region(tree, region, viewport)
    RelativeTo(relation, ref_id) => find_relative(tree, relation, ref_id)
    NearestTo(x, y) => find_nearest(tree, x, y)
    RoleInRegion(role, region) =>
      find_role_in_region(tree, role, region, viewport)
  }
}

///|
/// Find the best element for a spatial query
pub fn find_best(
  tree : @aom.AccessibilityTree,
  query : SpatialQuery,
  viewport : Viewport,
) -> GroundingResult? {
  let results = find_by_spatial(tree, query, viewport)
  if results.length() > 0 {
    Some(results[0])
  } else {
    None
  }
}

///|
/// Get click coordinates for an element by ref_id
pub fn get_click_coords(
  tree : @aom.AccessibilityTree,
  ref_id : String,
) -> (Double, Double)? {
  find_by_ref_id(tree.root, ref_id).map(fn(node) { get_element_center(node) })
}

///|
/// Find element by ref_id
fn find_by_ref_id(
  node : @aom.AccessibilityNode,
  ref_id : String,
) -> @aom.AccessibilityNode? {
  match node.ref_id {
    Some(id) if id == ref_id => return Some(node)
    _ => ()
  }
  for child in node.children {
    match find_by_ref_id(child, ref_id) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

// =============================================================================
// Region-based Search
// =============================================================================

///|
fn find_in_region(
  tree : @aom.AccessibilityTree,
  region : SpatialRegion,
  viewport : Viewport,
) -> Array[GroundingResult] {
  let results : Array[GroundingResult] = []
  let (target_x, target_y) = region_center(region, viewport)
  collect_in_region(tree.root, region, viewport, target_x, target_y, results)

  // Sort by distance to region center
  results.sort_by(fn(a, b) { a.distance.compare(b.distance) })
  results
}

///|
fn region_center(
  region : SpatialRegion,
  viewport : Viewport,
) -> (Double, Double) {
  let third_w = viewport.width / 3.0
  let third_h = viewport.height / 3.0
  match region {
    TopLeft => (third_w / 2.0, third_h / 2.0)
    TopCenter => (viewport.width / 2.0, third_h / 2.0)
    TopRight => (viewport.width - third_w / 2.0, third_h / 2.0)
    MiddleLeft => (third_w / 2.0, viewport.height / 2.0)
    Center => (viewport.width / 2.0, viewport.height / 2.0)
    MiddleRight => (viewport.width - third_w / 2.0, viewport.height / 2.0)
    BottomLeft => (third_w / 2.0, viewport.height - third_h / 2.0)
    BottomCenter => (viewport.width / 2.0, viewport.height - third_h / 2.0)
    BottomRight =>
      (viewport.width - third_w / 2.0, viewport.height - third_h / 2.0)
  }
}

///|
fn is_in_region(
  bounds : @aom.Bounds,
  region : SpatialRegion,
  viewport : Viewport,
) -> Bool {
  let center_x = bounds.x + bounds.width / 2.0
  let center_y = bounds.y + bounds.height / 2.0
  let third_w = viewport.width / 3.0
  let third_h = viewport.height / 3.0
  let (h_zone, v_zone) = match region {
    TopLeft => (0, 0)
    TopCenter => (1, 0)
    TopRight => (2, 0)
    MiddleLeft => (0, 1)
    Center => (1, 1)
    MiddleRight => (2, 1)
    BottomLeft => (0, 2)
    BottomCenter => (1, 2)
    BottomRight => (2, 2)
  }
  let actual_h = if center_x < third_w {
    0
  } else if center_x < third_w * 2.0 {
    1
  } else {
    2
  }
  let actual_v = if center_y < third_h {
    0
  } else if center_y < third_h * 2.0 {
    1
  } else {
    2
  }
  actual_h == h_zone && actual_v == v_zone
}

///|
fn collect_in_region(
  node : @aom.AccessibilityNode,
  region : SpatialRegion,
  viewport : Viewport,
  target_x : Double,
  target_y : Double,
  results : Array[GroundingResult],
) -> Unit {
  // Only consider focusable/interactive elements
  if node.focusable || is_interactive_role(node.role) {
    match node.bounds {
      Some(bounds) =>
        if is_in_region(bounds, region, viewport) {
          let (cx, cy) = get_element_center(node)
          let distance = calc_distance(cx, cy, target_x, target_y)
          results.push({ node, distance, click_x: cx, click_y: cy })
        }
      None => ()
    }
  }
  for child in node.children {
    collect_in_region(child, region, viewport, target_x, target_y, results)
  }
}

// =============================================================================
// Relative Search
// =============================================================================

///|
fn find_relative(
  tree : @aom.AccessibilityTree,
  relation : SpatialRelation,
  ref_id : String,
) -> Array[GroundingResult] {
  let results : Array[GroundingResult] = []

  // Find the reference element
  let anchor = find_by_ref_id(tree.root, ref_id)
  match anchor {
    Some(anchor_node) =>
      match anchor_node.bounds {
        Some(anchor_bounds) => {
          collect_relative(tree.root, relation, anchor_bounds, results)
          results.sort_by(fn(a, b) { a.distance.compare(b.distance) })
        }
        None => ()
      }
    None => ()
  }
  results
}

///|
fn collect_relative(
  node : @aom.AccessibilityNode,
  relation : SpatialRelation,
  anchor : @aom.Bounds,
  results : Array[GroundingResult],
) -> Unit {
  if node.focusable || is_interactive_role(node.role) {
    match node.bounds {
      Some(bounds) =>
        if matches_relation(bounds, relation, anchor) {
          let (cx, cy) = get_element_center(node)
          let distance = calc_relation_distance(bounds, relation, anchor)
          results.push({ node, distance, click_x: cx, click_y: cy })
        }
      None => ()
    }
  }
  for child in node.children {
    collect_relative(child, relation, anchor, results)
  }
}

///|
fn matches_relation(
  bounds : @aom.Bounds,
  relation : SpatialRelation,
  anchor : @aom.Bounds,
) -> Bool {
  match relation {
    Above => bounds.y + bounds.height < anchor.y
    Below => bounds.y > anchor.y + anchor.height
    LeftOf => bounds.x + bounds.width < anchor.x
    RightOf => bounds.x > anchor.x + anchor.width
    Inside =>
      bounds.x >= anchor.x &&
      bounds.y >= anchor.y &&
      bounds.x + bounds.width <= anchor.x + anchor.width &&
      bounds.y + bounds.height <= anchor.y + anchor.height
    Near => {
      let distance = calc_element_distance(bounds, anchor)
      distance < 100.0 // Within 100px
    }
  }
}

///|
fn calc_relation_distance(
  bounds : @aom.Bounds,
  relation : SpatialRelation,
  anchor : @aom.Bounds,
) -> Double {
  match relation {
    Above => anchor.y - (bounds.y + bounds.height)
    Below => bounds.y - (anchor.y + anchor.height)
    LeftOf => anchor.x - (bounds.x + bounds.width)
    RightOf => bounds.x - (anchor.x + anchor.width)
    Inside | Near => calc_element_distance(bounds, anchor)
  }
}

// =============================================================================
// Nearest Search
// =============================================================================

///|
fn find_nearest(
  tree : @aom.AccessibilityTree,
  x : Double,
  y : Double,
) -> Array[GroundingResult] {
  let results : Array[GroundingResult] = []
  collect_nearest(tree.root, x, y, results)
  results.sort_by(fn(a, b) { a.distance.compare(b.distance) })
  results
}

///|
fn collect_nearest(
  node : @aom.AccessibilityNode,
  x : Double,
  y : Double,
  results : Array[GroundingResult],
) -> Unit {
  if node.focusable || is_interactive_role(node.role) {
    match node.bounds {
      Some(_) => {
        let (cx, cy) = get_element_center(node)
        let distance = calc_distance(cx, cy, x, y)
        results.push({ node, distance, click_x: cx, click_y: cy })
      }
      None => ()
    }
  }
  for child in node.children {
    collect_nearest(child, x, y, results)
  }
}

// =============================================================================
// Role + Region Search
// =============================================================================

///|
fn find_role_in_region(
  tree : @aom.AccessibilityTree,
  role : @aom.Role,
  region : SpatialRegion,
  viewport : Viewport,
) -> Array[GroundingResult] {
  let results : Array[GroundingResult] = []
  let (target_x, target_y) = region_center(region, viewport)
  collect_role_in_region(
    tree.root,
    role,
    region,
    viewport,
    target_x,
    target_y,
    results,
  )
  results.sort_by(fn(a, b) { a.distance.compare(b.distance) })
  results
}

///|
fn collect_role_in_region(
  node : @aom.AccessibilityNode,
  role : @aom.Role,
  region : SpatialRegion,
  viewport : Viewport,
  target_x : Double,
  target_y : Double,
  results : Array[GroundingResult],
) -> Unit {
  if node.role == role {
    match node.bounds {
      Some(bounds) =>
        if is_in_region(bounds, region, viewport) {
          let (cx, cy) = get_element_center(node)
          let distance = calc_distance(cx, cy, target_x, target_y)
          results.push({ node, distance, click_x: cx, click_y: cy })
        }
      None => ()
    }
  }
  for child in node.children {
    collect_role_in_region(
      child, role, region, viewport, target_x, target_y, results,
    )
  }
}

// =============================================================================
// Helpers
// =============================================================================

///|
fn is_interactive_role(role : @aom.Role) -> Bool {
  match role {
    @aom.Button
    | @aom.Link
    | @aom.Textbox
    | @aom.Checkbox
    | @aom.Radio
    | @aom.Combobox
    | @aom.Listbox
    | @aom.Slider
    | @aom.Switch
    | @aom.Tab
    | @aom.MenuItem
    | @aom.MenuItemCheckbox
    | @aom.MenuItemRadio
    | @aom.SpinButton
    | @aom.SearchBox => true
    _ => false
  }
}

///|
fn get_element_center(node : @aom.AccessibilityNode) -> (Double, Double) {
  match node.bounds {
    Some(bounds) =>
      (bounds.x + bounds.width / 2.0, bounds.y + bounds.height / 2.0)
    None => (0.0, 0.0)
  }
}

///|
fn calc_distance(x1 : Double, y1 : Double, x2 : Double, y2 : Double) -> Double {
  let dx = x2 - x1
  let dy = y2 - y1
  (dx * dx + dy * dy).sqrt()
}

///|
fn calc_element_distance(a : @aom.Bounds, b : @aom.Bounds) -> Double {
  let a_cx = a.x + a.width / 2.0
  let a_cy = a.y + a.height / 2.0
  let b_cx = b.x + b.width / 2.0
  let b_cy = b.y + b.height / 2.0
  calc_distance(a_cx, a_cy, b_cx, b_cy)
}

// =============================================================================
// Debug Output
// =============================================================================

///|
pub fn GroundingResult::to_string(self : GroundingResult) -> String {
  let role = self.node.role.to_string()
  let name = match self.node.name {
    Some(n) => n
    None => "(no name)"
  }
  let ref_id = match self.node.ref_id {
    Some(id) => id
    None => "(no ref)"
  }
  "GroundingResult { ref: \{ref_id}, role: \{role}, name: \{name}, click: (\{self.click_x}, \{self.click_y}), distance: \{self.distance} }"
}

///|
pub fn SpatialRegion::to_string(self : SpatialRegion) -> String {
  match self {
    TopLeft => "top-left"
    TopCenter => "top-center"
    TopRight => "top-right"
    MiddleLeft => "middle-left"
    Center => "center"
    MiddleRight => "middle-right"
    BottomLeft => "bottom-left"
    BottomCenter => "bottom-center"
    BottomRight => "bottom-right"
  }
}
