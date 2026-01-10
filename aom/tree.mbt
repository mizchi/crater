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
  // Parsed stylesheets for pseudo-element content
  stylesheets : Array[@cascade.Stylesheet]
  // Ref counter for sequential element refs (ref_1, ref_2, ...)
  mut ref_counter : Int
}

///|
fn TreeBuilderContext::new() -> TreeBuilderContext {
  {
    element_map: {},
    label_map: {},
    in_sectioning: false,
    encapsulating_label: None,
    uid_counter: 0,
    stylesheets: [],
    ref_counter: 1,
  }
}

///|
fn TreeBuilderContext::with_stylesheets(
  self : TreeBuilderContext,
  stylesheets : Array[@cascade.Stylesheet],
) -> TreeBuilderContext {
  { ..self, stylesheets, }
}

///|
fn TreeBuilderContext::next_uid(self : TreeBuilderContext) -> String {
  let uid = self.uid_counter
  self.uid_counter += 1
  "aom-\{uid}"
}

///|
/// Generate next ref id (ref_1, ref_2, ...)
fn TreeBuilderContext::next_ref(self : TreeBuilderContext) -> String {
  let ref_num = self.ref_counter
  self.ref_counter += 1
  "ref_\{ref_num}"
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
// Pseudo-element Content Extraction
// =============================================================================

///|
/// Get content of ::before pseudo-element for an element
fn get_before_content(
  element : @html.Element,
  ctx : TreeBuilderContext,
) -> String? {
  get_pseudo_element_content(element, ctx, true)
}

///|
/// Get content of ::after pseudo-element for an element
fn get_after_content(
  element : @html.Element,
  ctx : TreeBuilderContext,
) -> String? {
  get_pseudo_element_content(element, ctx, false)
}

///|
/// Get content of a pseudo-element for an element
/// is_before: true for ::before, false for ::after
fn get_pseudo_element_content(
  element : @html.Element,
  ctx : TreeBuilderContext,
  is_before : Bool,
) -> String? {
  if ctx.stylesheets.is_empty() {
    return None
  }

  // Search through stylesheets for matching rules with the pseudo-element
  for stylesheet in ctx.stylesheets {
    for rule in stylesheet.rules {
      // Check selector text for ::before or ::after
      let has_pseudo = if is_before {
        rule.selector_text.contains("::before") ||
        rule.selector_text.contains(":before")
      } else {
        rule.selector_text.contains("::after") ||
        rule.selector_text.contains(":after")
      }
      if has_pseudo {
        // Try to match by checking if base selector matches the element
        // Use the selector_text to build a simpler match
        if matches_element_by_class(element, rule.selector_text) {
          // Found a match, extract content property
          for decl in rule.declarations {
            if decl.property == "content" {
              match decl.value {
                @cascade.Value(value) => {
                  // Remove quotes from string value
                  let content = parse_content_value(value)
                  if not(content.is_empty()) {
                    return Some(content)
                  }
                }
                _ => ()
              }
            }
          }
        }
      }
    }
  }
  None
}

///|
/// Simple class-based matching for pseudo-element selectors
fn matches_element_by_class(
  element : @html.Element,
  selector_text : String,
) -> Bool {
  // Extract class from selector like ".simple-before::before"
  // This is a simplified matcher for common patterns

  // Check for class selector
  let class_patterns = extract_class_patterns(selector_text)
  for pattern in class_patterns {
    if element.classes.contains(pattern) {
      return true
    }
  }

  // Check for tag selector
  let tag = element.tag.to_lower()
  if selector_text.has_prefix(tag) {
    return true
  }
  false
}

///|
/// Extract class names from a selector text
fn extract_class_patterns(selector_text : String) -> Array[String] {
  let classes : Array[String] = []
  let mut i = 0
  let dot_code = '.'.to_int().to_uint16()
  let hash_code = '#'.to_int().to_uint16()
  let colon_code = ':'.to_int().to_uint16()
  let bracket_code = '['.to_int().to_uint16()
  let space_code = ' '.to_int().to_uint16()
  let gt_code = '>'.to_int().to_uint16()
  let plus_code = '+'.to_int().to_uint16()
  let tilde_code = '~'.to_int().to_uint16()
  while i < selector_text.length() {
    if selector_text[i] == dot_code {
      // Found a class selector
      let start = i + 1
      let mut end = start
      while end < selector_text.length() {
        let c = selector_text[end]
        if c == dot_code ||
          c == hash_code ||
          c == colon_code ||
          c == bracket_code ||
          c == space_code ||
          c == gt_code ||
          c == plus_code ||
          c == tilde_code {
          break
        }
        end += 1
      }
      if end > start {
        // Build substring manually
        let buf = StringBuilder::new()
        for j = start; j < end; j = j + 1 {
          buf.write_char(selector_text[j].to_int().unsafe_to_char())
        }
        classes.push(buf.to_string())
      }
      i = end
    } else {
      i += 1
    }
  }
  classes
}

///|
/// Parse CSS content value (remove quotes, handle escapes)
fn parse_content_value(value : String) -> String {
  let trimmed = value.trim().to_string()

  // Check for quoted string
  if trimmed.length() >= 2 {
    let first = trimmed[0]
    let last = trimmed[trimmed.length() - 1]
    // Check for double or single quotes
    if (first == '"'.to_int().to_uint16() && last == '"'.to_int().to_uint16()) ||
      (first == '\''.to_int().to_uint16() && last == '\''.to_int().to_uint16()) {
      // Remove quotes - build string manually
      let buf = StringBuilder::new()
      for i = 1; i < trimmed.length() - 1; i = i + 1 {
        buf.write_char(trimmed[i].to_int().unsafe_to_char())
      }
      return buf.to_string()
    }
  }

  // Handle none, normal (no content)
  if trimmed == "none" || trimmed == "normal" {
    return ""
  }

  // Return as-is for other values
  trimmed
}

// =============================================================================
// Main Entry Point
// =============================================================================

///|
/// Build an AccessibilityTree from an HTML Document
pub fn build_accessibility_tree(doc : @html.Document) -> AccessibilityTree {
  let ctx = TreeBuilderContext::new()

  // Parse stylesheets from the document
  let stylesheets : Array[@cascade.Stylesheet] = []
  for css_text in doc.stylesheets {
    let stylesheet = @parser.parse_stylesheet(css_text)
    stylesheets.push(stylesheet)
  }
  let ctx = ctx.with_stylesheets(stylesheets)

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
      tabindex: Option::None,
      source_id: element.id,
      href: Option::None,
      tag_name: Some(element.tag.to_lower()),
      selector: build_selector(element),
      visible: is_visible_element(element.tag),
      ref_id: Some(ctx.next_ref()),
      input_type: Option::None,
      placeholder: Option::None,
      input_value: Option::None,
      required: false,
      text: Option::None,
      options: [],
      labelled_by: Option::None,
    }
  }

  // Compute accessible name
  let find_by_id = fn(id : String) -> @html.Element? { ctx.find_by_id(id) }
  let find_label_for_id = fn(id : String) -> @html.Element? {
    ctx.label_map.get(id)
  }
  let base_name = compute_accessible_name_full(
    element,
    find_by_id,
    find_label_for_id,
    ctx.encapsulating_label,
  )

  // Add pseudo-element content (::before and ::after)
  // Per accname spec, pseudo-element content is concatenated directly
  // (the content value itself may contain spaces that act as joiners)
  let name = match base_name {
    Some(n) => {
      let before = get_before_content(element, ctx)
      let after = get_after_content(element, ctx)
      let buf = StringBuilder::new()
      match before {
        Some(b) => buf.write_string(b)
        None => ()
      }
      buf.write_string(n)
      match after {
        Some(a) => buf.write_string(a)
        None => ()
      }
      Some(buf.to_string().trim().to_string())
    }
    None => None
  }

  // Compute accessible description
  let description = compute_accessible_description(element, find_by_id)

  // Compute heading level
  let level = get_heading_level(element)

  // Compute states
  let states = compute_states(element)

  // Check if focusable and get tabindex
  let focusable = is_focusable(element, role)
  let tabindex = get_tabindex(element)

  // Build children (update sectioning context if needed)
  let new_ctx = if is_sectioning_content(element.tag) {
    ctx.with_sectioning(true)
  } else {
    ctx
  }
  let children = build_children(element, new_ctx)

  // Extract href for links
  let href = extract_href(element)

  // Extract form input information
  let input_type = extract_input_type(element)
  let placeholder = extract_placeholder(element)
  let input_value = extract_input_value(element)
  let required = is_required(element)

  // Extract select options
  let options = extract_select_options(element)

  // Find labelling element
  let labelled_by = find_labelling_ref(element, ctx)

  // Aggregate text content for non-interactive elements
  let text = if role == Paragraph ||
    role == Heading ||
    role == ListItem ||
    role == Cell ||
    role == Caption {
    let content = get_element_text_content(element)
    if content.is_empty() { Option::None } else { Some(content) }
  } else {
    Option::None
  }
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
    tabindex,
    source_id: element.id,
    href,
    tag_name: Some(element.tag.to_lower()),
    selector: build_selector(element),
    visible: is_visible_element(element.tag),
    ref_id: Some(ctx.next_ref()),
    input_type,
    placeholder,
    input_value,
    required,
    text,
    options,
    labelled_by,
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
            tabindex: Option::None,
            source_id: Option::None,
            href: Option::None,
            tag_name: Option::None,
            selector: Option::None,
            visible: true,
            ref_id: Some(ctx.next_ref()),
            input_type: Option::None,
            placeholder: Option::None,
            input_value: Option::None,
            required: false,
            text: Option::None,
            options: [],
            labelled_by: Option::None,
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

