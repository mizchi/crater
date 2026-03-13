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
