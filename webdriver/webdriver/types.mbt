///|
/// WebDriver Protocol Types
/// Based on W3C WebDriver specification: https://www.w3.org/TR/webdriver2/

// =============================================================================
// Error Codes (W3C WebDriver)
// =============================================================================

///|
/// WebDriver error codes as defined in W3C spec
pub(all) enum ErrorCode {
  ElementClickIntercepted
  ElementNotInteractable
  InsecureCertificate
  InvalidArgument
  InvalidCookieDomain
  InvalidElementState
  InvalidSelector
  InvalidSessionId
  JavascriptError
  MoveTargetOutOfBounds
  NoSuchAlert
  NoSuchCookie
  NoSuchElement
  NoSuchFrame
  NoSuchWindow
  ScriptTimeout
  SessionNotCreated
  StaleElementReference
  Timeout
  UnableToSetCookie
  UnableToCaptureScreen
  UnexpectedAlertOpen
  UnknownCommand
  UnknownError
  UnknownMethod
  UnsupportedOperation
} derive(Debug, Eq)

///|
/// Convert error code to string
pub fn ErrorCode::to_string(self : ErrorCode) -> String {
  match self {
    ElementClickIntercepted => "element click intercepted"
    ElementNotInteractable => "element not interactable"
    InsecureCertificate => "insecure certificate"
    InvalidArgument => "invalid argument"
    InvalidCookieDomain => "invalid cookie domain"
    InvalidElementState => "invalid element state"
    InvalidSelector => "invalid selector"
    InvalidSessionId => "invalid session id"
    JavascriptError => "javascript error"
    MoveTargetOutOfBounds => "move target out of bounds"
    NoSuchAlert => "no such alert"
    NoSuchCookie => "no such cookie"
    NoSuchElement => "no such element"
    NoSuchFrame => "no such frame"
    NoSuchWindow => "no such window"
    ScriptTimeout => "script timeout"
    SessionNotCreated => "session not created"
    StaleElementReference => "stale element reference"
    Timeout => "timeout"
    UnableToSetCookie => "unable to set cookie"
    UnableToCaptureScreen => "unable to capture screen"
    UnexpectedAlertOpen => "unexpected alert open"
    UnknownCommand => "unknown command"
    UnknownError => "unknown error"
    UnknownMethod => "unknown method"
    UnsupportedOperation => "unsupported operation"
  }
}

///|
/// HTTP status code for error
pub fn ErrorCode::http_status(self : ErrorCode) -> Int {
  match self {
    InvalidArgument
    | InvalidCookieDomain
    | InvalidElementState
    | InvalidSelector => 400
    InvalidSessionId
    | NoSuchAlert
    | NoSuchCookie
    | NoSuchElement
    | NoSuchFrame
    | NoSuchWindow
    | StaleElementReference
    | UnknownCommand => 404
    UnknownMethod => 405
    ElementClickIntercepted
    | ElementNotInteractable
    | MoveTargetOutOfBounds
    | UnableToSetCookie
    | UnableToCaptureScreen
    | UnexpectedAlertOpen => 400
    InsecureCertificate
    | SessionNotCreated
    | UnknownError
    | UnsupportedOperation => 500
    JavascriptError | ScriptTimeout | Timeout => 500
  }
}

// =============================================================================
// Request Types
// =============================================================================

///|
/// HTTP method
pub(all) enum HttpMethod {
  Get
  Post
  Delete
} derive(Debug, Eq)

///|
/// Parsed WebDriver command from HTTP request
pub(all) struct WebDriverRequest {
  http_method : HttpMethod
  command : WebDriverCommand
  body : String // JSON body
} derive(Debug)

