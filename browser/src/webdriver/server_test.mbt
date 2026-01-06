///|
/// Tests for WebDriver Server Handler
test "status endpoint returns ready" {
  let manager = SessionManager::new()
  let req = parse_request("GET", "/status", "")
  let (status, resp) = manager.handle_request(req)
  inspect(status, content="200")
  let json = resp.to_json()
  assert_true(json.contains("\"ready\":true"))
  assert_true(json.contains("Crater WebDriver"))
}

///|
test "create new session" {
  let manager = SessionManager::new()
  let req = parse_request("POST", "/session", "{}")
  let (status, resp) = manager.handle_request(req)
  inspect(status, content="200")
  let json = resp.to_json()
  assert_true(json.contains("sessionId"))
  assert_true(json.contains("capabilities"))
  assert_true(json.contains("crater"))
}

///|
test "delete session" {
  let manager = SessionManager::new()
  // Create session first
  let create_req = parse_request("POST", "/session", "{}")
  let (_, _) = manager.handle_request(create_req)
  // Delete session
  let delete_req = parse_request("DELETE", "/session/session-1", "")
  let (status, resp) = manager.handle_request(delete_req)
  inspect(status, content="200")
  inspect(resp.to_json(), content="{\"value\":null}")
}

///|
test "delete non-existent session returns error" {
  let manager = SessionManager::new()
  let req = parse_request("DELETE", "/session/invalid-id", "")
  let (status, resp) = manager.handle_request(req)
  inspect(status, content="404")
  let json = resp.to_json()
  assert_true(json.contains("invalid session id"))
}

///|
test "get current url" {
  let manager = SessionManager::new()
  // Create session
  let create_req = parse_request("POST", "/session", "{}")
  let (_, _) = manager.handle_request(create_req)
  // Get URL
  let url_req = parse_request("GET", "/session/session-1/url", "")
  let (status, resp) = manager.handle_request(url_req)
  inspect(status, content="200")
  let json = resp.to_json()
  assert_true(json.contains("about:blank"))
}

///|
test "navigate to url" {
  let manager = SessionManager::new()
  // Create session
  let create_req = parse_request("POST", "/session", "{}")
  let (_, _) = manager.handle_request(create_req)
  // Navigate
  let nav_req = parse_request(
    "POST", "/session/session-1/url", "{\"url\":\"https://example.com\"}",
  )
  let (status, _) = manager.handle_request(nav_req)
  inspect(status, content="200")
  // Verify URL changed
  let url_req = parse_request("GET", "/session/session-1/url", "")
  let (_, resp) = manager.handle_request(url_req)
  let json = resp.to_json()
  assert_true(json.contains("example.com"))
}

///|
test "get title" {
  let manager = SessionManager::new()
  // Create session
  let create_req = parse_request("POST", "/session", "{}")
  let (_, _) = manager.handle_request(create_req)
  // Navigate
  let nav_req = parse_request(
    "POST", "/session/session-1/url", "{\"url\":\"https://example.com\"}",
  )
  let (_, _) = manager.handle_request(nav_req)
  // Get title
  let title_req = parse_request("GET", "/session/session-1/title", "")
  let (status, resp) = manager.handle_request(title_req)
  inspect(status, content="200")
  let json = resp.to_json()
  assert_true(json.contains("Example Domain"))
}

///|
test "get window rect" {
  let manager = SessionManager::new()
  // Create session
  let create_req = parse_request("POST", "/session", "{}")
  let (_, _) = manager.handle_request(create_req)
  // Get window rect
  let rect_req = parse_request("GET", "/session/session-1/window/rect", "")
  let (status, resp) = manager.handle_request(rect_req)
  inspect(status, content="200")
  let json = resp.to_json()
  assert_true(json.contains("\"width\":800"))
  assert_true(json.contains("\"height\":600"))
}

///|
test "unknown command returns 404" {
  let manager = SessionManager::new()
  let req = parse_request("GET", "/unknown/path", "")
  let (status, resp) = manager.handle_request(req)
  inspect(status, content="404")
  let json = resp.to_json()
  assert_true(json.contains("unknown command"))
}

///|
test "unimplemented command returns 501" {
  let manager = SessionManager::new()
  // Create session
  let create_req = parse_request("POST", "/session", "{}")
  let (_, _) = manager.handle_request(create_req)
  // Try to take screenshot (not yet implemented)
  let req = parse_request("GET", "/session/session-1/screenshot", "")
  let (status, resp) = manager.handle_request(req)
  inspect(status, content="501")
  let json = resp.to_json()
  assert_true(json.contains("not yet implemented"))
}
