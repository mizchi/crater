///|
/// Accessibility Tree Builder
/// Constructs AccessibilityTree from HTML Document

// =============================================================================
// Tree Builder Context
// =============================================================================

///|
/// Context for building accessibility tree
priv struct TreeBuilderContext {
  // Element lookup by id (for aria-labelledby, etc.)
  element_map : Map[String, @html.Element]
  // Label elements indexed by 'for' attribute
  label_map : Map[String, @html.Element]
  // Current nesting level for sectioning content
  in_sectioning : Bool
  // Encapsulating label element (for label wrapping input)
  encapsulating_label : @html.Element?
  // UID counter for generating unique ids
  mut uid_counter : Int
}

///|
fn TreeBuilderContext::new() -> TreeBuilderContext {
  {
    element_map: {},
    label_map: {},
    in_sectioning: false,
    encapsulating_label: None,
    uid_counter: 0,
  }
}

///|
fn TreeBuilderContext::next_uid(self : TreeBuilderContext) -> String {
  let uid = self.uid_counter
  self.uid_counter += 1
  "aom-\{uid}"
}

///|
fn TreeBuilderContext::find_by_id(
  self : TreeBuilderContext,
  id : String,
) -> @html.Element? {
  self.element_map.get(id)
}

///|
fn TreeBuilderContext::with_sectioning(
  self : TreeBuilderContext,
  in_sectioning : Bool,
) -> TreeBuilderContext {
  { ..self, in_sectioning, }
}

///|
fn TreeBuilderContext::with_encapsulating_label(
  self : TreeBuilderContext,
  label : @html.Element?,
) -> TreeBuilderContext {
  { ..self, encapsulating_label: label }
}

// =============================================================================
// Main Entry Point
// =============================================================================

///|
/// Build an AccessibilityTree from an HTML Document
pub fn build_accessibility_tree(doc : @html.Document) -> AccessibilityTree {
  let ctx = TreeBuilderContext::new()

  // First pass: index all elements by id and collect labels
  index_elements(doc.root, ctx)

  // Second pass: build the accessibility tree
  let root_node = build_node(doc.root, ctx)
  AccessibilityTree::new(root_node)
}

///|
/// Build an AccessibilityTree from a single HTML Element
pub fn build_accessibility_tree_from_element(
  element : @html.Element,
) -> AccessibilityTree {
  let ctx = TreeBuilderContext::new()
  index_elements(element, ctx)
  let root_node = build_node(element, ctx)
  AccessibilityTree::new(root_node)
}

// =============================================================================
// Element Indexing (First Pass)
// =============================================================================

///|
/// Index all elements by id for cross-referencing
fn index_elements(element : @html.Element, ctx : TreeBuilderContext) -> Unit {
  // Index by id
  match element.id {
    Some(id) => ctx.element_map[id] = element
    Option::None => ()
  }

  // Index labels by 'for' attribute
  if element.tag.to_lower() == "label" {
    match element.attributes.get("for") {
      Some(for_id) => ctx.label_map[for_id] = element
      Option::None => ()
    }
  }

  // Recurse
  for child in element.children {
    match child {
      @html.Element(child_elem) => index_elements(child_elem, ctx)
      @html.Text(_) => ()
    }
  }
}

// =============================================================================
// Node Building (Second Pass)
// =============================================================================

///|
/// Build an AccessibilityNode from an HTML Element
fn build_node(
  element : @html.Element,
  ctx : TreeBuilderContext,
) -> AccessibilityNode {
  // Generate unique id
  let node_id = match element.id {
    Some(id) => id
    Option::None => ctx.next_uid()
  }

  // Compute role with context
  let role_context = RoleMappingContext::{
    parent_tag: Option::None,
    has_accessible_name: has_accessible_name_source(element),
    in_sectioning_content: ctx.in_sectioning,
  }
  let role = compute_role(element, role_context)

  // Skip elements that don't contribute to accessibility tree
  if should_skip_element(element, role) {
    // Return a generic container that just passes through children
    let children = build_children(element, ctx)
    if children.length() == 1 {
      return children[0]
    }
    return {
      id: node_id,
      role: Generic,
      name: Option::None,
      description: Option::None,
      level: Option::None,
      states: [],
      properties: {},
      bounds: Option::None,
      children,
      focusable: false,
      source_id: element.id,
    }
  }

  // Compute accessible name
  let find_by_id = fn(id : String) -> @html.Element? { ctx.find_by_id(id) }
  let find_label_for_id = fn(id : String) -> @html.Element? {
    ctx.label_map.get(id)
  }
  let name = compute_accessible_name_full(
    element,
    find_by_id,
    find_label_for_id,
    ctx.encapsulating_label,
  )

  // Compute accessible description
  let description = compute_accessible_description(element, find_by_id)

  // Compute heading level
  let level = get_heading_level(element)

  // Compute states
  let states = compute_states(element)

  // Check if focusable
  let focusable = is_focusable(element, role)

  // Build children (update sectioning context if needed)
  let new_ctx = if is_sectioning_content(element.tag) {
    ctx.with_sectioning(true)
  } else {
    ctx
  }
  let children = build_children(element, new_ctx)
  {
    id: node_id,
    role,
    name,
    description,
    level,
    states,
    properties: {},
    bounds: Option::None,
    children,
    focusable,
    source_id: element.id,
  }
}

