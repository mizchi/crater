///|
/// Browser Control API
///
/// This module provides a typed API for browser automation.
/// It can be used:
/// 1. Directly from MoonBit code
/// 2. Via JSON-RPC over WebSocket/stdio
/// 3. Via WebDriver protocol (HTTP)
/// 4. Via CDP-like protocol for Playwright compatibility

// =============================================================================
// Core Types
// =============================================================================

///|
/// Unique identifier for browser elements
pub(all) struct ElementId {
  id : String
} derive(Show, Eq)

///|
/// Unique identifier for browser pages/tabs
pub(all) struct PageId {
  id : String
} derive(Show, Eq)

///|
/// Unique identifier for browser contexts
pub(all) struct ContextId {
  id : String
} derive(Show, Eq)

///|
/// Point in 2D space
pub(all) struct Point {
  x : Double
  y : Double
} derive(Show)

///|
/// Rectangle with position and size
pub(all) struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Show)

///|
/// Viewport size
pub(all) struct Viewport {
  width : Int
  height : Int
} derive(Show)

///|
/// Mouse button
pub(all) enum MouseButton {
  Left
  Right
  Middle
} derive(Show, Eq)

///|
/// Keyboard modifier keys
pub(all) struct Modifiers {
  ctrl : Bool
  shift : Bool
  alt : Bool
  meta : Bool
} derive(Show)

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
} derive(Show)

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
} derive(Show)

///|
/// API result - success or error
pub(all) enum ApiResult[T] {
  Ok(T)
  Err(ApiError)
} derive(Show)

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
} derive(Show)