// =============================================================================
// AI Scraping Helpers
// =============================================================================

///|
/// Extract href attribute from link elements
fn extract_href(element : @html.Element) -> String? {
  let tag = element.tag.to_lower()
  match tag {
    "a" => element.attributes.get("href")
    "area" => element.attributes.get("href")
    "link" => element.attributes.get("href")
    _ => Option::None
  }
}

///|
/// Build a CSS selector for an element
fn build_selector(element : @html.Element) -> String? {
  let tag = element.tag.to_lower()
  let buf = StringBuilder::new()
  buf.write_string(tag)

  // Add id if present (most specific)
  match element.id {
    Some(id) if not(id.is_empty()) => {
      buf.write_string("#")
      buf.write_string(id)
      return Some(buf.to_string())
    }
    _ => ()
  }

  // Add classes if present
  if not(element.classes.is_empty()) {
    for cls in element.classes {
      buf.write_string(".")
      buf.write_string(cls)
    }
  }
  Some(buf.to_string())
}

///|
/// Check if element tag represents visible content
/// Returns false for style, script, meta, and head content
fn is_visible_element(tag : String) -> Bool {
  let lower = tag.to_lower()
  match lower {
    "script"
    | "style"
    | "meta"
    | "link"
    | "head"
    | "title"
    | "noscript"
    | "template" => false
    _ => true
  }
}

