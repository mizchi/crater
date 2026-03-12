///|
/// WebDriver request routing
/// Parses HTTP method + path into WebDriverCommand

///|
/// Parse HTTP request into WebDriverRequest
pub fn parse_request(
  method_str : String,
  path : String,
  body : String,
) -> WebDriverRequest {
  let http_method = match method_str.to_upper() {
    "GET" => Get
    "POST" => Post
    "DELETE" => Delete
    _ => Get // Default to GET for unknown methods
  }
  let command = parse_command(http_method, path)
  { http_method, command, body }
}

///|
/// Parse path into WebDriverCommand
fn parse_command(http_method : HttpMethod, path : String) -> WebDriverCommand {
  // Remove leading slash and split by '/'
  let path : String = if path.has_prefix("/") && path.length() > 1 {
    let buf = StringBuilder::new()
    let mut skip_first = true
    for c in path.iter() {
      if skip_first {
        skip_first = false
        continue
      }
      buf.write_char(c)
    }
    buf.to_string()
  } else if path == "/" {
    ""
  } else {
    path
  }
  let parts = split_path(path)
  match (http_method, parts) {
    // Status
    (Get, ["status"]) => Status

    // Session management
    (Post, ["session"]) => NewSession
    (Get, ["session", session_id]) => GetSession(session_id~)
    (Delete, ["session", session_id]) => DeleteSession(session_id~)

    // Timeouts
    (Get, ["session", session_id, "timeouts"]) => GetTimeouts(session_id~)
    (Post, ["session", session_id, "timeouts"]) => SetTimeouts(session_id~)

    // Navigation
    (Post, ["session", session_id, "url"]) => NavigateTo(session_id~)
    (Get, ["session", session_id, "url"]) => GetCurrentUrl(session_id~)
    (Post, ["session", session_id, "back"]) => Back(session_id~)
    (Post, ["session", session_id, "forward"]) => Forward(session_id~)
    (Post, ["session", session_id, "refresh"]) => Refresh(session_id~)
    (Get, ["session", session_id, "title"]) => GetTitle(session_id~)

    // Window
    (Get, ["session", session_id, "window"]) => GetWindowHandle(session_id~)
    (Delete, ["session", session_id, "window"]) => CloseWindow(session_id~)
    (Post, ["session", session_id, "window"]) => SwitchToWindow(session_id~)
    (Get, ["session", session_id, "window", "handles"]) =>
      GetWindowHandles(session_id~)
    (Post, ["session", session_id, "window", "new"]) => NewWindow(session_id~)
    (Post, ["session", session_id, "frame"]) => SwitchToFrame(session_id~)
    (Post, ["session", session_id, "frame", "parent"]) =>
      SwitchToParentFrame(session_id~)
    (Get, ["session", session_id, "window", "rect"]) =>
      GetWindowRect(session_id~)
    (Post, ["session", session_id, "window", "rect"]) =>
      SetWindowRect(session_id~)
    (Post, ["session", session_id, "window", "maximize"]) =>
      MaximizeWindow(session_id~)
    (Post, ["session", session_id, "window", "minimize"]) =>
      MinimizeWindow(session_id~)
    (Post, ["session", session_id, "window", "fullscreen"]) =>
      FullscreenWindow(session_id~)

    // Element finding
    (Post, ["session", session_id, "element"]) => FindElement(session_id~)
    (Post, ["session", session_id, "elements"]) => FindElements(session_id~)
    (Post, ["session", session_id, "element", element_id, "element"]) =>
      FindElementFromElement(session_id~, element_id~)
    (Post, ["session", session_id, "element", element_id, "elements"]) =>
      FindElementsFromElement(session_id~, element_id~)
    (Get, ["session", session_id, "element", "active"]) =>
      GetActiveElement(session_id~)

    // Element properties
    (Get, ["session", session_id, "element", element_id, "selected"]) =>
      IsElementSelected(session_id~, element_id~)
    (Get, ["session", session_id, "element", element_id, "attribute", name]) =>
      GetElementAttribute(session_id~, element_id~, name~)
    (Get, ["session", session_id, "element", element_id, "property", name]) =>
      GetElementProperty(session_id~, element_id~, name~)
    (Get, ["session", session_id, "element", element_id, "css", name]) =>
      GetElementCssValue(session_id~, element_id~, name~)
    (Get, ["session", session_id, "element", element_id, "text"]) =>
      GetElementText(session_id~, element_id~)
    (Get, ["session", session_id, "element", element_id, "name"]) =>
      GetElementTagName(session_id~, element_id~)
    (Get, ["session", session_id, "element", element_id, "rect"]) =>
      GetElementRect(session_id~, element_id~)
    (Get, ["session", session_id, "element", element_id, "enabled"]) =>
      IsElementEnabled(session_id~, element_id~)

    // Element interaction
    (Post, ["session", session_id, "element", element_id, "click"]) =>
      ElementClick(session_id~, element_id~)
    (Post, ["session", session_id, "element", element_id, "clear"]) =>
      ElementClear(session_id~, element_id~)
    (Post, ["session", session_id, "element", element_id, "value"]) =>
      ElementSendKeys(session_id~, element_id~)

    // Document
    (Get, ["session", session_id, "source"]) => GetPageSource(session_id~)
    (Post, ["session", session_id, "execute", "sync"]) =>
      ExecuteScript(session_id~)
    (Post, ["session", session_id, "execute", "async"]) =>
      ExecuteAsyncScript(session_id~)

    // Cookies
    (Get, ["session", session_id, "cookie"]) => GetAllCookies(session_id~)
    (Get, ["session", session_id, "cookie", name]) =>
      GetNamedCookie(session_id~, name~)
    (Post, ["session", session_id, "cookie"]) => AddCookie(session_id~)
    (Delete, ["session", session_id, "cookie", name]) =>
      DeleteCookie(session_id~, name~)
    (Delete, ["session", session_id, "cookie"]) => DeleteAllCookies(session_id~)

    // Actions
    (Post, ["session", session_id, "actions"]) => PerformActions(session_id~)
    (Delete, ["session", session_id, "actions"]) => ReleaseActions(session_id~)

    // Alerts
    (Post, ["session", session_id, "alert", "dismiss"]) =>
      DismissAlert(session_id~)
    (Post, ["session", session_id, "alert", "accept"]) =>
      AcceptAlert(session_id~)
    (Get, ["session", session_id, "alert", "text"]) => GetAlertText(session_id~)
    (Post, ["session", session_id, "alert", "text"]) =>
      SendAlertText(session_id~)

    // Screenshot
    (Get, ["session", session_id, "screenshot"]) => TakeScreenshot(session_id~)
    (Get, ["session", session_id, "element", element_id, "screenshot"]) =>
      TakeElementScreenshot(session_id~, element_id~)

    // Print
    (Post, ["session", session_id, "print"]) => PrintPage(session_id~)

    // Unknown
    _ => Unknown(path~)
  }
}

///|
/// Split path by '/'
fn split_path(path : String) -> Array[String] {
  let parts : Array[String] = []
  let current = StringBuilder::new()
  for c in path {
    if c == '/' {
      let s = current.to_string()
      if not(s.is_empty()) {
        parts.push(s)
      }
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  let s = current.to_string()
  if not(s.is_empty()) {
    parts.push(s)
  }
  parts
}
