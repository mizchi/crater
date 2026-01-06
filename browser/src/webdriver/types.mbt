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
} derive(Show, Eq)

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
} derive(Show, Eq)

///|
/// Parsed WebDriver command from HTTP request
pub(all) struct WebDriverRequest {
  http_method : HttpMethod
  command : WebDriverCommand
  body : String // JSON body
} derive(Show)

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
} derive(Show)

// =============================================================================
// Response Types
// =============================================================================

///|
/// WebDriver response (success or error)
pub(all) enum WebDriverResponse {
  Success(WebDriverValue)
  Error(WebDriverError)
} derive(Show)

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
} derive(Show)

///|
/// WebDriver error response
pub(all) struct WebDriverError {
  error : ErrorCode
  message : String
  stacktrace : String
} derive(Show)

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
} derive(Show)

///|
/// Page load strategy
pub(all) enum PageLoadStrategy {
  None
  Eager
  Normal
} derive(Show, Eq)

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
} derive(Show)

///|
/// Timeout settings
pub(all) struct Timeouts {
  script : Int // milliseconds, default 30000
  page_load : Int // milliseconds, default 300000
  implicit : Int // milliseconds, default 0
} derive(Show)

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
} derive(Show)

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
} derive(Show, Eq)

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
} derive(Show)

///|
/// Element rectangle (with floating point)
pub(all) struct ElementRect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Show)
