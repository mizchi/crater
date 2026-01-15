///|
/// Event handling for interactive TUI components

///|
/// Click handler type
pub struct ClickHandler(() -> Unit)

///|
/// Event handlers map (component ID -> handler)
pub struct EventHandlers {
  click_handlers : Map[String, ClickHandler]
}

///|
pub fn EventHandlers::new() -> EventHandlers {
  { click_handlers: Map::new() }
}

///|
/// Register a click handler for a component
pub fn EventHandlers::on_click(
  self : EventHandlers,
  id : String,
  handler : ClickHandler,
) -> Unit {
  self.click_handlers.set(id, handler)
}

///|
/// Get click handler for a component
pub fn EventHandlers::get_click(
  self : EventHandlers,
  id : String,
) -> ClickHandler? {
  self.click_handlers.get(id)
}

///|
/// Hit test result
pub(all) struct HitTestResult {
  id : String
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
/// Perform hit test on layout tree
/// Returns the deepest (most specific) node containing the point
pub fn hit_test(
  layout : @node.Layout,
  mouse_x : Int,
  mouse_y : Int,
  offset_x : Int,
  offset_y : Int,
) -> HitTestResult? {
  let x = offset_x + layout.x.to_int()
  let y = offset_y + layout.y.to_int()
  let w = layout.width.to_int()
  let h = layout.height.to_int()

  // Check if point is within this node's bounds
  if mouse_x >= x && mouse_x < x + w && mouse_y >= y && mouse_y < y + h {
    // Check children first (deepest match wins)
    for child in layout.children {
      match hit_test(child, mouse_x, mouse_y, x, y) {
        Some(result) => return Some(result)
        None => continue
      }
    }
    // No child matched, return this node
    Some({ id: layout.id, x, y, width: w, height: h })
  } else {
    None
  }
}

///|
/// Hit test from root (convenience function)
pub fn hit_test_root(
  layout : @node.Layout,
  mouse_x : Int,
  mouse_y : Int,
) -> HitTestResult? {
  hit_test(layout, mouse_x, mouse_y, 0, 0)
}

///|
/// Handle mouse click event
/// Returns true if a handler was invoked
pub fn handle_click(
  layout : @node.Layout,
  handlers : EventHandlers,
  mouse_x : Int,
  mouse_y : Int,
) -> Bool {
  match hit_test_root(layout, mouse_x, mouse_y) {
    Some(result) =>
      match handlers.get_click(result.id) {
        Some(ClickHandler(handler)) => {
          handler()
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Find layout by ID
/// Returns the position and size of the component with the given ID
pub fn find_layout_by_id(
  layout : @node.Layout,
  target_id : String,
  offset_x : Int,
  offset_y : Int,
) -> HitTestResult? {
  let x = offset_x + layout.x.to_int()
  let y = offset_y + layout.y.to_int()
  let w = layout.width.to_int()
  let h = layout.height.to_int()

  // Check if this is the target
  if layout.id == target_id {
    return Some({ id: layout.id, x, y, width: w, height: h })
  }

  // Search children
  for child in layout.children {
    match find_layout_by_id(child, target_id, x, y) {
      Some(result) => return Some(result)
      None => continue
    }
  }
  None
}

///|
/// Find layout by ID from root
pub fn find_layout_by_id_root(
  layout : @node.Layout,
  target_id : String,
) -> HitTestResult? {
  find_layout_by_id(layout, target_id, 0, 0)
}

///|
/// Debug: dump layout tree structure
pub fn dump_layout(
  layout : @node.Layout,
  offset_x : Int,
  offset_y : Int,
  depth : Int,
) -> String {
  let raw_x = layout.x.to_int()
  let raw_y = layout.y.to_int()
  let x = offset_x + raw_x
  let y = offset_y + raw_y
  let w = layout.width.to_int()
  let h = layout.height.to_int()
  let indent = "  ".repeat(depth)
  let mut result = indent +
    layout.id +
    " raw=(" +
    raw_x.to_string() +
    "," +
    raw_y.to_string() +
    ") abs=(" +
    x.to_string() +
    "," +
    y.to_string() +
    ") " +
    w.to_string() +
    "x" +
    h.to_string() +
    " children=" +
    layout.children.length().to_string() +
    "\n"
  for child in layout.children {
    result = result + dump_layout(child, x, y, depth + 1)
  }
  result
}
