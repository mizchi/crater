///|
/// Focus Management for Tab/Shift+Tab Navigation
/// Implements standard HTML focus navigation order

// =============================================================================
// Types
// =============================================================================

///|
/// Represents a focusable item in the tab order
pub(all) struct FocusableItem {
  // Reference to the accessibility node
  node : AccessibilityNode
  // Document order index (for sorting)
  document_order : Int
  // Effective tabindex for sorting (0 for inherently focusable, actual value otherwise)
  effective_tabindex : Int
}

///|
/// Focus manager for handling Tab/Shift+Tab navigation
pub(all) struct FocusManager {
  // The accessibility tree
  tree : AccessibilityTree
  // Computed tab order (cached)
  tab_order : Array[FocusableItem]
  // Current focus index in tab_order (-1 if no focus)
  mut current_index : Int
}

// =============================================================================
// Tab Order Computation
// =============================================================================

///|
/// Compute the tab order for an accessibility tree
/// Returns focusable items sorted by tab order:
/// 1. Elements with tabindex > 0, sorted by tabindex value (ascending)
/// 2. Elements with tabindex = 0 or implicit focusable, in document order
/// 3. Elements with tabindex < 0 are excluded (not tabbable)
pub fn compute_tab_order(tree : AccessibilityTree) -> Array[FocusableItem] {
  let items : Array[FocusableItem] = []

  // Collect all focusable items in document order
  let _ = collect_focusable_items(tree.root, items, 0)

  // Filter out items with tabindex < 0 (not tabbable)
  let tabbable : Array[FocusableItem] = []
  for item in items {
    // tabindex < 0 means not tabbable (programmatic focus only)
    if item.effective_tabindex >= 0 {
      tabbable.push(item)
    }
  }

  // Sort by tab order:
  // 1. Items with tabindex > 0 come first, sorted by tabindex value
  // 2. Items with tabindex = 0 (or implicit) come after, in document order
  sort_tab_order(tabbable)
  tabbable
}

///|
/// Collect focusable items recursively in document order
fn collect_focusable_items(
  node : AccessibilityNode,
  items : Array[FocusableItem],
  doc_order : Int,
) -> Int {
  let mut current_order = doc_order

  // Check if this node is focusable
  if node.focusable {
    // Determine effective tabindex
    let effective_tabindex = match node.tabindex {
      Some(idx) => idx
      // No explicit tabindex but focusable = implicit tabindex 0
      None => 0
    }
    items.push({ node, document_order: current_order, effective_tabindex })
    current_order += 1
  }

  // Recurse into children
  for child in node.children {
    current_order = collect_focusable_items(child, items, current_order)
  }
  current_order
}

///|
/// Sort items by tab order (stable sort)
/// Items with tabindex > 0 come first (sorted by value)
/// Items with tabindex = 0 come after (in document order)
fn sort_tab_order(items : Array[FocusableItem]) -> Unit {
  // Simple insertion sort (stable)
  for i = 1; i < items.length(); i = i + 1 {
    let current = items[i]
    let mut j = i - 1
    while j >= 0 && should_come_after(items[j], current) {
      items[j + 1] = items[j]
      j -= 1
    }
    items[j + 1] = current
  }
}

///|
/// Compare function for tab order
/// Returns true if 'a' should come after 'b' in tab order
fn should_come_after(a : FocusableItem, b : FocusableItem) -> Bool {
  let a_positive = a.effective_tabindex > 0
  let b_positive = b.effective_tabindex > 0
  if a_positive && b_positive {
    // Both positive: lower tabindex comes first
    // If equal, earlier document order comes first
    if a.effective_tabindex == b.effective_tabindex {
      a.document_order > b.document_order
    } else {
      a.effective_tabindex > b.effective_tabindex
    }
  } else if a_positive && not(b_positive) {
    // Positive tabindex comes before zero tabindex
    false
  } else if not(a_positive) && b_positive {
    // Zero tabindex comes after positive tabindex
    true
  } else {
    // Both zero: document order
    a.document_order > b.document_order
  }
}

// =============================================================================
// Focus Manager
// =============================================================================

///|
/// Create a new FocusManager for an accessibility tree
pub fn FocusManager::new(tree : AccessibilityTree) -> FocusManager {
  let tab_order = compute_tab_order(tree)
  { tree, tab_order, current_index: -1 }
}

