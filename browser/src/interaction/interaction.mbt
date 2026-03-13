///|
pub enum DispatchEffect {
  None
  Render
  Quit
  PromptUrl
  SelectionModeChanged(Bool)
}

///|
pub struct PointerDispatchEvent {
  event_type : String
  button : Int
}

///|
pub enum DragDispatchTarget {
  Source
  PreviousTarget
  CurrentTarget
}

///|
pub struct DragDispatchEvent {
  event_type : String
  target : DragDispatchTarget
}

///|
pub enum InteractionCommand {
  IdleTick
  FocusedKey(String)
  KeyDown(String)
  KeyUp(String)
  TextInput(String)
  ScrollBy(Int)
  PageScroll(Int)
  FocusNext
  FocusPrev
  ActivateFocused
  PromptUrl
  Refresh
  Back
  Forward
  PointerClick(Int, Int)
  PointerDown(Int, Int)
  PointerUp(Int, Int)
  PointerMove(Int, Int)
  PointerButtonDown(Int, Int, Int)
  PointerButtonUp(Int, Int, Int)
  EnterHintMode
  ExitHintMode
  HintChar(String)
  ToggleSelectionMode
  ToggleDarkMode
  Quit
}

///|
pub fn none_effect() -> DispatchEffect {
  None
}

///|
pub fn text_input_command(text : String) -> InteractionCommand {
  TextInput(text)
}

///|
pub fn key_down_command(key : String) -> InteractionCommand {
  KeyDown(key)
}

///|
pub fn key_up_command(key : String) -> InteractionCommand {
  KeyUp(key)
}

///|
pub fn pointer_move_command(col : Int, row : Int) -> InteractionCommand {
  PointerMove(col, row)
}

///|
pub fn pointer_down_command(col : Int, row : Int) -> InteractionCommand {
  PointerDown(col, row)
}

///|
pub fn pointer_up_command(col : Int, row : Int) -> InteractionCommand {
  PointerUp(col, row)
}

///|
pub fn pointer_click_command(col : Int, row : Int) -> InteractionCommand {
  PointerClick(col, row)
}

///|
pub fn pointer_move_event_sequence(
  pointer_type : String,
) -> Array[PointerDispatchEvent] {
  let events : Array[PointerDispatchEvent] = []
  events.push({ event_type: "pointermove", button: 0 })
  if pointer_type == "mouse" {
    events.push({ event_type: "mousemove", button: 0 })
  }
  events
}

///|
pub fn pointer_press_event_sequence(
  pointer_type : String,
  button : Int,
) -> Array[PointerDispatchEvent] {
  let events : Array[PointerDispatchEvent] = []
  if button == 0 && pointer_type != "mouse" {
    events.push({ event_type: "pointerover", button })
    events.push({ event_type: "pointerenter", button })
  }
  events.push({ event_type: "pointerdown", button })
  events.push({ event_type: "mousedown", button })
  events
}

///|
pub fn pointer_release_event_sequence(
  pointer_type : String,
  button : Int,
) -> Array[PointerDispatchEvent] {
  let events : Array[PointerDispatchEvent] = []
  events.push({ event_type: "pointerup", button })
  if button == 0 && pointer_type == "touch" {
    events.push({ event_type: "pointerout", button })
    events.push({ event_type: "pointerleave", button })
  }
  events
}

///|
pub fn pointer_post_release_mouse_event_sequence(
  button : Int,
  emit_contextmenu : Bool,
  emit_click : Bool,
  emit_double_click : Bool,
) -> Array[PointerDispatchEvent] {
  let events : Array[PointerDispatchEvent] = []
  if emit_contextmenu {
    events.push({ event_type: "contextmenu", button })
  }
  events.push({ event_type: "mouseup", button })
  if emit_click {
    events.push({ event_type: "click", button })
    if emit_double_click {
      events.push({ event_type: "dblclick", button })
    }
  }
  events
}

///|
pub fn pointer_dispatch_event_names(
  events : Array[PointerDispatchEvent],
) -> Array[String] {
  let names : Array[String] = []
  for event in events {
    names.push(event.event_type)
  }
  names
}

