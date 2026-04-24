///|
/// Browser Control API
///
/// This module provides a typed API for browser automation.
/// It can be used:
/// 1. Directly from MoonBit code
/// 2. Via WebDriver BiDi (WebSocket, primary)
/// 3. Via JSON-RPC over WebSocket/stdio
/// 4. Via WebDriver protocol (HTTP, legacy)
/// 5. Via CDP-like protocol for Playwright compatibility

// =============================================================================
// Core Types
// =============================================================================

///|
/// Unique identifier for browser elements
pub(all) struct ElementId {
  id : String
} derive(Debug, Eq)

///|
/// Unique identifier for browser pages/tabs
pub(all) struct PageId {
  id : String
} derive(Debug, Eq)

///|
/// Unique identifier for browser contexts
pub(all) struct ContextId {
  id : String
} derive(Debug, Eq)

///|
/// Point in 2D space
pub(all) struct Point {
  x : Double
  y : Double
} derive(Debug)

///|
/// Rectangle with position and size
pub(all) struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Debug)

///|
/// Viewport size
pub(all) struct Viewport {
  width : Int
  height : Int
} derive(Debug)

///|
/// Mouse button
pub(all) enum MouseButton {
  Left
  Right
  Middle
} derive(Debug, Eq)

///|
/// Keyboard modifier keys
pub(all) struct Modifiers {
  ctrl : Bool
  shift : Bool
  alt : Bool
  meta : Bool
} derive(Debug)

///|
/// Default modifiers (none pressed)
pub fn Modifiers::none() -> Modifiers {
  { ctrl: false, shift: false, alt: false, meta: false }
}

// =============================================================================
// Element Selector
// =============================================================================

///|
/// Element selector strategy
pub(all) enum Selector {
  /// CSS selector (e.g., "#id", ".class", "div > p")
  Css(String)
  /// XPath expression
  XPath(String)
  /// Text content (exact match)
  Text(String)
  /// Text content (contains)
  TextContains(String)
  /// ARIA role
  Role(role~ : String, name~ : String?)
  /// Test ID attribute
  TestId(String)
  /// Accessibility label
  Label(String)
  /// Placeholder text
  Placeholder(String)
  /// Alt text (for images)
  AltText(String)
  /// Title attribute
  Title(String)
} derive(Debug)

///|
/// Convert selector to string representation
pub fn Selector::to_string(self : Selector) -> String {
  match self {
    Css(s) => "css=" + s
    XPath(s) => "xpath=" + s
    Text(s) => "text=\"" + s + "\""
    TextContains(s) => "text=" + s
    Role(role~, name~) =>
      match name {
        Some(n) => "role=" + role + "[name=\"" + n + "\"]"
        None => "role=" + role
      }
    TestId(s) => "data-testid=" + s
    Label(s) => "label=" + s
    Placeholder(s) => "placeholder=" + s
    AltText(s) => "alt=" + s
    Title(s) => "title=" + s
  }
}

// =============================================================================
// API Error Types
// =============================================================================

///|
/// API error
pub(all) enum ApiError {
  /// Element not found
  ElementNotFound(selector~ : String)
  /// Page not found
  PageNotFound(page_id~ : String)
  /// Context not found
  ContextNotFound(context_id~ : String)
  /// Timeout waiting for condition
  Timeout(message~ : String)
  /// Navigation failed
  NavigationFailed(url~ : String, reason~ : String)
  /// Element not visible
  ElementNotVisible(element_id~ : String)
  /// Element not enabled
  ElementNotEnabled(element_id~ : String)
  /// JavaScript evaluation error
  EvalError(message~ : String)
  /// Invalid argument
  InvalidArgument(message~ : String)
  /// Operation not supported
  NotSupported(message~ : String)
  /// Internal error
  InternalError(message~ : String)
} derive(Debug)

