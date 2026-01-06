///|
/// Tests for WebDriver router
test "parse status request" {
  let req = parse_request("GET", "/status", "")
  inspect(req.command, content="Status")
}

///|
test "parse new session request" {
  let req = parse_request("POST", "/session", "{}")
  inspect(req.command, content="NewSession")
}

///|
test "parse delete session request" {
  let req = parse_request("DELETE", "/session/abc123", "")
  match req.command {
    DeleteSession(session_id~) => inspect(session_id, content="abc123")
    _ => fail("Expected DeleteSession")
  }
}

///|
test "parse navigate to request" {
  let req = parse_request(
    "POST", "/session/abc123/url", "{\"url\":\"https://example.com\"}",
  )
  match req.command {
    NavigateTo(session_id~) => inspect(session_id, content="abc123")
    _ => fail("Expected NavigateTo")
  }
}

///|
test "parse get current url request" {
  let req = parse_request("GET", "/session/abc123/url", "")
  match req.command {
    GetCurrentUrl(session_id~) => inspect(session_id, content="abc123")
    _ => fail("Expected GetCurrentUrl")
  }
}

///|
test "parse find element request" {
  let req = parse_request(
    "POST", "/session/abc123/element", "{\"using\":\"css selector\",\"value\":\"#id\"}",
  )
  match req.command {
    FindElement(session_id~) => inspect(session_id, content="abc123")
    _ => fail("Expected FindElement")
  }
}

///|
test "parse element click request" {
  let req = parse_request("POST", "/session/abc123/element/elem456/click", "")
  match req.command {
    ElementClick(session_id~, element_id~) => {
      inspect(session_id, content="abc123")
      inspect(element_id, content="elem456")
    }
    _ => fail("Expected ElementClick")
  }
}

///|
test "parse get element attribute request" {
  let req = parse_request(
    "GET", "/session/abc123/element/elem456/attribute/href", "",
  )
  match req.command {
    GetElementAttribute(session_id~, element_id~, name~) => {
      inspect(session_id, content="abc123")
      inspect(element_id, content="elem456")
      inspect(name, content="href")
    }
    _ => fail("Expected GetElementAttribute")
  }
}

///|
test "parse screenshot request" {
  let req = parse_request("GET", "/session/abc123/screenshot", "")
  match req.command {
    TakeScreenshot(session_id~) => inspect(session_id, content="abc123")
    _ => fail("Expected TakeScreenshot")
  }
}

///|
test "parse unknown request" {
  let req = parse_request("GET", "/unknown/path", "")
  match req.command {
    Unknown(path~) => inspect(path, content="unknown/path")
    _ => fail("Expected Unknown")
  }
}
