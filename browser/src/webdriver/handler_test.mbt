///|
/// Tests for WebDriver Handler
test "browser manager create context" {
  let manager = BrowserManager::new()
  let ctx1 = manager.create_context()
  let ctx2 = manager.create_context()
  inspect(ctx1, content="ctx-1")
  inspect(ctx2, content="ctx-2")
}

///|
test "browser manager get browser" {
  let manager = BrowserManager::new()
  let ctx = manager.create_context()
  let browser = manager.get_browser(ctx)
  assert_true(browser is Some(_))
  let none = manager.get_browser("invalid")
  assert_true(none is None)
}

///|
test "browser manager close context" {
  let manager = BrowserManager::new()
  let ctx = manager.create_context()
  assert_true(manager.get_browser(ctx) is Some(_))
  let result = manager.close_context(ctx)
  assert_true(result)
  assert_true(manager.get_browser(ctx) is None)
}

///|
test "browser manager list contexts" {
  let manager = BrowserManager::new()
  let _ = manager.create_context()
  let _ = manager.create_context()
  let contexts = manager.list_contexts()
  inspect(contexts.length(), content="2")
}

///|
test "browser manager custom viewport" {
  let manager = BrowserManager::new_with_viewport(1024, 768)
  let ctx = manager.create_context()
  let browser = manager.get_browser(ctx).unwrap()
  inspect(browser.viewport_width, content="1024")
  inspect(browser.viewport_height, content="768")
}
