///|
async test "dispatch_key returns none for idle tick" {
  let browser = @shell.Browser::new(800, 600)
  match dispatch_key(browser, "") {
    None => ()
    _ => fail("expected none")
  }
}

///|
async test "dispatch_key reports selection mode changes" {
  let browser = @shell.Browser::new(800, 600)
  match dispatch_key(browser, "v") {
    SelectionModeChanged(true) => ()
    _ => fail("expected entering selection mode")
  }
  match dispatch_key(browser, "v") {
    SelectionModeChanged(false) => ()
    _ => fail("expected leaving selection mode")
  }
}

///|
async test "dispatch_key maps prompt-url action" {
  let browser = @shell.Browser::new(800, 600)
  match dispatch_key(browser, "g") {
    PromptUrl => ()
    _ => fail("expected prompt-url effect")
  }
}

///|
test "command_of_action normalizes tui actions into protocol-neutral commands" {
  let scroll_down = match @tui.key_to_action("j") {
    Some(action) => command_name(command_of_action(action))
    None => fail("expected scroll action")
  }
  let page_up = match @tui.key_to_action("PageUp") {
    Some(action) => command_name(command_of_action(action))
    None => fail("expected page action")
  }
  let mouse_down = match @tui.key_to_action("MouseDown:3,4") {
    Some(action) => command_name(command_of_action(action))
    None => fail("expected mouse-down action")
  }
  let toggle_selection = match @tui.key_to_action("v") {
    Some(action) => command_name(command_of_action(action))
    None => fail("expected toggle-selection action")
  }
  inspect(
    (scroll_down, page_up, mouse_down, toggle_selection),
    content="(\"ScrollBy(50)\", \"PageScroll(-1)\", \"PointerDown(3,4)\", \"ToggleSelectionMode\")",
  )
}

///|
async test "dispatch_command reports prompt and selection effects directly" {
  let browser = @shell.Browser::new(800, 600)
  match dispatch_command(browser, PromptUrl) {
    PromptUrl => ()
    _ => fail("expected prompt-url effect")
  }
  match dispatch_command(browser, ToggleSelectionMode) {
    SelectionModeChanged(true) => ()
    _ => fail("expected selection-mode effect")
  }
}
