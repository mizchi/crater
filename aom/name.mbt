///|
/// Accessible Name and Description Computation
/// Based on WAI-ARIA Accessible Name and Description Computation 1.2
/// https://www.w3.org/TR/accname-1.2/

// =============================================================================
// Accessible Name Computation
// =============================================================================

///|
/// Context for name computation (tracks visited nodes to avoid cycles)
priv struct NameComputationContext {
  visited : Map[String, Bool]
  is_referencing : Bool // true when following aria-labelledby/describedby
}

///|
fn NameComputationContext::new() -> NameComputationContext {
  { visited: {}, is_referencing: false }
}

///|
fn NameComputationContext::with_referencing(
  self : NameComputationContext,
  is_referencing : Bool,
) -> NameComputationContext {
  { ..self, is_referencing, }
}

///|
fn NameComputationContext::mark_visited(
  self : NameComputationContext,
  id : String,
) -> NameComputationContext {
  let new_visited = self.visited
  new_visited[id] = true
  { ..self, visited: new_visited }
}

///|
fn NameComputationContext::is_visited(
  self : NameComputationContext,
  id : String,
) -> Bool {
  self.visited.contains(id)
}

// =============================================================================
// Main Entry Point
// =============================================================================

///|
/// Compute the accessible name for an HTML element
/// Follows the accname-1.2 algorithm
pub fn compute_accessible_name(
  element : @html.Element,
  find_by_id : (String) -> @html.Element?,
) -> String? {
  compute_accessible_name_with_label(element, find_by_id, fn(_id) { None })
}

///|
/// Compute the accessible name with label lookup support
pub fn compute_accessible_name_with_label(
  element : @html.Element,
  find_by_id : (String) -> @html.Element?,
  find_label_for_id : (String) -> @html.Element?,
) -> String? {
  compute_accessible_name_full(element, find_by_id, find_label_for_id, None)
}

///|
/// Compute the accessible name with full label support (including encapsulation)
pub fn compute_accessible_name_full(
  element : @html.Element,
  find_by_id : (String) -> @html.Element?,
  find_label_for_id : (String) -> @html.Element?,
  encapsulating_label : @html.Element?,
) -> String? {
  let ctx = NameComputationContext::new()
  let name = compute_name_step(
    element, ctx, find_by_id, find_label_for_id, encapsulating_label,
  )
  let trimmed = name.trim().to_string()
  if trimmed.is_empty() {
    Option::None
  } else {
    // Apply text-transform from element's style
    let transformed = apply_text_transform(trimmed, element)
    Some(transformed)
  }
}

///|
/// Compute the accessible description for an HTML element
pub fn compute_accessible_description(
  element : @html.Element,
  find_by_id : (String) -> @html.Element?,
) -> String? {
  compute_accessible_description_with_label(element, find_by_id, fn(_id) {
    None
  })
}

///|
/// Compute the accessible description with label lookup support
pub fn compute_accessible_description_with_label(
  element : @html.Element,
  find_by_id : (String) -> @html.Element?,
  find_label_for_id : (String) -> @html.Element?,
) -> String? {
  // aria-describedby takes precedence
  match element.attributes.get("aria-describedby") {
    Some(ids) => {
      let ctx = NameComputationContext::new().with_referencing(true)
      let parts : Array[String] = []
      for id in ids.split(" ") {
        let id_str = id.to_string().trim().to_string()
        if not(id_str.is_empty()) {
          match find_by_id(id_str) {
            Some(ref_elem) => {
              let text = compute_name_step(
                ref_elem,
                ctx,
                find_by_id,
                find_label_for_id,
                None,
              )
              if not(text.is_empty()) {
                parts.push(text)
              }
            }
            Option::None => ()
          }
        }
      }
      if parts.is_empty() {
        Option::None
      } else {
        Some(parts.join(" "))
      }
    }
    Option::None =>
      // Fall back to title attribute
      match element.attributes.get("title") {
        Some(title) if not(title.is_empty()) => Some(title)
        _ => Option::None
      }
  }
}

// =============================================================================
// Name Computation Steps (accname-1.2 Algorithm)
// =============================================================================