///|
/// WebDriver commands (endpoints)
pub(all) enum WebDriverCommand {
  // Server status
  Status
  // Session management
  NewSession
  DeleteSession(session_id~ : String)
  GetSession(session_id~ : String)
  // Timeouts
  GetTimeouts(session_id~ : String)
  SetTimeouts(session_id~ : String)
  // Navigation
  NavigateTo(session_id~ : String)
  GetCurrentUrl(session_id~ : String)
  Back(session_id~ : String)
  Forward(session_id~ : String)
  Refresh(session_id~ : String)
  GetTitle(session_id~ : String)
  // Window
  GetWindowHandle(session_id~ : String)
  CloseWindow(session_id~ : String)
  SwitchToWindow(session_id~ : String)
  GetWindowHandles(session_id~ : String)
  NewWindow(session_id~ : String)
  SwitchToFrame(session_id~ : String)
  SwitchToParentFrame(session_id~ : String)
  GetWindowRect(session_id~ : String)
  SetWindowRect(session_id~ : String)
  MaximizeWindow(session_id~ : String)
  MinimizeWindow(session_id~ : String)
  FullscreenWindow(session_id~ : String)
  // Element
  FindElement(session_id~ : String)
  FindElements(session_id~ : String)
  FindElementFromElement(session_id~ : String, element_id~ : String)
  FindElementsFromElement(session_id~ : String, element_id~ : String)
  GetActiveElement(session_id~ : String)
  IsElementSelected(session_id~ : String, element_id~ : String)
  GetElementAttribute(
    session_id~ : String,
    element_id~ : String,
    name~ : String
  )
  GetElementProperty(session_id~ : String, element_id~ : String, name~ : String)
  GetElementCssValue(session_id~ : String, element_id~ : String, name~ : String)
  GetElementText(session_id~ : String, element_id~ : String)
  GetElementTagName(session_id~ : String, element_id~ : String)
  GetElementRect(session_id~ : String, element_id~ : String)
  IsElementEnabled(session_id~ : String, element_id~ : String)
  ElementClick(session_id~ : String, element_id~ : String)
  ElementClear(session_id~ : String, element_id~ : String)
  ElementSendKeys(session_id~ : String, element_id~ : String)
  // Document
  GetPageSource(session_id~ : String)
  ExecuteScript(session_id~ : String)
  ExecuteAsyncScript(session_id~ : String)
  // Cookies
  GetAllCookies(session_id~ : String)
  GetNamedCookie(session_id~ : String, name~ : String)
  AddCookie(session_id~ : String)
  DeleteCookie(session_id~ : String, name~ : String)
  DeleteAllCookies(session_id~ : String)
  // Actions
  PerformActions(session_id~ : String)
  ReleaseActions(session_id~ : String)
  // Alerts
  DismissAlert(session_id~ : String)
  AcceptAlert(session_id~ : String)
  GetAlertText(session_id~ : String)
  SendAlertText(session_id~ : String)
  // Screenshot
  TakeScreenshot(session_id~ : String)
  TakeElementScreenshot(session_id~ : String, element_id~ : String)
  // Print
  PrintPage(session_id~ : String)
  // Unknown
  Unknown(path~ : String)
} derive(Debug)

///|
pub impl Show for WebDriverCommand with output(self, logger) {
  match self {
    Status => logger.write_string("Status")
    NewSession => logger.write_string("NewSession")
    DeleteSession(..) => logger.write_string("DeleteSession")
    GetSession(..) => logger.write_string("GetSession")
    GetTimeouts(..) => logger.write_string("GetTimeouts")
    SetTimeouts(..) => logger.write_string("SetTimeouts")
    NavigateTo(..) => logger.write_string("NavigateTo")
    GetCurrentUrl(..) => logger.write_string("GetCurrentUrl")
    Back(..) => logger.write_string("Back")
    Forward(..) => logger.write_string("Forward")
    Refresh(..) => logger.write_string("Refresh")
    GetTitle(..) => logger.write_string("GetTitle")
    GetWindowHandle(..) => logger.write_string("GetWindowHandle")
    CloseWindow(..) => logger.write_string("CloseWindow")
    SwitchToWindow(..) => logger.write_string("SwitchToWindow")
    GetWindowHandles(..) => logger.write_string("GetWindowHandles")
    NewWindow(..) => logger.write_string("NewWindow")
    SwitchToFrame(..) => logger.write_string("SwitchToFrame")
    SwitchToParentFrame(..) => logger.write_string("SwitchToParentFrame")
    GetWindowRect(..) => logger.write_string("GetWindowRect")
    SetWindowRect(..) => logger.write_string("SetWindowRect")
    MaximizeWindow(..) => logger.write_string("MaximizeWindow")
    MinimizeWindow(..) => logger.write_string("MinimizeWindow")
    FullscreenWindow(..) => logger.write_string("FullscreenWindow")
    FindElement(..) => logger.write_string("FindElement")
    FindElements(..) => logger.write_string("FindElements")
    FindElementFromElement(..) => logger.write_string("FindElementFromElement")
    FindElementsFromElement(..) =>
      logger.write_string("FindElementsFromElement")
    GetActiveElement(..) => logger.write_string("GetActiveElement")
    IsElementSelected(..) => logger.write_string("IsElementSelected")
    GetElementAttribute(..) => logger.write_string("GetElementAttribute")
    GetElementProperty(..) => logger.write_string("GetElementProperty")
    GetElementCssValue(..) => logger.write_string("GetElementCssValue")
    GetElementText(..) => logger.write_string("GetElementText")
    GetElementTagName(..) => logger.write_string("GetElementTagName")
    GetElementRect(..) => logger.write_string("GetElementRect")
    IsElementEnabled(..) => logger.write_string("IsElementEnabled")
    ElementClick(..) => logger.write_string("ElementClick")
    ElementClear(..) => logger.write_string("ElementClear")
    ElementSendKeys(..) => logger.write_string("ElementSendKeys")
    GetPageSource(..) => logger.write_string("GetPageSource")
    ExecuteScript(..) => logger.write_string("ExecuteScript")
    ExecuteAsyncScript(..) => logger.write_string("ExecuteAsyncScript")
    GetAllCookies(..) => logger.write_string("GetAllCookies")
    GetNamedCookie(..) => logger.write_string("GetNamedCookie")
    AddCookie(..) => logger.write_string("AddCookie")
    DeleteCookie(..) => logger.write_string("DeleteCookie")
    DeleteAllCookies(..) => logger.write_string("DeleteAllCookies")
    PerformActions(..) => logger.write_string("PerformActions")
    ReleaseActions(..) => logger.write_string("ReleaseActions")
    DismissAlert(..) => logger.write_string("DismissAlert")
    AcceptAlert(..) => logger.write_string("AcceptAlert")
    GetAlertText(..) => logger.write_string("GetAlertText")
    SendAlertText(..) => logger.write_string("SendAlertText")
    TakeScreenshot(..) => logger.write_string("TakeScreenshot")
    TakeElementScreenshot(..) => logger.write_string("TakeElementScreenshot")
    PrintPage(..) => logger.write_string("PrintPage")
    Unknown(..) => logger.write_string("Unknown")
  }
}