///|
/// Extract input type from form elements
fn extract_input_type(element : @html.Element) -> String? {
  let tag = element.tag.to_lower()
  match tag {
    "input" =>
      match element.attributes.get("type") {
        Some(t) => Some(t)
        None => Some("text") // default input type
      }
    "textarea" => Some("textarea")
    "select" => Some("select")
    "button" =>
      match element.attributes.get("type") {
        Some(t) => Some(t)
        None => Some("submit") // default button type
      }
    _ => Option::None
  }
}

///|
/// Extract placeholder text from form inputs
fn extract_placeholder(element : @html.Element) -> String? {
  element.attributes.get("placeholder")
}

///|
/// Extract current value from form inputs
fn extract_input_value(element : @html.Element) -> String? {
  let tag = element.tag.to_lower()
  match tag {
    "input" => element.attributes.get("value")
    "textarea" => element.attributes.get("value")
    "select" => element.attributes.get("value")
    _ => Option::None
  }
}

///|
/// Check if form field is required
fn is_required(element : @html.Element) -> Bool {
  element.attributes.contains("required") ||
  element.attributes.get("aria-required") == Some("true")
}

///|
/// Extract options from select element
fn extract_select_options(element : @html.Element) -> Array[SelectOption] {
  let options : Array[SelectOption] = []
  let tag = element.tag.to_lower()
  if tag != "select" {
    return options
  }
  for child in element.children {
    match child {
      @html.Element(option_elem) => {
        let option_tag = option_elem.tag.to_lower()
        if option_tag == "option" {
          let value = option_elem.attributes.get("value").unwrap_or("")
          let label = get_element_text_content(option_elem)
          let selected = option_elem.attributes.contains("selected")
          options.push({ value, label, selected })
        } else if option_tag == "optgroup" {
          // Handle optgroup by extracting its options
          for optgroup_child in option_elem.children {
            match optgroup_child {
              @html.Element(opt) =>
                if opt.tag.to_lower() == "option" {
                  let value = opt.attributes.get("value").unwrap_or("")
                  let label = get_element_text_content(opt)
                  let selected = opt.attributes.contains("selected")
                  options.push({ value, label, selected })
                }
              _ => ()
            }
          }
        }
      }
      _ => ()
    }
  }
  options
}