///|
/// Build child nodes
fn build_children(
  element : @html.Element,
  ctx : TreeBuilderContext,
) -> Array[AccessibilityNode] {
  let children : Array[AccessibilityNode] = []

  // Check if this element is a label (for encapsulation tracking)
  let child_ctx = if element.tag.to_lower() == "label" {
    // If label has 'for' attribute that matches an element, use that association
    // Otherwise, it encapsulates its input
    match element.attributes.get("for") {
      Some(for_id) =>
        // Check if the 'for' attribute matches any element by id
        match ctx.element_map.get(for_id) {
          Some(_) => ctx // Has 'for' that matches an element id
          Option::None => ctx.with_encapsulating_label(Some(element)) // 'for' doesn't match
        }
      Option::None => ctx.with_encapsulating_label(Some(element))
    }
  } else {
    ctx
  }
  for child in element.children {
    match child {
      @html.Element(child_elem) => {
        let child_node = build_node(child_elem, child_ctx)
        // Don't add generic nodes with no name and no children
        if not(is_empty_generic(child_node)) {
          children.push(child_node)
        }
      }
      @html.Text(text) => {
        // Text nodes become static text
        let trimmed = text.trim().to_string()
        if not(trimmed.is_empty()) {
          let text_node = AccessibilityNode::{
            id: ctx.next_uid(),
            role: Generic,
            name: Some(trimmed),
            description: Option::None,
            level: Option::None,
            states: [],
            properties: {},
            bounds: Option::None,
            children: [],
            focusable: false,
            source_id: Option::None,
          }
          children.push(text_node)
        }
      }
    }
  }
  children
}

// =============================================================================
// Element Analysis Helpers
// =============================================================================

///|
/// Check if element has any source for accessible name
fn has_accessible_name_source(element : @html.Element) -> Bool {
  // aria-label
  match element.attributes.get("aria-label") {
    Some(label) if not(label.is_empty()) => return true
    _ => ()
  }

  // aria-labelledby
  match element.attributes.get("aria-labelledby") {
    Some(ids) if not(ids.is_empty()) => return true
    _ => ()
  }

  // title
  match element.attributes.get("title") {
    Some(title) if not(title.is_empty()) => return true
    _ => ()
  }
  false
}

///|
/// Check if element should be skipped in accessibility tree
fn should_skip_element(element : @html.Element, role : Role) -> Bool {
  let tag = element.tag.to_lower()

  // Skip script, style, template, head elements
  match tag {
    "script" | "style" | "template" | "head" | "meta" | "link" | "noscript" =>
      return true
    _ => ()
  }

  // Skip elements with role="presentation" or role="none"
  match role {
    Presentation | None => return true
    _ => ()
  }

  // Skip aria-hidden elements
  match element.attributes.get("aria-hidden") {
    Some("true") => return true
    _ => ()
  }

  // Skip hidden elements
  if element.attributes.contains("hidden") {
    return true
  }
  false
}

///|
/// Check if node is an empty generic that should be pruned
fn is_empty_generic(node : AccessibilityNode) -> Bool {
  match node.role {
    Generic =>
      node.name is None && node.children.is_empty() && not(node.focusable)
    _ => false
  }
}

///|
/// Compute states for an element
fn compute_states(element : @html.Element) -> Array[State] {
  let states : Array[State] = []

  // Disabled state
  if element.attributes.contains("disabled") {
    states.push(Disabled)
  }
  match element.attributes.get("aria-disabled") {
    Some("true") => states.push(Disabled)
    _ => ()
  }

  // Checked state
  if element.attributes.contains("checked") {
    states.push(Checked)
  }
  match element.attributes.get("aria-checked") {
    Some("true") => states.push(Checked)
    Some("mixed") => states.push(CheckedMixed)
    _ => ()
  }

  // Expanded state
  match element.attributes.get("aria-expanded") {
    Some("true") => states.push(Expanded)
    _ => ()
  }

  // Selected state
  if element.attributes.contains("selected") {
    states.push(Selected)
  }
  match element.attributes.get("aria-selected") {
    Some("true") => states.push(Selected)
    _ => ()
  }

  // Pressed state
  match element.attributes.get("aria-pressed") {
    Some("true") => states.push(Pressed)
    Some("mixed") => states.push(PressedMixed)
    _ => ()
  }

  // Hidden state
  match element.attributes.get("aria-hidden") {
    Some("true") => states.push(Hidden)
    _ => ()
  }

  // Busy state
  match element.attributes.get("aria-busy") {
    Some("true") => states.push(Busy)
    _ => ()
  }

  // Invalid state
  match element.attributes.get("aria-invalid") {
    Some("true") => states.push(Invalid)
    _ => ()
  }
  states
}

