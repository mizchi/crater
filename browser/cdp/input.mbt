///|
/// CDP Input Domain
///
/// Implements Chrome DevTools Protocol Input domain.
/// Handles mouse and keyboard input.

///|
/// Input Domain handler
pub struct InputDomain {
  tree : @dom.DomTree
  /// Current mouse position
  mut mouse_x : Double
  mut mouse_y : Double
  /// Mouse button state
  mut button_pressed : Bool
}

///|
/// Create new Input domain
pub fn InputDomain::new(tree : @dom.DomTree) -> InputDomain {
  { tree, mouse_x: 0.0, mouse_y: 0.0, button_pressed: false }
}

///|
fn rect_contains_point(rect : @dom.Rect, x : Double, y : Double) -> Bool {
  x >= rect.x &&
  x <= rect.x + rect.width &&
  y >= rect.y &&
  y <= rect.y + rect.height
}

///|
fn InputDomain::find_hit_node(
  self : InputDomain,
  node : @dom.NodeId,
  x : Double,
  y : Double,
) -> @dom.NodeId? {
  match self.tree.get_children(node) {
    Ok(children) => {
      let mut idx = children.length() - 1
      while idx >= 0 {
        match self.find_hit_node(children[idx], x, y) {
          Some(hit) => return Some(hit)
          None => ()
        }
        idx -= 1
      }
    }
    Err(_) => ()
  }
  match self.tree.get_node_info(node) {
    Ok(info) =>
      match info.node_type {
        @dom.Element =>
          match self.tree.get_cached_rect(node) {
            Some(rect) if rect_contains_point(rect, x, y) => Some(node)
            _ => None
          }
        _ => None
      }
    Err(_) => None
  }
}

// =============================================================================
// Mouse Events
// =============================================================================

///|
/// Input.dispatchMouseEvent
pub fn InputDomain::dispatch_mouse_event(
  self : InputDomain,
  type_ : String,
  x : Double,
  y : Double,
  button : String,
  click_count : Int,
) -> Result[Unit, CdpError] {
  // Suppress unused warnings for now
  let _ = button
  let _ = click_count
  // Update mouse position
  self.mouse_x = x
  self.mouse_y = y
  // Handle event type
  match type_ {
    "mousePressed" => {
      self.button_pressed = true
      Ok(())
    }
    "mouseReleased" => {
      self.button_pressed = false
      // On release, trigger click on element at position
      self.click_at(x, y)
    }
    "mouseMoved" => Ok(())
    _ =>
      Err(
        CdpError::from_code(InvalidParams, "Unknown mouse event type: " + type_),
      )
  }
}

///|
/// Find element at position and trigger click
fn InputDomain::click_at(
  self : InputDomain,
  x : Double,
  y : Double,
) -> Result[Unit, CdpError] {
  let doc = self.tree.get_document()
  match self.find_hit_node(doc, x, y) {
    Some(node) => self.tree.set_focus(Some(node))
    None => self.tree.set_focus(None)
  }
  Ok(())
}

// =============================================================================
// Keyboard Events
// =============================================================================

///|
/// Input.dispatchKeyEvent
pub fn InputDomain::dispatch_key_event(
  self : InputDomain,
  type_ : String,
  key : String,
  code : String,
  text : String?,
) -> Result[Unit, CdpError] {
  // Suppress unused warnings
  let _ = self
  let _ = code
  match type_ {
    "keyDown" =>
      // Handle special keys
      match key {
        "Enter" | "Return" =>
          // Submit form or activate focused element
          Ok(())
        "Tab" =>
          // Move focus to next element
          Ok(())
        "Escape" =>
          // Cancel current action
          Ok(())
        _ => Ok(())
      }
    "keyUp" => Ok(())
    "char" =>
      // Handle text input
      match text {
        Some(t) => {
          // Input text to focused element
          let _ = t
          Ok(())
        }
        None => Ok(())
      }
    _ =>
      Err(
        CdpError::from_code(InvalidParams, "Unknown key event type: " + type_),
      )
  }
}

///|
/// Input.insertText - Insert text at current cursor position
pub fn InputDomain::insert_text(
  self : InputDomain,
  text : String,
) -> Result[Unit, CdpError] {
  // Get focused element and insert text
  match self.tree.get_focus() {
    Some(focused) =>
      // Append text to focused element's value
      match self.tree.get_attribute(focused, "value") {
        Ok(Some(current)) =>
          match self.tree.set_attribute(focused, "value", current + text) {
            Ok(_) => Ok(())
            Err(e) => Err(core_to_cdp_error(e))
          }
        Ok(None) =>
          match self.tree.set_attribute(focused, "value", text) {
            Ok(_) => Ok(())
            Err(e) => Err(core_to_cdp_error(e))
          }
        Err(e) => Err(core_to_cdp_error(e))
      }
    None => Err(CdpError::from_code(NoSuchElement, "No element is focused"))
  }
}