///|
pub fn drag_move_event_sequence(
  emit_dragstart? : Bool = false,
  emit_dragleave? : Bool = false,
  emit_dragenter? : Bool = false,
  emit_dragover? : Bool = false,
) -> Array[DragDispatchEvent] {
  let events : Array[DragDispatchEvent] = []
  if emit_dragstart {
    events.push({ event_type: "dragstart", target: Source })
  }
  events.push({ event_type: "drag", target: Source })
  if emit_dragleave {
    events.push({ event_type: "dragleave", target: PreviousTarget })
  }
  if emit_dragenter {
    events.push({ event_type: "dragenter", target: CurrentTarget })
  }
  if emit_dragover {
    events.push({ event_type: "dragover", target: CurrentTarget })
  }
  events
}

///|
pub fn drag_release_event_sequence(
  emit_drop? : Bool = false,
) -> Array[DragDispatchEvent] {
  let events : Array[DragDispatchEvent] = []
  if emit_drop {
    events.push({ event_type: "drop", target: CurrentTarget })
  }
  events.push({ event_type: "dragend", target: Source })
  events
}

///|
pub fn drag_accept_target(
  drag_source : String,
  drag_target : String,
  dragover_prevented : Bool,
) -> String {
  if dragover_prevented && drag_target != "" && drag_target != drag_source {
    drag_target
  } else {
    ""
  }
}

///|
pub fn drag_drop_target(
  drag_source : String,
  drag_over_target : String,
  accepted_target : String,
) -> String {
  if drag_over_target != "" &&
    accepted_target == drag_over_target &&
    drag_over_target != drag_source {
    drag_over_target
  } else {
    ""
  }
}

///|
pub fn drag_dispatch_event_labels(
  events : Array[DragDispatchEvent],
) -> Array[String] {
  let labels : Array[String] = []
  for event in events {
    let target = match event.target {
      Source => "Source"
      PreviousTarget => "PreviousTarget"
      CurrentTarget => "CurrentTarget"
    }
    labels.push(target + ":" + event.event_type)
  }
  labels
}

///|
pub fn pointer_button_down_command(
  col : Int,
  row : Int,
  button : Int,
) -> InteractionCommand {
  PointerButtonDown(col, row, button)
}

///|
pub fn pointer_button_up_command(
  col : Int,
  row : Int,
  button : Int,
) -> InteractionCommand {
  PointerButtonUp(col, row, button)
}

///|
pub fn command_of_action(action : @tui.BrowserAction) -> InteractionCommand {
  match action {
    @tui.Quit => Quit
    @tui.ScrollDown => ScrollBy(50)
    @tui.ScrollUp => ScrollBy(-50)
    @tui.PageDown => PageScroll(1)
    @tui.PageUp => PageScroll(-1)
    @tui.NextLink => FocusNext
    @tui.PrevLink => FocusPrev
    @tui.ActivateLink => ActivateFocused
    @tui.GoToUrl(_) => PromptUrl
    @tui.Refresh => Refresh
    @tui.Back => Back
    @tui.Forward => Forward
    @tui.MouseClick(col, row) => PointerClick(col, row)
    @tui.MouseDown(col, row) => PointerDown(col, row)
    @tui.MouseUp(col, row) => PointerUp(col, row)
    @tui.MouseMove(col, row) => PointerMove(col, row)
    @tui.MouseScrollUp(_, _) => ScrollBy(-48)
    @tui.MouseScrollDown(_, _) => ScrollBy(48)
    @tui.EnterHintMode => EnterHintMode
    @tui.ExitHintMode => ExitHintMode
    @tui.HintChar(c) => HintChar(c)
    @tui.ToggleRawMode => ToggleSelectionMode
    @tui.ToggleDarkMode => ToggleDarkMode
  }
}