///|
/// Main computation step following accname specification
fn compute_name_step(
  element : @html.Element,
  ctx : NameComputationContext,
  find_by_id : (String) -> @html.Element?,
  find_label_for_id : (String) -> @html.Element?,
  encapsulating_label : @html.Element?,
) -> String {
  // Step 1: Skip hidden elements (unless referenced)
  if not(ctx.is_referencing) && is_hidden(element) {
    return ""
  }

  // Avoid cycles
  match element.id {
    Some(id) if ctx.is_visited(id) => {
      // Self-reference case: skip aria-labelledby but continue with other steps
      // Per accname spec, when aria-labelledby references itself, skip step 2A
      // but still check aria-label, native alternatives, etc.
      if ctx.is_referencing {
        return compute_name_steps_skip_labelledby(
          element, ctx, find_by_id, find_label_for_id, encapsulating_label,
        )
      }
      return ""
    }
    Some(id) => {
      let new_ctx = ctx.mark_visited(id)
      return compute_name_steps(
        element, new_ctx, find_by_id, find_label_for_id, encapsulating_label,
      )
    }
    Option::None =>
      compute_name_steps(
        element, ctx, find_by_id, find_label_for_id, encapsulating_label,
      )
  }
}

///|
fn compute_name_steps(
  element : @html.Element,
  ctx : NameComputationContext,
  find_by_id : (String) -> @html.Element?,
  find_label_for_id : (String) -> @html.Element?,
  encapsulating_label : @html.Element?,
) -> String {
  // Step 2A: aria-labelledby
  match element.attributes.get("aria-labelledby") {
    Some(ids) if not(ctx.is_referencing) => {
      let ref_ctx = ctx.with_referencing(true)
      let parts : Array[String] = []
      for id in ids.split(" ") {
        let id_str = id.to_string().trim().to_string()
        if not(id_str.is_empty()) {
          match find_by_id(id_str) {
            Some(ref_elem) => {
              let text = compute_name_step(
                ref_elem,
                ref_ctx,
                find_by_id,
                find_label_for_id,
                None,
              )
              if not(text.is_empty()) {
                parts.push(text)
              }
            }
            Option::None => ()
          }
        }
      }
      if not(parts.is_empty()) {
        return parts.join(" ")
      }
    }
    _ => ()
  }

  // Step 2B: aria-label
  match element.attributes.get("aria-label") {
    Some(label) if not(label.trim().is_empty()) =>
      return label.trim().to_string()
    _ => ()
  }

  // Step 2C: Native text alternatives (depends on element type)
  let native_text = compute_native_text_alternative(
    element, find_label_for_id, encapsulating_label,
  )
  if not(native_text.is_empty()) {
    return native_text
  }

  // Step 2C.5: Name from heading for dialog-like roles (tentative feature)
  let role = compute_role(element, RoleMappingContext::default())
  if role_gets_name_from_heading(role) {
    match find_first_heading(element) {
      Some(heading) => {
        let heading_text = extract_all_text(heading)
        if not(heading_text.is_empty()) {
          return heading_text
        }
      }
      None => ()
    }
  }

  // Step 2D: Name from content (if role allows it)
  if role_supports_name_from_content(role) || ctx.is_referencing {
    let content = compute_text_content(
      element, ctx, find_by_id, find_label_for_id,
    )
    if not(content.is_empty()) {
      return content
    }
  }

  // Step 2E: Tooltip (title attribute)
  match element.attributes.get("title") {
    Some(title) if not(title.is_empty()) => return title
    _ => ()
  }

  // Special case: select element without label or title - use selected option
  if element.tag.to_lower() == "select" {
    let option_text = find_selected_option_text(element)
    if not(option_text.is_empty()) {
      return option_text
    }
  }
  ""
}

