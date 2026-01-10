///|
/// Structural Diff for Accessibility Trees
/// Lightweight visual regression without screenshots

// =============================================================================
// Types
// =============================================================================

///|
/// Type of change detected
pub(all) enum ChangeType {
  Added
  Removed
  Moved
  Resized
  RoleChanged
  NameChanged
  StateChanged
}

///|
/// A single difference between two trees
pub(all) struct Difference {
  change_type : ChangeType
  /// Path to the element (e.g., "root > main > article")
  path : String
  /// Element identifier (ref_id or source_id)
  element_id : String
  /// Description of the change
  description : String
  /// Severity: 0 = info, 1 = minor, 2 = major, 3 = breaking
  severity : Int
}

///|
/// Complete diff result
pub(all) struct DiffResult {
  differences : Array[Difference]
  added_count : Int
  removed_count : Int
  changed_count : Int
  /// Overall similarity score (0.0 - 1.0)
  similarity : Double
}

///|
/// Configuration for diff sensitivity
pub(all) struct DiffConfig {
  /// Position change threshold in pixels
  position_threshold : Double
  /// Size change threshold in pixels
  size_threshold : Double
  /// Ignore non-visible elements
  ignore_invisible : Bool
  /// Ignore generic elements without names
  ignore_anonymous_generic : Bool
}

///|
pub fn DiffConfig::default() -> DiffConfig {
  {
    position_threshold: 5.0,
    size_threshold: 3.0,
    ignore_invisible: true,
    ignore_anonymous_generic: true,
  }
}

///|
pub fn DiffConfig::strict() -> DiffConfig {
  {
    position_threshold: 1.0,
    size_threshold: 1.0,
    ignore_invisible: false,
    ignore_anonymous_generic: false,
  }
}

// =============================================================================
// Main API
// =============================================================================

///|
/// Compare two accessibility trees and return differences
pub fn diff_trees(
  before : @aom.AccessibilityTree,
  after : @aom.AccessibilityTree,
  config : DiffConfig,
) -> DiffResult {
  let differences : Array[Difference] = []

  // Build maps of elements by ID for comparison
  let before_map = build_element_map(before.root, config)
  let after_map = build_element_map(after.root, config)

  // Find removed elements
  for id, before_elem in before_map {
    match after_map.get(id) {
      None =>
        differences.push({
          change_type: Removed,
          path: before_elem.path,
          element_id: id,
          description: "Element removed: \{before_elem.role}",
          severity: 2,
        })
      Some(after_elem) =>
        // Compare elements
        compare_elements(before_elem, after_elem, config, differences)
    }
  }

  // Find added elements
  for id, after_elem in after_map {
    match before_map.get(id) {
      None =>
        differences.push({
          change_type: Added,
          path: after_elem.path,
          element_id: id,
          description: "Element added: \{after_elem.role}",
          severity: 1,
        })
      Some(_) => () // Already handled in comparison
    }
  }

  // Calculate statistics
  let mut added = 0
  let mut removed = 0
  let mut changed = 0
  for diff in differences {
    match diff.change_type {
      Added => added = added + 1
      Removed => removed = removed + 1
      _ => changed = changed + 1
    }
  }

  // Calculate similarity
  let total_elements = before_map.length() + after_map.length()
  let unchanged = total_elements - differences.length()
  let similarity = if total_elements > 0 {
    unchanged.to_double() / total_elements.to_double()
  } else {
    1.0
  }
  {
    differences,
    added_count: added,
    removed_count: removed,
    changed_count: changed,
    similarity,
  }
}

///|
/// Quick check if two trees are structurally equivalent
pub fn trees_equal(
  before : @aom.AccessibilityTree,
  after : @aom.AccessibilityTree,
) -> Bool {
  let result = diff_trees(before, after, DiffConfig::default())
  result.differences.length() == 0
}

///|
/// Get a summary of differences
pub fn diff_summary(
  before : @aom.AccessibilityTree,
  after : @aom.AccessibilityTree,
) -> String {
  let result = diff_trees(before, after, DiffConfig::default())
  result.to_summary()
}

// =============================================================================
// Element Mapping
// =============================================================================