///|
pub fn command_name(command : InteractionCommand) -> String {
  match command {
    IdleTick => "IdleTick"
    FocusedKey(key) => "FocusedKey(" + key + ")"
    KeyDown(key) => "KeyDown(" + key + ")"
    KeyUp(key) => "KeyUp(" + key + ")"
    TextInput(text) => "TextInput(" + text + ")"
    ScrollBy(delta) => "ScrollBy(" + delta.to_string() + ")"
    PageScroll(direction) => "PageScroll(" + direction.to_string() + ")"
    FocusNext => "FocusNext"
    FocusPrev => "FocusPrev"
    ActivateFocused => "ActivateFocused"
    PromptUrl => "PromptUrl"
    Refresh => "Refresh"
    Back => "Back"
    Forward => "Forward"
    PointerClick(col, row) =>
      "PointerClick(" + col.to_string() + "," + row.to_string() + ")"
    PointerDown(col, row) =>
      "PointerDown(" + col.to_string() + "," + row.to_string() + ")"
    PointerUp(col, row) =>
      "PointerUp(" + col.to_string() + "," + row.to_string() + ")"
    PointerMove(col, row) =>
      "PointerMove(" + col.to_string() + "," + row.to_string() + ")"
    PointerButtonDown(col, row, button) =>
      "PointerButtonDown(" +
      col.to_string() +
      "," +
      row.to_string() +
      "," +
      button.to_string() +
      ")"
    PointerButtonUp(col, row, button) =>
      "PointerButtonUp(" +
      col.to_string() +
      "," +
      row.to_string() +
      "," +
      button.to_string() +
      ")"
    EnterHintMode => "EnterHintMode"
    ExitHintMode => "ExitHintMode"
    HintChar(c) => "HintChar(" + c + ")"
    ToggleSelectionMode => "ToggleSelectionMode"
    ToggleDarkMode => "ToggleDarkMode"
    Quit => "Quit"
  }
}

///|
pub async fn dispatch_key(
  browser : @shell.Browser,
  key : String,
) -> DispatchEffect raise @http.HttpError {
  if key.length() == 0 {
    return dispatch_command(browser, IdleTick)
  }
  if not(browser.is_hint_mode()) {
    let focused_effect = dispatch_command(browser, FocusedKey(key))
    match focused_effect {
      None => ()
      _ => return focused_effect
    }
  }
  let action = if browser.is_hint_mode() {
    @tui.key_to_hint_action(key)
  } else {
    @tui.key_to_action(key)
  }
  match action {
    Some(action) => dispatch_action(browser, action)
    None => None
  }
}

///|
pub async fn dispatch_action(
  browser : @shell.Browser,
  action : @tui.BrowserAction,
) -> DispatchEffect raise @http.HttpError {
  dispatch_command(browser, command_of_action(action))
}