///|
/// Compute name steps but skip aria-labelledby (for self-reference case)
fn compute_name_steps_skip_labelledby(
  element : @html.Element,
  ctx : NameComputationContext,
  find_by_id : (String) -> @html.Element?,
  find_label_for_id : (String) -> @html.Element?,
  encapsulating_label : @html.Element?,
) -> String {
  // Step 2B: aria-label (skip step 2A)
  match element.attributes.get("aria-label") {
    Some(label) if not(label.trim().is_empty()) =>
      return label.trim().to_string()
    _ => ()
  }

  // Step 2C: Native text alternatives
  let native_text = compute_native_text_alternative(
    element, find_label_for_id, encapsulating_label,
  )
  if not(native_text.is_empty()) {
    return native_text
  }

  // Step 2D: Name from content
  let role = compute_role(element, RoleMappingContext::default())
  if role_supports_name_from_content(role) || ctx.is_referencing {
    let content = compute_text_content(
      element, ctx, find_by_id, find_label_for_id,
    )
    if not(content.is_empty()) {
      return content
    }
  }

  // Step 2E: Tooltip
  match element.attributes.get("title") {
    Some(title) if not(title.is_empty()) => return title
    _ => ()
  }
  ""
}

// =============================================================================
// Native Text Alternatives
// =============================================================================

///|
/// Compute native text alternative based on element type
fn compute_native_text_alternative(
  element : @html.Element,
  find_label_for_id : (String) -> @html.Element?,
  encapsulating_label : @html.Element?,
) -> String {
  let tag = element.tag.to_lower()
  match tag {
    // Images: alt attribute
    "img" | "area" =>
      match element.attributes.get("alt") {
        Some(alt) => alt
        Option::None => ""
      }

    // Input elements: depends on type
    "input" =>
      compute_input_name(element, find_label_for_id, encapsulating_label)

    // Button: value attribute for certain types
    "button" => "" // Falls through to content

    // Textarea: associated label
    "textarea" =>
      find_label_text(element, find_label_for_id, encapsulating_label)

    // Select: associated label only (selected option handled in Step 2E fallback)
    "select" => find_label_text(element, find_label_for_id, encapsulating_label)

    // Table: caption
    "table" => find_child_text(element, "caption")

    // Fieldset: legend
    "fieldset" => find_child_text(element, "legend")

    // Figure: figcaption
    "figure" => find_child_text(element, "figcaption")

    // Details: does not get name from summary per html-aam
    "details" => ""
    _ => ""
  }
}

///|
/// Compute name for input elements
fn compute_input_name(
  element : @html.Element,
  find_label_for_id : (String) -> @html.Element?,
  encapsulating_label : @html.Element?,
) -> String {
  let input_type = match element.attributes.get("type") {
    Some(t) => t.to_lower()
    Option::None => "text"
  }
  match input_type {
    // Button types: use value
    "button" | "submit" | "reset" =>
      match element.attributes.get("value") {
        Some(value) if not(value.is_empty()) => value
        _ =>
          // Default labels for submit/reset
          match input_type {
            "submit" => "Submit"
            "reset" => "Reset"
            _ => ""
          }
      }

    // Image type: alt, then value
    "image" =>
      match element.attributes.get("alt") {
        Some(alt) if not(alt.is_empty()) => alt
        _ =>
          match element.attributes.get("value") {
            Some(value) if not(value.is_empty()) => value
            _ => "Submit" // default for image input
          }
      }

    // Text-like inputs: look for associated label
    _ => find_label_text(element, find_label_for_id, encapsulating_label)
  }
}

///|
/// Find text from an associated label element
fn find_label_text(
  element : @html.Element,
  find_label_for_id : (String) -> @html.Element?,
  encapsulating_label : @html.Element?,
) -> String {
  // Check for aria-labelledby first (handled in main algorithm)
  // Here we handle HTML label association

  // 1. Check for label with matching 'for' attribute
  match element.id {
    Some(id) =>
      match find_label_for_id(id) {
        Some(label_elem) => return extract_all_text(label_elem)
        Option::None => ()
      }
    Option::None => ()
  }

  // 2. Check for encapsulating label (label wrapping the input)
  match encapsulating_label {
    Some(label_elem) =>
      extract_label_text_excluding_control(label_elem, element)
    Option::None => ""
  }
}

///|
/// Extract text from a label element, excluding the control element itself
fn extract_label_text_excluding_control(
  label : @html.Element,
  control : @html.Element,
) -> String {
  let buf = StringBuilder::new()
  extract_text_excluding_control_recursive(label, control, buf)
  normalize_whitespace(buf.to_string())
}