///|
/// Get the currently focused node, if any
pub fn FocusManager::current(self : FocusManager) -> AccessibilityNode? {
  if self.current_index >= 0 && self.current_index < self.tab_order.length() {
    Some(self.tab_order[self.current_index].node)
  } else {
    None
  }
}

///|
/// Get the currently focused node id, if any
pub fn FocusManager::current_id(self : FocusManager) -> String? {
  match self.current() {
    Some(node) => Some(node.id)
    None => None
  }
}

///|
/// Move focus to the next focusable element (Tab)
/// Returns the newly focused node, or None if no focusable elements
pub fn FocusManager::focus_next(self : FocusManager) -> AccessibilityNode? {
  if self.tab_order.is_empty() {
    return None
  }

  // Move to next, wrap around
  self.current_index = (self.current_index + 1) % self.tab_order.length()
  Some(self.tab_order[self.current_index].node)
}

///|
/// Move focus to the previous focusable element (Shift+Tab)
/// Returns the newly focused node, or None if no focusable elements
pub fn FocusManager::focus_prev(self : FocusManager) -> AccessibilityNode? {
  if self.tab_order.is_empty() {
    return None
  }

  // Move to previous, wrap around
  if self.current_index <= 0 {
    self.current_index = self.tab_order.length() - 1
  } else {
    self.current_index -= 1
  }
  Some(self.tab_order[self.current_index].node)
}

///|
/// Focus a specific node by id
/// Returns true if focus was set, false if node not found or not focusable
pub fn FocusManager::focus_by_id(self : FocusManager, id : String) -> Bool {
  for i, item in self.tab_order {
    if item.node.id == id {
      self.current_index = i
      return true
    }
  }
  false
}

///|
/// Focus a specific node by source element id
/// Returns true if focus was set, false if not found
pub fn FocusManager::focus_by_source_id(
  self : FocusManager,
  source_id : String,
) -> Bool {
  for i, item in self.tab_order {
    match item.node.source_id {
      Some(sid) if sid == source_id => {
        self.current_index = i
        return true
      }
      _ => continue
    }
  }
  false
}

///|
/// Clear focus
pub fn FocusManager::blur(self : FocusManager) -> Unit {
  self.current_index = -1
}

///|
/// Check if there is currently a focused element
pub fn FocusManager::has_focus(self : FocusManager) -> Bool {
  self.current_index >= 0 && self.current_index < self.tab_order.length()
}

///|
/// Get the number of focusable elements
pub fn FocusManager::focusable_count(self : FocusManager) -> Int {
  self.tab_order.length()
}

///|
/// Get all focusable items in tab order
pub fn FocusManager::get_tab_order(self : FocusManager) -> Array[FocusableItem] {
  self.tab_order
}

///|
/// Reset focus to the first focusable element
/// Returns the focused node, or None if no focusable elements
pub fn FocusManager::focus_first(self : FocusManager) -> AccessibilityNode? {
  if self.tab_order.is_empty() {
    self.current_index = -1
    return None
  }
  self.current_index = 0
  Some(self.tab_order[0].node)
}

///|
/// Focus the last focusable element
/// Returns the focused node, or None if no focusable elements
pub fn FocusManager::focus_last(self : FocusManager) -> AccessibilityNode? {
  if self.tab_order.is_empty() {
    self.current_index = -1
    return None
  }
  self.current_index = self.tab_order.length() - 1
  Some(self.tab_order[self.current_index].node)
}

// =============================================================================
// Convenience Functions
// =============================================================================

///|
/// Get tab order node IDs as a simple array of strings
/// Useful for debugging and testing
pub fn get_tab_order_ids(tree : AccessibilityTree) -> Array[String] {
  let order = compute_tab_order(tree)
  let ids : Array[String] = []
  for item in order {
    ids.push(item.node.id)
  }
  ids
}

///|
/// Get tab order with names for debugging
pub fn get_tab_order_info(
  tree : AccessibilityTree,
) -> Array[(String, String?, Role)] {
  let order = compute_tab_order(tree)
  let info : Array[(String, String?, Role)] = []
  for item in order {
    info.push((item.node.id, item.node.name, item.node.role))
  }
  info
}