///|
/// Get text content from an element (recursively)
fn get_element_text_content(element : @html.Element) -> String {
  let buf = StringBuilder::new()
  collect_text_content(element, buf)
  buf.to_string().trim().to_string()
}

///|
/// Recursively collect text content from element
fn collect_text_content(element : @html.Element, buf : StringBuilder) -> Unit {
  for child in element.children {
    match child {
      @html.Text(text) => {
        let trimmed = text.trim().to_string()
        if not(trimmed.is_empty()) {
          if buf.to_string().length() > 0 {
            buf.write_string(" ")
          }
          buf.write_string(trimmed)
        }
      }
      @html.Element(child_elem) => {
        // Skip non-visible elements
        if is_visible_element(child_elem.tag) {
          collect_text_content(child_elem, buf)
        }
      }
    }
  }
}

///|
/// Find the ref of the labelling element for a form input
fn find_labelling_ref(
  element : @html.Element,
  ctx : TreeBuilderContext,
) -> String? {
  // Check aria-labelledby first
  match element.attributes.get("aria-labelledby") {
    Some(label_id) if not(label_id.is_empty()) => {
      // The value might be a space-separated list of IDs, take the first
      let parts : Array[String] = label_id.split(" ").map(fn(s) { s.to_string() }).collect()
      if parts.length() > 0 {
        return Some(parts[0])
      }
    }
    _ => ()
  }
  // Check if there's a label with 'for' attribute matching this element's id
  match element.id {
    Some(elem_id) =>
      match ctx.label_map.get(elem_id) {
        Some(_) => {
          // Return the element id as a hint (the ref will be computed later)
          return Some("label-for-" + elem_id)
        }
        _ => ()
      }
    _ => ()
  }
  Option::None
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
  let tag = element.tag.to_lower()

  // Elements that are never directly tab-focusable
  // (they may be focusable within their parent context, but not via Tab)
  match tag {
    "option" | "optgroup" => return false
    _ => ()
  }

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

///|
/// Get tabindex value from element
/// Returns None if no tabindex attribute, Some(n) otherwise
fn get_tabindex(element : @html.Element) -> Int? {
  match element.attributes.get("tabindex") {
    Some(tabindex_str) => {
      let idx = @strconv.parse_int(tabindex_str) catch { _ => return None }
      Some(idx)
    }
    Option::None => None
  }
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

// =============================================================================
// LayoutTree Integration
// =============================================================================

///|
/// Extract bounds from LayoutTree node map into a Map[String, Bounds]
/// Uses the layout node's id as key (which corresponds to HTML element id)
pub fn extract_bounds_from_layout(
  layout_tree : @tree.LayoutTree,
) -> Map[String, Bounds] {
  let bounds_map : Map[String, Bounds] = {}
  extract_bounds_recursive(layout_tree.root, bounds_map)
  bounds_map
}

///|
fn extract_bounds_recursive(
  node : @tree.LayoutNode,
  bounds_map : Map[String, Bounds],
) -> Unit {
  // Add bounds for this node if it has a non-empty id
  if not(node.id.is_empty()) {
    bounds_map[node.id] = Bounds::new(
      node.computed_x,
      node.computed_y,
      node.computed_width,
      node.computed_height,
    )
  }
  // Recurse into children
  for child in node.children {
    extract_bounds_recursive(child, bounds_map)
  }
}

///|
/// Build AccessibilityTree from HTML and attach layout bounds from LayoutTree
/// This is the main integration function for combining a11y and layout
pub fn build_accessibility_tree_with_layout(
  doc : @html.Document,
  layout_tree : @tree.LayoutTree,
) -> AccessibilityTree {
  // Build accessibility tree
  let a11y_tree = build_accessibility_tree(doc)
  // Extract bounds from layout tree
  let bounds_map = extract_bounds_from_layout(layout_tree)
  // Attach bounds to accessibility nodes
  attach_bounds(a11y_tree, bounds_map)
}