///|
fn extract_text_excluding_control_recursive(
  element : @html.Element,
  control : @html.Element,
  buf : StringBuilder,
) -> Unit {
  for child in element.children {
    match child {
      @html.Text(text) => buf.write_string(text)
      @html.Element(child_elem) => {
        // Skip the control element itself (the one being labeled)
        if is_same_element(child_elem, control) {
          continue
        }
        // For embedded form controls, extract their value
        // Check by tag name (native controls)
        let tag = child_elem.tag.to_lower()
        let is_native_control = tag == "input" ||
          tag == "select" ||
          tag == "textarea" ||
          tag == "button"
        // Also check by role for ARIA widgets
        let role = compute_role(child_elem, RoleMappingContext::default())
        let is_aria_widget = match role {
          Textbox | SearchBox | Combobox | Listbox | Slider | SpinButton => true
          _ => false
        }
        if is_native_control || is_aria_widget {
          // Get embedded control value (accname Step 2F)
          match get_embedded_control_value(child_elem) {
            Some(value) => buf.write_string(value)
            None => ()
          }
          continue
        }
        extract_text_excluding_control_recursive(child_elem, control, buf)
      }
    }
  }
}

///|
fn is_same_element(a : @html.Element, b : @html.Element) -> Bool {
  // Compare by id if available
  match (a.id, b.id) {
    (Some(id_a), Some(id_b)) => return id_a == id_b
    _ => ()
  }
  // Compare by tag and key attributes for form elements
  if a.tag.to_lower() != b.tag.to_lower() {
    return false
  }
  // For inputs, compare by type and name
  let tag = a.tag.to_lower()
  if tag == "input" || tag == "select" || tag == "textarea" || tag == "button" {
    let a_type = a.attributes.get("type").unwrap_or("text")
    let b_type = b.attributes.get("type").unwrap_or("text")
    let a_name = a.attributes.get("name").unwrap_or("")
    let b_name = b.attributes.get("name").unwrap_or("")
    return a_type == b_type && a_name == b_name
  }
  false
}

///|
/// Find text content of a specific child element
fn find_child_text(element : @html.Element, child_tag : String) -> String {
  for child in element.children {
    match child {
      @html.Element(child_elem) =>
        if child_elem.tag.to_lower() == child_tag {
          return extract_all_text(child_elem)
        }
      @html.Text(_) => ()
    }
  }
  ""
}

///|
/// Find text of selected option in a select element
fn find_selected_option_text(element : @html.Element) -> String {
  // First try to find an option with "selected" attribute
  for child in element.children {
    match child {
      @html.Element(option) =>
        if option.tag.to_lower() == "option" &&
          option.attributes.contains("selected") {
          return extract_all_text(option)
        }
      _ => ()
    }
  }
  // If no selected option, return first option's text
  for child in element.children {
    match child {
      @html.Element(option) =>
        if option.tag.to_lower() == "option" {
          return extract_all_text(option)
        }
      _ => ()
    }
  }
  ""
}

// =============================================================================
// Embedded Control Value (accname Step 2F)
// =============================================================================

