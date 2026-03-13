///|
pub enum DispatchEffect {
  None
  Render
  Quit
  PromptUrl
  SelectionModeChanged(Bool)
}

///|
pub fn none_effect() -> DispatchEffect {
  None
}

///|
pub async fn dispatch_key(
  browser : @shell.Browser,
  key : String,
) -> DispatchEffect raise @http.HttpError {
  if key.length() == 0 {
    return if browser.tick_js() { Render } else { None }
  }
  if not(browser.is_hint_mode()) {
    if browser.handle_focused_key(key) {
      return Render
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
  match action {
    @tui.Quit => Quit
    @tui.ScrollDown => {
      browser.scroll_down(50)
      Render
    }
    @tui.ScrollUp => {
      browser.scroll_up(50)
      Render
    }
    @tui.PageDown => {
      browser.scroll_down(browser.get_viewport_height() - 50)
      Render
    }
    @tui.PageUp => {
      browser.scroll_up(browser.get_viewport_height() - 50)
      Render
    }
    @tui.NextLink => {
      browser.next_link()
      Render
    }
    @tui.PrevLink => {
      browser.prev_link()
      Render
    }
    @tui.ActivateLink =>
      if browser.activate_focused_link() {
        Render
      } else {
        None
      }
    @tui.GoToUrl(_) => PromptUrl
    @tui.Refresh => {
      let _ = browser.navigate(browser.get_current_url())
      Render
    }
    @tui.Back =>
      match browser.go_back() {
        Some(_) => Render
        None => None
      }
    @tui.Forward =>
      match browser.go_forward() {
        Some(_) => Render
        None => None
      }
    @tui.MouseClick(col, row) =>
      if browser.activate_link_at(col, row) {
        Render
      } else {
        None
      }
    @tui.MouseDown(col, row) =>
      if browser.pointer_down_at(col, row) {
        Render
      } else {
        None
      }
    @tui.MouseUp(col, row) =>
      if browser.pointer_up_at(col, row) {
        Render
      } else {
        None
      }
    @tui.MouseMove(col, row) =>
      if browser.pointer_move_at(col, row) {
        Render
      } else {
        None
      }
    @tui.MouseScrollUp(_, _) => {
      browser.scroll_up(48)
      Render
    }
    @tui.MouseScrollDown(_, _) => {
      browser.scroll_down(48)
      Render
    }
    @tui.EnterHintMode => {
      browser.enter_hint_mode()
      Render
    }
    @tui.ExitHintMode => {
      browser.exit_hint_mode()
      Render
    }
    @tui.HintChar(c) =>
      match browser.process_hint_char(c) {
        Some(url) => {
          let _ = browser.navigate(url)
          Render
        }
        None => Render
      }
    @tui.ToggleRawMode => SelectionModeChanged(browser.toggle_selection_mode())
    @tui.ToggleDarkMode => {
      browser.toggle_dark_mode()
      Render
    }
  }
}
