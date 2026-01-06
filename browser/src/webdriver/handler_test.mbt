///|
/// Tests for WebDriver Handler
test "cdp session manager create session" {
  let manager = CdpSessionManager::new()
  let ctx1 = manager.create_session()
  let ctx2 = manager.create_session()
  inspect(ctx1, content="session-1")
  inspect(ctx2, content="session-2")
}

///|
test "cdp session manager get session" {
  let manager = CdpSessionManager::new()
  let ctx = manager.create_session()
  let session = manager.get_session(ctx)
  assert_true(session is Some(_))
  let none = manager.get_session("invalid")
  assert_true(none is None)
}

///|
test "cdp session manager close session" {
  let manager = CdpSessionManager::new()
  let ctx = manager.create_session()
  assert_true(manager.get_session(ctx) is Some(_))
  let result = manager.close_session(ctx)
  assert_true(result)
  assert_true(manager.get_session(ctx) is None)
}

///|
test "cdp session manager list sessions" {
  let manager = CdpSessionManager::new()
  let _ = manager.create_session()
  let _ = manager.create_session()
  let sessions = manager.list_sessions()
  inspect(sessions.length(), content="2")
}