///|
/// Get the value of an embedded control for accessible name computation
/// Returns Some(value) if the element is an embedded control, None otherwise
fn get_embedded_control_value(element : @html.Element) -> String? {
  let tag = element.tag.to_lower()
  let role = compute_role(element, RoleMappingContext::default())

  // Check if this is an embedded control
  match role {
    // Textbox: use value attribute
    Textbox | SearchBox =>
      match element.attributes.get("value") {
        Some(value) if not(value.is_empty()) => Some(value)
        _ => None
      }

    // Combobox/Listbox: use selected option text for select, value for input
    Combobox | Listbox =>
      if tag == "select" {
        // Find the selected option
        for child in element.children {
          match child {
            @html.Element(option) =>
              if option.tag.to_lower() == "option" &&
                option.attributes.contains("selected") {
                return Some(extract_all_text(option))
              }
            _ => ()
          }
        }
        // If no selected, use first option
        for child in element.children {
          match child {
            @html.Element(option) =>
              if option.tag.to_lower() == "option" {
                return Some(extract_all_text(option))
              }
            _ => ()
          }
        }
        None
      } else {
        // For non-select combobox (input, div, span with role="combobox")
        // Use value attribute, or text content for non-input elements
        match element.attributes.get("value") {
          Some(value) if not(value.is_empty()) => Some(value)
          _ =>
            // For span/div with role="combobox", use text content
            if tag != "input" {
              let text = extract_all_text(element)
              if not(text.is_empty()) {
                Some(text)
              } else {
                None
              }
            } else {
              None
            }
        }
      }

    // Slider/Spinbutton: use aria-valuetext, aria-valuenow, or value attribute
    Slider | SpinButton =>
      match element.attributes.get("aria-valuetext") {
        Some(text) if not(text.is_empty()) => Some(text)
        _ =>
          match element.attributes.get("aria-valuenow") {
            Some(value) if not(value.is_empty()) => Some(value)
            _ =>
              // For native range/number inputs, use value attribute
              match element.attributes.get("value") {
                Some(value) if not(value.is_empty()) => Some(value)
                _ => None
              }
          }
      }

    // Other form controls
    _ => None
  }
}

// =============================================================================
// Text Content Extraction
// =============================================================================

///|
/// Compute text content from element and children
/// When extracting text content for name computation, we need to:
/// 1. Get text from embedded controls (Step 2F)
/// 2. Recursively extract text from all other elements
/// 3. Include aria-owns referenced elements (Step 2D)
fn compute_text_content(
  element : @html.Element,
  _ctx : NameComputationContext,
  find_by_id : (String) -> @html.Element?,
  _find_label_for_id : (String) -> @html.Element?,
) -> String {
  let buf = StringBuilder::new()
  compute_text_content_recursive(element, buf, false)

  // Step 2D: Include aria-owns referenced elements
  // Per ARIA spec: ignore aria-owns when target is hidden from all users
  // or when target has an ancestor that is hidden from all users
  match element.attributes.get("aria-owns") {
    Some(ids) =>
      for id in ids.split(" ") {
        let id_str = id.to_string().trim().to_string()
        if not(id_str.is_empty()) {
          match find_by_id(id_str) {
            Some(owned_elem) => {
              // Skip if the owned element is hidden from all users
              if is_hidden(owned_elem) {
                continue
              }
              // Skip if any ancestor is hidden (check via find_by_id traversal)
              if is_in_hidden_subtree(owned_elem, find_by_id) {
                continue
              }
              // Get text from owned element - add space before aria-owns content
              let owned_text = extract_all_text_raw(owned_elem)
              if not(owned_text.is_empty()) {
                buf.write_char(' ')
                buf.write_string(owned_text)
              }
            }
            Option::None => ()
          }
        }
      }
    Option::None => ()
  }
  normalize_whitespace(buf.to_string())
}