///|
pub async fn dispatch_command(
  browser : @shell.Browser,
  command : InteractionCommand,
) -> DispatchEffect raise @http.HttpError {
  match command {
    IdleTick => if browser.tick_js() { Render } else { None }
    FocusedKey(key) =>
      if browser.is_hint_mode() {
        None
      } else if browser.handle_focused_key(key) {
        Render
      } else {
        None
      }
    KeyDown(key) =>
      if browser.is_hint_mode() {
        None
      } else if browser.handle_focused_key(key) {
        Render
      } else {
        None
      }
    KeyUp(_) => None
    TextInput(text) =>
      if browser.handle_focused_key(text) {
        Render
      } else {
        None
      }
    ScrollBy(delta) => {
      if delta >= 0 {
        browser.scroll_down(delta)
      } else {
        browser.scroll_up(-delta)
      }
      Render
    }
    PageScroll(direction) => {
      let amount = browser.get_viewport_height() - 50
      if direction >= 0 {
        browser.scroll_down(amount)
      } else {
        browser.scroll_up(amount)
      }
      Render
    }
    FocusNext => {
      browser.next_link()
      Render
    }
    FocusPrev => {
      browser.prev_link()
      Render
    }
    ActivateFocused =>
      if browser.activate_focused_link() {
        Render
      } else {
        None
      }
    PromptUrl => PromptUrl
    Refresh => {
      let _ = browser.navigate(browser.get_current_url())
      Render
    }
    Back =>
      match browser.go_back() {
        Some(_) => Render
        None => None
      }
    Forward =>
      match browser.go_forward() {
        Some(_) => Render
        None => None
      }
    PointerClick(col, row) =>
      if browser.activate_link_at(col, row) {
        Render
      } else {
        None
      }
    PointerDown(col, row) =>
      if browser.pointer_down_at(col, row) {
        Render
      } else {
        None
      }
    PointerUp(col, row) =>
      if browser.pointer_up_at(col, row) {
        Render
      } else {
        None
      }
    PointerMove(col, row) =>
      if browser.pointer_move_at(col, row) {
        Render
      } else {
        None
      }
    PointerButtonDown(col, row, button) =>
      if button == 0 && browser.pointer_down_at(col, row) {
        Render
      } else {
        None
      }
    PointerButtonUp(col, row, button) =>
      if button == 0 && browser.pointer_up_at(col, row) {
        Render
      } else {
        None
      }
    EnterHintMode => {
      browser.enter_hint_mode()
      Render
    }
    ExitHintMode => {
      browser.exit_hint_mode()
      Render
    }
    HintChar(c) =>
      match browser.process_hint_char(c) {
        Some(url) => {
          let _ = browser.navigate(url)
          Render
        }
        None => Render
      }
    ToggleSelectionMode => SelectionModeChanged(browser.toggle_selection_mode())
    ToggleDarkMode => {
      browser.toggle_dark_mode()
      Render
    }
    Quit => Quit
  }
}

///|
pub fn dispatch_cdp_command(
  session : @cdp.CdpSession,
  command : InteractionCommand,
) -> Result[Unit, @cdp.CdpError] {
  let input = session.get_input()
  match command {
    PointerMove(col, row) =>
      input.dispatch_mouse_event(
        "mouseMoved",
        col.to_double(),
        row.to_double(),
        "left",
        0,
      )
    PointerDown(col, row) =>
      input.dispatch_mouse_event(
        "mousePressed",
        col.to_double(),
        row.to_double(),
        "left",
        1,
      )
    PointerUp(col, row) =>
      input.dispatch_mouse_event(
        "mouseReleased",
        col.to_double(),
        row.to_double(),
        "left",
        1,
      )
    PointerClick(col, row) => {
      let _ = input.dispatch_mouse_event(
        "mousePressed",
        col.to_double(),
        row.to_double(),
        "left",
        1,
      )
      input.dispatch_mouse_event(
        "mouseReleased",
        col.to_double(),
        row.to_double(),
        "left",
        1,
      )
    }
    PointerButtonDown(col, row, button) =>
      input.dispatch_mouse_event(
        "mousePressed",
        col.to_double(),
        row.to_double(),
        if button == 2 {
          "right"
        } else if button == 1 {
          "middle"
        } else {
          "left"
        },
        1,
      )
    PointerButtonUp(col, row, button) =>
      input.dispatch_mouse_event(
        "mouseReleased",
        col.to_double(),
        row.to_double(),
        if button == 2 {
          "right"
        } else if button == 1 {
          "middle"
        } else {
          "left"
        },
        1,
      )
    KeyDown(key) => input.dispatch_key_event("keyDown", key, key, None)
    KeyUp(key) => input.dispatch_key_event("keyUp", key, key, None)
    TextInput(text) => input.insert_text(text)
    FocusedKey(key) =>
      if key == "Enter" || key == "Tab" || key == "Escape" {
        input.dispatch_key_event("keyDown", key, key, None)
      } else {
        session.type_text(key)
      }
    Refresh =>
      match session.get_page().reload() {
        Ok(_) => Ok(())
        Err(err) => Err(err)
      }
    Back =>
      match session.get_page().go_back() {
        Ok(_) => Ok(())
        Err(err) => Err(err)
      }
    Forward =>
      match session.get_page().go_forward() {
        Ok(_) => Ok(())
        Err(err) => Err(err)
      }
    _ =>
      input.dispatch_key_event(
        "__unsupported__",
        command_name(command),
        "",
        None,
      )
  }
}