// =============================================================================
// Response Types
// =============================================================================

///|
/// WebDriver response (success or error)
pub(all) enum WebDriverResponse {
  Success(WebDriverValue)
  Error(WebDriverError)
} derive(Debug)

///|
/// WebDriver success value
pub(all) enum WebDriverValue {
  Null
  Bool(Bool)
  String(String)
  Number(Double)
  Array(Array[WebDriverValue])
  Object(Map[String, WebDriverValue])
  Element(element_id~ : String)
} derive(Debug)

///|
/// WebDriver error response
pub(all) struct WebDriverError {
  error : ErrorCode
  message : String
  stacktrace : String
} derive(Debug)

// =============================================================================
// Session Types
// =============================================================================

///|
/// Browser capabilities
pub(all) struct Capabilities {
  browser_name : String
  browser_version : String
  platform_name : String
  accept_insecure_certs : Bool
  page_load_strategy : PageLoadStrategy
  proxy : ProxyConfig?
  timeouts : Timeouts
} derive(Debug)

///|
/// Page load strategy
pub(all) enum PageLoadStrategy {
  None
  Eager
  Normal
} derive(Debug, Eq)

///|
/// Proxy configuration
pub(all) struct ProxyConfig {
  proxy_type : String
  proxy_autoconfig_url : String?
  ftp_proxy : String?
  http_proxy : String?
  no_proxy : Array[String]
  ssl_proxy : String?
  socks_proxy : String?
  socks_version : Int?
} derive(Debug)

///|
/// Timeout settings
pub(all) struct Timeouts {
  script : Int // milliseconds, default 30000
  page_load : Int // milliseconds, default 300000
  implicit : Int // milliseconds, default 0
} derive(Debug)

///|
/// Default timeouts
pub fn Timeouts::default() -> Timeouts {
  { script: 30000, page_load: 300000, implicit: 0 }
}

///|
/// Session information
pub(all) struct Session {
  id : String
  capabilities : Capabilities
} derive(Debug)

// =============================================================================
// Element Locator
// =============================================================================

///|
/// Element location strategy
pub(all) enum LocatorStrategy {
  CssSelector
  LinkText
  PartialLinkText
  TagName
  XPath
} derive(Debug, Eq)

///|
/// Convert strategy to string
pub fn LocatorStrategy::to_string(self : LocatorStrategy) -> String {
  match self {
    CssSelector => "css selector"
    LinkText => "link text"
    PartialLinkText => "partial link text"
    TagName => "tag name"
    XPath => "xpath"
  }
}

///|
/// Parse strategy from string
pub fn LocatorStrategy::from_string(s : String) -> LocatorStrategy? {
  match s {
    "css selector" => Some(CssSelector)
    "link text" => Some(LinkText)
    "partial link text" => Some(PartialLinkText)
    "tag name" => Some(TagName)
    "xpath" => Some(XPath)
    _ => None
  }
}

// =============================================================================
// Window/Rect Types
// =============================================================================

///|
/// Window rectangle
pub(all) struct WindowRect {
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Debug)

///|
/// Element rectangle (with floating point)
pub(all) struct ElementRect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Debug)