///|
/// Recursively extract text content, handling embedded controls
/// Uses StringBuilder to preserve original whitespace, then normalizes at the end
fn compute_text_content_recursive(
  element : @html.Element,
  buf : StringBuilder,
  in_hidden_visibility : Bool,
) -> Unit {
  for child in element.children {
    match child {
      @html.Text(text) =>
        // Skip text if we're in a visibility:hidden context
        if not(in_hidden_visibility) {
          // Write text as-is, preserving original whitespace
          buf.write_string(text)
        }
      @html.Element(child_elem) => {
        // Skip completely hidden elements (display:none, aria-hidden, hidden)
        if is_hidden(child_elem) {
          continue
        }

        // Check visibility state for this element
        let child_hidden_visibility = if has_visibility_visible(child_elem) {
          // visibility:visible overrides parent's visibility:hidden
          false
        } else if has_visibility_hidden(child_elem) {
          // This element is visibility:hidden
          true
        } else {
          // Inherit from parent
          in_hidden_visibility
        }

        // Handle image elements - use alt text (only if visible)
        let tag = child_elem.tag.to_lower()
        if (tag == "img" || tag == "area") && not(child_hidden_visibility) {
          match child_elem.attributes.get("alt") {
            Some(alt) if not(alt.is_empty()) => {
              // Add space before image alt if buffer not empty and doesn't end with space
              ensure_space_separator(buf)
              buf.write_string(alt)
            }
            _ => ()
          }
          continue
        }

        // Step 2F: Check for embedded control value first (only if visible)
        if not(child_hidden_visibility) {
          match get_embedded_control_value(child_elem) {
            Some(value) => {
              ensure_space_separator(buf)
              buf.write_string(value)
              continue
            }
            None => ()
          }
        }

        // Per accname spec: when computing text content from descendants,
        // if a child element has aria-label, use that instead of its content
        if not(child_hidden_visibility) {
          match child_elem.attributes.get("aria-label") {
            Some(label) if not(label.trim().is_empty()) => {
              ensure_space_separator(buf)
              buf.write_string(label.trim().to_string())
              continue
            }
            _ => ()
          }
        }

        // Recursively extract text from child elements
        // Track buffer length to know if child added content
        let len_before = buf.to_string().length()

        // Pass visibility state - children may override with visibility:visible
        compute_text_content_recursive(child_elem, buf, child_hidden_visibility)

        // Add space after child element content only if child had content
        // This ensures "one" + "two" + "three" becomes "one two three"
        // but "button<span></span>label" stays "buttonlabel"
        let len_after = buf.to_string().length()
        if len_after > len_before {
          ensure_space_separator(buf)
        }
      }
    }
  }
}

///|
/// Ensure there's a space separator before adding new content
/// Does nothing if buffer is empty or already ends with whitespace
fn ensure_space_separator(buf : StringBuilder) -> Unit {
  let s = buf.to_string()
  if s.is_empty() {
    return
  }
  // Check if last char is whitespace
  let chars = s.to_array()
  if chars.length() > 0 {
    let last = chars[chars.length() - 1]
    if last != ' ' && last != '\t' && last != '\n' && last != '\r' {
      buf.write_char(' ')
    }
  }
}

///|
/// Extract all text content from element (simple, non-recursive aware)
/// Normalizes whitespace in the result
fn extract_all_text(element : @html.Element) -> String {
  normalize_whitespace(extract_all_text_raw(element))
}

///|
/// Extract all text content from element without normalizing
fn extract_all_text_raw(element : @html.Element) -> String {
  let buf = StringBuilder::new()
  extract_text_recursive(element, buf)
  buf.to_string()
}

///|
fn extract_text_recursive(element : @html.Element, buf : StringBuilder) -> Unit {
  for child in element.children {
    match child {
      @html.Text(text) => buf.write_string(text)
      @html.Element(child_elem) => {
        // Handle image elements - use alt text
        let tag = child_elem.tag.to_lower()
        if tag == "img" || tag == "area" {
          match child_elem.attributes.get("alt") {
            Some(alt) if not(alt.is_empty()) => buf.write_string(alt)
            _ => ()
          }
        } else {
          extract_text_recursive(child_elem, buf)
        }
      }
    }
  }
}

///|
/// Normalize whitespace: collapse consecutive whitespace to single space, trim
fn normalize_whitespace(s : String) -> String {
  let chars : Array[Char] = []
  let mut last_was_space = true // Start true to skip leading whitespace
  for c in s {
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      if not(last_was_space) {
        chars.push(' ')
        last_was_space = true
      }
    } else {
      chars.push(c)
      last_was_space = false
    }
  }
  // Trim trailing space
  while chars.length() > 0 && chars[chars.length() - 1] == ' ' {
    let _ = chars.pop()

  }
  String::from_array(chars)
}

// =============================================================================
// Hidden State Detection
// =============================================================================

///|
/// Check if an element is completely hidden from accessibility tree
/// (display:none, aria-hidden, hidden attribute - these hide element AND children)
fn is_hidden(element : @html.Element) -> Bool {
  // aria-hidden="true"
  match element.attributes.get("aria-hidden") {
    Some("true") => return true
    _ => ()
  }

  // hidden attribute
  if element.attributes.contains("hidden") {
    return true
  }

  // Check inline style for display:none (hides element and all children)
  match element.style {
    Some(style) => {
      let style_lower = style.to_lower()
      if style_lower.contains("display") && style_lower.contains("none") {
        return true
      }
    }
    Option::None => ()
  }
  false
}