///|
pub impl Show for ApiError with output(self, logger) {
  match self {
    ElementNotFound(selector~) => {
      logger.write_string("ElementNotFound(selector=")
      selector.output(logger)
      logger.write_string(")")
    }
    PageNotFound(page_id~) => {
      logger.write_string("PageNotFound(page_id=")
      page_id.output(logger)
      logger.write_string(")")
    }
    ContextNotFound(context_id~) => {
      logger.write_string("ContextNotFound(context_id=")
      context_id.output(logger)
      logger.write_string(")")
    }
    Timeout(message~) => {
      logger.write_string("Timeout(message=")
      message.output(logger)
      logger.write_string(")")
    }
    NavigationFailed(url~, reason~) => {
      logger.write_string("NavigationFailed(url=")
      url.output(logger)
      logger.write_string(", reason=")
      reason.output(logger)
      logger.write_string(")")
    }
    ElementNotVisible(element_id~) => {
      logger.write_string("ElementNotVisible(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    ElementNotEnabled(element_id~) => {
      logger.write_string("ElementNotEnabled(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    EvalError(message~) => {
      logger.write_string("EvalError(message=")
      message.output(logger)
      logger.write_string(")")
    }
    InvalidArgument(message~) => {
      logger.write_string("InvalidArgument(message=")
      message.output(logger)
      logger.write_string(")")
    }
    NotSupported(message~) => {
      logger.write_string("NotSupported(message=")
      message.output(logger)
      logger.write_string(")")
    }
    InternalError(message~) => {
      logger.write_string("InternalError(message=")
      message.output(logger)
      logger.write_string(")")
    }
  }
}

///|
/// API result - success or error
pub(all) enum ApiResult[T] {
  Ok(T)
  Err(ApiError)
} derive(Debug)

// =============================================================================
// API Method Enum (for JSON-RPC dispatch)
// =============================================================================

///|
/// All API methods as an enum for JSON-RPC dispatch
pub(all) enum ApiMethod {
  // Context
  NewContext
  CloseContext(context_id~ : String)
  // Page
  NewPage(context_id~ : String)
  ClosePage(page_id~ : String)
  Pages(context_id~ : String)
  // Navigation
  Goto(page_id~ : String, url~ : String)
  GoBack(page_id~ : String)
  GoForward(page_id~ : String)
  Reload(page_id~ : String)
  Url(page_id~ : String)
  Title(page_id~ : String)
  // Element queries
  Query(page_id~ : String, selector~ : String)
  QueryAll(page_id~ : String, selector~ : String)
  WaitFor(page_id~ : String, selector~ : String, timeout~ : Int)
  // Element properties
  BoundingBox(element_id~ : String)
  TextContent(element_id~ : String)
  InnerText(element_id~ : String)
  InnerHtml(element_id~ : String)
  GetAttribute(element_id~ : String, name~ : String)
  IsVisible(element_id~ : String)
  IsEnabled(element_id~ : String)
  IsChecked(element_id~ : String)
  // Element actions
  Click(element_id~ : String)
  DblClick(element_id~ : String)
  RightClick(element_id~ : String)
  Hover(element_id~ : String)
  Focus(element_id~ : String)
  Fill(element_id~ : String, value~ : String)
  Press(element_id~ : String, key~ : String)
  Clear(element_id~ : String)
  SelectOption(element_id~ : String, value~ : String)
  Check(element_id~ : String)
  Uncheck(element_id~ : String)
  // Mouse
  MouseMove(page_id~ : String, x~ : Double, y~ : Double)
  MouseClick(page_id~ : String, x~ : Double, y~ : Double, button~ : String)
  MouseDown(page_id~ : String, button~ : String)
  MouseUp(page_id~ : String, button~ : String)
  // Keyboard
  KeyboardPress(page_id~ : String, key~ : String)
  KeyboardType(page_id~ : String, text~ : String)
  // Page state
  Content(page_id~ : String)
  SetContent(page_id~ : String, html~ : String)
  ViewportSize(page_id~ : String)
  SetViewportSize(page_id~ : String, width~ : Int, height~ : Int)
  // JavaScript
  Evaluate(page_id~ : String, expression~ : String)
  // Screenshots
  Screenshot(page_id~ : String)
  ElementScreenshot(element_id~ : String)
  // Accessibility
  AccessibilitySnapshot(page_id~ : String)
} derive(Debug)

///|
pub impl Show for ApiMethod with output(self, logger) {
  match self {
    NewContext => logger.write_string("NewContext")
    CloseContext(context_id~) => {
      logger.write_string("CloseContext(context_id=")
      context_id.output(logger)
      logger.write_string(")")
    }
    NewPage(context_id~) => {
      logger.write_string("NewPage(context_id=")
      context_id.output(logger)
      logger.write_string(")")
    }
    ClosePage(page_id~) => {
      logger.write_string("ClosePage(page_id=")
      page_id.output(logger)
      logger.write_string(")")
    }
    Pages(context_id~) => {
      logger.write_string("Pages(context_id=")
      context_id.output(logger)
      logger.write_string(")")
    }
    Goto(page_id~, url~) => {
      logger.write_string("Goto(page_id=")
      page_id.output(logger)
      logger.write_string(", url=")
      url.output(logger)
      logger.write_string(")")
    }
    GoBack(page_id~) => {
      logger.write_string("GoBack(page_id=")
      page_id.output(logger)
      logger.write_string(")")
    }
    GoForward(page_id~) => {
      logger.write_string("GoForward(page_id=")
      page_id.output(logger)
      logger.write_string(")")
    }
    Reload(page_id~) => {
      logger.write_string("Reload(page_id=")
      page_id.output(logger)
      logger.write_string(")")
    }
    Url(page_id~) => {
      logger.write_string("Url(page_id=")
      page_id.output(logger)
      logger.write_string(")")
    }
    Title(page_id~) => {
      logger.write_string("Title(page_id=")
      page_id.output(logger)
      logger.write_string(")")
    }
    Query(page_id~, selector~) => {
      logger.write_string("Query(page_id=")
      page_id.output(logger)
      logger.write_string(", selector=")
      selector.output(logger)
      logger.write_string(")")
    }
    QueryAll(page_id~, selector~) => {
      logger.write_string("QueryAll(page_id=")
      page_id.output(logger)
      logger.write_string(", selector=")
      selector.output(logger)
      logger.write_string(")")
    }
    WaitFor(page_id~, selector~, timeout~) => {
      logger.write_string("WaitFor(page_id=")
      page_id.output(logger)
      logger.write_string(", selector=")
      selector.output(logger)
      logger.write_string(", timeout=")
      timeout.output(logger)
      logger.write_string(")")
    }
    BoundingBox(element_id~) => {
      logger.write_string("BoundingBox(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    TextContent(element_id~) => {
      logger.write_string("TextContent(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    InnerText(element_id~) => {
      logger.write_string("InnerText(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    InnerHtml(element_id~) => {
      logger.write_string("InnerHtml(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    GetAttribute(element_id~, name~) => {
      logger.write_string("GetAttribute(element_id=")
      element_id.output(logger)
      logger.write_string(", name=")
      name.output(logger)
      logger.write_string(")")
    }
    IsVisible(element_id~) => {
      logger.write_string("IsVisible(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    IsEnabled(element_id~) => {
      logger.write_string("IsEnabled(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    IsChecked(element_id~) => {
      logger.write_string("IsChecked(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    Click(element_id~) => {
      logger.write_string("Click(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    DblClick(element_id~) => {
      logger.write_string("DblClick(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    RightClick(element_id~) => {
      logger.write_string("RightClick(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    Hover(element_id~) => {
      logger.write_string("Hover(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    Focus(element_id~) => {
      logger.write_string("Focus(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    Fill(element_id~, value~) => {
      logger.write_string("Fill(element_id=")
      element_id.output(logger)
      logger.write_string(", value=")
      value.output(logger)
      logger.write_string(")")
    }
    Press(element_id~, key~) => {
      logger.write_string("Press(element_id=")
      element_id.output(logger)
      logger.write_string(", key=")
      key.output(logger)
      logger.write_string(")")
    }
    Clear(element_id~) => {
      logger.write_string("Clear(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    SelectOption(element_id~, value~) => {
      logger.write_string("SelectOption(element_id=")
      element_id.output(logger)
      logger.write_string(", value=")
      value.output(logger)
      logger.write_string(")")
    }
    Check(element_id~) => {
      logger.write_string("Check(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    Uncheck(element_id~) => {
      logger.write_string("Uncheck(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    MouseMove(page_id~, x~, y~) => {
      logger.write_string("MouseMove(page_id=")
      page_id.output(logger)
      logger.write_string(", x=")
      x.output(logger)
      logger.write_string(", y=")
      y.output(logger)
      logger.write_string(")")
    }
    MouseClick(page_id~, x~, y~, button~) => {
      logger.write_string("MouseClick(page_id=")
      page_id.output(logger)
      logger.write_string(", x=")
      x.output(logger)
      logger.write_string(", y=")
      y.output(logger)
      logger.write_string(", button=")
      button.output(logger)
      logger.write_string(")")
    }
    MouseDown(page_id~, button~) => {
      logger.write_string("MouseDown(page_id=")
      page_id.output(logger)
      logger.write_string(", button=")
      button.output(logger)
      logger.write_string(")")
    }
    MouseUp(page_id~, button~) => {
      logger.write_string("MouseUp(page_id=")
      page_id.output(logger)
      logger.write_string(", button=")
      button.output(logger)
      logger.write_string(")")
    }
    KeyboardPress(page_id~, key~) => {
      logger.write_string("KeyboardPress(page_id=")
      page_id.output(logger)
      logger.write_string(", key=")
      key.output(logger)
      logger.write_string(")")
    }
    KeyboardType(page_id~, text~) => {
      logger.write_string("KeyboardType(page_id=")
      page_id.output(logger)
      logger.write_string(", text=")
      text.output(logger)
      logger.write_string(")")
    }
    Content(page_id~) => {
      logger.write_string("Content(page_id=")
      page_id.output(logger)
      logger.write_string(")")
    }
    SetContent(page_id~, html~) => {
      logger.write_string("SetContent(page_id=")
      page_id.output(logger)
      logger.write_string(", html=")
      html.output(logger)
      logger.write_string(")")
    }
    ViewportSize(page_id~) => {
      logger.write_string("ViewportSize(page_id=")
      page_id.output(logger)
      logger.write_string(")")
    }
    SetViewportSize(page_id~, width~, height~) => {
      logger.write_string("SetViewportSize(page_id=")
      page_id.output(logger)
      logger.write_string(", width=")
      width.output(logger)
      logger.write_string(", height=")
      height.output(logger)
      logger.write_string(")")
    }
    Evaluate(page_id~, expression~) => {
      logger.write_string("Evaluate(page_id=")
      page_id.output(logger)
      logger.write_string(", expression=")
      expression.output(logger)
      logger.write_string(")")
    }
    Screenshot(page_id~) => {
      logger.write_string("Screenshot(page_id=")
      page_id.output(logger)
      logger.write_string(")")
    }
    ElementScreenshot(element_id~) => {
      logger.write_string("ElementScreenshot(element_id=")
      element_id.output(logger)
      logger.write_string(")")
    }
    AccessibilitySnapshot(page_id~) => {
      logger.write_string("AccessibilitySnapshot(page_id=")
      page_id.output(logger)
      logger.write_string(")")
    }
  }
}
