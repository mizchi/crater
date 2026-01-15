///|
/// Focus management for TUI applications

///|
/// Focus state for the application
pub(all) enum FocusState {
  None
  Focused(String) // Component ID
}

///|
/// Input mode for the application
pub(all) enum InputMode {
  Normal // Raw mode, full keyboard control
  Editing // Non-raw mode, IME enabled
}

///|
/// Focus manager for handling focus state and navigation
pub struct FocusManager {
  mut focus : FocusState
  mut mode : InputMode
  focusable_ids : Array[String]
}

///|
/// Create a new focus manager
pub fn FocusManager::new() -> FocusManager {
  { focus: FocusState::None, mode: InputMode::Normal, focusable_ids: [] }
}

///|
/// Register a focusable component ID
pub fn FocusManager::register(self : FocusManager, id : String) -> Unit {
  if not(self.focusable_ids.contains(id)) {
    self.focusable_ids.push(id)
  }
}

///|
/// Unregister a focusable component ID
pub fn FocusManager::unregister(self : FocusManager, id : String) -> Unit {
  let idx = self.focusable_ids.search(id)
  match idx {
    Some(i) => {
      let _ = self.focusable_ids.remove(i)

    }
    None => ()
  }
}

///|
/// Set focus to a specific component
pub fn FocusManager::focus(self : FocusManager, id : String) -> Unit {
  self.focus = FocusState::Focused(id)
}

///|
/// Remove focus (blur)
pub fn FocusManager::blur(self : FocusManager) -> Unit {
  self.focus = FocusState::None
}

///|
/// Check if a component is currently focused
pub fn FocusManager::is_focused(self : FocusManager, id : String) -> Bool {
  match self.focus {
    FocusState::Focused(focused_id) => focused_id == id
    FocusState::None => false
  }
}

///|
/// Get the currently focused component ID
pub fn FocusManager::get_focused(self : FocusManager) -> String? {
  match self.focus {
    FocusState::Focused(id) => Some(id)
    FocusState::None => None
  }
}

///|
/// Focus the next component in the focusable list (Tab navigation)
pub fn FocusManager::focus_next(self : FocusManager) -> Unit {
  if self.focusable_ids.length() == 0 {
    return
  }
  match self.focus {
    FocusState::None => self.focus = FocusState::Focused(self.focusable_ids[0])
    FocusState::Focused(current_id) => {
      let idx = self.focusable_ids.search(current_id)
      match idx {
        Some(i) => {
          let next_idx = (i + 1) % self.focusable_ids.length()
          self.focus = FocusState::Focused(self.focusable_ids[next_idx])
        }
        None => self.focus = FocusState::Focused(self.focusable_ids[0])
      }
    }
  }
}

///|
/// Focus the previous component in the focusable list (Shift+Tab navigation)
pub fn FocusManager::focus_prev(self : FocusManager) -> Unit {
  if self.focusable_ids.length() == 0 {
    return
  }
  match self.focus {
    FocusState::None =>
      self.focus = FocusState::Focused(
        self.focusable_ids[self.focusable_ids.length() - 1],
      )
    FocusState::Focused(current_id) => {
      let idx = self.focusable_ids.search(current_id)
      match idx {
        Some(i) => {
          let prev_idx = if i == 0 {
            self.focusable_ids.length() - 1
          } else {
            i - 1
          }
          self.focus = FocusState::Focused(self.focusable_ids[prev_idx])
        }
        None =>
          self.focus = FocusState::Focused(
            self.focusable_ids[self.focusable_ids.length() - 1],
          )
      }
    }
  }
}

///|
/// Enter editing mode
pub fn FocusManager::start_editing(self : FocusManager) -> Unit {
  self.mode = InputMode::Editing
}

///|
/// Exit editing mode
pub fn FocusManager::stop_editing(self : FocusManager) -> Unit {
  self.mode = InputMode::Normal
}

///|
/// Check if currently in editing mode
pub fn FocusManager::is_editing(self : FocusManager) -> Bool {
  match self.mode {
    InputMode::Editing => true
    InputMode::Normal => false
  }
}

///|
/// Get current input mode
pub fn FocusManager::get_mode(self : FocusManager) -> InputMode {
  self.mode
}