///|
priv struct ElementSnapshot {
  id : String
  path : String
  role : String
  name : String?
  bounds : @aom.Bounds?
  states : Array[@aom.State]
  visible : Bool
}

///|
fn build_element_map(
  root : @aom.AccessibilityNode,
  config : DiffConfig,
) -> Map[String, ElementSnapshot] {
  let map : Map[String, ElementSnapshot] = {}
  collect_elements(root, "", config, map)
  map
}

///|
fn collect_elements(
  node : @aom.AccessibilityNode,
  parent_path : String,
  config : DiffConfig,
  map : Map[String, ElementSnapshot],
) -> Unit {
  // Skip invisible if configured
  if config.ignore_invisible && not(node.visible) {
    return
  }

  // Skip anonymous generic if configured
  if config.ignore_anonymous_generic {
    if node.role == @aom.Generic && node.name is None && node.ref_id is None {
      // Still recurse into children
      for child in node.children {
        collect_elements(child, parent_path, config, map)
      }
      return
    }
  }

  // Build path
  let path = if parent_path.is_empty() {
    node.role.to_string()
  } else {
    parent_path + " > " + node.role.to_string()
  }

  // Get element ID (prefer ref_id, fall back to source_id or generated)
  let id = match node.ref_id {
    Some(ref_id) => ref_id
    None =>
      match node.source_id {
        Some(src_id) => src_id
        None => node.id
      }
  }

  // Create snapshot
  let snapshot : ElementSnapshot = {
    id,
    path,
    role: node.role.to_string(),
    name: node.name,
    bounds: node.bounds,
    states: node.states,
    visible: node.visible,
  }
  map[id] = snapshot

  // Recurse
  for child in node.children {
    collect_elements(child, path, config, map)
  }
}

// =============================================================================
// Element Comparison
// =============================================================================

///|
fn compare_elements(
  before : ElementSnapshot,
  after : ElementSnapshot,
  config : DiffConfig,
  diffs : Array[Difference],
) -> Unit {
  // Role changed
  if before.role != after.role {
    diffs.push({
      change_type: RoleChanged,
      path: after.path,
      element_id: after.id,
      description: "Role changed: \{before.role} -> \{after.role}",
      severity: 2,
    })
  }

  // Name changed
  match (before.name, after.name) {
    (Some(b), Some(a)) if b != a =>
      diffs.push({
        change_type: NameChanged,
        path: after.path,
        element_id: after.id,
        description: "Name changed: \"\{b}\" -> \"\{a}\"",
        severity: 1,
      })
    (Some(b), None) =>
      diffs.push({
        change_type: NameChanged,
        path: after.path,
        element_id: after.id,
        description: "Name removed: \"\{b}\"",
        severity: 1,
      })
    (None, Some(a)) =>
      diffs.push({
        change_type: NameChanged,
        path: after.path,
        element_id: after.id,
        description: "Name added: \"\{a}\"",
        severity: 0,
      })
    _ => ()
  }

  // Bounds changed
  match (before.bounds, after.bounds) {
    (Some(b_bounds), Some(a_bounds)) =>
      compare_bounds(before.id, after.path, b_bounds, a_bounds, config, diffs)
    _ => ()
  }

  // States changed
  if not(states_equal(before.states, after.states)) {
    let before_str = states_to_string(before.states)
    let after_str = states_to_string(after.states)
    diffs.push({
      change_type: StateChanged,
      path: after.path,
      element_id: after.id,
      description: "States changed: [\{before_str}] -> [\{after_str}]",
      severity: 1,
    })
  }
}

///|
fn compare_bounds(
  id : String,
  path : String,
  before : @aom.Bounds,
  after : @aom.Bounds,
  config : DiffConfig,
  diffs : Array[Difference],
) -> Unit {
  let dx = (after.x - before.x).abs()
  let dy = (after.y - before.y).abs()
  let dw = (after.width - before.width).abs()
  let dh = (after.height - before.height).abs()

  // Position changed
  if dx > config.position_threshold || dy > config.position_threshold {
    diffs.push({
      change_type: Moved,
      path,
      element_id: id,
      description: "Moved: (\{before.x}, \{before.y}) -> (\{after.x}, \{after.y})",
      severity: 1,
    })
  }

  // Size changed
  if dw > config.size_threshold || dh > config.size_threshold {
    diffs.push({
      change_type: Resized,
      path,
      element_id: id,
      description: "Resized: \{before.width}x\{before.height} -> \{after.width}x\{after.height}",
      severity: 1,
    })
  }
}

