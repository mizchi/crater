// ============================================================================
// Event System
// ============================================================================

///|
/// Mouse/pointer event data
pub(all) struct PointerEvent {
  x : Double // World coordinates
  y : Double
  button : Int // 0=left, 1=middle, 2=right
  target : String // ID of the target node
  mut propagation_stopped : Bool
}

///|
pub fn PointerEvent::new(
  x : Double,
  y : Double,
  button : Int,
  target : String,
) -> PointerEvent {
  pointer_event_from_msvg(@msvg.PointerEvent::new(x, y, button, target))
}

///|
/// Stop event propagation (prevent bubbling)
pub fn PointerEvent::stop_propagation(self : PointerEvent) -> Unit {
  let event = pointer_event_to_msvg(self)
  event.stop_propagation()
  copy_pointer_event_state_from_msvg(self, event)
}

///|
/// Event handler type
pub(all) struct EventHandler {
  call : (PointerEvent) -> Unit
}

///|
/// Event types
pub(all) enum EventType {
  Click
  MouseDown
  MouseUp
  MouseMove
  MouseEnter
  MouseLeave
  DragStart
  DragMove
  DragEnd
} derive(Eq, Debug)

///|
pub impl Show for EventType with output(self, logger) {
  let name = match self {
    Click => "Click"
    MouseDown => "MouseDown"
    MouseUp => "MouseUp"
    MouseMove => "MouseMove"
    MouseEnter => "MouseEnter"
    MouseLeave => "MouseLeave"
    DragStart => "DragStart"
    DragMove => "DragMove"
    DragEnd => "DragEnd"
  }
  logger.write_string(name)
}

///|
/// Event listener entry
pub(all) struct EventListener {
  event_type : EventType
  handler : EventHandler
}

///|
/// Event manager for handling input events
pub(all) struct EventManager {
  listeners : Map[String, Array[EventListener]] // node_id -> listeners
  mut hovered_node : String? // Currently hovered node
  mut dragging_node : String? // Currently dragging node
  mut drag_start_x : Double
  mut drag_start_y : Double
}

///|
pub fn EventManager::new() -> EventManager {
  {
    listeners: {},
    hovered_node: None,
    dragging_node: None,
    drag_start_x: 0.0,
    drag_start_y: 0.0,
  }
}

///|
/// Register an event listener for a node
pub fn EventManager::on(
  self : EventManager,
  node_id : String,
  event_type : EventType,
  handler : EventHandler,
) -> Unit {
  let listener = EventListener::{ event_type, handler }
  match self.listeners.get(node_id) {
    Some(arr) => arr.push(listener)
    None => self.listeners.set(node_id, [listener])
  }
}

///|
/// Remove all listeners for a node
pub fn EventManager::off_all(self : EventManager, node_id : String) -> Unit {
  let _ = self.listeners.remove(node_id)
}

///|
/// Dispatch a click event at coordinates
pub fn EventManager::dispatch_click(
  self : EventManager,
  x : Double,
  y : Double,
  button : Int,
  scene : Scene,
) -> Unit {
  let hit_nodes = scene.root.hit_test_all(x, y)
  for node in hit_nodes {
    let event = PointerEvent::new(x, y, button, node.id)
    self.dispatch_to_node(node.id, Click, event)
    if event.propagation_stopped {
      break
    }
  }
}

///|
/// Dispatch mouse down event
pub fn EventManager::dispatch_mouse_down(
  self : EventManager,
  x : Double,
  y : Double,
  button : Int,
  scene : Scene,
) -> Unit {
  let hit_nodes = scene.root.hit_test_all(x, y)
  for node in hit_nodes {
    let event = PointerEvent::new(x, y, button, node.id)
    self.dispatch_to_node(node.id, MouseDown, event)
    // Start drag
    if !event.propagation_stopped {
      self.dragging_node = Some(node.id)
      self.drag_start_x = x
      self.drag_start_y = y
      let drag_event = PointerEvent::new(x, y, button, node.id)
      self.dispatch_to_node(node.id, DragStart, drag_event)
    }
    if event.propagation_stopped {
      break
    }
  }
}

///|
/// Dispatch mouse up event
pub fn EventManager::dispatch_mouse_up(
  self : EventManager,
  x : Double,
  y : Double,
  button : Int,
  scene : Scene,
) -> Unit {
  // End drag if dragging
  match self.dragging_node {
    Some(node_id) => {
      let event = PointerEvent::new(x, y, button, node_id)
      self.dispatch_to_node(node_id, DragEnd, event)
      self.dragging_node = None
    }
    None => ()
  }
  // Dispatch mouse up
  let hit_nodes = scene.root.hit_test_all(x, y)
  for node in hit_nodes {
    let event = PointerEvent::new(x, y, button, node.id)
    self.dispatch_to_node(node.id, MouseUp, event)
    if event.propagation_stopped {
      break
    }
  }
}

///|
/// Dispatch mouse move event (handles hover and drag)
pub fn EventManager::dispatch_mouse_move(
  self : EventManager,
  x : Double,
  y : Double,
  scene : Scene,
) -> Unit {
  // Handle drag
  match self.dragging_node {
    Some(node_id) => {
      let event = PointerEvent::new(x, y, 0, node_id)
      self.dispatch_to_node(node_id, DragMove, event)
    }
    None => ()
  }
  // Handle hover (enter/leave)
  let hit_nodes = scene.root.hit_test_all(x, y)
  let new_hovered = if hit_nodes.length() > 0 {
    Some(hit_nodes[0].id)
  } else {
    None
  }
  // Check for mouse leave
  match (self.hovered_node, new_hovered) {
    (Some(old_id), Some(new_id)) =>
      if old_id != new_id {
        let leave_event = PointerEvent::new(x, y, 0, old_id)
        self.dispatch_to_node(old_id, MouseLeave, leave_event)
        let enter_event = PointerEvent::new(x, y, 0, new_id)
        self.dispatch_to_node(new_id, MouseEnter, enter_event)
      }
    (Some(old_id), None) => {
      let leave_event = PointerEvent::new(x, y, 0, old_id)
      self.dispatch_to_node(old_id, MouseLeave, leave_event)
    }
    (None, Some(new_id)) => {
      let enter_event = PointerEvent::new(x, y, 0, new_id)
      self.dispatch_to_node(new_id, MouseEnter, enter_event)
    }
    (None, None) => ()
  }
  self.hovered_node = new_hovered
  // Dispatch mouse move to hovered node
  match new_hovered {
    Some(node_id) => {
      let event = PointerEvent::new(x, y, 0, node_id)
      self.dispatch_to_node(node_id, MouseMove, event)
    }
    None => ()
  }
}

///|
fn EventManager::dispatch_to_node(
  self : EventManager,
  node_id : String,
  event_type : EventType,
  event : PointerEvent,
) -> Unit {
  match self.listeners.get(node_id) {
    Some(listeners) =>
      for listener in listeners {
        if listener.event_type == event_type {
          (listener.handler.call)(event)
        }
      }
    None => ()
  }
}