///|
/// Check if element is focusable
fn is_focusable(element : @html.Element, role : Role) -> Bool {
  // Check tabindex
  match element.attributes.get("tabindex") {
    Some(tabindex) => {
      let idx = @strconv.parse_int(tabindex) catch { _ => return false }
      if idx >= 0 {
        return true
      }
      // tabindex="-1" means programmatically focusable but not via tab
      return false
    }
    Option::None => ()
  }

  // Inherently focusable elements
  let tag = element.tag.to_lower()
  match tag {
    "a" => if element.attributes.contains("href") { return true }
    "button" => return not(element.attributes.contains("disabled"))
    "input" =>
      if element.attributes.get("type") != Some("hidden") {
        return not(element.attributes.contains("disabled"))
      }
    "select" | "textarea" => return not(element.attributes.contains("disabled"))
    "details" | "summary" => return true
    _ => ()
  }

  // Check if role is inherently focusable
  role_is_inherently_focusable(role) &&
  not(element.attributes.contains("disabled"))
}

// =============================================================================
// Layout Integration
// =============================================================================

///|
/// Attach layout bounds to accessibility nodes
/// Takes a mapping from element id to bounds
pub fn attach_bounds(
  tree : AccessibilityTree,
  bounds_map : Map[String, Bounds],
) -> AccessibilityTree {
  let new_root = attach_bounds_recursive(tree.root, bounds_map)
  AccessibilityTree::new(new_root)
}

///|
fn attach_bounds_recursive(
  node : AccessibilityNode,
  bounds_map : Map[String, Bounds],
) -> AccessibilityNode {
  // Attach bounds if available
  let new_bounds : Bounds? = match node.source_id {
    Some(id) =>
      match bounds_map.get(id) {
        Some(b) => Some(b)
        Option::None => node.bounds
      }
    Option::None => node.bounds
  }

  // Process children
  let new_children : Array[AccessibilityNode] = []
  for child in node.children {
    new_children.push(attach_bounds_recursive(child, bounds_map))
  }
  { ..node, bounds: new_bounds, children: new_children }
}

// =============================================================================
// Tree Queries
// =============================================================================

///|
/// Find all interactive elements in the tree
pub fn find_interactive(tree : AccessibilityTree) -> Array[AccessibilityNode] {
  let result : Array[AccessibilityNode] = []
  find_interactive_recursive(tree.root, result)
  result
}

///|
fn find_interactive_recursive(
  node : AccessibilityNode,
  result : Array[AccessibilityNode],
) -> Unit {
  // Check if this node is interactive
  if is_interactive_role(node.role) || node.focusable {
    result.push(node)
  }

  // Recurse into children
  for child in node.children {
    find_interactive_recursive(child, result)
  }
}

///|
fn is_interactive_role(role : Role) -> Bool {
  match role {
    Button
    | Checkbox
    | Combobox
    | Link
    | Listbox
    | Menu
    | MenuBar
    | MenuItem
    | MenuItemCheckbox
    | MenuItemRadio
    | Option
    | Radio
    | Scrollbar
    | SearchBox
    | Slider
    | SpinButton
    | Switch
    | Tab
    | Textbox
    | Tree
    | TreeItem => true
    _ => false
  }
}

///|
/// Find all landmarks in the tree
pub fn find_landmarks(tree : AccessibilityTree) -> Array[AccessibilityNode] {
  let result : Array[AccessibilityNode] = []
  find_landmarks_recursive(tree.root, result)
  result
}

///|
fn find_landmarks_recursive(
  node : AccessibilityNode,
  result : Array[AccessibilityNode],
) -> Unit {
  if role_is_landmark(node.role) {
    result.push(node)
  }
  for child in node.children {
    find_landmarks_recursive(child, result)
  }
}

///|
/// Find all headings in the tree (returns in document order)
pub fn find_headings(tree : AccessibilityTree) -> Array[AccessibilityNode] {
  let result : Array[AccessibilityNode] = []
  find_headings_recursive(tree.root, result)
  result
}

///|
fn find_headings_recursive(
  node : AccessibilityNode,
  result : Array[AccessibilityNode],
) -> Unit {
  match node.role {
    Heading => result.push(node)
    _ => ()
  }
  for child in node.children {
    find_headings_recursive(child, result)
  }
}