///|
fn states_equal(a : Array[@aom.State], b : Array[@aom.State]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for state in a {
    if not(array_contains_state(b, state)) {
      return false
    }
  }
  true
}

///|
fn array_contains_state(arr : Array[@aom.State], state : @aom.State) -> Bool {
  for s in arr {
    if s == state {
      return true
    }
  }
  false
}

///|
fn states_to_string(states : Array[@aom.State]) -> String {
  let parts : Array[String] = []
  for state in states {
    parts.push(state.to_string())
  }
  parts
  .iter()
  .fold(init="", fn(acc, s) { if acc.is_empty() { s } else { acc + ", " + s } })
}

// =============================================================================
// Output
// =============================================================================

///|
pub fn Difference::to_string(self : Difference) -> String {
  let severity_str = match self.severity {
    0 => "INFO"
    1 => "MINOR"
    2 => "MAJOR"
    _ => "BREAKING"
  }
  let change_str = match self.change_type {
    Added => "ADDED"
    Removed => "REMOVED"
    Moved => "MOVED"
    Resized => "RESIZED"
    RoleChanged => "ROLE_CHANGED"
    NameChanged => "NAME_CHANGED"
    StateChanged => "STATE_CHANGED"
  }
  "[\{severity_str}] \{change_str}: \{self.description} (at \{self.path})"
}

///|
pub fn DiffResult::to_summary(self : DiffResult) -> String {
  let buf = StringBuilder::new()
  buf.write_string("=== Structural Diff Result ===\n")
  buf.write_string("Similarity: ")
  buf.write_string((self.similarity * 100.0).to_string())
  buf.write_string("%\n")
  buf.write_string("Added: ")
  buf.write_string(self.added_count.to_string())
  buf.write_string(", Removed: ")
  buf.write_string(self.removed_count.to_string())
  buf.write_string(", Changed: ")
  buf.write_string(self.changed_count.to_string())
  buf.write_string("\n\nDifferences:\n")
  if self.differences.length() == 0 {
    buf.write_string("  (no differences)\n")
  } else {
    for diff in self.differences {
      buf.write_string("  ")
      buf.write_string(diff.to_string())
      buf.write_string("\n")
    }
  }
  buf.to_string()
}

///|
pub fn DiffResult::to_json(self : DiffResult) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\n")
  buf.write_string("  \"similarity\": ")
  buf.write_string(self.similarity.to_string())
  buf.write_string(",\n")
  buf.write_string("  \"added\": ")
  buf.write_string(self.added_count.to_string())
  buf.write_string(",\n")
  buf.write_string("  \"removed\": ")
  buf.write_string(self.removed_count.to_string())
  buf.write_string(",\n")
  buf.write_string("  \"changed\": ")
  buf.write_string(self.changed_count.to_string())
  buf.write_string(",\n")
  buf.write_string("  \"differences\": [\n")
  for i, diff in self.differences {
    if i > 0 {
      buf.write_string(",\n")
    }
    buf.write_string("    { \"type\": \"")
    buf.write_string(change_type_string(diff.change_type))
    buf.write_string("\", \"path\": \"")
    buf.write_string(escape_json(diff.path))
    buf.write_string("\", \"id\": \"")
    buf.write_string(escape_json(diff.element_id))
    buf.write_string("\", \"description\": \"")
    buf.write_string(escape_json(diff.description))
    buf.write_string("\", \"severity\": ")
    buf.write_string(diff.severity.to_string())
    buf.write_string(" }")
  }
  buf.write_string("\n  ]\n}")
  buf.to_string()
}

///|
fn change_type_string(ct : ChangeType) -> String {
  match ct {
    Added => "added"
    Removed => "removed"
    Moved => "moved"
    Resized => "resized"
    RoleChanged => "role_changed"
    NameChanged => "name_changed"
    StateChanged => "state_changed"
  }
}

///|
fn escape_json(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}
