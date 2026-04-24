///|
/// Tests for CDP-based WebDriver handler
/// Verifies the three-tier architecture: Core Primitives -> CDP Domains -> WebDriver

///|
/// Test CDP session manager basic operations
test "CdpSessionManager::create_and_get" {
  let manager = @webdriver.CdpSessionManager::new()

  // Create a session
  let session_id = manager.create_session()
  inspect(session_id, content="session-1")

  // Get the session
  let session = manager.get_session(session_id)
  assert_true(session is Some(_))

  // Create another session
  let session_id2 = manager.create_session()
  inspect(session_id2, content="session-2")

  // List sessions
  let sessions = manager.list_sessions()
  assert_eq(sessions.length(), 2)
}

///|
/// Test CDP session manager close operation
test "CdpSessionManager::close_session" {
  let manager = @webdriver.CdpSessionManager::new()
  let session_id = manager.create_session()
  assert_true(manager.get_session(session_id) is Some(_))

  // Close the session
  let closed = manager.close_session(session_id)
  assert_true(closed)

  // Session should no longer exist
  assert_true(manager.get_session(session_id) is None)

  // Closing again should return false
  let closed_again = manager.close_session(session_id)
  assert_false(closed_again)
}

///|
/// Test element finding via CDP session
test "handle_find_element::css_selector" {
  let session = @cdp.CdpSession::new("test-session")

  // Build a simple DOM: <html><body><div id="test">Hello</div></body></html>
  let tree = session.get_tree()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let div = tree.create_element("div")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, div)
  let _ = tree.set_attribute(div, "id", "test")

  // Find element by ID
  let result = @webdriver.handle_find_element(session, "id", "test")
  assert_true(result is Ok(_))

  // Find by CSS selector
  let result2 = @webdriver.handle_find_element(session, "css selector", "#test")
  assert_true(result2 is Ok(_))
}

///|
/// Test element finding with tag name
test "handle_find_element::tag_name" {
  let session = @cdp.CdpSession::new("test-session")
  let tree = session.get_tree()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)

  // Find body element by tag name
  let result = @webdriver.handle_find_element(session, "tag name", "body")
  assert_true(result is Ok(_))
}

///|
/// Test findElements returns multiple results
test "handle_find_elements::multiple" {
  let session = @cdp.CdpSession::new("test-session")
  let tree = session.get_tree()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let div1 = tree.create_element("div")
  let div2 = tree.create_element("div")
  let div3 = tree.create_element("div")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, div1)
  let _ = tree.append_child(body, div2)
  let _ = tree.append_child(body, div3)

  // Find all div elements
  let result = @webdriver.handle_find_elements(session, "tag name", "div")
  match result {
    Ok(elements) => assert_eq(elements.length(), 3)
    Err(_) => fail("Expected Ok result")
  }
}

///|
/// Test get element text via CDP
test "handle_get_element_text" {
  let session = @cdp.CdpSession::new("test-session")
  let tree = session.get_tree()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let div = tree.create_element("div")
  let text = tree.create_text("Hello World")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, div)
  let _ = tree.append_child(div, text)
  let div_id = div.to_int()
  let result = @webdriver.handle_get_element_text(session, div_id)
  match result {
    Ok(content) => inspect(content, content="Hello World")
    Err(_) => fail("Expected Ok result")
  }
}

///|
/// Test get element attribute via CDP
test "handle_get_element_attribute" {
  let session = @cdp.CdpSession::new("test-session")
  let tree = session.get_tree()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let link = tree.create_element("a")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, link)
  let _ = tree.set_attribute(link, "href", "https://example.com")
  let link_id = link.to_int()
  let result = @webdriver.handle_get_element_attribute(session, link_id, "href")
  match result {
    Ok(Some(value)) => inspect(value, content="https://example.com")
    Ok(None) => fail("Expected attribute value")
    Err(_) => fail("Expected Ok result")
  }
}

///|
/// Test get element tag name via CDP
test "handle_get_element_tag_name" {
  let session = @cdp.CdpSession::new("test-session")
  let tree = session.get_tree()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let button = tree.create_element("button")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, button)
  let button_id = button.to_int()
  let result = @webdriver.handle_get_element_tag_name(session, button_id)
  match result {
    Ok(tag) => inspect(tag, content="button")
    Err(_) => fail("Expected Ok result")
  }
}

///|
/// Test navigation via CDP
test "handle_navigate" {
  let session = @cdp.CdpSession::new("test-session")

  // Navigate to a URL
  let result = @webdriver.handle_navigate(session, "https://example.com")
  assert_true(result is Ok(_))

  // Verify URL was updated
  let url = @webdriver.handle_get_current_url(session)
  inspect(url, content="https://example.com")
}

///|
/// Test get title via CDP
test "handle_get_title" {
  let session = @cdp.CdpSession::new("test-session")

  // Set title via Page domain
  session.set_title("Test Page")

  // Get title
  let title = @webdriver.handle_get_title(session)
  inspect(title, content="Test Page")
}

///|
/// Test element click via CDP
test "handle_element_click" {
  let session = @cdp.CdpSession::new("test-session")
  let tree = session.get_tree()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let button = tree.create_element("button")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, button)
  let button_id = button.to_int()

  // Click should succeed
  let result = @webdriver.handle_element_click(session, button_id)
  assert_true(result is Ok(_))
}

///|
/// Test CdpHandlerError conversion to W3C format
test "CdpHandlerError::to_w3c_error" {
  // Use the error types through a returned error
  let session = @cdp.CdpSession::new("test-session")

  // Test invalid selector error
  let result = @webdriver.handle_find_element(session, "invalid", "test")
  match result {
    Err(err) => {
      let (code, _) = err.to_w3c_error()
      inspect(code, content="invalid selector")
    }
    Ok(_) => fail("Expected error")
  }

  // Test no such element error (query for non-existent element)
  let result2 = @webdriver.handle_find_element(session, "id", "nonexistent")
  match result2 {
    Err(err) => {
      let (code, _) = err.to_w3c_error()
      inspect(code, content="no such element")
    }
    Ok(_) => fail("Expected no such element error")
  }
}