///|
/// Check if element has visibility:hidden (children can override with visibility:visible)
fn has_visibility_hidden(element : @html.Element) -> Bool {
  match element.style {
    Some(style) => {
      let style_lower = style.to_lower()
      style_lower.contains("visibility") && style_lower.contains("hidden")
    }
    Option::None => false
  }
}

///|
/// Check if element has visibility:visible (overrides parent's visibility:hidden)
fn has_visibility_visible(element : @html.Element) -> Bool {
  match element.style {
    Some(style) => {
      let style_lower = style.to_lower()
      style_lower.contains("visibility") && style_lower.contains("visible")
    }
    Option::None => false
  }
}

///|
/// Check if an element is inside a hidden subtree
/// This is a simplified check - full implementation would require parent references
/// For now, we can't detect if an ancestor is hidden without traversing the DOM
fn is_in_hidden_subtree(
  _element : @html.Element,
  _find_by_id : (String) -> @html.Element?,
) -> Bool {
  // TODO: Implement ancestor hidden check when parent references are available
  // Currently, the test generator includes hidden wrappers for aria-owns targets,
  // but we can't traverse up the DOM tree to check ancestors at runtime
  false
}

///|
/// Find the first heading inside an element (h1-h6 or role="heading")
/// Used for dialog-like roles that get name from first heading (tentative feature)
fn find_first_heading(element : @html.Element) -> @html.Element? {
  // Depth-first search for first heading
  for child in element.children {
    match child {
      @html.Element(child_elem) => {
        let tag = child_elem.tag.to_lower()
        // Check for heading elements (h1-h6)
        if tag == "h1" ||
          tag == "h2" ||
          tag == "h3" ||
          tag == "h4" ||
          tag == "h5" ||
          tag == "h6" {
          return Some(child_elem)
        }
        // Check for role="heading"
        match child_elem.attributes.get("role") {
          Some(r) if r.to_lower() == "heading" => return Some(child_elem)
          _ => ()
        }
        // Recurse into children
        match find_first_heading(child_elem) {
          Some(h) => return Some(h)
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
/// Check if role should get name from first heading (dialog-like roles)
fn role_gets_name_from_heading(role : Role) -> Bool {
  match role {
    AlertDialog | Dialog | Article => true
    _ => false
  }
}

// =============================================================================
// Text Transform
// =============================================================================

///|
/// Apply CSS text-transform to a string based on element's style
fn apply_text_transform(text : String, element : @html.Element) -> String {
  let transform = get_text_transform(element)
  match transform {
    "uppercase" => text.to_upper()
    "lowercase" => text.to_lower()
    "capitalize" => capitalize_words(text)
    _ => text
  }
}

///|
/// Extract text-transform value from element's inline style
fn get_text_transform(element : @html.Element) -> String {
  match element.style {
    Some(style) => {
      let style_lower = style.to_lower()
      if style_lower.contains("text-transform") {
        // Parse text-transform value from style string
        // e.g. "text-transform:uppercase;" or "text-transform: uppercase"
        for part in style.split(";") {
          let part_str = part.to_string().trim().to_string()
          let part_lower = part_str.to_lower()
          if part_lower.contains("text-transform") {
            match part_str.split(":").collect().get(1) {
              Some(value) =>
                return value.to_string().trim().to_string().to_lower()
              None => ()
            }
          }
        }
      }
      ""
    }
    None => ""
  }
}

///|
/// Capitalize first letter of each word
fn capitalize_words(text : String) -> String {
  let result : Array[Char] = []
  let mut capitalize_next = true
  for c in text {
    if c == ' ' || c == '\t' || c == '\n' {
      result.push(c)
      capitalize_next = true
    } else if capitalize_next {
      result.push(char_to_upper(c))
      capitalize_next = false
    } else {
      result.push(c)
    }
  }
  String::from_array(result)
}

///|
/// Convert a single character to uppercase
fn char_to_upper(c : Char) -> Char {
  if c >= 'a' && c <= 'z' {
    (c.to_int() - 32).unsafe_to_char()
  } else {
    c
  }
}
