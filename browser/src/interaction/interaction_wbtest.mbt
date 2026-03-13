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

///|
test "command_name includes automation-oriented key and pointer button commands" {
  inspect(
    (
      command_name(key_down_command("Enter")),
      command_name(key_up_command("a")),
      command_name(pointer_button_down_command(10, 20, 0)),
      command_name(pointer_button_up_command(10, 20, 2)),
    ),
    content="(\"KeyDown(Enter)\", \"KeyUp(a)\", \"PointerButtonDown(10,20,0)\", \"PointerButtonUp(10,20,2)\")",
  )
}

///|
test "dispatch_cdp_command inserts text into focused control" {
  let session = @cdp.CdpSession::new("test-session")
  let tree = session.get_tree()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let input = tree.create_element("input")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, input)
  let _ = tree.set_attribute(input, "value", "a")
  let _ = session.focus_element(input.to_int())
  match dispatch_cdp_command(session, text_input_command("bc")) {
    Ok(_) => ()
    Err(err) => fail("unexpected cdp dispatch error: " + err.message)
  }
  match tree.get_attribute(input, "value") {
    Ok(Some(value)) => inspect(value, content="abc")
    _ => fail("expected updated input value")
  }
}

///|
test "dispatch_cdp_command treats grapheme focused key as text input" {
  let session = @cdp.CdpSession::new("test-session")
  let tree = session.get_tree()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let input = tree.create_element("input")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, input)
  let _ = session.focus_element(input.to_int())
  match dispatch_cdp_command(session, FocusedKey("x")) {
    Ok(_) => ()
    Err(err) => fail("unexpected cdp dispatch error: " + err.message)
  }
  match tree.get_attribute(input, "value") {
    Ok(Some(value)) => inspect(value, content="x")
    _ => fail("expected focused key to insert text")
  }
}

///|
test "dispatch_cdp_command rejects shell-only commands" {
  let session = @cdp.CdpSession::new("test-session")
  match dispatch_cdp_command(session, FocusNext) {
    Ok(_) => fail("expected unsupported command error")
    Err(err) =>
      inspect(err.message, content="Unknown key event type: __unsupported__")
  }
}

///|
test "dispatch_cdp_command accepts key and pointer button commands" {
  let session = @cdp.CdpSession::new("test-session")
  match dispatch_cdp_command(session, key_down_command("Enter")) {
    Ok(_) => ()
    Err(err) => fail("unexpected keyDown error: " + err.message)
  }
  match dispatch_cdp_command(session, key_up_command("Enter")) {
    Ok(_) => ()
    Err(err) => fail("unexpected keyUp error: " + err.message)
  }
  match dispatch_cdp_command(session, pointer_button_down_command(10, 20, 0)) {
    Ok(_) => ()
    Err(err) => fail("unexpected pointerDown error: " + err.message)
  }
  match dispatch_cdp_command(session, pointer_button_up_command(10, 20, 0)) {
    Ok(_) => ()
    Err(err) => fail("unexpected pointerUp error: " + err.message)
  }
}
